/// Abstract interface for persisting sync metrics.
///
/// Applications should implement this using their preferred storage:
/// - Drift (SQLite) for structured queries
/// - SharedPreferences/JSON file for simple storage
/// - Remote analytics service for centralized monitoring
///
/// The SDK provides the interface; the app provides the implementation.
///
/// Example (JSON file implementation):
/// ```dart
/// class JsonFileMetricsPersistence implements SyncMetricsPersistence {
///   final File _file;
///   JsonFileMetricsPersistence(this._file);
///
///   @override
///   Future<void> saveMetric(SyncOperationMetric metric) async {
///     final metrics = await loadMetrics();
///     metrics.add(metric);
///     await _file.writeAsString(jsonEncode(metrics.map((m) => m.toJson()).toList()));
///   }
///
///   @override
///   Future<List<SyncOperationMetric>> loadMetrics({DateTime? since}) async {
///     if (!await _file.exists()) return [];
///     final json = jsonDecode(await _file.readAsString()) as List;
///     var metrics = json.map((j) => SyncOperationMetric.fromJson(j)).toList();
///     if (since != null) {
///       metrics = metrics.where((m) => !m.startTime.isBefore(since)).toList();
///     }
///     return metrics;
///   }
///
///   @override
///   Future<void> clearMetrics({DateTime? before}) async {
///     if (before == null) {
///       await _file.writeAsString('[]');
///     } else {
///       final metrics = await loadMetrics();
///       final remaining = metrics.where((m) => !m.startTime.isBefore(before)).toList();
///       await _file.writeAsString(jsonEncode(remaining.map((m) => m.toJson()).toList()));
///     }
///   }
///
///   @override
///   Future<int> metricsCount() async {
///     final metrics = await loadMetrics();
///     return metrics.length;
///   }
/// }
/// ```
library;

import 'sync_metrics.dart';

/// Abstract interface for persisting sync metrics.
///
/// Implement this class to provide durable storage for [SyncOperationMetric]
/// instances across app restarts.
abstract class SyncMetricsPersistence {
  /// Save a single metric.
  Future<void> saveMetric(SyncOperationMetric metric);

  /// Save multiple metrics at once (batch).
  ///
  /// Default implementation calls [saveMetric] for each metric.
  /// Override for more efficient batch operations.
  Future<void> saveMetrics(List<SyncOperationMetric> metrics) async {
    for (final metric in metrics) {
      await saveMetric(metric);
    }
  }

  /// Load persisted metrics, optionally filtered by start time.
  ///
  /// If [since] is provided, only metrics with `startTime >= since` are returned.
  Future<List<SyncOperationMetric>> loadMetrics({DateTime? since});

  /// Clear persisted metrics, optionally only those before a date.
  ///
  /// If [before] is null, all metrics are cleared.
  /// If [before] is provided, only metrics with `startTime < before` are removed.
  Future<void> clearMetrics({DateTime? before});

  /// Get count of persisted metrics.
  Future<int> metricsCount();
}
