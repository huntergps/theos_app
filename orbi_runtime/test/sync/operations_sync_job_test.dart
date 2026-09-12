import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

final class _Adapter implements OfflineOperationAdapter {
  int dispatches = 0;
  int reconciles = 0;
  bool appliedOnReconcile = false;
  bool applyAfterDispatch = false;
  Object? dispatchError;
  ConflictInfo? conflict;
  Completer<void>? dispatchGate;

  @override
  Future<OperationReconciliation> reconcile(OfflineOperation operation) async {
    reconciles++;
    return (appliedOnReconcile || (applyAfterDispatch && reconciles > 1))
        ? const OperationApplied()
        : const OperationNotApplied();
  }

  @override
  Future<ConflictInfo?> dispatch(OfflineOperation operation) async {
    dispatches++;
    await dispatchGate?.future;
    final error = dispatchError;
    if (error != null) throw error;
    return conflict;
  }
}

AppScope _scope() => AppScope(
  appId: 'panel',
  installationId: 'install',
  normalizedServerUrl: 'https://erp.test',
  database: 'db',
  userId: 2,
);

Future<int> _enqueue(OfflineQueueDataSource queue, {String key = 'op-1'}) =>
    queue.queueOperation(
      model: 'sale.order',
      method: 'action_pos_confirm',
      recordId: -4,
      operationKey: key,
      replayPolicy: OfflineReplayPolicy.retrySafe,
      values: const {'order_uuid': 'order-4'},
    );

void main() {
  test('offline enqueue survives physical restart and drains once', () async {
    final dir = await Directory.systemTemp.createTemp('orbi-ops-');
    final path = '${dir.path}/ops.sqlite';
    final first = AppDatabase(NativeDatabase(File(path)));
    final firstQueue = OfflineQueueDataSource(first);
    await _enqueue(firstQueue);
    await first.close();

    final second = AppDatabase(NativeDatabase(File(path)));
    final queue = OfflineQueueDataSource(second);
    final adapter = _Adapter();
    final job = OperationsSyncJob(queue: queue, adapter: adapter);
    addTearDown(() async {
      await job.dispose();
      await second.close();
      await dir.delete(recursive: true);
    });
    final result = await job.run(_scope());
    expect(result.cursorConfirmed, isTrue);
    expect(adapter.dispatches, 1);
    expect(await queue.getPendingCount(), 0);
  });

  test('ambiguous response reconciles before a second dispatch', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final queue = OfflineQueueDataSource(db);
    await _enqueue(queue, key: 'ambiguous');
    final adapter = _Adapter()
      ..dispatchError = const AmbiguousOperationException('timeout')
      ..applyAfterDispatch = true;
    final job = OperationsSyncJob(queue: queue, adapter: adapter);
    addTearDown(() async {
      await job.dispose();
      await db.close();
    });
    final result = await job.run(_scope());
    expect(result.status, SyncJobStatus.committed);
    expect(adapter.dispatches, 1);
    expect(adapter.reconciles, 2);
    expect(await queue.getPendingCount(), 0);
  });

  test(
    'authentication failure retains the operation for later session',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final queue = OfflineQueueDataSource(db);
      await _enqueue(queue, key: 'auth');
      final adapter = _Adapter()
        ..dispatchError = const OdooAuthenticationException('expired');
      final job = OperationsSyncJob(queue: queue, adapter: adapter);
      addTearDown(() async {
        await job.dispose();
        await db.close();
      });
      final result = await job.run(_scope());
      expect(result.status, SyncJobStatus.failed);
      expect(await queue.getPendingCount(), 1);
    },
  );

  test(
    'queue snapshot exposes conflicts and dead letters for recovery UI',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      final queue = OfflineQueueDataSource(db);
      await _enqueue(queue, key: 'conflict');
      final conflict = ConflictInfo(
        operationId: 1,
        model: 'sale.order',
        localWriteDate: DateTime(2026),
        serverWriteDate: DateTime(2026),
        localValues: const {'amount_total': 15.0},
        serverValues: const {'amount_total': 18.0},
      );
      final adapter = _Adapter()..conflict = conflict;
      final job = OperationsSyncJob(queue: queue, adapter: adapter);
      addTearDown(() async {
        await job.dispose();
        await db.close();
      });
      final result = await job.run(_scope());
      // El resultado del trabajo, no sólo `queueSnapshot()`, es lo que llega
      // al coordinador (`SyncCoordinatorImpl._drainOnce` sólo lee
      // `result.conflicts`) — sin esto el conflicto nunca cruza a
      // `SyncSnapshot.conflictCount`.
      expect(result.conflicts, hasLength(1));
      expect(result.conflicts.single.jobId, 'operations');
      expect(result.conflicts.single.documentLabel, 'sale.order');
      final snapshot = await job.queueSnapshot();
      expect(snapshot.conflict, 1);
      // The recovery screen needs the actual conflict detail to compare
      // local vs. server values, not just a count — a snapshot that only
      // reports "1 conflict" gives it nothing to render.
      expect(snapshot.conflicts, hasLength(1));
      expect(snapshot.conflicts.single.operationId, conflict.operationId);
      expect(snapshot.conflicts.single.model, conflict.model);
      expect(snapshot.conflicts.single.localValues, conflict.localValues);
      expect(snapshot.conflicts.single.serverValues, conflict.serverValues);
      for (var i = 0; i < RetryBackoff.maxRetries; i++) {
        await queue.markOperationFailed(1, 'temporary');
      }
      expect((await job.queueSnapshot()).deadLetter, 1);
    },
  );

  test('scope invalidation discards a late operation response', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final queue = OfflineQueueDataSource(db);
    await _enqueue(queue, key: 'late');
    final adapter = _Adapter()..dispatchGate = Completer<void>();
    final job = OperationsSyncJob(queue: queue, adapter: adapter);
    addTearDown(() async {
      await job.dispose();
      await db.close();
    });
    final running = job.run(_scope());
    while (adapter.dispatches == 0) {
      await Future<void>.delayed(Duration.zero);
    }
    job.invalidate(_scope());
    adapter.dispatchGate!.complete();
    final result = await running;
    expect(result.status, SyncJobStatus.failed);
    expect(await queue.getPendingCount(), 1);
  });
}
