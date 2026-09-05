import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:window_manager/window_manager.dart';

import 'package:theos_pos/core/services/app_initializer.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/core/security/ephemeral_credential_store.dart';
import 'package:theos_pos/core/navigation/route_access_policy.dart';
import 'package:theos_pos/features/authentication/services/server_service.dart';
import 'package:theos_pos/features/authentication/widgets/login_form.dart';
import 'package:theos_pos/features/dashboard/widgets/supervisor_dashboard.dart';
import 'package:theos_pos/main.dart';
import 'package:theos_pos/routes/app_routes.dart';
import 'package:theos_pos/shared/screens/main_screen.dart';
import 'package:theos_pos/shared/providers/menu_provider.dart';
import 'package:theos_pos/shared/constants/user_groups.dart';
import 'package:theos_pos/shared/widgets/deferred_screen.dart';

import 'e2e_configuration.dart';

/// Drives only read-only paths through the real application.
///
/// The provider override prevents automatic queue processing and
/// connectivity-triggered synchronization from starting.
final class ReadOnlyAppDriver {
  ReadOnlyAppDriver(this.tester, this.configuration);

  final WidgetTester tester;
  final E2eConfiguration configuration;

  ProviderContainer get container => _container;

  late ProviderContainer _container;
  final _testCredentials = EphemeralCredentialStore();
  Directory? _testDirectory;
  ServerConfig? _createdServer;
  ServerConfig? _committedServer;
  int? _committedUserId;
  bool _createdCredential = false;
  bool _credentialExistedBeforeRun = false;

  Future<void> launch() async {
    // The application bootstrap normally performs this before runApp. The
    // integration harness pumps MyApp directly to inject Riverpod overrides,
    // so it must initialize the native window plugin itself. Without this,
    // SplashScreen.show() reaches isMinimized() with no registered NSWindow
    // and window_manager 0.5.2 aborts in Swift.
    await windowManager.ensureInitialized();
    // Exercise real HTTP/login/lifecycle, never the operator's saved secrets
    // or financial cache. Reuse these stores across the container restart.
    SharedPreferences.setMockInitialValues({});
    _testDirectory = await Directory.systemTemp.createTemp('theos-erp2-e2e-');
    DatabaseHelper.testExecutorFactory = (name) =>
        NativeDatabase(File('${_testDirectory!.path}/$name.sqlite'));
    _container = _createContainer();
    await _ensureConfiguredServer();

    AppRouter.session.value = const RouteSessionSnapshot();
    appRouter.go(AppRouter.splash);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: _container, child: const MyApp()),
    );
    await _pumpUntil(
      () => _path == AppRouter.login || _path == AppRouter.home,
      description: 'login or restored home route',
    );
  }

  Future<void> authenticateOrVerifyRestoredSession() async {
    if (_path == AppRouter.login) {
      await _selectConfiguredServer();
      final apiKeyField = find.descendant(
        of: find.byKey(LoginFormKeys.apiKey),
        matching: find.byType(EditableText),
      );
      expect(apiKeyField, findsOneWidget);
      await tester.enterText(apiKeyField, configuration.apiKey);
      await tester.pump();
      // Never render either credential in an assertion failure.
      expect(
        tester.widget<EditableText>(apiKeyField).controller.text ==
            configuration.apiKey,
        isTrue,
        reason: 'The access-key field did not retain the test credential.',
      );
      final loginForm = tester.widget<LoginForm>(find.byType(LoginForm));
      expect(
        loginForm.selectedServer?.url == configuration.serverUrl &&
            loginForm.selectedServer?.database == configuration.database,
        isTrue,
        reason: 'The selected server does not match the test target.',
      );
      expect(
        loginForm.formKey.currentState?.validate(),
        isTrue,
        reason: 'The populated login form is invalid.',
      );
      await tester.tap(find.byKey(LoginFormKeys.submit));
      await _pumpUntil(
        () {
          final errors = tester
              .widgetList<InfoBar>(find.byType(InfoBar))
              .where((bar) => bar.severity == InfoBarSeverity.error);
          if (errors.isNotEmpty) {
            final errorText = tester
                .widgetList<SelectableText>(find.byType(SelectableText))
                .map((widget) => widget.data ?? '')
                .join('\n')
                .replaceAll(configuration.apiKey, '[REDACTED]');
            throw StateError('Login rejected: $errorText');
          }
          return _path == AppRouter.home;
        },
        description: 'authenticated home route',
        timeout: const Duration(minutes: 3),
      );
      _createdCredential = true;
    }

    final session = _container
        .read(serverServiceProvider.notifier)
        .currentSession;
    expect(
      session,
      isNotNull,
      reason: 'A persisted session was not committed.',
    );
    expect(session!.url, configuration.serverUrl);
    expect(session.database, configuration.database);
    expect(
      session.apiKey == configuration.apiKey,
      isTrue,
      reason: 'The restored session belongs to a different test credential.',
    );
    expect(AppRouter.session.value.isAuthenticated, isTrue);
    _assertExpectedIdentity('login or restored session');
    _committedServer = session;
    _committedUserId = AppRouter.session.value.userId;
  }

  Future<void> verifySessionRestoration() async {
    // A second Splash inside the same provider tree is not an application
    // restart. In particular, the session coordinator would first close the
    // active Drift connection while repositories in that tree still retain
    // it. Unmount and tear down the scope/container, then boot a fresh tree to
    // exercise the same path as closing and reopening the desktop app.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    // Dispose Riverpod first so Drift stream subscriptions and health timers
    // release the active database. Closing Drift while those consumers are
    // still alive can wait indefinitely on macOS.
    _container.dispose();
    await AppInitializer.deactivateSessionScope().timeout(
      const Duration(seconds: 20),
    );
    AppInitializer.reset();

    _container = _createContainer();
    await _container.read(serverServiceProvider.notifier).loadLastServer();
    AppRouter.session.value = const RouteSessionSnapshot();
    appRouter.go(AppRouter.splash);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: _container, child: const MyApp()),
    );
    await _pumpUntilPath(AppRouter.home, timeout: const Duration(minutes: 2));
    expect(AppRouter.session.value.isAuthenticated, isTrue);
    _assertExpectedIdentity('session restoration');
  }

  void _assertExpectedIdentity(String phase) {
    final expectedUserId = configuration.expectedUserId;
    if (expectedUserId == null) return;
    expect(
      AppRouter.session.value.userId,
      expectedUserId,
      reason:
          'Authenticated session identity did not match '
          'THEOS_E2E_EXPECTED_UID during $phase.',
    );
  }

  Future<void> verifyMenuAndQuickActionNavigation() async {
    final filteredMenu = _container.read(filteredMenuItemsProvider);
    final permittedItems = <MenuItemDefinition>[
      ...filteredMenu.navItems,
      ...filteredMenu.footerItems,
    ].where((item) => !item.isAction).toList(growable: false);

    for (final item in permittedItems) {
      appRouter.go(
        item.path == AppRouter.home ? AppRouter.activities : AppRouter.home,
      );
      await _pumpUntilPath(
        item.path == AppRouter.home ? AppRouter.activities : AppRouter.home,
      );
      await _pumpUntilFound(find.byKey(ValueKey<String>(item.path)));
      await tester.tap(find.byKey(ValueKey<String>(item.path)).first);
      await _pumpUntilPath(item.path);
      await _verifyDeferredDestination(item.path);
    }

    // Operators have a different home from supervisors. Verify their actual
    // primary action rather than waiting for supervisor-only dashboard keys.
    final snapshot = AppRouter.session.value;
    final isSupervisor = kSupervisorGroups.any(snapshot.permissions.contains);
    if (!isSupervisor) {
      appRouter.go(AppRouter.home);
      await _pumpUntilPath(AppRouter.home);
      await _pumpUntilFound(find.byType(HomeScreen));
      final canStartSale = RouteAccessPolicy.allows(
        path: AppRouter.fastSale,
        isAuthenticated: true,
        permissions: snapshot.permissions,
        developerMode: snapshot.developerMode,
      );
      if (canStartSale) {
        await _pumpUntilFound(find.byKey(HomeScreen.startSaleKey));
        await tester.tap(find.byKey(HomeScreen.startSaleKey));
        await _pumpUntilPath(AppRouter.fastSale);
        await _verifyDeferredDestination(AppRouter.fastSale);
      } else {
        expect(find.byKey(HomeScreen.startSaleKey), findsNothing);
      }
      return;
    }

    for (final action in dashboardQuickActionDefinitions) {
      if (!RouteAccessPolicy.allows(
        path: action.path,
        isAuthenticated: true,
        permissions: AppRouter.session.value.permissions,
        developerMode: AppRouter.session.value.developerMode,
      )) {
        continue;
      }
      appRouter.go(AppRouter.home);
      await _pumpUntilPath(AppRouter.home);
      await _pumpUntilFound(find.byKey(action.key));
      await tester.tap(find.byKey(action.key));
      await _pumpUntilPath(action.path);
      await _verifyDeferredDestination(action.path);
    }
  }

  Future<void> _verifyDeferredDestination(String path) async {
    if (path == AppRouter.home) return;
    await _pumpUntilFound(
      find.byKey(DeferredScreen.loadedKey),
      timeout: const Duration(minutes: 1),
    );
    expect(
      find.byKey(DeferredScreen.errorKey),
      findsNothing,
      reason: 'Deferred module failed to load for $path.',
    );
  }

  Future<void> verifyProtectedRouteRedirect() async {
    final authenticatedSnapshot = AppRouter.session.value;
    AppRouter.session.value = const RouteSessionSnapshot();
    appRouter.go(AppRouter.sales);
    await _pumpUntilPath(AppRouter.login);
    expect(appRouter.state.uri.queryParameters['returnTo'], AppRouter.sales);

    AppRouter.session.value = authenticatedSnapshot;
    appRouter.go(AppRouter.home);
    await _pumpUntilPath(AppRouter.home);
  }

  Future<void> dispose() async {
    final service = _container.read(serverServiceProvider.notifier);
    final committedServer = _committedServer;
    final committedUserId = _committedUserId;
    if (_createdCredential) {
      if (!_credentialExistedBeforeRun &&
          committedServer != null &&
          committedUserId != null) {
        await service.removeStoredCredential(
          serverUrl: committedServer.url,
          database: committedServer.database,
          userId: committedUserId,
        );
      }
      await service.clearSession();
    }
    if (_createdServer case final server?) {
      await service.removeServer(server);
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    AppRouter.session.value = const RouteSessionSnapshot();
    _container.dispose();
    await AppInitializer.deactivateSessionScope().timeout(
      const Duration(seconds: 20),
    );
    AppInitializer.reset();
    DatabaseHelper.testExecutorFactory = null;
    await _testCredentials.deleteAll();
    await _testDirectory?.delete(recursive: true);
  }

  String get _path => appRouter.state.uri.path;

  ProviderContainer _createContainer() => ProviderContainer(
    overrides: [
      secureCredentialStoreProvider.overrideWithValue(_testCredentials),
      sessionBackgroundServicesEnabledProvider.overrideWithValue(false),
    ],
  );

  Future<void> _ensureConfiguredServer() async {
    final service = _container.read(serverServiceProvider.notifier);
    await service.loadLastServer();
    _credentialExistedBeforeRun =
        await service.findCredentialAsync(
          serverUrl: configuration.serverUrl,
          database: configuration.database,
          apiKey: configuration.apiKey,
        ) !=
        null;
    final existing = _container
        .read(serverServiceProvider)
        .where(
          (server) =>
              server.url == configuration.serverUrl &&
              server.database == configuration.database,
        );
    if (existing.isNotEmpty) return;

    final server = ServerConfig(
      name: 'E2E read-only',
      url: configuration.serverUrl,
      database: configuration.database,
    );
    await service.addServer(server);
    _createdServer = server;
  }

  Future<void> _selectConfiguredServer() async {
    await _pumpUntilFound(find.byKey(LoginFormKeys.server));
    await tester.tap(find.byKey(LoginFormKeys.server));
    await tester.pumpAndSettle();

    final option = find.textContaining(configuration.serverUrl);
    expect(
      option,
      findsWidgets,
      reason: 'The configured read-only server is not selectable.',
    );
    await tester.tap(option.last);
    await tester.pumpAndSettle();
  }

  Future<void> _pumpUntilPath(
    String path, {
    Duration timeout = const Duration(seconds: 45),
  }) => _pumpUntil(
    () => _path == path,
    description: 'route $path (current: $_path)',
    timeout: timeout,
  );

  Future<void> _pumpUntilFound(
    Finder finder, {
    Duration timeout = const Duration(seconds: 45),
  }) => _pumpUntil(
    () => finder.evaluate().isNotEmpty,
    description: 'widget $finder',
    timeout: timeout,
  );

  Future<void> _pumpUntil(
    bool Function() condition, {
    required String description,
    Duration timeout = const Duration(seconds: 45),
  }) async {
    final stopwatch = Stopwatch()..start();
    while (!condition()) {
      if (stopwatch.elapsed >= timeout) {
        throw TimeoutException('Timed out waiting for $description');
      }
      await tester.pump(const Duration(milliseconds: 100));
      await Future<void>.delayed(const Duration(milliseconds: 20));
    }
    await tester.pump();
  }
}
