import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'tax.model.freezed.dart';
part 'tax.model.g.dart';

/// Tax type for use context (Odoo type_tax_use)
enum TaxTypeUse {
  @JsonValue('sale')
  sale,
  @JsonValue('purchase')
  purchase,
  @JsonValue('none')
  none,
}

/// Tax computation type (Odoo amount_type)
enum TaxAmountType {
  @JsonValue('percent')
  percent,
  @JsonValue('fixed')
  fixed,
  @JsonValue('division')
  division,
}

/// Tax model representing account.tax in Odoo
@OdooModel('account.tax', tableName: 'account_tax')
@freezed
abstract class Tax with _$Tax {
  const Tax._();

  const factory Tax({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooString() String? description,
    @OdooSelection(odooName: 'type_tax_use') @Default(TaxTypeUse.sale) TaxTypeUse typeTaxUse,
    @OdooSelection(odooName: 'amount_type') @Default(TaxAmountType.percent) TaxAmountType amountType,
    @OdooFloat() @Default(0.0) double amount,
    @OdooBoolean() @Default(true) bool active,
    @OdooBoolean(odooName: 'price_include') @Default(false) bool priceInclude,
    @OdooBoolean(odooName: 'include_base_amount') @Default(false) bool includeBaseAmount,
    @OdooInteger() @Default(1) int sequence,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,
    @OdooMany2One('account.tax.group', odooName: 'tax_group_id') int? taxGroupId,
    @OdooMany2OneName(sourceField: 'tax_group_id') String? taxGroupName,
    @OdooString(odooName: 'tax_group_l10n_ec_type') String? taxGroupL10nEcType,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _Tax;

  // ============ Computed Fields (@api.depends equivalents) ============

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
    switch (amountType) {
      case TaxAmountType.percent:
        return '${amount.toStringAsFixed(amount.truncateToDouble() == amount ? 0 : 2)}%';
      case TaxAmountType.fixed:
        return '\$${amount.toStringAsFixed(2)}';
      case TaxAmountType.division:
        return '${amount.toStringAsFixed(2)} div';
    }
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
    // "IVA 12% Servicios (12%)" -> "IVA 12% Servicios"
    final match = RegExp(r'(.+?)\s*\(\d+(?:\.\d+)?%\)$').firstMatch(name);
    return match?.group(1)?.trim() ?? name;
  }
}
