import 'dart:convert';

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'product.model.freezed.dart';
part 'product.model.g.dart';

/// Product type enum matching Odoo's product.template.type
enum ProductType {
  @JsonValue('consu')
  consu, // Consumable (Goods)
  @JsonValue('service')
  service, // Service
  @JsonValue('product')
  product, // Storable Product (deprecated in newer Odoo)
}

/// Tracking type for inventory
enum TrackingType {
  @JsonValue('none')
  none,
  @JsonValue('serial')
  serial,
  @JsonValue('lot')
  lot,
}

/// Product model with computed fields like Odoo @api.depends
///
/// Uses @OdooModel annotation pattern for field mapping and code generation.
///
/// ## Computed fields (equivalent to @api.depends in Odoo)
/// - [hasStock] -> depends: [qtyAvailable]
/// - [hasBarcode] -> depends: [barcode]
/// - [displayName] -> depends: [defaultCode, name]
/// - [taxIdsList] -> depends: [taxesId]
@OdooModel('product.product', tableName: 'product_product')
@freezed
abstract class Product with _$Product {
  const Product._(); // Enable custom methods

  const factory Product({
    // ============ Identifiers ============
    @OdooId() required int id,

    // ============ Basic Data ============
    @OdooString() required String name,
    @OdooString(odooName: 'display_name', writable: false) String? displayNameOdoo,
    @OdooString(odooName: 'default_code') String? defaultCode,
    @OdooString() String? barcode,
    @OdooSelection() @Default(ProductType.consu) ProductType type,
    @OdooBoolean(odooName: 'sale_ok') @Default(true) bool saleOk,
    @OdooBoolean(odooName: 'purchase_ok') @Default(true) bool purchaseOk,
    @OdooBoolean() @Default(true) bool active,

    // ============ Pricing ============
    @OdooFloat(odooName: 'list_price') @Default(0.0) double listPrice,
    @OdooFloat(odooName: 'standard_price') @Default(0.0) double standardPrice,

    // ============ Category ============
    @OdooMany2One('product.category', odooName: 'categ_id') int? categId,
    @OdooMany2OneName(sourceField: 'categ_id') String? categName,

    // ============ Unit of Measure ============
    @OdooMany2One('uom.uom', odooName: 'uom_id') int? uomId,
    @OdooMany2OneName(sourceField: 'uom_id') String? uomName,
    @OdooMany2One('uom.uom', odooName: 'uom_po_id') int? uomPoId,
    @OdooMany2OneName(sourceField: 'uom_po_id') String? uomPoName,
    @OdooLocalOnly() List<int>? uomIds, // Allowed UoMs

    // ============ Taxes ============
    @OdooJson(odooName: 'taxes_id') String? taxesId,
    @OdooJson(odooName: 'supplier_taxes_id') String? supplierTaxesId,

    // ============ Description ============
    @OdooString() String? description,
    @OdooString(odooName: 'description_sale') String? descriptionSale,

    // ============ Template Reference ============
    @OdooMany2One('product.template', odooName: 'product_tmpl_id') int? productTmplId,

    // ============ Image ============
    @OdooBinary(odooName: 'image_128') String? image128,

    // ============ Inventory ============
    @OdooFloat(odooName: 'qty_available', writable: false) @Default(0.0) double qtyAvailable,
    @OdooFloat(odooName: 'virtual_available', writable: false) @Default(0.0) double virtualAvailable,
    @OdooSelection() @Default(TrackingType.none) TrackingType tracking,
    @OdooBoolean(odooName: 'is_storable') @Default(false) bool isStorable,

    // ============ Ecuador Localization ============
    @OdooString(odooName: 'l10n_ec_auxiliary_code') String? l10nEcAuxiliaryCode,
    @OdooBoolean(odooName: 'is_unit_product') @Default(true) bool isUnitProduct,
    @OdooBoolean(odooName: 'temporal_no_despachar') @Default(false) bool temporalNoDespachar,

    // ============ Metadata ============
    @OdooDateTime(odooName: 'write_date', writable: false) DateTime? writeDate,
  }) = _Product;

  // ============ COMPUTED FIELDS (like @api.depends) ============

  /// Check if product has stock available
  /// @api.depends('qty_available')
  bool get hasStock => qtyAvailable > 0;

  /// Check if product has virtual stock (including incoming)
  /// @api.depends('virtual_available')
  bool get hasVirtualStock => virtualAvailable > 0;

  /// Check if product has a barcode
  /// @api.depends('barcode')
  bool get hasBarcode => barcode != null && barcode!.isNotEmpty;

  /// Check if product has a default code (internal reference)
  /// @api.depends('default_code')
  bool get hasDefaultCode => defaultCode != null && defaultCode!.isNotEmpty;

  /// Display name with code prefix if available
  /// @api.depends('default_code', 'name')
  String get displayName {
    if (displayNameOdoo != null && displayNameOdoo!.isNotEmpty) {
      return displayNameOdoo!;
    }
    if (hasDefaultCode) {
      return '[$defaultCode] $name';
    }
    return name;
  }

  /// Parse tax IDs from JSON string
  /// @api.depends('taxes_id')
  List<int> get taxIdsList {
    if (taxesId == null || taxesId!.isEmpty) return [];
    try {
      final decoded = jsonDecode(taxesId!);
      if (decoded is List) {
        return decoded.cast<int>();
      }
      return [];
    } catch (_) {
      // Try parsing comma-separated format
      return taxesId!
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
    }
  }

  /// Parse supplier tax IDs from JSON string
  List<int> get supplierTaxIdsList {
    if (supplierTaxesId == null || supplierTaxesId!.isEmpty) return [];
    try {
      final decoded = jsonDecode(supplierTaxesId!);
      if (decoded is List) {
        return decoded.cast<int>();
      }
      return [];
    } catch (_) {
      return supplierTaxesId!
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
    }
  }

  /// Parse allowed UoM IDs
  List<int> get allowedUomIds {
    if (uomIds == null || uomIds!.isEmpty) return uomId != null ? [uomId!] : [];
    return uomIds!;
  }

  /// Check if product is a service
  bool get isService => type == ProductType.service;

  /// Check if product is consumable/goods
  bool get isConsumable => type == ProductType.consu;

  /// Check if product can be sold
  bool get canBeSold => saleOk && active;

  /// Check if product can be dispatched (Ecuador)
  bool get canBeDispatched => !temporalNoDespachar;

  // ============ BUSINESS LOGIC METHODS ============

  /// Simula onchange del precio de lista.
  ///
  /// Recalcula margenes si es necesario.
  Product onPriceChanged(double newListPrice) {
    if (newListPrice < 0) return this;
    return copyWith(listPrice: newListPrice);
  }

  /// Simula cambio de UoM.
  Product onUomChanged(int? newUomId, String? newUomName) {
    return copyWith(
      uomId: newUomId,
      uomName: newUomName,
    );
  }

  /// Crea una copia del producto con datos de una linea de venta.
  ///
  /// Util para pre-popular lineas de orden de venta.
  Map<String, dynamic> toSaleLineDefaults() {
    return {
      'productId': id,
      'productName': displayName,
      'productCode': defaultCode,
      'priceUnit': listPrice,
      'productUomId': uomId,
      'productUomName': uomName,
      'taxIds': taxesId,
      'productType': type.name,
      'categId': categId,
      'categName': categName,
      'isUnitProduct': isUnitProduct,
    };
  }
}
