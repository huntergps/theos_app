import '../client/odoo_crud_api.dart';
import 'odoo_auth_strategy.dart';

/// Authentication strategy using custom mobile endpoint
///
/// Calls res.users.mobile_get_websocket_session to create a real
/// Odoo session that can be used for WebSocket authentication.
///
/// This is the preferred method for mobile platforms.
class MobileAuthStrategy extends OdooAuthStrategy {
  final OdooCrudApi _crudApi;

  MobileAuthStrategy({required OdooCrudApi crudApi}) : _crudApi = crudApi;

  @override
  String get name => 'mobile_get_websocket_session';

  @override
  bool get isAvailable => true;

  @override
  Future<OdooSessionResult?> authenticate() async {
    try {
      final result = await _crudApi.call(
        model: 'res.users',
        method: 'mobile_get_websocket_session',
      );

      if (result is Map<String, dynamic>) {
        final sessionId = result['session_id'] as String?;
        final uid = result['uid'];

        if (sessionId != null && uid != null) {
          return OdooSessionResult(
            sessionId: sessionId,
            uid: uid is int ? uid : int.parse(uid.toString()),
            partnerId: result['partner_id'] as int?,
            extra: result,
          );
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
