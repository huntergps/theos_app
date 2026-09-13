import 'dart:convert';
import 'dart:async';

import 'package:drift/drift.dart';

import 'package:theos_pos_core/theos_pos_core.dart'
    show
        AppDatabase,
        ProductRecordMapper,
        WarehouseRecordMapper,
        PricelistRecordMapper,
        PaymentTermRecordMapper,
        TaxRecordMapper,
        PartnerRecordMapper,
        JournalRecordMapper,
        UomRecordMapper,
        CollectionConfigRecordMapper,
        CollectionSessionRecordMapper,
        PaymentConfigRecordMapper;

// PartnerRecordMapper is also a concrete core mapper.

import '../contracts.dart';
import '../storage/runtime_database_owner.dart';
import '../sync/catalog_sync.dart';

/// Atomic bridge between the generic sync job and existing Drift tables.
/// Concrete mappers are supplied by composition, where generated companions
/// are available; runtime does not duplicate schema or model definitions.
typedef CatalogRowsWriter<T> = Future<void> Function(
  AppDatabase database,
  List<CatalogRecord<T>> records,
  String? cursor,
);
typedef CatalogRowsReader<T> = Future<List<CatalogRecord<T>>> Function(
  AppDatabase database,
);

/// Removes local rows by Odoo id. Symmetric counterpart of
/// [CatalogRowsWriter]; concrete stores decide which Drift table to hit.
typedef CatalogRowsDeleter<T> = Future<void> Function(
  AppDatabase database,
  List<int> odooIds,
);

/// Production product mapper used by the runtime composition.
Future<void> writeProductRecords(
  AppDatabase database,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await ProductRecordMapper.upsert(database, record.value);
  }
}

Future<void> writeWarehouseRecords(
  AppDatabase database,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await WarehouseRecordMapper.upsert(database, record.value);
  }
}

Future<void> writePricelistRecords(
  AppDatabase database,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await PricelistRecordMapper.upsert(database, record.value);
  }
}

Future<void> writePaymentTermRecords(
  AppDatabase database,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await PaymentTermRecordMapper.upsert(database, record.value);
  }
}

Future<void> writeTaxRecords(
  AppDatabase database,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await TaxRecordMapper.upsert(database, record.value);
  }
}

Future<void> writePartnerRecords(
  AppDatabase database,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await PartnerRecordMapper.upsert(database, record.value);
  }
}

Future<List<CatalogRecord<Map<String, dynamic>>>> readPartnerRecords(
  AppDatabase database,
) async =>
    (await PartnerRecordMapper.read(database))
        .map((row) => CatalogRecord(uuid: 'partner:${row['id']}', value: row))
        .toList(growable: false);

Future<void> writeJournalRecords(
  AppDatabase database,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await JournalRecordMapper.upsert(database, record.value);
  }
}

Future<List<CatalogRecord<Map<String, dynamic>>>> readProductRecords(
  AppDatabase db,
) async => (await db.select(db.productProduct).get())
    .map(
      (r) => CatalogRecord(
        uuid: 'product:${r.odooId}',
        value: {'id': r.odooId, 'name': r.name, 'list_price': r.listPrice},
      ),
    )
    .toList(growable: false);
Future<List<CatalogRecord<Map<String, dynamic>>>> readWarehouseRecords(
  AppDatabase db,
) async => (await db.select(db.stockWarehouse).get())
    .map(
      (r) => CatalogRecord(
        uuid: 'warehouse:${r.odooId}',
        value: {'id': r.odooId, 'name': r.name, 'code': r.code},
      ),
    )
    .toList(growable: false);
Future<List<CatalogRecord<Map<String, dynamic>>>> readPricelistRecords(
  AppDatabase db,
) async => (await db.select(db.productPricelist).get())
    .map(
      (r) => CatalogRecord(
        uuid: 'pricelist:${r.odooId}',
        value: {'id': r.odooId, 'name': r.name},
      ),
    )
    .toList(growable: false);
Future<List<CatalogRecord<Map<String, dynamic>>>> readPaymentTermRecords(
  AppDatabase db,
) async => (await db.select(db.accountPaymentTerm).get())
    .map(
      (r) => CatalogRecord(
        uuid: 'payment-term:${r.odooId}',
        value: {'id': r.odooId, 'name': r.name},
      ),
    )
    .toList(growable: false);
Future<List<CatalogRecord<Map<String, dynamic>>>> readTaxRecords(
  AppDatabase db,
) async => (await db.select(db.accountTax).get())
    .map(
      (r) => CatalogRecord(
        uuid: 'tax:${r.odooId}',
        value: {'id': r.odooId, 'name': r.name, 'amount': r.amount},
      ),
    )
    .toList(growable: false);

Future<void> writeUomRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await UomRecordMapper.upsert(db, record.value);
  }
}

Future<void> writeCollectionConfigRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await CollectionConfigRecordMapper.upsert(db, record.value);
  }
}

Future<List<CatalogRecord<Map<String, dynamic>>>> readCollectionConfigRecords(
  AppDatabase db,
) async => (await db.select(db.collectionConfig).get())
    .map(
      (r) => CatalogRecord(
        uuid: 'collection-config:${r.odooId}',
        value: {
          'id': r.odooId,
          'name': r.name,
          'code': r.code,
          'company_id': r.companyId,
          'current_session_id': r.currentSessionId,
        },
      ),
    )
    .toList(growable: false);

Future<void> writeCollectionSessionRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await CollectionSessionRecordMapper.upsert(db, record.value);
  }
}

Future<void> writeCardBrandRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await PaymentConfigRecordMapper.upsertCardBrand(db, record.value);
  }
}

Future<void> writeCardDeadlineRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await PaymentConfigRecordMapper.upsertCardDeadline(db, record.value);
  }
}

Future<void> writeCardLoteRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await PaymentConfigRecordMapper.upsertCardLote(db, record.value);
  }
}

Future<void> writePaymentMethodLineRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    await PaymentConfigRecordMapper.upsertPaymentMethodLine(db, record.value);
  }
}

Future<List<CatalogRecord<Map<String, dynamic>>>> readCardBrandRecords(
  AppDatabase db,
) async => (await PaymentConfigRecordMapper.readCardBrands(db))
    .map((row) => CatalogRecord(uuid: 'card-brand:${row['id']}', value: row))
    .toList(growable: false);

Future<List<CatalogRecord<Map<String, dynamic>>>> readCardDeadlineRecords(
  AppDatabase db,
) async => (await PaymentConfigRecordMapper.readCardDeadlines(db))
    .map((row) => CatalogRecord(uuid: 'card-deadline:${row['id']}', value: row))
    .toList(growable: false);

Future<List<CatalogRecord<Map<String, dynamic>>>> readCardLoteRecords(
  AppDatabase db,
) async =>
    (await PaymentConfigRecordMapper.readCardLotes(db))
        .map((row) => CatalogRecord(uuid: 'card-lote:${row['id']}', value: row))
        .toList(growable: false);

Future<List<CatalogRecord<Map<String, dynamic>>>> readPaymentMethodLineRecords(
  AppDatabase db,
) async => (await PaymentConfigRecordMapper.readPaymentMethodLines(db))
    .map(
      (row) =>
          CatalogRecord(uuid: 'payment-method-line:${row['id']}', value: row),
    )
    .toList(growable: false);

Future<List<CatalogRecord<Map<String, dynamic>>>> readCollectionSessionRecords(
  AppDatabase db,
) async => (await db.select(db.collectionSession).get())
    .map(
      (r) => CatalogRecord(
        uuid: 'collection-session:${r.odooId}',
        value: {
          'id': r.odooId,
          'session_uuid': r.sessionUuid,
          'name': r.name,
          'state': r.state,
          'config_id': r.configId,
          'user_id': r.userId,
        },
      ),
    )
    .toList(growable: false);

Future<List<CatalogRecord<Map<String, dynamic>>>> readUomRecords(
  AppDatabase db,
) async =>
    (await UomRecordMapper.read(db))
        .map((r) => CatalogRecord(uuid: 'uom:${r['id']}', value: r))
        .toList(growable: false);

Future<List<CatalogRecord<Map<String, dynamic>>>> readJournalRecords(
  AppDatabase database,
) async =>
    (await JournalRecordMapper.read(database))
        .map((row) => CatalogRecord(uuid: 'journal:${row['id']}', value: row))
        .toList(growable: false);

// ============================================================================
// Deletion by Odoo id, one per catalog. Symmetric with the writers above:
// each function knows only its own Drift table, never another catalog's.
// ============================================================================

Future<void> deletePartnerRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(db.resPartner)..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deleteProductRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(db.productProduct)..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deleteWarehouseRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(db.stockWarehouse)..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deletePricelistRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(
    db.productPricelist,
  )..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deletePaymentTermRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(
    db.accountPaymentTerm,
  )..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deleteTaxRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(db.accountTax)..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deleteUomRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(db.uomUom)..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deleteJournalRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(db.accountJournal)..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deleteCollectionConfigRecords(
  AppDatabase db,
  List<int> ids,
) async {
  if (ids.isEmpty) return;
  await (db.delete(
    db.collectionConfig,
  )..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deleteCollectionSessionRecords(
  AppDatabase db,
  List<int> ids,
) async {
  if (ids.isEmpty) return;
  await (db.delete(
    db.collectionSession,
  )..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deleteCardBrandRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(
    db.accountCreditCardBrand,
  )..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deleteCardDeadlineRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(
    db.accountCreditCardDeadline,
  )..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deleteCardLoteRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(db.accountCardLote)..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> deletePaymentMethodLineRecords(
  AppDatabase db,
  List<int> ids,
) async {
  if (ids.isEmpty) return;
  await (db.delete(
    db.accountPaymentMethodLine,
  )..where((t) => t.odooId.isIn(ids))).go();
}

/// Catalog name → Odoo model. Necessarily duplicates
/// `RuntimeCatalogComposition`'s own `specs` map (composition owns the
/// wiring and is out of scope for this change — see the audit's phased plan
/// in `docs/orbi_panel/reports/TIEMPO_REAL_Y_GLOBAL_REFERENCIA_2026_09_13.md`).
/// Used only to make the pending-offline-queue guard work without touching
/// `runtime_catalog_composition.dart`; if a catalog key changes there, it
/// must change here too.
const Map<String, String> _catalogOdooModels = {
  'partner': 'res.partner',
  'product': 'product.product',
  'paymentTerm': 'account.payment.term',
  'uom': 'uom.uom',
  'collectionConfig': 'collection.config',
  'collectionSession': 'collection.session',
  'tax': 'account.tax',
  'pricelist': 'product.pricelist',
  'warehouse': 'stock.warehouse',
  'journal': 'account.journal',
  'cardBrand': 'account.credit.card.brand',
  'cardDeadline': 'account.credit.card.deadline',
  'cardLote': 'account.card.lote',
  'paymentMethodLine': 'account.payment.method.line',
};

/// Catalog name → its deleter. Same rationale/coupling as
/// [_catalogOdooModels]: it lets deletions and the pending-queue guard work
/// for the fourteen real catalogs today, by name convention, without editing
/// `runtime_catalog_composition.dart`.
final Map<String, CatalogRowsDeleter<Map<String, dynamic>>>
_defaultCatalogDeleters = {
  'partner': deletePartnerRecords,
  'product': deleteProductRecords,
  'paymentTerm': deletePaymentTermRecords,
  'uom': deleteUomRecords,
  'collectionConfig': deleteCollectionConfigRecords,
  'collectionSession': deleteCollectionSessionRecords,
  'tax': deleteTaxRecords,
  'pricelist': deletePricelistRecords,
  'warehouse': deleteWarehouseRecords,
  'journal': deleteJournalRecords,
  'cardBrand': deleteCardBrandRecords,
  'cardDeadline': deleteCardDeadlineRecords,
  'cardLote': deleteCardLoteRecords,
  'paymentMethodLine': deletePaymentMethodLineRecords,
};

final class DriftCatalogStore<T> implements LocalCatalogStore<T> {
  final RuntimeDatabaseOwner owner;
  final CatalogRowsWriter<T> writeRows;
  final CatalogRowsReader<T>? readRows;
  final Map<String, StreamController<CatalogState<T>>> _controllers = {};
  /// Nombre del catálogo. Es obligatorio porque la fila de metadatos se
  /// direcciona con él: sin nombre, los catorce catálogos escribían su cursor
  /// y su error en la MISMA fila (`catalog:<scope>`), y el último en
  /// sincronizar pisaba a todos los anteriores. Eso no sólo perdía el error
  /// —también el cursor, que es lo que decide desde dónde continúa la
  /// siguiente sincronización.
  final String name;

  /// Borra filas por id de Odoo. Opcional y con valor por defecto: si quien
  /// construye este store no lo pasa (como hace hoy
  /// `RuntimeCatalogComposition`, que este cambio no toca), se usa
  /// [_defaultCatalogDeleters] indexado por [name] — así las bajas funcionan
  /// para los catorce catálogos reales sin tocar la composición.
  final CatalogRowsDeleter<T>? deleteRows;

  /// Modelo de Odoo de este catálogo, sólo para mirar `offline_queue` antes
  /// de borrar o sobrescribir una fila. Igual que [deleteRows]: si no se
  /// pasa, se resuelve por [name] contra [_catalogOdooModels].
  final String? pendingOperationModel;

  DriftCatalogStore({
    required this.owner,
    required this.name,
    required this.writeRows,
    this.readRows,
    this.deleteRows,
    this.pendingOperationModel,
  });

  CatalogRowsDeleter<T>? get _effectiveDeleteRows {
    final own = deleteRows;
    if (own != null) return own;
    final fallback = _defaultCatalogDeleters[name];
    return fallback is CatalogRowsDeleter<T> ? fallback : null;
  }

  String? get _effectivePendingModel =>
      pendingOperationModel ?? _catalogOdooModels[name];

  @override
  Future<CatalogState<T>> read(AppScope scope) async {
    final runtime = owner.active;
    if (runtime == null || runtime.scope != scope) return CatalogState<T>();
    final rows = await runtime.database
        .customSelect(
          'SELECT value FROM sync_metadata WHERE key = ?',
          variables: [Variable<String>(_key(scope))],
        )
        .get();
    final row = rows.isEmpty ? null : rows.first.data['value'] as String?;
    if (row == null) return CatalogState<T>();
    final value = jsonDecode(row);
    final records = readRows == null
        ? <CatalogRecord<T>>[]
        : await readRows!(runtime.database);
    return CatalogState<T>(
      records: records,
      cursor: value is Map ? value['cursor'] as String? : null,
      error: value is Map ? value['error'] : null,
    );
  }

  @override
  Stream<CatalogState<T>> watch(AppScope scope) async* {
    final controller = _controllers.putIfAbsent(
      scope.scopeKey,
      () => StreamController<CatalogState<T>>.broadcast(),
    );
    yield await read(scope);
    yield* controller.stream;
  }

  @override
  Future<void> commit(AppScope scope, CatalogBatch<T> batch) async {
    final runtime = owner.active;
    if (runtime == null || runtime.scope != scope) {
      throw StateError('Catalog commit requires the active scope');
    }
    await runtime.database.transaction(() async {
      final pendingModel = _effectivePendingModel;
      final pendingIds = pendingModel == null
          ? const <int>{}
          : await _pendingRecordIds(runtime.database, pendingModel);

      // Nunca se pisa una fila con una operación sin resolver en
      // `offline_queue`: se salta el upsert y queda para el próximo ciclo,
      // como conflicto implícito (ver el contrato en `LocalCatalogStore`).
      final recordsToWrite = pendingIds.isEmpty
          ? batch.records
          : batch.records
                .where((record) => !pendingIds.contains(_idOf(record.value)))
                .toList(growable: false);
      await writeRows(runtime.database, recordsToWrite, batch.cursor);

      final deleter = _effectiveDeleteRows;
      if (deleter != null) {
        final toDelete = <int>{...batch.deletedIds};
        final activeIds = batch.remoteActiveIds;
        if (activeIds != null && readRows != null) {
          final localIds = (await readRows!(runtime.database))
              .map((record) => _idOf(record.value))
              .whereType<int>()
              .toSet();
          toDelete.addAll(localIds.difference(activeIds));
        }
        toDelete.removeAll(pendingIds);
        if (toDelete.isNotEmpty) {
          await deleter(
            runtime.database,
            toDelete.toList(growable: false),
          );
        }
      }

      await runtime.database.customStatement(
        'INSERT OR REPLACE INTO sync_metadata (key, value) VALUES (?, ?)',
        [
          _key(scope),
          jsonEncode({'cursor': batch.cursor}),
        ],
      );
    });
    _controllers[scope.scopeKey]?.add(await read(scope));
  }

  /// Ids con una operación en `offline_queue` que todavía no terminó
  /// (cualquier estado salvo `completed`: `pending`, `processing`,
  /// `recovery_pending`, `conflict`, `dead_letter` — todos representan una
  /// escritura local que un servidor remoto no puede pisar en silencio).
  static Future<Set<int>> _pendingRecordIds(
    AppDatabase database,
    String model,
  ) async {
    final rows = await database
        .customSelect(
          'SELECT record_id FROM offline_queue '
          'WHERE model = ? AND status != ? AND record_id IS NOT NULL',
          variables: [Variable<String>(model), Variable<String>('completed')],
        )
        .get();
    return rows
        .map((row) => row.data['record_id'])
        .whereType<int>()
        .toSet();
  }

  static int? _idOf(Object? value) {
    if (value is Map) {
      final id = value['id'];
      if (id is int) return id;
    }
    return null;
  }

  @override
  Future<void> recordError(AppScope scope, Object error) async {
    final runtime = owner.active;
    if (runtime == null || runtime.scope != scope) return;
    final prior = await read(scope);
    await runtime.database.customStatement(
      'INSERT OR REPLACE INTO sync_metadata (key, value) VALUES (?, ?)',
      [
        _key(scope),
        jsonEncode({'cursor': prior.cursor, 'error': '$error'}),
      ],
    );
    _controllers[scope.scopeKey]?.add(await read(scope));
  }

  // Al estrenar el nombre, la fila vieja compartida queda huérfana y cada
  // catálogo arranca sin cursor: hará una carga completa una vez y volverá a
  // tener el suyo. Es preferible a seguir leyendo el cursor de otro catálogo.
  String _key(AppScope scope) => 'catalog:$name:${scope.scopeKey}';
}
