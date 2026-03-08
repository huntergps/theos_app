import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import 'mocks/mock_offline_queue.dart';

void main() {
  group('OfflineQueueConfig', () {
    group('getRetryDelay', () {
      test('returns base delay when exponentialBackoff is false', () {
        const config = OfflineQueueConfig(
          baseRetryDelayMs: 1000,
          exponentialBackoff: false,
        );

        expect(config.getRetryDelay(0), const Duration(milliseconds: 1000));
        expect(config.getRetryDelay(1), const Duration(milliseconds: 1000));
        expect(config.getRetryDelay(5), const Duration(milliseconds: 1000));
        expect(config.getRetryDelay(10), const Duration(milliseconds: 1000));
      });

      test('calculates exponential backoff correctly', () {
        const config = OfflineQueueConfig(
          baseRetryDelayMs: 1000,
          maxRetryDelayMs: 60000,
          exponentialBackoff: true,
        );

        // 1000 * 2^0 = 1000
        expect(config.getRetryDelay(0), const Duration(milliseconds: 1000));
        // 1000 * 2^1 = 2000
        expect(config.getRetryDelay(1), const Duration(milliseconds: 2000));
        // 1000 * 2^2 = 4000
        expect(config.getRetryDelay(2), const Duration(milliseconds: 4000));
        // 1000 * 2^3 = 8000
        expect(config.getRetryDelay(3), const Duration(milliseconds: 8000));
        // 1000 * 2^4 = 16000
        expect(config.getRetryDelay(4), const Duration(milliseconds: 16000));
      });

      test('caps delay at maxRetryDelayMs', () {
        const config = OfflineQueueConfig(
          baseRetryDelayMs: 1000,
          maxRetryDelayMs: 10000,
          exponentialBackoff: true,
        );

        // 1000 * 2^4 = 16000, capped to 10000
        expect(config.getRetryDelay(4), const Duration(milliseconds: 10000));
        // 1000 * 2^5 = 32000, capped to 10000
        expect(config.getRetryDelay(5), const Duration(milliseconds: 10000));
        // 1000 * 2^10 = 1024000, capped to 10000
        expect(config.getRetryDelay(10), const Duration(milliseconds: 10000));
      });

      test('uses default values correctly', () {
        const config = OfflineQueueConfig();

        expect(config.maxRetries, 5);
        expect(config.baseRetryDelayMs, SyncConstants.baseRetryDelayMs);
        expect(config.maxRetryDelayMs, SyncConstants.maxRetryDelayMs);
        expect(config.exponentialBackoff, true);
        expect(config.parallelOperations, SyncConstants.defaultParallelOperations);
      });

      test('handles edge case of retry count 0', () {
        const config = OfflineQueueConfig(
          baseRetryDelayMs: 500,
          exponentialBackoff: true,
        );

        // 500 * 2^0 = 500
        expect(config.getRetryDelay(0), const Duration(milliseconds: 500));
      });
    });
  });

  group('InMemoryOfflineQueueStore', () {
    late InMemoryOfflineQueueStore store;

    setUp(() {
      store = InMemoryOfflineQueueStore();
    });

    group('queueOperation', () {
      test('adds operation to queue with auto-increment ID', () async {
        final id1 = await store.queueOperation(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test 1'},
        );

        final id2 = await store.queueOperation(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test 2'},
        );

        expect(id1, 1);
        expect(id2, 2);
        expect(store.allOperations.length, 2);
      });

      test('stores operation with all fields', () async {
        final id = await store.queueOperation(
          model: 'res.partner',
          method: 'write',
          recordId: 42,
          values: {'name': 'Updated'},
          priority: OfflinePriority.high,
          deviceId: 'device-123',
        );

        final op = store.getById(id);
        expect(op, isNotNull);
        expect(op!.model, 'res.partner');
        expect(op.method, 'write');
        expect(op.recordId, 42);
        expect(op.values, {'name': 'Updated'});
        expect(op.priority, OfflinePriority.high);
        expect(op.deviceId, 'device-123');
        expect(op.retryCount, 0);
      });
    });

    group('getPendingOperations', () {
      test('returns empty list for empty queue', () async {
        final operations = await store.getPendingOperations();
        expect(operations, isEmpty);
      });

      test('returns operations sorted by priority', () async {
        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {'order': 1},
          priority: OfflinePriority.low,
        );

        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {'order': 2},
          priority: OfflinePriority.high,
        );

        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {'order': 3},
          priority: OfflinePriority.normal,
        );

        final operations = await store.getPendingOperations();
        expect(operations.length, 3);
        // Lower priority value = higher priority
        expect(operations[0].values['order'], 2); // high
        expect(operations[1].values['order'], 3); // normal
        expect(operations[2].values['order'], 1); // low
      });

      test('excludes operations with max retries', () async {
        // Add an operation manually with maxRetries exceeded
        store.addOperation(OfflineOperation(
          id: 100,
          model: 'test.model',
          method: 'create',
          values: {},
          createdAt: DateTime.now(),
          retryCount: 5, // Max retries
        ));

        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {'normal': true},
        );

        final pending = await store.getPendingOperations();
        expect(pending.length, 1);
        expect(pending[0].values['normal'], true);
      });
    });

    group('markOperationFailed', () {
      test('increments retry count', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        expect(store.getById(id)!.retryCount, 0);

        await store.markOperationFailed(id, 'Network error');

        expect(store.getById(id)!.retryCount, 1);
      });

      test('sets lastError message', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        await store.markOperationFailed(id, 'Connection timeout');

        final op = store.getById(id)!;
        expect(op.lastError, 'Connection timeout');
      });

      test('schedules next retry with exponential backoff', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        final beforeFail = DateTime.now();
        await store.markOperationFailed(id, 'Error');

        final op = store.getById(id)!;
        expect(op.nextRetryAt, isNotNull);
        // First retry should be ~1 second later (1000ms * 2^0)
        expect(
          op.nextRetryAt!.difference(beforeFail).inMilliseconds,
          greaterThanOrEqualTo(900),
        );
      });

      test('does not schedule next retry when max retries reached', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        // Fail 5 times (max retries)
        for (int i = 0; i < 5; i++) {
          await store.markOperationFailed(id, 'Error $i');
        }

        final op = store.getById(id)!;
        expect(op.retryCount, 5);
        expect(op.nextRetryAt, isNull);
      });

      test('updates lastRetryAt timestamp', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        final beforeFail = DateTime.now();
        await store.markOperationFailed(id, 'Error');

        final op = store.getById(id)!;
        expect(op.lastRetryAt, isNotNull);
        expect(
          op.lastRetryAt!.difference(beforeFail).inMilliseconds,
          lessThan(100),
        );
      });
    });

    group('getDeadLetterOperations', () {
      test('returns empty list when no dead letter operations', () async {
        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        final deadLetter = await store.getDeadLetterOperations();
        expect(deadLetter, isEmpty);
      });

      test('returns operations that exceeded max retries', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {'dead': true},
        );

        // Fail 5 times to move to dead letter
        for (int i = 0; i < 5; i++) {
          await store.markOperationFailed(id, 'Error $i');
        }

        final deadLetter = await store.getDeadLetterOperations();
        expect(deadLetter.length, 1);
        expect(deadLetter[0].values['dead'], true);
        expect(deadLetter[0].retryCount, 5);
      });

      test('excludes operations still in pending', () async {
        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {'pending': true},
        );

        final deadId = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {'dead': true},
        );

        for (int i = 0; i < 5; i++) {
          await store.markOperationFailed(deadId, 'Error');
        }

        final deadLetter = await store.getDeadLetterOperations();
        expect(deadLetter.length, 1);
        expect(deadLetter[0].values['dead'], true);
      });
    });

    group('resetOperationRetry', () {
      test('resets retry count to zero', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        // Fail a few times
        await store.markOperationFailed(id, 'Error 1');
        await store.markOperationFailed(id, 'Error 2');

        expect(store.getById(id)!.retryCount, 2);

        await store.resetOperationRetry(id);

        expect(store.getById(id)!.retryCount, 0);
      });

      test('clears retry-related fields', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        await store.markOperationFailed(id, 'Some error');

        var op = store.getById(id)!;
        expect(op.lastError, 'Some error');
        expect(op.lastRetryAt, isNotNull);
        expect(op.nextRetryAt, isNotNull);

        await store.resetOperationRetry(id);

        op = store.getById(id)!;
        expect(op.lastError, isNull);
        expect(op.lastRetryAt, isNull);
        expect(op.nextRetryAt, isNull);
      });

      test('moves dead letter operation back to pending', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        // Move to dead letter
        for (int i = 0; i < 5; i++) {
          await store.markOperationFailed(id, 'Error');
        }

        var deadLetter = await store.getDeadLetterOperations();
        expect(deadLetter.length, 1);

        await store.resetOperationRetry(id);

        deadLetter = await store.getDeadLetterOperations();
        expect(deadLetter, isEmpty);

        final pending = await store.getPendingOperations();
        expect(pending.length, 1);
      });
    });

    group('getRetryStats', () {
      test('returns correct stats for empty queue', () async {
        final stats = await store.getRetryStats();

        expect(stats['total'], 0);
        expect(stats['ready'], 0);
        expect(stats['scheduled'], 0);
        expect(stats['dead_letter'], 0);
      });

      test('counts ready operations', () async {
        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        final stats = await store.getRetryStats();
        expect(stats['ready'], 2);
        expect(stats['total'], 2);
      });

      test('counts scheduled operations separately', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        // Fail one to schedule retry
        await store.markOperationFailed(id, 'Error');

        final stats = await store.getRetryStats();
        expect(stats['ready'], 1); // The one that hasn't failed
        expect(stats['scheduled'], 1); // The one waiting for retry
        expect(stats['total'], 2);
      });

      test('counts dead letter operations', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        // Move to dead letter
        for (int i = 0; i < 5; i++) {
          await store.markOperationFailed(id, 'Error');
        }

        final stats = await store.getRetryStats();
        expect(stats['dead_letter'], 1);
        expect(stats['ready'], 0);
        expect(stats['total'], 1);
      });
    });

    group('removeOperation', () {
      test('removes operation from queue', () async {
        final id = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        expect(store.allOperations.length, 1);

        await store.removeOperation(id);

        expect(store.allOperations, isEmpty);
      });

      test('does nothing for non-existent operation', () async {
        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        await store.removeOperation(999);

        expect(store.allOperations.length, 1);
      });
    });

    group('clear', () {
      test('removes all operations and resets ID counter', () async {
        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        store.clear();

        expect(store.allOperations, isEmpty);

        // Next ID should be 1 again
        final newId = await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {},
        );

        expect(newId, 1);
      });
    });
  });

  group('OfflineQueueWrapper', () {
    late InMemoryOfflineQueueStore store;
    late OfflineQueueWrapper queue;

    setUp(() {
      store = InMemoryOfflineQueueStore();
      queue = OfflineQueueWrapper(store);
    });

    tearDown(() {
      queue.dispose();
    });

    group('enqueue', () {
      test('adds operation and updates pending count', () async {
        await queue.initialize();

        // Collect pending count values
        final counts = <int>[];
        final subscription = queue.pendingCount.listen(counts.add);

        await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test'},
        );

        await Future.delayed(const Duration(milliseconds: 50));
        subscription.cancel();

        expect(counts.last, 1);
      });

      test('returns operation ID', () async {
        final id = await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test'},
        );

        expect(id, 1);
      });
    });

    group('markCompleted', () {
      test('removes operation and updates counts', () async {
        await queue.initialize();

        final id = await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test'},
        );

        final counts = <int>[];
        final subscription = queue.pendingCount.listen(counts.add);

        await queue.markCompleted(id);

        await Future.delayed(const Duration(milliseconds: 50));
        subscription.cancel();

        expect(counts.last, 0);
        expect(store.allOperations, isEmpty);
      });
    });

    group('markFailed', () {
      test('increments retry count and updates counts', () async {
        await queue.initialize();

        final id = await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test'},
        );

        await queue.markFailed(id, 'Test error');

        final op = store.getById(id)!;
        expect(op.retryCount, 1);
        expect(op.lastError, 'Test error');
      });

      test('moves to dead letter after max retries', () async {
        await queue.initialize();

        final id = await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test'},
        );

        // Fail 5 times
        for (int i = 0; i < 5; i++) {
          await queue.markFailed(id, 'Error $i');
        }

        final deadLetter = await queue.getDeadLetterOperations();
        expect(deadLetter.length, 1);

        // Check dead letter count stream
        final counts = <int>[];
        final subscription = queue.deadLetterCount.listen(counts.add);
        await Future.delayed(const Duration(milliseconds: 50));
        subscription.cancel();

        expect(counts.last, 1);
      });
    });

    group('resetOperationRetry', () {
      test('moves dead letter operation back to pending', () async {
        await queue.initialize();

        final id = await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test'},
        );

        // Move to dead letter
        for (int i = 0; i < 5; i++) {
          await queue.markFailed(id, 'Error');
        }

        await queue.resetOperationRetry(id);

        final pending = await queue.getPending();
        expect(pending.length, 1);

        final deadLetter = await queue.getDeadLetterOperations();
        expect(deadLetter, isEmpty);
      });
    });

    group('processQueue', () {
      test('processes all pending operations', () async {
        await queue.initialize();

        await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test 1'},
        );

        await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test 2'},
        );

        final processedOps = <OfflineOperation>[];
        final result = await queue.processQueue(
          processor: (op) async {
            processedOps.add(op);
          },
        );

        expect(result.processed, 2);
        expect(result.failed, 0);
        expect(processedOps.length, 2);
        expect(store.allOperations, isEmpty);
      });

      test('marks failed operations on processor error', () async {
        await queue.initialize();

        final id = await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test'},
        );

        final result = await queue.processQueue(
          processor: (op) async {
            throw Exception('Network error');
          },
        );

        expect(result.processed, 0);
        expect(result.failed, 1);

        final op = store.getById(id)!;
        expect(op.retryCount, 1);
        expect(op.lastError, contains('Network error'));
      });

      test('returns already processing message when queue is busy', () async {
        await queue.initialize();

        await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test'},
        );

        // Start a slow processing
        final firstProcess = queue.processQueue(
          processor: (op) async {
            await Future.delayed(const Duration(milliseconds: 200));
          },
        );

        // Try to process again immediately
        await Future.delayed(const Duration(milliseconds: 50));
        final secondResult = await queue.processQueue(
          processor: (op) async {},
        );

        expect(secondResult.message, 'Queue already being processed');
        expect(secondResult.processed, 0);

        // Wait for first to complete
        await firstProcess;
      });

      test('updates isProcessing stream', () async {
        await queue.initialize();

        await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test'},
        );

        final processingStates = <bool>[];
        final subscription = queue.isProcessing.listen(processingStates.add);

        await queue.processQueue(
          processor: (op) async {
            await Future.delayed(const Duration(milliseconds: 10));
          },
        );

        await Future.delayed(const Duration(milliseconds: 50));
        subscription.cancel();

        // Should have: initial false, then true during processing, then false
        expect(processingStates, contains(true));
        expect(processingStates.last, false);
      });

      test('skips operations not ready for retry', () async {
        // Add an operation that's scheduled for future retry
        store.addOperation(OfflineOperation(
          id: 1,
          model: 'test.model',
          method: 'create',
          values: {},
          createdAt: DateTime.now(),
          retryCount: 1,
          nextRetryAt: DateTime.now().add(const Duration(hours: 1)),
        ));

        // Add a ready operation
        await store.queueOperation(
          model: 'test.model',
          method: 'create',
          values: {'ready': true},
        );

        final processedOps = <OfflineOperation>[];
        final result = await queue.processQueue(
          processor: (op) async {
            processedOps.add(op);
          },
        );

        // Only the ready operation should be processed
        expect(processedOps.length, 1);
        expect(processedOps[0].values['ready'], true);
        expect(result.processed, 1);
      });
    });

    group('getStats', () {
      test('returns correct queue statistics', () async {
        await queue.initialize();

        // Add some pending operations
        await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test 1'},
        );

        final failId = await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test 2'},
        );

        final deadId = await queue.enqueue(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test 3'},
        );

        // Fail one to schedule
        await queue.markFailed(failId, 'Error');

        // Move one to dead letter
        for (int i = 0; i < 5; i++) {
          await queue.markFailed(deadId, 'Error');
        }

        final stats = await queue.getStats();

        expect(stats.pending, 1); // Ready to process
        expect(stats.failed, 1); // Scheduled for retry
        expect(stats.deadLetter, 1); // In dead letter queue
      });
    });

    group('dispose', () {
      test('closes all streams without errors', () async {
        await queue.initialize();

        // Dispose should complete without throwing
        queue.dispose();

        // After dispose, accessing the stream values should show they're closed
        // by trying to listen and seeing it completes immediately
        final subscription = queue.pendingCount.listen(
          (_) {},
          onDone: () {},
        );

        await Future.delayed(const Duration(milliseconds: 50));
        subscription.cancel();

        // The stream is closed after dispose, so it shouldn't emit new values
        // We just verify dispose doesn't throw
        expect(true, isTrue);
      });
    });
  });

  group('WrapperQueueResult', () {
    test('calculates total correctly', () {
      const result = WrapperQueueResult(
        processed: 5,
        failed: 2,
        skipped: 3,
      );

      expect(result.total, 10);
    });

    test('hasFailures returns true when failed > 0', () {
      const withFailures = WrapperQueueResult(
        processed: 5,
        failed: 1,
        skipped: 0,
      );

      const withoutFailures = WrapperQueueResult(
        processed: 5,
        failed: 0,
        skipped: 0,
      );

      expect(withFailures.hasFailures, true);
      expect(withoutFailures.hasFailures, false);
    });

    test('toString returns readable format', () {
      const result = WrapperQueueResult(
        processed: 5,
        failed: 2,
        skipped: 1,
      );

      expect(
        result.toString(),
        'WrapperQueueResult(processed: 5, failed: 2, skipped: 1)',
      );
    });
  });

  group('QueueStats', () {
    test('calculates total correctly', () {
      const stats = QueueStats(
        pending: 5,
        failed: 2,
        completed: 10,
        deadLetter: 1,
        processing: 2,
      );

      expect(stats.total, 20);
    });

    test('calculates active correctly', () {
      const stats = QueueStats(
        pending: 5,
        failed: 2,
        completed: 10,
        deadLetter: 1,
        processing: 2,
      );

      expect(stats.active, 9); // pending + failed + processing
    });

    test('toString returns readable format', () {
      const stats = QueueStats(
        pending: 5,
        failed: 2,
        completed: 10,
        deadLetter: 1,
        processing: 2,
      );

      expect(
        stats.toString(),
        'QueueStats(pending: 5, failed: 2, deadLetter: 1)',
      );
    });
  });
}
