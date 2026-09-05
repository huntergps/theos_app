/// Returns whether [url] may use clear-text HTTP transport.
///
/// Clear-text is restricted to the three canonical loopback host names on
/// every build mode. Debug builds do not receive a broader exception.
bool allowsInsecureLoopbackTransport(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null || uri.scheme.toLowerCase() != 'http') return false;

  final host = uri.host.toLowerCase();
  return host == 'localhost' || host == '127.0.0.1' || host == '::1';
}
