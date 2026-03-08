/// SyncCoordinator - Centralized Sync Management
///
/// Coordinates sync operations across multiple OdooModelManagers,
/// providing a unified interface for:
/// - Ordered sync execution
/// - Parallel sync for independent models
/// - Progress aggregation
/// - Cancellation handling
///
/// This class extracts sync coordination logic that would otherwise
/// be duplicated or scattered across managers.
library;

import 'dart:async';

import 'sync_models.dart';
import 'sync_types.dart';
import '../utils/value_stream.dart';

import '../model/odoo_model_manager.dart';

/// Configuration for sync operations.
class SyncCoordinatorConfig {
  /// Models to sync in order (dependencies first).
  final List<String> modelOrder;

  /// Groups of models that can sync in parallel.
  final List<List<String>> parallelGroups;

  /// Models to exclude from automatic sync.
  final Set<String> excludeModels;

  /// Whether to stop on first error.
  final bool stopOnError;

  /// Maximum concurrent syncs for parallel groups.
  final int maxConcurrent;

  const SyncCoordinatorConfig({
    this.modelOrder = const [],
    this.parallelGroups = const [],
    this.excludeModels = const {},
    this.stopOnError = false,
    this.maxConcurrent = 3,
  });

  static const SyncCoordinatorConfig defaultConfig = SyncCoordinatorConfig();
}

/// Progress for a multi-model sync operation.
class MultiSyncProgress {
  /// Progress for each model being synced.
  final Map<String, SyncProgress> modelProgress;

  /// Models that have completed.
  final Set<String> completedModels;

  /// Models currently syncing.
  final Set<String> activeModels;

  /// Total models to sync.
  final int totalModels;

  /// Overall progress (0.0 to 1.0).
  double get overallProgress {
    if (totalModels == 0) return 1.0;
    return completedModels.length / totalModels;
  }

  const MultiSyncProgress({
    required this.modelProgress,
    required this.completedModels,
    required this.activeModels,
    required this.totalModels,
  });

  factory MultiSyncProgress.initial(List<String> models) {
    return MultiSyncProgress(
      modelProgress: {},
      completedModels: {},
      activeModels: {},
      totalModels: models.length,
    );
  }

  MultiSyncProgress copyWith({
    Map<String, SyncProgress>? modelProgress,
    Set<String>? completedModels,
    Set<String>? activeModels,
    int? totalModels,
  }) {
    return MultiSyncProgress(
      modelProgress: modelProgress ?? this.modelProgress,
      completedModels: completedModels ?? this.completedModels,
      activeModels: activeModels ?? this.activeModels,
      totalModels: totalModels ?? this.totalModels,
    );
  }
}

/// Coordinates sync operations across multiple model managers.
///
/// Example usage:
/// ```dart
/// final coordinator = SyncCoordinator(
///   managers: {
///     'product.product': productManager,
///     'product.category': categoryManager,
///     'res.partner': partnerManager,
///   },
///   config: SyncCoordinatorConfig(
///     // Categories should sync before products (dependency)
///     modelOrder: ['product.category', 'product.product'],
///     // Partners can sync in parallel with products
///     parallelGroups: [['res.partner', 'product.product']],
///   ),
/// );
///
/// // Sync all models
/// final report = await coordinator.syncAll();
///
/// // Sync specific models in parallel
/// final report = await coordinator.syncParallel(['res.partner', 'res.users']);
/// ```
class SyncCoordinator {
  /// Registered managers by model name.
  final Map<String, OdooModelManager> _managers;

  /// Configuration for sync behavior.
  final SyncCoordinatorConfig config;

  // State
  final _isSyncing = ValueStream<bool>(false);
  final _progress = ValueStream<MultiSyncProgress?>(null);
  final _errors = StreamController<SyncError>.broadcast();

  /// Whether a sync is currently in progress.
  Stream<bool> get isSyncing => _isSyncing.stream;

  /// Current syncing state (synchronous).
  bool get isSyncingNow => _isSyncing.value;

  /// Current sync progress.
  Stream<MultiSyncProgress?> get progress => _progress.stream;

  /// Current multi-model sync progress (synchronous).
  MultiSyncProgress? get currentProgress => _progress.value;

  /// Stream of sync errors.
  Stream<SyncError> get errors => _errors.stream;

  SyncCoordinator({
    required Map<String, OdooModelManager> managers,
    this.config = SyncCoordinatorConfig.defaultConfig,
  }) : _managers = Map.from(managers);

  /// Add a manager for a model.
  void registerManager(String model, OdooModelManager manager) {
    _managers[model] = manager;
  }

  /// Remove a manager.
  void unregisterManager(String model) {
    _managers.remove(model);
  }

  /// Sync all registered models in configured order.
  Future<SyncReport> syncAll({
    DateTime? since,
    void Function(String model, SyncProgress progress)? onProgress,
    CancellationToken? cancellation,
  }) async {
    if (_isSyncing.value) {
      return SyncReport(
        results: [SyncResult.alreadyInProgress(model: 'all')],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
    }

    _isSyncing.add(true);
    final startTime = DateTime.now();
    final results = <SyncResult>[];

    try {
      final modelsToSync = _getOrderedModels();
      final progressState = MultiSyncProgress.initial(modelsToSync);
      _progress.add(progressState);

      for (final model in modelsToSync) {
        if (cancellation?.isCancelled ?? false) {
          results.add(SyncResult.cancelled(model: model));
          continue;
        }

        if (config.excludeModels.contains(model)) {
          continue;
        }

        final manager = _managers[model];
        if (manager == null) continue;

        // Update active models
        _progress.add(progressState.copyWith(
          activeModels: {...progressState.activeModels, model},
        ));

        try {
          final result = await manager.syncFromOdoo(
            since: since,
            onProgress: (p) {
              _progress.add(progressState.copyWith(
                modelProgress: {...progressState.modelProgress, model: p},
              ));
              onProgress?.call(model, p);
            },
            cancellation: cancellation,
          );
          results.add(result);

          // Update completed models
          _progress.add(progressState.copyWith(
            completedModels: {...progressState.completedModels, model},
            activeModels: progressState.activeModels..remove(model),
          ));
        } catch (e, stack) {
          _errors.add(SyncError(
            model: model,
            error: e,
            stackTrace: stack,
          ));

          results.add(SyncResult.error(model: model, error: e.toString()));

          if (config.stopOnError) break;
        }
      }
    } finally {
      _isSyncing.add(false);
      _progress.add(null);
    }

    return SyncReport(
      results: results,
      startTime: startTime,
      endTime: DateTime.now(),
    );
  }

  /// Sync specific models in parallel.
  Future<SyncReport> syncParallel(
    List<String> models, {
    DateTime? since,
    void Function(String model, SyncProgress progress)? onProgress,
    CancellationToken? cancellation,
  }) async {
    final startTime = DateTime.now();
    final progressState = MultiSyncProgress.initial(models);
    _progress.add(progressState);

    final futures = <Future<SyncResult>>[];

    for (final model in models) {
      if (cancellation?.isCancelled ?? false) {
        futures.add(Future.value(SyncResult.cancelled(model: model)));
        continue;
      }

      final manager = _managers[model];
      if (manager == null) {
        futures.add(Future.value(SyncResult.error(
          model: model,
          error: 'Manager not registered',
        )));
        continue;
      }

      futures.add(manager.syncFromOdoo(
        since: since,
        onProgress: (p) {
          _progress.add(progressState.copyWith(
            modelProgress: {...progressState.modelProgress, model: p},
          ));
          onProgress?.call(model, p);
        },
        cancellation: cancellation,
      ).catchError((e, stack) {
        _errors.add(SyncError(
          model: model,
          error: e,
          stackTrace: stack,
        ));
        return SyncResult.error(model: model, error: e.toString());
      }));
    }

    final results = await Future.wait(futures);
    _progress.add(null);

    return SyncReport(
      results: results,
      startTime: startTime,
      endTime: DateTime.now(),
    );
  }

  /// Sync with automatic parallel grouping.
  ///
  /// Uses configured parallel groups to optimize sync performance.
  Future<SyncReport> syncOptimized({
    DateTime? since,
    void Function(String model, SyncProgress progress)? onProgress,
    CancellationToken? cancellation,
  }) async {
    if (_isSyncing.value) {
      return SyncReport(
        results: [SyncResult.alreadyInProgress(model: 'all')],
        startTime: DateTime.now(),
        endTime: DateTime.now(),
      );
    }

    _isSyncing.add(true);
    final startTime = DateTime.now();
    final allResults = <SyncResult>[];

    try {
      // First, sync models in order (dependencies)
      final orderedModels = config.modelOrder
          .where((m) => _managers.containsKey(m) && !config.excludeModels.contains(m))
          .toList();

      for (final model in orderedModels) {
        if (cancellation?.isCancelled ?? false) {
          allResults.add(SyncResult.cancelled(model: model));
          continue;
        }

        final manager = _managers[model]!;
        final result = await manager.syncFromOdoo(
          since: since,
          onProgress: (p) => onProgress?.call(model, p),
          cancellation: cancellation,
        );
        allResults.add(result);
      }

      // Then, sync parallel groups
      for (final group in config.parallelGroups) {
        final groupModels = group
            .where((m) => _managers.containsKey(m) && !config.excludeModels.contains(m))
            .toList();

        if (groupModels.isEmpty) continue;

        final report = await syncParallel(
          groupModels,
          since: since,
          onProgress: onProgress,
          cancellation: cancellation,
        );
        allResults.addAll(report.results);
      }

      // Finally, sync remaining models
      final syncedModels = <String>{};
      syncedModels.addAll(orderedModels);
      for (final group in config.parallelGroups) {
        syncedModels.addAll(group);
      }

      final remainingModels = _managers.keys
          .where((m) => !syncedModels.contains(m) && !config.excludeModels.contains(m))
          .toList();

      for (final model in remainingModels) {
        if (cancellation?.isCancelled ?? false) {
          allResults.add(SyncResult.cancelled(model: model));
          continue;
        }

        final manager = _managers[model]!;
        final result = await manager.syncFromOdoo(
          since: since,
          onProgress: (p) => onProgress?.call(model, p),
          cancellation: cancellation,
        );
        allResults.add(result);
      }
    } finally {
      _isSyncing.add(false);
    }

    return SyncReport(
      results: allResults,
      startTime: startTime,
      endTime: DateTime.now(),
    );
  }

  /// Get models in configured order.
  List<String> _getOrderedModels() {
    final ordered = <String>[];
    final remaining = Set<String>.from(_managers.keys);

    // First, add models in specified order
    for (final model in config.modelOrder) {
      if (remaining.remove(model)) {
        ordered.add(model);
      }
    }

    // Then add remaining models
    ordered.addAll(remaining);

    return ordered;
  }

  /// Dispose resources.
  void dispose() {
    _isSyncing.close();
    _progress.close();
    _errors.close();
  }
}

/// Error that occurred during sync.
class SyncError {
  /// Model that was being synced.
  final String model;

  /// The error that occurred.
  final Object error;

  /// Stack trace of the error.
  final StackTrace? stackTrace;

  /// When the error occurred.
  final DateTime timestamp;

  SyncError({
    required this.model,
    required this.error,
    this.stackTrace,
  }) : timestamp = DateTime.now();

  @override
  String toString() => 'SyncError($model): $error';
}

// ════════════════════════════════════════════════════════════════════════════
// DETAILED SYNC METRICS
// ════════════════════════════════════════════════════════════════════════════

/// Detailed metrics for a single model sync operation.
class SyncOperationMetrics {
  /// Model name (e.g., 'sale.order').
  final String model;

  /// When sync started.
  final DateTime startTime;

  /// When sync ended.
  final DateTime endTime;

  /// Total records fetched from Odoo.
  final int recordsFetched;

  /// Records that were new (inserted locally).
  final int recordsInserted;

  /// Records that were updated locally.
  final int recordsUpdated;

  /// Records that were deleted locally.
  final int recordsDeleted;

  /// Records skipped (unchanged).
  final int recordsSkipped;

  /// Number of API requests made.
  final int apiRequests;

  /// Total bytes received from API.
  final int bytesReceived;

  /// Number of database operations performed.
  final int dbOperations;

  /// Whether sync completed successfully.
  final bool success;

  /// Error message if sync failed.
  final String? errorMessage;

  /// Retry count (if retries were needed).
  final int retryCount;

  /// Duration of the sync.
  Duration get duration => endTime.difference(startTime);

  /// Records processed per second.
  double get recordsPerSecond {
    final seconds = duration.inMilliseconds / 1000.0;
    if (seconds <= 0) return 0;
    return recordsFetched / seconds;
  }

  /// Average bytes per record.
  double get bytesPerRecord {
    if (recordsFetched == 0) return 0;
    return bytesReceived / recordsFetched;
  }

  /// Total records changed (inserted + updated + deleted).
  int get recordsChanged => recordsInserted + recordsUpdated + recordsDeleted;

  const SyncOperationMetrics({
    required this.model,
    required this.startTime,
    required this.endTime,
    this.recordsFetched = 0,
    this.recordsInserted = 0,
    this.recordsUpdated = 0,
    this.recordsDeleted = 0,
    this.recordsSkipped = 0,
    this.apiRequests = 0,
    this.bytesReceived = 0,
    this.dbOperations = 0,
    this.success = true,
    this.errorMessage,
    this.retryCount = 0,
  });

  factory SyncOperationMetrics.error({
    required String model,
    required String error,
    DateTime? startTime,
  }) {
    final now = DateTime.now();
    return SyncOperationMetrics(
      model: model,
      startTime: startTime ?? now,
      endTime: now,
      success: false,
      errorMessage: error,
    );
  }

  Map<String, dynamic> toJson() => {
    'model': model,
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'recordsFetched': recordsFetched,
    'recordsInserted': recordsInserted,
    'recordsUpdated': recordsUpdated,
    'recordsDeleted': recordsDeleted,
    'recordsSkipped': recordsSkipped,
    'recordsChanged': recordsChanged,
    'apiRequests': apiRequests,
    'bytesReceived': bytesReceived,
    'dbOperations': dbOperations,
    'recordsPerSecond': recordsPerSecond,
    'success': success,
    if (errorMessage != null) 'error': errorMessage,
    if (retryCount > 0) 'retryCount': retryCount,
  };

  @override
  String toString() {
    if (!success) return 'SyncOperationMetrics($model): FAILED - $errorMessage';
    return 'SyncOperationMetrics($model): ${recordsFetched}r in ${duration.inMilliseconds}ms '
        '(+$recordsInserted ~$recordsUpdated -$recordsDeleted)';
  }
}

/// Builder for collecting SyncOperationMetrics incrementally.
class SyncOperationMetricsBuilder {
  final String model;
  final DateTime startTime;

  int _recordsFetched = 0;
  int _recordsInserted = 0;
  int _recordsUpdated = 0;
  int _recordsDeleted = 0;
  int _recordsSkipped = 0;
  int _apiRequests = 0;
  int _bytesReceived = 0;
  int _dbOperations = 0;
  int _retryCount = 0;
  String? _errorMessage;

  SyncOperationMetricsBuilder(this.model) : startTime = DateTime.now();

  void addRecordsFetched(int count) => _recordsFetched += count;
  void addRecordsInserted(int count) => _recordsInserted += count;
  void addRecordsUpdated(int count) => _recordsUpdated += count;
  void addRecordsDeleted(int count) => _recordsDeleted += count;
  void addRecordsSkipped(int count) => _recordsSkipped += count;
  void addApiRequest({int bytes = 0}) {
    _apiRequests++;
    _bytesReceived += bytes;
  }
  void addDbOperation() => _dbOperations++;
  void addDbOperations(int count) => _dbOperations += count;
  void incrementRetry() => _retryCount++;
  void setError(String error) => _errorMessage = error;

  SyncOperationMetrics build({bool success = true}) {
    return SyncOperationMetrics(
      model: model,
      startTime: startTime,
      endTime: DateTime.now(),
      recordsFetched: _recordsFetched,
      recordsInserted: _recordsInserted,
      recordsUpdated: _recordsUpdated,
      recordsDeleted: _recordsDeleted,
      recordsSkipped: _recordsSkipped,
      apiRequests: _apiRequests,
      bytesReceived: _bytesReceived,
      dbOperations: _dbOperations,
      retryCount: _retryCount,
      success: success && _errorMessage == null,
      errorMessage: _errorMessage,
    );
  }
}

/// Aggregated metrics for a complete sync session.
class SyncSessionMetrics {
  /// Individual model metrics.
  final List<SyncOperationMetrics> modelMetrics;

  /// When the session started.
  final DateTime startTime;

  /// When the session ended.
  final DateTime endTime;

  /// Total duration of the sync session.
  Duration get duration => endTime.difference(startTime);

  /// Total records fetched across all models.
  int get totalRecordsFetched =>
      modelMetrics.fold(0, (sum, m) => sum + m.recordsFetched);

  /// Total records inserted across all models.
  int get totalRecordsInserted =>
      modelMetrics.fold(0, (sum, m) => sum + m.recordsInserted);

  /// Total records updated across all models.
  int get totalRecordsUpdated =>
      modelMetrics.fold(0, (sum, m) => sum + m.recordsUpdated);

  /// Total records deleted across all models.
  int get totalRecordsDeleted =>
      modelMetrics.fold(0, (sum, m) => sum + m.recordsDeleted);

  /// Total records skipped across all models.
  int get totalRecordsSkipped =>
      modelMetrics.fold(0, (sum, m) => sum + m.recordsSkipped);

  /// Total records changed (inserted + updated + deleted).
  int get totalRecordsChanged =>
      totalRecordsInserted + totalRecordsUpdated + totalRecordsDeleted;

  /// Total API requests made.
  int get totalApiRequests =>
      modelMetrics.fold(0, (sum, m) => sum + m.apiRequests);

  /// Total bytes received.
  int get totalBytesReceived =>
      modelMetrics.fold(0, (sum, m) => sum + m.bytesReceived);

  /// Total database operations.
  int get totalDbOperations =>
      modelMetrics.fold(0, (sum, m) => sum + m.dbOperations);

  /// Number of models synced successfully.
  int get successfulModels =>
      modelMetrics.where((m) => m.success).length;

  /// Number of models that failed.
  int get failedModels =>
      modelMetrics.where((m) => !m.success).length;

  /// Overall success rate (0.0 to 1.0).
  double get successRate {
    if (modelMetrics.isEmpty) return 1.0;
    return successfulModels / modelMetrics.length;
  }

  /// Average records per second across all models.
  double get averageRecordsPerSecond {
    final seconds = duration.inMilliseconds / 1000.0;
    if (seconds <= 0) return 0;
    return totalRecordsFetched / seconds;
  }

  /// Slowest model by duration.
  SyncOperationMetrics? get slowestModel {
    if (modelMetrics.isEmpty) return null;
    return modelMetrics.reduce((a, b) =>
        a.duration > b.duration ? a : b);
  }

  /// Model with most records.
  SyncOperationMetrics? get largestModel {
    if (modelMetrics.isEmpty) return null;
    return modelMetrics.reduce((a, b) =>
        a.recordsFetched > b.recordsFetched ? a : b);
  }

  /// Failed models.
  List<SyncOperationMetrics> get failures =>
      modelMetrics.where((m) => !m.success).toList();

  const SyncSessionMetrics({
    required this.modelMetrics,
    required this.startTime,
    required this.endTime,
  });

  factory SyncSessionMetrics.empty() {
    final now = DateTime.now();
    return SyncSessionMetrics(
      modelMetrics: [],
      startTime: now,
      endTime: now,
    );
  }

  Map<String, dynamic> toJson() => {
    'startTime': startTime.toIso8601String(),
    'endTime': endTime.toIso8601String(),
    'durationMs': duration.inMilliseconds,
    'modelsTotal': modelMetrics.length,
    'modelsSuccess': successfulModels,
    'modelsFailed': failedModels,
    'successRate': successRate,
    'totalRecordsFetched': totalRecordsFetched,
    'totalRecordsInserted': totalRecordsInserted,
    'totalRecordsUpdated': totalRecordsUpdated,
    'totalRecordsDeleted': totalRecordsDeleted,
    'totalRecordsSkipped': totalRecordsSkipped,
    'totalRecordsChanged': totalRecordsChanged,
    'totalApiRequests': totalApiRequests,
    'totalBytesReceived': totalBytesReceived,
    'totalDbOperations': totalDbOperations,
    'averageRecordsPerSecond': averageRecordsPerSecond,
    'models': modelMetrics.map((m) => m.toJson()).toList(),
    if (failures.isNotEmpty) 'failures': failures.map((m) => m.model).toList(),
  };

  /// Generate a human-readable summary.
  String toSummary() {
    final buffer = StringBuffer();
    buffer.writeln('=== Sync Session Summary ===');
    buffer.writeln('Duration: ${duration.inSeconds}s');
    buffer.writeln('Models: $successfulModels/${ modelMetrics.length} successful');
    buffer.writeln('');
    buffer.writeln('Records:');
    buffer.writeln('  Fetched:  $totalRecordsFetched');
    buffer.writeln('  Inserted: $totalRecordsInserted');
    buffer.writeln('  Updated:  $totalRecordsUpdated');
    buffer.writeln('  Deleted:  $totalRecordsDeleted');
    buffer.writeln('  Skipped:  $totalRecordsSkipped');
    buffer.writeln('');
    buffer.writeln('Performance:');
    buffer.writeln('  API Requests: $totalApiRequests');
    buffer.writeln('  Data Received: ${_formatBytes(totalBytesReceived)}');
    buffer.writeln('  Speed: ${averageRecordsPerSecond.toStringAsFixed(1)} rec/s');

    if (slowestModel != null) {
      buffer.writeln('');
      buffer.writeln('Slowest Model: ${slowestModel!.model} '
          '(${slowestModel!.duration.inMilliseconds}ms)');
    }

    if (largestModel != null) {
      buffer.writeln('Largest Model: ${largestModel!.model} '
          '(${largestModel!.recordsFetched} records)');
    }

    if (failures.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('Failures:');
      for (final f in failures) {
        buffer.writeln('  - ${f.model}: ${f.errorMessage}');
      }
    }

    return buffer.toString();
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  @override
  String toString() => 'SyncSessionMetrics(${modelMetrics.length} models, '
      '$totalRecordsFetched records, ${duration.inMilliseconds}ms)';
}

/// Real-time sync metrics tracker for observing sync progress.
class SyncMetricsTracker {
  final _metricsSubject = ValueStream<SyncSessionMetrics?>(null);
  final _modelMetrics = <String, SyncOperationMetricsBuilder>{};
  DateTime? _sessionStart;

  /// Stream of current session metrics.
  Stream<SyncSessionMetrics?> get metricsStream => _metricsSubject.stream;

  /// Current session metrics.
  SyncSessionMetrics? get currentMetrics => _metricsSubject.valueOrNull;

  /// Start tracking a new sync session.
  void startSession() {
    _sessionStart = DateTime.now();
    _modelMetrics.clear();
    _emitCurrentState();
  }

  /// Start tracking a model within the session.
  SyncOperationMetricsBuilder startModel(String model) {
    final builder = SyncOperationMetricsBuilder(model);
    _modelMetrics[model] = builder;
    _emitCurrentState();
    return builder;
  }

  /// Complete tracking for a model.
  void completeModel(String model, {bool success = true}) {
    final builder = _modelMetrics[model];
    if (builder != null) {
      builder.build(success: success);
      _emitCurrentState();
    }
  }

  /// End the sync session and return final metrics.
  SyncSessionMetrics endSession() {
    final metrics = SyncSessionMetrics(
      modelMetrics: _modelMetrics.values
          .map((b) => b.build())
          .toList(),
      startTime: _sessionStart ?? DateTime.now(),
      endTime: DateTime.now(),
    );
    _metricsSubject.add(metrics);
    return metrics;
  }

  void _emitCurrentState() {
    if (_sessionStart == null) return;

    _metricsSubject.add(SyncSessionMetrics(
      modelMetrics: _modelMetrics.values
          .map((b) => b.build())
          .toList(),
      startTime: _sessionStart!,
      endTime: DateTime.now(),
    ));
  }

  /// Dispose resources.
  void dispose() {
    _metricsSubject.close();
  }
}
