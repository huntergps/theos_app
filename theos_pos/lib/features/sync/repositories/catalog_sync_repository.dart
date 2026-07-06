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

// Fase E2: sub-repos extraídos de este mismo archivo (composición, mismo
// patrón que los de arriba). El facade delega — API pública intacta.
import 'sync_metadata_repository.dart';
import 'sync_counts_repository.dart';
import 'denormalized_field_sync_repository.dart';
import 'pricelist_item_sync_repository.dart';
import 'stock_sync_repository.dart';
import 'card_cash_sync_repository.dart';

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

  // Fase E2: sub-repos extraídos de este archivo (ver imports arriba).
  late final SyncMetadataRepository _metadataRepo;
  late final SyncCountsRepository _countsRepo;
  late final DenormalizedFieldSyncRepository _denormalizedRepo;
  late final PricelistItemSyncRepository _pricelistItemRepo;
  late final StockSyncRepository _stockRepo;
  late final CardCashSyncRepository _cardCashRepo;

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

    // Fase E2: sub-repos extraídos de este archivo.
    _metadataRepo = SyncMetadataRepository(
      appDb: _appDb,
      qwebTemplateSync: _qwebTemplateSync,
    );
    _countsRepo = SyncCountsRepository(
      appDb: _appDb,
      odooClient: odooClient,
      qwebTemplateSync: _qwebTemplateSync,
    );
    _denormalizedRepo = DenormalizedFieldSyncRepository(appDb: _appDb);
    _pricelistItemRepo = PricelistItemSyncRepository(
      appDb: _appDb,
      odooClient: odooClient,
      // getLocalProductById se queda en este facade (sección "Local Data
      // Access", fuera del alcance de este split) — se pasa como callback.
      getLocalProductById: getLocalProductById,
    );
    _stockRepo = StockSyncRepository(appDb: _appDb);
    _cardCashRepo = CardCashSyncRepository(
      appDb: _appDb,
      odooClient: odooClient,
      // syncGroups también se queda en este facade (wrapper de una línea a
      // UserSyncRepository) — se pasa como callback.
      syncGroups: syncGroups,
    );
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
    return _userSync.syncCurrencies(
      limit: batchSize,
      onProgress: onProgress,
      sinceDate: sinceDate,
    );
  }

  /// Sync decimal precision
  Future<int> syncDecimalPrecision({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) async {
    return _userSync.syncDecimalPrecision();
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

    // Capturado ANTES de iniciar el batch completo (~20 catálogos), no
    // después de que termine. Si se guardara el timestamp de después,
    // cualquier registro modificado en Odoo MIENTRAS este batch corre
    // (que puede tardar varios segundos) quedaría con un write_date
    // anterior al "last_sync" guardado y nunca más se volvería a traer.
    final syncStartTime = DateTime.now().toUtc();

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

      await _metadataRepo.saveLastSyncTime(syncStartTime);

      logger.i('[CatalogSync] All catalogs synced: $results');
    } catch (e) {
      logger.e('[CatalogSync]', 'Error syncing all catalogs', e);
      rethrow;
    }

    return results;
  }

  // ============================================================================
  // SYNC METADATA (delega a SyncMetadataRepository — Fase E2)
  // ============================================================================

  /// Get last sync time
  Future<DateTime?> getLastSyncTime() => _metadataRepo.getLastSyncTime();

  /// Get sync info for a specific model
  Future<SyncModelInfo> getModelSyncInfo(String modelName) =>
      _metadataRepo.getModelSyncInfo(modelName);

  /// Save sync info for a specific model
  Future<void> saveModelSyncInfo(SyncModelInfo info) =>
      _metadataRepo.saveModelSyncInfo(info);

  /// Clear error message for a specific model, allowing it to sync again
  Future<void> clearModelSyncError(String modelName) =>
      _metadataRepo.clearModelSyncError(modelName);

  /// Get sync info for all models
  Future<Map<String, SyncModelInfo>> getAllModelSyncInfo() =>
      _metadataRepo.getAllModelSyncInfo();

  /// Clear sync info for a specific model
  Future<void> clearModelSyncInfo(String modelName) =>
      _metadataRepo.clearModelSyncInfo(modelName);

  /// Clear all model sync info
  Future<void> clearAllModelSyncInfo() => _metadataRepo.clearAllModelSyncInfo();

  // ============================================================================
  // CLEAR TABLES (delega a SyncMetadataRepository — Fase E2)
  // ============================================================================

  /// Clear all catalog tables
  Future<Map<String, int>> clearAllCatalogTables() =>
      _metadataRepo.clearAllCatalogTables();

  /// Clear a specific catalog table
  Future<int> clearCatalogTable(String modelName) =>
      _metadataRepo.clearCatalogTable(modelName);

  // ============================================================================
  // LOCAL COUNTS (delega a SyncCountsRepository — Fase E2)
  // ============================================================================

  Future<int> getLocalProductCount() => _countsRepo.getLocalProductCount();

  Future<int> getLocalCategoryCount() => _countsRepo.getLocalCategoryCount();

  Future<int> getLocalTaxCount() => _countsRepo.getLocalTaxCount();

  Future<int> getLocalUomCount() => _countsRepo.getLocalUomCount();

  Future<int> getLocalProductUomCount() => _countsRepo.getLocalProductUomCount();

  Future<int> getLocalPricelistCount() => _countsRepo.getLocalPricelistCount();

  Future<int> getLocalPaymentTermCount() => _countsRepo.getLocalPaymentTermCount();

  Future<int> getLocalPartnerCount() => _countsRepo.getLocalPartnerCount();

  Future<int> getLocalSaleOrderCount() => _countsRepo.getLocalSaleOrderCount();

  Future<int> getLocalCountForModel(String modelName) =>
      _countsRepo.getLocalCountForModel(modelName);

  // ============================================================================
  // SYNC DELETED RECORDS (delega a SyncCountsRepository — Fase E2)
  // ============================================================================

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
  }) => _countsRepo.syncDeletedRecords(
    odooModel: odooModel,
    localModelName: localModelName,
    sinceDate: sinceDate,
  );

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
  // DENORMALIZED FIELD UPDATE METHODS (delega a DenormalizedFieldSyncRepository — Fase E2)
  // ============================================================================

  /// Update product name in sale order lines
  Future<int> updateSaleOrderLinesProductName(
    int productId,
    String name,
  ) => _denormalizedRepo.updateSaleOrderLinesProductName(productId, name);

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
  }) => _denormalizedRepo.updateSaleOrdersPartnerFields(
    partnerId,
    name: name,
    vat: vat,
    street: street,
    phone: phone,
    email: email,
    avatar: avatar,
  );

  /// Update user name in sale orders
  Future<int> updateSaleOrdersUserName(int userId, String name) =>
      _denormalizedRepo.updateSaleOrdersUserName(userId, name);

  /// Update user name in activities
  Future<int> updateActivitiesUserName(int userId, String name) =>
      _denormalizedRepo.updateActivitiesUserName(userId, name);

  /// Update company name in sale orders
  Future<int> updateSaleOrdersCompanyName(int companyId, String name) =>
      _denormalizedRepo.updateSaleOrdersCompanyName(companyId, name);

  // ============================================================================
  // PRICELIST METHODS (delega a PricelistItemSyncRepository — Fase E2)
  // ============================================================================

  /// Delete a pricelist item from local database
  Future<void> deletePricelistItem(int pricelistItemId) =>
      _pricelistItemRepo.deletePricelistItem(pricelistItemId);

  /// Sync pricelist items for a specific product
  Future<void> syncPricelistItemsForProduct(int productId) =>
      _pricelistItemRepo.syncPricelistItemsForProduct(productId);

  // ============================================================================
  // UOM METHODS (siguen acá — requerirían extender ProductSyncRepository,
  // fuera del alcance de este split — ver plan de descomposición Fase E2)
  // ============================================================================

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
  // STOCK METHODS (delega a StockSyncRepository — Fase E2)
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
  }) => _stockRepo.updateStockFromWebSocket(
    productId: productId,
    productName: productName,
    defaultCode: defaultCode,
    warehouseId: warehouseId,
    warehouseName: warehouseName,
    quantity: quantity,
    reservedQuantity: reservedQuantity,
    availableQuantity: availableQuantity,
  );

  /// Record a stock change for audit purposes
  Future<void> recordStockChange({
    required int productId,
    required String productName,
    String? defaultCode,
    required int warehouseId,
    required String warehouseName,
    required double oldQuantity,
    required double newQuantity,
  }) => _stockRepo.recordStockChange(
    productId: productId,
    productName: productName,
    defaultCode: defaultCode,
    warehouseId: warehouseId,
    warehouseName: warehouseName,
    oldQuantity: oldQuantity,
    newQuantity: newQuantity,
  );

  // ============================================================================
  // CARD & CASH OUT SYNC (delega a CardCashSyncRepository — Fase E2)
  // ============================================================================

  /// Sync card brands (account.credit.card.brand) from Odoo to local DB.
  Future<int> syncCardBrands({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _cardCashRepo.syncCardBrands(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync card deadlines (account.credit.card.deadline) from Odoo to local DB.
  Future<int> syncCardDeadlines({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _cardCashRepo.syncCardDeadlines(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync card lotes (account.card.lote) from Odoo to local DB.
  Future<int> syncCardLotes({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _cardCashRepo.syncCardLotes(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync cash out types — no-op, types are hardcoded.
  Future<int> syncCashOutTypes({
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  }) => _cardCashRepo.syncCashOutTypes(
    batchSize: batchSize,
    onProgress: onProgress,
    sinceDate: sinceDate,
  );

  /// Sync user groups for a specific user
  Future<int> syncUserGroups([
    int? userId,
    int batchSize = 100,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  ]) => _cardCashRepo.syncUserGroups(
    userId,
    batchSize,
    onProgress,
    sinceDate,
  );
}
