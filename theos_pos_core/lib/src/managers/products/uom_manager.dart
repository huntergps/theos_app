/// UomManager extensions - Business methods beyond generated CRUD
///
/// The base UomManager is generated in uom.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/products/uom.model.dart';

/// Extension methods for UomManager
extension UomManagerBusiness on UomManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  /// Get UoM by Odoo ID (alias for readLocal)
  Future<Uom?> getUom(int odooId) => readLocal(odooId);

  /// Get all active UoMs
  Future<List<Uom>> getUoms() async {
    final results = await (_db.select(_db.uomUom)
          ..where((t) => t.active.equals(true))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
        .get();
    return results.map((r) => fromDrift(r)).toList();
  }

  /// Get all UoMs including inactive
  Future<List<Uom>> getAllUoms() async {
    final results = await (_db.select(_db.uomUom)
          ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
        .get();
    return results.map((r) => fromDrift(r)).toList();
  }

  /// Get UoMs by category ID
  Future<List<Uom>> getUomsByCategory(int categoryId) async {
    final results = await (_db.select(_db.uomUom)
          ..where((t) => t.categoryId.equals(categoryId) & t.active.equals(true))
          ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]))
        .get();
    return results.map((r) => fromDrift(r)).toList();
  }

  /// Get reference UoM for a category
  Future<Uom?> getReferenceUom(int categoryId) async {
    final result = await (_db.select(_db.uomUom)
          ..where((t) =>
              t.categoryId.equals(categoryId) &
              t.uomType.equals('reference') &
              t.active.equals(true)))
        .getSingleOrNull();
    return result != null ? fromDrift(result) : null;
  }

  /// Upsert a UoM directly from WebSocket payload
  Future<void> upsertUomFromWebSocket({
    required int odooId,
    required String name,
    int? categoryId,
    String? categoryName,
    String uomType = 'reference',
    double factor = 1.0,
    double factorInv = 1.0,
    double rounding = 0.01,
    bool active = true,
    DateTime? writeDate,
  }) async {
    await _db.into(_db.uomUom).insert(
          UomUomCompanion.insert(
            odooId: odooId,
            name: name,
            categoryId: drift.Value(categoryId),
            categoryName: drift.Value(categoryName),
            uomType: drift.Value(uomType),
            factor: drift.Value(factor),
            factorInv: drift.Value(factorInv),
            rounding: drift.Value(rounding),
            active: drift.Value(active),
            writeDate: drift.Value(writeDate),
          ),
          onConflict: drift.DoUpdate(
            (_) => UomUomCompanion(
              name: drift.Value(name),
              categoryId: drift.Value(categoryId ?? 1),
              categoryName: drift.Value(categoryName),
              uomType: drift.Value(uomType),
              factor: drift.Value(factor),
              factorInv: drift.Value(factorInv),
              rounding: drift.Value(rounding),
              active: drift.Value(active),
              writeDate: drift.Value(writeDate),
            ),
            target: [_db.uomUom.odooId],
          ),
        );
  }
}
