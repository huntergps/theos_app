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

final class DriftCatalogStore<T> implements LocalCatalogStore<T> {
  final RuntimeDatabaseOwner owner;
  final CatalogRowsWriter<T> writeRows;
  final CatalogRowsReader<T>? readRows;
  final Map<String, StreamController<CatalogState<T>>> _controllers = {};
  DriftCatalogStore({
    required this.owner,
    required this.writeRows,
    this.readRows,
  });

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
      await writeRows(runtime.database, batch.records, batch.cursor);
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

  String _key(AppScope scope) => 'catalog:${scope.scopeKey}';
}
