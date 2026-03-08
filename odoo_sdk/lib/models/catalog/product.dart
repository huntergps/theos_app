/// Product model for Odoo product.product
///
/// This model uses OdooModelManager annotations for automatic:
/// - fromOdoo() generation
/// - toOdoo() serialization
/// - Drift table generation
/// - Sync configuration
import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

part 'product.freezed.dart';

/// Product type enum matching Odoo's product.template.type
enum ProductType {
  consu, // Consumable (Goods)
  service, // Service
  product; // Storable Product

  static ProductType fromString(String? value) {
    return ProductType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => ProductType.consu,
    );
  }

  String get displayName {
    return switch (this) {
      ProductType.consu => 'Consumible',
      ProductType.service => 'Servicio',
      ProductType.product => 'Almacenable',
    };
  }
}

/// Tracking type for inventory
enum TrackingType {
  none,
  serial,
  lot;

  static TrackingType fromString(String? value) {
    return TrackingType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => TrackingType.none,
    );
  }

  String get displayName {
    return switch (this) {
      TrackingType.none => 'Sin seguimiento',
      TrackingType.serial => 'Por número de serie',
      TrackingType.lot => 'Por lote',
    };
  }

  bool get requiresTracking => this != TrackingType.none;
}

/// Product model (product.product)
///
/// **Reduction: ~330 LOC → ~120 LOC (64% reduction)**
/// - Eliminates: fromOdoo(), fromDatabase(), parsing helpers
/// - Keeps: computed getters, business logic
@OdooModel('product.product', tableName: 'products')
@freezed
abstract class Product with _$Product {
  const Product._();

  const factory Product({
    // ============ Identifiers ============
    @OdooId() required int id,
    @OdooLocalOnly() String? uuid,

    // ============ Basic Data ============
    @OdooString() required String name,
    @OdooString(odooName: 'display_name') String? displayNameOdoo,
    @OdooString(odooName: 'default_code') String? defaultCode,
    @OdooString() String? barcode,
    @OdooSelection(odooName: 'type') @Default('consu') String typeStr,
    @OdooBoolean(odooName: 'sale_ok') @Default(true) bool saleOk,
    @OdooBoolean(odooName: 'purchase_ok') @Default(true) bool purchaseOk,
    @OdooBoolean() @Default(true) bool active,

    // ============ Pricing ============
    @OdooFloat(odooName: 'list_price', precision: 4) @Default(0.0) double listPrice,
    @OdooFloat(odooName: 'standard_price', precision: 4) @Default(0.0) double standardPrice,

    // ============ Category ============
    @OdooMany2One('product.category', odooName: 'categ_id') int? categId,
    @OdooMany2OneName(sourceField: 'categ_id') String? categName,

    // ============ Unit of Measure ============
    @OdooMany2One('uom.uom', odooName: 'uom_id') int? uomId,
    @OdooMany2OneName(sourceField: 'uom_id') String? uomName,
    @OdooMany2One('uom.uom', odooName: 'uom_po_id') int? uomPoId,
    @OdooMany2OneName(sourceField: 'uom_po_id') String? uomPoName,

    // ============ Taxes ============
    @OdooMany2Many('account.tax', odooName: 'taxes_id') @Default([]) List<int> taxIds,
    @OdooMany2Many('account.tax', odooName: 'supplier_taxes_id') @Default([]) List<int> supplierTaxIds,

    // ============ Description ============
    @OdooString() String? description,
    @OdooString(odooName: 'description_sale') String? descriptionSale,

    // ============ Template Reference ============
    @OdooMany2One('product.template', odooName: 'product_tmpl_id') int? productTmplId,

    // ============ Image ============
    @OdooBinary(odooName: 'image_128', fetchByDefault: false) String? image128,

    // ============ Inventory ============
    @OdooFloat(odooName: 'qty_available', precision: 4, writable: false) @Default(0.0) double qtyAvailable,
    @OdooFloat(odooName: 'virtual_available', precision: 4, writable: false) @Default(0.0) double virtualAvailable,
    @OdooSelection() @Default('none') String trackingStr,
    @OdooBoolean(odooName: 'is_storable', writable: false) @Default(false) bool isStorable,

    // ============ Ecuador Localization ============
    @OdooString(odooName: 'l10n_ec_auxiliary_code') String? auxiliaryCode,
    @OdooBoolean(odooName: 'is_unit_product') @Default(true) bool isUnitProduct,
    @OdooBoolean(odooName: 'temporal_no_despachar') @Default(false) bool temporalNoDespachar,

    // ============ Sync Metadata ============
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
    @OdooLocalOnly() @Default(false) bool isSynced,
    @OdooLocalOnly() DateTime? localModifiedAt,
  }) = _Product;

  // ============ TYPE GETTERS ============

  ProductType get type => ProductType.fromString(typeStr);
  TrackingType get tracking => TrackingType.fromString(trackingStr);

  // ============ COMPUTED FIELDS ============

  /// Check if product has stock available
  bool get hasStock => qtyAvailable > 0;

  /// Check if product has virtual stock (including incoming)
  bool get hasVirtualStock => virtualAvailable > 0;

  /// Check if product has a barcode
  bool get hasBarcode => barcode != null && barcode!.isNotEmpty;

  /// Check if product has a default code (internal reference)
  bool get hasDefaultCode => defaultCode != null && defaultCode!.isNotEmpty;

  /// Display name with code prefix if available
  String get displayName {
    if (displayNameOdoo != null && displayNameOdoo!.isNotEmpty) {
      return displayNameOdoo!;
    }
    if (hasDefaultCode) {
      return '[$defaultCode] $name';
    }
    return name;
  }

  /// Check if product is a service
  bool get isService => type == ProductType.service;

  /// Check if product is consumable/goods
  bool get isConsumable => type == ProductType.consu;

  /// Check if product can be sold
  bool get canBeSold => saleOk && active;

  /// Check if product can be dispatched (Ecuador)
  bool get canBeDispatched => !temporalNoDespachar;

  /// Has taxes configured
  bool get hasTaxes => taxIds.isNotEmpty;

  /// Has supplier taxes configured
  bool get hasSupplierTaxes => supplierTaxIds.isNotEmpty;

  /// Requires inventory tracking
  bool get requiresTracking => tracking.requiresTracking;

  // ============ JSON HELPERS (for local storage of many2many) ============

  /// Tax IDs as JSON string (for SQLite storage)
  String? get taxIdsJson => taxIds.isEmpty ? null : jsonEncode(taxIds);

  /// Supplier tax IDs as JSON string
  String? get supplierTaxIdsJson => supplierTaxIds.isEmpty ? null : jsonEncode(supplierTaxIds);

  /// Parse JSON string to tax IDs list
  static List<int> parseTaxIdsJson(String? json) {
    if (json == null || json.isEmpty) return [];
    try {
      final decoded = jsonDecode(json);
      if (decoded is List) return decoded.cast<int>();
      return [];
    } catch (_) {
      // Try comma-separated format
      return json
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
    }
  }
}

/// List of Odoo fields to fetch for Product
const productOdooFields = [
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
  'uom_po_id',
  'taxes_id',
  'supplier_taxes_id',
  'description',
  'description_sale',
  'product_tmpl_id',
  'qty_available',
  'virtual_available',
  'tracking',
  'is_storable',
  'l10n_ec_auxiliary_code',
  'is_unit_product',
  'temporal_no_despachar',
  'write_date',
];
