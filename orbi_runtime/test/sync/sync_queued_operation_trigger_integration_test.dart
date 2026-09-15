import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/envases/envases_operations.dart';
import 'package:orbi_runtime/src/envases/envases_operations_durable.dart';
import 'package:orbi_runtime/src/sales/sale_runtime_adapters.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';
import 'package:orbi_runtime/src/sync/sync_queued_operation_trigger.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Prueba de integración de la cola REAL (Drift en memoria, igual que
/// `envases_operations_durable_test.dart`): encolar un envío de envases
/// ESTANDO EN LÍNEA debe drenar la cola sola, sin que la persona pulse
/// "Sincronizar todo" a mano.
///
/// Contra 39ace0f (antes de `SyncQueuedOperationTrigger`) este archivo
/// DEBE fallar: nada escucha `watchPendingOperationCount()`, así que el
/// coordinador falso nunca recibe `requestSync`. Se demuestra comentando el
/// disparador (ver la nota `SIN DISPARADOR` más abajo) y corriendo el
/// archivo — pégale la salida a la evidencia del encargo.
class _MockSaleOdooActions extends Mock implements SaleOdooActions {}

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
    'encolar un envío de envases en línea drena la cola sola, sin '
    '"Sincronizar todo" manual',
    () async {
      final actions = _MockSaleOdooActions();
      when(
        () => actions.call(
          model: any(named: 'model'),
          method: 'fields_get',
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        ),
      ).thenAnswer(
        (_) async => {
          'envases_operacion_uuid': {'type': 'char'},
        },
      );

      final scope = AppScope(
        appId: 'orbi',
        installationId: 'install-1',
        normalizedServerUrl: 'https://erp.test',
        database: 'db',
        userId: 7,
      );
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      );
      final db = await owner.open(scope);
      await ensureEnvasesOperationsSchema(db.database);
      final company = CompanyContext.forScope(
        scope: scope,
        companyId: 1,
        allowedCompanyIds: const [1],
        capabilityRevision: 1,
      );
      final durable = DurableEnvasesOperations(
        owner: owner,
        lease: db.lease,
        company: company,
        actions: actions,
      );

      final queue = OfflineQueueDataSource(db.database);
      final coordinator = _CountingCoordinator();

      // SIN DISPARADOR: para reproducir la falla contra 39ace0f, comenta el
      // bloque de abajo (deja `trigger` sin construir/usar) y corre este
      // archivo — `coordinator.runs` se queda en 0 porque nadie escucha la
      // cola.
      final trigger = SyncQueuedOperationTrigger(
        coordinator: coordinator,
        pendingCount: queue.watchPendingOperationCount(),
        online: Stream<bool>.value(true),
        debounce: const Duration(milliseconds: 20),
      );

      // Deja que la línea base (0 pendientes) se registre antes de encolar.
      await Future<void>.delayed(const Duration(milliseconds: 30));

      await durable.enviar(
        EnvasesEnviarCommand(
          operacionUuid: 'uuid-trigger-1',
          origenId: 10,
          destinoId: 20,
          fechaSalida: DateTime.utc(2026, 9, 13, 8),
          lineas: const [EnvasesEnvioLinea(productId: 5, cantidad: 3)],
        ),
      );

      await Future<void>.delayed(const Duration(milliseconds: 100));

      expect(
        coordinator.runs,
        1,
        reason:
            'Encolar en línea debe drenar solo, sin esperar "Sincronizar '
            'todo" a mano. Si esto da 0, revisa que '
            'SyncQueuedOperationTrigger esté conectado a '
            'watchPendingOperationCount() — contra 39ace0f no existía '
            'ningún disparador escuchando la cola, y esta prueba fallaba '
            'exactamente así.',
      );
      expect(coordinator.reasons.single.code, 'queued_operation');
      expect(coordinator.reasons.single.onlyJobIds, {
        syncQueuedOperationJobId,
      });

      await trigger.dispose();
      await owner.close();
    },
  );
}
