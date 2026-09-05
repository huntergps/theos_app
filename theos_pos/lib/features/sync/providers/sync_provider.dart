import 'dart:async';

import 'package:odoo_sdk/odoo_sdk.dart'
    show logger, SyncModelInfo, SyncProgress, SyncProgressCallback;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../repositories/catalog_sync_repository.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/managers/manager_providers.dart';

import '../../reports/repositories/qweb_template_repository.dart';
import '../../../shared/providers/report_provider.dart';
import '../../../shared/utils/error_utils.dart';

part 'sync_provider.g.dart';

/// Serializes synchronization entry points and coalesces duplicate requests.
///
/// The queue is process-wide because [SyncNotifier] can be rebuilt while an
/// operation is still unwinding. A rebuilt notifier must observe and wait for
/// that work instead of starting a second writer against the same Drift scope.
class _SyncOperationQueue {
  Future<void> _tail = Future<void>.value();
  final Map<String, Future<void>> _pendingByKey = {};
  Completer<void>? _idleCompleter;
  var _pendingCount = 0;
  var _cancelRequested = false;

  bool get isCancellationRequested => _cancelRequested;
  bool get isBusy => _pendingCount > 0;
  bool hasPending(String key) => _pendingByKey.containsKey(key);

  Future<void> run(String key, Future<void> Function() operation) {
    final existing = _pendingByKey[key];
    if (existing != null) return existing;

    // A cancellation remains sticky until every old writer has stopped. The
    // first operation of a new idle session explicitly opens the queue again.
    if (!isBusy) _cancelRequested = false;

    final previous = _tail;
    _pendingCount++;
    _idleCompleter ??= Completer<void>();

    late final Future<void> task;
    task = () async {
      try {
        try {
          await previous;
        } catch (_) {
          // A failed predecessor must not poison the queue.
        }

        if (!_cancelRequested) await operation();
      } finally {
        if (identical(_pendingByKey[key], task)) {
          _pendingByKey.remove(key);
        }
        _pendingCount--;
        if (_pendingCount == 0) {
          _idleCompleter?.complete();
          _idleCompleter = null;
        }
      }
    }();

    _pendingByKey[key] = task;
    _tail = task;
    return task;
  }

  void requestCancellation() => _cancelRequested = true;

  Future<void> waitUntilIdle() =>
      isBusy ? _idleCompleter!.future : Future<void>.value();
}

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
  static final _syncQueue = _SyncOperationQueue();

  /// Requests cancellation without claiming that the writer is already idle.
  /// Callers that are about to close Drift must additionally await
  /// [cancelAndWait].
  static void resetSyncFlag() => _syncQueue.requestCancellation();

  /// Margen de solape para el high-water-mark de sync incremental.
  ///
  /// Se resta al timestamp capturado ANTES de iniciar el fetch a Odoo (no al
  /// de después de que termine) para cubrir dos escenarios reales:
  /// 1. Un registro se modifica en Odoo MIENTRAS el fetch está en curso —
  ///    sin este margen, su `write_date` podría quedar apenas antes del
  ///    `sinceDate` de la PRÓXIMA sync incremental y nunca más volver a
  ///    traerse (pérdida silenciosa y permanente).
  /// 2. Desfase de reloj (clock skew) entre el dispositivo y el servidor
  ///    Odoo — común en tablets POS sin NTP correctamente configurado.
  static const Duration _incrementalSyncOverlap = Duration(seconds: 60);

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
      odooModel: 'l10n.ec.bank',
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
    return SyncScreenState(
      isLoading: true,
      isSyncingAll: _syncQueue.hasPending('full'),
    );
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
          // The header badge only needs persisted status. Exact table counts
          // are refreshed when the dedicated Sync screen is opened, avoiding
          // one Drift COUNT query per catalog during the first Home frame.
          initialStates[item.name] = SyncItemState.fromModelInfo(info);
        } else {
          initialStates[item.name] = const SyncItemState();
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
  ///
  /// [syncStartTime] DEBE ser el timestamp capturado ANTES de iniciar el
  /// fetch a Odoo para este item (no el de después de que termine). Ver
  /// [_incrementalSyncOverlap] para el porqué.
  ///
  /// [previousLastSyncDate] es el `lastSyncDate` que ya estaba guardado
  /// antes de este intento. Si hubo error, NO avanzamos el watermark — lo
  /// conservamos tal cual, porque no hay garantía de que el fetch haya
  /// completado y avanzarlo igual arriesgaría saltarnos registros que
  /// quedaron sin traer.
  Future<void> _saveSyncResult(
    String itemName, {
    required int count,
    required String odooModel,
    required DateTime syncStartTime,
    DateTime? previousLastSyncDate,
    String? error,
    bool wasIncremental = false,
  }) async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) {
      throw StateError('CatalogSyncRepository not available');
    }

    final localCount = await catalogSync.getLocalCountForModel(odooModel);

    final lastSyncDate = error != null
        ? previousLastSyncDate
        : syncStartTime.subtract(_incrementalSyncOverlap);

    final info = SyncModelInfo(
      modelName: itemName,
      lastSyncDate: lastSyncDate,
      syncedCount: count,
      localCount: localCount,
      errorMessage: error,
      wasIncremental: wasIncremental,
    );

    // This write is the commit point of an item sync. Let failures propagate
    // so callers never publish an in-memory watermark that was not persisted.
    await catalogSync.saveModelSyncInfo(info);
  }

  Future<void> _saveFailedSyncResult(
    String itemName, {
    required String odooModel,
    required DateTime syncStartTime,
    DateTime? previousLastSyncDate,
    required String error,
  }) async {
    try {
      await _saveSyncResult(
        itemName,
        count: 0,
        odooModel: odooModel,
        syncStartTime: syncStartTime,
        previousLastSyncDate: previousLastSyncDate,
        error: error,
      );
    } catch (e) {
      logger.e('[SyncNotifier] Error saving failed sync for $itemName: $e');
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

    // Capturado ANTES de cualquier fetch a Odoo para este item (incluido
    // syncDeletedRecords). Se usa como el nuevo watermark en vez del
    // DateTime.now() de después de terminar — ver _incrementalSyncOverlap.
    final syncStartTime = DateTime.now().toUtc();

    try {
      logger.d(
        '[SyncNotifier] Syncing ${itemDef.description}... (incremental: $isIncremental)',
      );

      // First, sync deleted records if this is incremental
      if (isIncremental && currentInfo.lastSyncDate != null) {
        await catalogSync.syncDeletedRecords(
          odooModel: itemDef.odooModel,
          localModelName: itemName,
          sinceDate: currentInfo.lastSyncDate,
        );
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
        syncStartTime: syncStartTime,
        previousLastSyncDate: currentInfo.lastSyncDate,
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
          lastSyncDate: syncStartTime.subtract(_incrementalSyncOverlap),
          localCount: localCount,
          wasIncremental: isIncremental,
        ),
      );
    } catch (e) {
      logger.e('[SyncNotifier] Error syncing ${itemDef.description}: $e');
      final errorMessage = friendlyErrorMessage(e);

      // Save error — no avanza el watermark (ver _saveSyncResult)
      await _saveFailedSyncResult(
        itemName,
        odooModel: itemDef.odooModel,
        syncStartTime: syncStartTime,
        previousLastSyncDate: currentInfo.lastSyncDate,
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
    await _syncQueue.run('full', () async {
      final catalogSync = _catalogSync;
      if (catalogSync == null) {
        logger.e('[SyncNotifier] CatalogSyncRepository not available');
        return;
      }

      await catalogSync.clearAllModelSyncInfo();
      await _syncAllUnlocked();
    });
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
  Future<void> syncCriticalData() =>
      _syncQueue.run('critical-recovery', _syncCriticalDataUnlocked);

  Future<void> _syncCriticalDataUnlocked() async {
    final catalogSync = _catalogSync;
    if (catalogSync == null) {
      logger.e('[SyncNotifier] CatalogSyncRepository not available');
      return;
    }

    if (!catalogSync.isOnline) {
      logger.e('[SyncNotifier] Not online - cannot sync critical data');
      return;
    }

    // The queue guarantees that an older cancelled writer is already idle.
    // Clear its repository-level token before starting a new recovery pass.
    catalogSync.resetCancelFlag();
    logger.i('[SyncNotifier] Starting critical data sync...');

    final criticalItems = syncItems.where(
      (item) => _criticalItems.contains(item.name),
    );
    for (final itemDef in criticalItems) {
      if (_syncQueue.isCancellationRequested) {
        logger.d('[SyncNotifier] Critical data sync cancelled');
        break;
      }

      final itemName = itemDef.name;
      SyncModelInfo? syncInfo;
      DateTime? syncStartTime;
      try {
        // Get current sync info (for incremental sync)
        syncInfo = await catalogSync.getModelSyncInfo(itemName);
        final isIncremental = syncInfo.lastSyncDate != null;
        syncStartTime = DateTime.now().toUtc();

        // Recovery is an incremental writer too. Tombstones and records that
        // left an active/saleable domain must complete before fetching live
        // rows, otherwise persisting the recovery watermark would skip them.
        if (isIncremental) {
          await catalogSync.syncDeletedRecords(
            odooModel: itemDef.odooModel,
            localModelName: itemName,
            sinceDate: syncInfo.lastSyncDate,
          );
        }

        // Recovery uses the same persisted watermark as manual sync. Saving a
        // successful result below prevents every reconnect from becoming a
        // repeated full catalog download.
        final count = await itemDef.syncFn(
          catalogSync,
          null,
          syncInfo.lastSyncDate,
        );

        if (itemDef.postSyncFn != null) {
          await itemDef.postSyncFn!(ref);
        }

        await _saveSyncResult(
          itemName,
          count: count,
          odooModel: itemDef.odooModel,
          syncStartTime: syncStartTime,
          previousLastSyncDate: syncInfo.lastSyncDate,
          wasIncremental: isIncremental,
        );

        logger.d('[SyncNotifier] Synced critical item: $itemName');
      } catch (e) {
        logger.w('[SyncNotifier] Failed to sync critical item $itemName: $e');
        if (syncStartTime != null) {
          await _saveFailedSyncResult(
            itemName,
            odooModel: itemDef.odooModel,
            syncStartTime: syncStartTime,
            previousLastSyncDate: syncInfo?.lastSyncDate,
            error: friendlyErrorMessage(e),
          );
        }
        // Continue with other items
      }
    }

    logger.i('[SyncNotifier] Critical data sync completed');
  }

  /// Sync all catalogs sequentially
  Future<void> syncAll() => _syncQueue.run('full', _syncAllUnlocked);

  Future<void> _syncAllUnlocked() async {
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

    // Mark all as syncing
    final newStates = <String, SyncItemState>{};
    for (final item in syncItems) {
      final current = state.getItemState(item.name);
      newStates[item.name] = current.copyWith(status: SyncStatus.syncing);
    }
    state = SyncScreenState(itemStates: newStates, isSyncingAll: true);

    try {
      // Sync each item sequentially
      for (final itemDef in syncItems) {
        if (_syncQueue.isCancellationRequested) {
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

        // Capturado ANTES de cualquier fetch a Odoo para este item — ver
        // _incrementalSyncOverlap y syncItem() para la explicación completa.
        final syncStartTime = DateTime.now().toUtc();

        try {
          logger.d(
            '[SyncNotifier] Syncing ${itemDef.description}... (incremental: $isIncremental)',
          );

          // First, sync deleted records if this is incremental
          if (isIncremental && currentInfo.lastSyncDate != null) {
            await catalogSync.syncDeletedRecords(
              odooModel: itemDef.odooModel,
              localModelName: itemDef.name,
              sinceDate: currentInfo.lastSyncDate,
            );
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
          final count = await itemDef.syncFn(
            catalogSync,
            onProgress,
            sinceDate,
          );
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
            syncStartTime: syncStartTime,
            previousLastSyncDate: currentInfo.lastSyncDate,
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
              lastSyncDate: syncStartTime.subtract(_incrementalSyncOverlap),
              localCount: localCount,
              wasIncremental: isIncremental,
            ),
          );
        } catch (e) {
          logger.e('[SyncNotifier] Error syncing ${itemDef.description}: $e');
          final errorMessage = friendlyErrorMessage(e);

          // Save error — no avanza el watermark (ver _saveSyncResult)
          await _saveFailedSyncResult(
            itemDef.name,
            odooModel: itemDef.odooModel,
            syncStartTime: syncStartTime,
            previousLastSyncDate: currentInfo.lastSyncDate,
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

          // If cancelled, stop the whole sync after this item unwinds.
          if (catalogSync.isCancelRequested ||
              _syncQueue.isCancellationRequested) {
            logger.d(
              '[SyncNotifier] Item ${itemDef.name} was cancelled, stopping sync all',
            );
            break;
          }
        }
      }
    } finally {
      state = state.copyWith(isSyncingAll: false, currentSyncingItem: null);
      logger.d('[SyncNotifier] Full sync completed');
    }
  }

  /// Cancel current sync operation (all items)
  void cancelSync() {
    final catalogSync = _catalogSync;
    logger.d('[SyncNotifier] Requesting sync cancellation...');
    _syncQueue.requestCancellation();
    catalogSync?.cancelSync();

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
    // Keep isSyncingAll true until the active Future has actually unwound.
    state = state.copyWith(itemStates: newStates);
  }

  /// Cancels queued/active synchronization and waits until no writer can still
  /// access the current Drift scope.
  ///
  /// Logout and server-switch flows must await this before closing the scoped
  /// database. Cancellation is cooperative, so the currently awaited network
  /// call may finish before this future completes.
  Future<void> cancelAndWait() async {
    cancelSync();
    await _syncQueue.waitUntilIdle();
    state = state.copyWith(isSyncingAll: false, currentSyncingItem: null);
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

    _syncQueue.requestCancellation();

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
