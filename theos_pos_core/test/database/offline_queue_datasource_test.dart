import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/src/database/database.dart';
import 'package:theos_pos_core/src/database/datasources/offline_queue_datasource.dart';

void main() {
  late AppDatabase db;
  late OfflineQueueDataSource queue;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    queue = OfflineQueueDataSource(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('duplicate stable marker collapses to one durable operation', () async {
    final first = await queue.queueOperation(
      model: 'sale.order',
      method: 'create',
      recordId: -7,
      values: const {'_uuid': 'order-uuid-1', 'partner_id': 3},
    );
    final duplicate = await queue.queueOperation(
      model: 'sale.order',
      method: 'create',
      recordId: -7,
      values: const {'_uuid': 'order-uuid-1', 'partner_id': 3},
    );

    expect(duplicate, first);
    expect(await queue.getPendingCount(), 1);
    final operation = await queue.getOperationById(first);
    expect(operation?.operationKey, contains('order-uuid-1'));
    expect(operation?.replayPolicy, OfflineReplayPolicy.retrySafe);
  });

  test('sequential writes with the same UUID are not collapsed', () async {
    await queue.queueOperation(
      model: 'sale.order',
      method: 'write',
      recordId: 7,
      values: const {'uuid': 'order-7', 'name': 'first'},
    );
    await queue.queueOperation(
      model: 'sale.order',
      method: 'write',
      recordId: 7,
      values: const {'uuid': 'order-7', 'note': 'second'},
    );

    expect(await queue.getPendingCount(), 2);
  });

  test('remote ID hand-off survives for queued generic actions', () async {
    await queue.queueOperation(
      model: 'account.advance',
      method: 'create',
      recordId: -7,
      values: const {'amount': 25.0},
    );
    final actionId = await queue.queueOperation(
      model: 'account.advance',
      method: 'action_post',
      recordId: -7,
      values: const {},
    );

    final updated = await queue.updateRecordIdInPendingOperations(
      'account.advance',
      -7,
      701,
    );

    expect(updated, 2);
    expect((await queue.getOperationById(actionId))?.recordId, 701);
  });

  test(
    'terminal and in-flight states are excluded from pending reads',
    () async {
      final processing = await _enqueueWrite(queue, 1);
      final conflict = await _enqueueWrite(queue, 2);
      final dead = await _enqueueWrite(queue, 3);
      final completed = await _enqueueWrite(queue, 4);
      final pending = await _enqueueWrite(queue, 5);

      await queue.markOperationProcessing(processing);
      await queue.markOperationConflict(conflict);
      await queue.markOperationDeadLetter(dead, 'manual review');
      await queue.markOperationCompleted(completed);

      final rows = await queue.getPendingOperations(includeNotReady: true);
      expect(rows.map((row) => row.id), [pending]);
      expect(await queue.getPendingCount(), 1);
    },
  );

  test('max retry becomes terminal until an explicit manual reset', () async {
    final id = await _enqueueWrite(queue, 9);

    for (var attempt = 0; attempt < RetryBackoff.maxRetries; attempt++) {
      await queue.markOperationFailed(id, 'Bearer secret-token failed');
    }

    expect(await queue.getPendingOperations(includeNotReady: true), isEmpty);
    final dead = await queue.getDeadLetterOperations();
    expect(dead.map((row) => row.id), contains(id));
    expect(dead.single.status, OfflineOperationStatus.deadLetter);
    expect(dead.single.lastError, isNot(contains('secret-token')));

    await queue.resetOperationRetry(id);
    final reset = await queue.getOperationById(id);
    expect(reset?.status, OfflineOperationStatus.pending);
    expect(reset?.retryCount, 0);
    expect(await queue.getPendingCount(), 1);
  });

  test('stale cleanup never deletes unresolved queue evidence', () async {
    final pending = await _enqueueWrite(queue, 20);
    final completed = await _enqueueWrite(queue, 21);
    await queue.markOperationCompleted(completed);
    final old = DateTime.now().toUtc().subtract(const Duration(days: 60));
    await (db.update(db.offlineQueue)
          ..where((row) => row.id.isIn([pending, completed])))
        .write(OfflineQueueCompanion(createdAt: Value(old)));

    final removed = await queue.removeOperationsBefore(
      DateTime.now().toUtc().subtract(const Duration(days: 30)),
    );

    expect(removed, 1);
    expect(await queue.getOperationById(pending), isNotNull);
    expect(await queue.getOperationById(completed), isNull);
  });
}

Future<int> _enqueueWrite(OfflineQueueDataSource queue, int recordId) {
  return queue.queueOperation(
    model: 'sale.order',
    method: 'write',
    recordId: recordId,
    values: {'name': 'SO-$recordId'},
  );
}
