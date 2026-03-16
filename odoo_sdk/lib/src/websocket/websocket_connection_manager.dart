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

// Conditional imports for platform-specific WebSocket creation
import 'platform/websocket_connect_stub.dart'
    if (dart.library.js_interop) 'platform/websocket_connect_web.dart'
    if (dart.library.io) 'platform/websocket_connect_io.dart';

/// Manages WebSocket connection lifecycle.
///
/// Handles URL construction, platform-specific channel creation,
/// browser session establishment, and connection state tracking.
class WebSocketConnectionManager {
  WebSocketChannel? channel;
  StreamSubscription? subscription;

  bool isConnected = false;
  bool isConnecting = false;
  String? connectionUrl;
  String? lastError;

  /// Stored connection info for reconnection.
  OdooWebSocketConnectionInfo? connectionInfo;

  /// Optional callback for browser session establishment (Web only).
  BrowserSessionEstablisher? browserSessionEstablisher;

  /// Establishes the WebSocket connection.
  ///
  /// Returns the created [WebSocketChannel] on success.
  /// Throws on connection failure.
  Future<WebSocketChannel> connect(
    OdooWebSocketConnectionInfo info, {
    required void Function(dynamic) onMessage,
    required void Function(Object) onError,
    required void Function() onDone,
  }) async {
    // SEC-04: Validate secure connection before connecting
    info.validateSecureConnection();

    isConnecting = true;
    connectionInfo = info;

    final baseUrl = info.baseUrl;
    final database = info.database;
    final apiKey = info.apiKey;
    final storedSessionId = info.sessionId;

    // On Web platform, establish browser session cookies BEFORE connecting
    if (info.isWeb &&
        storedSessionId != null &&
        browserSessionEstablisher != null) {
      await browserSessionEstablisher!(
        baseUrl: baseUrl,
        apiKey: apiKey ?? '',
        database: database,
        sessionId: storedSessionId,
      );
    }

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

    String wsUrl;
    if (info.isWeb && storedSessionId != null) {
      wsUrl = shouldIncludePort
          ? '$wsScheme://${baseUri.host}:$port/websocket?session_id=$storedSessionId&version=$wsVersion'
          : '$wsScheme://${baseUri.host}/websocket?session_id=$storedSessionId&version=$wsVersion';
    } else {
      wsUrl = shouldIncludePort
          ? '$wsScheme://${baseUri.host}:$port/websocket?version=$wsVersion'
          : '$wsScheme://${baseUri.host}/websocket?version=$wsVersion';
    }

    final uri = Uri.parse(wsUrl);
    connectionUrl = wsUrl;

    // Create WebSocket connection using platform-specific implementation
    channel = await createWebSocketChannel(uri, baseUrl);

    // Listen to messages
    subscription = channel!.stream.listen(
      onMessage,
      onError: onError,
      onDone: onDone,
      cancelOnError: false,
    );

    isConnected = true;
    isConnecting = false;

    return channel!;
  }

  /// Disconnects and cleans up the connection.
  void disconnect() {
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
