import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

/// Contrato: la cola de operaciones offline drena ANTES de sincronizar
/// catálogos (CLAUDE.md, «Fronteras que el código respeta de facto» —
/// «un ciclo a la vez, y drena la cola durable antes de sincronizar
/// catálogos»). `SyncCoordinatorImpl` ejecuta `_jobs` en el orden en que
/// los recibe (`sync_coordinator_impl.dart:120`), así que el contrato real
/// vive aquí: en qué orden `RuntimeCatalogComposition` inserta las claves
/// del `Map<String, SyncJob>` que expone.
class _FakeReader implements Json2ReadPort {
  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async => const <Map<String, dynamic>>[];
}

final class _Adapter implements OfflineOperationAdapter {
  @override
  Future<OperationReconciliation> reconcile(OfflineOperation operation) async =>
      const OperationNotApplied();

  @override
  Future<ConflictInfo?> dispatch(OfflineOperation operation) async => null;
}

void main() {
  test('el job "operations" es la primera clave del grafo, antes que cualquier catálogo', () async {
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    final scope = AppScope(
      appId: 'panel',
      installationId: 'i',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 2,
    );
    final database = await owner.open(scope);
    addTearDown(owner.close);

    final operationsJob = OperationsSyncJob(
      queue: OfflineQueueDataSource(database.database),
      adapter: _Adapter(),
    );

    final composition = RuntimeCatalogComposition(
      activation: SessionActivation(database: database),
      owner: owner,
      reader: _FakeReader(),
      operationsJob: operationsJob,
    );

    final order = composition.jobs.keys.toList();
    expect(
      order.first,
      'operations',
      reason:
          'Orden real del grafo de sincronización: $order. Si "operations" '
          'no es el primero, la cola de ventas/cobros pendientes espera '
          'detrás de los 14 catálogos en vez de drenarse primero.',
    );
  });
}
