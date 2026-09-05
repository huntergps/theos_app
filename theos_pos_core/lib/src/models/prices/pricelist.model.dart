import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'pricelist.model.freezed.dart';
part 'pricelist.model.g.dart';

/// Pricelist model representing product.pricelist in Odoo
@OdooModel('product.pricelist', tableName: 'product_pricelist')
@freezed
abstract class Pricelist with _$Pricelist {
  const Pricelist._();

  const factory Pricelist({
    @OdooId() required int id,
    @OdooString() required String name,
    @OdooBoolean() @Default(true) bool active,
    @OdooMany2One('res.currency', odooName: 'currency_id') int? currencyId,
    @OdooMany2OneName(sourceField: 'currency_id') String? currencyName,
    @OdooMany2One('res.company', odooName: 'company_id') int? companyId,
    @OdooMany2OneName(sourceField: 'company_id') String? companyName,
    @OdooInteger() @Default(16) int sequence,
    // Odoo 19.5 (erp1): 'discount_policy' ya no existe en product.pricelist
    // del servidor (smoke fields_get, julio 2026).
    @OdooLocalOnly() String? discountPolicy,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _Pricelist;

  // ============ Computed Fields ============

  /// Display name with currency if available
  String get displayName =>
      currencyName != null ? '$name ($currencyName)' : name;

  /// Check if pricelist shows discount separately
  bool get showsDiscountSeparately => discountPolicy == 'without_discount';

  /// Check if pricelist includes discount in price
  bool get includesDiscountInPrice => discountPolicy != 'without_discount';
}

/// Pricelist Item model representing product.pricelist.item in Odoo
@OdooModel('product.pricelist.item', tableName: 'product_pricelist_item')
@freezed
abstract class PricelistItem with _$PricelistItem {
  const PricelistItem._();

  const factory PricelistItem({
    @OdooId() required int id,
    @OdooMany2One('product.pricelist', odooName: 'pricelist_id')
    required int pricelistId,
    @OdooMany2One('product.template', odooName: 'product_tmpl_id')
    int? productTmplId,
    @OdooMany2One('product.product', odooName: 'product_id') int? productId,
    @OdooMany2One('product.category', odooName: 'categ_id') int? categId,
    @OdooSelection() @Default('3_global') String appliedOn,
    @OdooFloat() @Default(0.0) double minQuantity,
    @OdooDateTime() DateTime? dateStart,
    @OdooDateTime() DateTime? dateEnd,
    @OdooSelection() @Default('fixed') String computePrice,
    @OdooFloat() @Default(0.0) double fixedPrice,
    @OdooFloat() @Default(0.0) double percentPrice,
    // `sequence` is not present on product.pricelist.item in ERP2/Odoo 19.5.
    // It remains a pure local default and is intentionally outside sync.
    @Default(5) int sequence,
    // `uom_id` is not present on product.pricelist.item in Odoo 19.
    @OdooLocalOnly() int? uomId,
    @OdooSelection() @Default('list_price') String base,
    @OdooMany2One('product.pricelist', odooName: 'base_pricelist_id')
    int? basePricelistId,
    @OdooFloat() @Default(0.0) double priceDiscount,
    @OdooFloat() @Default(0.0) double priceSurcharge,
    @OdooFloat() @Default(0.0) double priceRound,
    @OdooFloat() @Default(0.0) double priceMinMargin,
    @OdooFloat() @Default(0.0) double priceMaxMargin,
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _PricelistItem;

  Map<String, String> validate() {
    final errors = <String, String>{};
    if (pricelistId <= 0) errors['pricelistId'] = 'Pricelist ID is required';
    return errors;
  }

  // ============ Computed Fields ============

  /// Check if this is a global rule (applies to all products)
  bool get isGlobal => appliedOn == '3_global';

  /// Check if this is a product-specific rule
  bool get isProductSpecific =>
      appliedOn == '0_product_variant' || appliedOn == '1_product';

  /// Check if this is a category rule
  bool get isCategoryRule => appliedOn == '2_product_category';

  /// Check if rule is currently active based on dates
  bool get isDateValid {
    final now = DateTime.now();
    if (dateStart != null && dateStart!.isAfter(now)) return false;
    if (dateEnd != null && dateEnd!.isBefore(now)) return false;
    return true;
  }

  /// Check if this is a fixed price rule
  bool get isFixedPrice => computePrice == 'fixed';

  /// Check if this is a percentage discount rule
  bool get isPercentageDiscount => computePrice == 'percentage';

  /// Check if this is a formula-based rule
  bool get isFormula => computePrice == 'formula';
}
