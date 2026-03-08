/// DataSyncOrchestrator — multi-context sync coordination.
///
/// Orchestrates sync across multiple [DataContext] instances, supporting
/// sequential or parallel execution strategies.
library;

import 'package:meta/meta.dart';
import '../model/odoo_model_manager.dart';
import 'sync_types.dart';

import '../facade/odoo_data_layer.dart';

/// Configuration for a multi-context sync run.
@immutable
class MultiContextSyncConfig {
  /// Which context IDs to sync. If null/empty, syncs all.
  final List<String>? contextIds;

  /// Maximum number of contexts to sync in parallel.
  /// Set to 1 for sequential execution.
  final int parallelContexts;

  /// Maximum concurrent model syncs within each context.
  final int maxConcurrentPerContext;

  const MultiContextSyncConfig({
    this.contextIds,
    this.parallelContexts = 1,
    this.maxConcurrentPerContext = 1,
  });

  /// Sync all contexts sequentially.
  const MultiContextSyncConfig.sequential()
      : contextIds = null,
        parallelContexts = 1,
        maxConcurrentPerContext = 1;

  /// Sync all contexts in parallel (up to [maxParallel]).
  const MultiContextSyncConfig.parallel({int maxParallel = 3})
      : contextIds = null,
        parallelContexts = maxParallel,
        maxConcurrentPerContext = 1;
}

/// Result of a multi-context sync run.
@immutable
class MultiContextSyncResult {
  /// Per-context sync reports.
  final Map<String, SyncReport> reports;

  /// When the sync started.
  final DateTime startTime;

  /// When the sync ended.
  final DateTime endTime;

  const MultiContextSyncResult({
    required this.reports,
    required this.startTime,
    required this.endTime,
  });

  /// True if every context synced without errors.
  bool get allSuccessful =>
      reports.values.every((r) => r.allSuccess);

  /// Total sync duration.
  Duration get duration => endTime.difference(startTime);

  /// Context IDs that had errors.
  Iterable<String> get failedContexts =>
      reports.entries.where((e) => e.value.hasErrors).map((e) => e.key);
}

/// Orchestrates sync across multiple [DataContext] instances.
class DataSyncOrchestrator {
  final OdooDataLayer _layer;

  DataSyncOrchestrator(this._layer);

  /// Run a multi-context sync.
  ///
  /// Respects [config.parallelContexts] for parallelism control.
  Future<MultiContextSyncResult> syncAll({
    MultiContextSyncConfig config = const MultiContextSyncConfig.sequential(),
    CancellationToken? cancellation,
  }) async {
    final startTime = DateTime.now();
    final reports = <String, SyncReport>{};

    // Determine which contexts to sync
    final ids = config.contextIds ?? _layer.contextIds.toList();
    final validIds = ids.where((id) => _layer.getContext(id) != null).toList();

    if (config.parallelContexts <= 1) {
      // Sequential
      for (final id in validIds) {
        if (cancellation?.isCancelled ?? false) break;
        final ctx = _layer.getContext(id)!;
        try {
          reports[id] = await ctx.syncAll(cancellation: cancellation);
        } catch (e) {
          reports[id] = SyncReport(
            results: [SyncResult.error(model: '*', error: e.toString())],
            startTime: DateTime.now(),
            endTime: DateTime.now(),
          );
        }
      }
    } else {
      // Parallel with concurrency limit
      final pending = List.of(validIds);
      while (pending.isNotEmpty) {
        if (cancellation?.isCancelled ?? false) break;

        final batch = pending.take(config.parallelContexts).toList();
        pending.removeRange(0, batch.length);

        final futures = batch.map((id) async {
          final ctx = _layer.getContext(id)!;
          try {
            return MapEntry(id, await ctx.syncAll(cancellation: cancellation));
          } catch (e) {
            return MapEntry(
              id,
              SyncReport(
                results: [SyncResult.error(model: '*', error: e.toString())],
                startTime: DateTime.now(),
                endTime: DateTime.now(),
              ),
            );
          }
        });

        final results = await Future.wait(futures);
        for (final entry in results) {
          reports[entry.key] = entry.value;
        }
      }
    }

    return MultiContextSyncResult(
      reports: reports,
      startTime: startTime,
      endTime: DateTime.now(),
    );
  }
}
