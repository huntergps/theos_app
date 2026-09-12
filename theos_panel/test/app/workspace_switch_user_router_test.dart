import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

/// Same server/database, different `userId` per login — exactly what two
/// people sharing one Workspace device look like. `AppScope.scopeKey`
/// includes `userId` (see `orbi_runtime/lib/src/contracts.dart`), which is
/// what makes `RuntimeDatabaseOwner` open a physically different database
/// per user — proven directly, with a real runtime and a real queued
/// operation, in `workspace_switch_user_queue_isolation_test.dart`. This
/// test instead proves the piece that guarantee depends on: that the
/// shell's "cambiar de usuario" really tears down A's identity — with
/// confirmation — before B can ever authenticate, exactly like every other
/// authenticated route in this suite (`router_auth_test.dart`), so it
/// deliberately does not attach a real [SessionRuntime]: one that never
/// resolves a real `client` can still schedule catalog/sync watchers that
/// never quiesce, hanging `pumpAndSettle`.
AppScope _scopeFor(String login) => AppScope(
  appId: 'orbi-panel',
  installationId: 'switch-user-router-test',
  normalizedServerUrl: 'https://erp.test',
  database: 'orbi_demo',
  userId: login == 'erik' ? 11 : 22,
);

final class _SwitchableAuth implements AuthServicePort {
  int closeCalls = 0;
  final List<String> logins = [];

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async {
    logins.add(login);
    final scope = _scopeFor(login);
    return AuthServiceResult(
      status: AuthServiceStatus.authenticated,
      scope: scope,
      profile: AuthProfile(
        serverUrl: serverUrl,
        database: database,
        login: login,
        userId: scope.userId,
        installationId: scope.installationId,
        credentialReference: 'ref-$login',
      ),
      capabilities: CapabilitySnapshot(
        scopeKey: scope.scopeKey,
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026),
        permissions: const ['seller'],
      ),
    );
  }

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
  Future<void> close() async => closeCalls++;
}

void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'cambiar de usuario desde el shell pide confirmación, explica qué pasa '
    'con el trabajo pendiente, y cierra la identidad de A antes de que B '
    'pueda autenticarse — sin reutilizar el perfil de A para B',
    (tester) async {
      final auth = _SwitchableAuth();
      final preferences = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(auth),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: 'https://erp.test',
            database: 'orbi_demo',
            login: 'erik',
            password: 'secret',
          );

      // Ventana ancha a propósito: por debajo de 840 el panel de navegación
      // se esconde tras la hamburguesa, así que las acciones de sesión quedan
      // fuera de pantalla. Esta prueba es sobre cambiar de usuario, no sobre
      // el comportamiento en estrecho, que ya tiene la suya en el marco.
      await tester.binding.setSurfaceSize(const Size(1440, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final router = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('switch-user-button')), findsOneWidget);

      // Cancelling the confirmation must not touch anything.
      await tester.tap(find.byKey(const Key('switch-user-button')));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('nunca se envían ni se muestran'),
        findsOneWidget,
        reason: 'the dialog must explain what happens to pending work',
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      expect(auth.closeCalls, 0);
      expect(router.state.uri.path, '/');
      expect(container.read(authControllerProvider).profile?.login, 'erik');

      // Confirming does close A's identity before showing the login screen.
      await tester.tap(find.byKey(const Key('switch-user-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('confirm-switch-user-button')));
      await tester.pumpAndSettle();

      expect(
        auth.closeCalls,
        1,
        reason: "A's session must be closed before B can log in",
      );
      expect(container.read(authControllerProvider).profile, isNull);
      // `orbiRouterProvider` bakes the auth snapshot into the `GoRouter` it
      // builds (see the other scenarios in `router_auth_test.dart`), so the
      // now-stale `router` reference still thinks A is authenticated. Read
      // it again to get the router that reflects the just-closed session,
      // exactly like every other authenticated->unauthenticated transition
      // in this suite.
      final loggedOutRouter = container.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: FluentApp.router(routerConfig: loggedOutRouter),
        ),
      );
      await tester.pumpAndSettle();
      expect(loggedOutRouter.state.uri.path, '/login');

      // B logs in. The switch never reused A's identity for B.
      await container
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: 'https://erp.test',
            database: 'orbi_demo',
            login: 'maria',
            password: 'secret',
          );
      expect(container.read(authControllerProvider).profile?.login, 'maria');
      expect(
        container.read(authControllerProvider).profile?.userId,
        isNot(_scopeFor('erik').userId),
      );
    },
  );
}
