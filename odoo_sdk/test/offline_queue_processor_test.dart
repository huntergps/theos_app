import 'dart:async';

import 'package:test/test.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

/// In-memory implementation of OfflineQueueStore for testing.
///
/// A diferencia de versiones anteriores, esta implementación SÍ respeta un
/// status por operación ('pending' | 'processing'), igual que la tabla real
/// `offline_queue` en SQLite. Esto permite escribir tests de concurrencia
/// reales: dos `processQueue()` en paralelo no deben re-procesar la misma
/// operación, exactamente el bug que se corrigió en
/// OfflineQueueDataSource.getPendingOperations().
class InMemoryQueueStore implements OfflineQueueStore {
  final List<OfflineOperation> _operations = [];
  int _nextId = 1;

  // status por operación; default 'pending' (igual que la columna real).
  final Map<int, String> _status = {};

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
    String? operationKey,
    int commandVersion = 1,
    OfflineReplayPolicy? replayPolicy,
  }) async {
    final id = _nextId++;
    _operations.add(
      OfflineOperation(
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
        operationKey: operationKey,
        commandVersion: commandVersion,
        replayPolicy: replayPolicy ?? OfflineReplayPolicy.manualAfterAmbiguous,
      ),
    );
    _status[id] = 'pending';
    methodCalls.add('queueOperation:$id');
    return id;
  }

  @override
  Future<List<OfflineOperation>> getPendingOperations({
    bool includeNotReady = false,
  }) async {
    methodCalls.add('getPendingOperations');
    return _operations
        .where(
          (op) =>
              (_status[op.id] ?? 'pending') == 'pending' ||
              _status[op.id] == 'recovery_pending',
        )
        .where((op) => includeNotReady || op.isReadyForRetry)
        .toList()
      ..sort((a, b) => a.priority.compareTo(b.priority));
  }

  @override
  Future<int> getPendingCount() async {
    methodCalls.add('getPendingCount');
    return _operations
        .where(
          (op) =>
              (_status[op.id] ?? 'pending') == 'pending' ||
              _status[op.id] == 'recovery_pending',
        )
        .length;
  }

  @override
  Future<List<OfflineOperation>> getOperationsForModel(String model) async {
    methodCalls.add('getOperationsForModel:$model');
    return _operations
        .where(
          (op) =>
              op.model == model &&
              ((_status[op.id] ?? 'pending') == 'pending' ||
                  _status[op.id] == 'recovery_pending'),
        )
        .toList();
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
    _status.remove(id);
  }

  @override
  Future<void> markOperationFailed(int id, String errorMessage) async {
    methodCalls.add('markOperationFailed:$id');
    failedOperations[id] = errorMessage;

    final index = _operations.indexWhere((op) => op.id == id);
    if (index >= 0) {
      final op = _operations[index];
      _operations[index] = op.copyWith(
        retryCount: op.retryCount + 1,
        lastRetryAt: DateTime.now(),
        lastError: errorMessage,
        status: OfflineOperationStatus.pending,
      );
    }
    // Igual que en el datasource real: un fallo revierte 'processing' ->
    // 'pending' para que la operación no quede escondida para siempre.
    _status[id] = 'pending';
  }

  @override
  Future<void> resetOperationRetry(int id) async {
    methodCalls.add('resetOperationRetry:$id');
    failedOperations.remove(id);
    final index = _operations.indexWhere((op) => op.id == id);
    if (index >= 0) {
      _operations[index] = _operations[index].copyWith(
        retryCount: 0,
        status: OfflineOperationStatus.pending,
        clearLastRetryAt: true,
        clearNextRetryAt: true,
        clearLastError: true,
      );
    }
  }

  @override
  Future<List<OfflineOperation>> getDeadLetterOperations() async {
    methodCalls.add('getDeadLetterOperations');
    return _operations.where((op) => op.hasExceededMaxRetries).toList();
  }

  @override
  Future<Map<String, dynamic>> getRetryStats() async {
    methodCalls.add('getRetryStats');
    return {'total': _operations.length, 'failed': failedOperations.length};
  }

  @override
  Future<int> removeOperationsBefore(DateTime date) async {
    methodCalls.add('removeOperationsBefore');
    final before = _operations
        .where((op) => op.createdAt.isBefore(date))
        .toList();
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

  @override
  Future<void> markOperationProcessing(int id) async {
    methodCalls.add('markOperationProcessing:$id');
    _status[id] = 'processing';
  }

  @override
  Future<void> markOperationPending(int id) async {
    methodCalls.add('markOperationPending:$id');
    _status[id] = 'pending';
  }

  @override
  Future<void> markOperationCompleted(int id) async {
    methodCalls.add('markOperationCompleted:$id');
    _status[id] = 'completed';
  }

  @override
  Future<void> markOperationConflict(int id) async {
    methodCalls.add('markOperationConflict:$id');
    _status[id] = 'conflict';
  }

  @override
  Future<void> markOperationDeadLetter(int id, String errorMessage) async {
    methodCalls.add('markOperationDeadLetter:$id');
    failedOperations[id] = errorMessage;
    _status[id] = 'dead_letter';
  }

  @override
  Future<void> replaceOperationValues(
    int id,
    Map<String, dynamic> values,
  ) async {
    methodCalls.add('replaceOperationValues:$id');
    final index = _operations.indexWhere((op) => op.id == id);
    if (index >= 0) {
      _operations[index] = _operations[index].copyWith(values: values);
    }
  }

  /// Simula la recuperación de huérfanos que hace `AppDatabase.beforeOpen`
  /// en cada arranque de la app: cualquier fila que haya quedado en
  /// 'processing' (ej. porque la app crasheó a mitad de un processQueue())
  /// vuelve a 'pending'. Ver database.dart en theos_pos_core.
  void simulateAppRestartRecovery() {
    for (final id in _status.keys.toList()) {
      if (_status[id] == 'processing') {
        _status[id] = 'recovery_pending';
        final index = _operations.indexWhere((op) => op.id == id);
        if (index >= 0) {
          _operations[index] = _operations[index].copyWith(
            status: OfflineOperationStatus.recoveryPending,
          );
        }
      }
    }
  }

  /// Status actual de una operación (para asserts en tests).
  String? statusOf(int id) => _status[id];

  /// Helper to add operations directly for testing
  void addOperation(OfflineOperation op) {
    _operations.add(op);
    _status[op.id] = op.status.storageValue;
  }

  /// Clear all operations
  void clear() {
    _operations.clear();
    _status.clear();
    methodCalls.clear();
    failedOperations.clear();
    _nextId = 1;
  }
}

/// Mock audit logger for testing
class MockAuditLogger implements OfflineQueueAuditLogger {
  final List<Map<String, dynamic>> logs = [];

  @override
  Future<void> logConflict(OfflineOperation op, ConflictInfo conflict) async {
    logs.add({
      'operationId': op.id,
      'model': op.model,
      'method': op.method,
      'result': 'conflict',
      'conflict': conflict,
    });
  }

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

        // Evidence is retained, but held outside automatic retries.
        expect(await store.getPendingCount(), equals(0));
        expect(store.statusOf(1), 'conflict');

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

        // Evidence is retained as completed, not reprocessed forever.
        expect(await store.getPendingCount(), equals(0));
        expect(store.statusOf(1), 'completed');

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
        store.addOperation(
          OfflineOperation(
            id: 1,
            model: 'low.priority',
            method: 'write',
            values: {},
            createdAt: DateTime.now(),
            priority: OfflinePriority.low,
          ),
        );
        store.addOperation(
          OfflineOperation(
            id: 2,
            model: 'critical',
            method: 'write',
            values: {},
            createdAt: DateTime.now(),
            priority: OfflinePriority.critical,
          ),
        );
        store.addOperation(
          OfflineOperation(
            id: 3,
            model: 'normal',
            method: 'write',
            values: {},
            createdAt: DateTime.now(),
            priority: OfflinePriority.normal,
          ),
        );

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

      test('dependency order wins over numeric priority', () async {
        final now = DateTime.now();
        store.addOperation(
          OfflineOperation(
            id: 1,
            model: 'account.payment',
            method: OfflineLocalCommand.paymentCreate.storageName,
            parentOrderId: -10,
            values: const {'payment_uuid': 'pay-1'},
            createdAt: now,
            priority: OfflinePriority.critical,
          ),
        );
        store.addOperation(
          OfflineOperation(
            id: 2,
            model: 'sale.order.line',
            method: 'create',
            parentOrderId: -10,
            values: const {'uuid': 'line-1'},
            createdAt: now,
            priority: OfflinePriority.high,
          ),
        );
        store.addOperation(
          OfflineOperation(
            id: 3,
            model: 'sale.order',
            method: 'create',
            recordId: -10,
            values: const {'_uuid': 'order-1'},
            createdAt: now,
            priority: OfflinePriority.low,
          ),
        );

        final dispatched = <int>[];
        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            dispatched.add(op.id);
            return null;
          },
        );

        await processor.processQueue();

        expect(dispatched, [3, 2, 1]);
        await processor.shutdown();
      });

      test('refetches child payload after parent rewrites local IDs', () async {
        final now = DateTime.now();
        store.addOperation(
          OfflineOperation(
            id: 1,
            model: 'sale.order',
            method: 'create',
            recordId: -10,
            values: const {'_uuid': 'order-1'},
            createdAt: now,
          ),
        );
        store.addOperation(
          OfflineOperation(
            id: 2,
            model: 'sale.order.line',
            method: 'create',
            parentOrderId: -10,
            values: const {'uuid': 'line-1', 'order_id': -10},
            createdAt: now,
          ),
        );

        int? dispatchedOrderId;
        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            if (op.id == 1) {
              await store.replaceOperationValues(2, const {
                'uuid': 'line-1',
                'order_id': 88,
              });
            } else {
              dispatchedOrderId = op.values['order_id'] as int?;
            }
            return null;
          },
        );

        await processor.processQueue();

        expect(dispatchedOrderId, 88);
        await processor.shutdown();
      });

      test('parent failure blocks lines and financial dependants without spending their retries', () async {
        final now = DateTime.now();
        final operations = [
          OfflineOperation(
            id: 1,
            model: 'sale.order',
            method: 'create',
            recordId: -10,
            values: const {'uuid': 'order-1', 'local_id': -10},
            createdAt: now,
            replayPolicy: OfflineReplayPolicy.retrySafe,
          ),
          OfflineOperation(
            id: 2,
            model: 'sale.order.line',
            method: 'create',
            parentOrderId: -10,
            values: const {'uuid': 'line-1', 'order_id': -10},
            createdAt: now,
            replayPolicy: OfflineReplayPolicy.retrySafe,
          ),
          OfflineOperation(
            id: 3,
            model: 'sale.order',
            method: OfflineLocalCommand.orderConfirm.storageName,
            parentOrderId: -10,
            values: const {'local_id': -10, 'order_uuid': 'order-1'},
            createdAt: now,
            replayPolicy: OfflineReplayPolicy.retrySafe,
          ),
          OfflineOperation(
            id: 4,
            model: 'account.payment',
            method: OfflineLocalCommand.paymentCreate.storageName,
            parentOrderId: -10,
            values: const {'sale_id': -10, 'payment_uuid': 'payment-1'},
            createdAt: now,
            replayPolicy: OfflineReplayPolicy.retrySafe,
          ),
        ];
        for (final operation in operations) {
          store.addOperation(operation);
        }

        final dispatched = <int>[];
        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            dispatched.add(op.id);
            if (op.id == 1) throw StateError('parent failed');
            return null;
          },
        );

        final result = await processor.processQueue();

        expect(dispatched, [1]);
        expect(result.failed, 1);
        expect(result.skipped, 3);
        expect(store.statusOf(1), 'pending');
        expect(store.statusOf(2), 'pending');
        expect(store.statusOf(3), 'pending');
        expect(store.statusOf(4), 'pending');
        expect((await store.getOperationById(1))!.retryCount, 1);
        expect((await store.getOperationById(2))!.retryCount, 0);
        expect((await store.getOperationById(3))!.retryCount, 0);
        expect((await store.getOperationById(4))!.retryCount, 0);
        await processor.shutdown();
      });

      test('generic create failure blocks its action without spending the action retry', () async {
        final now = DateTime.now();
        store.addOperation(
          OfflineOperation(
            id: 1,
            model: 'account.advance',
            method: 'create',
            recordId: -9,
            values: const {'local_id': -9, 'amount': 20.0},
            createdAt: now,
            replayPolicy: OfflineReplayPolicy.retrySafe,
          ),
        );
        store.addOperation(
          OfflineOperation(
            id: 2,
            model: 'account.advance',
            method: 'action_post',
            recordId: -9,
            values: const {},
            createdAt: now,
            replayPolicy: OfflineReplayPolicy.retrySafe,
          ),
        );
        final dispatched = <int>[];
        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (operation) async {
            dispatched.add(operation.id);
            if (operation.id == 1) throw StateError('create failed');
            return null;
          },
        );

        final result = await processor.processQueue();

        expect(dispatched, [1]);
        expect(result.failed, 1);
        expect(result.skipped, 1);
        expect((await store.getOperationById(1))?.retryCount, 1);
        expect((await store.getOperationById(2))?.retryCount, 0);
        expect(store.statusOf(2), 'pending');
        await processor.shutdown();
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

    group('concurrency / double-dispatch protection', () {
      test('two concurrent processQueue() calls do not double-process the same operation', () async {
        // Regresión del bug crítico: getPendingOperations() no filtraba
        // por status, así que markOperationProcessing() no evitaba nada.
        // Este test simula dos llamadas paralelas a processQueue() sobre
        // el MISMO store (ej. dos instancias de OfflineSyncService, o
        // ConnectivitySyncOrchestrator + WebSocket reconnection disparando
        // sync al mismo tiempo) y verifica que cada operación se procese
        // exactamente una vez.
        await store.queueOperation(
          model: 'sale.order',
          method: 'create',
          values: {'partner_id': 1},
        );
        await store.queueOperation(
          model: 'res.partner',
          method: 'create',
          values: {'name': 'Cliente'},
        );

        final handlerCalls = <int>[];

        final processorA = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            // Simula latencia de red: le da tiempo a la segunda llamada
            // de tomar el snapshot de getPendingOperations() ANTES de
            // que la primera termine y remueva la operación.
            await Future.delayed(const Duration(milliseconds: 20));
            handlerCalls.add(op.id);
            return null;
          },
        );
        final processorB = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            await Future.delayed(const Duration(milliseconds: 20));
            handlerCalls.add(op.id);
            return null;
          },
        );

        final results = await Future.wait([
          processorA.processQueue(),
          processorB.processQueue(),
        ]);

        // Entre las dos llamadas, cada operación se procesó UNA sola vez.
        expect(handlerCalls.length, equals(2));
        expect(handlerCalls.toSet().length, equals(2));
        expect(results.map((r) => r.synced).reduce((a, b) => a + b), equals(2));
        expect(await store.getPendingCount(), equals(0));

        processorA.dispose();
        processorB.dispose();
      });

      test('a retry-safe failed operation returns to pending', () async {
        final id = await store.queueOperation(
          model: 'sale.order',
          method: 'create',
          values: {},
          replayPolicy: OfflineReplayPolicy.retrySafe,
        );

        var attempts = 0;
        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async {
            attempts++;
            throw Exception('Network error');
          },
        );

        await processor.processQueue();

        // Tras el fallo, la operación debe quedar 'pending' de nuevo
        // (no 'processing' para siempre) para que el próximo ciclo la
        // reintente cuando nextRetryAt lo permita.
        expect(store.statusOf(id), equals('pending'));
        expect(attempts, equals(1));

        processor.dispose();
      });

      test('a kept conflict is held outside automatic retries', () async {
        final id = await store.queueOperation(
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
          removeOnConflict: false,
        );

        await processor.processQueue();

        expect(store.statusOf(id), equals('conflict'));

        processor.dispose();
      });

      test('orphaned processing operations become visible again after simulated app restart recovery', () async {
        // Simula el escenario de crash: una operación quedó marcada
        // 'processing' porque la app murió a mitad de un processQueue().
        final id = await store.queueOperation(
          model: 'sale.order',
          method: 'create',
          values: {},
        );
        await store.markOperationProcessing(id);

        // Mientras está 'processing', no debe aparecer como pendiente.
        expect(await store.getPendingOperations(), isEmpty);

        // AppDatabase.beforeOpen (database.dart) hace este mismo reset en
        // cada apertura de la BD real; acá lo simulamos para el store en
        // memoria.
        store.simulateAppRestartRecovery();

        final pending = await store.getPendingOperations();
        expect(pending, hasLength(1));
        expect(pending.first.id, equals(id));
      });

      test(
        'recovered unsafe create is dead-lettered without dispatch',
        () async {
          final id = await store.queueOperation(
            model: 'test.model',
            method: 'create',
            values: const {},
            replayPolicy: OfflineReplayPolicy.manualAfterAmbiguous,
          );
          await store.markOperationProcessing(id);
          store.simulateAppRestartRecovery();

          var handlerCalls = 0;
          final processor = OfflineQueueProcessor(
            queue: store,
            handler: (_) async {
              handlerCalls++;
              return null;
            },
          );

          final result = await processor.processQueue();

          expect(handlerCalls, 0);
          expect(result.failed, 1);
          expect(store.statusOf(id), 'dead_letter');
          await processor.shutdown();
        },
      );

      test(
        'shutdown waits for the active writer and rejects new work',
        () async {
          await store.queueOperation(
            model: 'sale.order',
            method: 'write',
            recordId: 7,
            values: const {'name': 'SO7'},
            replayPolicy: OfflineReplayPolicy.retrySafe,
          );
          final entered = Completer<void>();
          final release = Completer<void>();
          final processor = OfflineQueueProcessor(
            queue: store,
            handler: (_) async {
              entered.complete();
              await release.future;
              return null;
            },
          );

          final run = processor.processQueue();
          await entered.future;
          var shutdownFinished = false;
          final shutdown = processor.shutdown().then((_) {
            shutdownFinished = true;
          });
          await Future<void>.delayed(Duration.zero);
          expect(shutdownFinished, isFalse);

          release.complete();
          await Future.wait([run, shutdown]);
          expect(shutdownFinished, isTrue);
          await expectLater(
            processor.processQueue(),
            throwsA(isA<StateError>()),
          );
        },
      );
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

        expect(
          events.any((e) => e.status == SyncOperationStatus.conflict),
          isTrue,
        );

        processor.dispose();
      });

      test('emits failed event with error message', () async {
        await store.queueOperation(model: 'test', method: 'create', values: {});

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
        expect(
          auditLogger.logs.first['errorMessage'],
          contains('Record deleted'),
        );

        processor.dispose();
      });

      test('logs errors', () async {
        await store.queueOperation(
          model: 'test',
          method: 'create',
          values: {},
          replayPolicy: OfflineReplayPolicy.retrySafe,
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
        expect(
          auditLogger.logs.first['errorMessage'],
          contains('Database error'),
        );

        processor.dispose();
      });
    });

    group('configuration options', () {
      test('removeOnSuccess defaults to true', () async {
        await store.queueOperation(model: 'test', method: 'create', values: {});

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => null,
        );

        await processor.processQueue();

        expect(await store.getPendingCount(), equals(0));

        processor.dispose();
      });

      test('removeOnSuccess=false keeps operations', () async {
        await store.queueOperation(model: 'test', method: 'create', values: {});

        final processor = OfflineQueueProcessor(
          queue: store,
          handler: (op) async => null,
          removeOnSuccess: false,
        );

        await processor.processQueue();

        expect(await store.getPendingCount(), equals(0));
        expect(store.statusOf(1), 'completed');

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
      expect(
        RetryBackoff.getNextRetryDelay(1),
        equals(const Duration(seconds: 30)),
      );
      expect(
        RetryBackoff.getNextRetryDelay(2),
        equals(const Duration(minutes: 2)),
      );
      expect(
        RetryBackoff.getNextRetryDelay(3),
        equals(const Duration(minutes: 10)),
      );
      expect(
        RetryBackoff.getNextRetryDelay(4),
        equals(const Duration(minutes: 30)),
      );
      expect(
        RetryBackoff.getNextRetryDelay(5),
        equals(const Duration(hours: 1)),
      );
      expect(
        RetryBackoff.getNextRetryDelay(10),
        equals(const Duration(hours: 1)),
      );
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
