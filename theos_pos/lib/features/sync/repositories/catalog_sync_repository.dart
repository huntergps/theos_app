import 'dart:convert';

import 'package:drift/drift.dart';
import '../../../core/database/database_helper.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

// Import split repositories
import 'product_sync_repository.dart';
import 'partner_sync_repository.dart';
import 'sale_order_sync_repository.dart';
import 'user_sync_repository.dart';
import 'qweb_template_sync_repository.dart';
import '../../banks/repositories/bank_repository.dart';
import '../../products/repositories/product_repository.dart';

// Import and re-export sync data classes for backward compatibility
import 'sync_models.dart';
export 'sync_models.dart';

/// Facade repository for syncing master catalogs from Odoo to local SQLite
///
/// This class delegates to specialized repositories:
/// - [ProductSyncRepository]: Products, categories, taxes, UoM, pricelists, payment terms
/// - [PartnerSyncRepository]: Partners/customers
/// - [SaleOrderSyncRepository]: Sale orders and lines
/// - [UserSyncRepository]: Users, warehouses, teams, companies, etc.
///
/// Maintains backward compatibility while using focused implementations internally.
class CatalogSyncRepository {
  final OdooClient? odooClient;
  final DatabaseHelper db;
  final ProductRepository? _productRepository;

  /// Always access the CURRENT database via DatabaseHelper to avoid
  /// stale references after server switch ("connection was closed" bug).
  // ignore: deprecated_member_use_from_same_package
  AppDatabase get _appDb => DatabaseHelper.db;

  // Delegate repositories (lazy initialized)
  late final ProductSyncRepository _productSync;
  late final PartnerSyncRepository _partnerSync;
  late final SaleOrderSyncRepository _saleOrderSync;
  late final UserSyncRepository _userSync;
  late final QwebTemplateSyncRepository _qwebTemplateSync;
  late final BankRepository _bankRepo;

  /// Flag to request sync cancellation
  bool _cancelRequested = false;

  CatalogSyncRepository({
    required this.db,
    this.odooClient,
    ProductRepository? productRepository,
    AppDatabase? appDb, // kept for API compatibility but ignored
  })  : _productRepository = productRepository {
    // Initialize delegate repositories
    // Sub-repos that take AppDatabase also use DatabaseHelper.db internally
    _productSync = ProductSyncRepository(db: _appDb, odooClient: odooClient);
    _partnerSync = PartnerSyncRepository(db: _appDb, odooClient: odooClient);
    _saleOrderSync = SaleOrderSyncRepository(
      db: db,
      odooClient: odooClient,
      productRepository: _productRepository,
    );
    _userSync = UserSyncRepository(
      db: db,
      odooClient: odooClient,
    );
    _qwebTemplateSync = QwebTemplateSyncRepository(
      db: db,
      odooClient: odooClient,
    );
    // Centralized bank repository (odooClient is optional - works offline)
    _bankRepo = BankRepository(db: _appDb, odooClient: odooClient);
  }

  bool get isOnline => odooClient != null;

  /// Request cancellation of current sync operation
  void cancelSync() {
    _cancelRequested = true;
    _productSync.cancelSync();
    _partnerSync.cancelSync();
    _saleOrderSync.cancelSync();
    _userSync.cancelSync();
    _qwebTemplateSync.cancelSync();
    logger.d('[CatalogSync] Cancellation requested');
  }

  /// Reset the cancellation flag (call before starting a new sync)
  void resetCancelFlag() {
    _cancelRequested = false;
    _productSync.resetCancelFlag();
    _partnerSync.resetCancelFlag();
    _saleOrderSync.resetCancelFlag();
    _userSync.resetCancelFlag();
    _qwebTemplateSync.resetCancelFlag();
  }

  /// Check if cancellation was requested
  bool get isCancelRequested => _cancelRequested;

  // ============================================================================
  // PRODUCT SYNC (delegates to ProductSyncRepository)
  // ============================================================================

  /// Sync all products from Odoo to local database
  Future<int> syncProducts({
    int batchSize = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _productSync.syncProducts(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync product categories
  Future<int> syncProductCategories({
    int batchSize = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _productSync.syncProductCategories(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync taxes
  Future<int> syncTaxes({
    int batchSize = 200,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _productSync.syncTaxes(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync units of measure
  Future<int> syncUom({
    int batchSize = 200,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _productSync.syncUom(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync product-specific UoM relationships
  Future<int> syncProductUom({
    int batchSize = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _productSync.syncProductUom(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync pricelists (pricelist items are synced automatically with each pricelist)
  Future<int> syncPricelists({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _productSync.syncPricelists(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync payment terms
  Future<int> syncPaymentTerms({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _productSync.syncPaymentTerms(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  // ============================================================================
  // PARTNER SYNC (delegates to PartnerSyncRepository)
  // ============================================================================

  /// Sync partners/customers
  Future<int> syncPartners({
    int batchSize = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _partnerSync.syncPartners(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  // ============================================================================
  // SALE ORDER SYNC (delegates to SaleOrderSyncRepository)
  // ============================================================================

  /// Sync sale orders
  Future<int> syncSaleOrders({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
    List<String>? states,
  }) => _saleOrderSync.syncSaleOrders(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Fetch sale orders (uses Drift SaleOrderData)
  Future<List<SaleOrderData>> fetchSaleOrdersWithLines({
    int? limit,
    int? offset,
    String? state,
    DateTime? sinceDate,
    String? searchTerm,
    int? partnerId,
    List<String>? states,
    bool forceRefresh = false,
  }) => _saleOrderSync.fetchSaleOrdersWithLines(
    limit: limit ?? 50,
    state: state,
    partnerId: partnerId,
    forceRefresh: forceRefresh,
  );

  /// Search sale orders with lines
  Future<List<SaleOrderData>> searchSaleOrdersWithLines(
    String searchTerm, {
    int? limit,
    int? offset,
    List<String>? states,
  }) =>
      _saleOrderSync.searchSaleOrdersWithLines(searchTerm, limit: limit ?? 20);

  // ============================================================================
  // USER SYNC (delegates to UserSyncRepository)
  // ============================================================================

  /// Sync currencies
  Future<int> syncCurrencies({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    // UserSyncRepository.syncCurrencies doesn't take onProgress yet, but it's fast
    await _userSync.syncCurrencies();
    return 0; // Returns count if updated, but void for now
  }

  /// Sync decimal precision
  Future<int> syncDecimalPrecision({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    await _userSync.syncDecimalPrecision();
    return 0;
  }

  /// Sync users
  Future<int> syncUsers({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncUsers(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync security groups (res.groups)
  Future<int> syncGroups({
    int batchSize = 200,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncGroups(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync warehouses
  Future<int> syncWarehouses({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncWarehouses(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync sales teams
  Future<int> syncTeams({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncTeams(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync fiscal positions
  Future<int> syncFiscalPositions({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncFiscalPositions(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync fiscal position tax mappings
  /// These define how taxes are mapped for different fiscal positions
  Future<int> syncFiscalPositionTaxMappings({
    int batchSize = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncFiscalPositionTaxMappings(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Get fiscal position tax mappings for a specific position
  Future<List<AccountFiscalPositionTaxData>> getFiscalPositionTaxMappings(
    int positionId,
  ) => _userSync.getFiscalPositionTaxMappings(positionId);

  /// Sync journals
  Future<int> syncJournals({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncJournals(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  // ============================================================================
  // PAYMENT DATA SYNC (payment methods, advances)
  // ============================================================================

  /// Sync payment method lines (payment methods per journal)
  Future<int> syncPaymentMethodLines({
    int batchSize = 200,
    DateTime? sinceDate,
  }) =>
      _userSync.syncPaymentMethodLines(limit: batchSize, sinceDate: sinceDate);

  /// Sync banks for offline payment processing (delegated to BankRepository)
  Future<int> syncBanks({
    int batchSize = 200,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _bankRepo.syncBanks(limit: batchSize);

  /// Sync customer advances
  Future<int> syncAdvances({int batchSize = 100, DateTime? sinceDate}) =>
      _userSync.syncAdvances(limit: batchSize, sinceDate: sinceDate);

  /// Sync credit notes with residual balance
  Future<int> syncCreditNotes({int batchSize = 100, DateTime? sinceDate}) =>
      _userSync.syncCreditNotes(limit: batchSize, sinceDate: sinceDate);

  /// Sync collection configs
  Future<int> syncCollectionConfigs({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncCollectionConfigs(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync company
  Future<int> syncCompany({
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncCompany(onProgress: onProgress, sinceDate: sinceDate);

  /// Sync countries
  Future<int> syncCountries({
    int batchSize = 300,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncCountries(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync country states
  Future<int> syncCountryStates({
    int batchSize = 500,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncCountryStates(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync languages
  Future<int> syncLanguages({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _userSync.syncLanguages(
    limit: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  // ============================================================================
  // QWEB TEMPLATE SYNC (delegates to QwebTemplateSyncRepository)
  // ============================================================================

  /// Sync QWeb templates for a specific model (e.g., 'sale.order')
  ///
  /// Templates are fetched with all inheritance resolved for offline PDF generation.
  Future<int> syncQwebTemplates(
    String model, {
    SyncProgressCallback? onProgress,
  }) => _qwebTemplateSync.syncTemplatesForModel(model, onProgress: onProgress);

  /// Sync QWeb templates for multiple models
  Future<Map<String, int>> syncAllQwebTemplates({
    List<String> models = const ['sale.order'],
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _qwebTemplateSync.syncAllTemplates(
    models: models,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync a single QWeb template by key
  Future<bool> syncSingleQwebTemplate(String templateKey) =>
      _qwebTemplateSync.syncTemplate(templateKey);

  /// Check for QWeb template updates using checksums
  Future<List<String>> checkQwebTemplateUpdates(List<String> templateKeys) =>
      _qwebTemplateSync.checkForUpdates(templateKeys);

  // ============================================================================
  // SYNC ALL CATALOGS
  // ============================================================================

  /// Sync all catalogs in sequence
  Future<Map<String, int>> syncAllCatalogs() async {
    final results = <String, int>{};

    try {
      results['users'] = await syncUsers();
      results['groups'] = await syncGroups();
      results['warehouses'] = await syncWarehouses();
      results['teams'] = await syncTeams();
      results['company'] = await syncCompany();
      // Core Config
      results['currencies'] = await syncCurrencies();
      results['decimalPrecision'] = await syncDecimalPrecision();
      results['countries'] = await syncCountries();
      results['states'] = await syncCountryStates();
      results['languages'] = await syncLanguages();
      results['fiscalPositions'] = await syncFiscalPositions();
      results['fiscalPositionTaxes'] = await syncFiscalPositionTaxMappings();
      results['journals'] = await syncJournals();
      // Payment-related data (depends on journals)
      results['paymentMethodLines'] = await syncPaymentMethodLines();
      results['advances'] = await syncAdvances();
      results['creditNotes'] = await syncCreditNotes();
      results['collectionConfigs'] = await syncCollectionConfigs();
      results['categories'] = await syncProductCategories();
      results['taxes'] = await syncTaxes();
      results['uom'] = await syncUom();
      results['productUom'] = await syncProductUom();
      results['paymentTerms'] = await syncPaymentTerms();
      results['pricelists'] = await syncPricelists();
      results['partners'] = await syncPartners();
      results['products'] = await syncProducts();
      results['saleOrders'] = await syncSaleOrders();

      await _saveLastSyncTime();

      logger.i('[CatalogSync] All catalogs synced: $results');
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing all catalogs', e);
      rethrow;
    }

    return results;
  }

  // ============================================================================
  // SYNC METADATA
  // ============================================================================

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() async {
    try {
      final metadata = await (_appDb.select(
        _appDb.syncMetadata,
      )..where((t) => t.key.equals('last_sync'))).getSingleOrNull();
      if (metadata != null) {
        return DateTime.tryParse(metadata.value);
      }
    } catch (e) {
      logger.e('[CatalogSync]', 'Error getting last sync time', e);
    }
    return null;
  }

  /// Save last sync time
  Future<void> _saveLastSyncTime() async {
    try {
      await _appDb
          .into(_appDb.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion(
              key: const Value('last_sync'),
              value: Value(DateTime.now().toIso8601String()),
            ),
          );
    } catch (e) {
      logger.e('[CatalogSync]', 'Error saving last sync time', e);
    }
  }

  /// Get sync info for a specific model
  Future<SyncModelInfo> getModelSyncInfo(String modelName) async {
    try {
      final metadata = await (_appDb.select(
        _appDb.syncMetadata,
      )..where((t) => t.key.equals('model_$modelName'))).getSingleOrNull();
      if (metadata != null) {
        final json = jsonDecode(metadata.value) as Map<String, dynamic>;
        return SyncModelInfo.fromJson(json);
      }
    } catch (e) {
      logger.e(
        '[CatalogSync]',
        'Error getting model sync info for $modelName',
        e,
      );
    }
    return SyncModelInfo(modelName: modelName);
  }

  /// Save sync info for a specific model
  Future<void> saveModelSyncInfo(SyncModelInfo info) async {
    try {
      await _appDb
          .into(_appDb.syncMetadata)
          .insertOnConflictUpdate(
            SyncMetadataCompanion(
              key: Value('model_${info.modelName}'),
              value: Value(jsonEncode(info.toJson())),
            ),
          );
    } catch (e) {
      logger.e('[CatalogSync]', 'Error saving model sync info', e);
    }
  }

  /// Clear error message for a specific model, allowing it to sync again
  Future<void> clearModelSyncError(String modelName) async {
    try {
      final info = await getModelSyncInfo(modelName);
      if (info.errorMessage != null) {
        await saveModelSyncInfo(info.copyWith(errorMessage: null));
        logger.d('[CatalogSync]', 'Cleared error for model: $modelName');
      }
    } catch (e) {
      logger.e('[CatalogSync]', 'Error clearing model sync error', e);
    }
  }

  /// Get sync info for all models
  Future<Map<String, SyncModelInfo>> getAllModelSyncInfo() async {
    final results = <String, SyncModelInfo>{};
    try {
      final rows = await (_appDb.select(
        _appDb.syncMetadata,
      )..where((t) => t.key.like('model_%'))).get();
      for (final row in rows) {
        final modelName = row.key.replaceFirst('model_', '');
        final json = jsonDecode(row.value) as Map<String, dynamic>;
        results[modelName] = SyncModelInfo.fromJson(json);
      }
    } catch (e) {
      logger.e('[CatalogSync]', 'Error getting all model sync info', e);
    }
    return results;
  }

  /// Clear sync info for a specific model
  Future<void> clearModelSyncInfo(String modelName) async {
    try {
      await (_appDb.delete(
        _appDb.syncMetadata,
      )..where((t) => t.key.equals('model_$modelName'))).go();
    } catch (e) {
      logger.e('[CatalogSync]', 'Error clearing model sync info', e);
    }
  }

  /// Clear all model sync info
  Future<void> clearAllModelSyncInfo() async {
    try {
      await (_appDb.delete(
        _appDb.syncMetadata,
      )..where((t) => t.key.like('model_%'))).go();
    } catch (e) {
      logger.e('[CatalogSync]', 'Error clearing all model sync info', e);
    }
  }

  // ============================================================================
  // CLEAR TABLES
  // ============================================================================

  /// Clear all catalog tables
  Future<Map<String, int>> clearAllCatalogTables() async {
    final results = <String, int>{};

    try {
      results['products'] = await clearCatalogTable('product.product');
      results['categories'] = await clearCatalogTable('product.category');
      results['taxes'] = await clearCatalogTable('account.tax');
      results['uom'] = await clearCatalogTable('uom.uom');
      results['productUom'] = await clearCatalogTable('product.uom');
      results['pricelists'] = await clearCatalogTable('product.pricelist');
      results['pricelistItems'] = await clearCatalogTable(
        'product.pricelist.item',
      );
      results['paymentTerms'] = await clearCatalogTable('account.payment.term');
      results['partners'] = await clearCatalogTable('res.partner');
      results['saleOrders'] = await clearCatalogTable('sale.order');
      results['saleOrderLines'] = await clearCatalogTable('sale.order.line');
      results['users'] = await clearCatalogTable('res.users');
      results['warehouses'] = await clearCatalogTable('stock.warehouse');
      results['teams'] = await clearCatalogTable('crm.team');
      results['fiscalPositions'] = await clearCatalogTable(
        'account.fiscal.position',
      );
      results['fiscalPositionTaxes'] = await clearCatalogTable(
        'account.fiscal.position.tax',
      );
      results['journals'] = await clearCatalogTable('account.journal');
      results['collectionConfigs'] = await clearCatalogTable(
        'collection.config',
      );

      // Clear sync metadata
      await clearAllModelSyncInfo();

      logger.i('[CatalogSync] All catalog tables cleared: $results');
    } catch (e) {
      logger.e('[CatalogSync]', 'Error clearing catalog tables', e);
    }

    return results;
  }

  /// Clear a specific catalog table
  Future<int> clearCatalogTable(String modelName) async {
    try {
      switch (modelName) {
        case 'product.product':
          return await _appDb.delete(_appDb.productProduct).go();
        case 'product.category':
          return await _appDb.delete(_appDb.productCategory).go();
        case 'account.tax':
          return await _appDb.delete(_appDb.accountTax).go();
        case 'uom.uom':
          return await _appDb.delete(_appDb.uomUom).go();
        case 'product.uom':
          return await _appDb.delete(_appDb.productUom).go();
        case 'product.pricelist':
          return await _appDb.delete(_appDb.productPricelist).go();
        case 'product.pricelist.item':
          return await _appDb.delete(_appDb.productPricelistItem).go();
        case 'account.payment.term':
          return await _appDb.delete(_appDb.accountPaymentTerm).go();
        case 'res.partner':
          return await _appDb.delete(_appDb.resPartner).go();
        case 'sale.order':
          return await _appDb.delete(_appDb.saleOrder).go();
        case 'sale.order.line':
          return await _appDb.delete(_appDb.saleOrderLine).go();
        case 'res.users':
          return await _appDb.delete(_appDb.resUsers).go();
        case 'stock.warehouse':
          return await _appDb.delete(_appDb.stockWarehouse).go();
        case 'crm.team':
          return await _appDb.delete(_appDb.crmTeam).go();
        case 'account.fiscal.position':
          return await _appDb.delete(_appDb.accountFiscalPosition).go();
        case 'account.fiscal.position.tax':
          return await _appDb.delete(_appDb.accountFiscalPositionTax).go();
        case 'res.currency':
          return await _appDb.delete(_appDb.resCurrency).go();
        case 'decimal.precision':
          return await _appDb.delete(_appDb.decimalPrecision).go();
        case 'account.journal':
          return await _appDb.delete(_appDb.accountJournal).go();
        case 'collection.config':
          return await _appDb.delete(_appDb.collectionConfig).go();
        case 'ir.ui.view':
          await _qwebTemplateSync.clearAllTemplates();
          return 0; // clearAll doesn't return count
        default:
          logger.w('[CatalogSync] Unknown model for clearing: $modelName');
          return 0;
      }
    } catch (e) {
      logger.e('[CatalogSync]', 'Error clearing table $modelName', e);
      return 0;
    }
  }

  // ============================================================================
  // LOCAL COUNTS
  // ============================================================================

  Future<int> getLocalProductCount() async =>
      (await _appDb.select(_appDb.productProduct).get()).length;

  Future<int> getLocalCategoryCount() async =>
      (await _appDb.select(_appDb.productCategory).get()).length;

  Future<int> getLocalTaxCount() async =>
      (await _appDb.select(_appDb.accountTax).get()).length;

  Future<int> getLocalUomCount() async =>
      (await _appDb.select(_appDb.uomUom).get()).length;

  Future<int> getLocalProductUomCount() async =>
      (await _appDb.select(_appDb.productUom).get()).length;

  Future<int> getLocalPricelistCount() async =>
      (await _appDb.select(_appDb.productPricelist).get()).length;

  Future<int> getLocalPaymentTermCount() async =>
      (await _appDb.select(_appDb.accountPaymentTerm).get()).length;

  Future<int> getLocalPartnerCount() async =>
      (await _appDb.select(_appDb.resPartner).get()).length;

  Future<int> getLocalSaleOrderCount() async =>
      (await _appDb.select(_appDb.saleOrder).get()).length;

  Future<int> getLocalCountForModel(String modelName) async {
    switch (modelName) {
      case 'product.product':
        return getLocalProductCount();
      case 'product.category':
        return getLocalCategoryCount();
      case 'account.tax':
        return getLocalTaxCount();
      case 'uom.uom':
        return getLocalUomCount();
      case 'product.uom':
        return getLocalProductUomCount();
      case 'product.pricelist':
        return getLocalPricelistCount();
      case 'account.payment.term':
        return getLocalPaymentTermCount();
      case 'res.partner':
        return getLocalPartnerCount();
      case 'sale.order':
        return getLocalSaleOrderCount();
      case 'res.users':
        return (await _appDb.select(_appDb.resUsers).get()).length;
      case 'stock.warehouse':
        return (await _appDb.select(_appDb.stockWarehouse).get()).length;
      case 'crm.team':
        return (await _appDb.select(_appDb.crmTeam).get()).length;
      case 'account.fiscal.position':
        return (await _appDb.select(_appDb.accountFiscalPosition).get()).length;
      case 'account.fiscal.position.tax':
        return (await _appDb.select(_appDb.accountFiscalPositionTax).get()).length;
      case 'res.currency':
        return (await _appDb.select(_appDb.resCurrency).get()).length;
      case 'decimal.precision':
        return (await _appDb.select(_appDb.decimalPrecision).get()).length;
      case 'account.journal':
        return (await _appDb.select(_appDb.accountJournal).get()).length;
      case 'account.payment.method.line':
        return (await _appDb.select(_appDb.accountPaymentMethodLine).get()).length;
      case 'account.advance':
        return (await _appDb.select(_appDb.accountAdvance).get()).length;
      case 'account.move':
        return (await _appDb.select(_appDb.accountMove).get()).length;
      case 'collection.config':
        return (await _appDb.select(_appDb.collectionConfig).get()).length;
      case 'res.company':
        return (await _appDb.select(_appDb.resCompanyTable).get()).length;
      case 'res.country':
        return (await _appDb.select(_appDb.resCountry).get()).length;
      case 'res.country.state':
        return (await _appDb.select(_appDb.resCountryState).get()).length;
      case 'res.lang':
        return (await _appDb.select(_appDb.resLang).get()).length;
      case 'res.groups':
        return (await _appDb.select(_appDb.resGroups).get()).length;
      case 'ir.ui.view':
        return _qwebTemplateSync.getLocalTemplateCount();
      case 'account.credit.card.brand':
        return (await _appDb.select(_appDb.accountCreditCardBrand).get()).length;
      case 'account.credit.card.deadline':
        return (await _appDb.select(_appDb.accountCreditCardDeadline).get()).length;
      case 'account.card.lote':
        return (await _appDb.select(_appDb.accountCardLote).get()).length;
      case 'res.bank':
        return (await _appDb.select(_appDb.resBank).get()).length;
      case 'l10n_ec.cash.out.type':
        return (await _appDb.select(_appDb.cashOutType).get()).length;
      default:
        logger.w('[CatalogSync] Unknown model for count: $modelName');
        return 0;
    }
  }

  // ============================================================================
  // SYNC DELETED RECORDS
  // ============================================================================

  /// Mapping from Odoo model names to local table deletion functions
  static const Map<String, String> _modelToTableMap = {
    'product.product': 'product_product',
    'res.partner': 'res_partner',
    'product.category': 'product_category',
    'account.tax': 'account_tax',
    'uom.uom': 'uom_uom',
    'product.pricelist': 'product_pricelist',
    'account.payment.term': 'account_payment_term',
    'sale.order': 'sale_order',
    'sale.order.line': 'sale_order_line',
    'account.move': 'account_move',
    'account.move.line': 'account_move_line',
    'account.journal': 'account_journal',
  };

  /// Sync deleted records from Odoo for a specific model or all tracked models
  ///
  /// Calls sync.deleted.record.get_deleted_since to get IDs of deleted records,
  /// then removes them from the local database.
  ///
  /// Returns the total number of records deleted locally.
  Future<int> syncDeletedRecords({
    String? odooModel,
    String? localModelName,
    DateTime? sinceDate,
  }) async {
    if (!isOnline) return 0;

    final since = sinceDate ?? DateTime.now().subtract(const Duration(days: 7));
    final sinceStr = since.toUtc().toIso8601String().replaceFirst('T', ' ').substring(0, 19);

    int totalDeleted = 0;

    // If specific model requested, only sync that model
    final modelsToSync = odooModel != null
        ? [odooModel]
        : _modelToTableMap.keys.toList();

    for (final model in modelsToSync) {
      try {
        logger.d('[CatalogSync] Checking deleted records for $model since $sinceStr');

        final response = await odooClient!.call(
          model: 'sync.deleted.record',
          method: 'get_deleted_since',
          kwargs: {
            'model_name': model,
            'since_date': sinceStr,
          },
        );

        if (response == null || response is! List || response.isEmpty) {
          continue;
        }

        final deletedRecords = List<Map<String, dynamic>>.from(response);
        final deletedIds = deletedRecords
            .map((r) => r['record_id'] as int)
            .toList();

        if (deletedIds.isEmpty) continue;

        logger.i('[CatalogSync] Found ${deletedIds.length} deleted $model records');

        // Delete from local database based on model
        final count = await _deleteLocalRecords(model, deletedIds);
        totalDeleted += count;

        logger.i('[CatalogSync] Deleted $count local $model records');
      } catch (e) {
        logger.w('[CatalogSync] Error syncing deleted $model: $e');
      }
    }

    return totalDeleted;
  }

  /// Delete local records by Odoo IDs for a given model
  Future<int> _deleteLocalRecords(String odooModel, List<int> odooIds) async {
    if (odooIds.isEmpty) return 0;

    switch (odooModel) {
      case 'product.product':
        return (_appDb.delete(_appDb.productProduct)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'res.partner':
        return (_appDb.delete(_appDb.resPartner)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'product.category':
        return (_appDb.delete(_appDb.productCategory)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'account.tax':
        return (_appDb.delete(_appDb.accountTax)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'uom.uom':
        return (_appDb.delete(_appDb.uomUom)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'product.pricelist':
        return (_appDb.delete(_appDb.productPricelist)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'account.payment.term':
        return (_appDb.delete(_appDb.accountPaymentTerm)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'sale.order':
        return (_appDb.delete(_appDb.saleOrder)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'sale.order.line':
        return (_appDb.delete(_appDb.saleOrderLine)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'account.move':
        // Also delete related lines first
        for (final moveId in odooIds) {
          await (_appDb.delete(_appDb.accountMoveLine)
                ..where((t) => t.moveId.equals(moveId)))
              .go();
        }
        return (_appDb.delete(_appDb.accountMove)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'account.move.line':
        return (_appDb.delete(_appDb.accountMoveLine)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      case 'account.journal':
        return (_appDb.delete(_appDb.accountJournal)
              ..where((t) => t.odooId.isIn(odooIds)))
            .go();

      default:
        logger.w('[CatalogSync] No local table mapping for model: $odooModel');
        return 0;
    }
  }

  // ============================================================================
  // LOCAL DATA ACCESS
  // ============================================================================

  /// Get local products
  Future<List<ProductProductData>> getLocalProducts({
    int? limit,
    int? offset,
    String? searchTerm,
  }) async {
    var query = _appDb.select(_appDb.productProduct);

    if (searchTerm != null && searchTerm.isNotEmpty) {
      final term = '%$searchTerm%';
      query = query
        ..where(
          (t) =>
              t.name.like(term) |
              t.defaultCode.like(term) |
              t.barcode.like(term),
        );
    }

    if (limit != null) {
      query = query..limit(limit, offset: offset ?? 0);
    }

    return query.get();
  }

  /// Get local product by ID
  Future<ProductProductData?> getLocalProductById(int odooId) async {
    return (_appDb.select(
      _appDb.productProduct,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();
  }

  /// Get local taxes
  Future<List<AccountTaxData>> getLocalTaxes() async {
    return _appDb.select(_appDb.accountTax).get();
  }

  /// Get local tax by ID
  Future<AccountTaxData?> getLocalTaxById(int odooId) async {
    return (_appDb.select(
      _appDb.accountTax,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();
  }

  /// Get local taxes by IDs
  Future<List<AccountTaxData>> getLocalTaxesByIds(List<int> odooIds) async {
    return (_appDb.select(
      _appDb.accountTax,
    )..where((t) => t.odooId.isIn(odooIds))).get();
  }

  /// Get local UoMs
  Future<List<UomUomData>> getLocalUoms() async {
    return _appDb.select(_appDb.uomUom).get();
  }

  /// Get local UoM by ID
  Future<UomUomData?> getLocalUomById(int odooId) async {
    return (_appDb.select(
      _appDb.uomUom,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();
  }

  /// Get local partners
  Future<List<ResPartnerData>> getLocalPartners({
    int? limit,
    int? offset,
    String? searchTerm,
  }) async {
    var query = _appDb.select(_appDb.resPartner);

    if (searchTerm != null && searchTerm.isNotEmpty) {
      final term = '%$searchTerm%';
      query = query
        ..where(
          (t) => t.name.like(term) | t.vat.like(term) | t.email.like(term),
        );
    }

    if (limit != null) {
      query = query..limit(limit, offset: offset ?? 0);
    }

    return query.get();
  }

  /// Get local partner by ID
  Future<ResPartnerData?> getLocalPartnerById(int odooId) async {
    return (_appDb.select(
      _appDb.resPartner,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();
  }

  /// Get local pricelists
  Future<List<ProductPricelistData>> getLocalPricelists() async {
    return _appDb.select(_appDb.productPricelist).get();
  }

  /// Get local payment terms
  Future<List<AccountPaymentTermData>> getLocalPaymentTerms() async {
    return _appDb.select(_appDb.accountPaymentTerm).get();
  }

  // ============================================================================
  // SINGLE-RECORD SYNC METHODS (WebSocket handlers)
  // ============================================================================

  /// Sync a single product from Odoo by ID
  Future<ProductSyncData?> syncSingleProduct(int productId) async {
    if (!isOnline) return null;

    try {
      final result = await odooClient!.searchRead(
        model: 'product.product',
        domain: [
          ['id', '=', productId],
        ],
        fields: [
          'id',
          'name',
          'display_name',
          'default_code',
          'list_price',
          'uom_id',
          'taxes_id',
          'active',
        ],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final data = result.first;
      final name = (data['display_name'] ?? data['name'] ?? '') as String;

      // Update local database
      // Update local database (Manual upsert)
      final existing = await (_appDb.select(
        _appDb.productProduct,
      )..where((t) => t.odooId.equals(productId))).getSingleOrNull();

      final companion = ProductProductCompanion(
        odooId: Value(productId),
        name: Value(name),
        defaultCode: Value(data['default_code'] as String?),
        listPrice: Value((data['list_price'] as num?)?.toDouble() ?? 0.0),
        active: Value(data['active'] as bool? ?? true),
      );

      if (existing != null) {
        await (_appDb.update(
          _appDb.productProduct,
        )..where((t) => t.odooId.equals(productId))).write(companion);
      } else {
        await _appDb.into(_appDb.productProduct).insert(companion);
      }

      return ProductSyncData(name: name);
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing single product $productId', e);
      return null;
    }
  }

  /// Sync a single partner from Odoo by ID
  Future<PartnerSyncData?> syncSinglePartner(int partnerId) async {
    if (!isOnline) return null;

    try {
      final result = await odooClient!.searchRead(
        model: 'res.partner',
        domain: [
          ['id', '=', partnerId],
        ],
        fields: [
          'id',
          'name',
          'vat',
          'street',
          'phone',
          'email',
          'active',
          'avatar_128',
        ],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final data = result.first;
      final name = (data['name'] ?? '') as String;
      final vat = data['vat'] as String?;
      final street = data['street'] as String?;
      final phone = data['phone'] as String?;
      final email = data['email'] as String?;
      final avatar = data['avatar_128'] is String ? data['avatar_128'] : null;

      // Update local database (Manual upsert)
      final existing = await (_appDb.select(
        _appDb.resPartner,
      )..where((t) => t.odooId.equals(partnerId))).getSingleOrNull();

      final companion = ResPartnerCompanion(
        odooId: Value(partnerId),
        name: Value(name),
        vat: Value(vat),
        street: Value(street),
        phone: Value(phone),
        email: Value(email),
        avatar128: Value(avatar),
        active: Value(data['active'] as bool? ?? true),
      );

      if (existing != null) {
        await (_appDb.update(
          _appDb.resPartner,
        )..where((t) => t.odooId.equals(partnerId))).write(companion);
      } else {
        await _appDb.into(_appDb.resPartner).insert(companion);
      }

      return PartnerSyncData(
        name: name,
        vat: vat,
        street: street,
        phone: phone,
        email: email,
        avatar: avatar,
      );
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing single partner $partnerId', e);
      return null;
    }
  }

  /// Sync a single user from Odoo by ID
  Future<UserSyncData?> syncSingleUser(int userId) async {
    if (!isOnline) return null;

    try {
      final result = await odooClient!.searchRead(
        model: 'res.users',
        domain: [
          ['id', '=', userId],
        ],
        fields: ['id', 'name', 'login', 'email', 'active'],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final data = result.first;
      final name = (data['name'] ?? '') as String;
      final email = data['email'] as String?;

      // Update local database (Manual upsert to avoid ON CONFLICT on PK)
      final existing = await (_appDb.select(
        _appDb.resUsers,
      )..where((t) => t.odooId.equals(userId))).getSingleOrNull();

      final companion = ResUsersCompanion(
        odooId: Value(userId),
        name: Value(name),
        login: Value((data['login'] ?? '') as String),
        email: Value(email),
      );

      if (existing != null) {
        // Preserve is_current_user flag when updating
        await (_appDb.update(
          _appDb.resUsers,
        )..where((t) => t.odooId.equals(userId))).write(companion);
      } else {
        // New users default to is_current_user = false
        await _appDb
            .into(_appDb.resUsers)
            .insert(companion.copyWith(isCurrentUser: const Value(false)));
      }

      return UserSyncData(name: name, email: email);
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing single user $userId', e);
      return null;
    }
  }

  /// Sync a single company from Odoo by ID
  Future<CompanySyncData?> syncSingleCompany(int companyId) async {
    if (!isOnline) return null;

    try {
      final result = await odooClient!.searchRead(
        model: 'res.company',
        domain: [
          ['id', '=', companyId],
        ],
        fields: ['id', 'name', 'vat', 'street', 'phone', 'email'],
        limit: 1,
      );

      if (result.isEmpty) return null;

      final data = result.first;
      final name = (data['name'] ?? '') as String;

      // Update local database
      // Update local database (Manual upsert)
      final existing = await (_appDb.select(
        _appDb.resCompanyTable,
      )..where((t) => t.odooId.equals(companyId))).getSingleOrNull();

      final companion = ResCompanyTableCompanion(
        odooId: Value(companyId),
        name: Value(name),
        vat: Value(data['vat'] as String?),
        street: Value(data['street'] as String?),
        phone: Value(data['phone'] as String?),
        email: Value(data['email'] as String?),
      );

      if (existing != null) {
        await (_appDb.update(
          _appDb.resCompanyTable,
        )..where((t) => t.odooId.equals(companyId))).write(companion);
      } else {
        await _appDb.into(_appDb.resCompanyTable).insert(companion);
      }

      return CompanySyncData(name: name);
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing single company $companyId', e);
      return null;
    }
  }

  // ============================================================================
  // DENORMALIZED FIELD UPDATE METHODS
  // ============================================================================

  /// Update product name in sale order lines
  Future<int> updateSaleOrderLinesProductName(
    int productId,
    String name,
  ) async {
    try {
      return await (_appDb.update(_appDb.saleOrderLine)
            ..where((t) => t.productId.equals(productId)))
          .write(SaleOrderLineCompanion(productName: Value(name)));
    } catch (e) {
      logger.e(
        '[CatalogSync]',
        'Error updating sale order lines product name',
        e,
      );
      return 0;
    }
  }

  /// Update partner fields in sale orders
  Future<int> updateSaleOrdersPartnerFields(
    int partnerId, {
    String? name,
    String? vat,
    String? street,
    String? phone,
    String? email,
    String?
    avatar, // Note: avatar is NOT stored in sale_order table, only in UI state
  }) async {
    try {
      // Note: partnerAvatar is NOT a column in sale_order table
      // It's populated via enrichment from res_partner when loading orders
      // The avatar update is handled separately in updatePartnerFieldsOnly
      return await (_appDb.update(
        _appDb.saleOrder,
      )..where((t) => t.partnerId.equals(partnerId))).write(
        SaleOrderCompanion(
          partnerName: name != null ? Value(name) : const Value.absent(),
          partnerVat: vat != null ? Value(vat) : const Value.absent(),
          partnerStreet: street != null ? Value(street) : const Value.absent(),
          partnerPhone: phone != null ? Value(phone) : const Value.absent(),
          partnerEmail: email != null ? Value(email) : const Value.absent(),
        ),
      );
    } catch (e) {
      logger.e('[CatalogSync]', 'Error updating sale orders partner fields', e);
      return 0;
    }
  }

  /// Update user name in sale orders
  Future<int> updateSaleOrdersUserName(int userId, String name) async {
    try {
      return await (_appDb.update(_appDb.saleOrder)
            ..where((t) => t.userId.equals(userId)))
          .write(SaleOrderCompanion(userName: Value(name)));
    } catch (e) {
      logger.e('[CatalogSync]', 'Error updating sale orders user name', e);
      return 0;
    }
  }

  /// Update user name in activities
  Future<int> updateActivitiesUserName(int userId, String name) async {
    try {
      return await (_appDb.update(_appDb.mailActivityTable)
            ..where((t) => t.userId.equals(userId)))
          .write(MailActivityTableCompanion(userName: Value(name)));
    } catch (e) {
      logger.e('[CatalogSync]', 'Error updating activities user name', e);
      return 0;
    }
  }

  /// Update company name in sale orders
  Future<int> updateSaleOrdersCompanyName(int companyId, String name) async {
    try {
      return await (_appDb.update(_appDb.saleOrder)
            ..where((t) => t.companyId.equals(companyId)))
          .write(SaleOrderCompanion(companyName: Value(name)));
    } catch (e) {
      logger.e('[CatalogSync]', 'Error updating sale orders company name', e);
      return 0;
    }
  }

  // ============================================================================
  // PRICELIST / UOM METHODS
  // ============================================================================

  /// Delete a pricelist item from local database
  Future<void> deletePricelistItem(int pricelistItemId) async {
    try {
      await (_appDb.delete(
        _appDb.productPricelistItem,
      )..where((t) => t.odooId.equals(pricelistItemId))).go();
    } catch (e) {
      logger.e(
        '[CatalogSync]',
        'Error deleting pricelist item $pricelistItemId',
        e,
      );
    }
  }

  /// Sync pricelist items for a specific product
  Future<void> syncPricelistItemsForProduct(int productId) async {
    if (!isOnline) return;

    try {
      // Get product's template ID
      final product = await getLocalProductById(productId);
      final productTmplId = product?.productTmplId;

      // Fetch pricelist items for this product
      final domain = [
        '|',
        ['product_id', '=', productId],
        ['product_tmpl_id', '=', productTmplId ?? productId],
      ];

      final result = await odooClient!.searchRead(
        model: 'product.pricelist.item',
        domain: domain,
        fields: [
          'id',
          'pricelist_id',
          'product_id',
          'product_tmpl_id',
          'compute_price',
          'fixed_price',
          'percent_price',
          'min_quantity',
          'date_start',
          'date_end',
          'applied_on',
        ],
      );

      for (final item in result) {
        final pricelistIdRaw = item['pricelist_id'];
        final pricelistId =
            (pricelistIdRaw is List && pricelistIdRaw.isNotEmpty)
            ? pricelistIdRaw.first as int
            : 0;

        final computePrice = item['compute_price'] as String? ?? 'fixed';
        final fixedPrice = (item['fixed_price'] as num?)?.toDouble() ?? 0.0;
        final percentPrice = (item['percent_price'] as num?)?.toDouble() ?? 0.0;
        final minQuantity = (item['min_quantity'] as num?)?.toDouble() ?? 0.0;
        final appliedOn = item['applied_on'] as String? ?? '3_global';

        await _appDb
            .into(_appDb.productPricelistItem)
            .insertOnConflictUpdate(
              ProductPricelistItemCompanion(
                odooId: Value(item['id'] as int),
                pricelistId: Value(pricelistId),
                productId: Value(
                  item['product_id'] is List
                      ? (item['product_id'] as List).first as int
                      : null,
                ),
                productTmplId: Value(
                  item['product_tmpl_id'] is List
                      ? (item['product_tmpl_id'] as List).first as int
                      : null,
                ),
                computePrice: Value(computePrice),
                fixedPrice: Value(fixedPrice),
                percentPrice: Value(percentPrice),
                minQuantity: Value(minQuantity),
                appliedOn: Value(appliedOn),
              ),
            );
      }
    } catch (e) {
      logger.e(
        '[CatalogSync]',
        'Error syncing pricelist items for product $productId',
        e,
      );
    }
  }

  /// Delete a product UoM from local database
  Future<void> deleteProductUom(int uomId) async {
    try {
      await (_appDb.delete(
        _appDb.productUom,
      )..where((t) => t.odooId.equals(uomId))).go();
    } catch (e) {
      logger.e('[CatalogSync]', 'Error deleting product UoM $uomId', e);
    }
  }

  /// Sync product UoMs for a specific product
  /// Note: ProductUom table stores barcode mappings, not full UoM data
  Future<void> syncProductUomsForProduct(int productId) async {
    if (!isOnline) return;

    try {
      final result = await odooClient!.searchRead(
        model: 'product.uom',
        domain: [
          ['product_id', '=', productId],
        ],
        fields: ['id', 'product_id', 'uom_id', 'barcode', 'company_id'],
      );

      for (final item in result) {
        final uomIdRaw = item['uom_id'];
        final uomId = (uomIdRaw is List && uomIdRaw.isNotEmpty)
            ? uomIdRaw.first as int
            : 0;

        final companyIdRaw = item['company_id'];
        final companyId = (companyIdRaw is List && companyIdRaw.isNotEmpty)
            ? companyIdRaw.first as int
            : null;

        await _appDb
            .into(_appDb.productUom)
            .insertOnConflictUpdate(
              ProductUomCompanion(
                odooId: Value(item['id'] as int),
                productId: Value(productId),
                uomId: Value(uomId),
                barcode: Value(item['barcode'] as String? ?? ''),
                companyId: Value(companyId),
              ),
            );
      }
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing UoMs for product $productId', e);
    }
  }

  // ============================================================================
  // STOCK METHODS
  // ============================================================================

  /// Update stock from WebSocket notification
  Future<bool> updateStockFromWebSocket({
    required int productId,
    required String productName,
    String? defaultCode,
    required int warehouseId,
    required String warehouseName,
    required double quantity,
    required double reservedQuantity,
    required double availableQuantity,
  }) async {
    try {
      await _appDb
          .into(_appDb.stockByWarehouse)
          .insertOnConflictUpdate(
            StockByWarehouseCompanion(
              productId: Value(productId),
              productName: Value(productName),
              defaultCode: Value(defaultCode),
              warehouseId: Value(warehouseId),
              warehouseName: Value(warehouseName),
              quantity: Value(quantity),
              reservedQuantity: Value(reservedQuantity),
              availableQuantity: Value(availableQuantity),
              lastSyncAt: Value(DateTime.now()),
            ),
          );
      return true;
    } catch (e) {
      logger.e('[CatalogSync]', 'Error updating stock from WebSocket', e);
      return false;
    }
  }

  /// Record a stock change for audit purposes
  Future<void> recordStockChange({
    required int productId,
    required String productName,
    String? defaultCode,
    required int warehouseId,
    required String warehouseName,
    required double oldQuantity,
    required double newQuantity,
  }) async {
    try {
      await _appDb
          .into(_appDb.stockQuantityChange)
          .insert(
            StockQuantityChangeCompanion(
              productId: Value(productId),
              productName: Value(productName),
              defaultCode: Value(defaultCode),
              warehouseId: Value(warehouseId),
              warehouseName: Value(warehouseName),
              oldQuantity: Value(oldQuantity),
              newQuantity: Value(newQuantity),
              quantityChange: Value(newQuantity - oldQuantity),
              detectedAt: Value(DateTime.now()),
            ),
          );
    } catch (e) {
      logger.e('[CatalogSync]', 'Error recording stock change', e);
    }
  }

  // ============================================================================
  // CARD & CASH OUT SYNC — Stubs called from sync_provider.dart
  // Implement via BankRepository or dedicated repositories when needed.
  // ============================================================================

  /// Sync card brands (account.credit.card.brand) from Odoo to local DB.
  ///
  /// Reads all active card brands and upserts into [AccountCreditCardBrand].
  /// CardBrand is a simple DTO (not @OdooModel) so we use raw DB operations.
  Future<int> syncCardBrands({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    if (odooClient == null) return 0;
    try {
      final domain = <List<dynamic>>[
        ['active', '=', true],
      ];
      if (sinceDate != null) {
        domain.add(['write_date', '>=', sinceDate.toIso8601String()]);
      }

      final result = await odooClient!.call(
        model: 'account.credit.card.brand',
        method: 'search_read',
        kwargs: {
          'domain': domain,
          'fields': ['id', 'name', 'code', 'active'],
          'limit': batchSize,
          'order': 'name asc',
        },
      );

      if (result == null || result is! List) return 0;

      int count = 0;
      for (final b in result) {
        final odooId = b['id'] as int;
        final companion = AccountCreditCardBrandCompanion(
          odooId: Value(odooId),
          name: Value(b['name'] as String? ?? ''),
          code: Value(b['code'] as String?),
          active: Value(b['active'] as bool? ?? true),
          writeDate: Value(DateTime.now()),
        );

        final existing = await (_appDb.select(_appDb.accountCreditCardBrand)
              ..where((t) => t.odooId.equals(odooId)))
            .getSingleOrNull();

        if (existing != null) {
          await (_appDb.update(_appDb.accountCreditCardBrand)
                ..where((t) => t.id.equals(existing.id)))
              .write(companion);
        } else {
          await _appDb.into(_appDb.accountCreditCardBrand).insert(companion);
        }
        count++;
      }

      logger.d('[CatalogSync]', 'Synced $count card brands');
      onProgress?.call(SyncProgress(model: 'account.credit.card.brand', total: count, synced: count, phase: SyncPhase.completed));
      return count;
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing card brands: $e');
      return 0;
    }
  }

  /// Sync card deadlines (account.credit.card.deadline) from Odoo to local DB.
  ///
  /// Reads all active card deadlines and upserts into [AccountCreditCardDeadline].
  Future<int> syncCardDeadlines({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    if (odooClient == null) return 0;
    try {
      final domain = <List<dynamic>>[
        ['active', '=', true],
      ];
      if (sinceDate != null) {
        domain.add(['write_date', '>=', sinceDate.toIso8601String()]);
      }

      final result = await odooClient!.call(
        model: 'account.credit.card.deadline',
        method: 'search_read',
        kwargs: {
          'domain': domain,
          'fields': ['id', 'name', 'meses', 'active'],
          'limit': batchSize,
          'order': 'name asc',
        },
      );

      if (result == null || result is! List) return 0;

      int count = 0;
      for (final d in result) {
        final odooId = d['id'] as int;
        final companion = AccountCreditCardDeadlineCompanion(
          odooId: Value(odooId),
          name: Value(d['name'] as String? ?? ''),
          deadlineDays: Value(d['meses'] as int? ?? 0),
          active: Value(d['active'] as bool? ?? true),
          writeDate: Value(DateTime.now()),
        );

        final existing = await (_appDb.select(_appDb.accountCreditCardDeadline)
              ..where((t) => t.odooId.equals(odooId)))
            .getSingleOrNull();

        if (existing != null) {
          await (_appDb.update(_appDb.accountCreditCardDeadline)
                ..where((t) => t.id.equals(existing.id)))
              .write(companion);
        } else {
          await _appDb.into(_appDb.accountCreditCardDeadline).insert(companion);
        }
        count++;
      }

      logger.d('[CatalogSync]', 'Synced $count card deadlines');
      onProgress?.call(SyncProgress(model: 'account.credit.card.deadline', total: count, synced: count, phase: SyncPhase.completed));
      return count;
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing card deadlines: $e');
      return 0;
    }
  }

  /// Sync card lotes (account.card.lote) from Odoo to local DB.
  ///
  /// Uses [cardLoteManager] which has full @OdooModel support.
  /// Only syncs open lotes (active transactions) to keep local DB lean.
  Future<int> syncCardLotes({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    if (odooClient == null) return 0;
    try {
      final domain = <List<dynamic>>[
        ['state', '=', 'open'],
      ];
      if (sinceDate != null) {
        domain.add(['write_date', '>=', sinceDate.toIso8601String()]);
      }

      final result = await odooClient!.call(
        model: 'account.card.lote',
        method: 'search_read',
        kwargs: {
          'domain': domain,
          'fields': cardLoteManager.odooFields,
          'limit': batchSize,
          'order': 'id desc',
        },
      );

      if (result == null || result is! List) return 0;

      int count = 0;
      for (final data in result) {
        final record = cardLoteManager.fromOdoo(data as Map<String, dynamic>);
        await cardLoteManager.upsertLocal(record);
        count++;
      }

      logger.d('[CatalogSync]', 'Synced $count card lotes');
      onProgress?.call(SyncProgress(model: 'account.card.lote', total: count, synced: count, phase: SyncPhase.completed));
      return count;
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing card lotes: $e');
      return 0;
    }
  }

  /// Sync cash out types — no-op, types are hardcoded.
  ///
  /// CashOutType in theos_pos_core is a static class with predefined constants
  /// (expense, withhold, refund, commission, invoice, general, security, other).
  /// These are not Odoo records — they're client-side classifications.
  /// No sync needed.
  Future<int> syncCashOutTypes({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    // CashOutType is hardcoded in cash_out.model.dart — nothing to sync.
    logger.d('[CatalogSync]', 'Cash out types are hardcoded, no sync needed');
    return 0;
  }

  /// Sync user groups for a specific user
  ///
  /// Fetches the user's group memberships from Odoo and updates the local
  /// user record, then ensures all referenced groups exist in the local
  /// res_groups table.
  Future<int> syncUserGroups([
    int? userId,
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  ]) async {
    // First ensure groups table is populated
    await syncGroups(batchSize: batchSize, sinceDate: sinceDate);

    // Then fetch the specific user's group memberships from Odoo.
    // groups_id on res.users is restricted via external API (both read and
    // search_read return HTTP 500). Use has_group() as the reliable approach.
    if (userId != null && odooClient != null) {
      await _syncUserGroupsViaHasGroup(userId);
    }
    return 0;
  }

  /// Check each known group XML ID via has_group() method.
  /// This works even when groups_id field is restricted via external API.
  /// In JSON-2 API, kwargs are spread into the body, so group_ext_id
  /// becomes a top-level parameter as Odoo expects.
  Future<void> _syncUserGroupsViaHasGroup(int userId) async {
    const knownGroups = [
      'base.group_system',
      'base.group_user',
      'account.group_account_manager',
      'sales_team.group_sale_salesman',
      'sales_team.group_sale_manager',
      'l10n_ec_collection_box.group_collection_user',
      'l10n_ec_collection_box.group_collection_manager',
    ];

    try {
      final matchedXmlIds = <String>[];
      final matchedGroupIds = <int>[];
      final appDb = _appDb;

      for (final xmlId in knownGroups) {
        try {
          final result = await odooClient!.call(
            model: 'res.users',
            method: 'has_group',
            ids: [userId],
            kwargs: {'group_ext_id': xmlId},
          );
          if (result == true) {
            matchedXmlIds.add(xmlId);
            // Find local group ID by xml_id
            final localGroup = await (appDb.select(appDb.resGroups)
                  ..where((t) => t.xmlId.equals(xmlId))
                  ..limit(1))
                .getSingleOrNull();
            if (localGroup != null) {
              matchedGroupIds.add(localGroup.odooId);
            }
          }
        } catch (e) {
          logger.w('[CatalogSync] has_group check failed for $xmlId: $e');
        }
      }

      if (matchedGroupIds.isNotEmpty) {
        final groupIdsStr = matchedGroupIds.join(',');
        await (appDb.update(appDb.resUsers)
              ..where((t) => t.odooId.equals(userId)))
            .write(ResUsersCompanion(groupIds: Value(groupIdsStr)));
        logger.d('[CatalogSync] Updated user $userId with ${matchedGroupIds.length} groups: $matchedXmlIds');
      } else {
        logger.w('[CatalogSync] No groups matched for user $userId');
      }
    } catch (e) {
      logger.e('[CatalogSync] has_group sync failed: $e');
    }
  }
}
