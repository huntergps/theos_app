import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:integration_test/integration_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/orbi_app.dart';
import 'package:theos_panel/app/orbi_splash_screen.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/app/session_composition.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/login_preferences.dart';
import 'package:theos_panel/features/auth/login_screen.dart';
import 'package:theos_panel/features/sync/sync_center.dart';

/// Native macOS acceptance surface. It intentionally uses ERP2 reads only:
/// no sale/order/payment mutation is reachable from this test.
/// The mutating four-flow pass is a separate, explicit opt-in test guarded by
/// `ORBI_ERP2_UI_E2E_RUN` in `orbi_erp2_ui_e2e_test.dart`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  test('read-only native target guard rejects newerp and alternate hosts', () {
    for (final value in <String>[
      'https://newerp.tecnosmart.com.ec',
      'https://erp2.example.invalid',
      'http://erp2.tecnosmart.com.ec',
    ]) {
      expect(
        () => _requiredErp2Server({'ORBI_ERP2_SERVER_URL': value}),
        throwsA(isA<TestFailure>()),
        reason: 'read-only ERP2 guard accepted $value',
      );
    }
  });

  testWidgets(
    'native macOS Orbi shell, persistence and online/offline restore',
    (tester) async {
      final env = Platform.environment;
      final serverUrl = _requiredErp2Server(env);
      final database = _required(env, 'ORBI_ERP2_DATABASE');
      // The native read-only pass has one credential boundary: the audit key.
      // Role keys belong only to the separately guarded mutating UI E2E.
      final apiKey = _required(env, 'ORBI_ERP2_AUDIT_API_KEY');
      final login = _required(env, 'ORBI_ERP2_SUPERVISOR_LOGIN');
      final userId = _positiveInt(env['ORBI_ERP2_SUPERVISOR_USER_ID']);
      final preferences = await SharedPreferences.getInstance();
      final oldLoginSelection = preferences.getString(
        LoginPreferencesStore.key,
      );

      final runtime = SessionRuntime();
      final scope = AppScope(
        appId: 'theos_panel',
        installationId: 'native-macos-acceptance',
        normalizedServerUrl: serverUrl,
        database: database,
        userId: userId,
      );
      final online = await runtime.activate(scope, apiKey: apiKey);
      final client = online.client;
      if (client == null) {
        fail('ERP2 online activation did not create a client');
      }
      final identity = await OdooActiveIdentityReader(client).read(scope);
      final capabilities = await OdooCapabilityReader(client).read(
        scope: scope,
        companyId: identity.companyId,
        revision: DateTime.now().millisecondsSinceEpoch,
      );
      final profile = AuthProfile(
        serverUrl: serverUrl,
        database: database,
        login: login,
        userId: userId,
        installationId: scope.installationId,
        credentialReference: 'api-key',
        companyId: identity.companyId,
        allowedCompanyIds: identity.allowedCompanyIds,
      );
      final auth = _ReadOnlyErp2AuthService(
        runtime: runtime,
        scope: scope,
        apiKey: apiKey,
        profile: profile,
        capabilities: capabilities,
      );
      final loginContainer = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(auth),
          authInitialStateProvider.overrideWithValue(
            const AuthViewState(status: AuthControllerStatus.required),
          ),
        ],
      );
      final composition = OrbiSessionComposition(
        authService: auth,
        runtime: runtime,
        capabilities: capabilities,
        // Visiting /sync in this read-only pass must not construct the scope
        // coordinator. A static port keeps the surface testable without
        // starting OperationsSyncJob or dispatching the local outbox.
        sync: _ReadOnlySyncPort(),
      );
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          ...composition.overrides,
          authInitialStateProvider.overrideWithValue(
            AuthViewState(
              status: AuthControllerStatus.authenticated,
              profile: profile,
              capabilities: capabilities,
            ),
          ),
        ],
      );

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        loginContainer.dispose();
        container.dispose();
        await runtime.close();
        if (oldLoginSelection == null) {
          await preferences.remove(LoginPreferencesStore.key);
        } else {
          await preferences.setString(
            LoginPreferencesStore.key,
            oldLoginSelection,
          );
        }
      });

      // The actual branded splash and login surfaces are pumped before the
      // authenticated shell, so a window that cannot foreground still gives a
      // deterministic widget-level failure rather than a false green build.
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(useMaterial3: true),
          home: const OrbiSplashScreen(),
        ),
      );
      expect(find.bySemanticsLabel('Marca Orbi ERP'), findsOneWidget);
      expect(find.text('Preparando Orbi ERP…'), findsOneWidget);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: loginContainer,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.bySemanticsLabel('Logo de Orbi ERP'), findsOneWidget);
      expect(find.text('Bienvenido'), findsOneWidget);

      final fields = find.byType(TextField);
      expect(fields, findsNWidgets(4));
      await tester.enterText(fields.at(0), serverUrl);
      await tester.enterText(fields.at(1), database);
      await tester.enterText(fields.at(2), login);
      await tester.enterText(fields.at(3), 'native-acceptance-placeholder');
      await tester.tap(find.text('Iniciar sesión'));
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 250));
        if (loginContainer.read(authControllerProvider).status !=
            AuthControllerStatus.loading) {
          break;
        }
      }
      expect(
        loginContainer.read(authControllerProvider).status,
        AuthControllerStatus.restored,
      );
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 150));
        final value = LoginPreferencesStore(preferences).load();
        if (value.serverUrl == serverUrl &&
            value.database == database &&
            value.login == login) {
          break;
        }
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 300)),
      );
      await tester.pump();
      final remembered = LoginPreferencesStore(preferences).load();
      expect(remembered.serverUrl, serverUrl);
      expect(remembered.database, database);
      expect(remembered.login, login);

      // Recreate the login widget to prove that only server/database/user are
      // restored; no password or API key is part of this persisted selection.
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: loginContainer,
          child: const MaterialApp(home: LoginScreen()),
        ),
      );
      await tester.pump(const Duration(milliseconds: 250));
      final restoredFields = find.byType(TextField);
      expect(
        tester.widget<TextField>(restoredFields.at(0)).controller?.text,
        serverUrl,
      );
      expect(
        tester.widget<TextField>(restoredFields.at(1)).controller?.text,
        database,
      );
      expect(
        tester.widget<TextField>(restoredFields.at(2)).controller?.text,
        login,
      );
      expect(
        tester.widget<TextField>(restoredFields.at(3)).controller?.text,
        '',
      );

      final router = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const OrbiApp()),
      );
      await tester.pump(const Duration(milliseconds: 500));
      expect(router.state.uri.path, '/');
      expect(find.text('Orbi ERP'), findsWidgets);

      await _visit(tester, router, '/sales', expectedText: 'Órdenes');
      await _visit(tester, router, '/collection', expectedText: 'Caja');
      await _visit(tester, router, '/approvals', expectedText: 'Aprobaciones');
      await _visit(tester, router, '/settings', expectedText: 'Configuración');

      // The setting is changed through the real SettingsScreen controller,
      // then changed back so the test leaves no preference mutation behind.
      final themeField = find.byType(
        DropdownButtonFormField<PreferenceThemeMode>,
      );
      expect(themeField, findsOneWidget);
      await tester.tap(themeField);
      await tester.pump();
      await tester.tap(find.text('dark').last);
      await tester.pump(const Duration(milliseconds: 250));
      expect(Theme.of(tester.element(themeField)).brightness, Brightness.dark);
      await tester.tap(
        find.byType(DropdownButtonFormField<PreferenceThemeMode>),
      );
      await tester.pump();
      await tester.tap(find.text('light').last);
      await tester.pump(const Duration(milliseconds: 250));
      expect(Theme.of(tester.element(themeField)).brightness, Brightness.light);

      // /sync remains reachable, but its injected read-only port is deliberately
      // not backed by OperationsSyncJob or the scope coordinator.
      final readOnlySync = composition.sync! as _ReadOnlySyncPort;
      await _visit(tester, router, '/sync', expectedText: 'Sincronización');
      expect(
        readOnlySync.retries,
        0,
        reason: 'read-only navigation must not dispatch a sync retry',
      );

      // Explicit offline restore keeps the same local database and drops only
      // the network client; reconnecting performs real ERP2 reads again.
      await container
          .read(authControllerProvider.notifier)
          .restore(offline: true);
      await tester.pump(const Duration(milliseconds: 250));
      expect(
        container.read(authControllerProvider).status,
        AuthControllerStatus.restored,
      );
      expect(runtime.active?.client, isNull);
      final offlineRouter = container.read(orbiRouterProvider);
      await _visit(
        tester,
        offlineRouter,
        '/settings',
        expectedText: 'Configuración',
      );

      await container.read(authControllerProvider.notifier).restore();
      await tester.pump(const Duration(milliseconds: 500));
      expect(
        container.read(authControllerProvider).status,
        AuthControllerStatus.restored,
      );
      expect(runtime.active?.client, isNotNull);
    },
  );
}

Future<void> _visit(
  WidgetTester tester,
  GoRouter router,
  String path, {
  required String expectedText,
}) async {
  router.go(path);
  // Screens backed by live ERP2 reads may legitimately remain loading; the
  // route assertion is immediate and the text check only needs a bounded
  // native frame window, never an unbounded pumpAndSettle.
  for (var i = 0; i < 8; i++) {
    await tester.pump(const Duration(milliseconds: 125));
  }
  expect(router.state.uri.path, path);
  expect(find.textContaining(expectedText), findsWidgets);
}

String _required(Map<String, String> env, String key) {
  final value = env[key]?.trim() ?? '';
  if (value.isEmpty) {
    fail('Missing secure test environment variable: $key');
  }
  return value;
}

String _requiredErp2Server(Map<String, String> env) {
  final value = _required(env, 'ORBI_ERP2_SERVER_URL');
  if (value != 'https://erp2.tecnosmart.com.ec') {
    fail(
      'Read-only native acceptance requires the exact ERP2 host '
      'https://erp2.tecnosmart.com.ec; newerp and alternate hosts are refused.',
    );
  }
  return value;
}

int _positiveInt(String? raw) {
  final value = int.tryParse(raw ?? '');
  if (value == null || value <= 0) {
    fail('Missing valid secure test environment user ID');
  }
  return value;
}

final class _ReadOnlyErp2AuthService implements AuthServicePort {
  _ReadOnlyErp2AuthService({
    required this.runtime,
    required this.scope,
    required this.apiKey,
    required this.profile,
    required this.capabilities,
  });

  final SessionRuntime runtime;
  final AppScope scope;
  final String apiKey;
  AuthProfile profile;
  CapabilitySnapshot capabilities;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) => restore();

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async {
    final activation = offline
        ? await runtime.activate(scope)
        : await runtime.activate(scope, apiKey: apiKey);
    if (!offline) {
      final client = activation.client;
      if (client == null) throw StateError('ERP2 restore has no client');
      final identity = await OdooActiveIdentityReader(client).read(scope);
      capabilities = await OdooCapabilityReader(client).read(
        scope: scope,
        companyId: identity.companyId,
        revision: DateTime.now().millisecondsSinceEpoch,
      );
      profile = AuthProfile(
        serverUrl: profile.serverUrl,
        database: profile.database,
        login: profile.login,
        userId: profile.userId,
        installationId: profile.installationId,
        credentialReference: profile.credentialReference,
        companyId: identity.companyId,
        allowedCompanyIds: identity.allowedCompanyIds,
      );
    }
    return AuthServiceResult(
      status: AuthServiceStatus.restored,
      scope: scope,
      profile: profile,
      capabilities: capabilities,
    );
  }

  @override
  Future<AuthProfile?> loadProfile() async => profile;

  @override
  Future<AuthProfile?> loadProfileFor(String serverUrl, String database) async {
    if (serverUrl == profile.serverUrl && database == profile.database) {
      return profile;
    }
    return null;
  }

  @override
  Future<void> close() => runtime.close();
}

/// Test-only sync surface for the non-mutating native pass.
///
/// This is intentionally not a coordinator: the route must not start the
/// production OperationsSyncJob merely because a reviewer opens /sync.
final class _ReadOnlySyncPort implements SyncCenterPort {
  _ReadOnlySyncPort() : _snapshot = SyncCenterSnapshot(sync: SyncSnapshot());

  final SyncCenterSnapshot _snapshot;
  var retries = 0;

  @override
  SyncCenterSnapshot get snapshot => _snapshot;

  @override
  Stream<SyncCenterSnapshot> get snapshots => const Stream.empty();

  @override
  Future<void> retry() async => retries++;
}
