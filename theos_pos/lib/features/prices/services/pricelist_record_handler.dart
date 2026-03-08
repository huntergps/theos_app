import 'package:drift/drift.dart';

import 'package:theos_pos_core/theos_pos_core.dart';
import '../../../core/services/handlers/model_record_handler.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

/// Handler for product.pricelist records
class PricelistRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'product.pricelist';

  @override
  List<String> get defaultFields => [
    'id',
    'name',
    'active',
    'currency_id',
    'company_id',
    'sequence',
    'write_date',
  ];

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    final result = await (db.select(db.productPricelist)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'] as int;

    final existing = await (db.select(db.productPricelist)
          ..where((t) => t.odooId.equals(id)))
        .getSingleOrNull();

    final companion = ProductPricelistCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      active: Value(data['active'] as bool? ?? true),
      currencyId: Value(odoo.extractMany2oneId(data['currency_id'])),
      currencyName: Value(odoo.extractMany2oneName(data['currency_id'])),
      companyId: Value(odoo.extractMany2oneId(data['company_id'])),
      companyName: Value(odoo.extractMany2oneName(data['company_id'])),
      sequence: Value(data['sequence'] as int? ?? 16),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );

    if (existing != null) {
      await (db.update(db.productPricelist)..where((t) => t.odooId.equals(id)))
          .write(companion);
    } else {
      await db.into(db.productPricelist).insert(companion);
    }
  }
}
