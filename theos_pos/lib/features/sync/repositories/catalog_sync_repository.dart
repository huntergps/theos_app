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
import '../../../core/services/handlers/model_record_handler.dart' as handlers;

// Fase E2: sub-repos extraídos de este mismo archivo (composición, mismo
// patrón que los de arriba). El facade delega — API pública intacta.
import 'sync_metadata_repository.dart';
import 'sync_counts_repository.dart';
import 'card_cash_sync_repository.dart';

/// Facade repository for syncing master catalogs from Odoo to local SQLite
///
/// This class delegates to specialized repositories:
/// - [ProductSyncRepository]: Products, categories, taxes, UoM, pricelists, payment terms
/// - [PartnerSyncRepository]: Partners/customers
/// - [SaleOrderSyncRepository]: Sale orders and lines
/// - [UserSyncRepository]: Users, warehouses, teams, companies, etc.
class CatalogSyncRepository {
  final OdooClient? odooClient;
  final DatabaseHelper db;
  final AppDatabase appDb;
  final handlers.ModelRecordHandlerRegistry recordHandlerRegistry;

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
  late final CardCashSyncRepository _cardCashRepo;

  /// Flag to request sync cancellation
  bool _cancelRequested = false;

  CatalogSyncRepository({
    required this.db,
    required this.appDb,
    required this.recordHandlerRegistry,
    this.odooClient,
  }) {
    // Initialize delegate repositories
    _productSync = ProductSyncRepository(db: appDb, odooClient: odooClient);
    _partnerSync = PartnerSyncRepository(db: appDb, odooClient: odooClient);
    _saleOrderSync = SaleOrderSyncRepository(
      db: appDb,
      odooClient: odooClient,
      recordHandlerRegistry: recordHandlerRegistry,
    );
    _userSync = UserSyncRepository(
      db: db,
      odooClient: odooClient,
      appDatabase: appDb,
    );
    _qwebTemplateSync = QwebTemplateSyncRepository(
      db: db,
      odooClient: odooClient,
    );
    // Centralized bank repository (odooClient is optional - works offline)
    _bankRepo = BankRepository(db: appDb, odooClient: odooClient);

    // Fase E2: sub-repos extraídos de este archivo.
    _metadataRepo = SyncMetadataRepository(
      appDb: appDb,
      qwebTemplateSync: _qwebTemplateSync,
    );
    _countsRepo = SyncCountsRepository(
      appDb: appDb,
      odooClient: odooClient,
      qwebTemplateSync: _qwebTemplateSync,
    );
    _cardCashRepo = CardCashSyncRepository(
      appDb: appDb,
      odooClient: odooClient,
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
    int batchSize = 200,
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
    bool allUsers = false,
  }) => _saleOrderSync.fetchSaleOrdersWithLines(
    limit: limit ?? 50,
    state: state,
    partnerId: partnerId,
    forceRefresh: forceRefresh,
    allUsers: allUsers,
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

  // ============================================================================
  // SYNC METADATA (delega a SyncMetadataRepository — Fase E2)
  // ============================================================================

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

  Future<int> getLocalProductUomCount() =>
      _countsRepo.getLocalProductUomCount();

  Future<int> getLocalPricelistCount() => _countsRepo.getLocalPricelistCount();

  Future<int> getLocalPaymentTermCount() =>
      _countsRepo.getLocalPaymentTermCount();

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
    var query = appDb.select(appDb.productProduct);

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
    return (appDb.select(
      appDb.productProduct,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();
  }

  /// Get local taxes
  Future<List<AccountTaxData>> getLocalTaxes() async {
    return appDb.select(appDb.accountTax).get();
  }

  /// Get local tax by ID
  Future<AccountTaxData?> getLocalTaxById(int odooId) async {
    return (appDb.select(
      appDb.accountTax,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();
  }

  /// Get local taxes by IDs
  Future<List<AccountTaxData>> getLocalTaxesByIds(List<int> odooIds) async {
    return (appDb.select(
      appDb.accountTax,
    )..where((t) => t.odooId.isIn(odooIds))).get();
  }

  /// Get local UoMs
  Future<List<UomUomData>> getLocalUoms() async {
    return appDb.select(appDb.uomUom).get();
  }

  /// Get local UoM by ID
  Future<UomUomData?> getLocalUomById(int odooId) async {
    return (appDb.select(
      appDb.uomUom,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();
  }

  /// Get local partners
  Future<List<ResPartnerData>> getLocalPartners({
    int? limit,
    int? offset,
    String? searchTerm,
  }) async {
    var query = appDb.select(appDb.resPartner);

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
    return (appDb.select(
      appDb.resPartner,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();
  }

  /// Get local pricelists
  Future<List<ProductPricelistData>> getLocalPricelists() async {
    return appDb.select(appDb.productPricelist).get();
  }

  /// Get local payment terms
  Future<List<AccountPaymentTermData>> getLocalPaymentTerms() async {
    return appDb.select(appDb.accountPaymentTerm).get();
  }

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
  ]) => _cardCashRepo.syncUserGroups(userId, batchSize, onProgress, sinceDate);
}
