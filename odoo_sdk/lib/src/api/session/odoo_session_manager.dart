import 'package:dio/dio.dart';

import '../client/odoo_http_client.dart';
import '../client/odoo_crud_api.dart';
import '../auth/odoo_auth_strategy.dart';
import '../auth/mobile_auth_strategy.dart';
import '../auth/json_rpc_auth_strategy.dart';
import 'session_persistence.dart';

/// Manages Odoo session lifecycle
///
/// Handles:
/// - Web session cookie establishment
/// - WebSocket session authentication
/// - Strategy chain for authentication
/// - Session persistence (save/restore/clear)
/// - Server-side logout
/// - Session expiration detection
class OdooSessionManager {
  final OdooHttpClient _httpClient;
  final OdooCrudApi _crudApi;
  final SessionPersistence? _persistence;

  OdooSessionResult? _currentSession;

  OdooSessionManager({
    required OdooHttpClient httpClient,
    required OdooCrudApi crudApi,
    SessionPersistence? persistence,
  }) : _httpClient = httpClient,
       _crudApi = crudApi,
       _persistence = persistence;

  /// Current authenticated session (if any)
  OdooSessionResult? get currentSession => _currentSession;

  /// Whether we have an active session
  bool get hasSession => _currentSession != null;

  /// Cache for session info (5 minute expiry)
  Map<String, dynamic>? _cachedSessionInfo;
  DateTime? _sessionInfoCacheTime;
  static const _sessionInfoCacheDuration = Duration(minutes: 5);

  /// Establish web session cookies for WebSocket authentication
  ///
  /// This method calls session_info through the /web endpoint to ensure
  /// session cookies are set by the server.
  Future<void> createWebSession() async {
    final config = _httpClient.config;

    if (config.apiKey.isEmpty || config.database == null) {
      return;
    }

    try {
      final response = await _httpClient.get(
        '${config.normalizedBaseUrl}/web/session/get_session_info',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'bearer ${config.apiKey}',
          'X-Odoo-Database': config.database!,
        },
      );

      if (response.statusCode == 200) {
        await _httpClient.loadCookies(
          Uri.parse(config.normalizedBaseUrl),
        );
      }
    } catch (e) {
      // Don't rethrow - this is best-effort for WebSocket compatibility
    }
  }

  /// Get session info from Odoo (cached for 5 minutes)
  ///
  /// Returns uid, partner_id, company info, im_status_access_token, etc.
  Future<Map<String, dynamic>?> getSessionInfo({
    bool forceRefresh = false,
  }) async {
    // Check cache first
    if (!forceRefresh &&
        _cachedSessionInfo != null &&
        _sessionInfoCacheTime != null &&
        DateTime.now().difference(_sessionInfoCacheTime!) <
            _sessionInfoCacheDuration) {
      return _cachedSessionInfo;
    }

    final config = _httpClient.config;

    if (config.apiKey.isEmpty || config.database == null) {
      return null;
    }

    try {
      final response = await _httpClient.get(
        '${config.normalizedBaseUrl}/web/session/get_session_info',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'bearer ${config.apiKey}',
          'X-Odoo-Database': config.database!,
        },
      );

      if (response.statusCode == 200 && response.data is Map) {
        final data = response.data as Map<String, dynamic>;

        // Handle JSON-RPC wrapper if present
        final sessionInfo = data.containsKey('result')
            ? data['result'] as Map<String, dynamic>
            : data;

        _cachedSessionInfo = sessionInfo;
        _sessionInfoCacheTime = DateTime.now();

        return sessionInfo;
      } else {
        return null;
      }
    } catch (e) {
      return null;
    }
  }

  /// Clear session info cache
  void clearSessionInfoCache() {
    _cachedSessionInfo = null;
    _sessionInfoCacheTime = null;
  }

  /// Authenticate session for WebSocket connection
  ///
  /// Tries authentication strategies in order:
  /// 1. Mobile endpoint (mobile_get_websocket_session)
  /// 2. JSON-RPC fallback (/web/session/authenticate)
  ///
  /// Returns session result on success, null on failure.
  /// If persistence is configured, saves the session on success.
  Future<OdooSessionResult?> authenticateSession({
    String? login,
    String? password,
  }) async {
    final config = _httpClient.config;

    if (config.database == null || config.apiKey.isEmpty) {
      return null;
    }

    // Build strategy chain
    final strategies = <OdooAuthStrategy>[
      MobileAuthStrategy(crudApi: _crudApi),
      JsonRpcAuthStrategy(
        httpClient: _httpClient,
        crudApi: _crudApi,
        login: login,
        password: password,
      ),
    ];

    // Try each strategy in order
    for (final strategy in strategies) {
      if (!strategy.isAvailable) continue;

      final result = await strategy.authenticate();

      if (result != null) {
        _currentSession = result;
        await _persistence?.saveSession(result);
        return result;
      }
    }

    return null;
  }

  /// Invalidate the session on the server and clear locally.
  ///
  /// Calls POST /web/session/destroy to invalidate the server-side session,
  /// then clears local session state and persistence.
  /// This is best-effort: failures are silently ignored.
  Future<void> logout() async {
    // Best-effort server-side logout
    try {
      await callJsonRpc(endpoint: '/web/session/destroy');
    } catch (_) {
      // Ignore errors — server may be unreachable
    }

    // Always clear local state regardless of server response
    _currentSession = null;
    clearSessionInfoCache();
    await _persistence?.clearSession();
  }

  /// Check whether the current session is still valid on the server.
  ///
  /// Makes a forced call to getSessionInfo and checks the uid.
  /// Returns true if the server responds with uid > 0, false otherwise
  /// (including 401/403 responses or network errors).
  Future<bool> isSessionValid() async {
    try {
      final info = await getSessionInfo(forceRefresh: true);
      if (info == null) return false;

      final uid = info['uid'];
      if (uid is int && uid > 0) return true;
      return false;
    } on DioException catch (e) {
      final statusCode = e.response?.statusCode;
      if (statusCode == 401 || statusCode == 403) return false;
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Restore a session from persistence.
  ///
  /// Loads the session from [SessionPersistence] and sets it as current.
  /// Returns the restored session, or null if none was persisted.
  Future<OdooSessionResult?> restoreSession() async {
    final session = await _persistence?.loadSession();
    if (session != null) {
      _currentSession = session;
    }
    return session;
  }

  /// Initialize session from storage with server-side validation.
  ///
  /// Tries to load a persisted session, then validates it against the server.
  /// If validation fails, clears the persisted session.
  /// Returns the restored session if valid, null otherwise.
  Future<OdooSessionResult?> initializeFromStorage() async {
    final session = await restoreSession();
    if (session == null) return null;

    final valid = await isSessionValid();
    if (valid) return session;

    // Session expired — clear everything
    _currentSession = null;
    clearSessionInfoCache();
    await _persistence?.clearSession();
    return null;
  }

  /// Call a JSON-RPC endpoint (for controllers like /mail/set_manual_im_status)
  Future<dynamic> callJsonRpc({
    required String endpoint,
    Map<String, dynamic>? params,
  }) async {
    final config = _httpClient.config;
    final url = '${config.normalizedBaseUrl}$endpoint';

    final body = {
      'jsonrpc': '2.0',
      'method': 'call',
      'params': params ?? {},
      'id': DateTime.now().millisecondsSinceEpoch,
    };

    final response = await _httpClient.post(
      url,
      data: body,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'bearer ${config.apiKey}',
        if (config.database != null && config.database!.isNotEmpty)
          'X-Odoo-Database': config.database!,
      },
    );

    // JSON-RPC responses have result/error structure
    if (response.data is Map) {
      final data = response.data as Map<String, dynamic>;
      if (data.containsKey('error')) {
        throw Exception('JSON-RPC error: ${data['error']}');
      }
      return data['result'];
    }
    return response.data;
  }

  /// Clear current session
  void clearSession() {
    _currentSession = null;
  }
}
