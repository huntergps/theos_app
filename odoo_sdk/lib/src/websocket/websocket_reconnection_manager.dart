/// Internal reconnection manager for OdooWebSocketService.
///
/// Handles exponential backoff reconnection logic.
library;

import 'dart:async';
import 'dart:math';

import '../services/logger_service.dart';

/// Manages WebSocket reconnection with exponential backoff.
///
/// Incluye un "circuit breaker suave" (Fase B, tarea 6): tras
/// [circuitBreakerThreshold] intentos consecutivos fallidos, el intervalo
/// entre reintentos se espacia a [circuitBreakerInterval] en vez de seguir
/// tope en ~120s. Esto evita bombardear un servidor caído por horas sin
/// dejar de reintentar NUNCA — es un POS: la meta es reconectar tarde o
/// temprano, no rendirse.
class WebSocketReconnectionManager {
  Timer? _reconnectTimer;
  int _reconnectAttempts = 0;

  /// Umbral de intentos consecutivos a partir del cual se activa el circuit
  /// breaker suave.
  static const int circuitBreakerThreshold = 10;

  /// Intervalo fijo entre intentos una vez activado el circuit breaker.
  static const Duration circuitBreakerInterval = Duration(minutes: 5);

  /// Current number of reconnection attempts.
  int get reconnectAttempts => _reconnectAttempts;

  /// Whether a reconnection was pending (attempts > 0) before last reset.
  bool get wasReconnection => _reconnectAttempts > 0;

  /// Si el intento actual (o el próximo a programarse) ya cruzó el umbral
  /// del circuit breaker suave.
  bool get isCircuitBreakerActive => _reconnectAttempts > circuitBreakerThreshold;

  /// Schedules a reconnection attempt with exponential backoff.
  ///
  /// Delay formula: `min(120, 2^attempt * 2)` seconds with ±20 % jitter,
  /// starting at ~2 s for the first attempt. Tras
  /// [circuitBreakerThreshold] intentos consecutivos, el delay pasa a ser
  /// fijo: [circuitBreakerInterval] (5 min).
  ///
  /// | Attempt   | Delay                              |
  /// |-----------|-------------------------------------|
  /// | 1         | ~2 s                                |
  /// | 2         | ~4 s                                |
  /// | 3         | ~8 s                                |
  /// | 4         | ~16 s                               |
  /// | 5+        | 32–120 s (con jitter, hasta ~144 s) |
  /// | 11+       | 5 min fijos (circuit breaker activo) |
  ///
  /// [onReconnect] is called after the delay to perform the actual reconnection.
  void schedule(Future<void> Function() onReconnect) {
    if (_reconnectTimer != null && _reconnectTimer!.isActive) return;

    _reconnectAttempts++;

    final Duration delay;
    if (isCircuitBreakerActive) {
      delay = circuitBreakerInterval;
      logger.w(
        '[OdooWebSocket]',
        'Circuit breaker activo: $_reconnectAttempts intentos de reconexión '
            'consecutivos fallidos. Espaciando reintentos a '
            '${circuitBreakerInterval.inMinutes} min (sin dejar de '
            'reintentar).',
      );
    } else {
      // Exponential backoff: 2^attempt * 2 seconds, capped at 120 s
      final baseSeconds = min(120, pow(2, _reconnectAttempts).toInt() * 2);
      // ±20 % jitter to spread reconnect bursts (e.g. after a server restart)
      final jitter = (baseSeconds * 0.2 * (Random().nextDouble() * 2 - 1)).round();
      final delaySeconds = (baseSeconds + jitter).clamp(1, 144);
      delay = Duration(seconds: delaySeconds);
    }

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
