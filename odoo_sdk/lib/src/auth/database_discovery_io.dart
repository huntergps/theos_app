import 'package:dio/dio.dart';

import 'database_discovery_types.dart';

/// Discovers the databases a bare Odoo server exposes, before login.
///
/// Uses Odoo's own `/web/database/list` controller (`auth='none'`,
/// `type='jsonrpc'`) — the same route Odoo's official mobile app uses to let
/// a person pick a database instead of typing it. It sends no credentials.
///
/// Serves every platform this SDK runs on, Flutter web included — plain
/// `Dio()` already resolves to a browser-compatible adapter (the same
/// unconditional `Dio()` `OdooHttpClient` uses for real web traffic), and
/// there is nothing platform-specific left to do here. See
/// `database_discovery.dart` for why an earlier web-only stub that refused
/// to even try was wrong.
///
/// Many deployments disable this on purpose (`--no-database-list` /
/// `list_db=False` in the server config) precisely so a stranger cannot
/// enumerate what databases exist. [DatabaseDiscoveryFailureKind.disabled]
/// is that case, and it is not a defect: callers must fall back to manual
/// entry, never treat it as a dead end.
class OdooDatabaseDiscovery {
  OdooDatabaseDiscovery({Dio? httpClient}) : _http = httpClient ?? Dio();

  final Dio _http;

  /// Returns the database names the server is willing to disclose.
  ///
  /// Throws [DatabaseDiscoveryException] for every case where a usable list
  /// could not be produced — disabled listing, an unreachable server, or an
  /// unexpected response shape. Never returns `null`; an empty list means
  /// the server answered with zero databases.
  Future<List<String>> listDatabases(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final normalized = _validatedBaseUrl(baseUrl);
    try {
      final response = await _http.post<dynamic>(
        '$normalized/web/database/list',
        data: const {
          'jsonrpc': '2.0',
          'method': 'call',
          'params': <String, dynamic>{},
          'id': 1,
        },
        options: Options(
          headers: const {'Content-Type': 'application/json'},
          sendTimeout: timeout,
          receiveTimeout: timeout,
          followRedirects: false,
          validateStatus: (status) => status != null && status < 500,
        ),
      );
      final body = response.data;
      if (body is Map && body['error'] != null) {
        final error = body['error'];
        final data = error is Map ? error['data'] : null;
        final name = data is Map ? data['name'] as String? : null;
        if (name == 'odoo.exceptions.AccessDenied') {
          throw const DatabaseDiscoveryException(
            DatabaseDiscoveryFailureKind.disabled,
          );
        }
        throw DatabaseDiscoveryException(
          DatabaseDiscoveryFailureKind.protocol,
          message: error is Map ? error['message'] as String? : null,
        );
      }
      final result = body is Map ? body['result'] : null;
      if (result is! List) {
        throw const DatabaseDiscoveryException(
          DatabaseDiscoveryFailureKind.protocol,
        );
      }
      return result.whereType<String>().toList(growable: false);
    } on DatabaseDiscoveryException {
      rethrow;
    } on DioException {
      throw const DatabaseDiscoveryException(
        DatabaseDiscoveryFailureKind.connection,
      );
    }
  }

  /// Asks a server which single database serves its own domain, without
  /// enumerating anything.
  ///
  /// Hits `GET {baseUrl}/orbi/database` — a route this project adds to Odoo
  /// deployments that run with `list_db = False` (the correct setting for a
  /// public server), precisely so [listDatabases] cannot be used: that
  /// endpoint returns a 200 carrying an `AccessDenied` JSON-RPC error with no
  /// CORS header, which a browser hides from the caller entirely, making a
  /// server that is reachable and simply refusing to enumerate look
  /// indistinguishable from an unreachable one. `/orbi/database` sidesteps
  /// that: it answers `{"database": "<name>"}` with
  /// `Access-Control-Allow-Origin: *` when the domain maps to exactly one
  /// database, or a bare 404 (`{"error": "no_single_database"}`) when it
  /// does not — never a list of names.
  ///
  /// A plain GET with no request headers of its own, on purpose: any custom
  /// header (a `Content-Type`, an auth header) turns this into a request
  /// that needs a CORS preflight, and the preflight is exactly what a server
  /// without this route yet cannot answer usefully.
  ///
  /// Returns the database name on success, `null` when the server answered
  /// but does not single out one database (its own 404), and throws
  /// [DatabaseDiscoveryException] for every other outcome: `connection` for
  /// a request that could not complete at all (including a server that has
  /// not deployed this route yet and whose resulting 404 a browser strips of
  /// its body/headers on a cross-origin call — that is measured as a Dio
  /// connection error, not a clean 404), `protocol` for a 200 that does not
  /// carry a usable `database` string, or any other HTTP status.
  Future<String?> servedDatabase(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final normalized = _validatedBaseUrl(baseUrl);
    try {
      final response = await _http.get<dynamic>(
        '$normalized/orbi/database',
        options: Options(
          sendTimeout: timeout,
          receiveTimeout: timeout,
          followRedirects: false,
          // Branch on every status ourselves below — a 404 here is the
          // expected "not a single database" answer, not a failure to
          // surface as a connection error.
          validateStatus: (_) => true,
        ),
      );
      if (response.statusCode == 404) return null;
      if (response.statusCode == 200) {
        final body = response.data;
        final database = body is Map ? body['database'] : null;
        if (database is String && database.isNotEmpty) return database;
      }
      throw const DatabaseDiscoveryException(
        DatabaseDiscoveryFailureKind.protocol,
      );
    } on DatabaseDiscoveryException {
      rethrow;
    } on DioException {
      throw const DatabaseDiscoveryException(
        DatabaseDiscoveryFailureKind.connection,
      );
    }
  }

  String _validatedBaseUrl(String value) {
    final trimmed = value.trim();
    final uri = Uri.tryParse(trimmed);
    if (uri == null ||
        uri.host.isEmpty ||
        (uri.scheme != 'http' && uri.scheme != 'https')) {
      throw const DatabaseDiscoveryException(
        DatabaseDiscoveryFailureKind.protocol,
      );
    }
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }
}
