// Reproduce la falla reportada por el dueño (Orbi web, orbi.galapagos.tech,
// servidor Mepriga, usuaria soledad.jinez, 15-sep-2026): la sesión se bloqueó
// por inactividad («Sesión bloqueada») y, al recargar la página, Orbi mostró
// la PANTALLA DE ACCESO en vez de volver a «Sesión bloqueada» — con «Guardar
// clave» ACTIVADO en el login original, tras recargar el interruptor apareció
// APAGADO y sin «Clave guardada en este equipo».
//
// Esta prueba usa los componentes REALES (`NativeAuthService`, `restoreOnce`,
// `orbiRouterProvider`) con almacenes falsos que imitan cómo persiste el
// navegador: un `CredentialBackend` en memoria COMPARTIDO entre dos
// instancias de `NativeAuthService` (así se comporta un backend respaldado
// por IndexedDB — sobrevive a la recarga, a diferencia del heap de Dart) y
// las MISMAS `SharedPreferences` para las dos "sesiones". Nunca se simula un
// rechazo del servidor (401): el segundo `restore()` debe tener éxito con la
// misma llave que dejó la primera sesión.
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/app/router.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/auth/login_screen.dart';
import 'package:theos_panel/ui/layouts/workspace_lock_screen.dart';

/// Backend de credenciales en memoria, pero DELIBERADAMENTE compartido entre
/// dos `NativeAuthService` distintos — así es como persiste de verdad
/// `WebCryptoCredentialBackend` (IndexedDB) entre una recarga: los datos
/// sobreviven aunque el heap de Dart se reinicie por completo.
class _PersistentBackend implements CredentialBackend, InstallationIdBackend {
  final values = <String, String>{};

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> delete(String key) async => values.remove(key);
}

class _FakeBootstrap implements AuthBootstrapPort {
  @override
  Future<NativeAuthBootstrapResult> authenticateAndCreateApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
  }) async =>
      const NativeAuthBootstrapResult(userId: 7, apiKey: 'secret-key');

  @override
  Future<void> revokeApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
    required int apiKeyId,
  }) async {}

  @override
  Future<void> revokeOwnApiKey({
    required String baseUrl,
    required String database,
    required String apiKey,
  }) async {}

  @override
  Future<ApiKeyRenewalResult> generateApiKey({
    required String baseUrl,
    required String database,
    required String currentApiKey,
    required String name,
    required DateTime expirationDate,
  }) async => throw UnimplementedError();
}

class _FakeRuntime implements SessionRuntimePort {
  AppScope? active;

  @override
  Future<void> activate(AppScope scope, {String? apiKey}) async =>
      active = scope;

  @override
  Future<void> close() async => active = null;

  @override
  void applyUserLocale({String? language, String? timezone}) {}
}

/// Confirma la conexión "de verdad" en `restore()` — igual que hacen los
/// servicios de producción (ver el comentario de `NativeAuthService.restore`
/// sobre por qué un servicio sin `identityReader` nunca finge un RPC real).
/// Nunca lanza: no hay ningún rechazo del servidor que modelar en esta
/// prueba.
class _FakeIdentityReader implements ActiveIdentityReader {
  @override
  Future<
    ({
      int companyId,
      String? companyName,
      String? name,
      List<int> allowedCompanyIds,
      String? lang,
      String? tz,
    })
  >
  read(AppScope scope) async => (
    companyId: 1,
    companyName: 'Empresa Demo',
    name: 'Soledad Jinez',
    allowedCompanyIds: <int>[1],
    lang: null,
    tz: null,
  );
}

class _FakeCapabilityPort implements CapabilitySnapshotPort {
  @override
  Future<CapabilitySnapshot?> refresh(AppScope scope, int companyId) async =>
      CapabilitySnapshot(
        scopeKey: scope.scopeKey,
        companyId: companyId,
        revision: 1,
        fetchedAt: DateTime.utc(2026, 9, 15),
        permissions: const [],
      );

  @override
  Future<CapabilitySnapshot?> offline(AppScope scope, int companyId) =>
      refresh(scope, companyId);
}

NativeAuthService _buildService(
  _PersistentBackend backend,
  SharedPreferences preferences,
  SessionRuntimePort runtime,
) => NativeAuthService(
  bootstrapPort: _FakeBootstrap(),
  credentialStore: CredentialStore(
    backend,
    durability: CredentialDurability.secureStore,
  ),
  preferences: preferences,
  runtimePort: runtime,
  installationIds: InstallationIdStore(backend, generator: () => 'install-1'),
  identityReader: _FakeIdentityReader(),
  capabilityPort: _FakeCapabilityPort(),
);

void main() {
  testWidgets(
    'bloquear por inactividad con "Guardar clave" activado y recargar la '
    'página (mismos almacenes persistentes) debe volver a "Sesión '
    'bloqueada", conservando la llave y la bandera de recordada — no a la '
    'pantalla de acceso',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      // --- "Sesión 1": entra de forma interactiva con «Guardar clave» ON. --
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final backend = _PersistentBackend();
      final runtime1 = _FakeRuntime();
      final service1 = _buildService(backend, preferences, runtime1);
      final port1 = NativeAuthServicePort(service1);

      final container1 = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(port1),
          sharedPreferencesProvider.overrideWithValue(preferences),
        ],
      );
      addTearDown(container1.dispose);

      await container1.read(authControllerProvider.notifier).login(
        serverUrl: 'https://mepriga.test',
        database: 'mepriga',
        login: 'soledad.jinez',
        password: 'secret',
        persistCredential: true, // «Guardar clave» ACTIVADO
      );
      final loggedInState = container1.read(authControllerProvider);
      expect(loggedInState.status, AuthControllerStatus.authenticated);
      expect(await service1.hasStoredCredential(loggedInState.profile!), isTrue);

      // La llave y la bandera de "recordada" quedan en el backend
      // persistente ANTES de "bloquear" — confirma la premisa del reporte.
      expect(backend.values.values, contains('secret-key'));

      // --- Bloqueo por inactividad: el mismo mecanismo que
      // `InactivityLockController.onLock` dispara
      // (`ref.read(workspaceLockProvider.notifier).lock()`).
      container1.read(workspaceLockProvider.notifier).lock();
      // Deja constancia también directa, para no depender de que el
      // `unawaited()` interno de `lock()` ya haya terminado de escribir.
      await preferences.setBool('orbi/workspace/locked', true);

      // --- "Recargar la página": nada se cierra explícitamente (nunca se
      // llama a `close()`), sólo se descarta el contenedor — igual que un F5
      // destruye el heap de Dart pero no toca IndexedDB/SharedPreferences.
      container1.dispose();

      // --- "Sesión 2": arranque nuevo, mismos almacenes persistentes. ------
      final runtime2 = _FakeRuntime();
      final service2 = _buildService(backend, preferences, runtime2);
      final port2 = NativeAuthServicePort(service2);

      final restored = await restoreOnce(port2);

      // Primera aserción, la más directa: `restoreOnce` (el mismo helper que
      // usa `bootstrap.dart` en el arranque real) debe reactivar la sesión,
      // no devolver `required`.
      expect(
        restored.status,
        AuthServiceStatus.restored,
        reason:
            'restoreOnce() debió reactivar la sesión con la llave que dejó '
            'la sesión 1 — si esto es "required", la llave o la marca de '
            'sesión abierta se perdieron entre el bloqueo y la recarga.',
      );

      // La llave y la bandera de "recordada" deben SEGUIR en el backend
      // persistente tras la recarga.
      expect(
        backend.values.values,
        contains('secret-key'),
        reason: 'La llave desapareció del almacén persistente al recargar.',
      );
      expect(
        await service2.hasStoredCredential(restored.profile!),
        isTrue,
        reason:
            '"Clave guardada en este equipo" debería seguir ofreciéndose '
            'tras recargar: la bandera de recordada se perdió.',
      );

      final container2 = ProviderContainer(
        overrides: [
          authServiceProvider.overrideWithValue(port2),
          sharedPreferencesProvider.overrideWithValue(preferences),
          authInitialStateProvider.overrideWithValue(
            authViewStateFromResult(restored),
          ),
        ],
      );
      addTearDown(container2.dispose);
      final router = container2.read(orbiRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container2,
          child: FluentApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      // Segunda aserción, a nivel de router/pantalla — lo que el dueño vio
      // realmente en el navegador.
      expect(
        find.byType(WorkspaceLockScreen),
        findsOneWidget,
        reason:
            'Tras recargar con la sesión bloqueada, Orbi debe mostrar '
            '"Sesión bloqueada", no la pantalla de acceso.',
      );
      expect(find.byType(LoginScreen), findsNothing);
    },
  );
}
