/// Model Registry - Central Manager for OdooModelManagers
///
/// The ModelRegistry is a singleton that:
/// - Registers and manages all model managers
/// - Initializes managers with shared dependencies
/// - Routes WebSocket events to appropriate managers
/// - Coordinates sync operations across models
///
/// Usage:
/// ```dart
/// // Register managers (usually done at app startup)
/// ModelRegistry.register(productManager);
/// ModelRegistry.register(partnerManager);
///
/// // Initialize all with dependencies
/// ModelRegistry.initializeAll(
///   client: odooClient,
///   db: database,
///   queue: offlineQueue,
/// );
///
/// // Sync all models
/// await ModelRegistry.syncAll();
/// ```
library;

import 'dart:async';

import 'package:drift/drift.dart';
import '../api/odoo_client.dart';
import '../sync/sync_models.dart';
import '../sync/sync_types.dart';
import '../utils/value_stream.dart';

// Local OfflineQueueWrapper (application-specific implementation)
import '../sync/offline_queue.dart';
import 'odoo_model_manager.dart';

/// Callback for sync progress across multiple models.
typedef MultiModelSyncCallback = void Function(
  String model,
  SyncProgress progress,
);

/// Configuration for model sync order and dependencies.
class SyncConfiguration {
  /// Order in which models should be synced.
  /// Models not in this list are synced after listed models.
  final List<String> syncOrder;

  /// Models that should be synced in parallel.
  final List<List<String>> parallelGroups;

  /// Models that should not be synced automatically.
  final Set<String> excludeFromAutoSync;

  const SyncConfiguration({
    this.syncOrder = const [],
    this.parallelGroups = const [],
    this.excludeFromAutoSync = const {},
  });

  /// Default configuration - sync in registration order.
  static const SyncConfiguration defaultConfig = SyncConfiguration();
}

/// Central registry for all Odoo model managers.
///
/// Provides a unified interface for:
/// - Managing model manager lifecycle
/// - Coordinating sync operations
/// - Routing WebSocket events
/// - Querying across models
///
/// ## Registry Architecture
///
/// The framework uses three complementary registries:
///
/// 1. **[ModelRegistry]** (this class) - Maps Odoo model names (e.g.
///    `'product.product'`) to their [OdooModelManager] instances.
///    Coordinates initialization, sync, and WebSocket routing.
///
/// 2. **[OdooRecordRegistry]** (in `odoo_record.dart`) - Maps Dart types
///    (e.g. `Product`) to their [OdooModelManager]. Allows `OdooRecord`
///    and `SmartOdooModel` mixins to find their manager without injection.
///
/// 3. **[DataContext]** - Per-session container that combines all registries.
///    Manages `SmartModelConfig`, `FieldRegistry`, and `ComputedFieldEngine`
///    alongside managers.
///
/// ## Initialization Flow
///
/// ```
/// OdooRecordRegistry.register<T>(manager)    // by Dart Type
///        |
///        v
/// ModelRegistry.register(manager)            // by model name
///        |
///        v
/// DataContext.initialize(client, db, queue)
///        |
///        v
/// ModelRegistry.initializeAll(client, db, queue)
///        |
///        v
/// each manager.initialize(client, db, queue)
/// ```
class ModelRegistry {
  // Singleton instance
  static final ModelRegistry _instance = ModelRegistry._internal();
  factory ModelRegistry() => _instance;
  ModelRegistry._internal();

  // Registered managers
  final _managers = <String, OdooModelManager>{};

  // Dependencies (OdooClient from odoo_offline_core - single connection point)
  OdooClient? _client;
  GeneratedDatabase? _db;
  OfflineQueueWrapper? _queue;
  SyncConfiguration _syncConfig = SyncConfiguration.defaultConfig;

  // State streams
  final _isSyncing = ValueStream<bool>(false);
  final _syncProgress = ValueStream<Map<String, SyncProgress>>({});
  final _lastSyncReport = ValueStream<SyncReport?>(null);

  /// Stream indicating if any sync is in progress.
  Stream<bool> get isSyncing => _isSyncing.stream;

  /// Current syncing state (synchronous).
  bool get isSyncingNow => _isSyncing.value;

  /// Stream of sync progress for all models.
  Stream<Map<String, SyncProgress>> get syncProgress => _syncProgress.stream;

  /// Current sync progress for all models (synchronous).
  Map<String, SyncProgress> get currentSyncProgress => _syncProgress.value;

  /// Stream of last sync report.
  Stream<SyncReport?> get lastSyncReport => _lastSyncReport.stream;

  /// Latest sync report (synchronous).
  SyncReport? get latestSyncReport => _lastSyncReport.value;

  /// Get all registered model names.
  List<String> get registeredModels => _managers.keys.toList();

  /// Check if a model is registered.
  bool isRegistered(String model) => _managers.containsKey(model);

  // ═══════════════════════════════════════════════════════════════════════════
  // Static Convenience Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Register a model manager.
  ///
  /// If [initializeAll] was already called, the new manager is automatically
  /// initialized with the stored dependencies.
  static void register(OdooModelManager manager) {
    _instance._managers[manager.odooModel] = manager;

    // Auto-initialize if dependencies are already available
    final client = _instance._client;
    final db = _instance._db;
    final queue = _instance._queue;
    if (client != null && db != null && queue != null) {
      manager.initialize(client: client, db: db, queue: queue);
    }
  }

  /// Get a manager by model name.
  static T? get<T extends OdooModelManager>(String model) {
    return _instance._managers[model] as T?;
  }

  /// Initialize all registered managers with dependencies.
  ///
  /// Uses OdooClient from odoo_offline_core as the single connection point.
  static void initializeAll({
    required OdooClient client,
    required GeneratedDatabase db,
    required OfflineQueueWrapper queue,
    SyncConfiguration? syncConfig,
    ModelManagerConfig? managerConfig,
  }) {
    _instance._client = client;
    _instance._db = db;
    _instance._queue = queue;

    if (syncConfig != null) {
      _instance._syncConfig = syncConfig;
    }

    for (final manager in _instance._managers.values) {
      manager.initialize(
        client: client,
        db: db,
        queue: queue,
        config: managerConfig,
      );
    }
  }

  /// Sync all models from Odoo.
  static Future<SyncReport> syncAll({
    DateTime? since,
    MultiModelSyncCallback? onProgress,
    CancellationToken? cancellation,
  }) {
    return _instance._syncAllModels(
      since: since,
      onProgress: onProgress,
      cancellation: cancellation,
    );
  }

  /// Sync a specific model.
  static Future<SyncResult> syncModel(
    String model, {
    DateTime? since,
    void Function(SyncProgress)? onProgress,
    CancellationToken? cancellation,
  }) {
    final manager = _instance._managers[model];
    if (manager == null) {
      return Future.value(SyncResult.error(
        model: model,
        error: 'Model $model not registered',
      ));
    }

    return manager.syncFromOdoo(
      since: since,
      onProgress: onProgress,
      cancellation: cancellation,
    );
  }

  /// Get a manager by Odoo model name (non-generic).
  static OdooModelManager? getByModel(String model) {
    return _instance._managers[model];
  }

  /// Route a WebSocket event to the appropriate manager.
  static void handleWebSocketEvent(ModelRecordEvent event) {
    final manager = _instance._managers[event.model];
    manager?.handleWebSocketEvent(event);
  }

  /// Setup WebSocket event handlers.
  static void setupWebSocketHandlers(Stream<ModelRecordEvent> eventStream) {
    _instance._setupWebSocketHandlers(eventStream);
  }

  /// Dispose all managers and resources.
  static void disposeAll() {
    _instance._dispose();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Instance Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get manager for a model (instance method).
  OdooModelManager? getManager(String model) => _managers[model];

  /// Get typed manager for a model (instance method).
  T? getTypedManager<T extends OdooModelManager>(String model) {
    return _managers[model] as T?;
  }

  /// Sync all models with proper ordering.
  Future<SyncReport> _syncAllModels({
    DateTime? since,
    MultiModelSyncCallback? onProgress,
    CancellationToken? cancellation,
  }) async {
    if (_isSyncing.value) {
      return SyncReport(
        results: [
          SyncResult.alreadyInProgress(model: 'all'),
        ],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
    }

    _isSyncing.add(true);
    final startTime = DateTime.now();
    final results = <SyncResult>[];
    final progressMap = <String, SyncProgress>{};

    try {
      // Determine sync order
      final modelsToSync = _getSyncOrder();

      for (final model in modelsToSync) {
        if (cancellation?.isCancelled ?? false) {
          results.add(SyncResult.cancelled(model: model));
          continue;
        }

        if (_syncConfig.excludeFromAutoSync.contains(model)) {
          continue;
        }

        final manager = _managers[model];
        if (manager == null) continue;

        final result = await manager.syncFromOdoo(
          since: since,
          onProgress: (progress) {
            progressMap[model] = progress;
            _syncProgress.add(Map.from(progressMap));
            onProgress?.call(model, progress);
          },
          cancellation: cancellation,
        );

        results.add(result);
      }
    } finally {
      _isSyncing.add(false);
    }

    final report = SyncReport(
      results: results,
      startTime: startTime,
      endTime: DateTime.now(),
    );

    _lastSyncReport.add(report);
    return report;
  }

  /// Get models in sync order.
  List<String> _getSyncOrder() {
    final ordered = <String>[];
    final remaining = Set<String>.from(_managers.keys);

    // First, add models in specified order
    for (final model in _syncConfig.syncOrder) {
      if (remaining.remove(model)) {
        ordered.add(model);
      }
    }

    // Then add remaining models in registration order
    ordered.addAll(remaining);

    return ordered;
  }

  /// Setup WebSocket event routing.
  StreamSubscription<ModelRecordEvent>? _webSocketSubscription;

  void _setupWebSocketHandlers(Stream<ModelRecordEvent> eventStream) {
    _webSocketSubscription?.cancel();
    _webSocketSubscription = eventStream.listen((event) {
      final manager = _managers[event.model];
      manager?.handleWebSocketEvent(event);
    });
  }

  /// Dispose all resources.
  void _dispose() {
    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;

    for (final manager in _managers.values) {
      manager.dispose();
    }
    _managers.clear();

    _isSyncing.close();
    _syncProgress.close();
    _lastSyncReport.close();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Utility Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get aggregate unsynced count across all models.
  Future<int> getTotalUnsyncedCount() async {
    int total = 0;
    for (final manager in _managers.values) {
      final unsynced = await manager.getUnsyncedRecords();
      total += unsynced.length;
    }
    return total;
  }

  /// Get sync status for all models.
  Future<Map<String, ModelSyncStatus>> getSyncStatus() async {
    final status = <String, ModelSyncStatus>{};

    for (final entry in _managers.entries) {
      final unsynced = await entry.value.getUnsyncedRecords();
      final lastWrite = await entry.value.getLastWriteDate();

      status[entry.key] = ModelSyncStatus(
        model: entry.key,
        unsyncedCount: unsynced.length,
        lastSyncTime: null, // Would need to track this
        lastWriteDate: lastWrite,
      );
    }

    return status;
  }

  /// Check if any model has unsynced changes.
  Future<bool> hasUnsyncedChanges() async {
    for (final manager in _managers.values) {
      final unsynced = await manager.getUnsyncedRecords();
      if (unsynced.isNotEmpty) return true;
    }
    return false;
  }

  /// Push all local changes to Odoo.
  Future<SyncReport> pushAll({
    MultiModelSyncCallback? onProgress,
    CancellationToken? cancellation,
  }) async {
    final startTime = DateTime.now();
    final results = <SyncResult>[];

    for (final manager in _managers.values) {
      if (cancellation?.isCancelled ?? false) {
        results.add(SyncResult.cancelled(model: manager.odooModel));
        continue;
      }

      final result = await manager.syncToOdoo(
        onProgress: (progress) {
          onProgress?.call(manager.odooModel, progress);
        },
        cancellation: cancellation,
      );

      results.add(result);
    }

    return SyncReport(
      results: results,
      startTime: startTime,
      endTime: DateTime.now(),
    );
  }
}

/// Sync status for a single model.
class ModelSyncStatus {
  final String model;
  final int unsyncedCount;
  final DateTime? lastSyncTime;
  final DateTime? lastWriteDate;

  const ModelSyncStatus({
    required this.model,
    required this.unsyncedCount,
    this.lastSyncTime,
    this.lastWriteDate,
  });

  bool get hasUnsyncedChanges => unsyncedCount > 0;

  @override
  String toString() =>
      'ModelSyncStatus($model: unsynced=$unsyncedCount, lastSync=$lastSyncTime)';
}

/// Extension for registering managers with type inference.
extension ModelRegistryExtension on ModelRegistry {
  /// Register a manager and return it for chaining.
  T registerManager<T extends OdooModelManager>(T manager) {
    _managers[manager.odooModel] = manager;
    return manager;
  }
}
