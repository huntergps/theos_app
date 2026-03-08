import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/catalog_sync_repository.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/managers/manager_providers.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show logger;
import '../../reports/repositories/qweb_template_repository.dart';
import '../../../shared/providers/report_provider.dart';

part 'sync_provider.g.dart';

/// Sync status for each catalog
enum SyncStatus { idle, syncing, success, error }

/// State for individual sync item
class SyncItemState {
  final SyncStatus status;
  final int? count;
  final String? error;
  final SyncProgress? progress;
  final DateTime? lastSyncDate;
  final int localCount;
  final bool wasIncremental;

  const SyncItemState({
    this.status = SyncStatus.idle,
    this.count,
    this.error,
    this.progress,
    this.lastSyncDate,
    this.localCount = 0,
    this.wasIncremental = false,
  });

  SyncItemState copyWith({
    SyncStatus? status,
    int? count,
    String? error,
    SyncProgress? progress,
    DateTime? lastSyncDate,
    int? localCount,
    bool? wasIncremental,
  }) {
    return SyncItemState(
      status: status ?? this.status,
      count: count ?? this.count,
      error: error,
      progress: progress ?? this.progress,
      lastSyncDate: lastSyncDate ?? this.lastSyncDate,
      localCount: localCount ?? this.localCount,
      wasIncremental: wasIncremental ?? this.wasIncremental,
    );
  }

  /// Create from SyncModelInfo
  factory SyncItemState.fromModelInfo(SyncModelInfo info) {
    return SyncItemState(
      status: info.errorMessage != null ? SyncStatus.error : SyncStatus.idle,
      count: info.syncedCount,
      error: info.errorMessage,
      lastSyncDate: info.lastSyncDate,
      localCount: info.localCount,
      wasIncremental: info.wasIncremental,
    );
  }
}

/// Overall sync screen state
class SyncScreenState {
  final Map<String, SyncItemState> itemStates;
  final bool isSyncingAll;
  final String? currentSyncingItem;
  final bool isLoading;

  const SyncScreenState({
    this.itemStates = const {},
    this.isSyncingAll = false,
    this.currentSyncingItem,
    this.isLoading = false,
  });

  SyncScreenState copyWith({
    Map<String, SyncItemState>? itemStates,
    bool? isSyncingAll,
    String? currentSyncingItem,
    bool? isLoading,
  }) {
    return SyncScreenState(
      itemStates: itemStates ?? this.itemStates,
      isSyncingAll: isSyncingAll ?? this.isSyncingAll,
      currentSyncingItem: currentSyncingItem,
      isLoading: isLoading ?? this.isLoading,
    );
  }

  /// Check if any sync is in progress
  bool get isAnySyncing =>
      isSyncingAll ||
      itemStates.values.any((s) => s.status == SyncStatus.syncing);

  /// Get state for a specific item
  SyncItemState getItemState(String name) =>
      itemStates[name] ?? const SyncItemState();
}

/// Sync item definition
class SyncItemDef {
  final String name;
  final String description;
  final String odooModel;
  final Future<int> Function(
    CatalogSyncRepository repo,
    SyncProgressCallback? onProgress,
    DateTime? sinceDate,
  )
  syncFn;

  /// Optional callback after successful sync
  final Future<void> Function(Ref ref)? postSyncFn;

  const SyncItemDef({
    required this.name,
    required this.description,
    required this.odooModel,
    required this.syncFn,
    this.postSyncFn,
  });
}

/// Provider for sync state - persists across navigation
@Riverpod(keepAlive: true)
class SyncNotifier extends _$SyncNotifier {
  /// Static flag to track if sync is running (persists across notifier rebuilds)
  /// This is needed because Riverpod may rebuild the notifier when navigating,
  /// which would reset the state and cancel the ongoing sync.
  static bool _isSyncRunning = false;

  /// List of all sync items
  /// IMPORTANT: Products is synced LAST because it has 13,000+ records
  /// and would block all other sync items during initial splash screen sync
  static final List<SyncItemDef> syncItems = [
    // === SMALL REFERENCE DATA - sync first ===
    SyncItemDef(
      name: 'categories',
      description: 'Categorias de Productos',
      odooModel: 'product.category',
      syncFn: (repo, onProgress, sinceDate) => repo.syncProductCategories(
        onProgress: onProgress,
        sinceDate: sinceDate,
      ),
    ),
    SyncItemDef(
      name: 'taxes',
      description: 'Impuestos',
      odooModel: 'account.tax',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncTaxes(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'currencies',
      description: 'Monedas',
      odooModel: 'res.currency',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncCurrencies(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'decimal_precision',
      description: 'Prefición Decimal', // Typo intended? 'Precisión'
      odooModel: 'decimal.precision',
      syncFn: (repo, onProgress, sinceDate) => repo.syncDecimalPrecision(
        onProgress: onProgress,
        sinceDate: sinceDate,
      ),
    ),
    // === PAYMENT INFRASTRUCTURE - sync early ===
    SyncItemDef(
      name: 'journals',
      description: 'Diarios Contables',
      odooModel: 'account.journal',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncJournals(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'card_brands',
      description: 'Marcas de Tarjeta',
      odooModel: 'account.credit.card.brand',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncCardBrands(sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'card_deadlines',
      description: 'Plazos de Tarjeta',
      odooModel: 'account.credit.card.deadline',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncCardDeadlines(sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'card_lotes',
      description: 'Lotes de Tarjeta',
      odooModel: 'account.card.lote',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncCardLotes(sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'payment_method_lines',
      description: 'Metodos de Pago',
      odooModel: 'account.payment.method.line',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncPaymentMethodLines(sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'banks',
      description: 'Bancos',
      odooModel: 'res.bank',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncBanks(onProgress: onProgress, sinceDate: sinceDate),
    ),
    // === END Payment infrastructure ===
    SyncItemDef(
      name: 'uom',
      description: 'Unidades de Medida',
      odooModel: 'uom.uom',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncUom(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'product_uom',
      description: 'Codigos de Barra por Empaque',
      odooModel: 'product.uom',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncProductUom(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'pricelists',
      description: 'Listas de Precios',
      odooModel: 'product.pricelist',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncPricelists(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'payment_terms',
      description: 'Terminos de Pago',
      odooModel: 'account.payment.term',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncPaymentTerms(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'partners',
      description: 'Clientes (todos)',
      odooModel: 'res.partner',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncPartners(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'sale_orders',
      description: 'Ordenes de Venta (90 dias)',
      odooModel: 'sale.order',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncSaleOrders(onProgress: onProgress, sinceDate: sinceDate),
    ),
    // System catalogs
    SyncItemDef(
      name: 'users',
      description: 'Usuarios',
      odooModel: 'res.users',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncUsers(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'groups',
      description: 'Grupos de Seguridad',
      odooModel: 'res.groups',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncGroups(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'warehouses',
      description: 'Almacenes',
      odooModel: 'stock.warehouse',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncWarehouses(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'teams',
      description: 'Equipos de Ventas',
      odooModel: 'crm.team',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncTeams(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'fiscal_positions',
      description: 'Posiciones Fiscales',
      odooModel: 'account.fiscal.position',
      syncFn: (repo, onProgress, sinceDate) => repo.syncFiscalPositions(
        onProgress: onProgress,
        sinceDate: sinceDate,
      ),
    ),
    // Advances and credit notes (sync later, need partner data)
    SyncItemDef(
      name: 'advances',
      description: 'Anticipos de Clientes',
      odooModel: 'account.advance',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncAdvances(sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'credit_notes',
      description: 'Notas de Credito',
      odooModel: 'account.move',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncCreditNotes(sinceDate: sinceDate),
    ),
    // Collection catalogs
    SyncItemDef(
      name: 'collection_configs',
      description: 'Config. Cajas de Cobro',
      odooModel: 'collection.config',
      syncFn: (repo, onProgress, sinceDate) => repo.syncCollectionConfigs(
        onProgress: onProgress,
        sinceDate: sinceDate,
      ),
    ),
    SyncItemDef(
      name: 'cash_out_types',
      description: 'Tipos de Salida Efectivo',
      odooModel: 'l10n_ec.cash.out.type',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncCashOutTypes(onProgress: onProgress, sinceDate: sinceDate),
    ),
    // Company configuration (includes sale.order defaults)
    SyncItemDef(
      name: 'company',
      description: 'Configuracion de Compania',
      odooModel: 'res.company',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncCompany(onProgress: onProgress, sinceDate: sinceDate),
    ),
    // System reference data
    SyncItemDef(
      name: 'countries',
      description: 'Paises',
      odooModel: 'res.country',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncCountries(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'country_states',
      description: 'Provincias/Estados',
      odooModel: 'res.country.state',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncCountryStates(onProgress: onProgress, sinceDate: sinceDate),
    ),
    SyncItemDef(
      name: 'languages',
      description: 'Idiomas',
      odooModel: 'res.lang',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncLanguages(onProgress: onProgress, sinceDate: sinceDate),
    ),
    // QWeb Report Templates for offline PDF generation
    SyncItemDef(
      name: 'qweb_templates',
      description: 'Plantillas PDF (QWeb)',
      odooModel: 'ir.ui.view',
      syncFn: (repo, onProgress, sinceDate) async {
        final results = await repo.syncAllQwebTemplates(
          models: ['sale.order', 'account.move'],
          onProgress: onProgress,
          sinceDate: sinceDate,
        );
        // Sum all template counts (only those actually updated)
        return results.values.fold<int>(0, (sum, count) => sum + count);
      },
      postSyncFn: (ref) async {
        // Load templates into ReportService after sync
        final dbHelper = ref.read(databaseHelperProvider);
        if (dbHelper != null) {
          final appDb = ref.read(appDatabaseProvider);
          final templateRepo = QwebTemplateRepository(appDb);
          final reportService = ref.read(reportServiceProvider);
          await reportService.loadTemplatesFromDatabase(templateRepo);
          logger.i(
            '[SyncNotifier]',
            'Loaded QWeb templates into ReportService',
          );
        }
      },
    ),
    // === LARGE DATA - sync LAST ===
    // Products has 13,000+ records and takes significant time
    // By syncing it last, all critical catalogs are available first
    SyncItemDef(
      name: 'products',
      description: 'Productos (todos)',
      odooModel: 'product.product',
      syncFn: (repo, onProgress, sinceDate) =>
          repo.syncProducts(onProgress: onProgress, sinceDate: sinceDate),
    ),
  ];

  @override
  SyncScreenState build() {
    // Initialize with loading state, then load persisted data
    // Preserve isSyncingAll from static flag (in case notifier was rebuilt during sync)
    _loadPersistedState();
    return SyncScreenState(isLoading: true, isSyncingAll: _isSyncRunning);
  }

  /// Get the catalog sync repository
  CatalogSyncRepository? get _catalogSync =>
      ref.read(catalogSyncRepositoryProvider);

  /// Check if online
  bool get isOnline => _catalogSync?.isOnline ?? false;

  /// Load persisted sync state from database
  Future<void> _loadPersistedState() async {
    try {
      final catalogSync = _catalogSync;
      if (catalogSync == null) {
        state = const SyncScreenState();
        return;
      }

      final allSyncInfo = await catalogSync.getAllModelSyncInfo();
      final initialStates = <String, SyncItemState>{};

      for (final item in syncItems) {
        final info = allSyncInfo[item.name];
        if (info != null) {
          // Also get current local count
          final localCount = await catalogSync.getLocalCountForModel(
            item.odooModel,
          );
          initialStates[item.name] = SyncItemState.fromModelInfo(
            info.copyWith(localCount: localCount),
          );
        } else {
          final localCount = await catalogSync.getLocalCountForModel(
            item.odooModel,
          );
          initialStates[item.name] = SyncItemState(localCount: localCount);
        }
      }

      state = SyncScreenState(itemStates: initialStates);
      logger.d('[SyncNotifier] Loaded persisted sync state');
    } catch (e) {
      logger.e('[SyncNotifier] Error loading persisted state: $e');
      state = const SyncScreenState();
    }
  }

  /// Reload local counts (call when navigating to sync screen)
  Future<void> refreshLocalCounts() async {
    try {
      final catalogSync = _catalogSync;
      if (catalogSync == null) return;

      final newStates = <String, SyncItemState>{};
      for (final item in syncItems) {
        final currentState = state.getItemState(item.name);
        final localCount = await catalogSync.getLocalCountForModel(
          item.odooModel,
        );
        newStates[item.name] = currentState.copyWith(localCount: localCount);
      }
      state = state.copyWith(itemStates: newStates);
    } catch (e) {
      logger.e('[SyncNotifier] Error refreshing local counts: $e');
    }
  }

  /// Update state for a specific item
  void _updateItemState(String name, SyncItemState itemState) {
    final newStates = Map<String, SyncItemState>.from(state.itemStates);
    newStates[name] = itemState;
    state = state.copyWith(itemStates: newStates);
  }

  /// Save sync result to persistent storage
  Future<void> _saveSyncResult(
    String itemName, {
    required int count,
    required String odooModel,
    String? error,
    bool wasIncremental = false,
  }) async {
    try {
      final catalogSync = _catalogSync;
      if (catalogSync == null) return;

      final localCount = await catalogSync.getLocalCountForModel(odooModel);

      final info = SyncModelInfo(
        modelName: itemName,
        lastSyncDate: DateTime.now(),
        syncedCount: count,
        localCount: localCount,
        errorMessage: error,
        wasIncremental: wasIncremental,
      );

      await catalogSync.saveModelSyncInfo(info);
    } catch (e) {
      logger.e('[SyncNotifier] Error saving sync result for $itemName: $e');
    }
  }

  /// Sync a single catalog item
  Future<void> syncItem(String itemName, {bool forceFullSync = false}) async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) {
      logger.e('[SyncNotifier] CatalogSyncRepository not available');
      return;
    }

    if (!catalogSync.isOnline) {
      logger.e('[SyncNotifier] Not online');
      return;
    }

    // Reset cancellation flag before starting
    catalogSync.resetCancelFlag();

    // Find the item definition
    final itemDef = syncItems.firstWhere(
      (item) => item.name == itemName,
      orElse: () => throw ArgumentError('Unknown sync item: $itemName'),
    );

    // Check if already syncing this item
    if (state.getItemState(itemName).status == SyncStatus.syncing) {
      logger.d('[SyncNotifier] Already syncing $itemName');
      return;
    }

    // Clear sync info if force full sync
    if (forceFullSync) {
      await catalogSync.clearModelSyncInfo(itemName);
    }

    // Get current sync info for incremental sync
    final currentInfo = await catalogSync.getModelSyncInfo(itemName);
    final isIncremental = !forceFullSync && currentInfo.lastSyncDate != null;

    // Mark as syncing
    _updateItemState(
      itemName,
      state
          .getItemState(itemName)
          .copyWith(status: SyncStatus.syncing, wasIncremental: isIncremental),
    );
    state = state.copyWith(currentSyncingItem: itemName);

    try {
      logger.d(
        '[SyncNotifier] Syncing ${itemDef.description}... (incremental: $isIncremental)',
      );

      // First, sync deleted records if this is incremental
      if (isIncremental && currentInfo.lastSyncDate != null) {
        try {
          await catalogSync.syncDeletedRecords(
            odooModel: itemDef.odooModel,
            localModelName: itemName,
            sinceDate: currentInfo.lastSyncDate,
          );
        } catch (e) {
          logger.w('[SyncNotifier] Error syncing deleted records: $e');
          // Continue with sync even if deleted records fail
        }
      }

      // Progress callback
      void onProgress(SyncProgress progress) {
        _updateItemState(
          itemName,
          SyncItemState(
            status: SyncStatus.syncing,
            progress: progress,
            lastSyncDate: currentInfo.lastSyncDate,
            wasIncremental: isIncremental,
          ),
        );
      }

      // Pass sinceDate for incremental sync (null if force full sync)
      final sinceDate = isIncremental ? currentInfo.lastSyncDate : null;
      final count = await itemDef.syncFn(catalogSync, onProgress, sinceDate);
      logger.d('[SyncNotifier] ${itemDef.description}: $count records');

      // Run post-sync callback if defined
      if (itemDef.postSyncFn != null) {
        await itemDef.postSyncFn!(ref);
      }

      // Save sync result
      await _saveSyncResult(
        itemName,
        count: count,
        odooModel: itemDef.odooModel,
        wasIncremental: isIncremental,
      );

      // Get updated local count
      final localCount = await catalogSync.getLocalCountForModel(
        itemDef.odooModel,
      );

      _updateItemState(
        itemName,
        SyncItemState(
          status: SyncStatus.success,
          count: count,
          lastSyncDate: DateTime.now(),
          localCount: localCount,
          wasIncremental: isIncremental,
        ),
      );
    } catch (e) {
      logger.e('[SyncNotifier] Error syncing ${itemDef.description}: $e');
      final errorMessage = e.toString();

      // Save error
      await _saveSyncResult(
        itemName,
        count: 0,
        odooModel: itemDef.odooModel,
        error: errorMessage,
      );

      _updateItemState(
        itemName,
        SyncItemState(
          status: SyncStatus.error,
          error: errorMessage,
          lastSyncDate: currentInfo.lastSyncDate,
          localCount: state.getItemState(itemName).localCount,
        ),
      );
    } finally {
      if (state.currentSyncingItem == itemName) {
        state = state.copyWith(currentSyncingItem: null);
      }
    }
  }

  /// Force full sync for a single item (clear last sync date)
  Future<void> forceFullSyncItem(String itemName) async {
    await syncItem(itemName, forceFullSync: true);
  }

  /// Force full sync for all items
  Future<void> forceFullSyncAll() async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) {
      logger.e('[SyncNotifier] CatalogSyncRepository not available');
      return;
    }

    // Clear all sync info first
    await catalogSync.clearAllModelSyncInfo();

    // Then sync all
    await syncAll();
  }

  /// Critical items that should be synced during recovery
  /// These are small, essential catalogs needed for basic operations
  static const List<String> _criticalItems = [
    'categories',
    'taxes',
    'currencies',
    'decimal_precision',
    'journals',
    'payment_terms',
    'uom',
    'pricelists',
  ];

  /// Sync only critical data (lightweight sync for recovery scenarios)
  /// Used by ConnectivitySyncOrchestrator when server recovers
  Future<void> syncCriticalData() async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) {
      logger.e('[SyncNotifier] CatalogSyncRepository not available');
      return;
    }

    if (!catalogSync.isOnline) {
      logger.e('[SyncNotifier] Not online - cannot sync critical data');
      return;
    }

    logger.i('[SyncNotifier] Starting critical data sync...');

    for (final itemName in _criticalItems) {
      try {
        // Find the item definition
        final itemDef = syncItems.firstWhere(
          (item) => item.name == itemName,
          orElse: () => throw ArgumentError('Unknown sync item: $itemName'),
        );

        // Get current sync info (for incremental sync)
        final syncInfo = await catalogSync.getModelSyncInfo(itemName);

        // Perform incremental sync
        await itemDef.syncFn(catalogSync, null, syncInfo.lastSyncDate);

        logger.d('[SyncNotifier] Synced critical item: $itemName');
      } catch (e) {
        logger.w('[SyncNotifier] Failed to sync critical item $itemName: $e');
        // Continue with other items
      }
    }

    logger.i('[SyncNotifier] Critical data sync completed');
  }

  /// Sync all catalogs sequentially
  Future<void> syncAll() async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) {
      logger.e('[SyncNotifier] CatalogSyncRepository not available');
      return;
    }

    if (!catalogSync.isOnline) {
      logger.e('[SyncNotifier] Not online');
      return;
    }

    // Check if already syncing all (use static flag for reliability)
    if (_isSyncRunning) {
      logger.d('[SyncNotifier] Already syncing all (static flag)');
      return;
    }

    // Set static flag to prevent re-entry and state resets from cancelling sync
    _isSyncRunning = true;

    // Reset cancellation flag before starting
    catalogSync.resetCancelFlag();

    // Mark all as syncing
    final newStates = <String, SyncItemState>{};
    for (final item in syncItems) {
      final current = state.getItemState(item.name);
      newStates[item.name] = current.copyWith(status: SyncStatus.syncing);
    }
    state = SyncScreenState(itemStates: newStates, isSyncingAll: true);

    // Sync each item sequentially
    for (final itemDef in syncItems) {
      // Check if sync was cancelled globally (use static flag)
      if (!_isSyncRunning) {
        logger.d('[SyncNotifier] Sync all was cancelled, stopping...');
        // Mark remaining items as idle
        for (final item in syncItems) {
          final itemState = state.getItemState(item.name);
          if (itemState.status == SyncStatus.syncing) {
            _updateItemState(
              item.name,
              itemState.copyWith(status: SyncStatus.idle),
            );
          }
        }
        break;
      }

      // Check if this specific item was already cancelled/errored
      final currentItemState = state.getItemState(itemDef.name);
      if (currentItemState.status == SyncStatus.error) {
        logger.d(
          '[SyncNotifier] Skipping ${itemDef.name} - already cancelled/errored',
        );
        continue;
      }

      // Mark this item as current
      state = state.copyWith(currentSyncingItem: itemDef.name);

      // Reset cancel flag before each item ONLY if we're still syncing
      // Don't reset if cancellation was requested
      if (!catalogSync.isCancelRequested) {
        catalogSync.resetCancelFlag();
      } else {
        logger.d(
          '[SyncNotifier] Cancel flag is set, skipping reset and breaking',
        );
        break;
      }

      // Get current sync info for incremental sync
      final currentInfo = await catalogSync.getModelSyncInfo(itemDef.name);
      final isIncremental = currentInfo.lastSyncDate != null;

      _updateItemState(
        itemDef.name,
        state
            .getItemState(itemDef.name)
            .copyWith(
              status: SyncStatus.syncing,
              wasIncremental: isIncremental,
            ),
      );

      try {
        logger.d(
          '[SyncNotifier] Syncing ${itemDef.description}... (incremental: $isIncremental)',
        );

        // First, sync deleted records if this is incremental
        if (isIncremental && currentInfo.lastSyncDate != null) {
          try {
            await catalogSync.syncDeletedRecords(
              odooModel: itemDef.odooModel,
              localModelName: itemDef.name,
              sinceDate: currentInfo.lastSyncDate,
            );
          } catch (e) {
            logger.w('[SyncNotifier] Error syncing deleted records: $e');
          }
        }

        // Progress callback
        void onProgress(SyncProgress progress) {
          _updateItemState(
            itemDef.name,
            SyncItemState(
              status: SyncStatus.syncing,
              progress: progress,
              lastSyncDate: currentInfo.lastSyncDate,
              wasIncremental: isIncremental,
            ),
          );
        }

        // Pass sinceDate for incremental sync
        final sinceDate = isIncremental ? currentInfo.lastSyncDate : null;
        final count = await itemDef.syncFn(catalogSync, onProgress, sinceDate);
        logger.d('[SyncNotifier] ${itemDef.description}: $count records');

        // Run post-sync callback if defined
        if (itemDef.postSyncFn != null) {
          await itemDef.postSyncFn!(ref);
        }

        // Save sync result
        await _saveSyncResult(
          itemDef.name,
          count: count,
          odooModel: itemDef.odooModel,
          wasIncremental: isIncremental,
        );

        // Get updated local count
        final localCount = await catalogSync.getLocalCountForModel(
          itemDef.odooModel,
        );

        _updateItemState(
          itemDef.name,
          SyncItemState(
            status: SyncStatus.success,
            count: count,
            lastSyncDate: DateTime.now(),
            localCount: localCount,
            wasIncremental: isIncremental,
          ),
        );
      } catch (e) {
        logger.e('[SyncNotifier] Error syncing ${itemDef.description}: $e');
        final errorMessage = e.toString();

        // Save error
        await _saveSyncResult(
          itemDef.name,
          count: 0,
          odooModel: itemDef.odooModel,
          error: errorMessage,
        );

        _updateItemState(
          itemDef.name,
          SyncItemState(
            status: SyncStatus.error,
            error: errorMessage,
            lastSyncDate: currentInfo.lastSyncDate,
            localCount: state.getItemState(itemDef.name).localCount,
          ),
        );

        // If cancelled, check if we should stop the whole sync
        if (catalogSync.isCancelRequested && !_isSyncRunning) {
          logger.d(
            '[SyncNotifier] Item ${itemDef.name} was cancelled, stopping sync all',
          );
          break;
        }
      }
    }

    // Mark as done and clear static flag
    _isSyncRunning = false;
    state = state.copyWith(isSyncingAll: false, currentSyncingItem: null);
    logger.d('[SyncNotifier] Full sync completed');
  }

  /// Cancel current sync operation (all items)
  void cancelSync() {
    final catalogSync = _catalogSync;
    if (catalogSync == null) return;

    logger.d('[SyncNotifier] Requesting sync cancellation...');
    _isSyncRunning = false; // Clear static flag first
    catalogSync.cancelSync();

    // Mark current syncing item as idle with cancellation message
    final currentItem = state.currentSyncingItem;
    if (currentItem != null) {
      final currentState = state.getItemState(currentItem);
      _updateItemState(
        currentItem,
        currentState.copyWith(
          status: SyncStatus.error,
          error: 'Cancelado por el usuario',
        ),
      );
    }

    // Mark all pending items as idle
    final newStates = <String, SyncItemState>{};
    for (final item in syncItems) {
      final itemState = state.getItemState(item.name);
      if (itemState.status == SyncStatus.syncing && item.name != currentItem) {
        newStates[item.name] = itemState.copyWith(status: SyncStatus.idle);
      } else {
        newStates[item.name] = itemState;
      }
    }
    state = state.copyWith(itemStates: newStates, isSyncingAll: false);
  }

  /// Cancel sync for a specific item
  void cancelItemSync(String itemName) {
    final catalogSync = _catalogSync;
    if (catalogSync == null) return;

    final itemState = state.getItemState(itemName);
    if (itemState.status != SyncStatus.syncing) {
      logger.d(
        '[SyncNotifier] Item $itemName is not syncing, nothing to cancel',
      );
      return;
    }

    logger.d('[SyncNotifier] Requesting cancellation for $itemName...');

    // Clear static flag first to stop the sync loop
    _isSyncRunning = false;

    // Also cancel via repository to set the flag
    catalogSync.cancelSync();
    logger.d('[SyncNotifier] Cancel flag set in repository');

    // Update item state to cancelled
    _updateItemState(
      itemName,
      itemState.copyWith(
        status: SyncStatus.error,
        error: 'Cancelado por el usuario',
      ),
    );

    // Mark as not syncing all anymore
    if (state.isSyncingAll) {
      logger.d('[SyncNotifier] Setting isSyncingAll = false');
      state = state.copyWith(isSyncingAll: false, currentSyncingItem: null);
    }

    // Also mark all other syncing items as idle (they haven't started yet)
    final newStates = <String, SyncItemState>{};
    for (final item in syncItems) {
      final currentState = state.getItemState(item.name);
      if (currentState.status == SyncStatus.syncing && item.name != itemName) {
        newStates[item.name] = currentState.copyWith(status: SyncStatus.idle);
      } else {
        newStates[item.name] = currentState;
      }
    }
    state = state.copyWith(itemStates: newStates);
    logger.d('[SyncNotifier] Cancellation complete for $itemName');
  }

  /// Reset all states to idle
  void resetAll() {
    final newStates = <String, SyncItemState>{};
    for (final item in syncItems) {
      newStates[item.name] = const SyncItemState();
    }
    state = SyncScreenState(itemStates: newStates);
  }

  /// Clear all catalog tables (wipe local data)
  Future<Map<String, int>> clearAllTables() async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) {
      logger.e('[SyncNotifier] CatalogSyncRepository not available');
      return {};
    }

    try {
      logger.d('[SyncNotifier] Clearing all catalog tables...');
      final results = await catalogSync.clearAllCatalogTables();

      // Reset all states to idle with zero counts
      final newStates = <String, SyncItemState>{};
      for (final item in syncItems) {
        newStates[item.name] = const SyncItemState(
          status: SyncStatus.idle,
          localCount: 0,
        );
      }
      state = SyncScreenState(itemStates: newStates);

      logger.i('[SyncNotifier] All catalog tables cleared');
      return results;
    } catch (e) {
      logger.e('[SyncNotifier] Error clearing tables: $e');
      rethrow;
    }
  }

  /// Clear a single catalog table
  /// Reset error state for a specific item, allowing it to sync again
  Future<void> resetItemError(String itemName) async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) {
      logger.e('[SyncNotifier] CatalogSyncRepository not available');
      return;
    }

    try {
      logger.d('[SyncNotifier] Resetting error for $itemName...');

      // Clear error in database
      await catalogSync.clearModelSyncError(itemName);

      // Update local state
      final currentState = state.getItemState(itemName);
      _updateItemState(
        itemName,
        currentState.copyWith(status: SyncStatus.idle, error: null),
      );

      logger.i('[SyncNotifier] Reset error for $itemName');
    } catch (e) {
      logger.e('[SyncNotifier] Error resetting $itemName: $e');
    }
  }

  /// Reset all error states, allowing all items to sync again
  /// This clears errors directly from DB to avoid race conditions with state loading
  Future<void> resetAllErrors() async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) return;

    logger.d('[SyncNotifier] Resetting all sync errors in database...');

    // Clear errors from ALL items in database (don't depend on in-memory state)
    // This avoids race conditions when _loadPersistedState() hasn't completed yet
    for (final item in syncItems) {
      try {
        await catalogSync.clearModelSyncError(item.name);
      } catch (e) {
        logger.e('[SyncNotifier] Error clearing ${item.name} error: $e');
      }
    }

    // Also update in-memory state if already loaded
    final newStates = <String, SyncItemState>{};
    for (final item in syncItems) {
      final currentState = state.getItemState(item.name);
      if (currentState.status == SyncStatus.error) {
        newStates[item.name] = currentState.copyWith(
          status: SyncStatus.idle,
          error: null,
        );
      } else {
        newStates[item.name] = currentState;
      }
    }
    state = state.copyWith(itemStates: newStates);

    logger.i('[SyncNotifier] All sync errors reset');
  }

  Future<int> clearTable(String itemName) async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) {
      logger.e('[SyncNotifier] CatalogSyncRepository not available');
      return 0;
    }

    try {
      logger.d('[SyncNotifier] Clearing table for $itemName...');
      final count = await catalogSync.clearCatalogTable(itemName);

      // Update state for this item
      _updateItemState(
        itemName,
        const SyncItemState(status: SyncStatus.idle, localCount: 0),
      );

      logger.i('[SyncNotifier] Cleared $count records from $itemName');
      return count;
    } catch (e) {
      logger.e('[SyncNotifier] Error clearing table $itemName: $e');
      rethrow;
    }
  }
}

