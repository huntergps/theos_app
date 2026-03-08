/// Product Category model for Odoo product.category
///
/// This model uses OdooModelManager annotations for automatic:
/// - fromOdoo() generation
/// - toOdoo() serialization
/// - Drift table generation
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

part 'product_category.freezed.dart';

/// Product Category model (product.category)
///
/// **Reduction: ~80 LOC → ~40 LOC (50% reduction)**
@OdooModel('product.category', tableName: 'product_categories')
@freezed
abstract class ProductCategory with _$ProductCategory {
  const ProductCategory._();

  const factory ProductCategory({
    // ============ Identifiers ============
    @OdooId() required int id,
    @OdooLocalOnly() String? uuid,

    // ============ Basic Data ============
    @OdooString() required String name,
    @OdooString(odooName: 'complete_name') String? completeName,

    // ============ Hierarchy ============
    @OdooMany2One('product.category', odooName: 'parent_id') int? parentId,
    @OdooMany2OneName(sourceField: 'parent_id') String? parentName,

    // ============ Sync Metadata ============
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
    @OdooLocalOnly() @Default(false) bool isSynced,
    @OdooLocalOnly() DateTime? localModifiedAt,
  }) = _ProductCategory;

  // ============ COMPUTED FIELDS ============

  /// Display name (complete name if available, otherwise name)
  String get displayName => completeName ?? name;

  /// Check if category has a parent
  bool get hasParent => parentId != null;

  /// Check if this is a root category
  bool get isRoot => parentId == null;

  /// Get the depth level from complete_name (count of " / ")
  int get depth {
    if (completeName == null) return 0;
    return ' / '.allMatches(completeName!).length;
  }
}

/// List of Odoo fields to fetch for ProductCategory
const productCategoryOdooFields = [
  'id',
  'name',
  'complete_name',
  'parent_id',
  'write_date',
];
