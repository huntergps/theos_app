import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/sync/sync_queued_operation_trigger.dart';

/// Contrato: drenar la cola de operaciones offline apenas se encola algo
/// ESTANDO EN LÍNEA, sin esperar el próximo filo de conectividad/primer
/// plano ni el respaldo periódico de 5 minutos. Falla medida el 14-sep-2026
/// (Orbi web contra Odoo real): un envío y una recepción de envases
/// quedaron "En espera, Intentos: 0" con "Conectado" y "Tiempo real:
/// conectado" ambos verdes, hasta que la persona pulsó "Sincronizar todo" a
/// mano — ver `sync_queued_operation_trigger.dart` para la causa raíz.
final class _CountingCoordinator implements SyncCoordinator {
  int runs = 0;
  final List<SyncReason> reasons = [];

  @override
  Future<void> start(AppScope scope) async {}

  @override
  Future<void> requestSync(SyncReason reason) async {
    runs++;
    reasons.add(reason);
  }

  @override
  Future<void> pause(PauseReason reason) async {}

  @override
  Future<void> stop(AppScope scope) async {}
}

void main() {
  test(
    'en línea, la cuenta pasa de 0 a 1 -> exactamente un requestSync con '
    'razón queued_operation y sólo el trabajo de operaciones',
    () async {
      final coordinator = _CountingCoordinator();
      final counts = StreamController<int>();
      final trigger = SyncQueuedOperationTrigger(
        coordinator: coordinator,
        pendingCount: counts.stream,
        online: Stream<bool>.value(true),
        debounce: const Duration(milliseconds: 20),
      );

      counts.add(0); // línea base — no es una subida
      await Future<void>.delayed(Duration.zero);
      counts.add(1); // subida real, con conexión
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(coordinator.runs, 1);
      expect(coordinator.reasons.single.code, 'queued_operation');
      expect(coordinator.reasons.single.onlyJobIds, {
        syncQueuedOperationJobId,
      });

      await trigger.dispose();
      await counts.close();
    },
  );

  test('sin conexión, la cuenta pasa de 0 a 1 -> ninguno', () async {
    final coordinator = _CountingCoordinator();
    final counts = StreamController<int>();
    final trigger = SyncQueuedOperationTrigger(
      coordinator: coordinator,
      pendingCount: counts.stream,
      online: Stream<bool>.value(false),
      debounce: const Duration(milliseconds: 20),
    );

    counts.add(0);
    await Future<void>.delayed(Duration.zero);
    counts.add(1);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(coordinator.runs, 0);

    await trigger.dispose();
    await counts.close();
  });

  test(
    'la cuenta igual o menor nunca dispara (sin bucle cuando un reintento '
    'falla y la operación sigue pendiente)',
    () async {
      final coordinator = _CountingCoordinator();
      final counts = StreamController<int>();
      final trigger = SyncQueuedOperationTrigger(
        coordinator: coordinator,
        pendingCount: counts.stream,
        online: Stream<bool>.value(true),
        debounce: const Duration(milliseconds: 20),
      );

      counts.add(2); // línea base
      await Future<void>.delayed(Duration.zero);
      counts.add(1); // 2 -> 1: baja, no dispara
      await Future<void>.delayed(const Duration(milliseconds: 40));
      counts.add(1); // 1 -> 1: igual, no dispara
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(coordinator.runs, 0);

      await trigger.dispose();
      await counts.close();
    },
  );

  test(
    'varias subidas dentro del debounce producen un solo pedido',
    () async {
      final coordinator = _CountingCoordinator();
      final counts = StreamController<int>();
      final trigger = SyncQueuedOperationTrigger(
        coordinator: coordinator,
        pendingCount: counts.stream,
        online: Stream<bool>.value(true),
        debounce: const Duration(milliseconds: 50),
      );

      counts.add(0); // línea base
      await Future<void>.delayed(Duration.zero);
      counts.add(1); // subida 1
      await Future<void>.delayed(const Duration(milliseconds: 15));
      counts.add(2); // subida 2, funde el temporizador anterior
      await Future<void>.delayed(const Duration(milliseconds: 15));
      counts.add(3); // subida 3, vuelve a fundir
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(coordinator.runs, 1);

      await trigger.dispose();
      await counts.close();
    },
  );

  test('tras dispose, ninguno', () async {
    final coordinator = _CountingCoordinator();
    final counts = StreamController<int>();
    final trigger = SyncQueuedOperationTrigger(
      coordinator: coordinator,
      pendingCount: counts.stream,
      online: Stream<bool>.value(true),
      debounce: const Duration(milliseconds: 20),
    );

    counts.add(0); // línea base
    await Future<void>.delayed(Duration.zero);
    await trigger.dispose();

    counts.add(1); // ya nadie escucha
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(coordinator.runs, 0);

    await counts.close();
  });
}
