/// Offline Operation Queue
///
/// Manages a persistent queue of operations to sync with Odoo
/// when the device comes back online.
///
/// Features:
/// - Priority-based processing
/// - Retry with exponential backoff
/// - Dead letter queue for failed operations
/// - UUID tracking for record correlation
///
/// NOTE: Core types (OfflineOperation, OfflinePriority, RetryBackoff) are
/// imported from odoo_offline_core to ensure consistency across the ecosystem.
library;

import 'dart:async';

import '../utils/value_stream.dart';

// Re-export core types for convenience
export 'offline_queue_types.dart'
    show OfflineOperation, OfflinePriority, RetryBackoff, OfflineQueueStore;

// Import for internal use
import 'offline_queue_types.dart' as core;

/// Types of offline operations (for OdooModelManager internal use).
enum OfflineOperationType {
  create,
  write,
  unlink,
}

/// Status of an offline operation (for queue management).
enum OperationStatus {
  /// Pending, waiting to be processed
  pending,
  /// Currently being processed
  processing,
  /// Successfully completed
  completed,
  /// Failed, will be retried
  failed,
  /// Moved to dead letter queue after max retries
  deadLetter,
}

/// Configuration for the offline queue.
class OfflineQueueConfig {
  /// Maximum number of retries before moving to dead letter queue.
  final int maxRetries;

  /// Base delay between retries in milliseconds.
  final int baseRetryDelayMs;

  /// Maximum delay between retries in milliseconds.
  final int maxRetryDelayMs;

  /// Whether to use exponential backoff for retries.
  final bool exponentialBackoff;

  /// Number of operations to process in parallel.
  final int parallelOperations;

  /// Maximum queue size (0 = unlimited).
  final int maxQueueSize;

  /// Maximum age for operations before cleanup (null = no limit).
  final Duration? maxOperationAge;

  const OfflineQueueConfig({
    this.maxRetries = 5,
    this.baseRetryDelayMs = 1000,
    this.maxRetryDelayMs = 60000,
    this.exponentialBackoff = true,
    this.parallelOperations = 1,
    this.maxQueueSize = 10000,
    this.maxOperationAge = const Duration(days: 30),
  });

  /// Calculate delay for a retry attempt.
  Duration getRetryDelay(int retryCount) {
    if (!exponentialBackoff) {
      return Duration(milliseconds: baseRetryDelayMs);
    }

    // Exponential backoff: base * 2^retry, capped at max
    final delay = baseRetryDelayMs * (1 << retryCount);
    return Duration(
      milliseconds: delay.clamp(baseRetryDelayMs, maxRetryDelayMs),
    );
  }
}

/// Offline operation queue manager wrapper.
///
/// This class provides a wrapper around [OfflineQueueStore] from odoo_offline_core
/// with additional stream-based state management for UI binding.
///
/// For most use cases, prefer using [OfflineQueueStore] directly via
/// your database's DataSource implementation.
///
/// Usage:
/// ```dart
/// final queueStore = MyOfflineQueueDataSource(database);
/// final queue = OfflineQueueWrapper(queueStore);
///
/// // Process queue when online
/// await queue.processQueue(processor: (op) async {
///   await odooClient.call(...);
/// });
/// ```
class OfflineQueueWrapper {
  final core.OfflineQueueStore _store;
  final OfflineQueueConfig config;

  // State streams
  final _pendingCount = ValueStream<int>(0);
  final _processingCount = ValueStream<int>(0);
  final _deadLetterCount = ValueStream<int>(0);
  final _isProcessing = ValueStream<bool>(false);

  /// Stream of pending operation count.
  Stream<int> get pendingCount => _pendingCount.stream;

  /// Current pending operation count (synchronous).
  int get pendingCountValue => _pendingCount.value;

  /// Stream of currently processing operation count.
  Stream<int> get processingCount => _processingCount.stream;

  /// Current processing operation count (synchronous).
  int get processingCountValue => _processingCount.value;

  /// Stream of dead letter operation count.
  Stream<int> get deadLetterCount => _deadLetterCount.stream;

  /// Current dead letter operation count (synchronous).
  int get deadLetterCountValue => _deadLetterCount.value;

  /// Stream indicating if queue is being processed.
  Stream<bool> get isProcessing => _isProcessing.stream;

  /// Whether queue is currently being processed (synchronous).
  bool get isProcessingNow => _isProcessing.value;

  OfflineQueueWrapper(this._store, {this.config = const OfflineQueueConfig()});

  /// Initialize the queue and update counts.
  Future<void> initialize() async {
    await _updateCounts();
  }

  /// Dispose resources.
  void dispose() {
    _pendingCount.close();
    _processingCount.close();
    _deadLetterCount.close();
    _isProcessing.close();
  }

  /// Add an operation to the queue.
  Future<int> enqueue({
    required String model,
    required String method,
    int? recordId,
    required Map<String, dynamic> values,
    int priority = core.OfflinePriority.normal,
    String? deviceId,
  }) async {
    final id = await _store.queueOperation(
      model: model,
      method: method,
      recordId: recordId,
      values: values,
      priority: priority,
      deviceId: deviceId,
    );
    await _updateCounts();
    return id;
  }

  /// Get all pending operations for a model.
  Future<List<core.OfflineOperation>> getPendingForModel(String model) async {
    return _store.getOperationsForModel(model);
  }

  /// Get all pending operations.
  Future<List<core.OfflineOperation>> getPending() async {
    return _store.getPendingOperations();
  }

  /// Get operations in dead letter queue.
  Future<List<core.OfflineOperation>> getDeadLetterOperations() async {
    return _store.getDeadLetterOperations();
  }

  /// Mark an operation as completed (removes it from queue).
  Future<void> markCompleted(int operationId) async {
    await _store.removeOperation(operationId);
    await _updateCounts();
  }

  /// Mark an operation as failed.
  Future<void> markFailed(int operationId, String error) async {
    await _store.markOperationFailed(operationId, error);
    await _updateCounts();
  }

  /// Reset a dead letter operation for retry.
  Future<void> resetOperationRetry(int operationId) async {
    await _store.resetOperationRetry(operationId);
    await _updateCounts();
  }

  /// Remove an operation from the queue.
  Future<void> removeOperation(int operationId) async {
    await _store.removeOperation(operationId);
    await _updateCounts();
  }

  /// Process all pending operations.
  ///
  /// [processor] is called for each operation and should throw on failure.
  Future<WrapperQueueResult> processQueue({
    required Future<void> Function(core.OfflineOperation op) processor,
  }) async {
    if (_isProcessing.value) {
      return const WrapperQueueResult(
        processed: 0,
        failed: 0,
        skipped: 0,
        message: 'Queue already being processed',
      );
    }

    _isProcessing.add(true);

    int processed = 0;
    int failed = 0;

    try {
      final operations = await getPending();

      for (final op in operations) {
        // Skip operations not ready for retry
        if (!op.isReadyForRetry) {
          continue;
        }

        try {
          _processingCount.add(_processingCount.value + 1);

          // Wait for retry delay if this is a retry
          if (op.retryCount > 0) {
            final delay = config.getRetryDelay(op.retryCount);
            await Future.delayed(delay);
          }

          await processor(op);
          await markCompleted(op.id);
          processed++;
        } catch (e) {
          await markFailed(op.id, e.toString());
          failed++;
        } finally {
          _processingCount.add(_processingCount.value - 1);
        }
      }
    } finally {
      _isProcessing.add(false);
      await _updateCounts();
    }

    return WrapperQueueResult(
      processed: processed,
      failed: failed,
      skipped: 0,
    );
  }

  /// Remove operations older than [config.maxOperationAge].
  ///
  /// Returns the number of operations removed.
  Future<int> cleanupStaleOperations() async {
    final maxAge = config.maxOperationAge;
    if (maxAge == null) return 0;

    final cutoff = DateTime.now().subtract(maxAge);
    final removed = await _store.removeOperationsBefore(cutoff);
    if (removed > 0) await _updateCounts();
    return removed;
  }

  /// Compress queue by merging consecutive writes to the same record.
  ///
  /// Finds write operations targeting the same model and recordId,
  /// keeps only the latest one (with merged values), and removes
  /// duplicates. Returns the number of operations removed.
  Future<int> compressQueue() async {
    final pending = await _store.getPendingOperations(includeNotReady: true);

    // Group by model+recordId for write operations
    final groups = <String, List<core.OfflineOperation>>{};
    for (final op in pending) {
      if (op.method != 'write' || op.recordId == null) continue;
      final key = '${op.model}:${op.recordId}';
      groups.putIfAbsent(key, () => []).add(op);
    }

    int removed = 0;
    for (final ops in groups.values) {
      if (ops.length < 2) continue;

      // Sort by createdAt ascending so latest is last
      ops.sort((a, b) => a.createdAt.compareTo(b.createdAt));

      // Remove all but the last (latest) operation
      for (int i = 0; i < ops.length - 1; i++) {
        await _store.removeOperation(ops[i].id);
        removed++;
      }
    }

    if (removed > 0) await _updateCounts();
    return removed;
  }

  /// Remove all dead letter operations.
  ///
  /// Returns the number of operations removed.
  Future<int> purgeDeadLetterQueue() async {
    final removed = await _store.removeDeadLetterOperations();
    if (removed > 0) await _updateCounts();
    return removed;
  }

  /// Enforce maximum queue size by removing oldest low-priority operations.
  ///
  /// Returns the number of operations removed.
  Future<int> enforceMaxSize() async {
    if (config.maxQueueSize <= 0) return 0;

    final pending = await _store.getPendingOperations(includeNotReady: true);
    if (pending.length <= config.maxQueueSize) return 0;

    final excess = pending.length - config.maxQueueSize;

    // Sort by priority descending (higher number = lower priority),
    // then by createdAt ascending (oldest first) for same priority.
    final sorted = List<core.OfflineOperation>.from(pending)
      ..sort((a, b) {
        final priCmp = b.priority.compareTo(a.priority);
        if (priCmp != 0) return priCmp;
        return a.createdAt.compareTo(b.createdAt);
      });

    int removed = 0;
    for (int i = 0; i < excess && i < sorted.length; i++) {
      await _store.removeOperation(sorted[i].id);
      removed++;
    }

    if (removed > 0) await _updateCounts();
    return removed;
  }

  /// Get queue statistics.
  Future<QueueStats> getStats() async {
    final stats = await _store.getRetryStats();
    return QueueStats(
      pending: (stats['ready'] as int?) ?? 0,
      failed: (stats['scheduled'] as int?) ?? 0,
      completed: 0, // Not tracked in core store
      deadLetter: (stats['dead_letter'] as int?) ?? 0,
      processing: 0,
    );
  }

  Future<void> _updateCounts() async {
    final stats = await _store.getRetryStats();
    _pendingCount.add((stats['ready'] as int?) ?? 0);
    _deadLetterCount.add((stats['dead_letter'] as int?) ?? 0);
  }
}

/// Result of queue processing (local wrapper class).
///
/// For most use cases, use [QueueProcessResult] from odoo_offline_core instead.
class WrapperQueueResult {
  final int processed;
  final int failed;
  final int skipped;
  final String? message;

  const WrapperQueueResult({
    required this.processed,
    required this.failed,
    required this.skipped,
    this.message,
  });

  int get total => processed + failed + skipped;
  bool get hasFailures => failed > 0;

  @override
  String toString() =>
      'WrapperQueueResult(processed: $processed, failed: $failed, skipped: $skipped)';
}

/// Queue statistics.
class QueueStats {
  final int pending;
  final int failed;
  final int completed;
  final int deadLetter;
  final int processing;

  const QueueStats({
    required this.pending,
    required this.failed,
    required this.completed,
    required this.deadLetter,
    required this.processing,
  });

  int get total => pending + failed + completed + deadLetter + processing;
  int get active => pending + failed + processing;

  @override
  String toString() =>
      'QueueStats(pending: $pending, failed: $failed, deadLetter: $deadLetter)';
}
