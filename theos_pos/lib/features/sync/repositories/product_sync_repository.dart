/// ProductSyncRepository - Sync de catálogo de productos usando GenericSyncRepository
///
/// Maneja sincronización de:
/// - Products (product.product)
/// - Product Categories (product.category)
/// - Taxes (account.tax)
/// - Units of Measure (uom.uom)
/// - Product UoM with barcodes (product.uom)
/// - Pricelists and items (product.pricelist, product.pricelist.item)
/// - Payment Terms (account.payment.term)
library;

import 'package:odoo_sdk/odoo_sdk.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

/// Repository for syncing product-related catalog data from Odoo.
///
/// Usa GenericSyncRepository para eliminar código repetitivo de:
/// - Paginación manual
/// - Reporte de progreso
/// - Verificación de cancelación
class ProductSyncRepository {
  final OdooClient? odooClient;
  final AppDatabase db;
  final GenericSyncRepository _syncRepo;

  // Managers for model operations
  late final ProductManager _productManager;
  late final ProductCategoryManager _categoryManager;
  late final TaxManager _taxManager;
  late final UomManager _uomManager;
  late final ProductUomManager _productUomManager;
  late final PricelistManager _pricelistManager;
  late final PricelistItemManager _pricelistItemManager;
  late final PaymentTermManager _paymentTermManager;

  ProductSyncRepository({
    required this.db,
    this.odooClient,
  }) : _syncRepo = GenericSyncRepository(odooClient: odooClient) {
    _productManager = productManager;
    _categoryManager = productCategoryManager;
    _taxManager = taxManager;
    _uomManager = uomManager;
    _productUomManager = productUomManager;
    _pricelistManager = pricelistManager;
    _pricelistItemManager = PricelistItemManager(db);
    _paymentTermManager = paymentTermManager;
  }

  bool get isOnline => odooClient != null;

  void cancelSync() => _syncRepo.cancelSync();
  void resetCancelFlag() => _syncRepo.resetCancelFlag();

  // ============ Product Fields ============

  static const _productFields = [
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
    'uom_ids',
    'taxes_id',
    'supplier_taxes_id',
    'description',
    'description_sale',
    'product_tmpl_id',
    'image_128',
    'qty_available',
    'virtual_available',
    'write_date',
    'tracking',
    'is_storable',
    'is_unit_product',
    'temporal_no_despachar',
    'l10n_ec_auxiliary_code',
  ];

  // ============ Single Model Sync Methods ============

  /// Sync products
  Future<int> syncProducts({
    int batchSize = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: 'product.product',
        fields: _productFields,
        domain: [
          ['sale_ok', '=', true],
          ['active', '=', true],
        ],
        batchSize: batchSize,
        fromOdoo: _productManager.fromOdoo,
        upsertLocal: _productManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  /// Sync product categories
  Future<int> syncProductCategories({
    int batchSize = 200,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: 'product.category',
        fields: ['id', 'name', 'complete_name', 'parent_id', 'write_date'],
        batchSize: batchSize,
        fromOdoo: _categoryManager.fromOdoo,
        upsertLocal: _categoryManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  /// Sync taxes
  Future<int> syncTaxes({
    int batchSize = 200,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: 'account.tax',
        fields: [
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
        ],
        domain: [
          ['active', '=', true],
        ],
        batchSize: batchSize,
        fromOdoo: _taxManager.fromOdoo,
        upsertLocal: _taxManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  /// Sync units of measure
  Future<int> syncUom({
    int limit = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: 'uom.uom',
        fields: [
          'id',
          'name',
          'factor',
          'active',
          'write_date',
        ],
        domain: [
          ['active', '=', true],
        ],
        batchSize: limit,
        order: 'name asc',
        fromOdoo: _uomManager.fromOdoo,
        upsertLocal: _uomManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  /// Sync product UoMs (packaging barcodes)
  Future<int> syncProductUom({
    int limit = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      ModelSyncConfig(
        model: 'product.uom',
        fields: [
          'id',
          'product_id',
          'uom_id',
          'barcode',
          'company_id',
          'write_date',
        ],
        batchSize: limit,
        upsertRecord: (data) async {
          final productUom = _productUomManager.fromOdoo(data);
          // Skip if no product or uom
          if (productUom.productId == 0 || productUom.uomId == 0) return;
          await _productUomManager.upsertLocal(productUom);
        },
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  /// Sync pricelists (and their items)
  Future<int> syncPricelists({
    int limit = 50,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      ModelSyncConfig(
        model: 'product.pricelist',
        fields: [
          'id',
          'name',
          'active',
          'currency_id',
          'company_id',
          'sequence',
          'write_date',
        ],
        domain: [
          ['active', '=', true],
        ],
        batchSize: limit,
        order: 'sequence asc',
        upsertRecord: (data) async {
          final pricelist = _pricelistManager.fromOdoo(data);
          await _pricelistManager.upsertLocal(pricelist);
          // Also sync pricelist items for this pricelist
          await _syncPricelistItems(pricelistId: pricelist.id);
        },
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  /// Sync pricelist items for a specific pricelist
  Future<int> _syncPricelistItems({required int pricelistId, int limit = 500}) async {
    if (!isOnline) return 0;

    try {
      final items = await odooClient!.searchRead(
        model: 'product.pricelist.item',
        domain: [
          ['pricelist_id', '=', pricelistId],
        ],
        fields: [
          'id',
          'pricelist_id',
          'product_tmpl_id',
          'product_id',
          'categ_id',
          'applied_on',
          'min_quantity',
          'date_start',
          'date_end',
          'compute_price',
          'fixed_price',
          'percent_price',
          'base',
          'base_pricelist_id',
          'price_discount',
          'price_surcharge',
          'price_round',
          'price_min_margin',
          'price_max_margin',
          'uom_id',
          'write_date',
        ],
        limit: limit,
      );

      int count = 0;
      for (final item in items) {
        final pricelistItem = _pricelistItemManager.fromOdoo(item);
        await _pricelistItemManager.upsertLocal(pricelistItem);
        count++;
      }
      return count;
    } catch (e) {
      logger.e('[ProductSync] Error syncing pricelist items: $e');
      return 0;
    }
  }

  /// Sync payment terms
  Future<int> syncPaymentTerms({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    final result = await _syncRepo.syncModel(
      SyncConfigBuilder.create(
        model: 'account.payment.term',
        fields: [
          'id',
          'name',
          'active',
          'note',
          'company_id',
          'sequence',
          'is_cash',
          'is_credit',
          'write_date',
        ],
        domain: [
          ['active', '=', true],
        ],
        batchSize: batchSize,
        fromOdoo: _paymentTermManager.fromOdoo,
        upsertLocal: _paymentTermManager.upsertLocal,
      ),
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
    return result.synced;
  }

  // ============ Aggregate Sync ============

  /// Sync all product-related catalog data in the recommended order.
  ///
  /// Order: Categories -> UoM -> Taxes -> Products -> ProductUom -> Pricelists -> PaymentTerms
  Future<AggregateSyncResult> syncAllCatalog({
    DateTime? sinceDate,
    MultiModelProgressCallback? onProgress,
  }) async {
    return _syncRepo.syncModels(
      [
        // Categories first (products reference them)
        SyncConfigBuilder.create(
          model: 'product.category',
          fields: ['id', 'name', 'complete_name', 'parent_id', 'write_date'],
          batchSize: 200,
          fromOdoo: _categoryManager.fromOdoo,
          upsertLocal: _categoryManager.upsertLocal,
        ),

        // UoM (products reference them)
        SyncConfigBuilder.create(
          model: 'uom.uom',
          fields: ['id', 'name', 'factor', 'active', 'write_date'],
          domain: [
            ['active', '=', true]
          ],
          batchSize: 100,
          fromOdoo: _uomManager.fromOdoo,
          upsertLocal: _uomManager.upsertLocal,
        ),

        // Taxes (products reference them)
        SyncConfigBuilder.create(
          model: 'account.tax',
          fields: [
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
          ],
          domain: [
            ['active', '=', true]
          ],
          batchSize: 200,
          fromOdoo: _taxManager.fromOdoo,
          upsertLocal: _taxManager.upsertLocal,
        ),

        // Products
        SyncConfigBuilder.create(
          model: 'product.product',
          fields: _productFields,
          domain: [
            ['sale_ok', '=', true],
            ['active', '=', true],
          ],
          batchSize: 500,
          fromOdoo: _productManager.fromOdoo,
          upsertLocal: _productManager.upsertLocal,
        ),

        // Product UoM (needs products)
        ModelSyncConfig(
          model: 'product.uom',
          fields: [
            'id',
            'product_id',
            'uom_id',
            'barcode',
            'company_id',
            'write_date'
          ],
          batchSize: 500,
          upsertRecord: (data) async {
            final productUom = _productUomManager.fromOdoo(data);
            if (productUom.productId == 0 || productUom.uomId == 0) return;
            await _productUomManager.upsertLocal(productUom);
          },
        ),

        // Pricelists (with items)
        ModelSyncConfig(
          model: 'product.pricelist',
          fields: [
            'id',
            'name',
            'active',
            'currency_id',
            'company_id',
            'sequence',
            'write_date'
          ],
          domain: [
            ['active', '=', true]
          ],
          batchSize: 50,
          order: 'sequence asc',
          upsertRecord: (data) async {
            final pricelist = _pricelistManager.fromOdoo(data);
            await _pricelistManager.upsertLocal(pricelist);
            await _syncPricelistItems(pricelistId: pricelist.id);
          },
        ),

        // Payment Terms
        SyncConfigBuilder.create(
          model: 'account.payment.term',
          fields: [
            'id',
            'name',
            'active',
            'note',
            'company_id',
            'sequence',
            'is_cash',
            'is_credit',
            'write_date',
          ],
          domain: [
            ['active', '=', true]
          ],
          batchSize: 100,
          fromOdoo: _paymentTermManager.fromOdoo,
          upsertLocal: _paymentTermManager.upsertLocal,
        ),
      ],
      sinceDate: sinceDate,
      onProgress: onProgress,
    );
  }
}
