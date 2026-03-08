/// Related Field Service - App adapter
///
/// Bridges the generic RelatedFieldService from odoo_offline_core
/// with the Drift-backed RelatedRecordCache table in this app.
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as core;
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

export 'package:odoo_sdk/odoo_sdk.dart'
    show
        RelatedFieldService,
        RelatedFieldResult,
        RelatedRecordCacheStore,
        RelatedRecordCacheEntry;

/// Drift implementation of the RelatedRecordCacheStore.
class DriftRelatedRecordCacheStore implements core.RelatedRecordCacheStore {
  final AppDatabase _db;

  DriftRelatedRecordCacheStore({required AppDatabase db})
      : _db = db;

  @override
  Future<core.RelatedRecordCacheEntry?> get(String model, int odooId) async {
    final row = await (_db.select(_db.relatedRecordCache)
          ..where((t) => t.model.equals(model) & t.odooId.equals(odooId)))
        .getSingleOrNull();

    if (row == null) return null;

    return core.RelatedRecordCacheEntry(
      model: row.model,
      odooId: row.odooId,
      name: row.name,
      data: row.data == null || row.data!.isEmpty
          ? null
          : jsonDecode(row.data!) as Map<String, dynamic>,
      cachedAt: row.cachedAt,
      writeDate: row.writeDate,
    );
  }

  @override
  Future<void> upsert(core.RelatedRecordCacheEntry entry) async {
    final companion = RelatedRecordCacheCompanion(
      model: Value(entry.model),
      odooId: Value(entry.odooId),
      name: Value(entry.name),
      data: Value(entry.data == null ? null : jsonEncode(entry.data)),
      cachedAt: Value(entry.cachedAt),
      writeDate: Value(entry.writeDate),
    );

    final existing = await (_db.select(_db.relatedRecordCache)
          ..where((t) => t.model.equals(entry.model) &
              t.odooId.equals(entry.odooId)))
        .getSingleOrNull();

    if (existing == null) {
      await _db.into(_db.relatedRecordCache).insert(companion);
    } else {
      await (_db.update(_db.relatedRecordCache)
            ..where((t) =>
                t.model.equals(entry.model) & t.odooId.equals(entry.odooId)))
          .write(companion);
    }
  }

  @override
  Future<int> deleteByModel(String model) async {
    return (_db.delete(_db.relatedRecordCache)
          ..where((t) => t.model.equals(model)))
        .go();
  }

  @override
  Future<int> deleteRecord(String model, int odooId) async {
    return (_db.delete(_db.relatedRecordCache)
          ..where((t) => t.model.equals(model) & t.odooId.equals(odooId)))
        .go();
  }

  @override
  Future<int> deleteOlderThan(DateTime cutoff) async {
    return (_db.delete(_db.relatedRecordCache)
          ..where((t) => t.cachedAt.isSmallerThanValue(cutoff)))
        .go();
  }
}
