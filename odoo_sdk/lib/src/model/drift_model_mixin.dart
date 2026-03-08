/// Drift Model Mixin - Default Database Operations
///
/// Provides a template and helper methods for implementing local database
/// operations using Drift. Due to Drift's type-safe design, actual
/// implementations must be done in subclasses with concrete table types.
///
/// Usage:
/// ```dart
/// class ProductManager extends OdooModelManager<Product> {
///   final AppDatabase _appDb;
///
///   ProductManager(this._appDb);
///
///   // Implement local database operations using your specific table
///   @override
///   Future<Product?> readLocal(int id) async {
///     final row = await (_appDb.select(_appDb.productProduct)
///       ..where((t) => t.odooId.equals(id)))
///         .getSingleOrNull();
///     return row != null ? Product.fromDatabase(row) : null;
///   }
///
///   // ... other implementations
/// }
/// ```
library;

import 'package:drift/drift.dart';

/// Helper functions for Drift-based managers.
///
/// These functions help with common patterns when implementing
/// OdooModelManager methods with Drift.
class DriftHelpers {
  /// Build an upsert operation.
  ///
  /// Checks if a record exists and either inserts or updates.
  static Future<void> upsert<T extends Table, D>(
    GeneratedDatabase db,
    TableInfo<T, D> table,
    Insertable<D> companion,
    Expression<bool> Function(T table) whereClause,
  ) async {
    final query = db.select(table)..where(whereClause);
    final existing = await query.getSingleOrNull();

    if (existing != null) {
      await (db.update(table)..where(whereClause)).write(companion);
    } else {
      await db.into(table).insert(companion);
    }
  }

  /// Batch insert or replace records.
  static Future<void> batchUpsert<T extends Table, D>(
    GeneratedDatabase db,
    TableInfo<T, D> table,
    List<Insertable<D>> companions,
  ) async {
    await db.batch((batch) {
      for (final companion in companions) {
        batch.insert(
          table,
          companion,
          mode: InsertMode.insertOrReplace,
        );
      }
    });
  }

  /// Execute a raw SQL count query.
  static Future<int> countWithSql(
    GeneratedDatabase db,
    String tableName, {
    String? whereClause,
  }) async {
    final sql = StringBuffer('SELECT COUNT(*) as count FROM $tableName');
    if (whereClause != null && whereClause.isNotEmpty) {
      sql.write(' WHERE $whereClause');
    }
    final result = await db.customSelect(sql.toString()).getSingle();
    return result.read<int>('count');
  }

  /// Get max value of a column.
  static Future<DateTime?> maxDateTime(
    GeneratedDatabase db,
    String tableName,
    String columnName,
  ) async {
    final result = await db
        .customSelect(
          'SELECT MAX($columnName) as max_val FROM $tableName',
        )
        .getSingleOrNull();
    if (result == null) return null;
    final value = result.read<String?>('max_val');
    if (value == null) return null;
    return DateTime.tryParse(value);
  }
}

/// Base class for a Drift-backed model manager.
///
/// Extend this class to create a concrete manager with type-safe
/// database operations. This class provides the common patterns
/// while your subclass provides the specific table and conversion methods.
///
/// Example:
/// ```dart
/// class ProductManager extends DriftBackedManager<Product, ProductProductData> {
///   final AppDatabase db;
///
///   ProductManager(this.db);
///
///   @override
///   String get odooModel => 'product.product';
///
///   @override
///   String get tableName => 'product_product';
///
///   @override
///   List<String> get odooFields => ['id', 'name', 'default_code', ...];
///
///   @override
///   TableInfo<ProductProduct, ProductProductData> get table => db.productProduct;
///
///   @override
///   GeneratedDatabase get database => db;
///
///   @override
///   Product fromDriftRow(ProductProductData row) => Product.fromDatabase(row);
///
///   @override
///   Insertable<ProductProductData> toCompanion(Product model) {
///     return ProductProductCompanion(
///       odooId: Value(model.id),
///       name: Value(model.name),
///       // ...
///     );
///   }
///
///   @override
///   Expression<bool> whereId(ProductProduct t, int id) => t.odooId.equals(id);
///
///   @override
///   Expression<bool> whereUuid(ProductProduct t, String uuid) => t.uuid.equals(uuid);
///
///   @override
///   Expression<bool> whereUnsynced(ProductProduct t) => t.isSynced.equals(false);
/// }
/// ```
// Note: This is a documentation-only class showing the pattern.
// Actual implementation requires concrete types for the table.

