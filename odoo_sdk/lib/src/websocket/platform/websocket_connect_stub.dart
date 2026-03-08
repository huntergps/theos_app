import 'package:web_socket_channel/web_socket_channel.dart';

/// Stub for WebSocket connection (should never be called)
Future<WebSocketChannel> createWebSocketChannel(Uri uri, String baseUrl) async {
  throw UnimplementedError('WebSocket creation not supported on this platform');
}
