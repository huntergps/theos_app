import '../client/odoo_http_client.dart';
import '../client/odoo_crud_api.dart';
import 'odoo_auth_strategy.dart';

/// Fallback authentication strategy using /web/session/authenticate
///
/// This strategy is used when the mobile endpoint is not available.
/// It authenticates via JSON-RPC and extracts session_id from cookies.
class JsonRpcAuthStrategy extends OdooAuthStrategy {
  final OdooHttpClient _httpClient;
  final OdooCrudApi _crudApi;
  final String? _login;
  final String? _password;

  JsonRpcAuthStrategy({
    required OdooHttpClient httpClient,
    required OdooCrudApi crudApi,
    String? login,
    String? password,
  }) : _httpClient = httpClient,
       _crudApi = crudApi,
       _login = login,
       _password = password;

  @override
  String get name => 'json_rpc_authenticate';

  @override
  bool get isAvailable => true;

  @override
  Future<OdooSessionResult?> authenticate() async {
    final config = _httpClient.config;

    // Use API key as password if no password provided
    final authPassword = _password ?? config.apiKey;
    if (authPassword.isEmpty) {
      return null;
    }

    try {
      // If no login provided, fetch it from the current user
      String? userLogin = _login;
      if (userLogin == null) {
        try {
          final users = await _crudApi.searchRead(
            model: 'res.users',
            fields: ['login'],
            limit: 1,
          );
          if (users.isNotEmpty) {
            userLogin = users[0]['login'] as String?;
          }
        } catch (e) {
          // Could not fetch user login
        }
      }

      if (userLogin == null) {
        return null;
      }

      // Call /web/session/authenticate
      final response = await _httpClient.post(
        '${config.normalizedBaseUrl}/web/session/authenticate',
        data: {
          'jsonrpc': '2.0',
          'method': 'call',
          'params': {
            'db': config.database,
            'login': userLogin,
            'password': authPassword,
          },
          'id': DateTime.now().millisecondsSinceEpoch,
        },
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;

        // Check for JSON-RPC error
        if (data.containsKey('error')) {
          return null;
        }

        // Extract session_id from cookies
        String? sessionId;
        final cookies = response.headers['set-cookie'];
        if (cookies != null) {
          for (final cookie in cookies) {
            if (cookie.contains('session_id=')) {
              final match = RegExp(r'session_id=([^;]+)').firstMatch(cookie);
              if (match != null) {
                sessionId = match.group(1);
                break;
              }
            }
          }
        }

        // Get result from JSON-RPC response
        final result = data['result'] as Map<String, dynamic>?;

        if (result != null) {
          final uid = result['uid'];

          if (uid == null || uid == false) {
            return null;
          }

          return OdooSessionResult(
            sessionId: sessionId ?? '',
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
