import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/security/inactivity_lock_trigger.dart';

void main() {
  // Contra 90a37dc este archivo no compila: `inactivity_lock_trigger.dart`
  // no existe todavía, así que las pruebas de este bloque fallan por falta
  // del propio disparador, no por una aserción concreta.
  test('locks after N minutes without interaction', () {
    fakeAsync((async) {
      var locks = 0;
      final trigger = InactivityLockTrigger(
        lockAfter: () => const Duration(minutes: 15),
        now: async.getClock(DateTime.utc(2026, 9, 14, 8)).now,
        onLock: () => locks++,
      );
      addTearDown(trigger.dispose);

      async.elapse(const Duration(minutes: 14, seconds: 59));
      expect(locks, 0, reason: 'todavía no se cumplen los 15 minutos');

      async.elapse(const Duration(seconds: 1));
      expect(locks, 1, reason: 'se cumplieron los 15 minutos sin actividad');
    });
  });

  test('interaction resets the countdown', () {
    fakeAsync((async) {
      var locks = 0;
      final clock = async.getClock(DateTime.utc(2026, 9, 14, 8));
      final trigger = InactivityLockTrigger(
        lockAfter: () => const Duration(minutes: 15),
        now: clock.now,
        onLock: () => locks++,
      );
      addTearDown(trigger.dispose);

      async.elapse(const Duration(minutes: 14));
      expect(locks, 0);

      // Un toque a los 14 minutos reinicia la cuenta.
      trigger.recordInteraction(clock.now());
      async.elapse(const Duration(minutes: 14));
      expect(
        locks,
        0,
        reason:
            'la interacción a los 14 min reinició la cuenta; sólo pasaron '
            '14 min más desde entonces',
      );

      async.elapse(const Duration(minutes: 1));
      expect(locks, 1, reason: 'ahora sí se cumplieron los 15 min desde el toque');
    });
  });

  test('uses server-provided minutes', () {
    fakeAsync((async) {
      var locks = 0;
      var minutes = 5;
      final trigger = InactivityLockTrigger(
        lockAfter: () => Duration(minutes: minutes),
        now: async.getClock(DateTime.utc(2026, 9, 14, 8)).now,
        onLock: () => locks++,
      );
      addTearDown(trigger.dispose);

      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(locks, 0);
      async.elapse(const Duration(seconds: 1));
      expect(locks, 1, reason: 'N=5 del snapshot del servidor, no 15');
      // Se usa `minutes` (variable, no constante) para dejar constancia de
      // que `lockAfter` es una función leída en cada tic, no un valor
      // congelado al construir el disparador.
      expect(minutes, 5);
    });
  });

  test('does not lock again after already locking without a fresh interaction', () {
    fakeAsync((async) {
      var locks = 0;
      final trigger = InactivityLockTrigger(
        lockAfter: () => const Duration(minutes: 15),
        now: async.getClock(DateTime.utc(2026, 9, 14, 8)).now,
        onLock: () => locks++,
      );
      addTearDown(trigger.dispose);

      async.elapse(const Duration(minutes: 15));
      expect(locks, 1);
      async.elapse(const Duration(minutes: 30));
      expect(locks, 1, reason: 'ya bloqueado: no vuelve a llamar a onLock solo');
    });
  });

  group('shouldStartLocked', () {
    final deviceNow = DateTime.utc(2026, 9, 14, 12);

    test('reopening after the deadline starts locked', () {
      final result = shouldStartLocked(
        persistedLastInteraction: deviceNow.subtract(
          const Duration(minutes: 20),
        ),
        deviceNow: deviceNow,
        lockAfter: const Duration(minutes: 15),
      );
      expect(result, isTrue);
    });

    test('reopening before the deadline stays unlocked', () {
      final result = shouldStartLocked(
        persistedLastInteraction: deviceNow.subtract(
          const Duration(minutes: 10),
        ),
        deviceNow: deviceNow,
        lockAfter: const Duration(minutes: 15),
      );
      expect(result, isFalse);
    });

    test('device clock behind last interaction starts locked', () {
      // La "última interacción" persistida queda 10 minutos ADELANTE de la
      // hora actual del equipo — el reloj retrocedió.
      final result = shouldStartLocked(
        persistedLastInteraction: deviceNow.add(const Duration(minutes: 10)),
        deviceNow: deviceNow,
        lockAfter: const Duration(minutes: 15),
      );
      expect(result, isTrue);
    });

    test('no persisted interaction never invents a lock', () {
      final result = shouldStartLocked(
        persistedLastInteraction: null,
        deviceNow: deviceNow,
        lockAfter: const Duration(minutes: 15),
      );
      expect(result, isFalse);
    });
  });
}
