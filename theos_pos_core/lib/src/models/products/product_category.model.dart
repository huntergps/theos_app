import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'product_category.model.freezed.dart';
part 'product_category.model.g.dart';

/// Product Category model
///
/// Implements Odoo's product.category model with @OdooModel annotation pattern.
@OdooModel('product.category', tableName: 'product_category')
@freezed
abstract class ProductCategory with _$ProductCategory {
  const ProductCategory._(); // Enable custom methods

  const factory ProductCategory({
    // ============ Identifiers ============
    @OdooId() required int id,

    // ============ Basic Data ============
    @OdooString() required String name,
    @OdooString(odooName: 'complete_name') String? completeName,

    // ============ Hierarchy ============
    @OdooMany2One('product.category', odooName: 'parent_id') int? parentId,
    @OdooMany2OneName(sourceField: 'parent_id') String? parentName,

    // ============ Metadata ============
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _ProductCategory;

  // ============ COMPUTED FIELDS ============

  /// Display name (complete name or just name)
  String get displayName => completeName ?? name;

  /// Check if has parent category
  bool get hasParent => parentId != null;
}
