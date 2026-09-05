import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/core/managers/manager_providers.dart';
import 'package:theos_pos/features/sync/services/offline_sync_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    hide DatabaseHelper, OfflineOperation;

import '../../../mocks/mock_odoo_client.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

class _NoopAuditLogger implements OfflineQueueAuditLogger {
  @override
  Future<void> logConflict(OfflineOperation op, ConflictInfo conflict) async {}

  @override
  Future<void> logOperation(
    OfflineOperation op, {
    required String result,
    int? odooId,
    String? errorMessage,
  }) async {}
}

void main() {
  late AppDatabase database;
  late OfflineQueueDataSource queue;
  late MockOdooClient client;
  late OfflineSyncService service;
  late Directory temporaryDirectory;
  late File databaseFile;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'offline-sale-confirm-',
    );
    databaseFile = File('${temporaryDirectory.path}/offline.sqlite');
    database = AppDatabase(NativeDatabase(databaseFile));
    queue = OfflineQueueDataSource(database);
    client = MockOdooClient.online();
    await initializeModelManagers(
      client: client,
      db: database,
      queueStore: queue,
    );
    service = OfflineSyncService(
      db: _MockDatabaseHelper(),
      appDb: database,
      odooClient: client,
      offlineQueue: queue,
      sessionManager: collectionSessionManager,
      paymentManager: accountPaymentManager,
      auditLogger: _NoopAuditLogger(),
    );
    await saleOrderManager.upsertLocal(
      const SaleOrder(id: 42, name: 'SO42', state: SaleOrderState.approved),
    );
    await saleOrderManager.updateSaleOrderState(
      42,
      state: 'approved',
      pendingConfirm: true,
    );
  });

  tearDown(() async {
    await service.shutdown();
    resetModelManagersSession();
    await database.close();
    await temporaryDirectory.delete(recursive: true);
  });

  Future<int> enqueueConfirmation() => queue.queueCommand(
    model: 'sale.order',
    command: OfflineLocalCommand.orderConfirm,
    recordId: 42,
    parentOrderId: 42,
    values: const {'local_id': 42, 'order_id': 42, 'order_uuid': 'order-42'},
    replayPolicy: OfflineReplayPolicy.retrySafe,
  );

  void stubRemoteState({String state = 'approved'}) {
    when(
      () => client.searchRead(
        model: 'sale.order',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer(
      (_) async => [
        {'state': state},
      ],
    );
  }

  test('HTTP 200 success closes pending confirmation', () async {
    stubRemoteState();
    when(
      () => client.call(
        model: 'sale.order',
        method: 'action_pos_confirm',
        ids: [42],
      ),
    ).thenAnswer(
      (_) async => const {'success': true, 'order_id': 42, 'state': 'sale'},
    );
    final operationId = await enqueueConfirmation();

    final result = await service.processQueue();

    expect(result.synced, 1);
    expect(result.errors, isEmpty);
    expect(await queue.getOperationById(operationId), isNull);
    final row = await (database.select(
      database.saleOrder,
    )..where((table) => table.odooId.equals(42))).getSingle();
    expect(row.pendingConfirm, isFalse);
    verify(
      () => client.call(
        model: 'sale.order',
        method: 'action_pos_confirm',
        ids: [42],
      ),
    ).called(1);
  });

  test('restart replays durable confirmation exactly once', () async {
    stubRemoteState();
    when(
      () => client.call(
        model: 'sale.order',
        method: 'action_pos_confirm',
        ids: [42],
      ),
    ).thenAnswer(
      (_) async => const {'success': true, 'order_id': 42, 'state': 'sale'},
    );
    final operationId = await enqueueConfirmation();
    expect(
      (await queue.getOperationById(operationId))?.status,
      isNot(OfflineOperationStatus.completed),
    );

    await service.shutdown();
    await database.close();
    resetModelManagersSession();

    client = MockOdooClient.online();
    database = AppDatabase(NativeDatabase(databaseFile));
    queue = OfflineQueueDataSource(database);
    await initializeModelManagers(
      client: client,
      db: database,
      queueStore: queue,
    );
    service = OfflineSyncService(
      db: _MockDatabaseHelper(),
      appDb: database,
      odooClient: client,
      offlineQueue: queue,
      sessionManager: collectionSessionManager,
      paymentManager: accountPaymentManager,
      auditLogger: _NoopAuditLogger(),
    );
    stubRemoteState();
    when(
      () => client.call(
        model: 'sale.order',
        method: 'action_pos_confirm',
        ids: [42],
      ),
    ).thenAnswer(
      (_) async => const {'success': true, 'order_id': 42, 'state': 'sale'},
    );

    final result = await service.processQueue();
    expect(result.synced, 1);
    expect(await queue.getOperationById(operationId), isNull);
    final row = await (database.select(
      database.saleOrder,
    )..where((table) => table.odooId.equals(42))).getSingle();
    expect(row.pendingConfirm, isFalse);
    verify(
      () => client.call(
        model: 'sale.order',
        method: 'action_pos_confirm',
        ids: [42],
      ),
    ).called(1);
  });

  test(
    'replay reconciles remote sale without duplicate confirmation',
    () async {
      stubRemoteState(state: 'sale');
      final operationId = await enqueueConfirmation();

      final result = await service.processQueue();
      expect(result.synced, 1);
      expect(await queue.getOperationById(operationId), isNull);
      final row = await (database.select(
        database.saleOrder,
      )..where((table) => table.odooId.equals(42))).getSingle();
      expect(row.pendingConfirm, isFalse);
      verifyNever(
        () => client.call(
          model: 'sale.order',
          method: 'action_pos_confirm',
          ids: [42],
        ),
      );
    },
  );

  test(
    'HTTP 200 success false retains pending confirmation and evidence',
    () async {
      stubRemoteState();
      when(
        () => client.call(
          model: 'sale.order',
          method: 'action_pos_confirm',
          ids: [42],
        ),
      ).thenAnswer(
        (_) async => const {
          'success': false,
          'error': 'credit approval required',
          'credit_issue': {'type': 'overdue_debt'},
        },
      );
      final operationId = await enqueueConfirmation();

      final result = await service.processQueue();

      expect(result.synced, 0);
      expect(result.failed, 1);
      expect(result.errors, isNotEmpty);
      final retained = await queue.getOperationById(operationId);
      expect(retained, isNotNull);
      expect(retained!.status, isNot(OfflineOperationStatus.completed));
      final row = await (database.select(
        database.saleOrder,
      )..where((table) => table.odooId.equals(42))).getSingle();
      expect(row.pendingConfirm, isTrue);
      verify(
        () => client.call(
          model: 'sale.order',
          method: 'action_pos_confirm',
          ids: [42],
        ),
      ).called(1);

      // A restart must preserve the rejected approval operation and evidence.
      await service.shutdown();
      await database.close();
      resetModelManagersSession();
      client = MockOdooClient.online();
      database = AppDatabase(NativeDatabase(databaseFile));
      queue = OfflineQueueDataSource(database);
      await initializeModelManagers(
        client: client,
        db: database,
        queueStore: queue,
      );
      service = OfflineSyncService(
        db: _MockDatabaseHelper(),
        appDb: database,
        odooClient: client,
        offlineQueue: queue,
        sessionManager: collectionSessionManager,
        paymentManager: accountPaymentManager,
        auditLogger: _NoopAuditLogger(),
      );
      expect(await queue.getOperationById(operationId), isNotNull);
      final restartedRow = await (database.select(
        database.saleOrder,
      )..where((table) => table.odooId.equals(42))).getSingle();
      expect(restartedRow.pendingConfirm, isTrue);
    },
  );

  test(
    'HTTP 200 action response is not treated as confirmation success',
    () async {
      stubRemoteState();
      when(
        () => client.call(
          model: 'sale.order',
          method: 'action_pos_confirm',
          ids: [42],
        ),
      ).thenAnswer(
        (_) async => const {
          'type': 'ir.actions.act_window',
          'res_model': 'credit.limit.exceeded.wizard',
          'state': 'approved',
        },
      );
      final operationId = await enqueueConfirmation();

      final result = await service.processQueue();

      expect(result.synced, 0);
      expect(result.failed, 1);
      expect(await queue.getOperationById(operationId), isNotNull);
      final row = await (database.select(
        database.saleOrder,
      )..where((table) => table.odooId.equals(42))).getSingle();
      expect(row.pendingConfirm, isTrue);
    },
  );
}
