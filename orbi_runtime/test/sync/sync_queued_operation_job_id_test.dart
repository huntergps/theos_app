import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

/// `SyncQueuedOperationTrigger` pide el drenaje pasando
/// `onlyJobIds: {syncQueuedOperationJobId}` — una cadena repetida a mano en
/// `sync_queued_operation_trigger.dart` para no acoplar ese archivo a
/// `operations_sync_job.dart`. Esta prueba es la correa que evita que las
/// dos cadenas se separen en silencio: si alguien cambia
/// `OperationsSyncJob.id` sin actualizar `syncQueuedOperationJobId`, el
/// disparador seguiría compilando y pasando sus propias pruebas, pero en
/// producción `SyncCoordinatorImpl.requestSync` jamás encontraría un
/// `SyncJob` con ese id y el drenaje pedido no correría nunca — el mismo
/// síntoma ("En espera, Intentos: 0") por una vía distinta.
final class _NoopAdapter implements OfflineOperationAdapter {
  @override
  Future<OperationReconciliation> reconcile(OfflineOperation operation) async {
    return const OperationNotApplied();
  }

  @override
  Future<ConflictInfo?> dispatch(OfflineOperation operation) async => null;
}

void main() {
  test(
    'syncQueuedOperationJobId coincide con el id real de OperationsSyncJob',
    () {
      final job = OperationsSyncJob(
        queue: OfflineQueueDataSource(AppDatabase(NativeDatabase.memory())),
        adapter: _NoopAdapter(),
      );

      expect(syncQueuedOperationJobId, job.id);
    },
  );
}
