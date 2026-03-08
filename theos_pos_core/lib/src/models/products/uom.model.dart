import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'uom.model.freezed.dart';
part 'uom.model.g.dart';

/// UoM type enum matching Odoo's uom.uom.uom_type
enum UomType {
  @JsonValue('bigger')
  bigger, // Bigger than reference
  @JsonValue('reference')
  reference, // Reference UoM
  @JsonValue('smaller')
  smaller, // Smaller than reference
}

/// Unit of Measure model with computed fields
///
/// Implements Odoo's uom.uom model with proper conversion factors.
///
/// **Computed fields:**
/// - [isReference] -> depends: [uomType]
/// - [conversionFactor] -> depends: [uomType, factor, factorInv]
@OdooModel('uom.uom', tableName: 'uom_uom')
@freezed
abstract class Uom with _$Uom {
  const Uom._(); // Enable custom methods

  const factory Uom({
    // ============ Identifiers ============
    @OdooId() required int id,

    // ============ Basic Data ============
    @OdooString() required String name,
    @OdooMany2One('uom.category', odooName: 'category_id') int? categoryId,
    @OdooMany2OneName(sourceField: 'category_id') String? categoryName,
    @OdooSelection(odooName: 'uom_type') @Default(UomType.reference) UomType uomType,
    @OdooFloat() @Default(1.0) double factor,
    @OdooFloat(odooName: 'factor_inv') @Default(1.0) double factorInv,
    @OdooFloat() @Default(0.01) double rounding,
    @OdooBoolean() @Default(true) bool active,

    // ============ Metadata ============
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _Uom;

  // ============ COMPUTED FIELDS (like @api.depends) ============

  /// Check if this is the reference UoM for its category
  /// @api.depends('uom_type')
  bool get isReference => uomType == UomType.reference;

  /// Check if this UoM is bigger than reference
  bool get isBigger => uomType == UomType.bigger;

  /// Check if this UoM is smaller than reference
  bool get isSmaller => uomType == UomType.smaller;

  /// Get the conversion factor to convert TO reference UoM
  /// For bigger UoMs, use factorInv (e.g., 1 box = 12 units, factorInv = 12)
  /// For smaller UoMs, use factor (e.g., 1 gram = 0.001 kg, factor = 0.001)
  /// @api.depends('uom_type', 'factor', 'factor_inv')
  double get conversionFactor {
    switch (uomType) {
      case UomType.bigger:
        return factorInv;
      case UomType.smaller:
        return factor;
      case UomType.reference:
        return 1.0;
    }
  }

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
}

/// UoM Category model
@freezed
abstract class UomCategory with _$UomCategory {
  const UomCategory._();

  const factory UomCategory({
    required int id,
    required int odooId,
    required String name,
    DateTime? writeDate,
  }) = _UomCategory;
}
