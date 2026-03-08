/// OdooDataLayer — multi-context facade.
///
/// Manages multiple [DataContext] instances and provides context switching
/// with automatic global-registry synchronization.
library;

import 'dart:async';

import 'package:drift/drift.dart';
import '../model/odoo_model_manager.dart';
import '../model/odoo_record.dart';
import '../sync/offline_queue.dart';

import '../context/context_state.dart';
import '../context/data_context.dart';
import '../session/data_session.dart';

/// Top-level facade for managing multiple isolated data contexts.
///
/// Each context represents one Odoo connection (session + managers + DB).
/// At any time one context is "active" — its managers are published to
/// the global [OdooRecordRegistry] so that [OdooRecord] mixins resolve
/// correctly.
///
/// ## Usage
///
/// ```dart
/// final layer = OdooDataLayer();
///
/// // Create and initialize a context
/// await layer.createAndInitializeContext(
///   session: posSession,
///   database: db,
///   queueStore: store,
///   registerModels: (ctx) {
///     ctx.registerConfig<Product>(Product.config);
///     ctx.registerManager<Product>(productManager);
///   },
/// );
///
/// // Switch active context
/// layer.setActiveContext('pos-session-id');
///
/// // Dispose when done
/// layer.dispose();
/// ```
class OdooDataLayer {
  final Map<String, DataContext> _contexts = {};
  String? _activeContextId;
  final _contextChanges = StreamController<String?>.broadcast();

  /// Stream of active context ID changes.
  Stream<String?> get contextChanges => _contextChanges.stream;

  /// The currently active context ID, or null if none.
  String? get activeContextId => _activeContextId;

  /// The currently active context, or null if none.
  DataContext? get activeContext =>
      _activeContextId != null ? _contexts[_activeContextId] : null;

  /// All registered context IDs.
  Iterable<String> get contextIds => _contexts.keys;

  /// Number of registered contexts.
  int get contextCount => _contexts.length;

  // ═══════════════════════════════════════════════════════════════════════════
  // Context lifecycle
  // ═══════════════════════════════════════════════════════════════════════════

  /// Create a new [DataContext] from a session.
  ///
  /// The context is registered but NOT initialized. Call
  /// [DataContext.initialize] or use [createAndInitializeContext] instead.
  DataContext createContext(DataSession session) {
    if (_contexts.containsKey(session.id)) {
      throw StateError(
        'A context with id "${session.id}" already exists',
      );
    }
    final ctx = DataContext(session);
    _contexts[session.id] = ctx;
    return ctx;
  }

  /// Create, register models, initialize, and optionally activate a context.
  ///
  /// This is the preferred one-shot factory method.
  Future<DataContext> createAndInitializeContext({
    required DataSession session,
    required GeneratedDatabase database,
    required OfflineQueueStore queueStore,
    required void Function(DataContext ctx) registerModels,
    ModelManagerConfig? config,
    bool setActive = true,
  }) async {
    final ctx = createContext(session);
    registerModels(ctx);
    await ctx.initialize(
      database: database,
      queueStore: queueStore,
      config: config,
    );

    if (setActive) {
      setActiveContext(session.id);
    }
    return ctx;
  }

  /// Get a context by session ID.
  DataContext? getContext(String sessionId) => _contexts[sessionId];

  /// Set the active context and sync global registries.
  ///
  /// Throws [StateError] if the context doesn't exist or isn't initialized.
  void setActiveContext(String sessionId) {
    final ctx = _contexts[sessionId];
    if (ctx == null) {
      throw StateError('No context with id "$sessionId"');
    }
    if (ctx.state != ContextState.initialized) {
      throw StateError(
        'Context "$sessionId" is not initialized (state: ${ctx.state})',
      );
    }

    _activeContextId = sessionId;
    _syncGlobalRegistry(ctx);
    _contextChanges.add(sessionId);
  }

  /// Dispose and remove a single context.
  void disposeContext(String sessionId) {
    final ctx = _contexts.remove(sessionId);
    ctx?.dispose();
    if (_activeContextId == sessionId) {
      _activeContextId = null;
      OdooRecordRegistry.clear();
      _contextChanges.add(null);
    }
  }

  /// Dispose all contexts and close streams.
  void dispose() {
    for (final ctx in _contexts.values) {
      ctx.dispose();
    }
    _contexts.clear();
    _activeContextId = null;
    _contextChanges.close();
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Global registry synchronization
  // ═══════════════════════════════════════════════════════════════════════════

  /// Push the given context's managers into the global [OdooRecordRegistry].
  void _syncGlobalRegistry(DataContext context) {
    OdooRecordRegistry.clear();
    context.managers.registerAllInGlobalRegistry();
  }
}
