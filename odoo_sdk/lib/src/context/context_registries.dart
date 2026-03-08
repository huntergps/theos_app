/// Instance-based registries for a [DataContext].
///
/// Each [DataContext] owns its own set of registries, replacing the
/// global singletons ([SmartModelConfigRegistry], [ModelFieldRegistry],
/// [ComputeEngineRegistry], [OdooRecordRegistry]).
library;

import '../api/odoo_client.dart';
import '../model/computed_field_engine.dart';
import '../model/field_definition.dart';
import '../model/odoo_model_manager.dart';
import '../model/odoo_record.dart';
import '../model/smart_model_config.dart';
import '../sync/offline_queue.dart';
import '../sync/sync_types.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Config Registry
// ═══════════════════════════════════════════════════════════════════════════

/// Per-context model configuration registry.
///
/// Replaces the global [SmartModelConfigRegistry] for isolated contexts.
class ContextConfigRegistry {
  final Map<Type, SmartModelConfig> _configs = {};
  final Map<String, Type> _modelToType = {};

  /// Register a model configuration by Dart type.
  void register<T>(SmartModelConfig config) {
    registerByType(T, config);
  }

  /// Register a model configuration by runtime type.
  void registerByType(Type type, SmartModelConfig config) {
    _configs[type] = config;
    _modelToType[config.odooModel] = type;
  }

  /// Get config by Dart type.
  SmartModelConfig? get<T>() => _configs[T];

  /// Get config by Odoo model name.
  SmartModelConfig? getByModel(String modelName) {
    final type = _modelToType[modelName];
    return type != null ? _configs[type] : null;
  }

  /// All registered configurations.
  Iterable<SmartModelConfig> get all => _configs.values;

  /// All registered types.
  Iterable<Type> get types => _configs.keys;

  /// All registered Odoo model names.
  Iterable<String> get modelNames => _modelToType.keys;

  /// Check if a type is registered.
  bool has<T>() => _configs.containsKey(T);

  /// Check if a model name is registered.
  bool hasModel(String modelName) => _modelToType.containsKey(modelName);

  /// Clear all registrations.
  void clear() {
    _configs.clear();
    _modelToType.clear();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Manager Registry
// ═══════════════════════════════════════════════════════════════════════════

/// Per-context manager registry.
///
/// Stores [OdooModelManager] instances keyed by both Odoo model name
/// and Dart type. Replaces [ModelRegistry] + [OdooRecordRegistry]
/// for isolated contexts.
class ContextManagerRegistry {
  final Map<String, OdooModelManager> _byModel = {};
  final Map<Type, OdooModelManager> _byType = {};

  /// Register a manager by type and model name.
  void register<T>(OdooModelManager<T> manager) {
    _byType[T] = manager;
    _byModel[manager.odooModel] = manager;
  }

  /// Get manager by Dart type.
  OdooModelManager<T>? getByType<T>() {
    return _byType[T] as OdooModelManager<T>?;
  }

  /// Get manager by Odoo model name.
  OdooModelManager? getByModel(String modelName) {
    return _byModel[modelName];
  }

  /// All registered Odoo model names.
  Iterable<String> get modelNames => _byModel.keys;

  /// All registered managers.
  Iterable<OdooModelManager> get all => _byModel.values;

  /// Number of registered managers.
  int get length => _byModel.length;

  /// Initialize all managers with shared dependencies.
  void initializeAll({
    required OdooClient client,
    required dynamic database, // GeneratedDatabase
    required OfflineQueueWrapper queue,
    ModelManagerConfig? config,
  }) {
    for (final manager in _byModel.values) {
      manager.initialize(
        client: client,
        db: database,
        queue: queue,
        config: config,
      );
    }
  }

  /// Sync all managers, returning a combined [SyncReport].
  Future<SyncReport> syncAll({
    CancellationToken? cancellation,
  }) async {
    final results = <SyncResult>[];
    final startTime = DateTime.now();

    for (final manager in _byModel.values) {
      if (cancellation?.isCancelled ?? false) break;
      final result = await manager.sync(cancellation: cancellation);
      results.add(result);
    }

    return SyncReport(
      results: results,
      startTime: startTime,
      endTime: DateTime.now(),
    );
  }

  /// Sync a single model by name.
  Future<SyncResult> syncModel(
    String modelName, {
    DateTime? since,
    CancellationToken? cancellation,
  }) async {
    final manager = _byModel[modelName];
    if (manager == null) {
      return SyncResult.error(
        model: modelName,
        error: 'No manager registered for $modelName',
      );
    }
    return manager.sync(since: since, cancellation: cancellation);
  }

  /// Push this context's managers into the global [OdooRecordRegistry].
  ///
  /// This bridges the per-context world to the global singletons that
  /// [OdooRecord] mixins still depend on.
  void registerAllInGlobalRegistry() {
    for (final entry in _byType.entries) {
      OdooRecordRegistry.registerByType(entry.key, entry.value);
    }
  }

  /// Dispose all managers and clear maps.
  void disposeAll() {
    for (final manager in _byModel.values) {
      manager.dispose();
    }
    _byModel.clear();
    _byType.clear();
  }
}

// ═══════════════════════════════════════════════════════════════════════════
// Field Registry
// ═══════════════════════════════════════════════════════════════════════════

/// Per-context field registry.
///
/// Replaces the global [ModelFieldRegistry] for isolated contexts.
class ContextFieldRegistry {
  final Map<Type, FieldRegistry> _registries = {};

  /// Register a field registry by Dart type.
  void register<T>(FieldRegistry registry) {
    registerByType(T, registry);
  }

  /// Register by runtime type.
  void registerByType(Type type, FieldRegistry registry) {
    _registries[type] = registry;
  }

  /// Get field registry by Dart type.
  FieldRegistry? get<T>() => _registries[T];

  /// Get field registry by runtime type.
  FieldRegistry? getByType(Type type) => _registries[type];

  /// Check if a type has a field registry.
  bool has<T>() => _registries.containsKey(T);

  /// Clear all registrations.
  void clear() => _registries.clear();
}

// ═══════════════════════════════════════════════════════════════════════════
// Compute Registry
// ═══════════════════════════════════════════════════════════════════════════

/// Per-context compute engine registry.
///
/// Replaces the global [ComputeEngineRegistry] for isolated contexts.
class ContextComputeRegistry {
  final Map<Type, ComputedFieldEngine> _engines = {};

  /// Register a compute engine by Dart type.
  void register<T>(ComputedFieldEngine<T> engine) {
    registerByType(T, engine);
  }

  /// Register by runtime type.
  void registerByType(Type type, ComputedFieldEngine engine) {
    _engines[type] = engine;
  }

  /// Get compute engine by Dart type.
  ComputedFieldEngine<T>? get<T>() {
    return _engines[T] as ComputedFieldEngine<T>?;
  }

  /// Check if a type has a compute engine.
  bool has<T>() => _engines.containsKey(T);

  /// Clear all registrations.
  void clear() => _engines.clear();
}
