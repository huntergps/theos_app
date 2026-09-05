import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/core/managers/manager_providers.dart';
import 'package:theos_pos/features/collection/repositories/collection_repository.dart';
import 'package:theos_pos/features/sync/services/offline_sync_service.dart';
import 'package:theos_pos/features/users/repositories/user_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    hide DatabaseHelper, OfflineOperation;

import '../../../mocks/mock_odoo_client.dart';

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

class _MockUserRepository extends Mock implements UserRepository {}

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
  }) => throw StateError('simulated collection outbox failure');
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

CollectionRepository _repository(
  AppDatabase database,
  OfflineQueueDataSource queue, {
  OdooClient? client,
}) => CollectionRepository(
  odooClient: client,
  db: _MockDatabaseHelper(),
  userRepository: _MockUserRepository(),
  sessionManager: collectionSessionManager,
  paymentManager: accountPaymentManager,
  cashOutManager: cashOutManager,
  sessionCashManager: collectionSessionCashManager,
  sessionDepositManager: collectionSessionDepositManager,
  offlineQueue: queue,
);

const _localSessionId = -4101;
const _remoteSessionId = 14101;
const _sessionUuid = 'collection-session-restart-key';

CollectionSession _session({
  int id = _localSessionId,
  SessionState state = SessionState.opened,
}) => CollectionSession(
  id: id,
  name: 'Sesión durable',
  state: state,
  sessionUuid: _sessionUuid,
  configId: 7,
  companyId: 1,
  userId: 42,
  currencyId: 1,
  startAt: DateTime.utc(2026, 8, 26),
  isSynced: false,
);

void main() {
  test('session transition rolls back when its outbox insert fails', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final queue = _FailingOfflineQueue(database);
    await initializeModelManagers(db: database, queueStore: queue);
    await collectionSessionManager.upsertLocal(_session(id: 701));
    final repository = _repository(database, queue);

    await expectLater(
      repository.startSessionClosingControlOffline(701, 25),
      throwsA(isA<StateError>()),
    );

    final persisted = await collectionSessionManager.readLocal(701);
    expect(persisted?.state, SessionState.opened);
    expect(persisted?.cashRegisterBalanceEndReal, 0);
    expect(await database.select(database.offlineQueue).get(), isEmpty);
    resetModelManagersSession();
    await database.close();
  });

  test('deposit snapshot rolls back when its outbox insert fails', () async {
    final database = AppDatabase(NativeDatabase.memory());
    final queue = _FailingOfflineQueue(database);
    await initializeModelManagers(db: database, queueStore: queue);
    final repository = _repository(database, queue);

    final result = await repository.createDeposit(
      CollectionSessionDeposit.create(
        collectionSessionId: 701,
        sessionUuid: _sessionUuid,
        depositDate: DateTime.utc(2026, 8, 26),
        amount: 25,
        bankJournalId: 8,
        notes: 'Debe revertirse con la cola',
      ),
    );

    expect(result.isLeft(), isTrue);
    expect(
      await database.select(database.collectionSessionDeposit).get(),
      isEmpty,
    );
    expect(await database.select(database.offlineQueue).get(), isEmpty);
    resetModelManagersSession();
    await database.close();
  });

  test(
    'deposit uses one durable queue writer and preserves its full snapshot',
    () async {
      final database = AppDatabase(NativeDatabase.memory());
      final queue = OfflineQueueDataSource(database);
      await initializeModelManagers(db: database, queueStore: queue);
      final client = MockOdooClient.online();
      final repository = _repository(database, queue, client: client);

      final result = await repository.createDeposit(
        CollectionSessionDeposit.create(
          collectionSessionId: 701,
          sessionUuid: _sessionUuid,
          depositDate: DateTime.utc(2026, 8, 26, 12),
          amount: 25,
          cashAmount: 10,
          checkAmount: 15,
          checkCount: 1,
          bankJournalId: 8,
          bankJournalName: 'Banco de prueba',
          notes: 'Snapshot completo',
        ),
      );

      expect(result.isRight(), isTrue);
      verifyNever(
        () => client.create(
          model: any(named: 'model'),
          values: any(named: 'values'),
        ),
      );
      final operations = await queue.getPendingOperations();
      expect(operations, hasLength(1));
      expect(operations.single.model, 'collection.session.deposit');
      expect(operations.single.replayPolicy, OfflineReplayPolicy.retrySafe);
      expect(operations.single.values, isNot(contains('session_uuid')));
      expect(operations.single.values, isNot(contains('bank_id')));
      expect(operations.single.values, isNot(contains('state')));

      final localId = operations.single.recordId!;
      final persisted = await collectionSessionDepositManager.readLocal(
        localId,
      );
      expect(persisted?.sessionUuid, _sessionUuid);
      expect(persisted?.bankJournalName, 'Banco de prueba');
      expect(persisted?.cashAmount, 10);
      expect(persisted?.checkAmount, 15);
      expect(persisted?.notes, 'Snapshot completo');
      resetModelManagersSession();
      await database.close();
    },
  );

  test(
    'restart consumes the session marker and atomically rewrites child IDs',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'theos-collection-restart-',
      );
      final file = File('${directory.path}/offline.sqlite');
      final firstDatabase = AppDatabase(NativeDatabase(file));
      final firstQueue = OfflineQueueDataSource(firstDatabase);
      await initializeModelManagers(db: firstDatabase, queueStore: firstQueue);
      await collectionSessionManager.upsertLocal(_session());
      await collectionSessionDepositManager.upsertLocal(
        CollectionSessionDeposit(
          id: -4201,
          uuid: 'deposit-child-restart-key',
          collectionSessionId: _localSessionId,
          sessionUuid: _sessionUuid,
          depositDate: DateTime.utc(2026, 8, 26),
          amount: 10,
          isSynced: false,
        ),
      );
      final parentOperationId = await firstQueue.queueCommand(
        model: 'collection.session',
        command: OfflineLocalCommand.sessionCreateAndOpen,
        recordId: _localSessionId,
        values: const {
          'local_id': _localSessionId,
          'config_id': 7,
          'user_id': 42,
          'cash_register_balance_start': 0.0,
          'session_uuid': _sessionUuid,
        },
        priority: OfflinePriority.critical,
      );
      await firstQueue.queueOperation(
        model: 'collection.session.deposit',
        method: 'create',
        recordId: -4201,
        values: const {
          'local_id': -4201,
          'uuid': 'deposit-child-restart-key',
          'collection_session_id': _localSessionId,
          'amount': 10.0,
        },
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      await firstQueue.markOperationProcessing(parentOperationId);
      await firstQueue.persistRemoteCreateId(
        parentOperationId,
        _remoteSessionId,
      );
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
          model: 'collection.session',
          domain: any(named: 'domain'),
          fields: const ['state'],
          limit: 1,
        ),
      ).thenAnswer(
        (_) async => const [
          {'state': 'opened'},
        ],
      );
      final service = OfflineSyncService(
        db: _MockDatabaseHelper(),
        appDb: restartedDatabase,
        odooClient: client,
        offlineQueue: restartedQueue,
        sessionManager: collectionSessionManager,
        paymentManager: accountPaymentManager,
        auditLogger: _NoopAuditLogger(),
      );

      final result = await service.processModelQueue('collection.session');

      expect(result.synced, 1);
      expect(result.errors, isEmpty);
      verifyNever(
        () => client.create(
          model: any(named: 'model'),
          values: any(named: 'values'),
        ),
      );
      verifyNever(
        () => client.call(
          model: any(named: 'model'),
          method: any(named: 'method'),
          ids: any(named: 'ids'),
          kwargs: any(named: 'kwargs'),
        ),
      );
      expect(
        await collectionSessionManager.readLocal(_remoteSessionId),
        isNotNull,
      );
      final deposit = await collectionSessionDepositManager.readLocal(-4201);
      expect(deposit?.collectionSessionId, _remoteSessionId);
      final childOperation = (await restartedQueue.getPendingOperations())
          .singleWhere(
            (operation) => operation.model == 'collection.session.deposit',
          );
      expect(childOperation.values['collection_session_id'], _remoteSessionId);

      await service.shutdown();
      resetModelManagersSession();
      await restartedDatabase.close();
      await directory.delete(recursive: true);
    },
  );
}
