import 'package:drift/drift.dart' show GeneratedDatabase, RawValuesInsertable, TableInfo, Value, Variable;
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import '../../database/database.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

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
    @OdooSelection(odooName: 'discount_policy') String? discountPolicy,
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
///
/// Wraps the Drift-generated [ProductPricelistItemData] with business logic.
@freezed
abstract class PricelistItem with _$PricelistItem, OdooRecord<PricelistItem> {
  const PricelistItem._();

  const factory PricelistItem({
    required int id,
    required int odooId,
    String? uuid,
    required int pricelistId,
    int? productTmplId,
    int? productId,
    int? categId,
    @Default('3_global') String appliedOn,
    @Default(0.0) double minQuantity,
    DateTime? dateStart,
    DateTime? dateEnd,
    @Default('fixed') String computePrice,
    @Default(0.0) double fixedPrice,
    @Default(0.0) double percentPrice,
    @Default(5) int sequence,
    int? uomId,
    @Default('list_price') String base,
    int? basePricelistId,
    @Default(0.0) double priceDiscount,
    @Default(0.0) double priceSurcharge,
    double? priceRound,
    double? priceMinMargin,
    double? priceMaxMargin,
    DateTime? writeDate,
  }) = _PricelistItem;

  // ============ OdooRecord Implementation ============

  @override
  bool get isSynced => odooId > 0;

  Map<String, List<String>> get dependencyGraph => const {};

  @override
  Map<String, String> validate() {
    final errors = <String, String>{};
    if (pricelistId <= 0) errors['pricelistId'] = 'Pricelist ID is required';
    return errors;
  }

  @override
  Map<String, dynamic> toOdoo() {
    return {
      'pricelist_id': pricelistId,
      if (productTmplId != null) 'product_tmpl_id': productTmplId,
      if (productId != null) 'product_id': productId,
      if (categId != null) 'categ_id': categId,
      'applied_on': appliedOn,
      'min_quantity': minQuantity,
      if (dateStart != null) 'date_start': dateStart!.toIso8601String(),
      if (dateEnd != null) 'date_end': dateEnd!.toIso8601String(),
      'compute_price': computePrice,
      'fixed_price': fixedPrice,
      'percent_price': percentPrice,
      'sequence': sequence,
      if (uomId != null) 'uom_id': uomId,
      'base': base,
      if (basePricelistId != null) 'base_pricelist_id': basePricelistId,
      'price_discount': priceDiscount,
      'price_surcharge': priceSurcharge,
      if (priceRound != null) 'price_round': priceRound,
      if (priceMinMargin != null) 'price_min_margin': priceMinMargin,
      if (priceMaxMargin != null) 'price_max_margin': priceMaxMargin,
    };
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

  // ============ Factory Methods ============

  /// Create from Drift database row
  factory PricelistItem.fromDatabase(dynamic data) {
    return PricelistItem(
      id: data.id,
      odooId: data.odooId,
      pricelistId: data.pricelistId,
      productTmplId: data.productTmplId,
      productId: data.productId,
      categId: data.categId,
      appliedOn: data.appliedOn,
      minQuantity: data.minQuantity,
      dateStart: data.dateStart,
      dateEnd: data.dateEnd,
      computePrice: data.computePrice,
      fixedPrice: data.fixedPrice,
      percentPrice: data.percentPrice,
      sequence: data.sequence,
      uomId: data.uomId,
      base: data.base,
      basePricelistId: data.basePricelistId,
      priceDiscount: data.priceDiscount,
      priceSurcharge: data.priceSurcharge,
      priceRound: data.priceRound,
      priceMinMargin: data.priceMinMargin,
      priceMaxMargin: data.priceMaxMargin,
      writeDate: data.writeDate,
    );
  }

  /// Odoo model name
  static const String odooModel = 'product.pricelist.item';

  /// Create from Odoo JSON response
  factory PricelistItem.fromOdoo(Map<String, dynamic> json) {
    return PricelistItem(
      id: 0, // Will be set by database
      odooId: json['id'] as int,
      pricelistId: odoo.extractMany2oneId(json['pricelist_id']) ?? 0,
      productTmplId: odoo.extractMany2oneId(json['product_tmpl_id']),
      productId: odoo.extractMany2oneId(json['product_id']),
      categId: odoo.extractMany2oneId(json['categ_id']),
      appliedOn: (json['applied_on'] ?? '3_global') as String,
      minQuantity: (json['min_quantity'] as num?)?.toDouble() ?? 0.0,
      dateStart: odoo.parseOdooDateTime(json['date_start']),
      dateEnd: odoo.parseOdooDateTime(json['date_end']),
      computePrice: (json['compute_price'] ?? 'fixed') as String,
      fixedPrice: (json['fixed_price'] as num?)?.toDouble() ?? 0.0,
      percentPrice: (json['percent_price'] as num?)?.toDouble() ?? 0.0,
      sequence: (json['sequence'] ?? 5) as int,
      uomId: odoo.extractMany2oneId(json['uom_id']),
      base: (json['base'] ?? 'list_price') as String,
      basePricelistId: odoo.extractMany2oneId(json['base_pricelist_id']),
      priceDiscount: (json['price_discount'] as num?)?.toDouble() ?? 0.0,
      priceSurcharge: (json['price_surcharge'] as num?)?.toDouble() ?? 0.0,
      priceRound: (json['price_round'] as num?)?.toDouble(),
      priceMinMargin: (json['price_min_margin'] as num?)?.toDouble(),
      priceMaxMargin: (json['price_max_margin'] as num?)?.toDouble(),
      writeDate: odoo.parseOdooDateTime(json['write_date']),
    );
  }
}

/// Extension to add toCompanion() method to PricelistItem model
extension PricelistItemToCompanion on PricelistItem {
  /// Convert to Drift database companion for insert/update
  ProductPricelistItemCompanion toCompanion() {
    return ProductPricelistItemCompanion(
      odooId: Value(odooId),
      pricelistId: Value(pricelistId),
      productTmplId: Value(productTmplId),
      productId: Value(productId),
      categId: Value(categId),
      appliedOn: Value(appliedOn),
      minQuantity: Value(minQuantity),
      dateStart: Value(dateStart),
      dateEnd: Value(dateEnd),
      computePrice: Value(computePrice),
      fixedPrice: Value(fixedPrice),
      percentPrice: Value(percentPrice),
      sequence: Value(sequence),
      uomId: Value(uomId),
      base: Value(base),
      basePricelistId: Value(basePricelistId),
      priceDiscount: Value(priceDiscount),
      priceSurcharge: Value(priceSurcharge),
      priceRound: Value(priceRound ?? 0.0),
      priceMinMargin: Value(priceMinMargin ?? 0.0),
      priceMaxMargin: Value(priceMaxMargin ?? 0.0),
      writeDate: Value(writeDate),
    );
  }
}
