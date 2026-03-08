/// Tax model for Odoo account.tax
///
/// This model uses OdooModelManager annotations for automatic:
/// - fromOdoo() generation
/// - toOdoo() serialization
/// - Drift table generation
import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

part 'tax.freezed.dart';

/// Tax type for use context (Odoo type_tax_use)
enum TaxTypeUse {
  sale,
  purchase,
  none;

  static TaxTypeUse fromString(String? value) {
    return TaxTypeUse.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaxTypeUse.sale,
    );
  }

  String get displayName {
    return switch (this) {
      TaxTypeUse.sale => 'Ventas',
      TaxTypeUse.purchase => 'Compras',
      TaxTypeUse.none => 'Ninguno',
    };
  }
}

/// Tax computation type (Odoo amount_type)
enum TaxAmountType {
  percent,
  fixed,
  division;

  static TaxAmountType fromString(String? value) {
    return TaxAmountType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TaxAmountType.percent,
    );
  }

  String get displayName {
    return switch (this) {
      TaxAmountType.percent => 'Porcentaje',
      TaxAmountType.fixed => 'Fijo',
      TaxAmountType.division => 'División',
    };
  }
}

/// Tax model (account.tax)
///
/// **Reduction: ~260 LOC → ~90 LOC (65% reduction)**
/// - Eliminates: fromOdoo(), fromDatabase(), toCompanion(), parsing helpers
/// - Keeps: computed getters, business logic
@OdooModel('account.tax', tableName: 'account_taxes')
@freezed
abstract class Tax with _$Tax {
  const Tax._();

  const factory Tax({
    // ============ Identifiers ============
    @OdooId() required int id,
    @OdooLocalOnly() String? uuid,

    // ============ Basic Data ============
    @OdooString() required String name,
    @OdooString() String? description,
    @OdooSelection(odooName: 'type_tax_use') @Default('sale') String typeTaxUseStr,
    @OdooSelection(odooName: 'amount_type') @Default('percent') String amountTypeStr,
    @OdooFloat(precision: 4) @Default(0.0) double amount,
    @OdooBoolean() @Default(true) bool active,

    // ============ Configuration ============
    @OdooBoolean(odooName: 'price_include') @Default(false) bool priceInclude,
    @OdooBoolean(odooName: 'include_base_amount') @Default(false) bool includeBaseAmount,
    @OdooInteger() @Default(1) int sequence,

    // ============ Company ============
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,

    // ============ Tax Group ============
    @OdooMany2One('account.tax.group', odooName: 'tax_group_id') int? taxGroupId,
    @OdooMany2OneName(sourceField: 'tax_group_id') String? taxGroupName,

    // ============ Sync Metadata ============
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
    @OdooLocalOnly() @Default(false) bool isSynced,
    @OdooLocalOnly() DateTime? localModifiedAt,
  }) = _Tax;

  // ============ TYPE GETTERS ============

  TaxTypeUse get typeTaxUse => TaxTypeUse.fromString(typeTaxUseStr);
  TaxAmountType get amountType => TaxAmountType.fromString(amountTypeStr);

  // ============ COMPUTED FIELDS ============

  /// Display name with amount (e.g., "IVA 15%", "Fixed $5.00")
  String get displayName {
    if (amountType == TaxAmountType.percent) {
      return '${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}%';
    } else if (amountType == TaxAmountType.fixed) {
      return '\$${amount.toStringAsFixed(2)}';
    }
    return name;
  }

  /// Display amount string
  String get displayAmount {
    return switch (amountType) {
      TaxAmountType.percent => '${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}%',
      TaxAmountType.fixed => '\$${amount.toStringAsFixed(2)}',
      TaxAmountType.division => '${amount.toStringAsFixed(2)} div',
    };
  }

  /// Check if tax is percentage based
  bool get isPercentage => amountType == TaxAmountType.percent;

  /// Check if tax is fixed amount
  bool get isFixed => amountType == TaxAmountType.fixed;

  /// Check if tax is division type
  bool get isDivision => amountType == TaxAmountType.division;

  /// Check if tax is for sales
  bool get isSalesTax => typeTaxUse == TaxTypeUse.sale;

  /// Check if tax is for purchases
  bool get isPurchaseTax => typeTaxUse == TaxTypeUse.purchase;

  /// Simplified name for display (remove percentage in parentheses)
  String get simplifiedName {
    // "IVA 15% (15%)" -> "IVA 15%"
    final match = RegExp(r'(.+?)\s*\(\d+(?:\.\d+)?%\)$').firstMatch(name);
    return match?.group(1)?.trim() ?? name;
  }

  /// Calculate tax amount for a given base
  double calculateTax(double baseAmount) {
    return switch (amountType) {
      TaxAmountType.percent => baseAmount * amount / 100,
      TaxAmountType.fixed => amount,
      TaxAmountType.division => baseAmount - (baseAmount / (1 + amount / 100)),
    };
  }

  /// Calculate base amount from a price that includes tax
  double calculateBaseFromPriceIncluded(double priceIncluded) {
    if (!priceInclude) return priceIncluded;
    return switch (amountType) {
      TaxAmountType.percent => priceIncluded / (1 + amount / 100),
      TaxAmountType.fixed => priceIncluded - amount,
      TaxAmountType.division => priceIncluded * (1 - amount / 100),
    };
  }
}

/// List of Odoo fields to fetch for Tax
const taxOdooFields = [
  'id',
  'name',
  'description',
  'type_tax_use',
  'amount_type',
  'amount',
  'active',
  'price_include',
  'include_base_amount',
  'sequence',
  'company_id',
  'tax_group_id',
  'write_date',
];
