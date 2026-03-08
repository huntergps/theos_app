import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'product_uom.model.freezed.dart';
part 'product_uom.model.g.dart';

/// ProductUom model for product-specific UoM with barcodes
///
/// Links a product to a UoM with a specific barcode.
/// Used for packaging/presentation barcodes (e.g., box of 12 units).
///
/// This is Odoo's product.uom model (not to be confused with uom.uom).
@OdooModel('product.uom', tableName: 'product_uom')
@freezed
abstract class ProductUom with _$ProductUom {
  const ProductUom._();

  const factory ProductUom({
    @OdooId() required int id,
    @OdooMany2One('product.product', odooName: 'product_id') required int productId,
    @OdooMany2One('uom.uom', odooName: 'uom_id') required int uomId,
    @OdooMany2OneName(sourceField: 'uom_id') String? uomName,
    @OdooString() required String barcode,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _ProductUom;

  /// Check if has a valid barcode
  bool get hasBarcode => barcode.isNotEmpty;
}
