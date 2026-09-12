import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

abstract final class PricelistRecordMapper {
  static const fields = <String>[
    'id',
    'name',
    'active',
    'currency_id',
    'company_id',
    'sequence',
    'write_date',
  ];
  static Future<bool> exists(AppDatabase db, int id) async =>
      (await (db.select(
        db.productPricelist,
      )..where((t) => t.odooId.equals(id))).getSingleOrNull()) !=
      null;
  static Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('product.pricelist id');
    }
    final c = ProductPricelistCompanion(
      odooId: Value(id),
      // 🔴 Mismo patrón que en `PartnerRecordMapper`: `as String?` no filtra
      // el `false` que Odoo manda para un texto vacío.
      name: Value(odoo.toStringOrNull(data['name']) ?? ''),
      active: Value(data['active'] as bool? ?? true),
      currencyId: Value(odoo.extractMany2oneId(data['currency_id'])),
      currencyName: Value(odoo.extractMany2oneName(data['currency_id'])),
      companyId: Value(odoo.extractMany2oneId(data['company_id'])),
      companyName: Value(odoo.extractMany2oneName(data['company_id'])),
      sequence: Value(data['sequence'] as int? ?? 16),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );
    if (await exists(db, id)) {
      await (db.update(
        db.productPricelist,
      )..where((t) => t.odooId.equals(id))).write(c);
    } else {
      await db.into(db.productPricelist).insert(c);
    }
  }
}
