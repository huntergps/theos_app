/// WarehouseManager extensions - Business methods beyond generated CRUD
///
/// The base WarehouseManager is generated in warehouse.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' show Value;

import '../../database/database.dart';
import '../../models/warehouses/warehouse.model.dart';

/// Extension methods for WarehouseManager
extension WarehouseManagerBusiness on WarehouseManager {
  /// Upsert warehouse to local database using AppDatabase directly
  Future<void> upsertWarehouse(AppDatabase db, Warehouse record) async {
    final existing = await (db.select(db.stockWarehouse)
          ..where((t) => t.odooId.equals(record.id)))
        .getSingleOrNull();

    final companion = StockWarehouseCompanion(
      odooId: Value(record.id),
      name: Value(record.name),
      code: Value(record.code ?? ''),
      writeDate: Value(record.writeDate),
    );

    if (existing != null) {
      await (db.update(db.stockWarehouse)
            ..where((t) => t.odooId.equals(record.id)))
          .write(companion);
    } else {
      await db.into(db.stockWarehouse).insert(companion);
    }
  }
}
