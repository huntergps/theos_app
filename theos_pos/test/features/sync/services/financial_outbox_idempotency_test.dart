import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/core/managers/manager_providers.dart';
import 'package:theos_pos/core/services/odoo_service.dart';
import 'package:theos_pos/features/advances/services/advance_service.dart';
import 'package:theos_pos/features/banks/repositories/bank_repository.dart';
import 'package:theos_pos/features/sales/services/cash_out_service.dart';
import 'package:theos_pos/features/sync/services/offline_sync_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    hide DatabaseHelper, OfflineOperation;

import '../../../mocks/mock_odoo_client.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

class _MockOdooService extends Mock implements OdooService {}

class _MockBankRepository extends Mock implements BankRepository {}

final class _FailingOfflineQueue extends OfflineQueueDataSource {
  _FailingOfflineQueue(super.db);

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
  }) => throw StateError('simulated financial outbox failure');
}

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

const _advanceLocalId = -201;
const _advanceRemoteId = 1201;
const _cashOutLocalId = -202;
const _cashOutRemoteId = 1202;

Advance _advance({int id = _advanceLocalId}) => Advance(
  id: id,
  advanceUuid: 'advance-idempotency-key',
  date: DateTime.utc(2026, 8, 26),
  advanceType: AdvanceType.inbound,
  partnerId: 7,
  reference: 'Referencia financiera de prueba 0001',
  amount: 25,
  amountAvailable: 25,
  lines: const [AdvanceLine(id: -1, journalId: 8, amount: 25)],
);

CashOut _cashOut({int id = _cashOutLocalId}) => CashOut(
  id: id,
  uuid: 'cash-out-idempotency-key',
  date: DateTime.utc(2026, 8, 26),
  journalId: 8,
  collectionSessionId: 9,
  amount: 15,
  typeCode: 'other',
  isSynced: false,
);

Future<void> _insertFinancialRows() async {
  await advanceManager.upsertLocalWithLines(_advance());
  await cashOutManager.upsertLocal(_cashOut());
}

Future<void> _queueFinancialCreates(OfflineQueueDataSource queue) async {
  await queue.queueOperation(
    model: 'account.advance',
    method: 'create',
    recordId: _advanceLocalId,
    values: const {
      'local_id': _advanceLocalId,
      'external_id': 'advance-idempotency-key',
      'partner_id': 7,
      'reference': 'Referencia financiera de prueba 0001',
      'advance_type': 'inbound',
      'amount': 25.0,
    },
    replayPolicy: OfflineReplayPolicy.retrySafe,
  );
  await queue.queueOperation(
    model: 'l10n_ec.cash.out',
    method: 'create',
    recordId: _cashOutLocalId,
    values: const {
      'local_id': _cashOutLocalId,
      'cash_out_uuid': 'cash-out-idempotency-key',
      'collection_session_id': 9,
      'journal_id': 8,
      'amount': 15.0,
    },
    replayPolicy: OfflineReplayPolicy.retrySafe,
  );
}

OfflineSyncService _syncService(
  AppDatabase database,
  OfflineQueueDataSource queue,
  MockOdooClient client,
) => OfflineSyncService(
  db: _MockDatabaseHelper(),
  appDb: database,
  odooClient: client,
  offlineQueue: queue,
  sessionManager: collectionSessionManager,
  paymentManager: accountPaymentManager,
  auditLogger: _NoopAuditLogger(),
);

void main() {
  test('advance snapshot rolls back when its outbox insert fails', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final queue = _FailingOfflineQueue(database);
    await initializeModelManagers(db: database, queueStore: queue);
    final odoo = _MockOdooService();
    when(() => odoo.client).thenReturn(null);
    final service = AdvanceService(odoo, _MockBankRepository(), queue);

    final result = await service.createAdvance(_advance(id: 0));

    expect(result.success, isFalse);
    expect(await database.select(database.accountAdvance).get(), isEmpty);
    expect(await database.select(database.offlineQueue).get(), isEmpty);
    resetModelManagersSession();
    await database.close();
  });

  test('cash-out snapshot rolls back when its outbox insert fails', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final queue = _FailingOfflineQueue(database);
    await initializeModelManagers(db: database, queueStore: queue);
    final odoo = _MockOdooService();
    when(() => odoo.client).thenReturn(null);
    final service = CashOutService(odoo, cashOutManager, queue, database);

    final result = await service.createCashOut(_cashOut(id: 0));

    expect(result.success, isFalse);
    expect(await database.select(database.cashOut).get(), isEmpty);
    expect(await database.select(database.offlineQueue).get(), isEmpty);
    resetModelManagersSession();
    await database.close();
  });

  test(
    'advance state rolls back when its action intent cannot be queued',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final queue = _FailingOfflineQueue(database);
      await initializeModelManagers(db: database, queueStore: queue);
      await advanceManager.upsertLocal(
        _advance(id: _advanceRemoteId).copyWith(state: AdvanceState.draft),
      );
      final odoo = _MockOdooService();
      when(() => odoo.client).thenReturn(null);
      final service = AdvanceService(odoo, _MockBankRepository(), queue);

      final result = await service.postAdvance(_advanceRemoteId);

      expect(result.success, isFalse);
      expect(
        (await advanceManager.readLocal(_advanceRemoteId))?.state,
        AdvanceState.draft,
      );
      expect(await database.select(database.offlineQueue).get(), isEmpty);
      resetModelManagersSession();
      await database.close();
    },
  );

  test(
    'cash-out state rolls back when its action intent cannot be queued',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final queue = _FailingOfflineQueue(database);
      await initializeModelManagers(db: database, queueStore: queue);
      await cashOutManager.upsertCashOut(
        _cashOut(id: _cashOutRemoteId).copyWith(state: CashOutState.draft),
      );
      final odoo = _MockOdooService();
      when(() => odoo.client).thenReturn(null);
      final service = CashOutService(odoo, cashOutManager, queue, database);

      final result = await service.confirmCashOut(_cashOutRemoteId);

      expect(result.success, isFalse);
      expect(
        (await cashOutManager.getByOdooId(_cashOutRemoteId))?.state,
        CashOutState.draft,
      );
      expect(await database.select(database.offlineQueue).get(), isEmpty);
      resetModelManagersSession();
      await database.close();
    },
  );

  test(
    'financial workflows persist markers and retry-safe action chains',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final queue = OfflineQueueDataSource(database);
      await initializeModelManagers(db: database, queueStore: queue);
      final odoo = _MockOdooService();
      when(() => odoo.client).thenReturn(null);

      final advanceResult = await AdvanceService(
        odoo,
        _MockBankRepository(),
        queue,
      ).createAndPostAdvance(_advance(id: 0));
      final cashOutResult = await CashOutService(
        odoo,
        cashOutManager,
        queue,
        database,
      ).createAndConfirmCashOut(_cashOut(id: 0));

      expect(advanceResult.success, isTrue);
      expect(cashOutResult.success, isTrue);
      final operations = await queue.getPendingOperations();
      expect(operations, hasLength(4));
      final advanceOp = operations.singleWhere(
        (operation) =>
            operation.model == 'account.advance' &&
            operation.method == 'create',
      );
      final cashOutOp = operations.singleWhere(
        (operation) =>
            operation.model == 'l10n_ec.cash.out' &&
            operation.method == 'create',
      );
      expect(advanceOp.values['external_id'], isNotEmpty);
      expect(cashOutOp.values['cash_out_uuid'], isNotEmpty);
      expect(advanceOp.replayPolicy, OfflineReplayPolicy.retrySafe);
      expect(cashOutOp.replayPolicy, OfflineReplayPolicy.retrySafe);
      final advanceAction = operations.singleWhere(
        (operation) => operation.method == 'action_post',
      );
      final cashOutAction = operations.singleWhere(
        (operation) => operation.method == 'action_confirm',
      );
      expect(advanceAction.replayPolicy, OfflineReplayPolicy.retrySafe);
      expect(cashOutAction.replayPolicy, OfflineReplayPolicy.retrySafe);
      expect(
        (await advanceManager.readLocal(advanceResult.advanceId!))?.state,
        AdvanceState.posted,
      );
      expect(
        (await cashOutManager.getByOdooId(cashOutResult.cashOutId!))?.state,
        CashOutState.posted,
      );
      resetModelManagersSession();
      await database.close();
    },
  );

  test(
    'restart reconciles committed financial creates without duplicate RPC',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'theos-financial-reconcile-',
      );
      final file = File('${directory.path}/offline.sqlite');
      final firstDatabase = AppDatabase(NativeDatabase(file));
      final firstQueue = OfflineQueueDataSource(firstDatabase);
      await initializeModelManagers(db: firstDatabase, queueStore: firstQueue);
      await _insertFinancialRows();
      await _queueFinancialCreates(firstQueue);
      resetModelManagersSession();
      await firstDatabase.close();

      final restartedDatabase = AppDatabase(NativeDatabase(file));
      final restartedQueue = OfflineQueueDataSource(restartedDatabase);
      await initializeModelManagers(
        db: restartedDatabase,
        queueStore: restartedQueue,
      );
      final client = MockOdooClient.online();
      when(
        () => client.searchRead(
          model: 'account.advance',
          domain: any(named: 'domain'),
          fields: const ['id'],
          limit: 1,
        ),
      ).thenAnswer(
        (_) async => const [
          {'id': _advanceRemoteId},
        ],
      );
      when(
        () => client.searchRead(
          model: 'l10n_ec.cash.out',
          domain: any(named: 'domain'),
          fields: const ['id'],
          limit: 1,
        ),
      ).thenAnswer(
        (_) async => const [
          {'id': _cashOutRemoteId},
        ],
      );
      final service = _syncService(restartedDatabase, restartedQueue, client);

      final result = await service.processQueue();

      expect(result.synced, 2);
      verifyNever(
        () => client.create(
          model: any(named: 'model'),
          values: any(named: 'values'),
        ),
      );
      expect(await advanceManager.readLocal(_advanceRemoteId), isNotNull);
      expect(
        (await advanceManager.readLocalWithLines(_advanceRemoteId))?.lines
            .map((line) => line.amount),
        [25.0],
      );
      final cashOut = await cashOutManager.getByOdooId(_cashOutRemoteId);
      expect(cashOut?.isSynced, isTrue);
      expect(await restartedQueue.getPendingCount(), 0);
      await service.shutdown();
      resetModelManagersSession();
      await restartedDatabase.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'financial create is sent once and remains complete after restart',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'theos-financial-once-',
      );
      final file = File('${directory.path}/offline.sqlite');
      final database = AppDatabase(NativeDatabase(file));
      final queue = OfflineQueueDataSource(database);
      await initializeModelManagers(db: database, queueStore: queue);
      await _insertFinancialRows();
      await _queueFinancialCreates(queue);
      final client = MockOdooClient.online();
      for (final model in const ['account.advance', 'l10n_ec.cash.out']) {
        when(
          () => client.searchRead(
            model: model,
            domain: any(named: 'domain'),
            fields: const ['id'],
            limit: 1,
          ),
        ).thenAnswer((_) async => const []);
      }
      when(
        () => client.create(
          model: 'account.advance',
          values: any(named: 'values'),
        ),
      ).thenAnswer((_) async => _advanceRemoteId);
      when(
        () => client.create(
          model: 'l10n_ec.cash.out',
          values: any(named: 'values'),
        ),
      ).thenAnswer((_) async => _cashOutRemoteId);
      final service = _syncService(database, queue, client);

      expect((await service.processQueue()).synced, 2);
      verify(
        () => client.create(
          model: 'account.advance',
          values: any(named: 'values'),
        ),
      ).called(1);
      expect(
        (await advanceManager.readLocalWithLines(_advanceRemoteId))?.lines
            .map((line) => line.amount),
        [25.0],
      );
      verify(
        () => client.create(
          model: 'l10n_ec.cash.out',
          values: any(named: 'values'),
        ),
      ).called(1);
      await service.shutdown();
      resetModelManagersSession();
      await database.close();
      clearInteractions(client);

      final restartedDatabase = AppDatabase(NativeDatabase(file));
      final restartedQueue = OfflineQueueDataSource(restartedDatabase);
      await initializeModelManagers(
        db: restartedDatabase,
        queueStore: restartedQueue,
      );
      final restartedService = _syncService(
        restartedDatabase,
        restartedQueue,
        client,
      );
      expect((await restartedService.processQueue()).isEmpty, isTrue);
      verifyNever(
        () => client.create(
          model: any(named: 'model'),
          values: any(named: 'values'),
        ),
      );
      await restartedService.shutdown();
      resetModelManagersSession();
      await restartedDatabase.close();
      await directory.delete(recursive: true);
    },
  );

  test(
    'recovered financial actions use server state instead of duplicate RPC',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'theos-financial-action-',
      );
      final file = File('${directory.path}/offline.sqlite');
      final firstDatabase = AppDatabase(NativeDatabase(file));
      final firstQueue = OfflineQueueDataSource(firstDatabase);
      final advanceAction = await firstQueue.queueOperation(
        model: 'account.advance',
        method: 'action_post',
        recordId: _advanceRemoteId,
        values: const {},
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      final cashOutAction = await firstQueue.queueOperation(
        model: 'l10n_ec.cash.out',
        method: 'action_confirm',
        recordId: _cashOutRemoteId,
        values: const {},
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      await firstQueue.markOperationProcessing(advanceAction);
      await firstQueue.markOperationProcessing(cashOutAction);
      await firstDatabase.close();

      final restartedDatabase = AppDatabase(NativeDatabase(file));
      final restartedQueue = OfflineQueueDataSource(restartedDatabase);
      await initializeModelManagers(
        db: restartedDatabase,
        queueStore: restartedQueue,
      );
      final client = MockOdooClient.online();
      when(
        () => client.searchRead(
          model: 'account.advance',
          domain: any(named: 'domain'),
          fields: const ['state'],
          limit: 1,
        ),
      ).thenAnswer(
        (_) async => const [
          {'state': 'posted'},
        ],
      );
      when(
        () => client.searchRead(
          model: 'l10n_ec.cash.out',
          domain: any(named: 'domain'),
          fields: const ['state'],
          limit: 1,
        ),
      ).thenAnswer(
        (_) async => const [
          {'state': 'posted'},
        ],
      );
      final service = _syncService(restartedDatabase, restartedQueue, client);

      final result = await service.processQueue();

      expect(result.synced, 2);
      verifyNever(
        () => client.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          ids: any(named: 'ids'),
        ),
      );
      expect(await restartedQueue.getPendingCount(), 0);
      await service.shutdown();
      resetModelManagersSession();
      await restartedDatabase.close();
      await directory.delete(recursive: true);
    },
  );
}
