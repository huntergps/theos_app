import 'package:web_socket_channel/web_socket_channel.dart';

/// Web implementation - creates WebSocket without custom headers.
///
/// The browser controls the `Origin` header and does not let us set custom
/// ones on a WebSocket handshake, so authentication travels entirely in the
/// URL's `session_id` query parameter that [WebSocketConnectionManager]
/// already built into [uri] — there is no `Authorization` header to send
/// here either way.
Future<WebSocketChannel> createWebSocketChannel(
  Uri uri,
  String baseUrl, {
  String? database,
}) async {
  return WebSocketChannel.connect(uri);
}
