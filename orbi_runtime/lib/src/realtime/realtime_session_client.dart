/// Cambia la llave API vigente por un TICKET de un solo uso para abrir la
/// sesión de tiempo real, contra `POST /app_sync/realtime/session` del
/// módulo Odoo `l10n_ec_app_sync` (`controllers/realtime_session.py`).
///
/// No es una ruta `/json/2/<modelo>/<método>`: es una ruta de proyecto propia
/// (`type='json2'`, `auth='bearer'`), así que se llama con
/// `OdooClient.http.post`, no con `OdooClient.call`.
///
/// El servidor NUNCA entrega un `session_id` de una hora en esta respuesta:
/// eso quedaría en claro en cualquier log de acceso o de proxy de la línea
/// `GET /websocket?...` del handshake. En su lugar entrega un `ticket` de un
/// solo uso, válido unos segundos (`expires_at`), que el servidor cambia por
/// la sesión real durante el handshake y descarta — `session_expires_at` es
/// cuándo vencerá ESA sesión, y es lo que de verdad programa la renovación
/// proactiva (ver `RealtimeCredential.sessionExpiresAt`). Un ticket usado o
/// vencido hace fallar el handshake con 403 — eso es un reintento con
/// retroceso más, nunca `disabled` (`disabled` es sólo el 404 de esta ruta).
library;

import 'package:dio/dio.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

/// El servidor no tiene el módulo de tiempo real instalado (`404`): la app
/// debe seguir funcionando SIN tiempo real, sin error visible — nunca se
/// reintenta esta sesión hasta el próximo `start()`.
final class RealtimeUnsupportedException implements Exception {
  const RealtimeUnsupportedException();

  @override
  String toString() => 'RealtimeUnsupportedException';
}

/// La llave está inválida, vencida o a punto de vencer (`401`), o el usuario
/// de la llave no es interno (`403`). El llamador debe pedir la renovación
/// al mecanismo que ya existe (`NativeAuthService.renewApiKeyIfNeeded`),
/// nunca inventar otro.
final class RealtimeUnauthorizedException implements Exception {
  const RealtimeUnauthorizedException();

  @override
  String toString() => 'RealtimeUnauthorizedException';
}

/// Fetches a [RealtimeCredential] for the real-time bus. See
/// [RealtimeCredentialProvider] in `odoo_sdk` for when this gets called.
abstract interface class RealtimeSessionClient {
  Future<RealtimeCredential> createSession();
}

/// Real implementation over an [OdooClient] already scoped to the active
/// session's bearer API key.
final class OdooRealtimeSessionClient implements RealtimeSessionClient {
  OdooRealtimeSessionClient(this._client);

  final OdooClient _client;

  static const _path = '/app_sync/realtime/session';

  @override
  Future<RealtimeCredential> createSession() async {
    final url = '${_client.config.normalizedBaseUrl}$_path';
    try {
      final response = await _client.http.post(url, data: const {});
      final data = response.data as Map<String, dynamic>;
      final ticket = data['ticket'] as String;
      final expiresAt = DateTime.parse(data['expires_at'] as String).toUtc();
      final sessionExpiresAt = DateTime.parse(
        data['session_expires_at'] as String,
      ).toUtc();
      // Opcional: un servidor sin este campo (módulo más viejo) deja que
      // WebSocketConnectionManager use su valor por omisión.
      final websocketVersion = data['websocket_version'] as String?;
      return RealtimeCredential(
        ticket: ticket,
        expiresAt: expiresAt,
        sessionExpiresAt: sessionExpiresAt,
        websocketVersion: websocketVersion,
      );
    } on DioException catch (error) {
      final statusCode = error.response?.statusCode;
      if (statusCode == 404) throw const RealtimeUnsupportedException();
      if (statusCode == 401 || statusCode == 403) {
        throw const RealtimeUnauthorizedException();
      }
      rethrow;
    }
  }
}
