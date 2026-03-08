/// ProductManager extensions - Business methods beyond generated CRUD
///
/// The base ProductManager is generated in product.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/products/product.model.dart';

/// Extension methods for ProductManager
extension ProductManagerBusiness on ProductManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  /// Get a product by Odoo ID (alias for readLocal)
  Future<Product?> getById(int odooId) => readLocal(odooId);

  /// Get products by list of Odoo IDs
  Future<List<Product>> getByIds(List<int> odooIds) async {
    if (odooIds.isEmpty) return [];
    final results = await (_db.select(_db.productProduct)
          ..where((t) => t.odooId.isIn(odooIds)))
        .get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Search products by name, code, or barcode
  Future<List<Product>> searchProducts(
    String query, {
    int limit = 50,
    bool activeOnly = true,
  }) async {
    if (query.trim().isEmpty) return [];

    final lowerQuery = query.toLowerCase();

    var selectQuery = _db.select(_db.productProduct)
      ..where((t) =>
          t.name.lower().like('%$lowerQuery%') |
          t.defaultCode.lower().like('%$lowerQuery%') |
          t.barcode.lower().like('%$lowerQuery%'))
      ..orderBy([(t) => drift.OrderingTerm.asc(t.name)])
      ..limit(limit);

    if (activeOnly) {
      selectQuery = selectQuery..where((t) => t.active.equals(true));
    }

    final results = await selectQuery.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Get all active products
  Future<List<Product>> getActive({int? limit}) async {
    var query = _db.select(_db.productProduct)
      ..where((t) => t.active.equals(true))
      ..orderBy([(t) => drift.OrderingTerm.asc(t.name)]);

    if (limit != null) {
      query = query..limit(limit);
    }

    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Get product by barcode
  Future<Product?> getByBarcode(String barcode) async {
    if (barcode.trim().isEmpty) return null;

    final result = await (_db.select(_db.productProduct)
          ..where((t) => t.barcode.equals(barcode))
          ..limit(1))
        .getSingleOrNull();
    return result != null ? fromDrift(result) : null;
  }

  /// Get product by default code
  Future<Product?> getByCode(String code) async {
    if (code.trim().isEmpty) return null;

    final result = await (_db.select(_db.productProduct)
          ..where((t) => t.defaultCode.equals(code))
          ..limit(1))
        .getSingleOrNull();
    return result != null ? fromDrift(result) : null;
  }

  /// Get products count
  Future<int> countProducts({bool activeOnly = true}) async {
    final countExp = _db.productProduct.odooId.count();
    var query = _db.selectOnly(_db.productProduct)..addColumns([countExp]);

    if (activeOnly) {
      query = query..where(_db.productProduct.active.equals(true));
    }

    final result = await query.map((row) => row.read(countExp)).getSingle();
    return result ?? 0;
  }

  /// Bulk upsert products
  Future<void> upsertManyProducts(List<Product> products) async {
    await _db.batch((batch) {
      for (final product in products) {
        batch.insert(
          _db.productProduct,
          createDriftCompanion(product),
          onConflict: drift.DoUpdate(
            (old) => createDriftCompanion(product),
            target: [_db.productProduct.odooId],
          ),
        );
      }
    });
  }
}
