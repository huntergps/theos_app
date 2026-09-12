import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

/// Single product.product persistence policy shared by all app shells.
abstract final class ProductRecordMapper {
  static const fields = <String>[
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

  static Future<bool> exists(AppDatabase db, int odooId) async =>
      (await (db.select(
        db.productProduct,
      )..where((t) => t.odooId.equals(odooId))).getSingleOrNull()) !=
      null;

  static Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('product.product id');
    }
    final c = ProductProductCompanion(
      odooId: Value(id),
      // 🔴 Mismo patrón que en `PartnerRecordMapper`: `as String?` no filtra
      // el `false` que Odoo manda para un texto vacío.
      name: Value(odoo.toStringOrNull(data['name']) ?? ''),
      displayName: Value(odoo.toStringOrNull(data['display_name'])),
      defaultCode: Value(
        data['default_code'] is String ? data['default_code'] : null,
      ),
      barcode: Value(data['barcode'] is String ? data['barcode'] : null),
      type: Value(odoo.toStringOrNull(data['type']) ?? 'consu'),
      saleOk: Value(data['sale_ok'] as bool? ?? true),
      purchaseOk: Value(data['purchase_ok'] as bool? ?? true),
      active: Value(data['active'] as bool? ?? true),
      listPrice: Value((data['list_price'] as num?)?.toDouble() ?? 0),
      standardPrice: Value((data['standard_price'] as num?)?.toDouble() ?? 0),
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
      qtyAvailable: Value((data['qty_available'] as num?)?.toDouble() ?? 0),
      virtualAvailable: Value(
        (data['virtual_available'] as num?)?.toDouble() ?? 0,
      ),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );
    final found = await exists(db, id);
    if (found) {
      await (db.update(
        db.productProduct,
      )..where((t) => t.odooId.equals(id))).write(c);
    } else {
      await db.into(db.productProduct).insert(c);
    }
  }
}
