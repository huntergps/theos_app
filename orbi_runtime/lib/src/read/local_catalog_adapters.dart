import 'dart:convert';
import 'dart:async';

import 'package:drift/drift.dart';

import 'package:odoo_sdk/odoo_sdk.dart' as odoo;
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
        PaymentConfigRecordMapper,
        FieldSelectionDatasource,
        ResLangCompanion,
        ResCountryCompanion,
        ResCountryStateCompanion,
        ResGroupsCompanion,
        ResUsersCompanion;

// PartnerRecordMapper is also a concrete core mapper.

// De preferencias-odoo (`orbi_runtime/lib/src/account/`): sólo se USA su
// clase pública, este archivo no la edita. Ver la nota en
// writeCurrentUserRecords.
import '../account/user_preferences.dart' show FieldAvailabilityCache;
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
// res.lang / res.country / res.country.state / res.groups — catálogos de
// referencia que necesita "Mis preferencias" (theos_panel/lib/features/account).
// Mismo patrón exists-then-update-or-insert que PartnerRecordMapper.upsert,
// usando los helpers ya probados de odoo_sdk (extractMany2oneId,
// toStringOrNull, parseOdooDateTime, parseOdooBool, parseOdooStringRequired)
// en vez de repetir su parseo a mano.
// ============================================================================

Future<void> writeLanguageRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    final d = record.value;
    final id = d['id'];
    if (id is! int || id <= 0) throw const FormatException('res.lang id');
    // `insertOnConflictUpdate` a secas conflicta por la PK autoincremental
    // (`id`), NUNCA por `odoo_id` — lo dice su propia doc ("By default, only
    // the primary key is used"). Sin `target` explícito, cada pasada de sync
    // insertaría una fila NUEVA con el mismo `odoo_id` y violaría su UNIQUE,
    // en vez de actualizar la existente. Medido con la prueba (h) del
    // encargo de sync-cuenta el 13-sep-2026.
    final companion = ResLangCompanion.insert(
      odooId: id,
      name: odoo.parseOdooStringRequired(d['name']),
      code: odoo.parseOdooStringRequired(d['code']),
      active: Value(odoo.parseOdooBool(d['active'], defaultValue: true)),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    await db
        .into(db.resLang)
        .insert(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [db.resLang.odooId],
          ),
        );
  }
}

Future<List<CatalogRecord<Map<String, dynamic>>>> readLanguageRecords(
  AppDatabase db,
) async => (await db.select(db.resLang).get())
    .map(
      (r) => CatalogRecord(
        uuid: 'language:${r.odooId}',
        value: {'id': r.odooId, 'name': r.name, 'code': r.code},
      ),
    )
    .toList(growable: false);

Future<void> deleteLanguageRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(db.resLang)..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> writeCountryRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    final d = record.value;
    final id = d['id'];
    if (id is! int || id <= 0) throw const FormatException('res.country id');
    // Ver la nota en writeLanguageRecords: el target explícito es lo que
    // hace que esto conflicte por `odoo_id`, no por la PK autoincremental.
    final companion = ResCountryCompanion.insert(
      odooId: id,
      name: odoo.parseOdooStringRequired(d['name']),
      code: Value(odoo.toStringOrNull(d['code'])),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    await db
        .into(db.resCountry)
        .insert(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [db.resCountry.odooId],
          ),
        );
  }
}

Future<List<CatalogRecord<Map<String, dynamic>>>> readCountryRecords(
  AppDatabase db,
) async => (await db.select(db.resCountry).get())
    .map(
      (r) => CatalogRecord(
        uuid: 'country:${r.odooId}',
        value: {'id': r.odooId, 'name': r.name, 'code': r.code},
      ),
    )
    .toList(growable: false);

Future<void> deleteCountryRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(db.resCountry)..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> writeCountryStateRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    final d = record.value;
    final id = d['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('res.country.state id');
    }
    // Ver la nota en writeLanguageRecords: el target explícito es lo que
    // hace que esto conflicte por `odoo_id`, no por la PK autoincremental.
    final companion = ResCountryStateCompanion.insert(
      odooId: id,
      name: odoo.parseOdooStringRequired(d['name']),
      code: Value(odoo.toStringOrNull(d['code'])),
      countryId: Value(odoo.extractMany2oneId(d['country_id'])),
      countryName: Value(odoo.extractMany2oneName(d['country_id'])),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    await db
        .into(db.resCountryState)
        .insert(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [db.resCountryState.odooId],
          ),
        );
  }
}

Future<List<CatalogRecord<Map<String, dynamic>>>> readCountryStateRecords(
  AppDatabase db,
) async => (await db.select(db.resCountryState).get())
    .map(
      (r) => CatalogRecord(
        uuid: 'country-state:${r.odooId}',
        value: {
          'id': r.odooId,
          'name': r.name,
          'code': r.code,
          'country_id': r.countryId,
        },
      ),
    )
    .toList(growable: false);

Future<void> deleteCountryStateRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(db.resCountryState)..where((t) => t.odooId.isIn(ids))).go();
}

Future<void> writeGroupRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    final d = record.value;
    final id = d['id'];
    if (id is! int || id <= 0) throw const FormatException('res.groups id');
    // `category_id` no existe en Odoo 19/20 (reemplazado por `privilege_id`,
    // ver res_groups.py en dev_odoo20) pero sí en versiones anteriores —
    // `selfDescribingLoader` sólo lo pide si `fields_get` lo confirma, así
    // que aquí puede o no venir. `xml_id` nunca llega (no es un campo real,
    // ver la nota en `selfDescribingLoader`): esa columna se queda `null`.
    //
    // Target explícito: ver la nota en writeLanguageRecords — conflicta por
    // `odoo_id`, no por la PK autoincremental.
    final companion = ResGroupsCompanion.insert(
      odooId: id,
      name: odoo.parseOdooStringRequired(d['name']),
      fullName: Value(odoo.toStringOrNull(d['full_name'])),
      categoryId: Value(odoo.extractMany2oneId(d['category_id'])),
      categoryName: Value(odoo.extractMany2oneName(d['category_id'])),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    await db
        .into(db.resGroups)
        .insert(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [db.resGroups.odooId],
          ),
        );
  }
}

Future<List<CatalogRecord<Map<String, dynamic>>>> readGroupRecords(
  AppDatabase db,
) async => (await db.select(db.resGroups).get())
    .map(
      (r) => CatalogRecord(
        uuid: 'group:${r.odooId}',
        value: {'id': r.odooId, 'name': r.name, 'full_name': r.fullName},
      ),
    )
    .toList(growable: false);

Future<void> deleteGroupRecords(AppDatabase db, List<int> ids) async {
  if (ids.isEmpty) return;
  await (db.delete(db.resGroups)..where((t) => t.odooId.isIn(ids))).go();
}

// ============================================================================
// Usuario y partner de la sesión activa — "Mis preferencias"
// (theos_panel/lib/features/account). Ver RuntimeAccountLoader en
// json2_read_adapters.dart para cómo se resuelven los campos.
// ============================================================================

Future<void> writeCurrentUserRecords(
  AppDatabase db,
  List<CatalogRecord<Map<String, dynamic>>> records,
  String? cursor,
) async {
  for (final record in records) {
    final d = record.value;
    final id = d['id'];
    if (id is! int || id <= 0) throw const FormatException('res.users id');

    final selections = d['_field_selections'];
    if (selections is Map) {
      final datasource = FieldSelectionDatasource(db);
      for (final entry in selections.entries) {
        final field = entry.key;
        final value = entry.value;
        if (field is String && value is List) {
          await datasource.upsertFieldSelection('res.users', field, value);
        }
      }
    }

    // `FieldAvailabilityCache` (orbi_runtime/lib/src/account/user_preferences.dart):
    // "Mis preferencias" la lee sin red para decidir si mostrar el campo
    // `mobile_phone`/`property_warehouse_id`. `markUnavailable` es lo que
    // hace que un módulo desinstalado (p. ej. `sale_stock`) no deje un
    // marcador viejo diciendo "disponible" para siempre — sin esto, una
    // segunda pasada donde el campo ya no viene en `fields_get` no bastaba
    // para que el marcador de una pasada ANTERIOR desapareciera.
    final availability = d['_field_availability'];
    if (availability is Map) {
      final availabilityCache = FieldAvailabilityCache(db);
      for (final entry in availability.entries) {
        final field = entry.key;
        if (field is! String) continue;
        if (entry.value == true) {
          await availabilityCache.markAvailable(field);
        } else {
          await availabilityCache.markUnavailable(field);
        }
      }
    }

    final groupIds = d['group_ids'];
    final groupIdsJson = groupIds is List
        ? jsonEncode(
            groupIds.whereType<num>().map((v) => v.toInt()).toList(),
          )
        : null;

    // Sólo puede haber UN usuario "actual" a la vez: si la sesión cambió de
    // uid entre un ciclo y otro (relogin en la misma base local), la fila
    // vieja se queda huérfana con la marca puesta si no se limpia antes.
    await (db.update(
      db.resUsers,
    )..where((t) => t.odooId.equals(id).not())).write(
      const ResUsersCompanion(isCurrentUser: Value(false)),
    );

    // Target explícito: ver la nota en writeLanguageRecords — conflicta por
    // `odoo_id`, no por la PK autoincremental. Aquí importa doble: sin esto,
    // cada ciclo de sync duplicaba también la fila del usuario actual.
    final companion = ResUsersCompanion.insert(
      odooId: id,
      name: odoo.parseOdooStringRequired(d['name']),
      login: odoo.parseOdooStringRequired(d['login']),
      lang: Value(odoo.toStringOrNull(d['lang'])),
      tz: Value(odoo.toStringOrNull(d['tz'])),
      signature: Value(odoo.toStringOrNull(d['signature'])),
      partnerId: Value(odoo.extractMany2oneId(d['partner_id'])),
      companyId: Value(odoo.extractMany2oneId(d['company_id'])),
      propertyWarehouseId: Value(
        odoo.extractMany2oneId(d['property_warehouse_id']),
      ),
      avatar128: Value(odoo.toStringOrNull(d['avatar_128'])),
      notificationType: Value(odoo.toStringOrNull(d['notification_type'])),
      workEmail: Value(odoo.toStringOrNull(d['work_email'])),
      workPhone: Value(odoo.toStringOrNull(d['work_phone'])),
      mobilePhone: Value(odoo.toStringOrNull(d['mobile_phone'])),
      groupIds: Value(groupIdsJson),
      isCurrentUser: const Value(true),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    await db
        .into(db.resUsers)
        .insert(
          companion,
          onConflict: DoUpdate(
            (_) => companion,
            target: [db.resUsers.odooId],
          ),
        );
  }
}

/// Protege el partner de la sesión actual de las bajas del catálogo
/// `customers` (`res.partner` con `customer_rank > 0`). Sin esto, el barrido
/// de "salida de dominio" de `RuntimeCatalogLoader._fetchDomainExitIds`
/// —pensado para productos/clientes que se archivan— también atrapa al
/// propio usuario cuando su partner NO es cliente (`customer_rank == 0`, el
/// caso normal de un vendedor): su `write_date` cambia por cualquier motivo,
/// el escaneo negado de `customers.domain` lo encuentra, y
/// `DriftCatalogStore.commit` lo borra de `res_partner` aunque lo acabe de
/// escribir esta misma sincronización. Confirmado con una prueba en
/// `test/read/current_account_test.dart` (mutando `neverDeleteIds` a `null`
/// para ver el borrado ocurrir).
///
/// Instancia única por `RuntimeCatalogComposition` (una por activación,
/// igual que `RuntimeCatalogLoader`) — nunca un singleton global: ver
/// ADR-03 en `docs/orbi_panel/ARCHITECTURE.md`.
final class CurrentAccountPartnerGuard {
  int? _partnerId;

  void update(int? partnerId) => _partnerId = partnerId;

  Set<int> get protectedIds =>
      _partnerId == null ? const <int>{} : {_partnerId!};
}

/// Fábrica, no una función suelta: captura [guard] para que la protección de
/// [CurrentAccountPartnerGuard] se actualice en cada ciclo. Reutiliza
/// [PartnerRecordMapper.upsert] — la misma escritura que ya usa el catálogo
/// `customers` — así que un usuario que SÍ es cliente (`customer_rank > 0`)
/// no arrastra dos representaciones de su fila.
CatalogRowsWriter<Map<String, dynamic>> writeCurrentUserPartnerRecords(
  CurrentAccountPartnerGuard guard,
) {
  return (db, records, cursor) async {
    if (records.isEmpty) {
      guard.update(null);
      return;
    }
    for (final record in records) {
      final id = record.value['id'];
      await PartnerRecordMapper.upsert(db, record.value);
      guard.update(id is int ? id : null);
    }
  };
}

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
  'lang': 'res.lang',
  'country': 'res.country',
  'countryState': 'res.country.state',
  'groups': 'res.groups',
  // Sin deleter (single record, ver writeCurrentUserRecords/
  // writeCurrentUserPartnerRecords) pero SÍ necesitan la guarda de
  // `offline_queue`: si "Mis preferencias" encoló un cambio de `res.users`/
  // `res.partner` que todavía no sincronizó, este catálogo no debe pisarlo
  // con la versión vieja del servidor en el próximo ciclo.
  'currentUser': 'res.users',
  'currentUserPartner': 'res.partner',
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
  'lang': deleteLanguageRecords,
  'country': deleteCountryRecords,
  'countryState': deleteCountryStateRecords,
  'groups': deleteGroupRecords,
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

  /// Ids que este catálogo NUNCA debe borrar, sin importar lo que traiga
  /// [CatalogBatch.deletedIds] o la diferencia contra
  /// [CatalogBatch.remoteActiveIds]. Existe para el catálogo `partner`
  /// (clientes, `customer_rank > 0`): su barrido de "salida de dominio"
  /// atrapa al partner del usuario de la sesión cuando éste NO es cliente —
  /// ver [CurrentAccountPartnerGuard] en este mismo archivo, que es quien
  /// arma el `Set` que se pasa aquí. `null` (el valor de todos los catálogos
  /// de siempre) es "no proteger nada", igual que antes de que este campo
  /// existiera.
  final Set<int> Function()? neverDeleteIds;

  DriftCatalogStore({
    required this.owner,
    required this.name,
    required this.writeRows,
    this.readRows,
    this.deleteRows,
    this.pendingOperationModel,
    this.neverDeleteIds,
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
        toDelete.removeAll(neverDeleteIds?.call() ?? const <int>{});
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
