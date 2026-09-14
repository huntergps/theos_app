import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/bootstrap.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

/// Este fichero retira el puente de sesión web por cookie de
/// `WebSessionAuthService` (`bootstrap.dart`). No reproduce un defecto que el
/// dueño haya visto en pantalla: aclarado por él el 12-sep-2026, «Aldas Romero
/// Erik Andres» es el nombre de la EMPRESA en ERP2 (existe además el usuario
/// `erik.aldas`), y la cabecera mostró siempre, correctamente, la compañía de
/// `carlos.guajala` — no hubo identidad cruzada en pantalla.
///
/// Lo que sí motiva el cambio: el conector de sesión web por cookie
/// es **código muerto contra un servidor que ya no lo sirve** — retirado de
/// ERP2 y de Mepriga por decisión del dueño (Orbi web vive sólo en
/// `orbi.galapagos.tech`; 404 medido en los dos). Mantenerlo no era inerte:
/// era un segundo canal de credencial (la cookie HttpOnly, junto a la API key
/// propia) que `close()` nunca invalidaba, y que en principio podía discrepar
/// de una sesión ya activa si algo volvía a llamar `restore()` — un riesgo
/// latente, nunca observado, que ya no puede materializarse sin servidor que
/// lo alimente. `WebSessionAuthService.restore()` ya no lo intenta — ver el
/// docstring de esa clase en `bootstrap.dart`. Lo que queda son las dos
/// pruebas de abajo, sobre el camino que sí sigue vivo: la credencial propia
/// guardada.
void main() {
  setUpAll(() => SharedPreferences.setMockInitialValues({}));

  // ---------------------------------------------------------------------
  // El camino real de arranque en frío (`restoreOnce()`, `bootstrap.dart`),
  // no una llamada a `restore()` hecha a mano.
  //
  // 🔴 **No pude ejecutar el antiguo camino de cookie tal cual en este
  // arnés**, ni antes ni ahora que ya no existe. La primera línea de aquel
  // bloque era `baseUrl: Uri.base.origin`, y `Uri.origin` revienta con
  // cualquier esquema que no sea http/https — el propio comentario del
  // código lo decía. En `flutter test` sin `-p chrome`, `Uri.base` es un URI
  // `file://` (el directorio del paquete), así que esa línea truena ANTES de
  // intentar ninguna petición HTTP. No había ningún parámetro de prueba en
  // `WebSessionAuthService` para sustituir esa llamada de red (a diferencia
  // de `tokenClient`, que sí es inyectable) — reproducirlo de verdad habría
  // exigido `flutter test -p chrome` con un interceptor de red, que no
  // monté. Ahora que el código ya no tiene ese camino, esta prueba demuestra
  // sin matices lo que antes sólo podía demostrar a medias: el arranque en
  // frío con la credencial de B guardada recupera a B.
  test(
    'restoreOnce() con la credencial de B ya guardada recupera a B, nunca '
    'inventa a A',
    () async {
      final preferences = await SharedPreferences.getInstance();
      // Compartidos entre las dos instancias de `WebSessionAuthService` de
      // abajo, para modelar lo que sobrevive a una recarga real: las
      // `SharedPreferences` (localStorage) y el backend de credencial
      // durable (IndexedDB/WebCrypto, W04). Lo que NO se comparte —
      // `_profile` en memoria, el `SessionRuntime`— es precisamente lo que
      // una recarga de página también borra.
      final credentialBackend = _SharedCredentialBackend();
      final identity = _PerUserIdentity({
        _userIdA: _companyA,
        _userIdB: _companyB,
      });

      WebSessionAuthService buildService() => WebSessionAuthService(
        runtime: SessionRuntime(),
        installationIds: InstallationIdStore(
          _Installation(),
          generator: () => 'install-1',
        ),
        identityReader: identity,
        capabilityPort: _NullCapabilities(),
        preferences: preferences,
        credentialBackend: credentialBackend,
        apiKeyRuntimePort: _FakeSessionRuntimePort(),
        apiKeyIdentityProbe: (client) async =>
            (userId: _userIdB, login: 'carlos.guajala'),
      );

      // "Primera carga de página": B entra con su API key y queda guardado
      // de forma durable — exactamente lo que deja atrás un login real
      // antes de una recarga.
      final firstLoad = buildService();
      final loginResult = await firstLoad.loginWithApiKey(
        serverUrl: 'https://erp.test',
        database: 'orbi_demo',
        login: 'carlos.guajala',
        apiKey: 'key-b',
      );
      expect(loginResult.status, AuthServiceStatus.authenticated);
      expect(loginResult.profile?.login, 'carlos.guajala');

      // "Recarga de página": una instancia NUEVA (nada en memoria
      // sobrevive), las mismas `preferences` y el mismo backend de
      // credencial (lo durable sí sobrevive) — el mismo camino que
      // `_initializeApplication` corre de verdad al arrancar en frío.
      final reloaded = buildService();
      final result = await restoreOnce(reloaded);

      expect(
        result.profile?.login,
        isNot('erik.aldas'),
        reason:
            'un arranque en frío con la credencial de B guardada nunca '
            'debería resolver como A',
      );
      expect(result.profile?.login, 'carlos.guajala');
      expect(result.profile?.userId, _userIdB);
    },
  );

  // ---------------------------------------------------------------------
  // Lo que sí debe cumplirse hoy: con la credencial de B guardada,
  // `restore()` — en línea o sin conexión — siempre devuelve a B, porque ya
  // no hay dos caminos distintos que puedan discrepar entre sí.
  //
  // 🔴 Contrato, no observación directa de red: este arnés no puede probar
  // que `restore()` en línea deja de INTENTAR una petición de cookie —
  // no hay forma de inyectar esa llamada (ver el docstring de la prueba de
  // arriba). Lo que sí verifiqué, estáticamente, es que el código fuente de
  // `bootstrap.dart` ya no menciona ni la ruta retirada ni la referencia de
  // credencial que usaba (cero coincidencias buscando esas dos cadenas).
  // Lo que esta prueba demuestra en cambio es la consecuencia observable de
  // haberlo quitado: `restore()` en línea y `restore(offline: true)` ya no
  // pueden divergir, porque los dos terminan en la misma llamada a
  // `_restoreFromStoredCredential`.
  test(
    'restore() en línea y sin conexión dan la misma identidad: ya no hay '
    'un camino de cookie aparte que pueda discrepar',
    () async {
      final preferences = await SharedPreferences.getInstance();
      final credentialBackend = _SharedCredentialBackend();
      final identity = _PerUserIdentity({_userIdB: _companyB});

      WebSessionAuthService buildService() => WebSessionAuthService(
        runtime: SessionRuntime(),
        installationIds: InstallationIdStore(
          _Installation(),
          generator: () => 'install-1',
        ),
        identityReader: identity,
        capabilityPort: _NullCapabilities(),
        preferences: preferences,
        credentialBackend: credentialBackend,
        apiKeyRuntimePort: _FakeSessionRuntimePort(),
        apiKeyIdentityProbe: (client) async =>
            (userId: _userIdB, login: 'carlos.guajala'),
      );

      await buildService().loginWithApiKey(
        serverUrl: 'https://erp.test',
        database: 'orbi_demo',
        login: 'carlos.guajala',
        apiKey: 'key-b',
      );

      final online = await buildService().restore();
      final offlineResult = await buildService().restore(offline: true);

      for (final result in [online, offlineResult]) {
        expect(result.profile?.login, 'carlos.guajala');
        expect(result.profile?.userId, _userIdB);
        expect(result.profile?.companyName, _companyB);
      }
    },
  );
}

const _companyA = 'Aldas Romero Erik Andres';
const _companyB = 'Guajala Carlos';
const _userIdA = 11;
const _userIdB = 22;

// ---------------------------------------------------------------------
// Piezas de apoyo contra el `WebSessionAuthService` real (mismo patrón que
// `test/app/web_session_auth_service_test.dart`).

class _Installation implements InstallationIdBackend {
  final values = <String, String>{};
  @override
  Future<String?> read(String key) async => values[key];
  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

/// Igual que hace Odoo de verdad: leer `res.users` para `scope.userId`
/// trae la compañía de ESE usuario — nunca la de otro.
class _PerUserIdentity implements ActiveIdentityReader {
  final Map<int, String> companyNameByUserId;
  _PerUserIdentity(this.companyNameByUserId);
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
    companyId: scope.userId,
    companyName: companyNameByUserId[scope.userId],
    name: null,
    allowedCompanyIds: [scope.userId],
    lang: null,
    tz: null,
  );
}

class _NullCapabilities implements CapabilitySnapshotPort {
  @override
  Future<CapabilitySnapshot?> refresh(AppScope scope, int companyId) async =>
      null;
  @override
  Future<CapabilitySnapshot?> offline(AppScope scope, int companyId) async =>
      null;
}

/// El mismo asiento que ya usa `web_session_auth_service_test.dart` para no
/// abrir un Drift real (necesita `path_provider`, no disponible en un
/// `test()` a secas).
class _FakeSessionRuntimePort implements SessionRuntimePort {
  @override
  Future<void> activate(AppScope scope, {String? apiKey}) async {}
  @override
  Future<void> close() async {}
  @override
  void applyUserLocale({String? language, String? timezone}) {}
}

/// Un backend durable de mentira: un `Map` que SOBREVIVE entre las dos
/// instancias de `WebSessionAuthService` de la prueba, para modelar lo que
/// de verdad sobrevive a una recarga de página (IndexedDB/WebCrypto, W04) —
/// a diferencia del backend en memoria privado de `bootstrap.dart`, que
/// muere con la instancia.
class _SharedCredentialBackend implements CredentialBackend {
  final Map<String, String> store = {};
  @override
  Future<void> write(String key, String value) async => store[key] = value;
  @override
  Future<String?> read(String key) async => store[key];
  @override
  Future<void> delete(String key) async => store.remove(key);
}
