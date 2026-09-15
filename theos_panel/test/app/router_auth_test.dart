import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/app/orbi_app.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/login_screen.dart';
import 'package:theos_panel/features/auth/saved_servers.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class _Auth implements AuthServicePort {
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => AuthServiceResult(
    status: AuthServiceStatus.authenticated,
    // Carries a real profile matching (serverUrl, database) so anything
    // that keys off the ACTIVE identity — `serverFeaturesProvider`
    // included, 14-sep-2026 — has something coherent to read. Before this,
    // the fake authenticated with `profile: null`, which is not a shape
    // the real app ever produces (login always returns both together).
    profile: AuthProfile(
      serverUrl: serverUrl,
      database: database,
      login: login,
      userId: 1,
      installationId: 'router-auth-test',
      credentialReference: 'api-key',
    ),
  );
  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthProfile?> loadProfile() async => null;
  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => null;
  @override
  Future<void> close() async {}
}

final class _ProfileDuringLoginAuth implements AuthServicePort {
  static const profile = AuthProfile(
    serverUrl: 'https://saved.test',
    database: 'saved_db',
    login: 'saved_user',
    userId: 7,
    installationId: 'installation',
    credentialReference: 'api-key',
  );
  final profileReady = Completer<AuthProfile?>();

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthProfile?> loadProfile() => profileReady.future;
  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => null;
  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  testWidgets(
    'unauthenticated direct access redirects to login and safe returnTo',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_Auth()),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      router.go('/collection');
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/login');
      expect(router.state.uri.queryParameters['returnTo'], '/collection');
    },
  );

  testWidgets('bootstrap router keeps login stable while profile loads', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    // Seed a saved server that matches the remembered profile below, so
    // LoginScreen's initState codepath (`_findServer` + `setState`) actually
    // runs once `loadProfile()` resolves, instead of finding no match and
    // doing nothing. That `setState` mid-typing is exactly what this test
    // guards: it must not tear down the login form or clobber user input.
    await tester.runAsync(
      () => SavedServersStore(preferences).upsert(
        SavedServer(
          id: 'saved',
          name: 'Guardado',
          url: _ProfileDuringLoginAuth.profile.serverUrl,
          database: _ProfileDuringLoginAuth.profile.database,
        ),
      ),
    );
    final authService = _ProfileDuringLoginAuth();
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(authService),
          authInitialStateProvider.overrideWithValue(
            const AuthViewState(status: AuthControllerStatus.required),
          ),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
        child: const OrbiApp(),
      ),
    );
    await tester.pump();
    final loginElement = find.byType(LoginScreen).evaluate().single;
    // En Fluent la etiqueta va FUERA del campo, en un `InfoLabel`, así que
    // buscarlo «por su etiqueta» ya no encuentra nada: el campo no contiene
    // ese texto. Se busca por posición, que es lo que hace también
    // test/features/auth/login_screen_test.dart desde la migración.
    final usuarioField = find.byType(TextBox).at(0);
    final passwordField = find.byType(TextBox).at(1);
    final loginController = tester.widget<TextBox>(usuarioField).controller;
    await tester.tap(usuarioField);
    const login = 'alice';
    for (var index = 1; index <= login.length; index++) {
      await tester.enterText(usuarioField, login.substring(0, index));
      await tester.pump(const Duration(milliseconds: 20));
      if (index == 3) {
        authService.profileReady.complete(_ProfileDuringLoginAuth.profile);
        await tester.pump();
      }
    }
    expect(
      identical(find.byType(LoginScreen).evaluate().single, loginElement),
      isTrue,
    );
    expect(
      identical(
        tester.widget<TextBox>(usuarioField).controller,
        loginController,
      ),
      isTrue,
    );
    // The user's own typing wins over the just-loaded remembered login: the
    // background profile load must not overwrite what is already on screen.
    expect(tester.widget<TextBox>(usuarioField).controller?.text, login);
    await tester.ensureVisible(passwordField);
    await tester.tap(passwordField);
    await tester.enterText(passwordField, 'password');
    expect(tester.widget<TextBox>(passwordField).focusNode?.hasFocus, isTrue);
    expect(tester.widget<TextBox>(passwordField).controller?.text, 'password');
  });

  testWidgets(
    'authenticated routes and menu policy deny unauthorized collection',
    (tester) async {
      final capabilities = CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime(2026),
        permissions: const ['seller'],
      );
      // `RouteAccessPolicy` now also asks `ServerFeatures` for `/sales`
      // (14-sep-2026, «theos_panel debe ser universal»): with nothing
      // probed yet it reads `unknown`, and `unknown` enables nothing. This
      // test is about the SELLER PERMISSION reaching `/sales`, not about
      // server evidence, so it seeds the cache as if `sale.order` was
      // already confirmed — the erp.test/db pair the `.login(...)` call
      // below actually establishes as the active profile.
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(
        serverFeaturesPrefsKey('https://erp.test', 'db'),
        ServerFeatures.empty
            .withState(
              ServerFeature.sales,
              ServerFeatureState.available,
              DateTime.utc(2026),
            )
            .toJson(),
      );
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_Auth()),
          capabilitySnapshotProvider.overrideWithValue(capabilities),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      await container
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: 'https://erp.test',
            database: 'db',
            login: 'seller',
            password: 'secret',
          );
      final authenticatedRouter = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(routerConfig: authenticatedRouter),
        ),
      );
      await tester.pumpAndSettle();
      authenticatedRouter.go('/collection');
      await tester.pumpAndSettle();
      expect(authenticatedRouter.state.uri.path, '/');
      authenticatedRouter.go('/sales');
      await tester.pumpAndSettle();
      expect(authenticatedRouter.state.uri.path, '/sales');
    },
  );

  testWidgets('approvals route requires effective approver capability', (
    tester,
  ) async {
    final capabilities = CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime(2026),
      permissions: const ['approver'],
    );
    // Same reason as the `/sales` test above: `/approvals` now also asks
    // `ServerFeatures`, so this seeds `approval.request` as already
    // confirmed — this test is about the APPROVER capability, not about
    // whether the server has Enterprise approvals installed.
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      serverFeaturesPrefsKey('https://erp.test', 'db'),
      ServerFeatures.empty
          .withState(
            ServerFeature.approvals,
            ServerFeatureState.available,
            DateTime.utc(2026),
          )
          .toJson(),
    );
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_Auth()),
        capabilitySnapshotProvider.overrideWithValue(capabilities),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(orbiRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: FluentApp.router(routerConfig: router),
      ),
    );
    await container
        .read(authControllerProvider.notifier)
        .login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'approver',
          password: 'secret',
        );
    await tester.pumpAndSettle();
    final authenticatedRouter = container.read(orbiRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: FluentApp.router(routerConfig: authenticatedRouter),
      ),
    );
    await tester.pumpAndSettle();
    authenticatedRouter.go('/approvals');
    await tester.pumpAndSettle();
    expect(authenticatedRouter.state.uri.path, '/approvals');
    expect(find.text('No hay aprobaciones pendientes'), findsOneWidget);
  });

  testWidgets(
    'any authenticated user enters the sync area, even without sales or cash capabilities',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(_Auth()),
          capabilitySnapshotProvider.overrideWithValue(
            CapabilitySnapshot(
              scopeKey: 'scope',
              companyId: 1,
              revision: 1,
              fetchedAt: DateTime(2026),
              // Sólo bodega: aun así ve su sincronización y su Modo Ruta.
              permissions: const ['warehouse'],
            ),
          ),
          sharedPreferencesProvider.overrideWithValue(
            await SharedPreferences.getInstance(),
          ),
        ],
      );
      addTearDown(container.dispose);
      final router = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(routerConfig: router),
        ),
      );
      await container
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: 'https://erp.test',
            database: 'db',
            login: 'warehouse',
            password: 'secret',
          );
      final authenticatedRouter = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(routerConfig: authenticatedRouter),
        ),
      );
      await tester.pumpAndSettle();
      authenticatedRouter.go('/sync');
      await tester.pumpAndSettle();
      expect(authenticatedRouter.state.uri.path, '/sync');
    },
  );

  testWidgets('synchronized administrator can enter sync route', (
    tester,
  ) async {
    final container = ProviderContainer(
      overrides: [
        authServiceProvider.overrideWithValue(_Auth()),
        capabilitySnapshotProvider.overrideWithValue(
          CapabilitySnapshot(
            scopeKey: 'scope',
            companyId: 1,
            revision: 1,
            fetchedAt: DateTime(2026),
            permissions: const ['administrator', 'sync'],
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(orbiRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: FluentApp.router(routerConfig: router),
      ),
    );
    await container
        .read(authControllerProvider.notifier)
        .login(
          serverUrl: 'https://erp.test',
          database: 'db',
          login: 'administrator',
          password: 'secret',
        );
    final authenticatedRouter = container.read(orbiRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: FluentApp.router(routerConfig: authenticatedRouter),
      ),
    );
    await tester.pumpAndSettle();
    authenticatedRouter.go('/sync');
    await tester.pumpAndSettle();
    expect(authenticatedRouter.state.uri.path, '/sync');
  });
}
