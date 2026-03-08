/// DataContext — isolated data container for one Odoo connection.
///
/// Each context owns its own client, database handle, offline queue,
/// and per-context registries. Multiple contexts can coexist, e.g.
/// one for POS and another for back-office.
library;

import 'dart:async';

import 'package:drift/drift.dart';
import '../api/odoo_client.dart';
import '../model/computed_field_engine.dart';
import '../model/odoo_model_manager.dart';
import '../model/smart_model_config.dart';
import '../sync/offline_queue.dart';
import '../sync/sync_metrics.dart';
import '../sync/sync_types.dart';

import '../session/data_session.dart';
import 'context_registries.dart';
import 'context_state.dart';

/// An isolated data context backed by a single [DataSession].
///
/// ## Lifecycle
///
/// ```
/// created  ─── register models ───> initialize() ──> initialized
///                                                       │
///                                                    dispose()
///                                                       │
///                                                    disposed
/// ```
///
/// ## Usage
///
/// ```dart
/// final ctx = DataContext(session);
///
/// // Register models before init
/// ctx.registerManager<Product>(productManager);
/// ctx.registerConfig<Product>(Product.config);
///
/// // Initialize with DB + queue
/// await ctx.initialize(database: db, queueStore: store);
///
/// // Use
/// final mgr = ctx.managerFor<Product>();
/// final products = await mgr?.search();
///
/// // Cleanup
/// ctx.dispose();
/// ```
class DataContext {
  /// The session this context is backed by.
  final DataSession session;

  ContextState _state = ContextState.created;

  /// Current lifecycle state.
  ContextState get state => _state;

  // Dependencies (set during initialize)
  OdooClient? _client;
  GeneratedDatabase? _database;
  OfflineQueueWrapper? _queue;

  /// The Odoo client for this context (null until initialized).
  OdooClient? get client => _client;

  /// The Drift database for this context (null until initialized).
  GeneratedDatabase? get database => _database;

  /// The offline queue for this context (null until initialized).
  OfflineQueueWrapper? get queue => _queue;

  // Metrics
  SyncMetricsCollector? _metricsCollector;

  /// The sync metrics collector for this context.
  ///
  /// Lazily created on first access. Use [enableMetrics] to configure
  /// before first use, or access directly to use default settings.
  SyncMetricsCollector get metrics =>
      _metricsCollector ??= SyncMetricsCollector();

  // Per-context registries
  final ContextConfigRegistry configs = ContextConfigRegistry();
  final ContextManagerRegistry managers = ContextManagerRegistry();
  final ContextFieldRegistry fields = ContextFieldRegistry();
  final ContextComputeRegistry computes = ContextComputeRegistry();

  DataContext(this.session);

  // ═══════════════════════════════════════════════════════════════════════════
  // Registration (before init)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Register a model configuration.
  ///
  /// Must be called before [initialize].
  void registerConfig<T>(SmartModelConfig config) {
    _ensureNotDisposed();
    configs.register<T>(config);

    // Auto-create field registry + compute engine
    fields.register<T>(config.toFieldRegistry());
    computes.register<T>(ComputedFieldEngine<T>.fromConfig(config));
  }

  /// Register a manager instance.
  ///
  /// Must be called before [initialize].
  void registerManager<T>(OdooModelManager<T> manager) {
    _ensureNotDisposed();
    managers.register<T>(manager);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Initialization
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize the context with infrastructure dependencies.
  ///
  /// Creates an [OdooClient] from the session, wires the database and
  /// offline queue, and initializes all registered managers.
  ///
  /// Throws [StateError] if already initialized or disposed.
  Future<void> initialize({
    required GeneratedDatabase database,
    required OfflineQueueStore queueStore,
    ModelManagerConfig? config,
  }) async {
    if (_state == ContextState.initialized) {
      throw StateError('DataContext "${session.id}" is already initialized');
    }
    if (_state == ContextState.disposed) {
      throw StateError('DataContext "${session.id}" has been disposed');
    }

    _client = OdooClient(config: session.toClientConfig());
    _database = database;
    _queue = OfflineQueueWrapper(queueStore);
    await _queue!.initialize();

    // Initialize all registered managers
    managers.initializeAll(
      client: _client!,
      database: database,
      queue: _queue!,
      config: config,
    );

    _state = ContextState.initialized;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Manager access
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get the manager for a model by Dart type.
  OdooModelManager<T>? managerFor<T>() {
    _ensureInitialized();
    return managers.getByType<T>();
  }

  /// Get the manager by Odoo model name.
  OdooModelManager? managerByModel(String modelName) {
    _ensureInitialized();
    return managers.getByModel(modelName);
  }

  /// All registered Odoo model names in this context.
  Iterable<String> get registeredModels => managers.modelNames;

  // ═══════════════════════════════════════════════════════════════════════════
  // Sync
  // ═══════════════════════════════════════════════════════════════════════════

  /// Enable metrics collection with the given configuration.
  ///
  /// Call this before any sync operations to configure the collector.
  /// If not called, a default collector is lazily created on first access.
  void enableMetrics({int maxMetrics = 1000}) {
    _metricsCollector = SyncMetricsCollector(maxMetrics: maxMetrics);
  }

  /// Sync all models in this context.
  ///
  /// If metrics are enabled, each model result is automatically recorded.
  Future<SyncReport> syncAll({CancellationToken? cancellation}) async {
    _ensureInitialized();
    final startTime = DateTime.now();
    final report = await managers.syncAll(cancellation: cancellation);
    if (_metricsCollector != null) {
      for (final result in report.results) {
        _metricsCollector!.recordFromResult(result, startTime: startTime);
      }
    }
    return report;
  }

  /// Sync a single model by Odoo model name.
  ///
  /// If metrics are enabled, the result is automatically recorded.
  Future<SyncResult> syncModel(
    String modelName, {
    DateTime? since,
    CancellationToken? cancellation,
  }) async {
    _ensureInitialized();
    if (_metricsCollector != null) {
      return _metricsCollector!.timed(modelName, () {
        return managers.syncModel(
          modelName,
          since: since,
          cancellation: cancellation,
        );
      });
    }
    return managers.syncModel(
      modelName,
      since: since,
      cancellation: cancellation,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // WebSocket
  // ═══════════════════════════════════════════════════════════════════════════

  /// Route a WebSocket record event to the appropriate manager.
  void handleWebSocketEvent(ModelRecordEvent event) {
    _ensureInitialized();
    final manager = managers.getByModel(event.model);
    manager?.handleWebSocketEvent(event);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Cleanup
  // ═══════════════════════════════════════════════════════════════════════════

  /// Dispose all resources owned by this context.
  void dispose() {
    if (_state == ContextState.disposed) return;

    managers.disposeAll();
    _queue?.dispose();
    _metricsCollector?.clear();
    _metricsCollector = null;
    configs.clear();
    fields.clear();
    computes.clear();

    _client = null;
    _database = null;
    _queue = null;

    _state = ContextState.disposed;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Guards
  // ═══════════════════════════════════════════════════════════════════════════

  void _ensureInitialized() {
    if (_state != ContextState.initialized) {
      throw StateError(
        'DataContext "${session.id}" is not initialized (state: $_state)',
      );
    }
  }

  void _ensureNotDisposed() {
    if (_state == ContextState.disposed) {
      throw StateError('DataContext "${session.id}" has been disposed');
    }
  }

  @override
  String toString() => 'DataContext(${session.id}, state: $_state)';
}
