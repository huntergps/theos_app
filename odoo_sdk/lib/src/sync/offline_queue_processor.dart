/// Offline Queue Processor (Generic)
///
/// Orchestrates processing of queued offline operations with progress
/// events, retry backoff, and optional audit logging.
library;

import 'dart:async';

import 'offline_queue_types.dart';
import 'sync_types.dart';

/// Result of a processed operation.
class OfflineOperationResult {
  final SyncOperationStatus status;
  final ConflictInfo? conflict;
  final int? odooId;
  final String? errorMessage;

  const OfflineOperationResult({
    required this.status,
    this.conflict,
    this.odooId,
    this.errorMessage,
  });

  const OfflineOperationResult.success({int? odooId})
      : this(
          status: SyncOperationStatus.success,
          odooId: odooId,
        );

  const OfflineOperationResult.conflict(ConflictInfo conflict)
      : this(
          status: SyncOperationStatus.conflict,
          conflict: conflict,
        );

  const OfflineOperationResult.skipped({String? errorMessage})
      : this(
          status: SyncOperationStatus.skipped,
          errorMessage: errorMessage,
        );
}

/// Handler for processing a single offline operation.
typedef OfflineOperationHandler =
    Future<ConflictInfo?> Function(OfflineOperation op);

/// Audit logger for sync operations.
abstract class OfflineQueueAuditLogger {
  Future<void> logOperation(
    OfflineOperation op, {
    required String result, // success, conflict, skipped, error
    int? odooId,
    String? errorMessage,
  });
}

/// Processor for offline queue operations.
///
/// Orchestrates the processing of queued offline operations with support for
/// progress tracking, conflict detection, retry management, and optional
/// audit logging.
///
/// ## Usage
///
/// ```dart
/// final processor = OfflineQueueProcessor(
///   queue: myQueueStore,
///   handler: (op) async {
///     // Process operation with Odoo
///     await odooClient.call(model: op.model, method: op.method, ...);
///     return null; // No conflict
///   },
///   auditLogger: myAuditLogger,
/// );
///
/// // Listen to progress
/// processor.progressStream.listen((event) {
///   print('Progress: ${event.current}/${event.total}');
/// });
///
/// // Process queue
/// final result = await processor.processQueue();
/// print('Synced: ${result.synced}, Failed: ${result.failed}');
///
/// // Cleanup
/// processor.dispose();
/// ```
class OfflineQueueProcessor {
  final OfflineQueueStore _queue;
  final OfflineOperationHandler _handler;
  final OfflineQueueAuditLogger? _auditLogger;
  final bool _removeOnSuccess;
  final bool _removeOnConflict;
  final bool _removeOnSkipped;

  final _progressController =
      StreamController<SyncProgressEvent>.broadcast();

  /// Creates a new [OfflineQueueProcessor].
  ///
  /// [queue] The queue store to read pending operations from.
  /// [handler] Function to process each operation. Returns [ConflictInfo] if
  ///   a conflict is detected, or null on success.
  /// [auditLogger] Optional logger for recording sync results.
  /// [removeOnSuccess] Whether to remove operations after successful sync.
  ///   Defaults to true.
  /// [removeOnConflict] Whether to remove operations that result in conflicts.
  ///   Defaults to false (keeps them for manual resolution).
  /// [removeOnSkipped] Whether to remove skipped operations.
  ///   Defaults to false.
  OfflineQueueProcessor({
    required OfflineQueueStore queue,
    required OfflineOperationHandler handler,
    OfflineQueueAuditLogger? auditLogger,
    bool removeOnSuccess = true,
    bool removeOnConflict = false,
    bool removeOnSkipped = false,
  })  : _queue = queue,
        _handler = handler,
        _auditLogger = auditLogger,
        _removeOnSuccess = removeOnSuccess,
        _removeOnConflict = removeOnConflict,
        _removeOnSkipped = removeOnSkipped;

  /// Stream of progress events emitted during queue processing.
  ///
  /// Each [SyncProgressEvent] contains the current operation index, total count,
  /// and status. Subscribe before calling [processQueue] to receive all events.
  Stream<SyncProgressEvent> get progressStream => _progressController.stream;

  /// Releases resources used by this processor.
  ///
  /// Closes the [progressStream]. After calling dispose, this processor
  /// should not be used again.
  void dispose() {
    _progressController.close();
  }

  /// Processes all pending operations in the queue.
  ///
  /// Iterates through each pending operation, calls the [handler] to process it,
  /// and emits progress events. Operations are removed from the queue based on
  /// the configured removal policies.
  ///
  /// [operations] Optional list of operations to process. If null, fetches
  ///   pending operations from the queue store.
  ///
  /// Returns a [QueueProcessResult] with counts of synced, failed, skipped
  /// operations, any errors, and detected conflicts.
  Future<QueueProcessResult> processQueue({
    List<OfflineOperation>? operations,
  }) async {
    final ops = operations ?? await _queue.getPendingOperations();
    if (ops.isEmpty) {
      return QueueProcessResult.empty;
    }

    // Sort operations by dependency order:
    // 1. Priority (lower value = higher priority: critical=0, high=1, normal=2, low=3)
    // 2. Parents before children (parentOrderId == null first)
    // 3. Creates before writes before deletes
    // 4. FIFO within same group (by createdAt)
    ops.sort((a, b) {
      // 1. Priority
      final priorityCompare = a.priority.compareTo(b.priority);
      if (priorityCompare != 0) return priorityCompare;

      // 2. Parents first
      final aIsParent = a.parentOrderId == null ? 0 : 1;
      final bIsParent = b.parentOrderId == null ? 0 : 1;
      final parentCompare = aIsParent.compareTo(bIsParent);
      if (parentCompare != 0) return parentCompare;

      // 3. Operation order: create < write < unlink
      final methodOrder = _methodSortOrder(a.method)
          .compareTo(_methodSortOrder(b.method));
      if (methodOrder != 0) return methodOrder;

      // 4. FIFO
      return a.createdAt.compareTo(b.createdAt);
    });

    int success = 0;
    int failed = 0;
    int skipped = 0;
    final errors = <String>[];
    final conflicts = <ConflictInfo>[];

    final totalOps = ops.length;
    var currentIndex = 0;

    for (final op in ops) {
      currentIndex++;

      _progressController.add(
        SyncProgressEvent(
          operationId: op.id,
          current: currentIndex,
          total: totalOps,
          status: SyncOperationStatus.processing,
        ),
      );

      try {
        final conflict = await _handler(op);
        if (conflict != null) {
          conflicts.add(conflict);
          await _auditLogger?.logOperation(
            op,
            result: 'conflict',
          );
          if (_removeOnConflict) {
            await _queue.removeOperation(op.id);
          }
          _progressController.add(
            SyncProgressEvent(
              operationId: op.id,
              current: currentIndex,
              total: totalOps,
              status: SyncOperationStatus.conflict,
            ),
          );
        } else {
          await _auditLogger?.logOperation(
            op,
            result: 'success',
          );
          if (_removeOnSuccess) {
            await _queue.removeOperation(op.id);
          }
          success++;
          _progressController.add(
            SyncProgressEvent(
              operationId: op.id,
              current: currentIndex,
              total: totalOps,
              status: SyncOperationStatus.success,
            ),
          );
        }
      } on OperationSkippedException catch (e) {
        skipped++;
        await _auditLogger?.logOperation(
          op,
          result: 'skipped',
          errorMessage: e.toString(),
        );
        if (_removeOnSkipped) {
          await _queue.removeOperation(op.id);
        }
        _progressController.add(
          SyncProgressEvent(
            operationId: op.id,
            current: currentIndex,
            total: totalOps,
            status: SyncOperationStatus.skipped,
            error: e.toString(),
          ),
        );
      } catch (e) {
        failed++;
        final errorMsg = 'Op ${op.id} (${op.model}.${op.method}): $e';
        errors.add(errorMsg);
        await _queue.markOperationFailed(op.id, e.toString());
        await _auditLogger?.logOperation(
          op,
          result: 'error',
          errorMessage: e.toString(),
        );
        _progressController.add(
          SyncProgressEvent(
            operationId: op.id,
            current: currentIndex,
            total: totalOps,
            status: SyncOperationStatus.failed,
            error: e.toString(),
          ),
        );
      }
    }

    return QueueProcessResult(
      synced: success,
      failed: failed,
      skipped: skipped,
      errors: errors,
      conflicts: conflicts,
    );
  }

  /// Sort order for operation methods: create=0, write=1, unlink=2.
  static int _methodSortOrder(String method) {
    return switch (method) {
      'create' => 0,
      'write' => 1,
      'unlink' => 2,
      _ => 1, // default to write-level
    };
  }
}
