/// DataLayerBridge — context-aware bridge for [OdooDataLayer].
///
/// Delegates all operations to the active [DataContext] managed by
/// [OdooDataLayer], providing a simple API surface for app code.
library;

import 'dart:async';

import 'package:drift/drift.dart';
import '../api/odoo_client.dart';
import '../model/odoo_model_manager.dart';
import '../model/smart_model_config.dart';
import '../sync/offline_queue.dart';
import '../sync/sync_types.dart';

import '../context/data_context.dart';
import '../facade/odoo_data_layer.dart';
import '../session/data_session.dart';

/// Abstract logger interface for bridge operations.
///
/// Implement this to provide custom logging (console, file, Sentry, etc.).
abstract class MatrixLogger {
  void info(String tag, String message);
  void warning(String tag, String message);
  void error(String tag, String message, [Object? error, StackTrace? stackTrace]);
}

/// Context-aware bridge that delegates to [OdooDataLayer].
///
/// Routes all operations through the active [DataContext].
///
/// ## Usage
///
/// ```dart
/// final layer = OdooDataLayer();
/// final bridge = DataLayerBridge(layer);
///
/// await bridge.initialize(
///   session: posSession,
///   database: db,
///   queueStore: store,
///   registerModels: (ctx) { ... },
/// );
///
/// // Operations go through the active context
/// await bridge.syncAll();
/// bridge.managerFor('sale.order');
///
/// // Switch context
/// bridge.switchContext('other-session-id');
/// ```
class DataLayerBridge {
  final OdooDataLayer _layer;
  MatrixLogger? _logger;

  DataLayerBridge(this._layer, {MatrixLogger? logger}) : _logger = logger;

  /// Whether the bridge has an active, initialized context.
  bool get isReady => _layer.activeContext != null;

  /// The Odoo client from the active context.
  OdooClient? get odooClient => _layer.activeContext?.client;

  /// The offline queue from the active context.
  OfflineQueueWrapper? get offlineQueue => _layer.activeContext?.queue;

  /// Set a custom logger.
  void setLogger(MatrixLogger logger) {
    _logger = logger;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Initialization
  // ═══════════════════════════════════════════════════════════════════════════

  /// Initialize a new context and make it active.
  ///
  /// This is the main entry point — creates a [DataContext] via
  /// [OdooDataLayer.createAndInitializeContext].
  Future<DataContext> initialize({
    required DataSession session,
    required GeneratedDatabase database,
    required OfflineQueueStore queueStore,
    required void Function(DataContext ctx) registerModels,
    ModelManagerConfig? config,
  }) async {
    _logger?.info('DataLayerBridge', 'Initializing context "${session.id}"...');

    final ctx = await _layer.createAndInitializeContext(
      session: session,
      database: database,
      queueStore: queueStore,
      registerModels: registerModels,
      config: config,
    );

    _logger?.info('DataLayerBridge', 'Context "${session.id}" ready');
    return ctx;
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Manager access
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get manager by Odoo model name from the active context.
  OdooModelManager? managerFor(String modelName) {
    _ensureReady();
    return _layer.activeContext!.managerByModel(modelName);
  }

  /// Get model configuration by name from the active context.
  SmartModelConfig? configFor(String modelName) {
    _ensureReady();
    return _layer.activeContext!.configs.getByModel(modelName);
  }

  /// All registered model names in the active context.
  List<String> get registeredModels {
    if (!isReady) return [];
    return _layer.activeContext!.registeredModels.toList();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Sync
  // ═══════════════════════════════════════════════════════════════════════════

  /// Sync all models in the active context.
  Future<SyncReport> syncAll({CancellationToken? cancellation}) async {
    _ensureReady();
    _logger?.info('DataLayerBridge', 'Syncing all models...');
    return _layer.activeContext!.syncAll(cancellation: cancellation);
  }

  /// Sync a single model by name in the active context.
  Future<SyncResult> syncModel(
    String modelName, {
    DateTime? since,
    CancellationToken? cancellation,
  }) async {
    _ensureReady();
    _logger?.info('DataLayerBridge', 'Syncing model: $modelName');
    return _layer.activeContext!.syncModel(
      modelName,
      since: since,
      cancellation: cancellation,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Model actions
  // ═══════════════════════════════════════════════════════════════════════════

  /// Call an Odoo action on a model record via the active context's client.
  Future<dynamic> callModelAction(
    String model,
    int recordId,
    String action, {
    Map<String, dynamic>? kwargs,
  }) async {
    _ensureReady();
    final client = _layer.activeContext!.client!;
    return client.call(
      model: model,
      method: action,
      ids: [recordId],
      kwargs: kwargs,
    );
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Context switching
  // ═══════════════════════════════════════════════════════════════════════════

  /// Switch to a different context by session ID.
  void switchContext(String sessionId) {
    _logger?.info('DataLayerBridge', 'Switching to context "$sessionId"');
    _layer.setActiveContext(sessionId);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Cleanup
  // ═══════════════════════════════════════════════════════════════════════════

  /// Dispose the bridge (does NOT dispose the underlying [OdooDataLayer]).
  void dispose() {
    _logger?.info('DataLayerBridge', 'Disposed');
    _logger = null;
  }

  void _ensureReady() {
    if (!isReady) {
      throw StateError(
        'DataLayerBridge has no active context. '
        'Call initialize() or switchContext() first.',
      );
    }
  }
}
