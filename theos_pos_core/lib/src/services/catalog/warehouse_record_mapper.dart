import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

abstract final class WarehouseRecordMapper {
  static const fields = <String>['id', 'name', 'code', 'write_date'];
  static Future<bool> exists(AppDatabase db, int id) async =>
      (await (db.select(
        db.stockWarehouse,
      )..where((t) => t.odooId.equals(id))).getSingleOrNull()) !=
      null;
  static Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('stock.warehouse id');
    }
    final c = StockWarehouseCompanion(
      odooId: Value(id),
      // 🔴 Mismo patrón que en `PartnerRecordMapper`: `as String?` no filtra
      // el `false` que Odoo manda para un texto vacío.
      name: Value(odoo.toStringOrNull(data['name']) ?? ''),
      code: Value(data['code'] is String ? data['code'] as String : ''),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );
    if (await exists(db, id)) {
      await (db.update(
        db.stockWarehouse,
      )..where((t) => t.odooId.equals(id))).write(c);
    } else {
      await db.into(db.stockWarehouse).insert(c);
    }
  }
}
