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
///
/// 🔴 Revisión del 14-sep-2026: la señal pasó de un `Stream<int>` (conteo
/// de pendientes) a un `Stream<void>` (un evento por INSERT real en la
/// cola) porque el conteo se cancelaba cuando la misma transacción de
/// Drift borraba una operación resuelta y encolaba una nueva a la vez
/// (1→1) — ver `theos_pos_core/.../offline_queue_datasource.dart`,
/// `watchQueuedInserts`.
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
    'en línea, una inserción -> exactamente un requestSync con razón '
    'queued_operation y sólo el trabajo de operaciones',
    () async {
      final coordinator = _CountingCoordinator();
      final inserts = StreamController<void>();
      final trigger = SyncQueuedOperationTrigger(
        coordinator: coordinator,
        queuedInserts: inserts.stream,
        online: Stream<bool>.value(true),
        debounce: const Duration(milliseconds: 20),
      );

      // Deja que la señal de red se asiente antes de la inserción.
      await Future<void>.delayed(Duration.zero);
      inserts.add(null);
      await Future<void>.delayed(const Duration(milliseconds: 60));

      expect(coordinator.runs, 1);
      expect(coordinator.reasons.single.code, 'queued_operation');
      expect(coordinator.reasons.single.onlyJobIds, {
        syncQueuedOperationJobId,
      });

      await trigger.dispose();
      await inserts.close();
    },
  );

  test('sin conexión, una inserción -> ninguno', () async {
    final coordinator = _CountingCoordinator();
    final inserts = StreamController<void>();
    final trigger = SyncQueuedOperationTrigger(
      coordinator: coordinator,
      queuedInserts: inserts.stream,
      online: Stream<bool>.value(false),
      debounce: const Duration(milliseconds: 20),
    );

    await Future<void>.delayed(Duration.zero);
    inserts.add(null);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(coordinator.runs, 0);

    await trigger.dispose();
    await inserts.close();
  });

  test(
    'varias inserciones dentro del debounce producen un solo pedido',
    () async {
      final coordinator = _CountingCoordinator();
      final inserts = StreamController<void>();
      final trigger = SyncQueuedOperationTrigger(
        coordinator: coordinator,
        queuedInserts: inserts.stream,
        online: Stream<bool>.value(true),
        debounce: const Duration(milliseconds: 50),
      );

      await Future<void>.delayed(Duration.zero);
      inserts.add(null); // inserción 1
      await Future<void>.delayed(const Duration(milliseconds: 15));
      inserts.add(null); // inserción 2, funde el temporizador anterior
      await Future<void>.delayed(const Duration(milliseconds: 15));
      inserts.add(null); // inserción 3, vuelve a fundir
      await Future<void>.delayed(const Duration(milliseconds: 150));

      expect(coordinator.runs, 1);

      await trigger.dispose();
      await inserts.close();
    },
  );

  test('tras dispose, ninguno', () async {
    final coordinator = _CountingCoordinator();
    final inserts = StreamController<void>();
    final trigger = SyncQueuedOperationTrigger(
      coordinator: coordinator,
      queuedInserts: inserts.stream,
      online: Stream<bool>.value(true),
      debounce: const Duration(milliseconds: 20),
    );

    await Future<void>.delayed(Duration.zero);
    await trigger.dispose();

    inserts.add(null); // ya nadie escucha
    await Future<void>.delayed(const Duration(milliseconds: 60));

    expect(coordinator.runs, 0);

    await inserts.close();
  });
}
