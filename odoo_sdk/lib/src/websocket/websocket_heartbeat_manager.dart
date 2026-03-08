/// Internal heartbeat manager for OdooWebSocketService.
///
/// Handles periodic heartbeat messages to keep the WebSocket alive.
library;

import 'dart:async';
import 'dart:convert';

import '../services/logger_service.dart';
import 'websocket_connection_manager.dart';

/// Manages WebSocket heartbeat timer and messages.
class WebSocketHeartbeatManager {
  Timer? _heartbeatTimer;

  /// Last heartbeat timestamp for monitoring.
  DateTime? lastHeartbeat;

  /// Starts the periodic heartbeat timer.
  void start(Duration interval, WebSocketConnectionManager connection) {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer.periodic(
      interval,
      (_) => _sendHeartbeat(connection),
    );
  }

  /// Sends a single heartbeat message.
  void _sendHeartbeat(WebSocketConnectionManager connection) {
    if (!connection.isConnected || connection.channel == null) return;

    try {
      lastHeartbeat = DateTime.now();
      connection.channel!.sink.add(
        jsonEncode({
          'event_name': 'heartbeat',
          'data': {'timestamp': DateTime.now().millisecondsSinceEpoch},
        }),
      );
    } catch (e) {
      connection.lastError = 'Heartbeat error: $e';
      logger.e('[OdooWebSocket]', connection.lastError!);
    }
  }

  /// Stops the heartbeat timer.
  void stop() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }
}
