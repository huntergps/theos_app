/// Internal reconnection manager for OdooWebSocketService.
///
/// Handles exponential backoff reconnection logic.
library;

import 'dart:async';

/// Manages WebSocket reconnection with exponential backoff.
class WebSocketReconnectionManager {
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  /// Current number of reconnection attempts.
  int get reconnectAttempts => _reconnectAttempts;

  /// Whether a reconnection was pending (attempts > 0) before last reset.
  bool get wasReconnection => _reconnectAttempts > 0;

  /// Schedules a reconnection attempt with exponential backoff.
  ///
  /// [onReconnect] is called after the delay to perform the actual reconnection.
  void schedule(Future<void> Function() onReconnect) {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    _reconnectAttempts++;
    final delay = Duration(seconds: (5 * _reconnectAttempts).clamp(10, 120));

    _reconnectTimer = Timer(delay, () {
      onReconnect();
    });
  }

  /// Resets the reconnection counter (e.g., after a successful connection).
  void reset() {
    _reconnectAttempts = 0;
  }

  /// Cancels any pending reconnection timer.
  void cancel() {
    _reconnectTimer?.cancel();
  }
}
