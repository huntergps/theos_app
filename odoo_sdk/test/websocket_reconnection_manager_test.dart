/// Tests for [WebSocketReconnectionManager], incluyendo el circuit breaker
/// suave agregado en Fase B (tarea 6).
///
/// A diferencia del grupo "Reconnection Logic" en websocket_test.dart (que
/// reimplementa la fórmula de backoff inline sin tocar la clase real), estos
/// tests instancian [WebSocketReconnectionManager] directamente.
import 'package:test/test.dart';

import 'package:odoo_sdk/src/websocket/websocket_reconnection_manager.dart';

void main() {
  group('WebSocketReconnectionManager', () {
    late WebSocketReconnectionManager manager;

    setUp(() {
      manager = WebSocketReconnectionManager();
    });

    tearDown(() {
      manager.cancel();
    });

    test('reconnectAttempts starts at 0 and wasReconnection is false', () {
      expect(manager.reconnectAttempts, equals(0));
      expect(manager.wasReconnection, isFalse);
      expect(manager.isCircuitBreakerActive, isFalse);
    });

    test('schedule() increments reconnectAttempts', () {
      manager.schedule(() async {});
      expect(manager.reconnectAttempts, equals(1));
      expect(manager.wasReconnection, isTrue);
    });

    test('schedule() does not queue a second timer while one is active', () {
      manager.schedule(() async {});
      final attemptsAfterFirst = manager.reconnectAttempts;

      // Llamar de nuevo mientras el timer anterior sigue activo no debe
      // incrementar el contador (guard `_reconnectTimer.isActive`).
      manager.schedule(() async {});
      expect(manager.reconnectAttempts, equals(attemptsAfterFirst));
    });

    test('reset() clears the attempt counter', () {
      manager.schedule(() async {});
      expect(manager.reconnectAttempts, greaterThan(0));

      manager.reset();
      expect(manager.reconnectAttempts, equals(0));
      expect(manager.wasReconnection, isFalse);
    });

    test(
      'circuit breaker is inactive below circuitBreakerThreshold attempts',
      () {
        for (var i = 0; i < WebSocketReconnectionManager.circuitBreakerThreshold; i++) {
          manager.cancel(); // permite que schedule() vuelva a programar
          manager.schedule(() async {});
        }
        expect(
          manager.reconnectAttempts,
          equals(WebSocketReconnectionManager.circuitBreakerThreshold),
        );
        expect(manager.isCircuitBreakerActive, isFalse);
      },
    );

    test(
      'circuit breaker activates after circuitBreakerThreshold consecutive attempts',
      () {
        // Superar el umbral: threshold + 1 intentos.
        for (var i = 0; i < WebSocketReconnectionManager.circuitBreakerThreshold + 1; i++) {
          manager.cancel();
          manager.schedule(() async {});
        }
        expect(
          manager.reconnectAttempts,
          equals(WebSocketReconnectionManager.circuitBreakerThreshold + 1),
        );
        expect(manager.isCircuitBreakerActive, isTrue);
      },
    );

    test('circuit breaker constants match documented values', () {
      // Umbral: 10 intentos. Intervalo: 5 minutos. Si esto cambia, el
      // comentario en la clase y este test deben actualizarse juntos.
      expect(WebSocketReconnectionManager.circuitBreakerThreshold, equals(10));
      expect(
        WebSocketReconnectionManager.circuitBreakerInterval,
        equals(const Duration(minutes: 5)),
      );
    });
  });
}
