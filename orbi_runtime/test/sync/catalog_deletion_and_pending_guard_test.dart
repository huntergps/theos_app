import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show AppDatabase, OfflineQueueDataSource, OfflineQueueCompanion;
// Import directo, sin pasar por el barril `orbi_runtime.dart`: éste no
// necesita nada de `src/realtime/`, y así el test no depende de que ese
// módulo (en obras por otro agente) compile.
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/read/local_catalog_adapters.dart';
import 'package:orbi_runtime/src/storage/runtime_database_owner.dart';
import 'package:orbi_runtime/src/sync/catalog_sync.dart';

/// Contrato encargado por el coordinador (13-sep-2026): un catálogo debe
/// reflejar en local lo que se borró en Odoo (con y sin `sync.deleted.record`)
/// y nunca pisar una fila local con una operación pendiente en
/// `offline_queue`.
///
/// `DriftCatalogStore` se construye aquí exactamente como lo hace
/// `RuntimeCatalogComposition` — `owner`, `name`, `writeRows`, `readRows`,
/// SIN pasar `deleteRows` ni `pendingOperationModel` — para probar que los
/// catorce catálogos reales quedan cubiertos por los valores por defecto
/// (`_catalogOdooModels`/`_defaultCatalogDeleters` en
/// `local_catalog_adapters.dart`) sin tocar `runtime_catalog_composition.dart`.
void main() {
  late RuntimeDatabaseOwner owner;
  late AppScope scope;

  setUp(() async {
    owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase.memory()),
    );
    scope = AppScope(
      appId: 'panel',
      installationId: 'i',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 2,
    );
    await owner.open(scope);
  });

  tearDown(() => owner.close());

  DriftCatalogStore<Map<String, dynamic>> productStore() =>
      DriftCatalogStore<Map<String, dynamic>>(
        owner: owner,
        name: 'product',
        writeRows: writeProductRecords,
        readRows: readProductRecords,
      );

  test(
    'B: un id que sync.deleted.record reporta como borrado desaparece de Drift',
    () async {
      final store = productStore();
      await store.commit(
        scope,
        CatalogBatch(
          records: const [
            CatalogRecord(uuid: 'p7', value: {'id': 7, 'name': 'Producto'}),
          ],
          cursor: 'c1',
        ),
      );
      expect(await readProductRecords(owner.active!.database), hasLength(1));

      await store.commit(
        scope,
        const CatalogBatch(records: [], cursor: 'c2', deletedIds: [7]),
      );

      expect(await readProductRecords(owner.active!.database), isEmpty);
    },
  );

  test('C: en un servidor sin sync.deleted.record, la reconciliación por ids '
      'borra el local que ya no existe', () async {
    final store = productStore();
    await store.commit(
      scope,
      CatalogBatch(
        records: const [
          CatalogRecord(uuid: 'p7', value: {'id': 7, 'name': 'Producto 7'}),
          CatalogRecord(uuid: 'p8', value: {'id': 8, 'name': 'Producto 8'}),
        ],
        cursor: 'c1',
      ),
    );
    expect(await readProductRecords(owner.active!.database), hasLength(2));

    // El servidor ya no tiene el 8 (sin `sync.deleted.record`, esto sólo se
    // sabe comparando el conjunto COMPLETO de ids activos remotos).
    await store.commit(
      scope,
      const CatalogBatch(records: [], cursor: 'c2', remoteActiveIds: {7}),
    );

    final remaining = await readProductRecords(owner.active!.database);
    expect(remaining.map((row) => row.value['id']), [7]);
  });

  test(
    'D: una fila con operación pendiente en la cola no se borra ni se pisa',
    () async {
      final store = productStore();
      await store.commit(
        scope,
        CatalogBatch(
          records: const [
            CatalogRecord(
              uuid: 'p7',
              value: {'id': 7, 'name': 'Producto local sin sincronizar'},
            ),
          ],
          cursor: 'c1',
        ),
      );

      // Encola una operación pendiente contra el producto 7 (p. ej. un precio
      // editado offline que todavía no se sincronizó).
      await OfflineQueueDataSource(owner.active!.database).queueOperation(
        model: 'product.product',
        method: 'write',
        recordId: 7,
        values: const {'list_price': 12.5},
      );

      // El servidor manda una versión distinta del mismo id, Y TAMBIÉN lo
      // reporta borrado en el mismo ciclo: ninguna de las dos debe aplicarse
      // mientras la cola tenga la operación sin resolver.
      await store.commit(
        scope,
        CatalogBatch(
          records: const [
            CatalogRecord(
              uuid: 'p7',
              value: {'id': 7, 'name': 'Versión remota'},
            ),
          ],
          cursor: 'c2',
          deletedIds: const [7],
        ),
      );

      final rows = await readProductRecords(owner.active!.database);
      expect(rows.single.value['name'], 'Producto local sin sincronizar');
    },
  );

  test(
    '4: un registro que salió del dominio (p. ej. se desactivó) pero tiene '
    'una operación pendiente tampoco se borra',
    () async {
      // El mecanismo de "salida de dominio" en json2_read_adapters.dart
      // termina volcando sus ids en el MISMO `deletedIds` que
      // `sync.deleted.record` — así que la guarda de `offline_queue` de aquí
      // los cubre igual, sin distinguir de dónde vino el id.
      final store = productStore();
      await store.commit(
        scope,
        CatalogBatch(
          records: const [
            CatalogRecord(
              uuid: 'p7',
              value: {'id': 7, 'name': 'Editado offline, aún sin subir'},
            ),
          ],
          cursor: 'c1',
        ),
      );
      await OfflineQueueDataSource(owner.active!.database).queueOperation(
        model: 'product.product',
        method: 'write',
        recordId: 7,
        values: const {'list_price': 9.99},
      );

      // El escaneo de salida de dominio reporta el 7 como archivado.
      await store.commit(
        scope,
        const CatalogBatch(records: [], cursor: 'c2', deletedIds: [7]),
      );

      final rows = await readProductRecords(owner.active!.database);
      expect(rows.single.value['name'], 'Editado offline, aún sin subir');
    },
  );

  test('D bis: una operación ya completada deja de proteger la fila', () async {
    final store = productStore();
    await store.commit(
      scope,
      CatalogBatch(
        records: const [
          CatalogRecord(uuid: 'p7', value: {'id': 7, 'name': 'Original'}),
        ],
        cursor: 'c1',
      ),
    );
    final opId = await OfflineQueueDataSource(owner.active!.database)
        .queueOperation(
          model: 'product.product',
          method: 'write',
          recordId: 7,
          values: const {'list_price': 12.5},
        );
    await (owner.active!.database.update(owner.active!.database.offlineQueue)
          ..where((t) => t.id.equals(opId)))
        .write(const OfflineQueueCompanion(status: Value('completed')));

    await store.commit(
      scope,
      CatalogBatch(
        records: const [
          CatalogRecord(uuid: 'p7', value: {'id': 7, 'name': 'Versión remota'}),
        ],
        cursor: 'c2',
      ),
    );

    final rows = await readProductRecords(owner.active!.database);
    expect(rows.single.value['name'], 'Versión remota');
  });
}
