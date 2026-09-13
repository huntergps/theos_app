/// Internal connection manager for OdooWebSocketService.
///
/// Handles WebSocket connection lifecycle: URL building, connecting,
/// browser session establishment, and disconnecting.
library;

import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../services/logger_service.dart';
import 'odoo_websocket_service.dart';
import 'websocket_model_registry.dart';

// `RealtimeCredential` comes in transitively through
// `odoo_websocket_service.dart`, which exports `realtime_credential.dart`.

// Conditional imports for platform-specific WebSocket creation
import 'platform/websocket_connect_stub.dart'
    if (dart.library.js_interop) 'platform/websocket_connect_web.dart'
    if (dart.library.io) 'platform/websocket_connect_io.dart';

/// Creates the platform [WebSocketChannel] for [uri].
///
/// Matches the signature of the conditionally-imported
/// `createWebSocketChannel` top-level function. Exposed as a typedef so
/// [WebSocketConnectionManager] can accept a fake factory in tests instead
/// of opening a real socket.
typedef WebSocketChannelFactory =
    Future<WebSocketChannel> Function(Uri uri, String baseUrl, {String? database});

/// Manages WebSocket connection lifecycle.
///
/// Handles URL construction, platform-specific channel creation,
/// browser session establishment, and connection state tracking.
class WebSocketConnectionManager {
  /// [channelFactory] defaults to the real platform implementation.
  /// Tests inject a fake to capture the built [Uri] and simulate a socket
  /// without touching the network.
  WebSocketConnectionManager({WebSocketChannelFactory? channelFactory})
    : _channelFactory = channelFactory ?? createWebSocketChannel;

  final WebSocketChannelFactory _channelFactory;

  WebSocketChannel? channel;
  StreamSubscription? subscription;

  bool isConnected = false;
  bool isConnecting = false;
  String? connectionUrl;
  String? lastError;

  /// Stored connection info for reconnection.
  OdooWebSocketConnectionInfo? connectionInfo;

  /// Timer that fires when the current [RealtimeCredential] expires while
  /// still connected, so the socket can proactively renew it instead of
  /// waiting for the server to close the connection.
  Timer? _credentialExpiryTimer;

  /// Establishes the WebSocket connection.
  ///
  /// Fetches a fresh [RealtimeCredential] from
  /// [OdooWebSocketConnectionInfo.realtimeCredentialProvider] on every call
  /// — first connect, every reconnection, and every credential renewal all
  /// go through here — and authenticates the bus with `?session_id=`
  /// instead of a JSON-2 Bearer token (Odoo's bus route does not accept
  /// one; it identifies the caller by session).
  ///
  /// Returns the created [WebSocketChannel] on success.
  /// Throws on connection failure.
  Future<WebSocketChannel> connect(
    OdooWebSocketConnectionInfo info, {
    required void Function(dynamic) onMessage,
    required void Function(Object) onError,
    required void Function() onDone,
    required void Function() onCredentialExpired,
  }) async {
    // SEC-04: Validate secure connection before connecting
    info.validateSecureConnection();

    isConnecting = true;
    connectionInfo = info;

    final baseUrl = info.baseUrl;
    final database = info.database;

    // SEC-01: never log the credential itself, only that one was fetched.
    final credential = await info.realtimeCredentialProvider();

    // Parse base URL to get components
    final baseUri = Uri.parse(baseUrl);
    final wsScheme = baseUri.scheme == 'https' ? 'wss' : 'ws';

    // Build WebSocket URL manually to avoid iOS port:0 issue
    final port = baseUri.hasPort
        ? baseUri.port
        : (wsScheme == 'wss' ? 443 : 80);
    final shouldIncludePort =
        baseUri.hasPort && port != (wsScheme == 'wss' ? 443 : 80);

    final wsVersion = WebSocketModelRegistry.instance.wsVersion;
    final host = shouldIncludePort
        ? '${baseUri.host}:$port'
        : baseUri.host;

    final uri = Uri(
      scheme: wsScheme,
      host: baseUri.host,
      port: shouldIncludePort ? port : null,
      path: '/websocket',
      queryParameters: {
        'version': wsVersion,
        'session_id': credential.sessionId,
      },
    );
    connectionUrl = '$wsScheme://$host/websocket?version=$wsVersion';

    // Create WebSocket connection using platform-specific implementation.
    // No Authorization header is sent: the bus identifies the caller by
    // the `session_id` query parameter above.
    channel = await _channelFactory(uri, baseUrl, database: database);

    // Listen to messages
    subscription = channel!.stream.listen(
      onMessage,
      onError: onError,
      onDone: onDone,
      cancelOnError: false,
    );

    isConnected = true;
    isConnecting = false;

    _scheduleCredentialExpiry(credential, onCredentialExpired);

    return channel!;
  }

  /// Schedules [onExpired] to run when [credential] reaches its
  /// `expiresAt`, so the caller can reconnect and fetch a fresh one before
  /// the server drops the socket.
  void _scheduleCredentialExpiry(
    RealtimeCredential credential,
    void Function() onExpired,
  ) {
    _credentialExpiryTimer?.cancel();
    final remaining = credential.expiresAt.difference(DateTime.now());
    _credentialExpiryTimer = Timer(
      remaining.isNegative ? Duration.zero : remaining,
      onExpired,
    );
  }

  /// Disconnects and cleans up the connection.
  void disconnect() {
    _credentialExpiryTimer?.cancel();
    _credentialExpiryTimer = null;
    subscription?.cancel();
    channel?.sink.close();
    channel = null;
    subscription = null;
    isConnected = false;
    isConnecting = false;
  }

  /// Resets connecting state on failure.
  void onConnectFailed() {
    isConnected = false;
    isConnecting = false;
    lastError = null;
  }

  /// Sends a raw JSON-encoded message through the WebSocket.
  void send(String encodedMessage) {
    if (!isConnected || channel == null) return;
    try {
      channel!.sink.add(encodedMessage);
    } catch (e) {
      lastError = 'Send error: $e';
      logger.e('[OdooWebSocket]', lastError!);
    }
  }
}
