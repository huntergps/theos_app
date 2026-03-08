/// Smart Model Configuration
///
/// Base configuration class that defines all model-specific settings
/// in a centralized way. Similar to Odoo's model metadata.
///
/// Each model provides its configuration via a static [config] getter,
/// enabling the framework to automatically handle:
/// - Sync strategy and timing
/// - WebSocket subscriptions
/// - Field mappings
/// - Validation rules
/// - State machine transitions
library;

import 'package:meta/meta.dart';

import '../utils/sync_constants.dart';
import 'field_definition.dart';

/// Sync strategy for a model.
enum SyncStrategy {
  /// Sync immediately when online (real-time).
  realtime,

  /// Sync in background periodically.
  background,

  /// Sync only on user request.
  manual,

  /// One-way sync from Odoo only (catalog data).
  pullOnly,

  /// One-way sync to Odoo only.
  pushOnly,

  /// No sync (local-only model).
  none,
}

/// Priority for sync operations.
enum SyncPriority {
  /// Critical data (orders, payments).
  critical,

  /// Important data (customers, products).
  high,

  /// Normal data.
  normal,

  /// Low priority (logs, analytics).
  low,
}

/// Configuration for sync behavior.
@immutable
class SyncConfig {
  /// The sync strategy for this model.
  final SyncStrategy strategy;

  /// Sync priority.
  final SyncPriority priority;

  /// Interval for background sync in seconds (for [SyncStrategy.background]).
  final int backgroundIntervalSeconds;

  /// Maximum batch size for sync operations.
  final int batchSize;

  /// Whether to sync on app startup.
  final bool syncOnStartup;

  /// Whether to subscribe to WebSocket events.
  final bool subscribeWebSocket;

  /// Maximum age of local data before forcing refresh (in hours).
  final int? maxDataAgeHours;

  /// Fields to always fetch (even if not in model).
  final List<String> alwaysFetchFields;

  /// Fields to exclude from sync.
  final List<String> excludeFromSync;

  /// Custom domain for sync (e.g., filter by company).
  final List<dynamic>? syncDomain;

  const SyncConfig({
    this.strategy = SyncStrategy.realtime,
    this.priority = SyncPriority.normal,
    this.backgroundIntervalSeconds = 300,
    this.batchSize = 100,
    this.syncOnStartup = true,
    this.subscribeWebSocket = true,
    this.maxDataAgeHours,
    this.alwaysFetchFields = const [],
    this.excludeFromSync = const [],
    this.syncDomain,
  });

  /// Configuration for real-time sync (orders, payments).
  const SyncConfig.realtime()
      : strategy = SyncStrategy.realtime,
        priority = SyncPriority.critical,
        backgroundIntervalSeconds = 0,
        batchSize = SyncConstants.realtimeBatchSize,
        syncOnStartup = true,
        subscribeWebSocket = true,
        maxDataAgeHours = null,
        alwaysFetchFields = const [],
        excludeFromSync = const [],
        syncDomain = null;

  /// Configuration for background sync (products, customers).
  const SyncConfig.background({
    int intervalSeconds = SyncConstants.backgroundIntervalSeconds,
  })  : strategy = SyncStrategy.background,
        priority = SyncPriority.high,
        backgroundIntervalSeconds = intervalSeconds,
        batchSize = SyncConstants.defaultBatchSize,
        syncOnStartup = true,
        subscribeWebSocket = true,
        maxDataAgeHours = SyncConstants.maxDataAgeHours,
        alwaysFetchFields = const [],
        excludeFromSync = const [],
        syncDomain = null;

  /// Configuration for catalog data (pull-only).
  const SyncConfig.catalog()
      : strategy = SyncStrategy.pullOnly,
        priority = SyncPriority.normal,
        backgroundIntervalSeconds = SyncConstants.catalogIntervalSeconds,
        batchSize = SyncConstants.catalogBatchSize,
        syncOnStartup = true,
        subscribeWebSocket = false,
        maxDataAgeHours = SyncConstants.catalogMaxDataAgeHours,
        alwaysFetchFields = const [],
        excludeFromSync = const [],
        syncDomain = null;

  /// Configuration for local-only models.
  const SyncConfig.localOnly()
      : strategy = SyncStrategy.none,
        priority = SyncPriority.low,
        backgroundIntervalSeconds = 0,
        batchSize = 0,
        syncOnStartup = false,
        subscribeWebSocket = false,
        maxDataAgeHours = null,
        alwaysFetchFields = const [],
        excludeFromSync = const [],
        syncDomain = null;

  /// Create a copy with modified values.
  SyncConfig copyWith({
    SyncStrategy? strategy,
    SyncPriority? priority,
    int? backgroundIntervalSeconds,
    int? batchSize,
    bool? syncOnStartup,
    bool? subscribeWebSocket,
    int? maxDataAgeHours,
    List<String>? alwaysFetchFields,
    List<String>? excludeFromSync,
    List<dynamic>? syncDomain,
  }) {
    return SyncConfig(
      strategy: strategy ?? this.strategy,
      priority: priority ?? this.priority,
      backgroundIntervalSeconds:
          backgroundIntervalSeconds ?? this.backgroundIntervalSeconds,
      batchSize: batchSize ?? this.batchSize,
      syncOnStartup: syncOnStartup ?? this.syncOnStartup,
      subscribeWebSocket: subscribeWebSocket ?? this.subscribeWebSocket,
      maxDataAgeHours: maxDataAgeHours ?? this.maxDataAgeHours,
      alwaysFetchFields: alwaysFetchFields ?? this.alwaysFetchFields,
      excludeFromSync: excludeFromSync ?? this.excludeFromSync,
      syncDomain: syncDomain ?? this.syncDomain,
    );
  }
}

/// Base configuration for a smart model.
///
/// Models provide their configuration via a static getter:
/// ```dart
/// class SaleOrder ... {
///   static SmartModelConfig get config => SmartModelConfig(
///     odooModel: 'sale.order',
///     tableName: 'sale_orders',
///     syncConfig: SyncConfig.realtime(),
///     fieldDefinitions: [
///       FieldBuilder.char('name').isRequired().build(),
///       FieldBuilder.selection('state', {...}).build(),
///       // ...
///     ],
///   );
/// }
/// ```
@immutable
class SmartModelConfig {
  /// The Odoo model name (e.g., 'sale.order').
  final String odooModel;

  /// The local database table name.
  final String tableName;

  /// Human-readable model description.
  final String? description;

  /// Sync configuration.
  final SyncConfig syncConfig;

  /// Field definitions.
  final List<FieldDefinition> fieldDefinitions;

  /// State machine transitions (if applicable).
  /// Map of state -> list of allowed next states.
  final Map<String, List<String>>? stateTransitions;

  /// The field name that holds the state.
  final String? stateField;

  /// SQL constraints.
  final List<SqlConstraintDef>? sqlConstraints;

  /// Default order for records.
  final String? defaultOrder;

  /// Whether the model supports soft delete (active field).
  final bool supportsSoftDelete;

  /// Parent model (for _inherits in Odoo or one2many relations).
  final String? parentModel;

  /// Field name that links to parent (for one2many relations).
  final String? parentField;

  /// Display name field.
  final String displayNameField;

  /// Fields to use for rec_name (search).
  final List<String> recNameFields;

  /// Computed fields configuration.
  ///
  /// Defines computed fields with their dependencies for automatic recalculation.
  final List<ComputedFieldConfig> computedFields;

  const SmartModelConfig({
    required this.odooModel,
    required this.tableName,
    this.description,
    this.syncConfig = const SyncConfig(),
    this.fieldDefinitions = const [],
    this.computedFields = const [],
    this.stateTransitions,
    this.stateField,
    this.sqlConstraints,
    this.defaultOrder,
    this.supportsSoftDelete = true,
    this.parentModel,
    this.parentField,
    this.displayNameField = 'name',
    this.recNameFields = const ['name'],
  });

  /// Get field definitions as a registry.
  FieldRegistry toFieldRegistry() {
    final registry = FieldRegistry(odooModel);
    registry.registerAll(fieldDefinitions);
    return registry;
  }

  /// Get Odoo field names to fetch.
  List<String> get odooFields {
    final fields = <String>{};

    // Add fields from definitions
    for (final field in fieldDefinitions) {
      if (field.isReadable && !field.isComputed && !field.localOnly) {
        fields.add(field.effectiveOdooName);
      }
    }

    // Add always-fetch fields
    fields.addAll(syncConfig.alwaysFetchFields);

    // Add standard fields
    fields.addAll(['id', 'write_date', 'create_date']);
    if (supportsSoftDelete) fields.add('active');

    // Remove excluded fields
    for (final excluded in syncConfig.excludeFromSync) {
      fields.remove(excluded);
    }

    return fields.toList();
  }

  /// Get the dependency graph for computed fields.
  Map<String, List<String>> get dependencyGraph {
    final graph = <String, List<String>>{};

    for (final field in fieldDefinitions) {
      if (field.isComputed) {
        for (final dep in field.depends) {
          graph[dep] ??= [];
          graph[dep]!.add(field.name);
        }
      }
    }

    return graph;
  }

  /// Get fields with onchange handlers.
  Map<String, String> get onchangeHandlers {
    final handlers = <String, String>{};

    for (final field in fieldDefinitions) {
      if (field.hasOnchange && field.onchangeMethod != null) {
        handlers[field.name] = field.onchangeMethod!;
      }
    }

    return handlers;
  }
}

/// SQL constraint definition.
@immutable
class SqlConstraintDef {
  /// Constraint name.
  final String name;

  /// SQL constraint expression.
  final String constraint;

  /// Error message.
  final String message;

  const SqlConstraintDef(this.name, this.constraint, this.message);
}

/// Computed field configuration.
///
/// Defines a computed field with its dependencies.
/// Used for automatic recalculation when dependencies change.
///
/// ```dart
/// ComputedFieldConfig(name: 'amountTotal', depends: ['orderLines.priceSubtotal'])
/// ```
@immutable
class ComputedFieldConfig {
  /// The computed field name.
  final String name;

  /// List of field names this computed field depends on.
  final List<String> depends;

  /// Optional description for documentation.
  final String? description;

  const ComputedFieldConfig({
    required this.name,
    required this.depends,
    this.description,
  });
}

/// Global registry of model configurations.
class SmartModelConfigRegistry {
  static final Map<Type, SmartModelConfig> _configs = {};
  static final Map<String, Type> _modelToType = {};

  /// Register a configuration for a model type.
  static void register<T>(SmartModelConfig config) {
    _configs[T] = config;
    _modelToType[config.odooModel] = T;
  }

  /// Register a configuration by Type (for dynamic registration).
  static void registerByType(Type type, SmartModelConfig config) {
    _configs[type] = config;
    _modelToType[config.odooModel] = type;
  }

  /// Get configuration for a model type.
  static SmartModelConfig? get<T>() => _configs[T];

  /// Get configuration by Odoo model name.
  static SmartModelConfig? getByModel(String modelName) {
    final type = _modelToType[modelName];
    return type != null ? _configs[type] : null;
  }

  /// Get all registered configurations.
  static Iterable<SmartModelConfig> get all => _configs.values;

  /// Get all registered model types.
  static Iterable<Type> get types => _configs.keys;

  /// Check if a type has configuration.
  static bool has<T>() => _configs.containsKey(T);

  /// Check if a model name has configuration.
  static bool hasModel(String modelName) => _modelToType.containsKey(modelName);

  /// Clear all configurations.
  static void clear() {
    _configs.clear();
    _modelToType.clear();
  }
}

/// Mixin that provides access to model configuration.
///
/// Add to your model class to enable automatic configuration:
/// ```dart
/// @freezed
/// class SaleOrder with _$SaleOrder, SmartModelConfigured<SaleOrder> {
///   static SmartModelConfig get config => SmartModelConfig(...);
/// }
/// ```
mixin SmartModelConfigured<T> {
  /// Get the configuration for this model type.
  ///
  /// Models should override this with their specific configuration.
  SmartModelConfig get modelConfig {
    final config = SmartModelConfigRegistry.get<T>();
    if (config == null) {
      throw StateError(
        'No configuration registered for ${T.toString()}. '
        'Call SmartModelConfigRegistry.register<$T>(config) first.',
      );
    }
    return config;
  }

  /// Get the field registry.
  FieldRegistry get fieldRegistry => modelConfig.toFieldRegistry();

  /// Get sync configuration.
  SyncConfig get syncConfig => modelConfig.syncConfig;

  /// Get the Odoo model name.
  String get odooModelName => modelConfig.odooModel;

  /// Get the table name.
  String get localTableName => modelConfig.tableName;
}
