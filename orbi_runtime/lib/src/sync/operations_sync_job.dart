import 'package:odoo_sdk/odoo_sdk.dart';

import '../contracts.dart';
import '../session/session_runtime.dart';
import 'sync_job.dart';

/// Result of checking whether a possibly interrupted operation already reached
/// the server. The adapter owns the exact model/command-specific query.
sealed class OperationReconciliation {
  const OperationReconciliation();
}

final class OperationNotApplied extends OperationReconciliation {
  const OperationNotApplied();
}

final class OperationApplied extends OperationReconciliation {
  const OperationApplied();
}

final class OperationConflict extends OperationReconciliation {
  const OperationConflict(this.details);
  final ConflictInfo details;
}

/// The transport cannot establish whether the remote mutation committed.
/// The job reconciles this marker before allowing another dispatch.
final class AmbiguousOperationException implements Exception {
  const AmbiguousOperationException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Adapter for the already existing sale/approval/collection command handlers.
/// It deliberately receives a queue operation rather than inventing a second
/// command payload or endpoint vocabulary.
abstract interface class OfflineOperationAdapter {
  Future<OperationReconciliation> reconcile(OfflineOperation operation);

  Future<ConflictInfo?> dispatch(OfflineOperation operation);
}

/// Durable operation drain. Dependency sorting, retry/backoff, recovery of
/// interrupted rows and dead-letter policy remain in the SDK processor.
final class OperationsSyncJob implements SyncJob {
  OperationsSyncJob({
    required this.queue,
    required this.adapter,
    this.sessions,
  }) {
    _processor = OfflineQueueProcessor(
      queue: queue,
      handler: _handle,
      removeOnSuccess: true,
      removeOnConflict: false,
      removeOnSkipped: false,
    );
  }

  final OfflineQueueStore queue;
  final OfflineOperationAdapter adapter;
  final SessionRuntime? sessions;
  late final OfflineQueueProcessor _processor;
  AppScope? _scope;
  SessionLease? _lease;
  int _epoch = 0;
  int _conflictCount = 0;

  @override
  String get id => 'operations';

  Future<OperationsQueueSnapshot> queueSnapshot() async {
    final stats = await queue.getRetryStats();
    return OperationsQueueSnapshot(
      pending:
          (stats['ready'] as int? ?? 0) + (stats['scheduled'] as int? ?? 0),
      scheduled: stats['scheduled'] as int? ?? 0,
      deadLetter: stats['dead_letter'] as int? ?? 0,
      conflict: _conflictCount,
    );
  }

  /// Invalidates in-flight dispatches when the owning session changes.
  void invalidate(AppScope scope) {
    if (_scope == scope) {
      _epoch++;
      _scope = null;
      _lease = null;
    }
  }

  @override
  Future<SyncJobResult> run(AppScope scope) async {
    final token = ++_epoch;
    _scope = scope;
    _lease = sessions?.active?.lease;
    final active = sessions?.active;
    if (sessions != null && (active?.scope != scope || _lease == null)) {
      return SyncJobResult.failed(
        StateError('Operation session is not active'),
      );
    }
    try {
      final result = await _processor.processQueue();
      _conflictCount = result.conflicts.length;
      if (!_current(scope, token)) {
        return SyncJobResult.failed(StateError('Operation scope changed'));
      }
      return result.failed == 0 && result.conflicts.isEmpty
          ? const SyncJobResult.committed()
          : SyncJobResult.failed(
              StateError(
                'Operation drain failed=${result.failed}, conflicts=${result.conflicts.length}',
              ),
            );
    } catch (error) {
      return SyncJobResult.failed(error);
    }
  }

  Future<ConflictInfo?> _handle(OfflineOperation operation) async {
    final scope = _scope;
    final token = _epoch;
    if (scope == null || !_current(scope, token)) {
      throw StateError('Operation scope changed before dispatch');
    }

    // A retry-safe command has an explicit server marker/reconciliation query.
    // Recovery rows must reconcile before any remote mutation is attempted.
    if (operation.replayPolicy == OfflineReplayPolicy.retrySafe ||
        operation.status == OfflineOperationStatus.recoveryPending) {
      final prior = await adapter.reconcile(operation);
      if (!_current(scope, token)) {
        throw StateError('Operation scope changed during reconciliation');
      }
      switch (prior) {
        case OperationApplied():
          return null;
        case OperationConflict(:final details):
          return details;
        case OperationNotApplied():
          break;
      }
    }

    try {
      final conflict = await adapter.dispatch(operation);
      if (!_current(scope, token)) {
        throw StateError('Operation scope changed during dispatch');
      }
      return conflict;
    } on AmbiguousOperationException {
      final prior = await adapter.reconcile(operation);
      if (!_current(scope, token)) {
        throw StateError('Operation scope changed during ambiguity recovery');
      }
      switch (prior) {
        case OperationApplied():
          return null;
        case OperationConflict(:final details):
          return details;
        case OperationNotApplied():
          rethrow;
      }
    } on OdooAuthenticationException catch (error) {
      throw RetryableOfflineOperationException(error.message);
    } on OdooAccessDeniedException catch (error) {
      throw RetryableOfflineOperationException(error.message);
    }
  }

  bool _current(AppScope scope, int token) {
    if (_scope != scope || _epoch != token) return false;
    final sessions = this.sessions;
    final lease = _lease;
    return sessions == null || (lease != null && sessions.accepts(lease));
  }

  Future<void> dispose() => _processor.shutdown();
}

final class OperationsQueueSnapshot {
  const OperationsQueueSnapshot({
    required this.pending,
    required this.scheduled,
    required this.deadLetter,
    required this.conflict,
  });
  final int pending;
  final int scheduled;
  final int deadLetter;
  final int conflict;
}
