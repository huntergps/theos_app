import 'dart:async';

import '../services/logger_service.dart';
import 'odoo_websocket_events.dart';
import 'websocket_channel_manager.dart';
import 'websocket_connection_manager.dart';
import 'websocket_event_parser.dart';
import 'websocket_heartbeat_manager.dart';
import 'websocket_message_deduplicator.dart';
import 'websocket_reconnection_manager.dart';

// Re-export events for consumers
export 'odoo_websocket_events.dart';

/// SEC-04: Exception thrown when insecure WebSocket connection is attempted.
class InsecureWebSocketException implements Exception {
  final String message;
  final String url;

  const InsecureWebSocketException(this.message, {required this.url});

  @override
  String toString() => 'InsecureWebSocketException: $message (url: $url)';
}

/// Connection information needed to establish WebSocket connection
class OdooWebSocketConnectionInfo {
  final String baseUrl;
  final String database;
  final String? apiKey;
  final String? sessionId;
  final int? partnerId;

  /// Heartbeat interval to keep connection alive.
  /// Default: 30 seconds.
  final Duration heartbeatInterval;

  /// Default channels to subscribe to.
  /// If null, uses the built-in default channels.
  /// If empty list, subscribes to no default channels (only additional channels).
  final List<String>? defaultChannels;

  /// SEC-04: Whether to allow insecure ws:// connections.
  ///
  /// SECURITY: Should be `false` in production to enforce wss://.
  /// Set to `true` only for local development (e.g., localhost).
  final bool allowInsecure;

  /// Whether the app is running on a web platform.
  ///
  /// Used for browser-specific session handling (e.g., cookie-based auth).
  /// Pass `true` when running on web, `false` otherwise.
  final bool isWeb;

  const OdooWebSocketConnectionInfo({
    required this.baseUrl,
    required this.database,
    this.apiKey,
    this.sessionId,
    this.partnerId,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.defaultChannels,
    this.allowInsecure = false,
    this.isWeb = false,
  });

  /// Whether this connection uses a secure HTTPS base URL.
  bool get isSecure {
    try {
      final uri = Uri.parse(baseUrl);
      return uri.scheme == 'https';
    } catch (_) {
      return false;
    }
  }

  /// The WebSocket URL derived from baseUrl.
  String get websocketUrl {
    final uri = Uri.parse(baseUrl);
    final wsScheme = uri.scheme == 'https' ? 'wss' : 'ws';
    return '$wsScheme://${uri.host}${uri.hasPort ? ':${uri.port}' : ''}/websocket';
  }

  /// SEC-04: Validates that the connection uses HTTPS/WSS.
  ///
  /// Throws [InsecureWebSocketException] if:
  /// - URL uses http:// (which means ws://) and [allowInsecure] is false
  ///
  /// Does nothing if [allowInsecure] is true or URL uses https://.
  void validateSecureConnection() {
    if (allowInsecure) return;

    final uri = Uri.parse(baseUrl);

    if (uri.scheme == 'http') {
      throw InsecureWebSocketException(
        'Insecure WebSocket connection not allowed in production. '
        'Use https:// base URL or set allowInsecure=true for development.',
        url: baseUrl,
      );
    }

    if (uri.scheme != 'https') {
      throw InsecureWebSocketException(
        'Invalid URL scheme: ${uri.scheme}. Must be http:// or https://.',
        url: baseUrl,
      );
    }
  }

  /// SEC-01: Secure string representation that masks sensitive credentials.
  ///
  /// API keys and session IDs are masked to prevent accidental exposure
  /// in logs, error messages, or stack traces.
  @override
  String toString() {
    return 'OdooWebSocketConnectionInfo('
        'baseUrl: $baseUrl, '
        'database: $database, '
        'apiKey: ${_maskCredential(apiKey)}, '
        'sessionId: ${_maskCredential(sessionId)}, '
        'partnerId: $partnerId, '
        'secure: ${!allowInsecure})';
  }

  /// Masks a credential showing only first and last 2 characters.
  static String _maskCredential(String? value) {
    if (value == null) return 'null';
    if (value.isEmpty) return '';
    if (value.length <= 4) return '*' * value.length;
    return '${value.substring(0, 2)}${'*' * (value.length - 4)}${value.substring(value.length - 2)}';
  }
}

/// Callback type for establishing browser session before WebSocket connection
typedef BrowserSessionEstablisher = Future<void> Function({
  required String baseUrl,
  required String apiKey,
  required String database,
  required String sessionId,
});

/// WebSocket service for Odoo 19.0 real-time notifications
/// Implements the Odoo bus.websocket protocol
///
/// ## Usage with Typed Event Stream (Recommended)
///
/// ```dart
/// final wsService = OdooWebSocketService();
///
/// // Connect with connection info
/// await wsService.connect(OdooWebSocketConnectionInfo(
///   baseUrl: 'https://odoo.example.com',
///   database: 'mydb',
///   sessionId: 'abc123',
/// ));
///
/// // Listen to typed events with pattern matching
/// wsService.eventStream.listen((event) {
///   switch (event) {
///     case OdooConnectionEvent e:
///       print('Connected: ${e.isConnected}');
///     case OdooRecordEvent e when e.model == 'sale.order':
///       handleOrderUpdate(e);
///     case OdooPresenceEvent e:
///       updateUserStatus(e.partnerId, e.imStatus);
///   }
/// });
/// ```
class OdooWebSocketService {
  // Internal managers
  final WebSocketConnectionManager _connection = WebSocketConnectionManager();
  final WebSocketHeartbeatManager _heartbeat = WebSocketHeartbeatManager();
  final WebSocketReconnectionManager _reconnection =
      WebSocketReconnectionManager();
  final WebSocketMessageDeduplicator _deduplicator =
      WebSocketMessageDeduplicator();
  final WebSocketEventParser _parser = WebSocketEventParser();
  final WebSocketChannelManager _channels = WebSocketChannelManager();

  // Queue for notifications that arrive before any listener is registered
  final List<Map<String, dynamic>> _pendingNotifications = [];

  // Optional callback for browser session establishment (Web only)
  BrowserSessionEstablisher? get browserSessionEstablisher =>
      _connection.browserSessionEstablisher;
  set browserSessionEstablisher(BrowserSessionEstablisher? value) =>
      _connection.browserSessionEstablisher = value;

  // ============================================================================
  // TYPED EVENT STREAM (Primary API)
  // ============================================================================

  /// StreamController for typed WebSocket events
  final StreamController<OdooWebSocketEvent> _eventController =
      StreamController<OdooWebSocketEvent>.broadcast();

  /// Stream of typed WebSocket events.
  Stream<OdooWebSocketEvent> get eventStream => _eventController.stream;

  /// Subscribes to typed WebSocket events with automatic cleanup.
  ///
  /// Returns a [StreamSubscription] that can be used to cancel the subscription.
  /// The subscription is automatically cleaned up when cancelled.
  ///
  /// Example:
  /// ```dart
  /// final subscription = wsService.addEventListener((event) {
  ///   if (event is OdooRecordEvent) {
  ///     print('Record changed: ${event.model} #${event.recordId}');
  ///   }
  /// });
  ///
  /// // Later, cancel the subscription
  /// subscription.cancel();
  /// ```
  StreamSubscription<OdooWebSocketEvent> addEventListener(
    void Function(OdooWebSocketEvent) callback,
  ) {
    return _eventController.stream.listen(callback);
  }

  /// Returns a filtered stream of specific event types.
  ///
  /// Use this to listen only to events of a particular type without
  /// manual type checking.
  ///
  /// Example:
  /// ```dart
  /// // Listen only to record events
  /// wsService.eventsOfType<OdooRecordEvent>().listen((event) {
  ///   print('${event.model} #${event.recordId} was ${event.action}');
  /// });
  ///
  /// // Listen only to connection events
  /// wsService.eventsOfType<OdooConnectionEvent>().listen((event) {
  ///   print('Connected: ${event.isConnected}');
  /// });
  /// ```
  Stream<T> eventsOfType<T extends OdooWebSocketEvent>() {
    return _eventController.stream.where((e) => e is T).cast<T>();
  }

  /// Emit a typed event to all listeners
  void _emitEvent(OdooWebSocketEvent event) {
    if (_eventController.hasListener) {
      _eventController.add(event);
      logger.d('[OdooWebSocket]', 'Event emitted: ${event.runtimeType}');
    } else {
      logger.d('[OdooWebSocket]', 'No event listeners, event discarded');
    }
  }

  // ============================================================================
  // RAW NOTIFICATION STREAM (Legacy API - for backwards compatibility)
  // ============================================================================

  final StreamController<Map<String, dynamic>> _notificationController =
      StreamController<Map<String, dynamic>>.broadcast();

  /// Stream of raw notifications that multiple listeners can subscribe to.
  Stream<Map<String, dynamic>> get notificationStream =>
      _notificationController.stream;

  /// Subscribes to raw notification events with automatic cleanup.
  ///
  /// This is the legacy API for backwards compatibility. For new code,
  /// prefer using [addEventListener] or [eventsOfType] for typed events.
  ///
  /// When a new listener is registered, any pending notifications that
  /// arrived before any listener was registered are immediately delivered.
  ///
  /// Returns a [StreamSubscription] that can be cancelled to stop receiving
  /// notifications.
  ///
  /// Example:
  /// ```dart
  /// final subscription = wsService.addNotificationListener((notification) {
  ///   final type = notification['type'];
  ///   final payload = notification['payload'];
  ///   print('Received $type: $payload');
  /// });
  /// ```
  StreamSubscription<Map<String, dynamic>> addNotificationListener(
    void Function(Map<String, dynamic>) callback,
  ) {
    // First, process any pending notifications for this new listener
    if (_pendingNotifications.isNotEmpty) {
      logger.d(
        '[OdooWebSocket]',
        'Processing ${_pendingNotifications.length} pending notifications for new listener...',
      );
      for (final notification in _pendingNotifications) {
        callback(notification);
      }
    }
    return _notificationController.stream.listen(callback);
  }

  // Getters for monitoring
  bool get isConnected => _connection.isConnected;
  String? get connectionUrl => _connection.connectionUrl;
  String? get lastError => _connection.lastError;
  DateTime? get lastHeartbeat => _heartbeat.lastHeartbeat;
  Map<String, dynamic>? get lastNotification => _parser.lastNotification;
  int get reconnectAttempts => _reconnection.reconnectAttempts;
  List<String> get subscribedChannels =>
      _channels.subscribedChannels.toList();

  /// Adds additional channels to subscribe to.
  ///
  /// Channels can be added before or after connecting. If already connected,
  /// the subscription message is sent immediately. Otherwise, channels are
  /// queued and subscribed when [connect] is called.
  ///
  /// Channel names should be in the format `database.channel_name` or just
  /// `channel_name` (database prefix will be added automatically).
  ///
  /// Example:
  /// ```dart
  /// // Add custom channels before connecting
  /// wsService.addChannels(['custom_notifications', 'stock_moves']);
  /// await wsService.connect(connectionInfo);
  ///
  /// // Or add channels after connecting
  /// await wsService.connect(connectionInfo);
  /// wsService.addChannels(['pos_orders']); // Subscribed immediately
  /// ```
  void addChannels(List<String> channels) {
    _channels.addChannels(channels, _connection);
  }

  /// Connects to the Odoo WebSocket server.
  ///
  /// Establishes a WebSocket connection using the provided [connectionInfo].
  /// On success, starts the heartbeat timer and subscribes to default channels.
  ///
  /// If already connected or connecting, this method returns immediately.
  ///
  /// For web platforms with session authentication, set [browserSessionEstablisher]
  /// before calling this method to establish browser cookies.
  ///
  /// Throws [InsecureWebSocketException] if [connectionInfo.allowInsecure] is
  /// false and the URL uses http:// instead of https://.
  ///
  /// Emits [OdooConnectionEvent] on success or failure via [eventStream].
  ///
  /// Example:
  /// ```dart
  /// final wsService = OdooWebSocketService();
  ///
  /// await wsService.connect(OdooWebSocketConnectionInfo(
  ///   baseUrl: 'https://odoo.example.com',
  ///   database: 'production',
  ///   apiKey: 'your-api-key',
  /// ));
  ///
  /// if (wsService.isConnected) {
  ///   print('Connected to WebSocket');
  /// }
  /// ```
  Future<void> connect(OdooWebSocketConnectionInfo connectionInfo) async {
    if (_connection.isConnected || _connection.isConnecting) {
      return;
    }

    try {
      final wasReconnection = _reconnection.wasReconnection;

      await _connection.connect(
        connectionInfo,
        onMessage: _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
      );

      _reconnection.reset();

      // Emit typed connection event
      _emitEvent(OdooConnectionEvent(
        isConnected: true,
        isReconnection: wasReconnection,
      ));

      if (wasReconnection) {
        logger.i('[OdooWebSocket]', 'Reconnected - triggering offline sync');
      }

      // Start heartbeat
      final interval =
          connectionInfo.heartbeatInterval;
      _heartbeat.start(interval, _connection);

      // Build and subscribe to channels
      final channels = _channels.buildDefaultChannels(
        connectionInfo.database,
        connectionInfo.partnerId,
        connectionInfo,
      );
      channels.addAll(_channels.additionalChannels);

      await _channels.subscribeToChannels(
        channels,
        _connection,
        lastNotificationId: _parser.lastNotificationId,
      );
    } catch (e) {
      logger.e('[OdooWebSocket]', 'Connection error: $e');
      _connection.onConnectFailed();

      // Emit typed events
      _emitEvent(OdooErrorEvent(e));
      _emitEvent(OdooConnectionEvent(isConnected: false, error: e.toString()));
      _scheduleReconnect();
    }
  }

  /// Handle incoming messages
  void _onMessage(dynamic message) {
    // Check for duplicate messages first
    if (_deduplicator.isDuplicate(message)) return;

    _parser.parseMessage(
      message,
      onEvent: _emitEvent,
      onNotification: _emitRawNotification,
    );
  }

  /// Emit a raw notification to legacy listeners or queue it.
  void _emitRawNotification(Map<String, dynamic> notification) {
    final hasListeners = _notificationController.hasListener;
    final type = notification['type'] as String?;
    logger.d('[OdooWebSocket]',
        'Emitting to stream (hasListeners: $hasListeners, type: $type)');

    if (hasListeners) {
      try {
        _notificationController.add(notification);
        logger.d(
            '[OdooWebSocket]', 'Stream notification emitted successfully');
      } catch (e) {
        logger.e('[OdooWebSocket]', 'Error emitting to stream: $e');
      }
    } else {
      logger.d(
          '[OdooWebSocket]', 'No stream listeners, queueing notification');
      _pendingNotifications.add(notification);
    }
  }

  /// Handle errors
  void _onError(Object error) {
    _connection.lastError = 'WebSocket error: $error';
    logger.e('[OdooWebSocket]', _connection.lastError!);

    _emitEvent(OdooErrorEvent(error));

    disconnect();
    _scheduleReconnect();
  }

  /// Handle disconnection
  void _onDisconnected() {
    _connection.isConnected = false;
    _emitEvent(OdooConnectionEvent(isConnected: false));
    _heartbeat.stop();
    _scheduleReconnect();
  }

  /// Schedule reconnection with exponential backoff
  void _scheduleReconnect() {
    if (_connection.connectionInfo == null) return;

    _reconnection.schedule(() async {
      final info = _connection.connectionInfo;
      if (info != null) {
        await connect(info);
      }
    });
  }

  /// Disconnects from the WebSocket server.
  ///
  /// Stops the heartbeat timer, cancels any pending reconnection attempts,
  /// and closes the WebSocket channel. The connection info is preserved,
  /// allowing [connect] to be called again to reconnect.
  ///
  /// This method is safe to call multiple times or when not connected.
  ///
  /// Example:
  /// ```dart
  /// // Disconnect temporarily
  /// wsService.disconnect();
  ///
  /// // Can reconnect later
  /// await wsService.connect(connectionInfo);
  /// ```
  void disconnect() {
    _heartbeat.stop();
    _reconnection.cancel();
    _connection.disconnect();
    _channels.clear();
  }

  /// Releases all resources used by this service.
  ///
  /// Disconnects from the WebSocket, closes all stream controllers, and
  /// clears pending notifications. After calling dispose, this service
  /// should not be used again.
  ///
  /// Call this method when the service is no longer needed, such as when
  /// the widget using it is disposed.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// void dispose() {
  ///   wsService.dispose();
  ///   super.dispose();
  /// }
  /// ```
  void dispose() {
    disconnect();
    _eventController.close();
    _notificationController.close();
    _pendingNotifications.clear();
    _connection.connectionInfo = null;
  }
}
