/// Example: Product model using OdooModelManager framework
///
/// This shows how the current 330-line Product model would be simplified
/// to ~60 lines using the new framework with code generation.
///
/// **Before (current theos_pos):**
/// - product.model.dart: 330 lines
/// - product_repository.dart: ~150 lines
/// - product_record_handler.dart: ~100 lines
/// - database.dart (table): ~50 lines
/// - **Total: ~630 lines**
///
/// **After (with odoo_model_manager):**
/// - product.dart: ~60 lines (this file)
/// - Generated: ProductManager, ProductTable, conversions
/// - **Total: ~60 lines of hand-written code**
library;

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

part 'product_example.freezed.dart';

/// Product type enum matching Odoo's product.template.type
enum ProductType {
  consu,
  service,
  product,
}

/// Tracking type for inventory
enum TrackingType {
  none,
  serial,
  lot,
}

/// Product model with Odoo field annotations.
///
/// The @OdooModel annotation triggers code generation for:
/// - ProductManager (OdooModelManager<Product>)
/// - ProductTable (Drift table)
/// - fromOdoo() / toOdoo() conversions
@OdooModel('product.product')
@freezed
abstract class Product with _$Product {
  const Product._();

  const factory Product({
    // ═══════════════════ Identifiers ═══════════════════
    @OdooId() required int id,

    @OdooLocalOnly()
    String? uuid,

    @OdooLocalOnly()
    @Default(false)
    bool isSynced,

    // ═══════════════════ Basic Data ═══════════════════
    @OdooString()
    required String name,

    @OdooString(odooName: 'display_name')
    String? displayNameOdoo,

    @OdooString(odooName: 'default_code')
    String? defaultCode,

    @OdooString()
    String? barcode,

    @OdooSelection(options: {
      'consu': 'Consumable',
      'service': 'Service',
      'product': 'Storable',
    })
    @Default('consu')
    String type,

    @OdooBoolean(odooName: 'sale_ok')
    @Default(true)
    bool saleOk,

    @OdooBoolean(odooName: 'purchase_ok')
    @Default(true)
    bool purchaseOk,

    @OdooBoolean()
    @Default(true)
    bool active,

    // ═══════════════════ Pricing ═══════════════════
    @OdooMonetary(odooName: 'list_price')
    @Default(0.0)
    double listPrice,

    @OdooMonetary(odooName: 'standard_price')
    @Default(0.0)
    double standardPrice,

    // ═══════════════════ Category ═══════════════════
    @OdooMany2One('product.category', odooName: 'categ_id')
    int? categId,

    @OdooMany2OneName(sourceField: 'categ_id')
    String? categName,

    // ═══════════════════ Unit of Measure ═══════════════════
    @OdooMany2One('uom.uom', odooName: 'uom_id')
    int? uomId,

    @OdooMany2OneName(sourceField: 'uom_id')
    String? uomName,

    @OdooMany2One('uom.uom', odooName: 'uom_po_id')
    int? uomPoId,

    @OdooMany2OneName(sourceField: 'uom_po_id')
    String? uomPoName,

    // ═══════════════════ Taxes ═══════════════════
    @OdooMany2Many('account.tax', odooName: 'taxes_id')
    List<int>? taxesId,

    @OdooMany2Many('account.tax', odooName: 'supplier_taxes_id')
    List<int>? supplierTaxesId,

    // ═══════════════════ Description ═══════════════════
    @OdooHtml()
    String? description,

    @OdooString(odooName: 'description_sale')
    String? descriptionSale,

    // ═══════════════════ Template Reference ═══════════════════
    @OdooMany2One('product.template', odooName: 'product_tmpl_id')
    int? productTmplId,

    // ═══════════════════ Image ═══════════════════
    @OdooBinary(odooName: 'image_128', fetchByDefault: false)
    String? image128,

    // ═══════════════════ Inventory ═══════════════════
    @OdooFloat(odooName: 'qty_available')
    @Default(0.0)
    double qtyAvailable,

    @OdooFloat(odooName: 'virtual_available')
    @Default(0.0)
    double virtualAvailable,

    @OdooSelection(options: {
      'none': 'No Tracking',
      'serial': 'By Serial Number',
      'lot': 'By Lot',
    })
    @Default('none')
    String tracking,

    @OdooBoolean(odooName: 'is_storable')
    @Default(false)
    bool isStorable,

    // ═══════════════════ Ecuador Localization ═══════════════════
    @OdooString(odooName: 'l10n_ec_auxiliary_code')
    String? l10nEcAuxiliaryCode,

    @OdooBoolean(odooName: 'is_unit_product')
    @Default(true)
    bool isUnitProduct,

    @OdooBoolean(odooName: 'temporal_no_despachar')
    @Default(false)
    bool temporalNoDespachar,

    // ═══════════════════ Metadata ═══════════════════
    @OdooDateTime(odooName: 'write_date')
    DateTime? writeDate,
  }) = _Product;

  // ═══════════════════ COMPUTED FIELDS ═══════════════════
  // These remain as getters - not stored, not synced

  /// Check if product has stock available
  bool get hasStock => qtyAvailable > 0;

  /// Check if product has virtual stock
  bool get hasVirtualStock => virtualAvailable > 0;

  /// Check if product has a barcode
  bool get hasBarcode => barcode != null && barcode!.isNotEmpty;

  /// Check if product has a default code
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
  bool get isService => type == 'service';

  /// Check if product is consumable
  bool get isConsumable => type == 'consu';

  /// Check if product can be sold
  bool get canBeSold => saleOk && active;

  /// Check if product can be dispatched (Ecuador)
  bool get canBeDispatched => !temporalNoDespachar;
}

// ═══════════════════════════════════════════════════════════════════════════
// USAGE EXAMPLE
// ═══════════════════════════════════════════════════════════════════════════

/*
// At app startup:
void initializeOdooModels() {
  final client = OdooClient(config: OdooClientConfig(
    baseUrl: 'https://odoo.example.com',
    apiKey: 'your_api_key',
    database: 'your_database',
  ));

  // Register managers
  ModelRegistry.register(productManager); // Auto-generated global instance

  // Initialize all with dependencies
  ModelRegistry.initializeAll(
    client: client,
    db: database,
    queue: offlineQueue,
  );

  // Setup WebSocket for real-time updates
  ModelRegistry.setupWebSocketHandlers(wsService.recordEvents);
}

// In your code:
void example() async {
  // Search products (offline-first)
  final products = await productManager.search(
    domain: [['active', '=', true]],
    limit: 50,
  );

  // Create new product (works offline)
  final newId = await productManager.create(Product(
    id: 0, // Will be replaced
    name: 'New Product',
    listPrice: 99.99,
  ));

  // Update product
  await productManager.update(product.copyWith(
    listPrice: 89.99,
  ));

  // Sync with Odoo
  final result = await productManager.syncFromOdoo(
    onProgress: (progress) {
      print('Synced ${progress.synced}/${progress.total}');
    },
  );

  // Sync all models
  final report = await ModelRegistry.syncAll();
  print('Total synced: ${report.totalSynced}');
}
*/
