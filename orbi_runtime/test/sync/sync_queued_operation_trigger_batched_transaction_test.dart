import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/sync/sync_queued_operation_trigger.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Hueco medido el 14-sep-2026 en la primera versión de
/// `SyncQueuedOperationTrigger` (la que escuchaba
/// `watchPendingOperationCount()`, un `Stream<int>`): Drift junta en una
/// sola notificación las actualizaciones de tabla que ocurren dentro de la
/// MISMA transacción. Si el drenaje borra una operación X ya resuelta y, en
/// esa misma transacción, la persona encola una operación Y nueva, el
/// conteo total de pendientes emite el MISMO número (1→1) — la subida de Y
/// y la bajada de X se cancelan antes de llegar al stream, y un disparador
/// que sólo reacciona a SUBIDAS del conteo se queda callado. Y quedaría "En
/// espera, Intentos: 0" — el mismo síntoma que este disparador existe para
/// resolver.
///
/// Esta prueba reproduce exactamente esa transacción con la cola REAL
/// (Drift en memoria) y comprueba que el coordinador recibe el pedido.
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
    'borrar X y encolar Y en UNA sola transacción, en línea, dispara '
    'exactamente un requestSync',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final queue = OfflineQueueDataSource(db);

      // X: una operación ya pendiente, como si el drenaje anterior la
      // hubiera dejado en la cola.
      final xId = await queue.queueOperation(
        model: 'sale.order',
        method: 'write',
        recordId: 7,
        values: const {'note': 'x'},
      );

      final coordinator = _CountingCoordinator();
      final trigger = SyncQueuedOperationTrigger(
        coordinator: coordinator,
        queuedInserts: queue.watchQueuedInserts(),
        online: Stream<bool>.value(true),
        debounce: const Duration(milliseconds: 20),
      );

      // Deja que la señal de red se asiente antes de tocar la cola.
      await Future<void>.delayed(const Duration(milliseconds: 20));

      // La transacción que reproduce el hueco: X sale (se resolvió) y Y
      // entra (la persona encoló algo nuevo), ambas dentro de la MISMA
      // transacción de Drift — exactamente lo que agrupa `notifyUpdates`.
      await db.transaction(() async {
        await queue.removeOperation(xId);
        await queue.queueOperation(
          model: 'sale.order',
          method: 'write',
          recordId: 7,
          values: const {'note': 'y'},
        );
      });

      await Future<void>.delayed(const Duration(milliseconds: 80));

      expect(
        coordinator.runs,
        1,
        reason:
            'Borrar X y encolar Y en la misma transacción debe seguir '
            'disparando un drenaje. Si esto da 0, el disparador está '
            'escuchando un CONTEO (que se cancela 1→1 en esta transacción) '
            'en vez de watchQueuedInserts() — exactamente el hueco medido '
            'en la primera versión (commit adfe4a2).',
      );
      expect(coordinator.reasons.single.code, 'queued_operation');
      expect(coordinator.reasons.single.onlyJobIds, {
        syncQueuedOperationJobId,
      });

      await trigger.dispose();
    },
  );
}
