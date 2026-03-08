import 'dart:async';

import 'package:test/test.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

/// In-memory implementation of OfflineQueueStore for testing.
class InMemoryQueueStore implements OfflineQueueStore {
  final List<OfflineOperation> _operations = [];
  int _nextId = 1;

  // Track method calls for verification
  final List<String> methodCalls = [];
  final Map<int, String> failedOperations = {};

  @override
  Future<int> queueOperation({
    required String model,
    required String method,
    int? recordId,
    required Map<String, dynamic> values,
    DateTime? baseWriteDate,
    int? parentOrderId,
    int priority = OfflinePriority.normal,
    String? deviceId,
  }) async {
    final id = _nextId++;
    _operations.add(OfflineOperation(
      id: id,
      model: model,
      method: method,
      recordId: recordId,
      values: values,
      createdAt: DateTime.now(),
      baseWriteDate: baseWriteDate,
      parentOrderId: parentOrderId,
      priority: priority,
      deviceId: deviceId,
    ));
    methodCalls.add('queueOperation:$id');
    return id;
  }

  @override
  Future<List<OfflineOperation>> getPendingOperations({
    bool includeNotReady = false,
  }) async {
    methodCalls.add('getPendingOperations');
    return _operations
        .where((op) => includeNotReady || op.isReadyForRetry)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  @override
  Future<int> getPendingCount() async {
    methodCalls.add('getPendingCount');
    return _operations.length;
  }

  @override
  Future<List<OfflineOperation>> getOperationsForModel(String model) async {
    methodCalls.add('getOperationsForModel:$model');
    return _operations.where((op) => op.model == model).toList();
  }

  @override
  Future<OfflineOperation?> getOperationById(int id) async {
    methodCalls.add('getOperationById:$id');
    try {
      return _operations.firstWhere((op) => op.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> removeOperation(int id) async {
    methodCalls.add('removeOperation:$id');
    _operations.removeWhere((op) => op.id == id);
  }

  @override
  Future<void> markOperationFailed(int id, String errorMessage) async {
    methodCalls.add('markOperationFailed:$id');
    failedOperations[id] = errorMessage;

    final index = _operations.indexWhere((op) => op.id == id);
    if (index >= 0) {
      final op = _operations[index];
      _operations[index] = OfflineOperation(
        id: op.id,
        model: op.model,
        method: op.method,
        recordId: op.recordId,
        values: op.values,
        createdAt: op.createdAt,
        baseWriteDate: op.baseWriteDate,
        parentOrderId: op.parentOrderId,
        priority: op.priority,
        deviceId: op.deviceId,
        retryCount: op.retryCount + 1,
        lastRetryAt: DateTime.now(),
        lastError: errorMessage,
      );
    }
  }

  @override
  Future<void> resetOperationRetry(int id) async {
    methodCalls.add('resetOperationRetry:$id');
    failedOperations.remove(id);
  }

  @override
  Future<List<OfflineOperation>> getDeadLetterOperations() async {
    methodCalls.add('getDeadLetterOperations');
    return _operations.where((op) => op.hasExceededMaxRetries).toList();
  }

  @override
  Future<Map<String, dynamic>> getRetryStats() async {
    methodCalls.add('getRetryStats');
    return {
      'total': _operations.length,
      'failed': failedOperations.length,
    };
  }

  @override
  Future<int> removeOperationsBefore(DateTime date) async {
    methodCalls.add('removeOperationsBefore');
    final before = _operations.where((op) => op.createdAt.isBefore(date)).toList();
    _operations.removeWhere((op) => op.createdAt.isBefore(date));
    return before.length;
  }

  @override
  Future<int> removeDeadLetterOperations() async {
    methodCalls.add('removeDeadLetterOperations');
    final dead = _operations.where((op) => op.hasExceededMaxRetries).toList();
    _operations.removeWhere((op) => op.hasExceededMaxRetries);
    return dead.length;
  }

  @override
  Future<List<OfflineOperation>> getOperationsForRecord(
    String model,
    int recordId,
  ) async {
    methodCalls.add('getOperationsForRecord:$model:$recordId');
    return _operations
        .where((op) => op.model == model && op.recordId == recordId)
        .toList();
  }

  /// Helper to add operations directly for testing
  void addOperation(OfflineOperation op) {
    _operations.add(op);
  }

  /// Clear all operations
  void clear() {
    _operations.clear();
    methodCalls.clear();
    failedOperations.clear();
    _nextId = 1;
  }
}

/// Mock audit logger for testing
class MockAuditLogger implements OfflineQueueAuditLogger {
  final List<Map<String, dynamic>> logs = [];

  @override
  Future<void> logOperation(
    OfflineOperation op, {
    required String result,
    int? odooId,
    String? errorMessage,
  }) async {
    logs.add({
      'operationId': op.id,
      'model': op.model,
      'method': op.method,
      'result': result,
      'odooId': odooId,
      'errorMessage': errorMessage,
    });
  }

  void clear() => logs.clear();
}

void main() {
  group('OfflineQueueProcessor', () {
    late InMemoryQueueStore store;
    late MockAuditLogger auditLogger;

    setUp(() {
      store = InMemoryQueueStore();
      auditLogger = MockAuditLogger();
    });

    tearDown(() {
      store.clear();
      auditLogger.clear();
    });

    group('processQueue', () {
      test('returns empty result for empty queue', () async {
        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => null,
        );

        final result = await processor.processQueue();

        expect(result.synced, equals(0));
        expect(result.failed, equals(0));
        expect(result.skipped, equals(0));
        expect(result.isEmpty, isTrue);
        expect(store.methodCalls, contains('getPendingOperations'));

        processor.dispose();
      });

      test('processes successful operations', () async {
        // Add test operations
        await store.queueOperation(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test Partner'},
        );
        await store.queueOperation(
          model: 'sale.order',
          method: 'write',
          recordId: 100,
          values: {'state': 'sale'},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => null, // null = success
        );

        final result = await processor.processQueue();

        expect(result.synced, equals(2));
        expect(result.failed, equals(0));
        expect(result.conflicts, isEmpty);
        expect(result.errors, isEmpty);

        // Operations should be removed on success (default behavior)
        expect(await store.getPendingCount(), equals(0));

        processor.dispose();
      });

      test('handles conflicts correctly', () async {
        await store.queueOperation(
          model: 'res.partner',
          method: 'write',
          recordId: 1,
          values: {'name': 'Updated'},
        );

        final conflict = ConflictInfo(
          operationId: 1,
          model: 'res.partner',
          recordId: 1,
          localWriteDate: DateTime.now().subtract(const Duration(hours: 1)),
          serverWriteDate: DateTime.now(),
          localValues: {'name': 'Updated'},
          serverValues: {'name': 'Server Value'},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => conflict, // Return conflict
          removeOnConflict: false, // Keep conflicting operations
        );

        final result = await processor.processQueue();

        expect(result.synced, equals(0));
        expect(result.conflicts, hasLength(1));
        expect(result.conflicts.first.model, equals('res.partner'));

        // Operation should NOT be removed (removeOnConflict: false)
        expect(await store.getPendingCount(), equals(1));

        processor.dispose();
      });

      test('removes operations on conflict when configured', () async {
        await store.queueOperation(
          model: 'res.partner',
          method: 'write',
          recordId: 1,
          values: {'name': 'Updated'},
        );

        final conflict = ConflictInfo(
          operationId: 1,
          model: 'res.partner',
          recordId: 1,
          localWriteDate: DateTime.now(),
          serverWriteDate: DateTime.now(),
          localValues: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => conflict,
          removeOnConflict: true, // Remove on conflict
        );

        await processor.processQueue();

        // Operation should be removed
        expect(await store.getPendingCount(), equals(0));

        processor.dispose();
      });

      test('handles skipped operations', () async {
        await store.queueOperation(
          model: 'res.partner',
          method: 'unlink',
          recordId: 999,
          values: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            throw const OperationSkippedException('Record not found');
          },
          removeOnSkipped: true,
        );

        final result = await processor.processQueue();

        expect(result.synced, equals(0));
        expect(result.skipped, equals(1));
        expect(result.failed, equals(0));

        // Operation should be removed (removeOnSkipped: true)
        expect(await store.getPendingCount(), equals(0));

        processor.dispose();
      });

      test('keeps skipped operations when not configured to remove', () async {
        await store.queueOperation(
          model: 'res.partner',
          method: 'unlink',
          recordId: 999,
          values: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            throw const OperationSkippedException('Record not found');
          },
          removeOnSkipped: false, // Default
        );

        await processor.processQueue();

        // Operation should NOT be removed
        expect(await store.getPendingCount(), equals(1));

        processor.dispose();
      });

      test('handles failed operations with errors', () async {
        await store.queueOperation(
          model: 'sale.order',
          method: 'create',
          values: {'partner_id': 1},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            throw Exception('Network error');
          },
        );

        final result = await processor.processQueue();

        expect(result.synced, equals(0));
        expect(result.failed, equals(1));
        expect(result.errors, hasLength(1));
        expect(result.errors.first, contains('Network error'));

        // Operation should be marked as failed
        expect(store.failedOperations, hasLength(1));

        processor.dispose();
      });

      test('processes operations in priority order', () async {
        // Add operations in reverse priority order
        store.addOperation(OfflineOperation(
          id: 1,
          model: 'low.priority',
          method: 'write',
          values: {},
          createdAt: DateTime.now(),
          priority: OfflinePriority.low,
        ));
        store.addOperation(OfflineOperation(
          id: 2,
          model: 'critical',
          method: 'write',
          values: {},
          createdAt: DateTime.now(),
          priority: OfflinePriority.critical,
        ));
        store.addOperation(OfflineOperation(
          id: 3,
          model: 'normal',
          method: 'write',
          values: {},
          createdAt: DateTime.now(),
          priority: OfflinePriority.normal,
        ));

        final processedOrder = <String>[];

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            processedOrder.add(op.model);
            return null;
          },
        );

        await processor.processQueue();

        // Should be processed in priority order: critical, normal, low
        expect(processedOrder, equals(['critical', 'normal', 'low.priority']));

        processor.dispose();
      });

      test('can process specific operations list', () async {
        // Add some operations to the store
        await store.queueOperation(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'A'},
        );
        await store.queueOperation(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'B'},
        );

        // But only process a specific subset
        final specificOps = [
          OfflineOperation(
            id: 100,
            model: 'specific.model',
            method: 'write',
            values: {},
            createdAt: DateTime.now(),
          ),
        ];

        final processedModels = <String>[];

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            processedModels.add(op.model);
            return null;
          },
        );

        final result = await processor.processQueue(operations: specificOps);

        expect(result.synced, equals(1));
        expect(processedModels, equals(['specific.model']));

        // Original store operations should still be there
        expect(await store.getPendingCount(), equals(2));

        processor.dispose();
      });
    });

    group('progressStream', () {
      test('emits progress events for each operation', () async {
        await store.queueOperation(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test'},
        );
        await store.queueOperation(
          model: 'sale.order',
          method: 'create',
          values: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => null,
        );

        final events = <SyncProgressEvent>[];
        final subscription = processor.progressStream.listen(events.add);

        await processor.processQueue();
        await Future.delayed(const Duration(milliseconds: 10));

        await subscription.cancel();

        // Should have 2 processing + 2 success events = 4 events
        expect(events.length, equals(4));

        // First operation: processing then success
        expect(events[0].status, equals(SyncOperationStatus.processing));
        expect(events[0].current, equals(1));
        expect(events[0].total, equals(2));

        expect(events[1].status, equals(SyncOperationStatus.success));
        expect(events[1].current, equals(1));

        // Second operation: processing then success
        expect(events[2].status, equals(SyncOperationStatus.processing));
        expect(events[2].current, equals(2));

        expect(events[3].status, equals(SyncOperationStatus.success));
        expect(events[3].current, equals(2));

        processor.dispose();
      });

      test('emits conflict event', () async {
        await store.queueOperation(
          model: 'res.partner',
          method: 'write',
          recordId: 1,
          values: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => ConflictInfo(
            operationId: op.id,
            model: op.model,
            recordId: op.recordId,
            localWriteDate: DateTime.now(),
            serverWriteDate: DateTime.now(),
            localValues: {},
          ),
        );

        final events = <SyncProgressEvent>[];
        final subscription = processor.progressStream.listen(events.add);

        await processor.processQueue();
        await Future.delayed(const Duration(milliseconds: 10));

        await subscription.cancel();

        expect(events.any((e) => e.status == SyncOperationStatus.conflict), isTrue);

        processor.dispose();
      });

      test('emits failed event with error message', () async {
        await store.queueOperation(
          model: 'test',
          method: 'create',
          values: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            throw Exception('Test error');
          },
        );

        final events = <SyncProgressEvent>[];
        final subscription = processor.progressStream.listen(events.add);

        await processor.processQueue();
        await Future.delayed(const Duration(milliseconds: 10));

        await subscription.cancel();

        final failedEvent = events.firstWhere(
          (e) => e.status == SyncOperationStatus.failed,
        );
        expect(failedEvent.error, contains('Test error'));

        processor.dispose();
      });

      test('emits skipped event', () async {
        await store.queueOperation(
          model: 'test',
          method: 'unlink',
          recordId: 1,
          values: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            throw const OperationSkippedException('Not found');
          },
        );

        final events = <SyncProgressEvent>[];
        final subscription = processor.progressStream.listen(events.add);

        await processor.processQueue();
        await Future.delayed(const Duration(milliseconds: 10));

        await subscription.cancel();

        final skippedEvent = events.firstWhere(
          (e) => e.status == SyncOperationStatus.skipped,
        );
        expect(skippedEvent.error, contains('Not found'));

        processor.dispose();
      });

      test('calculates progress correctly', () async {
        for (var i = 0; i < 5; i++) {
          await store.queueOperation(
            model: 'test',
            method: 'create',
            values: {'index': i},
          );
        }

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => null,
        );

        final progresses = <double>[];
        final subscription = processor.progressStream.listen((event) {
          if (event.status == SyncOperationStatus.success) {
            progresses.add(event.progress);
          }
        });

        await processor.processQueue();
        await Future.delayed(const Duration(milliseconds: 10));

        await subscription.cancel();

        expect(progresses, equals([0.2, 0.4, 0.6, 0.8, 1.0]));

        processor.dispose();
      });
    });

    group('audit logging', () {
      test('logs successful operations', () async {
        await store.queueOperation(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Test'},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => null,
          auditLogger: auditLogger,
        );

        await processor.processQueue();

        expect(auditLogger.logs, hasLength(1));
        expect(auditLogger.logs.first['result'], equals('success'));
        expect(auditLogger.logs.first['model'], equals('res.partner'));

        processor.dispose();
      });

      test('logs conflicts', () async {
        await store.queueOperation(
          model: 'sale.order',
          method: 'write',
          recordId: 1,
          values: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => ConflictInfo(
            operationId: op.id,
            model: op.model,
            recordId: op.recordId,
            localWriteDate: DateTime.now(),
            serverWriteDate: DateTime.now(),
            localValues: {},
          ),
          auditLogger: auditLogger,
        );

        await processor.processQueue();

        expect(auditLogger.logs, hasLength(1));
        expect(auditLogger.logs.first['result'], equals('conflict'));

        processor.dispose();
      });

      test('logs skipped operations', () async {
        await store.queueOperation(
          model: 'test',
          method: 'unlink',
          recordId: 1,
          values: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            throw const OperationSkippedException('Record deleted');
          },
          auditLogger: auditLogger,
        );

        await processor.processQueue();

        expect(auditLogger.logs, hasLength(1));
        expect(auditLogger.logs.first['result'], equals('skipped'));
        expect(auditLogger.logs.first['errorMessage'], contains('Record deleted'));

        processor.dispose();
      });

      test('logs errors', () async {
        await store.queueOperation(
          model: 'test',
          method: 'create',
          values: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            throw Exception('Database error');
          },
          auditLogger: auditLogger,
        );

        await processor.processQueue();

        expect(auditLogger.logs, hasLength(1));
        expect(auditLogger.logs.first['result'], equals('error'));
        expect(auditLogger.logs.first['errorMessage'], contains('Database error'));

        processor.dispose();
      });
    });

    group('configuration options', () {
      test('removeOnSuccess defaults to true', () async {
        await store.queueOperation(
          model: 'test',
          method: 'create',
          values: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => null,
        );

        await processor.processQueue();

        expect(await store.getPendingCount(), equals(0));

        processor.dispose();
      });

      test('removeOnSuccess=false keeps operations', () async {
        await store.queueOperation(
          model: 'test',
          method: 'create',
          values: {},
        );

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => null,
          removeOnSuccess: false,
        );

        await processor.processQueue();

        expect(await store.getPendingCount(), equals(1));

        processor.dispose();
      });
    });
  });

  group('OfflineOperation', () {
    test('isReadyForRetry returns true when nextRetryAt is null', () {
      final op = OfflineOperation(
        id: 1,
        model: 'test',
        method: 'create',
        values: const {},
        createdAt: DateTime.now(),
        nextRetryAt: null,
      );

      expect(op.isReadyForRetry, isTrue);
    });

    test('isReadyForRetry returns true when nextRetryAt is in the past', () {
      final op = OfflineOperation(
        id: 1,
        model: 'test',
        method: 'create',
        values: {},
        createdAt: DateTime.now(),
        nextRetryAt: DateTime.now().subtract(const Duration(minutes: 1)),
      );

      expect(op.isReadyForRetry, isTrue);
    });

    test('isReadyForRetry returns false when nextRetryAt is in the future', () {
      final op = OfflineOperation(
        id: 1,
        model: 'test',
        method: 'create',
        values: {},
        createdAt: DateTime.now(),
        nextRetryAt: DateTime.now().add(const Duration(minutes: 1)),
      );

      expect(op.isReadyForRetry, isFalse);
    });

    test('hasExceededMaxRetries checks against RetryBackoff.maxRetries', () {
      final op1 = OfflineOperation(
        id: 1,
        model: 'test',
        method: 'create',
        values: {},
        createdAt: DateTime.now(),
        retryCount: 5,
      );

      final op2 = OfflineOperation(
        id: 2,
        model: 'test',
        method: 'create',
        values: {},
        createdAt: DateTime.now(),
        retryCount: RetryBackoff.maxRetries,
      );

      expect(op1.hasExceededMaxRetries, isFalse);
      expect(op2.hasExceededMaxRetries, isTrue);
    });

    test('toMap converts all fields correctly', () {
      final now = DateTime.now();
      final op = OfflineOperation(
        id: 1,
        model: 'sale.order',
        method: 'write',
        recordId: 100,
        values: {'state': 'sale'},
        createdAt: now,
        baseWriteDate: now,
        parentOrderId: 50,
        priority: OfflinePriority.high,
        deviceId: 'device-123',
        retryCount: 2,
        lastRetryAt: now,
        nextRetryAt: now,
        lastError: 'Network error',
      );

      final map = op.toMap();

      expect(map['id'], equals(1));
      expect(map['model'], equals('sale.order'));
      expect(map['method'], equals('write'));
      expect(map['record_id'], equals(100));
      expect(map['values'], equals({'state': 'sale'}));
      expect(map['parent_order_id'], equals(50));
      expect(map['priority'], equals(OfflinePriority.high));
      expect(map['device_id'], equals('device-123'));
      expect(map['retry_count'], equals(2));
      expect(map['last_error'], equals('Network error'));
    });
  });

  group('RetryBackoff', () {
    test('getNextRetryDelay returns correct delays', () {
      expect(RetryBackoff.getNextRetryDelay(0), equals(Duration.zero));
      expect(RetryBackoff.getNextRetryDelay(1), equals(const Duration(seconds: 30)));
      expect(RetryBackoff.getNextRetryDelay(2), equals(const Duration(minutes: 2)));
      expect(RetryBackoff.getNextRetryDelay(3), equals(const Duration(minutes: 10)));
      expect(RetryBackoff.getNextRetryDelay(4), equals(const Duration(minutes: 30)));
      expect(RetryBackoff.getNextRetryDelay(5), equals(const Duration(hours: 1)));
      expect(RetryBackoff.getNextRetryDelay(10), equals(const Duration(hours: 1)));
    });

    test('shouldRetry returns correct values', () {
      expect(RetryBackoff.shouldRetry(0), isTrue);
      expect(RetryBackoff.shouldRetry(5), isTrue);
      expect(RetryBackoff.shouldRetry(9), isTrue);
      expect(RetryBackoff.shouldRetry(10), isFalse);
      expect(RetryBackoff.shouldRetry(15), isFalse);
    });

    test('maxRetries is 10', () {
      expect(RetryBackoff.maxRetries, equals(10));
    });
  });

  group('OfflinePriority', () {
    test('priority constants are ordered correctly', () {
      expect(OfflinePriority.critical, lessThan(OfflinePriority.high));
      expect(OfflinePriority.high, lessThan(OfflinePriority.normal));
      expect(OfflinePriority.normal, lessThan(OfflinePriority.low));
    });

    test('priority values', () {
      expect(OfflinePriority.critical, equals(0));
      expect(OfflinePriority.high, equals(1));
      expect(OfflinePriority.normal, equals(2));
      expect(OfflinePriority.low, equals(3));
    });
  });

  group('OfflineOperationResult', () {
    test('success factory', () {
      const result = OfflineOperationResult.success(odooId: 42);

      expect(result.status, equals(SyncOperationStatus.success));
      expect(result.odooId, equals(42));
      expect(result.conflict, isNull);
      expect(result.errorMessage, isNull);
    });

    test('conflict factory', () {
      final conflict = ConflictInfo(
        operationId: 1,
        model: 'test',
        recordId: 1,
        localWriteDate: DateTime.now(),
        serverWriteDate: DateTime.now(),
        localValues: {},
      );

      final result = OfflineOperationResult.conflict(conflict);

      expect(result.status, equals(SyncOperationStatus.conflict));
      expect(result.conflict, equals(conflict));
    });

    test('skipped factory', () {
      const result = OfflineOperationResult.skipped(errorMessage: 'Not found');

      expect(result.status, equals(SyncOperationStatus.skipped));
      expect(result.errorMessage, equals('Not found'));
    });
  });
}
