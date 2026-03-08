import 'package:drift/drift.dart';

import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;
import '../../../core/services/handlers/model_record_handler.dart';

/// Handler for stock.warehouse records
class WarehouseRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'stock.warehouse';

  @override
  List<String> get defaultFields => [
    'id',
    'name',
    'code',
    'write_date',
  ];

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    final result = await (db.select(db.stockWarehouse)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'] as int;

    final existing = await (db.select(db.stockWarehouse)
          ..where((t) => t.odooId.equals(id)))
        .getSingleOrNull();

    final companion = StockWarehouseCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      code: Value(data['code'] is String ? data['code'] : null),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );

    if (existing != null) {
      await (db.update(db.stockWarehouse)..where((t) => t.odooId.equals(id)))
          .write(companion);
    } else {
      await db.into(db.stockWarehouse).insert(companion);
    }
  }
}
