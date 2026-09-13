import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Builds the headers for the native real-time socket connection.
///
/// No `Authorization` header: Odoo's `/websocket` bus route does not accept
/// a JSON-2 Bearer token (measured against ERP2, it closes with 4001) — the
/// caller is identified by the single-use `ticket` query parameter that
/// [WebSocketConnectionManager] puts on the URL instead. Extracted as a
/// pure function so it can be unit-tested without opening a real socket.
Map<String, String> buildRealtimeSocketHeaders(String baseUrl, {String? database}) {
  return {
    'Origin': baseUrl, // Odoo requires Origin header
    'User-Agent': 'Flutter-OdooOfflineCore/1.0',
    'Sec-WebSocket-Protocol': 'websocket', // Required by Odoo
    if (database != null && database.isNotEmpty) 'X-Odoo-Database': database,
  };
}

/// Native (iOS/Android/Desktop) implementation - creates WebSocket with Origin header
Future<WebSocketChannel> createWebSocketChannel(
  Uri uri,
  String baseUrl, {
  String? database,
}) async {
  // Use IOWebSocketChannel.connect directly with headers (works on all native platforms)
  return IOWebSocketChannel.connect(
    uri,
    headers: buildRealtimeSocketHeaders(baseUrl, database: database),
  );
}
