import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/io.dart';

/// Native (iOS/Android/Desktop) implementation - creates WebSocket with Origin header
Future<WebSocketChannel> createWebSocketChannel(Uri uri, String baseUrl) async {
  // Use IOWebSocketChannel.connect directly with headers (works on all native platforms)
  return IOWebSocketChannel.connect(
    uri,
    headers: {
      'Origin': baseUrl, // Odoo requires Origin header
      'User-Agent': 'Flutter-OdooOfflineCore/1.0',
      'Sec-WebSocket-Protocol': 'websocket', // Required by Odoo
    },
  );
}
