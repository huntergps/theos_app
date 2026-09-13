import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/sync/sync_auto_resync_trigger.dart';

/// Contrato: la app re-sincroniza sola en los momentos en que retomar tiene
/// sentido, sin que la persona tenga que abrir «Sincronización» y pulsar
/// «Reintentar» a mano — prioridad del dueño (13-sep-2026) sobre el frente
/// de conectividad/offline-first. Antes de este archivo, `requestSync` sólo
/// se llamaba una vez al abrir el scope y bajo ese botón manual; nada
/// escuchaba la red ni el ciclo de vida de la app (medido en la auditoría
/// del 13-sep-2026: cero `Timer.periodic`, cero listener de
/// `networkSignalProvider` fuera del pie de página).
final class _CountingCoordinator implements SyncCoordinator {
  int runs = 0;
  final List<String> reasons = [];

  @override
  Future<void> start(AppScope scope) async {}

  @override
  Future<void> requestSync(SyncReason reason) async {
    runs++;
    reasons.add(reason.code);
  }

  @override
  Future<void> pause(PauseReason reason) async {}

  @override
  Future<void> stop(AppScope scope) async {}
}

void main() {
  test('reconectar (sin red -> con red) dispara exactamente un ciclo', () async {
    final coordinator = _CountingCoordinator();
    final online = StreamController<bool>();
    final trigger = SyncAutoResyncTrigger(
      coordinator: coordinator,
      online: online.stream,
      debounce: const Duration(milliseconds: 20),
    );

    online.add(false); // estado inicial: sin red — no es un filo
    await Future<void>.delayed(Duration.zero);
    online.add(true); // vuelve la red — filo real
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(coordinator.runs, 1);
    expect(coordinator.reasons.single, contains('online'));

    await trigger.dispose();
    await online.close();
  });

  test('volver a primer plano dispara exactamente un ciclo', () async {
    final coordinator = _CountingCoordinator();
    final foreground = StreamController<bool>();
    final trigger = SyncAutoResyncTrigger(
      coordinator: coordinator,
      online: const Stream<bool>.empty(),
      foreground: foreground.stream,
      debounce: const Duration(milliseconds: 20),
    );

    foreground.add(false); // en segundo plano — estado inicial, no es filo
    await Future<void>.delayed(Duration.zero);
    foreground.add(true); // vuelve a primer plano — filo real
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(coordinator.runs, 1);
    expect(coordinator.reasons.single, contains('foreground'));

    await trigger.dispose();
    await foreground.close();
  });

  test(
    'tres cambios seguidos en ~100ms producen a lo sumo un ciclo adicional, '
    'nunca uno por cambio',
    () async {
      final coordinator = _CountingCoordinator();
      final online = StreamController<bool>();
      final trigger = SyncAutoResyncTrigger(
        coordinator: coordinator,
        online: online.stream,
        debounce: const Duration(milliseconds: 50),
      );

      online.add(true); // estado inicial "con red" — no es filo
      await Future<void>.delayed(Duration.zero);
      // Parpadeo de red: tres filos de falso a verdadero en ~100ms.
      online.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      online.add(true); // filo 1
      await Future<void>.delayed(const Duration(milliseconds: 15));
      online.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      online.add(true); // filo 2
      await Future<void>.delayed(const Duration(milliseconds: 15));
      online.add(false);
      await Future<void>.delayed(const Duration(milliseconds: 15));
      online.add(true); // filo 3
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(
        coordinator.runs,
        lessThanOrEqualTo(1),
        reason:
            'Un parpadeo de red no debe disparar una ráfaga de ciclos; cada '
            'filo debe reprogramar el mismo temporizador, nunca sumar uno '
            'nuevo por filo. runs=${coordinator.runs}',
      );

      await trigger.dispose();
      await online.close();
    },
  );

  test('el primer valor de una señal nunca cuenta como filo', () async {
    final coordinator = _CountingCoordinator();
    final online = StreamController<bool>();
    final trigger = SyncAutoResyncTrigger(
      coordinator: coordinator,
      online: online.stream,
      debounce: const Duration(milliseconds: 20),
    );

    online.add(true); // primer valor ya "con red": no describe una vuelta
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(coordinator.runs, 0);

    await trigger.dispose();
    await online.close();
  });
}
