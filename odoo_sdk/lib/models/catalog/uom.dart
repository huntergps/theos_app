/// Unit of Measure model for Odoo uom.uom
///
/// This model uses OdooModelManager annotations for automatic:
/// - fromOdoo() generation
/// - toOdoo() serialization
/// - Drift table generation
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

part 'uom.freezed.dart';

/// UoM type enum matching Odoo's uom.uom.uom_type
enum UomType {
  bigger, // Bigger than reference (e.g., Box = 12 units)
  reference, // Reference UoM (base unit)
  smaller; // Smaller than reference (e.g., gram = 0.001 kg)

  static UomType fromString(String? value) {
    return UomType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => UomType.reference,
    );
  }

  String get displayName {
    return switch (this) {
      UomType.bigger => 'Mayor que referencia',
      UomType.reference => 'Referencia',
      UomType.smaller => 'Menor que referencia',
    };
  }
}

/// Unit of Measure model (uom.uom)
///
/// **Reduction: ~190 LOC → ~80 LOC (58% reduction)**
/// - Eliminates: fromOdoo(), fromDatabase(), parsing helpers
/// - Keeps: conversion methods, computed getters
@OdooModel('uom.uom', tableName: 'uom_uom')
@freezed
abstract class Uom with _$Uom {
  const Uom._();

  const factory Uom({
    // ============ Identifiers ============
    @OdooId() required int id,
    @OdooLocalOnly() String? uuid,

    // ============ Basic Data ============
    @OdooString() required String name,
    @OdooMany2One('uom.category', odooName: 'category_id') int? categoryId,
    @OdooMany2OneName(sourceField: 'category_id') String? categoryName,
    @OdooSelection(odooName: 'uom_type') @Default('reference') String uomTypeStr,

    // ============ Conversion Factors ============
    @OdooFloat(precision: 6) @Default(1.0) double factor,
    @OdooFloat(odooName: 'factor_inv', precision: 6) @Default(1.0) double factorInv,
    @OdooFloat(precision: 5) @Default(0.01) double rounding,

    // ============ Status ============
    @OdooBoolean() @Default(true) bool active,

    // ============ Sync Metadata ============
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
    @OdooLocalOnly() @Default(false) bool isSynced,
    @OdooLocalOnly() DateTime? localModifiedAt,
  }) = _Uom;

  // ============ TYPE GETTERS ============

  UomType get uomType => UomType.fromString(uomTypeStr);

  // ============ COMPUTED FIELDS ============

  /// Check if this is the reference UoM for its category
  bool get isReference => uomType == UomType.reference;

  /// Check if this UoM is bigger than reference
  bool get isBigger => uomType == UomType.bigger;

  /// Check if this UoM is smaller than reference
  bool get isSmaller => uomType == UomType.smaller;

  /// Get the conversion factor to convert TO reference UoM
  /// - For bigger UoMs: use factorInv (e.g., 1 box = 12 units, factorInv = 12)
  /// - For smaller UoMs: use factor (e.g., 1 gram = 0.001 kg, factor = 0.001)
  /// - For reference: always 1.0
  double get conversionFactor {
    return switch (uomType) {
      UomType.bigger => factorInv,
      UomType.smaller => factor,
      UomType.reference => 1.0,
    };
  }

  // ============ CONVERSION METHODS ============

  /// Convert a quantity in this UoM to the reference UoM
  double toReference(double qty) {
    return qty * conversionFactor;
  }

  /// Convert a quantity from reference UoM to this UoM
  double fromReference(double qty) {
    if (conversionFactor == 0) return qty;
    return qty / conversionFactor;
  }

  /// Round a quantity according to this UoM's rounding precision
  double roundQty(double qty) {
    if (rounding <= 0) return qty;
    return (qty / rounding).round() * rounding;
  }

  /// Convert quantity from another UoM to this UoM
  /// Both UoMs must be in the same category
  double convertFrom(Uom other, double qty) {
    // First convert to reference, then from reference to this UoM
    final refQty = other.toReference(qty);
    return fromReference(refQty);
  }
}

/// UoM Category model (uom.category)
@OdooModel('uom.category', tableName: 'uom_categories')
@freezed
abstract class UomCategory with _$UomCategory {
  const UomCategory._();

  const factory UomCategory({
    @OdooId() required int id,
    @OdooLocalOnly() String? uuid,
    @OdooString() required String name,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
    @OdooLocalOnly() @Default(false) bool isSynced,
  }) = _UomCategory;
}

/// List of Odoo fields to fetch for Uom
const uomOdooFields = [
  'id',
  'name',
  'category_id',
  'uom_type',
  'factor',
  'factor_inv',
  'rounding',
  'active',
  'write_date',
];

/// List of Odoo fields to fetch for UomCategory
const uomCategoryOdooFields = [
  'id',
  'name',
  'write_date',
];
