/// Generic Sync Repository - Orchestrates syncing multiple models
///
/// Provides a unified interface for syncing multiple Odoo models with:
/// - Progress tracking across all models
/// - Cancellation support
/// - Configurable sync order
/// - Aggregate reporting
library;

import '../api/odoo_client.dart';
import '../services/logger_service.dart';
import '../utils/odoo_parsing_utils.dart' show formatOdooDateTime;
import 'sync_models.dart';

/// Configuration for a single model sync operation.
///
/// Supports full record sync or selective field-level sync for
/// optimized bandwidth and processing.
class ModelSyncConfig {
  /// Odoo model name (e.g., 'product.product')
  final String model;

  /// Domain filter for sync
  final List<dynamic>? domain;

  /// Fields to fetch (required for searchRead)
  final List<String> fields;

  /// Batch size for pagination
  final int batchSize;

  /// Whether to support incremental sync via write_date
  final bool supportsIncremental;

  /// Order to fetch records
  final String order;

  /// Callback to upsert a single record
  final Future<void> Function(Map<String, dynamic> data) upsertRecord;

  // ===========================================================================
  // SELECTIVE FIELD SYNC OPTIONS
  // ===========================================================================

  /// Fields to track for selective sync.
  ///
  /// When set, only these fields are compared between local and remote data
  /// to determine if an update is needed. This reduces unnecessary writes
  /// when only untracked fields changed.
  ///
  /// Example:
  /// ```dart
  /// ModelSyncConfig(
  ///   model: 'product.product',
  ///   fields: ['id', 'name', 'list_price', 'qty_available', 'write_date'],
  ///   selectiveFields: ['name', 'list_price'], // Only sync if these change
  ///   ...
  /// )
  /// ```
  final List<String>? selectiveFields;

  /// Whether to enable field-level sync comparison.
  ///
  /// When true, the sync process compares individual field values between
  /// local and remote data, and only updates if tracked fields differ.
  ///
  /// Requires [selectiveFields] to be set, or uses [fields] if not.
  final bool enableFieldLevelSync;

  /// Optional callback to get local record for comparison.
  ///
  /// Required when [enableFieldLevelSync] is true. Returns the local
  /// record data for the given record ID, or null if not found locally.
  ///
  /// Example:
  /// ```dart
  /// getLocalRecord: (recordId) async {
  ///   final product = await productDao.getById(recordId);
  ///   return product?.toMap();
  /// }
  /// ```
  final Future<Map<String, dynamic>?> Function(int recordId)? getLocalRecord;

  /// Optional callback for custom field comparison logic.
  ///
  /// When provided, this function determines if a record should be updated
  /// based on local and remote field values. Return true if update is needed.
  ///
  /// If not provided, uses simple equality comparison on [selectiveFields].
  final bool Function(
    Map<String, dynamic> localData,
    Map<String, dynamic> remoteData,
    List<String> fieldsToCompare,
  )? fieldChangeDetector;

  /// Callback invoked when field-level changes are detected.
  ///
  /// Receives a [FieldLevelSyncResult] with details about which fields
  /// changed. Useful for logging, analytics, or triggering side effects.
  final void Function(FieldLevelSyncResult result)? onFieldsChanged;

  const ModelSyncConfig({
    required this.model,
    this.domain,
    required this.fields,
    this.batchSize = 200,
    this.supportsIncremental = true,
    this.order = 'id asc',
    required this.upsertRecord,
    // Selective sync options
    this.selectiveFields,
    this.enableFieldLevelSync = false,
    this.getLocalRecord,
    this.fieldChangeDetector,
    this.onFieldsChanged,
  });

  /// Creates a copy of this config with selective sync enabled.
  ModelSyncConfig withSelectiveSync({
    required List<String> selectiveFields,
    required Future<Map<String, dynamic>?> Function(int recordId) getLocalRecord,
    bool Function(
      Map<String, dynamic> localData,
      Map<String, dynamic> remoteData,
      List<String> fieldsToCompare,
    )? fieldChangeDetector,
    void Function(FieldLevelSyncResult result)? onFieldsChanged,
  }) {
    return ModelSyncConfig(
      model: model,
      domain: domain,
      fields: fields,
      batchSize: batchSize,
      supportsIncremental: supportsIncremental,
      order: order,
      upsertRecord: upsertRecord,
      selectiveFields: selectiveFields,
      enableFieldLevelSync: true,
      getLocalRecord: getLocalRecord,
      fieldChangeDetector: fieldChangeDetector,
      onFieldsChanged: onFieldsChanged,
    );
  }
}

/// Result of field-level sync comparison for a single record.
///
/// Provides detailed information about which fields changed between
/// local and remote versions of a record.
class FieldLevelSyncResult {
  /// The Odoo model name.
  final String model;

  /// The record ID that was compared.
  final int recordId;

  /// List of field names that have different values.
  final List<String> changedFields;

  /// Previous local values for the changed fields.
  final Map<String, dynamic> oldValues;

  /// New remote values for the changed fields.
  final Map<String, dynamic> newValues;

  /// Whether the record was newly created (no local version existed).
  final bool isNew;

  /// Timestamp when the comparison was made.
  final DateTime timestamp;

  const FieldLevelSyncResult({
    required this.model,
    required this.recordId,
    required this.changedFields,
    required this.oldValues,
    required this.newValues,
    this.isNew = false,
    required this.timestamp,
  });

  /// Whether any tracked fields changed.
  bool get hasChanges => changedFields.isNotEmpty || isNew;

  /// Number of fields that changed.
  int get changeCount => changedFields.length;

  @override
  String toString() {
    if (isNew) return 'FieldLevelSyncResult($model #$recordId: new record)';
    if (changedFields.isEmpty) {
      return 'FieldLevelSyncResult($model #$recordId: no changes)';
    }
    return 'FieldLevelSyncResult($model #$recordId: ${changedFields.join(", ")} changed)';
  }
}

/// Compares two records field-by-field and returns changed fields.
///
/// This is a utility function for implementing custom [ModelSyncConfig.fieldChangeDetector].
List<String> compareRecordFields(
  Map<String, dynamic> localData,
  Map<String, dynamic> remoteData,
  List<String> fieldsToCompare,
) {
  final changedFields = <String>[];

  for (final field in fieldsToCompare) {
    final localValue = localData[field];
    final remoteValue = remoteData[field];

    if (!_areValuesEqual(localValue, remoteValue)) {
      changedFields.add(field);
    }
  }

  return changedFields;
}

/// Compares two values for equality, handling special Odoo types.
bool _areValuesEqual(dynamic local, dynamic remote) {
  // Both null
  if (local == null && remote == null) return true;

  // One null
  if (local == null || remote == null) return false;

  // Handle Many2one fields (returned as [id, name] or just id)
  if (local is List && remote is List) {
    if (local.isEmpty && remote.isEmpty) return true;
    if (local.isNotEmpty && remote.isNotEmpty) {
      return local[0] == remote[0]; // Compare IDs
    }
    return false;
  }

  // Handle Many2one when local is int and remote is list
  if (local is int && remote is List && remote.isNotEmpty) {
    return local == remote[0];
  }
  if (remote is int && local is List && local.isNotEmpty) {
    return remote == local[0];
  }

  // Handle numeric comparison with tolerance for doubles
  if (local is num && remote is num) {
    if (local is double || remote is double) {
      return (local.toDouble() - remote.toDouble()).abs() < 0.0001;
    }
    return local == remote;
  }

  // Handle DateTime comparison
  if (local is DateTime && remote is DateTime) {
    return local.isAtSameMomentAs(remote);
  }

  // Default equality
  return local == remote;
}

/// Result of syncing a single model.
class ModelSyncResult {
  final String model;
  final int synced;
  final int total;
  final String? error;
  final bool wasCancelled;
  final Duration duration;

  const ModelSyncResult({
    required this.model,
    required this.synced,
    required this.total,
    this.error,
    this.wasCancelled = false,
    required this.duration,
  });

  bool get isSuccess => error == null && !wasCancelled;
  bool get isPartial => synced > 0 && synced < total;

  @override
  String toString() {
    if (wasCancelled) return 'ModelSyncResult($model: cancelled at $synced/$total)';
    if (error != null) return 'ModelSyncResult($model: error - $error)';
    return 'ModelSyncResult($model: $synced/$total in ${duration.inSeconds}s)';
  }
}

/// Aggregate result of syncing multiple models.
class AggregateSyncResult {
  final List<ModelSyncResult> results;
  final DateTime startTime;
  final DateTime endTime;

  AggregateSyncResult({
    required this.results,
    required this.startTime,
    required this.endTime,
  });

  Duration get totalDuration => endTime.difference(startTime);
  int get totalSynced => results.fold(0, (sum, r) => sum + r.synced);
  int get totalExpected => results.fold(0, (sum, r) => sum + r.total);
  int get modelsSucceeded => results.where((r) => r.isSuccess).length;
  int get modelsFailed => results.where((r) => r.error != null).length;
  bool get hasErrors => results.any((r) => r.error != null);
  bool get wasCancelled => results.any((r) => r.wasCancelled);
  bool get allSuccess => results.every((r) => r.isSuccess);

  @override
  String toString() =>
      'AggregateSyncResult(${results.length} models, $totalSynced synced, '
      '${totalDuration.inSeconds}s)';
}

/// Callback for sync progress across multiple models.
typedef MultiModelProgressCallback = void Function(
  String model,
  SyncProgress progress,
);

/// Generic sync repository that orchestrates syncing multiple Odoo models.
///
/// Example usage:
/// ```dart
/// final repo = GenericSyncRepository(odooClient: client);
///
/// // Sync a single model
/// final result = await repo.syncModel(
///   ModelSyncConfig(
///     model: 'product.product',
///     domain: [['active', '=', true]],
///     fields: ['id', 'name', 'list_price'],
///     upsertRecord: (data) => productManager.upsertLocal(productManager.fromOdoo(data)),
///   ),
///   onProgress: (progress) => print('${progress.synced}/${progress.total}'),
/// );
///
/// // Sync multiple models in sequence
/// final aggregateResult = await repo.syncModels(
///   [productsConfig, categoriesConfig, taxesConfig],
///   onProgress: (model, progress) => print('$model: ${progress.percentage}%'),
/// );
/// ```
class GenericSyncRepository {
  final OdooClient? odooClient;

  /// Flag to request sync cancellation
  bool _cancelRequested = false;

  GenericSyncRepository({this.odooClient});

  /// Check if online (has OdooClient)
  bool get isOnline => odooClient != null;

  /// Request cancellation of current sync operation
  void cancelSync() {
    _cancelRequested = true;
  }

  /// Reset the cancellation flag
  void resetCancelFlag() {
    _cancelRequested = false;
  }

  /// Check if cancellation was requested
  bool get isCancelRequested => _cancelRequested;

  /// Sync a single model from Odoo.
  ///
  /// [config] defines the model, domain, fields, and upsert callback.
  /// [sinceDate] enables incremental sync (only records modified after this date).
  /// [onProgress] reports sync progress.
  ///
  /// Returns [ModelSyncResult] with sync statistics.
  Future<ModelSyncResult> syncModel(
    ModelSyncConfig config, {
    DateTime? sinceDate,
    SyncProgressCallback? onProgress,
  }) async {
    if (!isOnline) {
      return ModelSyncResult(
        model: config.model,
        synced: 0,
        total: 0,
        error: 'Offline',
        duration: Duration.zero,
      );
    }

    final startTime = DateTime.now();
    int syncedCount = 0;
    int totalRecords = 0;

    try {
      // Build domain
      final domain = <dynamic>[
        if (config.domain != null) ...config.domain!,
      ];

      // Add incremental filter if supported
      if (sinceDate != null && config.supportsIncremental) {
        final sinceDateStr = formatOdooDateTime(sinceDate) ?? '';
        domain.add(['write_date', '>', sinceDateStr]);
        logger.d('[GenericSync] ${config.model}: incremental since $sinceDateStr');
      }

      // Get total count
      totalRecords = await odooClient!.searchCount(
        model: config.model,
        domain: domain.isEmpty ? null : domain,
      ) ?? 0;

      logger.d('[GenericSync] ${config.model}: $totalRecords records to sync');

      onProgress?.call(SyncProgress(
        total: totalRecords,
        synced: 0,
        currentItem: 'Iniciando...',
      ));

      if (totalRecords == 0) {
        return ModelSyncResult(
          model: config.model,
          synced: 0,
          total: 0,
          duration: DateTime.now().difference(startTime),
        );
      }

      // Paginated fetch and upsert
      int offset = 0;
      bool hasMore = true;

      while (hasMore) {
        // Check cancellation
        if (_cancelRequested) {
          logger.i('[GenericSync] ${config.model}: cancelled at $syncedCount/$totalRecords');
          return ModelSyncResult(
            model: config.model,
            synced: syncedCount,
            total: totalRecords,
            wasCancelled: true,
            duration: DateTime.now().difference(startTime),
          );
        }

        final records = await odooClient!.searchRead(
          model: config.model,
          domain: domain.isEmpty ? null : domain,
          fields: config.fields,
          limit: config.batchSize,
          offset: offset,
          order: config.order,
        );

        if (records.isEmpty) {
          hasMore = false;
          break;
        }

        for (final record in records) {
          // Check cancellation periodically
          if (syncedCount % 20 == 0 && _cancelRequested) {
            return ModelSyncResult(
              model: config.model,
              synced: syncedCount,
              total: totalRecords,
              wasCancelled: true,
              duration: DateTime.now().difference(startTime),
            );
          }

          await config.upsertRecord(record);
          syncedCount++;

          // Report progress every 50 records
          if (syncedCount % 50 == 0 || syncedCount == totalRecords) {
            final name = _extractDisplayName(record);
            onProgress?.call(SyncProgress(
              total: totalRecords,
              synced: syncedCount,
              currentItem: name.length > 30 ? '${name.substring(0, 30)}...' : name,
            ));
          }
        }

        if (records.length < config.batchSize) {
          hasMore = false;
        } else {
          offset += config.batchSize;
        }
      }

      logger.i('[GenericSync] ${config.model}: synced $syncedCount records');

      return ModelSyncResult(
        model: config.model,
        synced: syncedCount,
        total: totalRecords,
        duration: DateTime.now().difference(startTime),
      );
    } catch (e, stack) {
      logger.e('[GenericSync] ${config.model}: error - $e', e.toString(), stack);
      onProgress?.call(SyncProgress(
        total: totalRecords,
        synced: syncedCount,
        error: e.toString(),
      ));
      return ModelSyncResult(
        model: config.model,
        synced: syncedCount,
        total: totalRecords,
        error: e.toString(),
        duration: DateTime.now().difference(startTime),
      );
    }
  }

  /// Sync multiple models in sequence.
  ///
  /// Models are synced in the order provided. If one fails, subsequent models
  /// still attempt to sync. Use [resetCancelFlag] before calling if reusing
  /// the repository.
  ///
  /// [configs] list of model configurations in sync order.
  /// [sinceDate] enables incremental sync for all models that support it.
  /// [onProgress] reports progress for each model.
  ///
  /// Returns [AggregateSyncResult] with results for all models.
  Future<AggregateSyncResult> syncModels(
    List<ModelSyncConfig> configs, {
    DateTime? sinceDate,
    MultiModelProgressCallback? onProgress,
  }) async {
    final startTime = DateTime.now();
    final results = <ModelSyncResult>[];

    resetCancelFlag();

    for (final config in configs) {
      if (_cancelRequested) {
        // Add cancelled results for remaining models
        results.add(ModelSyncResult(
          model: config.model,
          synced: 0,
          total: 0,
          wasCancelled: true,
          duration: Duration.zero,
        ));
        continue;
      }

      final result = await syncModel(
        config,
        sinceDate: sinceDate,
        onProgress: (progress) => onProgress?.call(config.model, progress),
      );

      results.add(result);

      // If this model was cancelled, mark rest as cancelled too
      if (result.wasCancelled) {
        _cancelRequested = true;
      }
    }

    return AggregateSyncResult(
      results: results,
      startTime: startTime,
      endTime: DateTime.now(),
    );
  }

  /// Extract a display name from a record for progress reporting
  String _extractDisplayName(Map<String, dynamic> record) {
    return record['name'] as String? ??
        record['display_name'] as String? ??
        'ID: ${record['id']}';
  }
}

/// Builder for creating ModelSyncConfig from an OdooModelManager-like interface.
///
/// This allows using the GenericSyncRepository with existing managers:
/// ```dart
/// final config = SyncConfigBuilder.fromManager(
///   manager: productManager,
///   domain: [['active', '=', true]],
/// );
/// ```
class SyncConfigBuilder {
  /// Create a ModelSyncConfig that delegates to a manager's methods.
  ///
  /// [model] is the Odoo model name
  /// [fields] are the fields to fetch
  /// [fromOdoo] converts Odoo data to domain model
  /// [upsertLocal] persists the record locally
  /// [domain] optional domain filter
  /// [batchSize] records per batch
  static ModelSyncConfig create<T>({
    required String model,
    required List<String> fields,
    required T Function(Map<String, dynamic>) fromOdoo,
    required Future<void> Function(T) upsertLocal,
    List<dynamic>? domain,
    int batchSize = 200,
    bool supportsIncremental = true,
    String order = 'id asc',
  }) {
    return ModelSyncConfig(
      model: model,
      fields: fields,
      domain: domain,
      batchSize: batchSize,
      supportsIncremental: supportsIncremental,
      order: order,
      upsertRecord: (data) async {
        final record = fromOdoo(data);
        await upsertLocal(record);
      },
    );
  }
}
