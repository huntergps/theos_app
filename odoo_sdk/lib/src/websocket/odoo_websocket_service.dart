import 'dart:async';

import '../services/logger_service.dart';
import 'odoo_websocket_events.dart';
import 'realtime_credential.dart';
import 'websocket_channel_manager.dart';
import 'websocket_connection_manager.dart';
import 'websocket_event_parser.dart';
import 'websocket_heartbeat_manager.dart';
import 'websocket_message_deduplicator.dart';
import 'websocket_reconnection_manager.dart';

// Re-export events for consumers
export 'odoo_websocket_events.dart';
export 'realtime_credential.dart';

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

  /// Fetches the [RealtimeCredential] used to authenticate the bus
  /// connection. Called before the first connect, on every reconnection,
  /// and again when the current credential expires — see
  /// [RealtimeCredentialProvider] for the full contract.
  ///
  /// Odoo's bus does not accept the JSON-2 Bearer API key, so this replaces
  /// the old `apiKey` field entirely.
  final RealtimeCredentialProvider realtimeCredentialProvider;

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

  /// Notification id to seed the parser with before the very first
  /// `subscribe` message of this service's lifetime.
  ///
  /// Lets the runtime persist `last` per scope (e.g. in Drift) and resume
  /// from where it left off instead of always starting at 0. Ignored on
  /// later reconnections within the same [OdooWebSocketService] instance,
  /// which instead carry forward whatever `last` the service already
  /// tracked live — see [OdooWebSocketService.lastNotificationIdStream].
  final int initialLast;

  const OdooWebSocketConnectionInfo({
    required this.baseUrl,
    required this.database,
    required this.realtimeCredentialProvider,
    this.partnerId,
    this.heartbeatInterval = const Duration(seconds: 30),
    this.defaultChannels,
    this.allowInsecure = false,
    this.initialLast = 0,
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

  /// The WebSocket URL derived from baseUrl (scheme/host/port only — the
  /// real connect flow in [WebSocketConnectionManager] appends `?version=`
  /// and `&ticket=` on top of this).
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

  /// SEC-01: Secure string representation.
  ///
  /// [realtimeCredentialProvider] is a function reference, never a raw
  /// credential value, so there is nothing here to mask: the actual
  /// [RealtimeCredential] it returns masks its own `ticket` in its
  /// `toString()`.
  @override
  String toString() {
    return 'OdooWebSocketConnectionInfo('
        'baseUrl: $baseUrl, '
        'database: $database, '
        'partnerId: $partnerId, '
        'secure: ${!allowInsecure})';
  }
}

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
///   realtimeCredentialProvider: fetchRealtimeSession,
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
  /// [connectionManager] is injectable so tests can supply a
  /// [WebSocketConnectionManager] built with a fake `channelFactory`
  /// instead of opening a real socket. Production code never needs to pass
  /// it.
  OdooWebSocketService({WebSocketConnectionManager? connectionManager})
    : _connection = connectionManager ?? WebSocketConnectionManager();

  // Internal managers
  final WebSocketConnectionManager _connection;
  final WebSocketHeartbeatManager _heartbeat = WebSocketHeartbeatManager();
  final WebSocketReconnectionManager _reconnection =
      WebSocketReconnectionManager();
  final WebSocketMessageDeduplicator _deduplicator =
      WebSocketMessageDeduplicator();
  final WebSocketEventParser _parser = WebSocketEventParser();
  final WebSocketChannelManager _channels = WebSocketChannelManager();

  /// Whether [OdooWebSocketConnectionInfo.initialLast] has already been
  /// applied. Seeded only once per service lifetime — later reconnections
  /// must keep whatever `last` the parser tracked live, never reset back to
  /// the original seed.
  bool _hasSeededInitialLast = false;

  // ============================================================================
  // TYPED EVENT STREAM (Primary API)
  // ============================================================================

  /// StreamController for typed WebSocket events
  final StreamController<OdooWebSocketEvent> _eventController =
      StreamController<OdooWebSocketEvent>.broadcast();

  /// Stream of typed WebSocket events.
  Stream<OdooWebSocketEvent> get eventStream => _eventController.stream;

  /// StreamController that reports every new `lastNotificationId` seen from
  /// the server, so a consumer (orbi_runtime) can persist it per scope and
  /// pass it back as [OdooWebSocketConnectionInfo.initialLast] on the next
  /// cold start.
  final StreamController<int> _lastNotificationIdController =
      StreamController<int>.broadcast();

  /// Stream of `lastNotificationId` updates. Emits once per notification
  /// batch that advances the id, not once per raw message.
  Stream<int> get lastNotificationIdStream => _lastNotificationIdController.stream;

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

  // Getters for monitoring
  bool get isConnected => _connection.isConnected;
  String? get connectionUrl => _connection.connectionUrl;
  String? get lastError => _connection.lastError;
  DateTime? get lastHeartbeat => _heartbeat.lastHeartbeat;
  Map<String, dynamic>? get lastNotification => _parser.lastNotification;
  int get reconnectAttempts => _reconnection.reconnectAttempts;
  List<String> get subscribedChannels => _channels.subscribedChannels.toList();

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
  ///   realtimeCredentialProvider: fetchRealtimeSession,
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

    if (!_hasSeededInitialLast) {
      _hasSeededInitialLast = true;
      _parser.seedLastNotificationId(connectionInfo.initialLast);
    }

    // FIX 4: If the server URL or database changed, clear additionalChannels so
    // channels registered for the previous server are not re-subscribed to the
    // new one.  For a same-server reconnect, additionalChannels are preserved
    // (see disconnect()) and re-activated below.
    final previousInfo = _connection.connectionInfo;
    if (previousInfo != null &&
        (previousInfo.baseUrl != connectionInfo.baseUrl ||
            previousInfo.database != connectionInfo.database)) {
      logger.i(
        '[OdooWebSocket]',
        'Server switch detected (${previousInfo.baseUrl} → ${connectionInfo.baseUrl}): '
            'clearing additionalChannels',
      );
      _channels.clear(clearAdditional: true);
    }

    try {
      final wasReconnection = _reconnection.wasReconnection;

      await _connection.connect(
        connectionInfo,
        onMessage: _onMessage,
        onError: _onError,
        onDone: _onDisconnected,
        onCredentialExpired: _onCredentialExpired,
      );

      _reconnection.reset();

      // Emit typed connection event
      _emitEvent(
        OdooConnectionEvent(isConnected: true, isReconnection: wasReconnection),
      );

      if (wasReconnection) {
        logger.i('[OdooWebSocket]', 'Reconnected - triggering offline sync');
      }

      // Start heartbeat
      final interval = connectionInfo.heartbeatInterval;
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

    final previousLast = _parser.lastNotificationId;
    _parser.parseMessage(message, onEvent: _emitEvent);
    if (_parser.lastNotificationId != previousLast) {
      _lastNotificationIdController.add(_parser.lastNotificationId);
    }
  }

  /// Called when the real-time session's `expiresAt` is reached while still
  /// connected.
  ///
  /// This is a planned renewal, not a failure: it reconnects immediately
  /// (fetching a fresh [RealtimeCredential] from
  /// [OdooWebSocketConnectionInfo.realtimeCredentialProvider] as part of the
  /// normal [connect] flow) instead of going through
  /// [WebSocketReconnectionManager]'s exponential backoff, and it never logs
  /// the credential itself.
  void _onCredentialExpired() {
    logger.i(
      '[OdooWebSocket]',
      'Real-time session expired: reconnecting to request a fresh one',
    );
    final info = _connection.connectionInfo;
    disconnect();
    if (info != null) {
      connect(info);
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
    // Un cierre LIMPIO con esta razón significa que el `?version=` que
    // mandamos no coincide con el de este servidor — medido contra ERP2
    // 19.5. El estado sigue el camino genérico de abajo (retrying, con
    // reintento normal, nunca `disabled`: la próxima credencial puede traer
    // la versión corregida, ver `RealtimeCredential.websocketVersion`);
    // esto sólo lo hace diagnosticable en el log en vez de verse como un
    // corte de red cualquiera.
    if (_connection.channel?.closeReason == 'OUTDATED_VERSION') {
      logger.w(
        '[OdooWebSocket]',
        'Socket cerrado por el servidor: versión de protocolo del bus '
            'desactualizada (OUTDATED_VERSION). Reintentando con la versión '
            'que traiga la próxima credencial.',
      );
    }
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

    // Fase B, tarea 6: circuit breaker suave — avisar a los listeners de
    // eventStream (ej. un widget de estado en la UI) cuando ya llevamos
    // demasiados intentos consecutivos fallidos, sin dejar de reintentar.
    if (_reconnection.isCircuitBreakerActive) {
      _emitEvent(
        OdooConnectionEvent(
          isConnected: false,
          isReconnection: true,
          circuitBreakerActive: true,
          reconnectAttempts: _reconnection.reconnectAttempts,
        ),
      );
    }
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
    // Preserve additionalChannels so they are re-subscribed on the next
    // connect() call to the SAME server (transient network drop / reconnect).
    // When switching to a DIFFERENT server, connect() detects the URL change
    // and clears additionalChannels before building the channel list.
    _channels.clear(clearAdditional: false);
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
    _lastNotificationIdController.close();
    _connection.connectionInfo = null;
  }
}
