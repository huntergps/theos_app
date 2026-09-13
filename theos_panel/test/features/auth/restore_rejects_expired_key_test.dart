// Contrato (auditoría de sesión, 13-sep-2026): reiniciar la app con una
// clave API ya vencida debe pedir credenciales de nuevo, nunca disfrazarse
// de "restaurado sin conexión".
//
// `restoreOnce` (theos_panel/lib/features/auth/auth_controller.dart) hace
// exactamente un intento en línea y, sólo si falla, un intento explícito sin
// conexión. Antes de este arreglo, el `catch` del intento en línea no
// distinguía "no hay red" de "el servidor respondió y rechazó la
// credencial" (`OdooAuthenticationException` — la misma excepción que
// `odoo_error_mapper.dart` lanza para un 401/403 real): cualquiera de las
// dos caía al mismo respaldo offline, que nunca toca la red y devuelve
// `restored` con lo que ya había en disco. Medido entonces: una clave
// vencida por completo producía el MISMO resultado para el operador que
// estar sin señal — la pantalla nunca pedía credenciales de nuevo.
//
// La regla ahora: un rechazo EXPLÍCITO del servidor resuelve en `required`
// directo. Cualquier OTRO error (sin red, timeout, DNS, servidor caído)
// sigue cayendo al respaldo offline exactamente como siempre — ahí sí tiene
// sentido seguir trabajando sin conexión hasta que vuelva la red.
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/auth/auth_controller.dart';

const _kRestoredProfile = AuthProfile(
  serverUrl: 'https://erp2.tecnosmart.com.ec',
  database: 'erp2_tecnosmart_com_ec',
  login: 'vendedor.auditoria',
  userId: 9,
  installationId: 'audit-install',
  credentialReference: 'api-key',
);

/// Modela el servidor rechazando la clave por caducidad: `restore()` en
/// línea revienta con la MISMA excepción que `odoo_error_mapper.dart`
/// produce para un 401/403 real; `restore(offline: true)` nunca toca la red,
/// así que tendría éxito con lo que ya había en disco SI llegara a
/// intentarse — el contrato es que no debe intentarse.
final class _ExpiredKeyAuthService implements AuthServicePort {
  var onlineAttempts = 0;
  var offlineAttempts = 0;

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async {
    if (!offline) {
      onlineAttempts++;
      throw const OdooSessionExpiredException();
    }
    offlineAttempts++;
    return const AuthServiceResult(
      status: AuthServiceStatus.restored,
      profile: _kRestoredProfile,
    );
  }

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) => throw UnimplementedError();

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

/// Modela la OTRA causa, la que SÍ debe seguir cayendo al respaldo offline:
/// un problema de transporte sin relación alguna con la credencial.
final class _NetworkDownAuthService implements AuthServicePort {
  var onlineAttempts = 0;
  var offlineAttempts = 0;

  @override
  Future<AuthServiceResult> restore({bool offline = false}) async {
    if (!offline) {
      onlineAttempts++;
      throw const OdooConnectionException('socket de red no disponible');
    }
    offlineAttempts++;
    return const AuthServiceResult(
      status: AuthServiceStatus.restored,
      profile: _kRestoredProfile,
    );
  }

  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) => throw UnimplementedError();

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

void main() {
  test(
    'una clave vencida (rechazo explícito del servidor) va directo a '
    'required — nunca al respaldo offline',
    () async {
      final service = _ExpiredKeyAuthService();

      final result = await restoreOnce(service);

      expect(service.onlineAttempts, 1);
      expect(
        service.offlineAttempts,
        0,
        reason:
            'un rechazo EXPLÍCITO del servidor no debe disparar el '
            'fallback ciego a offline=true.',
      );
      expect(result.status, AuthServiceStatus.required);
    },
  );

  test(
    'sin red (ningún rechazo del servidor) sigue cayendo al respaldo '
    'offline exactamente como antes',
    () async {
      final service = _NetworkDownAuthService();

      final result = await restoreOnce(service);

      expect(service.onlineAttempts, 1);
      expect(
        service.offlineAttempts,
        1,
        reason:
            'un problema de transporte SIN relación con la credencial debe '
            'seguir cayendo al respaldo offline — ahí sí tiene sentido '
            'trabajar sin conexión.',
      );
      expect(result.status, AuthServiceStatus.restored);
    },
  );
}
