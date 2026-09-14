// Auditoría de router+login, 14-sep-2026 (encargo del dueño). Reporte
// original, verbatim:
//
// 1. Encendió «Guardar clave» y pulsó «Iniciar sesión».
// 2. Mientras decía «Conectando…», el interruptor apareció apagado.
// 3. Entró. Cerró sesión.
// 4. La clave no estaba, y el campo Usuario mostraba «soleda.jinez» en vez
//    de «soledad.jinez», que fue lo que escribió.
//
// Causa raíz (dos bugs independientes, ambos en este archivo/login_screen):
//
// A. `orbiRouterProvider` hacía `ref.watch(authControllerProvider)` en la
//    raíz del propio provider, así que CUALQUIER cambio de sesión —incluido
//    el primer `state = loading` de `AuthNotifier.login()`— reconstruía TODO
//    el `GoRouter`, tirando abajo la pantalla de acceso a mitad de un envío
//    (`_LoginScreenState` nueva, `_saveCredential` vuelto a `false`).
// B. `login_screen.dart` guardaba el usuario en `LoginPreferencesStore`
//    desde el debounce de `onChanged` (a medio teclear), y el guardado
//    correcto al terminar dependía de `if (!mounted) return;` — que el bug A
//    disparaba antes de que corriera.
//
// Estas pruebas fijan el contrato de la corrección de los dos. Cada una
// debe salir ROJA contra el commit 4638255 (sin la corrección) y VERDE
// después de aplicarla.
import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/orbi_app.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/login_preferences.dart';
import 'package:theos_panel/features/auth/login_screen.dart';
import 'package:theos_panel/features/auth/saved_servers.dart';

/// Un login que nunca resuelve hasta que la prueba complete [gate] a mano —
/// deja el formulario congelado en «Conectando…» el tiempo que haga falta
/// para inspeccionarlo a mitad de envío.
final class _GatedAuthService
    implements AuthServicePort, CredentialPolicyAuthServicePort {
  final gate = Completer<AuthServiceResult>();

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
    bool persistCredential = true,
  }) => gate.future;

  @override
  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
    bool persistCredential = true,
  }) => gate.future;

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

/// Nunca resuelve — usada por la prueba (d), donde ni siquiera se pulsa
/// «Iniciar sesión».
final class _NeverUsedAuthService implements AuthServicePort {
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
  Future<AuthProfile?> loadProfile() async => null;

  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => null;

  @override
  Future<void> close() async {}
}

/// Avanza un puñado de frames sin exigir que la app quede "quieta" — a
/// diferencia de `pumpAndSettle`, que nunca termina mientras el `ProgressRing`
/// de "Conectando…" siga en pantalla (su animación es indeterminada, no deja
/// de programar frames nuevos).
Future<void> _pumpAFew(WidgetTester tester, [int times = 10]) async {
  for (var i = 0; i < times; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

SavedServer _testServer() => SavedServer(
  id: 'erp',
  name: 'ERP de prueba',
  url: 'https://erp.test',
  database: 'db',
);

const _successProfile = AuthProfile(
  serverUrl: 'https://erp.test',
  database: 'db',
  login: 'soledad.jinez',
  userId: 5,
  installationId: 'installation',
  credentialReference: 'api-key',
);

Future<SharedPreferences> _preferencesWithSavedServer() async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await SavedServersStore(preferences).upsert(_testServer());
  return preferences;
}

void main() {
  testWidgets(
    'a: el router no reconstruye la pantalla de acceso mientras dice '
    '«Conectando…» — el interruptor "Guardar clave" sigue encendido',
    (tester) async {
      final preferences = await _preferencesWithSavedServer();
      final authService = _GatedAuthService();
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
      await tester.pumpAndSettle();

      final loginElementBefore = find.byType(LoginScreen).evaluate().single;

      await tester.tap(find.byType(ComboBox<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_testServer().name));
      await tester.pumpAndSettle();

      final fields = find.byType(TextBox);
      await tester.enterText(fields.at(0), 'soledad.jinez');
      await tester.enterText(fields.at(1), 'secret');

      final saveToggle = find.byKey(const Key('save-credential-toggle'));
      await tester.ensureVisible(saveToggle);
      await tester.tap(saveToggle);
      await tester.pump();
      expect(
        tester.widget<ToggleSwitch>(saveToggle).checked,
        isTrue,
        reason: 'El interruptor no se encendió al tocarlo.',
      );

      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await _pumpAFew(tester);

      // Todavía "Conectando…": el login está atascado en `gate`, sin resolver.
      expect(
        find.text('Conectando…'),
        findsOneWidget,
        reason:
            'El envío no llegó a quedar "en curso" — la prueba no está '
            'midiendo lo que dice medir.',
      );
      expect(
        identical(find.byType(LoginScreen).evaluate().single, loginElementBefore),
        isTrue,
        reason:
            'El router recreó la pantalla de acceso a mitad del envío '
            '(bug A: orbiRouterProvider reconstruía el GoRouter completo '
            'con cada cambio de authControllerProvider).',
      );
      expect(
        tester.widget<ToggleSwitch>(saveToggle).checked,
        isTrue,
        reason:
            'El interruptor "Guardar clave" se apagó solo: la pantalla se '
            'reconstruyó desde cero (mismo bug A, reporte textual del '
            'dueño: "mientras decía Conectando…, el interruptor apareció '
            'apagado").',
      );

      authService.gate.complete(
        const AuthServiceResult(
          status: AuthServiceStatus.authenticated,
          profile: _successProfile,
        ),
      );
      await _pumpAFew(tester);
    },
  );

  testWidgets(
    'b: tras un login exitoso se guarda el usuario tal como se tecleó al '
    'enviar, nunca uno a medias que quedó de un debounce anterior',
    (tester) async {
      final preferences = await _preferencesWithSavedServer();
      final authService = _GatedAuthService();
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
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ComboBox<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_testServer().name));
      await tester.pumpAndSettle();

      final fields = find.byType(TextBox);
      // Escribe el usuario incompleto y deja pasar el debounce (400ms) —
      // en el código con el bug esto queda grabado en LoginPreferencesStore.
      await tester.enterText(fields.at(0), 'soleda.jinez');
      await tester.pump(const Duration(milliseconds: 450));
      // Corrige de inmediato y envía sin esperar otro debounce.
      await tester.enterText(fields.at(0), 'soledad.jinez');
      await tester.enterText(fields.at(1), 'secret');

      await tester.ensureVisible(find.text('Iniciar sesión'));
      await tester.tap(find.text('Iniciar sesión'));
      await _pumpAFew(tester);

      authService.gate.complete(
        const AuthServiceResult(
          status: AuthServiceStatus.authenticated,
          profile: _successProfile,
        ),
      );
      await _pumpAFew(tester);

      expect(
        LoginPreferencesStore(preferences).load().login,
        'soledad.jinez',
        reason:
            'Quedó guardado el usuario a medias ("soleda.jinez") en vez '
            'del que realmente se envió a entrar.',
      );
    },
  );

  testWidgets(
    'c: una revisión de capacidades que no cierra la sesión no devuelve al '
    'inicio — la ruta interna sigue siendo la misma',
    (tester) async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      const profile = AuthProfile(
        serverUrl: 'https://erp.test',
        database: 'demo',
        login: 'bodega-1',
        userId: 9,
        installationId: 'i-1',
        credentialReference: 'api-key',
        companyId: 1,
      );
      CapabilitySnapshot capabilitiesAt(int revision) => CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: revision,
        fetchedAt: DateTime.utc(2026, 9, 14, revision),
        permissions: const ['envases_read'],
      );
      final overrides = [
        authInitialStateProvider.overrideWithValue(
          AuthViewState(
            status: AuthControllerStatus.authenticated,
            profile: profile,
            capabilities: capabilitiesAt(1),
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ];
      final container = ProviderContainer(overrides: overrides);
      addTearDown(container.dispose);
      // `OrbiApp`, no un `FluentApp.router(routerConfig: router)` fijo: el
      // bug real está en `OrbiApp.build()`, que hace
      // `routerConfig: ref.watch(orbiRouterProvider)` — un router leído UNA
      // vez con `container.read` y pasado como valor estático nunca lo
      // ejercita, sin importar qué tan roto esté `orbiRouterProvider`.
      await tester.pumpWidget(
        UncontrolledProviderScope(container: container, child: const OrbiApp()),
      );
      await tester.pumpAndSettle();

      container.read(orbiRouterProvider).go('/envases/por-recibir');
      await tester.pumpAndSettle();
      expect(
        container.read(orbiRouterProvider).state.uri.path,
        '/envases/por-recibir',
      );

      // Una revisión de capacidades: MISMOS permisos, otra instancia (otra
      // `revision`/`fetchedAt`) — exactamente lo que un refresco de
      // capacidades en caliente produce, sin cerrar la sesión (el `status`
      // sigue `authenticated`).
      container.updateOverrides([
        authInitialStateProvider.overrideWithValue(
          AuthViewState(
            status: AuthControllerStatus.authenticated,
            profile: profile,
            capabilities: capabilitiesAt(2),
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ]);
      await tester.pumpAndSettle();

      expect(
        container.read(orbiRouterProvider).state.uri.path,
        '/envases/por-recibir',
        reason:
            'La revisión de capacidades devolvió la navegación a Inicio '
            '(bug A: cualquier cambio de authControllerProvider recreaba '
            'el GoRouter, reiniciando la navegación).',
      );
    },
  );

  testWidgets(
    'd: escribir en Usuario sin pulsar Iniciar sesión no escribe en '
    'LoginPreferencesStore',
    (tester) async {
      final preferences = await _preferencesWithSavedServer();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(_NeverUsedAuthService()),
            sharedPreferencesProvider.overrideWithValue(preferences),
          ],
          child: FluentApp(home: const LoginScreen()),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(ComboBox<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text(_testServer().name));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextBox).at(0), 'nunca-envio');
      // De sobra por encima del debounce de 400ms.
      await tester.pump(const Duration(milliseconds: 600));

      expect(
        LoginPreferencesStore(preferences).load().login,
        isEmpty,
        reason:
            'Teclear sin enviar dejó guardado un usuario en '
            'LoginPreferencesStore.',
      );
    },
  );
}
