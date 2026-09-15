import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/workspace_unlock_store.dart';
import 'package:theos_panel/features/security/inactivity_lock_controller.dart';

// Contra 326010e, `WorkspaceLockNotifier.build()` observaba
// `authControllerProvider` directamente: CUALQUIER cambio de ese estado —
// incluido un acceso interactivo recién exitoso, o un simple refresco de
// capacidades en medio de una sesión ya en uso — repetía la cuenta de
// "¿debe arrancar bloqueada?" contra la última interacción PERSISTIDA (que
// puede tener horas), bloqueando a alguien que acababa de demostrar quién
// es, o a mitad de una sesión que seguía en uso. Las pruebas de este
// archivo fallan contra ese commit por eso, no por un detalle de aserción.
void main() {
  const profile = AuthProfile(
    serverUrl: 'https://erp.test',
    database: 'demo',
    login: 'carlos.guajala',
    userId: 7,
    installationId: 'i-1',
    credentialReference: 'api-key',
    companyId: 1,
    companyName: 'Empresa Demo',
  );

  final scopeKey = workspaceUnlockScopeKeyFor(profile);

  CapabilitySnapshot capabilities({List<String> permissions = const []}) =>
      CapabilitySnapshot(
        scopeKey: 'scope',
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026, 9, 14),
        permissions: permissions,
      );

  test(
    'interactive login after a long absence does not start locked',
    () async {
      SharedPreferences.setMockInitialValues({
        inactivityLastInteractionKey(scopeKey): DateTime.now()
            .toUtc()
            .subtract(const Duration(hours: 20))
            .toIso8601String(),
      });
      final preferences = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          // Arranca sin sesión: el `login()` de más abajo es el ÚNICO
          // motivo por el que `authControllerProvider` cambia de valor, así
          // que el resultado nunca es `identical` al que instaló
          // `authInitialStateProvider` — exactamente la señal que debe
          // leerse como "acceso interactivo", sin importar qué status
          // reporte.
          authInitialStateProvider.overrideWithValue(const AuthViewState()),
          sharedPreferencesProvider.overrideWithValue(preferences),
          authServiceProvider.overrideWithValue(
            _FakeAuthService(
              loginResult: AuthServiceResult(
                status: AuthServiceStatus.authenticated,
                profile: profile,
                capabilities: capabilities(),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(authControllerProvider.notifier)
          .login(
            serverUrl: profile.serverUrl,
            database: profile.database,
            login: profile.login,
            password: 'whatever it was',
            persistCredential: false,
          );

      expect(
        container.read(workspaceLockProvider),
        isFalse,
        reason: 'un acceso interactivo recién exitoso nunca arranca bloqueado',
      );
      expect(
        preferences.getBool('orbi/workspace/locked') ?? false,
        isFalse,
        reason: 'tampoco debe dejar el flag manual en true tras ese acceso',
      );
    },
  );

  test('pin login after a long absence does not start locked', () async {
    SharedPreferences.setMockInitialValues({
      inactivityLastInteractionKey(scopeKey): DateTime.now()
          .toUtc()
          .subtract(const Duration(hours: 20))
          .toIso8601String(),
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        authInitialStateProvider.overrideWithValue(const AuthViewState()),
        sharedPreferencesProvider.overrideWithValue(preferences),
        authServiceProvider.overrideWithValue(
          _FakeAuthService(
            // `restoreForSellerPin` reutiliza `restore()`, así que el PIN
            // también reporta `restored` — la MISMA etiqueta que un
            // reinicio silencioso de verdad. Es justo lo que este archivo
            // corrige: `identical(auth, initial)` distingue los dos casos,
            // el status por sí solo no puede.
            restoreResult: AuthServiceResult(
              status: AuthServiceStatus.restored,
              profile: profile,
              capabilities: capabilities(permissions: const ['seller']),
            ),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    await container.read(authControllerProvider.notifier).restoreForSellerPin();

    expect(
      container.read(authControllerProvider).status,
      AuthControllerStatus.restored,
      reason:
          'confirma que este PIN realmente pasa por el mismo status que un '
          'reinicio silencioso — si esto cambiara, la prueba dejaría de '
          'probar lo que dice probar',
    );
    expect(
      container.read(workspaceLockProvider),
      isFalse,
      reason: 'un PIN recién tecleado tampoco arranca bloqueado',
    );
    expect(preferences.getBool('orbi/workspace/locked') ?? false, isFalse);
  });

  test('restored session after the deadline still starts locked', () async {
    SharedPreferences.setMockInitialValues({
      inactivityLastInteractionKey(scopeKey): DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 20))
          .toIso8601String(),
      inactivityLockMinutesKey(scopeKey): 15,
    });
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        // El valor SIN TOCAR de `authInitialStateProvider`: nada llamó a
        // ningún método del notifier todavía, así que es exactamente lo
        // que `bootstrap.dart` habría instalado tras un `restoreOnce()`
        // silencioso — reabrir la pestaña o la app.
        authInitialStateProvider.overrideWithValue(
          AuthViewState(
            status: AuthControllerStatus.restored,
            profile: profile,
            capabilities: capabilities(),
          ),
        ),
        sharedPreferencesProvider.overrideWithValue(preferences),
      ],
    );
    addTearDown(container.dispose);

    expect(
      container.read(workspaceLockProvider),
      isTrue,
      reason: 'pasaron 20 min con un límite de 15: sí debe arrancar bloqueado',
    );
  });

  test('auth refresh during use does not re-lock', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final initialOverride = authInitialStateProvider.overrideWithValue(
      AuthViewState(
        status: AuthControllerStatus.authenticated,
        profile: profile,
        capabilities: capabilities(),
      ),
    );
    final overrides = [
      initialOverride,
      sharedPreferencesProvider.overrideWithValue(preferences),
    ];
    final container = ProviderContainer(overrides: overrides);
    addTearDown(container.dispose);

    // Primera lectura: sesión recién activada, sin interacción persistida
    // todavía — se resuelve sin bloquear, y de paso fija
    // `_evaluatedScopeKey` para este scope (esta es la "sesión en uso
    // desbloqueada" del enunciado).
    expect(container.read(workspaceLockProvider), isFalse);

    // Pasa el tiempo SIN que nadie toque nada: la última interacción
    // persistida queda a 16 minutos — más que el límite por omisión (15) —
    // simulando lo que `InactivityLockController` dejaría escrito si el
    // último toque real fue justo antes de una pausa larga.
    await preferences.setString(
      inactivityLastInteractionKey(scopeKey),
      DateTime.now()
          .toUtc()
          .subtract(const Duration(minutes: 16))
          .toIso8601String(),
    );

    // Refresco de capacidades EN LA MISMA sesión (mismo perfil/scope): no
    // pasa por `login()`/`restore()`, así que nunca hay un `state=loading`
    // de por medio — exactamente como un refresco real de
    // `authControllerProvider` que no es un acceso nuevo.
    overrides[0] = authInitialStateProvider.overrideWithValue(
      AuthViewState(
        status: AuthControllerStatus.authenticated,
        profile: profile,
        capabilities: capabilities(permissions: const ['seller']),
      ),
    );
    container.updateOverrides(overrides);

    expect(
      container.read(workspaceLockProvider),
      isFalse,
      reason:
          'un refresco de capacidades en medio de una sesión en uso no debe '
          're-evaluar el arranque bloqueado, así la interacción persistida '
          'ya esté "vencida"',
    );
  });
}

final class _FakeAuthService implements AuthServicePort {
  _FakeAuthService({this.loginResult, this.restoreResult});

  final AuthServiceResult? loginResult;
  final AuthServiceResult? restoreResult;

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async =>
      loginResult ?? const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      restoreResult ??
      const AuthServiceResult(status: AuthServiceStatus.required);

  @override
  Future<AuthProfile?> loadProfile() async => null;

  @override
  Future<AuthProfile?> loadProfileFor(String serverUrl, String database) async =>
      null;

  @override
  Future<void> close() async {}
}
