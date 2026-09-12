import 'database_discovery_types.dart';

/// Browser builds cannot discover databases this way.
///
/// Odoo's `/web/database/list` controller declares no CORS policy (measured
/// against a real server, unlike the JSON-2 data interface which explicitly
/// allows any origin), so a cross-origin request from a Flutter web build is
/// blocked by the browser before it ever reaches the server. Failing fast
/// here — instead of letting the request run and die on a CORS error —
/// avoids a useless network round trip and a confusing console error.
class OdooDatabaseDiscovery {
  OdooDatabaseDiscovery({Object? httpClient});

  Future<List<String>> listDatabases(
    String baseUrl, {
    Duration timeout = const Duration(seconds: 8),
  }) async {
    throw const DatabaseDiscoveryException(
      DatabaseDiscoveryFailureKind.unsupportedPlatform,
    );
  }
}
