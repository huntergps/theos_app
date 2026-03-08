import 'package:web_socket_channel/web_socket_channel.dart';

/// Web implementation - creates WebSocket without custom headers
Future<WebSocketChannel> createWebSocketChannel(Uri uri, String baseUrl) async {
  return WebSocketChannel.connect(uri);
}
