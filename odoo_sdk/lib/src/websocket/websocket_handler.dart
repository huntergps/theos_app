/// WebSocket Handler for Odoo Real-time Events
///
/// Handles WebSocket connections to Odoo for receiving real-time
/// record change notifications (create, write, unlink).
///
/// This integrates with ModelRegistry to automatically update
/// local data when changes occur on the server.
library;

import 'dart:async';
import 'dart:convert';

import '../utils/value_stream.dart';
import 'odoo_websocket_events.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

// ═════════════════════════════════════════════════════════════════════════════
// Security Exceptions
// ═════════════════════════════════════════════════════════════════════════════

/// Exception thrown when a WebSocket security validation fails.
class WebSocketSecurityException implements Exception {
  final String message;
  const WebSocketSecurityException(this.message);

  @override
  String toString() => 'WebSocketSecurityException: $message';
}

/// Exception thrown when a session token is required but not provided (SEC-03).
class SessionTokenRequiredException implements Exception {
  final String message;
  const SessionTokenRequiredException([
    this.message = 'Session token is required for WebSocket connection. '
        'Provide sessionToken or set requireSessionToken=false',
  ]);

  @override
  String toString() => 'SessionTokenRequiredException: $message';
}

// ═════════════════════════════════════════════════════════════════════════════
// Configuration
// ═════════════════════════════════════════════════════════════════════════════

/// Configuration for WebSocket connection.
class WebSocketConfig {
  /// WebSocket URL (ws:// or wss://)
  final String url;

  /// Database name
  final String database;

  /// User ID
  final int userId;

  /// Session token
  final String? sessionToken;

  /// Models to subscribe to
  final List<String> subscribedModels;

  /// Reconnect delay in milliseconds
  final int reconnectDelayMs;

  /// Maximum reconnect attempts (0 = infinite)
  final int maxReconnectAttempts;

  /// Enable automatic reconnection
  final bool autoReconnect;

  /// Allow insecure (ws://) connections. Default false (secure by default).
  final bool allowInsecure;

  /// Whitelist of allowed models. Empty set means all models are allowed.
  final Set<String> allowedModels;

  /// Require a session token for connection (SEC-03). Default true.
  final bool requireSessionToken;

  const WebSocketConfig({
    required this.url,
    required this.database,
    required this.userId,
    this.sessionToken,
    this.subscribedModels = const [],
    this.reconnectDelayMs = 5000,
    this.maxReconnectAttempts = 0,
    this.autoReconnect = true,
    this.allowInsecure = false,
    this.allowedModels = const {},
    this.requireSessionToken = true,
  });

  /// Validate that the connection uses a secure WebSocket scheme.
  ///
  /// Throws [WebSocketSecurityException] if the URL is invalid or insecure.
  void validateSecureConnection() {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      throw WebSocketSecurityException(
        'Invalid WebSocket URL: $url',
      );
    }

    if (uri.scheme != 'ws' && uri.scheme != 'wss') {
      throw WebSocketSecurityException(
        'Invalid WebSocket scheme: ${uri.scheme}. Use ws:// or wss://',
      );
    }

    if (uri.scheme == 'ws' && !allowInsecure) {
      throw const WebSocketSecurityException(
        'Insecure WebSocket connection not allowed. '
        'Use wss:// or set allowInsecure=true',
      );
    }
  }

  /// Validate that the requested models are in the allowed whitelist.
  ///
  /// Throws [WebSocketSecurityException] if any model is not allowed.
  void validateModels(List<String> models) {
    if (allowedModels.isEmpty) return; // No whitelist = allow all

    final disallowed =
        models.where((m) => !allowedModels.contains(m)).toSet();
    if (disallowed.isNotEmpty) {
      throw WebSocketSecurityException(
        'Models not in whitelist: ${disallowed.join(', ')}. '
        'Allowed: ${allowedModels.join(', ')}',
      );
    }
  }

  /// Validate that a session token is present (SEC-03).
  ///
  /// Throws [SessionTokenRequiredException] if a token is required but missing.
  void validateSessionToken() {
    if (!requireSessionToken) return;
    if (sessionToken == null || sessionToken!.isEmpty) {
      throw const SessionTokenRequiredException(
        'Session token is required for WebSocket connection. '
        'Provide sessionToken or set requireSessionToken=false',
      );
    }
  }

  /// Validate all security requirements.
  ///
  /// Runs URL validation first, then session token validation.
  void validateSecurity() {
    validateSecureConnection();
    validateSessionToken();
  }

  /// Create a copy with updated fields.
  WebSocketConfig copyWith({
    String? url,
    String? database,
    int? userId,
    String? sessionToken,
    List<String>? subscribedModels,
    int? reconnectDelayMs,
    int? maxReconnectAttempts,
    bool? autoReconnect,
    bool? allowInsecure,
    Set<String>? allowedModels,
    bool? requireSessionToken,
  }) {
    return WebSocketConfig(
      url: url ?? this.url,
      database: database ?? this.database,
      userId: userId ?? this.userId,
      sessionToken: sessionToken ?? this.sessionToken,
      subscribedModels: subscribedModels ?? this.subscribedModels,
      reconnectDelayMs: reconnectDelayMs ?? this.reconnectDelayMs,
      maxReconnectAttempts: maxReconnectAttempts ?? this.maxReconnectAttempts,
      autoReconnect: autoReconnect ?? this.autoReconnect,
      allowInsecure: allowInsecure ?? this.allowInsecure,
      allowedModels: allowedModels ?? this.allowedModels,
      requireSessionToken: requireSessionToken ?? this.requireSessionToken,
    );
  }

  @override
  String toString() {
    final masked = sessionToken != null ? '****' : 'null';
    final secure = url.startsWith('wss') && !allowInsecure;
    return 'WebSocketConfig('
        'url: $url, '
        'database: $database, '
        'userId: $userId, '
        'sessionToken: $masked, '
        'models: ${subscribedModels.length}, '
        'secure: $secure)';
  }
}

// ═════════════════════════════════════════════════════════════════════════════
// State and Events
// ═════════════════════════════════════════════════════════════════════════════

/// WebSocket connection state.
enum WebSocketState {
  disconnected,
  connecting,
  connected,
  reconnecting,
  error,
}

/// Types of connection events.
enum ConnectionEventType {
  connected,
  disconnected,
  reconnecting,
  error,
}

/// WebSocket connection event.
class WebSocketConnectionEvent {
  final ConnectionEventType type;
  final DateTime timestamp;
  final String? error;

  const WebSocketConnectionEvent({
    required this.type,
    required this.timestamp,
    this.error,
  });

  @override
  String toString() => 'WebSocketConnectionEvent($type, error: $error)';
}

// ═════════════════════════════════════════════════════════════════════════════
// Handler
// ═════════════════════════════════════════════════════════════════════════════

/// Handler for Odoo WebSocket connections.
///
/// Provides real-time record change notifications that can be
/// used to keep local data in sync with the server.
///
/// Usage:
/// ```dart
/// final handler = OdooWebSocketHandler(config);
///
/// // Listen to record events
/// handler.recordEvents.listen((event) {
///   print('${event.model} ${event.operation}: ${event.recordId}');
/// });
///
/// // Connect
/// await handler.connect();
///
/// // Subscribe to models
/// handler.subscribe(['product.product', 'res.partner']);
/// ```
class OdooWebSocketHandler {
  final WebSocketConfig config;

  WebSocketChannel? _channel;
  StreamSubscription? _subscription;
  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;
  bool _isDisposed = false;

  // State streams
  final _state = ValueStream<WebSocketState>(
    WebSocketState.disconnected,
  );
  final _recordEvents = StreamController<OdooRecordEvent>.broadcast();
  final _connectionEvents = StreamController<WebSocketConnectionEvent>.broadcast();

  /// Stream of connection state changes.
  Stream<WebSocketState> get state => _state.stream;

  /// Current connection state.
  WebSocketState get currentState => _state.value;

  /// Whether currently connected.
  bool get isConnected => _state.value == WebSocketState.connected;

  /// Whether this handler has been disposed.
  bool get isDisposed => _isDisposed;

  /// Stream of record change events.
  Stream<OdooRecordEvent> get recordEvents => _recordEvents.stream;

  /// Stream of connection events.
  Stream<WebSocketConnectionEvent> get connectionEvents =>
      _connectionEvents.stream;

  OdooWebSocketHandler(this.config);

  /// Connect to the WebSocket server.
  ///
  /// Validates security before attempting connection.
  /// Throws [WebSocketSecurityException] or [SessionTokenRequiredException]
  /// if security requirements are not met.
  Future<void> connect() async {
    // Validate security before connecting
    config.validateSecurity();

    if (_state.value == WebSocketState.connecting) return;
    if (_state.value == WebSocketState.connected) return;

    _state.add(WebSocketState.connecting);

    try {
      final uri = Uri.parse(config.url);
      _channel = WebSocketChannel.connect(uri);

      // Wait for connection
      await _channel!.ready;

      _state.add(WebSocketState.connected);
      _reconnectAttempts = 0;

      _connectionEvents.add(WebSocketConnectionEvent(
        type: ConnectionEventType.connected,
        timestamp: DateTime.now(),
      ));

      // Start listening
      _subscription = _channel!.stream.listen(
        _handleMessage,
        onError: _handleError,
        onDone: _handleDone,
      );

      // Send authentication/subscription
      _authenticate();

      // Start ping timer
      _startPingTimer();
    } catch (e) {
      _state.add(WebSocketState.error);
      _connectionEvents.add(WebSocketConnectionEvent(
        type: ConnectionEventType.error,
        timestamp: DateTime.now(),
        error: e.toString(),
      ));

      if (config.autoReconnect) {
        _scheduleReconnect();
      }
    }
  }

  /// Disconnect from the WebSocket server.
  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _reconnectTimer?.cancel();
    await _subscription?.cancel();
    await _channel?.sink.close();

    _channel = null;
    _subscription = null;

    if (!_isDisposed) {
      _state.add(WebSocketState.disconnected);
      _connectionEvents.add(WebSocketConnectionEvent(
        type: ConnectionEventType.disconnected,
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Subscribe to record changes for specific models.
  void subscribe(List<String> models) {
    if (!isConnected) return;

    _send({
      'type': 'subscribe',
      'models': models,
    });
  }

  /// Unsubscribe from record changes for specific models.
  void unsubscribe(List<String> models) {
    if (!isConnected) return;

    _send({
      'type': 'unsubscribe',
      'models': models,
    });
  }

  /// Dispose resources.
  ///
  /// Safe to call multiple times.
  Future<void> dispose() async {
    if (_isDisposed) return;
    _isDisposed = true;

    await disconnect();
    _state.close();
    _recordEvents.close();
    _connectionEvents.close();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private Methods
  // ═══════════════════════════════════════════════════════════════════════════

  void _authenticate() {
    _send({
      'type': 'authenticate',
      'database': config.database,
      'user_id': config.userId,
      if (config.sessionToken != null) 'session': config.sessionToken,
    });

    // Subscribe to initial models
    if (config.subscribedModels.isNotEmpty) {
      subscribe(config.subscribedModels);
    }
  }

  void _handleMessage(dynamic message) {
    try {
      final data = message is String
          ? jsonDecode(message) as Map<String, dynamic>
          : message as Map<String, dynamic>;

      final type = data['type'] as String?;

      switch (type) {
        case 'record_change':
          _handleRecordChange(data);
          break;

        case 'pong':
          // Keep-alive response
          break;

        case 'subscribed':
          // Subscription confirmed
          break;

        case 'error':
          _connectionEvents.add(WebSocketConnectionEvent(
            type: ConnectionEventType.error,
            timestamp: DateTime.now(),
            error: data['message']?.toString(),
          ));
          break;
      }
    } catch (e) {
      // Ignore parse errors
    }
  }

  void _handleRecordChange(Map<String, dynamic> data) {
    final model = data['model'] as String?;
    final recordId = data['record_id'] as int?;
    final operation = data['operation'] as String?;

    if (model == null || recordId == null || operation == null) return;

    OdooRecordAction action;
    switch (operation) {
      case 'create':
        action = OdooRecordAction.created;
        break;
      case 'write':
        action = OdooRecordAction.updated;
        break;
      case 'unlink':
        action = OdooRecordAction.deleted;
        break;
      default:
        return;
    }

    final values = data['data'] as Map<String, dynamic>? ?? const {};

    _recordEvents.add(OdooRecordEvent(
      model: model,
      recordId: recordId,
      action: action,
      values: values,
      writeDate: DateTime.now(),
    ));
  }

  void _handleError(dynamic error) {
    _state.add(WebSocketState.error);
    _connectionEvents.add(WebSocketConnectionEvent(
      type: ConnectionEventType.error,
      timestamp: DateTime.now(),
      error: error.toString(),
    ));

    if (config.autoReconnect) {
      _scheduleReconnect();
    }
  }

  void _handleDone() {
    if (_state.value == WebSocketState.disconnected) return;

    _state.add(WebSocketState.disconnected);
    _connectionEvents.add(WebSocketConnectionEvent(
      type: ConnectionEventType.disconnected,
      timestamp: DateTime.now(),
    ));

    if (config.autoReconnect) {
      _scheduleReconnect();
    }
  }

  void _scheduleReconnect() {
    if (config.maxReconnectAttempts > 0 &&
        _reconnectAttempts >= config.maxReconnectAttempts) {
      return;
    }

    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(
      Duration(milliseconds: config.reconnectDelayMs),
      () {
        _reconnectAttempts++;
        _state.add(WebSocketState.reconnecting);
        connect();
      },
    );
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) {
        if (isConnected) {
          _send({'type': 'ping'});
        }
      },
    );
  }

  void _send(Map<String, dynamic> data) {
    if (_channel != null) {
      _channel!.sink.add(jsonEncode(data));
    }
  }
}
