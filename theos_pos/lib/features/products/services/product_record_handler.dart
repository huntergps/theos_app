import 'package:drift/drift.dart';

import 'package:theos_pos_core/theos_pos_core.dart';
import '../../../core/services/handlers/model_record_handler.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

/// Handler for product.product records
class ProductRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'product.product';

  @override
  List<String> get defaultFields => [
    'id',
    'name',
    'display_name',
    'default_code',
    'barcode',
    'type',
    'sale_ok',
    'purchase_ok',
    'active',
    'list_price',
    'standard_price',
    'categ_id',
    'uom_id',
    'taxes_id',
    'supplier_taxes_id',
    'description',
    'description_sale',
    'product_tmpl_id',
    'image_128',
    'qty_available',
    'virtual_available',
    'write_date',
  ];

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    final result = await (db.select(db.productProduct)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'] as int;

    final existing = await (db.select(db.productProduct)
          ..where((t) => t.odooId.equals(id)))
        .getSingleOrNull();

    final companion = ProductProductCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      displayName: Value(data['display_name'] as String?),
      defaultCode: Value(
        data['default_code'] is String ? data['default_code'] : null,
      ),
      barcode: Value(data['barcode'] is String ? data['barcode'] : null),
      type: Value(data['type'] as String? ?? 'consu'),
      saleOk: Value(data['sale_ok'] as bool? ?? true),
      purchaseOk: Value(data['purchase_ok'] as bool? ?? true),
      active: Value(data['active'] as bool? ?? true),
      listPrice: Value((data['list_price'] as num?)?.toDouble() ?? 0.0),
      standardPrice: Value((data['standard_price'] as num?)?.toDouble() ?? 0.0),
      categId: Value(odoo.extractMany2oneId(data['categ_id'])),
      categName: Value(odoo.extractMany2oneName(data['categ_id'])),
      uomId: Value(odoo.extractMany2oneId(data['uom_id'])),
      uomName: Value(odoo.extractMany2oneName(data['uom_id'])),
      taxesId: Value(odoo.extractMany2manyToJson(data['taxes_id'])),
      supplierTaxesId: Value(
        odoo.extractMany2manyToJson(data['supplier_taxes_id']),
      ),
      description: Value(
        data['description'] is String ? data['description'] : null,
      ),
      descriptionSale: Value(
        data['description_sale'] is String ? data['description_sale'] : null,
      ),
      productTmplId: Value(odoo.extractMany2oneId(data['product_tmpl_id'])),
      image128: Value(data['image_128'] is String ? data['image_128'] : null),
      qtyAvailable: Value((data['qty_available'] as num?)?.toDouble() ?? 0.0),
      virtualAvailable: Value(
        (data['virtual_available'] as num?)?.toDouble() ?? 0.0,
      ),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );

    if (existing != null) {
      await (db.update(db.productProduct)
            ..where((t) => t.odooId.equals(id)))
          .write(companion);
    } else {
      await db.into(db.productProduct).insert(companion);
    }
  }
}

/// Handler for uom.uom records
class UomRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'uom.uom';

  @override
  List<String> get defaultFields => [
    'id',
    'name',
    'factor',
    'rounding',
    'active',
    'write_date',
  ];

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    final result = await (db.select(db.uomUom)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'] as int;

    final existing = await (db.select(db.uomUom)
          ..where((t) => t.odooId.equals(id)))
        .getSingleOrNull();

    final companion = UomUomCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      factor: Value((data['factor'] as num?)?.toDouble() ?? 1.0),
      rounding: Value((data['rounding'] as num?)?.toDouble() ?? 0.01),
      active: Value(data['active'] as bool? ?? true),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );

    if (existing != null) {
      await (db.update(db.uomUom)..where((t) => t.odooId.equals(id)))
          .write(companion);
    } else {
      await db.into(db.uomUom).insert(companion);
    }
  }
}
