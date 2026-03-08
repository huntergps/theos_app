/// Sync Metrics Collector
///
/// Provides observability for sync operations including:
/// - Average sync time per model
/// - Conflict rate per model
/// - Success/failure rates
/// - Records synced per session
library;

import 'sync_metrics_persistence.dart';
import 'sync_types.dart';

/// A single sync operation metric.
class SyncOperationMetric {
  /// Model that was synced.
  final String model;

  /// When the sync started.
  final DateTime startTime;

  /// When the sync completed.
  final DateTime endTime;

  /// Final status of the sync.
  final SyncStatus status;

  /// Number of records synced.
  final int recordsSynced;

  /// Number of records that failed.
  final int recordsFailed;

  /// Number of conflicts detected.
  final int conflictsDetected;

  /// Error message if any.
  final String? error;

  const SyncOperationMetric({
    required this.model,
    required this.startTime,
    required this.endTime,
    required this.status,
    this.recordsSynced = 0,
    this.recordsFailed = 0,
    this.conflictsDetected = 0,
    this.error,
  });

  /// Duration of the sync operation.
  Duration get duration => endTime.difference(startTime);

  /// Duration in milliseconds.
  int get durationMs => duration.inMilliseconds;

  /// Whether the sync was successful.
  bool get isSuccess => status == SyncStatus.success || status == SyncStatus.partial;

  /// Total records processed.
  int get totalRecords => recordsSynced + recordsFailed;

  /// Create from a SyncResult.
  factory SyncOperationMetric.fromResult(
    SyncResult result, {
    required DateTime startTime,
  }) {
    return SyncOperationMetric(
      model: result.model,
      startTime: startTime,
      endTime: result.timestamp,
      status: result.status,
      recordsSynced: result.synced,
      recordsFailed: result.failed,
      conflictsDetected: result.conflicts.length,
      error: result.error,
    );
  }

  /// Serialize to JSON map.
  Map<String, dynamic> toJson() => {
        'model': model,
        'startTime': startTime.toIso8601String(),
        'endTime': endTime.toIso8601String(),
        'status': status.name,
        'recordsSynced': recordsSynced,
        'recordsFailed': recordsFailed,
        'conflictsDetected': conflictsDetected,
        if (error != null) 'error': error,
      };

  /// Deserialize from JSON map.
  factory SyncOperationMetric.fromJson(Map<String, dynamic> json) {
    return SyncOperationMetric(
      model: json['model'] as String,
      startTime: DateTime.parse(json['startTime'] as String),
      endTime: DateTime.parse(json['endTime'] as String),
      status: SyncStatus.values.byName(json['status'] as String),
      recordsSynced: json['recordsSynced'] as int? ?? 0,
      recordsFailed: json['recordsFailed'] as int? ?? 0,
      conflictsDetected: json['conflictsDetected'] as int? ?? 0,
      error: json['error'] as String?,
    );
  }

  @override
  String toString() =>
      'SyncMetric($model: ${durationMs}ms, synced: $recordsSynced, '
      'failed: $recordsFailed, conflicts: $conflictsDetected)';
}

/// Aggregated metrics for a specific model.
class ModelSyncMetrics {
  /// Model name.
  final String model;

  /// Total sync operations.
  final int totalOperations;

  /// Successful sync operations.
  final int successfulOperations;

  /// Failed sync operations.
  final int failedOperations;

  /// Total records synced.
  final int totalRecordsSynced;

  /// Total records failed.
  final int totalRecordsFailed;

  /// Total conflicts detected.
  final int totalConflicts;

  /// Average sync duration in milliseconds.
  final double averageDurationMs;

  /// Minimum sync duration in milliseconds.
  final int minDurationMs;

  /// Maximum sync duration in milliseconds.
  final int maxDurationMs;

  /// P50 (median) sync duration in milliseconds.
  final double p50DurationMs;

  /// P95 sync duration in milliseconds.
  final double p95DurationMs;

  /// P99 sync duration in milliseconds.
  final double p99DurationMs;

  /// Time window start.
  final DateTime windowStart;

  /// Time window end.
  final DateTime windowEnd;

  const ModelSyncMetrics({
    required this.model,
    required this.totalOperations,
    required this.successfulOperations,
    required this.failedOperations,
    required this.totalRecordsSynced,
    required this.totalRecordsFailed,
    required this.totalConflicts,
    required this.averageDurationMs,
    required this.minDurationMs,
    required this.maxDurationMs,
    required this.p50DurationMs,
    required this.p95DurationMs,
    required this.p99DurationMs,
    required this.windowStart,
    required this.windowEnd,
  });

  /// Success rate as percentage (0-100).
  double get successRate =>
      totalOperations > 0 ? (successfulOperations / totalOperations) * 100 : 0;

  /// Failure rate as percentage (0-100).
  double get failureRate =>
      totalOperations > 0 ? (failedOperations / totalOperations) * 100 : 0;

  /// Conflict rate as percentage of total records (0-100).
  double get conflictRate {
    final total = totalRecordsSynced + totalRecordsFailed + totalConflicts;
    return total > 0 ? (totalConflicts / total) * 100 : 0;
  }

  /// Average records per sync.
  double get averageRecordsPerSync =>
      totalOperations > 0 ? totalRecordsSynced / totalOperations : 0;

  @override
  String toString() =>
      'ModelSyncMetrics($model: ops=$totalOperations, success=${successRate.toStringAsFixed(1)}%, '
      'conflicts=${conflictRate.toStringAsFixed(1)}%, avgTime=${averageDurationMs.toStringAsFixed(0)}ms)';
}

/// Global sync metrics summary.
class GlobalSyncMetrics {
  /// Metrics per model.
  final Map<String, ModelSyncMetrics> byModel;

  /// Total sync operations across all models.
  final int totalOperations;

  /// Total records synced across all models.
  final int totalRecordsSynced;

  /// Total conflicts across all models.
  final int totalConflicts;

  /// Overall success rate.
  final double overallSuccessRate;

  /// Overall conflict rate.
  final double overallConflictRate;

  /// Average sync duration across all models.
  final double averageDurationMs;

  /// Time window.
  final DateTime windowStart;
  final DateTime windowEnd;

  const GlobalSyncMetrics({
    required this.byModel,
    required this.totalOperations,
    required this.totalRecordsSynced,
    required this.totalConflicts,
    required this.overallSuccessRate,
    required this.overallConflictRate,
    required this.averageDurationMs,
    required this.windowStart,
    required this.windowEnd,
  });

  /// Get metrics for a specific model.
  ModelSyncMetrics? operator [](String model) => byModel[model];

  /// List of all models with metrics.
  List<String> get models => byModel.keys.toList();

  /// Models sorted by conflict rate (highest first).
  List<ModelSyncMetrics> get modelsByConflictRate {
    final list = byModel.values.toList();
    list.sort((a, b) => b.conflictRate.compareTo(a.conflictRate));
    return list;
  }

  /// Models sorted by average duration (slowest first).
  List<ModelSyncMetrics> get modelsByDuration {
    final list = byModel.values.toList();
    list.sort((a, b) => b.averageDurationMs.compareTo(a.averageDurationMs));
    return list;
  }

  @override
  String toString() =>
      'GlobalSyncMetrics(models: ${byModel.length}, ops: $totalOperations, '
      'success: ${overallSuccessRate.toStringAsFixed(1)}%, '
      'conflicts: ${overallConflictRate.toStringAsFixed(1)}%)';
}

/// Callback type for sync metric events.
typedef SyncMetricCallback = void Function(SyncOperationMetric metric);

/// Collector for sync operation metrics.
///
/// Usage:
/// ```dart
/// final collector = SyncMetricsCollector();
///
/// // Record a sync operation
/// final startTime = DateTime.now();
/// final result = await syncModel('sale.order');
/// collector.recordFromResult(result, startTime: startTime);
///
/// // Or use the timing helper
/// final result = await collector.timed('sale.order', () async {
///   return await syncModel('sale.order');
/// });
///
/// // Get metrics
/// final metrics = collector.getModelMetrics('sale.order');
/// print('Avg sync time: ${metrics.averageDurationMs}ms');
/// print('Conflict rate: ${metrics.conflictRate}%');
///
/// // Listen to metrics
/// collector.addCallback((metric) {
///   print('Sync completed: ${metric.model} in ${metric.durationMs}ms');
/// });
/// ```
class SyncMetricsCollector {
  final List<SyncOperationMetric> _metrics = [];
  final int _maxMetrics;
  final List<SyncMetricCallback> _callbacks = [];

  /// Track active sync operations for timing.
  final Map<String, DateTime> _activeOperations = {};

  /// Optional persistence layer.
  final SyncMetricsPersistence? _persistence;

  SyncMetricsCollector({
    int maxMetrics = 1000,
    SyncMetricsPersistence? persistence,
  })  : _maxMetrics = maxMetrics,
        _persistence = persistence;

  /// Whether persistence is configured.
  bool get hasPersistence => _persistence != null;

  /// Add a callback to be notified of new metrics.
  void addCallback(SyncMetricCallback callback) {
    _callbacks.add(callback);
  }

  /// Remove a callback.
  void removeCallback(SyncMetricCallback callback) {
    _callbacks.remove(callback);
  }

  /// Start timing a sync operation.
  void startOperation(String model) {
    _activeOperations[model] = DateTime.now();
  }

  /// End timing and record a sync operation.
  void endOperation(String model, SyncResult result) {
    final startTime = _activeOperations.remove(model);
    if (startTime != null) {
      recordFromResult(result, startTime: startTime);
    }
  }

  /// Record a metric from a SyncResult.
  void recordFromResult(SyncResult result, {required DateTime startTime}) {
    final metric = SyncOperationMetric.fromResult(result, startTime: startTime);
    record(metric);
  }

  /// Record a sync operation metric.
  void record(SyncOperationMetric metric) {
    _metrics.add(metric);

    // Trim old metrics if we exceed the limit
    while (_metrics.length > _maxMetrics) {
      _metrics.removeAt(0);
    }

    // Write-through to persistence (fire-and-forget)
    _persistence?.saveMetric(metric);

    // Notify callbacks
    for (final callback in _callbacks) {
      callback(metric);
    }
  }

  /// Execute a sync operation and automatically record its metrics.
  ///
  /// Example:
  /// ```dart
  /// final result = await collector.timed('sale.order', () async {
  ///   return await mySync.syncModel('sale.order');
  /// });
  /// ```
  Future<SyncResult> timed(
    String model,
    Future<SyncResult> Function() operation,
  ) async {
    final startTime = DateTime.now();
    try {
      final result = await operation();
      recordFromResult(result, startTime: startTime);
      return result;
    } catch (e) {
      // Record error as a failed sync
      final errorResult = SyncResult.error(model: model, error: e.toString());
      recordFromResult(errorResult, startTime: startTime);
      rethrow;
    }
  }

  /// Get all recorded metrics.
  List<SyncOperationMetric> get metrics => List.unmodifiable(_metrics);

  /// Get metrics for a specific model.
  List<SyncOperationMetric> metricsForModel(String model) {
    return _metrics.where((m) => m.model == model).toList();
  }

  /// Get metrics within a time window (inclusive).
  List<SyncOperationMetric> metricsInWindow(DateTime start, DateTime end) {
    return _metrics
        .where((m) =>
            !m.startTime.isBefore(start) && !m.startTime.isAfter(end))
        .toList();
  }

  /// Get aggregated metrics for a specific model.
  ModelSyncMetrics? getModelMetrics(String model, {Duration? window}) {
    final windowEnd = DateTime.now();
    final windowStart = window != null
        ? windowEnd.subtract(window)
        : _metrics.isNotEmpty
            ? _metrics.map((m) => m.startTime).reduce((a, b) => a.isBefore(b) ? a : b)
            : windowEnd;

    final modelMetrics = _metrics
        .where((m) =>
            m.model == model &&
            !m.startTime.isBefore(windowStart) &&
            !m.startTime.isAfter(windowEnd))
        .toList();

    if (modelMetrics.isEmpty) return null;

    return _aggregateMetrics(model, modelMetrics, windowStart, windowEnd);
  }

  /// Get global metrics across all models.
  GlobalSyncMetrics getGlobalMetrics({Duration? window}) {
    final windowEnd = DateTime.now();
    final windowStart = window != null
        ? windowEnd.subtract(window)
        : _metrics.isNotEmpty
            ? _metrics.map((m) => m.startTime).reduce((a, b) => a.isBefore(b) ? a : b)
            : windowEnd;

    final windowMetrics = metricsInWindow(windowStart, windowEnd);

    if (windowMetrics.isEmpty) {
      return GlobalSyncMetrics(
        byModel: const {},
        totalOperations: 0,
        totalRecordsSynced: 0,
        totalConflicts: 0,
        overallSuccessRate: 0,
        overallConflictRate: 0,
        averageDurationMs: 0,
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
    }

    // Group by model
    final byModel = <String, List<SyncOperationMetric>>{};
    for (final m in windowMetrics) {
      byModel.putIfAbsent(m.model, () => []).add(m);
    }

    // Aggregate per model
    final modelMetrics = <String, ModelSyncMetrics>{};
    for (final entry in byModel.entries) {
      modelMetrics[entry.key] = _aggregateMetrics(
        entry.key,
        entry.value,
        windowStart,
        windowEnd,
      );
    }

    // Calculate global stats
    final totalOps = windowMetrics.length;
    final successfulOps = windowMetrics.where((m) => m.isSuccess).length;
    final totalSynced = windowMetrics.fold(0, (sum, m) => sum + m.recordsSynced);
    final totalConflicts =
        windowMetrics.fold(0, (sum, m) => sum + m.conflictsDetected);
    final totalRecords = windowMetrics.fold(
      0,
      (sum, m) => sum + m.totalRecords + m.conflictsDetected,
    );
    final avgDuration = windowMetrics.isNotEmpty
        ? windowMetrics.fold(0, (sum, m) => sum + m.durationMs) /
            windowMetrics.length
        : 0.0;

    return GlobalSyncMetrics(
      byModel: modelMetrics,
      totalOperations: totalOps,
      totalRecordsSynced: totalSynced,
      totalConflicts: totalConflicts,
      overallSuccessRate: totalOps > 0 ? (successfulOps / totalOps) * 100 : 0,
      overallConflictRate:
          totalRecords > 0 ? (totalConflicts / totalRecords) * 100 : 0,
      averageDurationMs: avgDuration,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
  }

  /// Clear all recorded metrics.
  ///
  /// If [clearPersistence] is true, also clears persisted metrics.
  /// Defaults to false for backward compatibility.
  void clear({bool clearPersistence = false}) {
    _metrics.clear();
    _activeOperations.clear();
    if (clearPersistence) {
      _persistence?.clearMetrics();
    }
  }

  /// Load metrics from persistence into memory.
  ///
  /// Call this during initialization to restore previous metrics.
  /// Only loads metrics that fit within [_maxMetrics].
  /// Returns the number of metrics loaded from persistence.
  Future<int> loadFromPersistence({DateTime? since}) async {
    final persistence = _persistence;
    if (persistence == null) return 0;

    final persisted = await persistence.loadMetrics(since: since);

    // Add to in-memory list, respecting max limit
    for (final metric in persisted) {
      _metrics.add(metric);
    }

    // Trim to max
    while (_metrics.length > _maxMetrics) {
      _metrics.removeAt(0);
    }

    return persisted.length;
  }

  ModelSyncMetrics _aggregateMetrics(
    String model,
    List<SyncOperationMetric> metrics,
    DateTime windowStart,
    DateTime windowEnd,
  ) {
    final successful = metrics.where((m) => m.isSuccess).length;
    final failed = metrics.length - successful;
    final totalSynced = metrics.fold(0, (sum, m) => sum + m.recordsSynced);
    final totalFailed = metrics.fold(0, (sum, m) => sum + m.recordsFailed);
    final totalConflicts =
        metrics.fold(0, (sum, m) => sum + m.conflictsDetected);

    // Calculate duration percentiles
    final durations = metrics.map((m) => m.durationMs).toList()..sort();
    final avgDuration =
        durations.isNotEmpty ? durations.reduce((a, b) => a + b) / durations.length : 0.0;

    return ModelSyncMetrics(
      model: model,
      totalOperations: metrics.length,
      successfulOperations: successful,
      failedOperations: failed,
      totalRecordsSynced: totalSynced,
      totalRecordsFailed: totalFailed,
      totalConflicts: totalConflicts,
      averageDurationMs: avgDuration,
      minDurationMs: durations.isNotEmpty ? durations.first : 0,
      maxDurationMs: durations.isNotEmpty ? durations.last : 0,
      p50DurationMs: _percentile(durations, 50),
      p95DurationMs: _percentile(durations, 95),
      p99DurationMs: _percentile(durations, 99),
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
  }

  /// Calculates the given percentile from a sorted list of durations.
  ///
  /// Returns 0 if the list is empty. The [percentile] should be
  /// between 0 and 100 (e.g., 95 for p95 latency).
  double _percentile(List<int> sorted, int percentile) {
    if (sorted.isEmpty) return 0;
    final index = (percentile / 100 * (sorted.length - 1)).round();
    return sorted[index].toDouble();
  }
}
