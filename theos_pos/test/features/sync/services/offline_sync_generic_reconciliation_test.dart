import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/database_helper.dart';
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

const _models = <String, (int, int)>{
  'res.partner.bank': (-101, 1101),
  'collection.session.cash': (-102, 1102),
  'collection.session.deposit': (-103, 1103),
};

Future<void> _insertUnsyncedRows(AppDatabase database) async {
  await database
      .into(database.resPartnerBank)
      .insert(
        ResPartnerBankCompanion.insert(
          odooId: _models['res.partner.bank']!.$1,
          accNumber: 'TEST-001',
          partnerId: 7,
          isSynced: const drift.Value(false),
        ),
      );
  await database
      .into(database.collectionSessionCash)
      .insert(
        CollectionSessionCashCompanion.insert(
          odooId: _models['collection.session.cash']!.$1,
          collectionSessionId: 8,
          cashType: 'opening',
          isSynced: const drift.Value(false),
        ),
      );
  await database
      .into(database.collectionSessionDeposit)
      .insert(
        CollectionSessionDepositCompanion.insert(
          odooId: drift.Value(_models['collection.session.deposit']!.$1),
          collectionSessionId: 8,
          depositType: 'cash',
          depositDate: DateTime.utc(2026, 8, 26),
          isSynced: const drift.Value(false),
        ),
      );
}

Future<void> _expectSyncedRows(AppDatabase database) async {
  final bank =
      await (database.select(database.resPartnerBank)..where(
            (table) => table.odooId.equals(_models['res.partner.bank']!.$2),
          ))
          .getSingle();
  final cash =
      await (database.select(database.collectionSessionCash)..where(
            (table) =>
                table.odooId.equals(_models['collection.session.cash']!.$2),
          ))
          .getSingle();
  final deposit =
      await (database.select(database.collectionSessionDeposit)..where(
            (table) =>
                table.odooId.equals(_models['collection.session.deposit']!.$2),
          ))
          .getSingle();

  expect(bank.isSynced, isTrue);
  expect(cash.isSynced, isTrue);
  expect(cash.lastSyncDate, isNotNull);
  expect(deposit.isSynced, isTrue);
  expect(deposit.lastSyncDate, isNotNull);
}

OfflineSyncService _service(
  AppDatabase database,
  OfflineQueueDataSource queue,
  MockOdooClient client,
) {
  return OfflineSyncService(
    db: _MockDatabaseHelper(),
    appDb: database,
    odooClient: client,
    offlineQueue: queue,
    sessionManager: collectionSessionManager,
    paymentManager: accountPaymentManager,
    auditLogger: _NoopAuditLogger(),
  );
}

void main() {
  late Directory temporaryDirectory;
  late File databaseFile;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'theos-generic-reconcile-',
    );
    databaseFile = File('${temporaryDirectory.path}/offline.sqlite');
  });

  tearDown(() async {
    await temporaryDirectory.delete(recursive: true);
  });

  test(
    'generic creates reconcile local IDs and are not sent after restart',
    () async {
      final database = AppDatabase(NativeDatabase(databaseFile));
      final queue = OfflineQueueDataSource(database);
      await _insertUnsyncedRows(database);

      for (final entry in _models.entries) {
        await queue.queueOperation(
          model: entry.key,
          method: 'create',
          recordId: entry.value.$1,
          values: {'local_id': entry.value.$1, 'name': 'offline-test'},
        );
      }

      final client = MockOdooClient.online();
      for (final entry in _models.entries) {
        when(
          () => client.create(
            model: entry.key,
            values: any(named: 'values'),
          ),
        ).thenAnswer((_) async => entry.value.$2);
      }
      final service = _service(database, queue, client);

      final result = await service.processQueue();

      expect(result.synced, 3);
      expect(result.errors, isEmpty);
      await _expectSyncedRows(database);
      for (final entry in _models.entries) {
        verify(
          () => client.create(
            model: entry.key,
            values: any(named: 'values'),
          ),
        ).called(1);
      }
      await service.shutdown();
      await database.close();
      clearInteractions(client);

      final restartedDatabase = AppDatabase(NativeDatabase(databaseFile));
      final restartedQueue = OfflineQueueDataSource(restartedDatabase);
      final restartedService = _service(
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
      await _expectSyncedRows(restartedDatabase);
      await restartedService.shutdown();
      await restartedDatabase.close();
    },
  );

  test(
    'durable create hand-off resumes locally without duplicate RPC',
    () async {
      final database = AppDatabase(NativeDatabase(databaseFile));
      final queue = OfflineQueueDataSource(database);
      await _insertUnsyncedRows(database);

      for (final entry in _models.entries) {
        final operationId = await queue.queueOperation(
          model: entry.key,
          method: 'create',
          recordId: entry.value.$1,
          values: {'local_id': entry.value.$1, 'name': 'interrupted-test'},
        );
        await queue.markOperationProcessing(operationId);
        await queue.persistRemoteCreateId(operationId, entry.value.$2);
      }
      await database.close();

      final restartedDatabase = AppDatabase(NativeDatabase(databaseFile));
      final restartedQueue = OfflineQueueDataSource(restartedDatabase);
      final client = MockOdooClient.online();
      final service = _service(restartedDatabase, restartedQueue, client);

      final result = await service.processQueue();

      expect(result.synced, 3);
      expect(result.errors, isEmpty);
      verifyNever(
        () => client.create(
          model: any(named: 'model'),
          values: any(named: 'values'),
        ),
      );
      await _expectSyncedRows(restartedDatabase);
      expect(await restartedQueue.getPendingCount(), 0);
      await service.shutdown();
      await restartedDatabase.close();
    },
  );

  test(
    'generic creates reconcile by natural key before issuing create',
    () async {
      final database = AppDatabase(NativeDatabase(databaseFile));
      final queue = OfflineQueueDataSource(database);
      await _insertUnsyncedRows(database);

      await queue.queueOperation(
        model: 'res.partner.bank',
        method: 'create',
        recordId: _models['res.partner.bank']!.$1,
        values: {
          'local_id': _models['res.partner.bank']!.$1,
          'partner_id': 7,
          'account_number': 'TEST-001',
        },
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      await queue.queueOperation(
        model: 'collection.session.cash',
        method: 'create',
        recordId: _models['collection.session.cash']!.$1,
        values: {
          'local_id': _models['collection.session.cash']!.$1,
          'collection_session_id': 8,
          'cash_type': 'opening',
        },
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      await queue.queueOperation(
        model: 'collection.session.deposit',
        method: 'create',
        recordId: _models['collection.session.deposit']!.$1,
        values: {
          'local_id': _models['collection.session.deposit']!.$1,
          'uuid': 'deposit-natural-key',
        },
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );

      final client = MockOdooClient.online();
      for (final entry in _models.entries) {
        when(
          () => client.searchRead(
            model: entry.key,
            domain: any(named: 'domain'),
            fields: const ['id'],
            limit: 1,
          ),
        ).thenAnswer(
          (_) async => [
            {'id': entry.value.$2},
          ],
        );
      }
      final service = _service(database, queue, client);

      final result = await service.processQueue();

      expect(result.synced, 3);
      expect(result.errors, isEmpty);
      verifyNever(
        () => client.create(
          model: any(named: 'model'),
          values: any(named: 'values'),
        ),
      );
      await _expectSyncedRows(database);
      expect(await queue.getPendingCount(), 0);
      await service.shutdown();
      await database.close();
    },
  );

  test('successful generic writes mark local rows synced', () async {
    final database = AppDatabase(NativeDatabase(databaseFile));
    final queue = OfflineQueueDataSource(database);

    await database
        .into(database.resPartnerBank)
        .insert(
          ResPartnerBankCompanion.insert(
            odooId: 1101,
            accNumber: 'TEST-001',
            partnerId: 7,
            isSynced: const drift.Value(false),
          ),
        );
    await database
        .into(database.collectionSessionCash)
        .insert(
          CollectionSessionCashCompanion.insert(
            odooId: 1102,
            collectionSessionId: 8,
            cashType: 'opening',
            isSynced: const drift.Value(false),
          ),
        );
    await database
        .into(database.collectionSessionDeposit)
        .insert(
          CollectionSessionDepositCompanion.insert(
            odooId: const drift.Value(1103),
            collectionSessionId: 8,
            depositType: 'cash',
            depositDate: DateTime.utc(2026, 8, 26),
            isSynced: const drift.Value(false),
          ),
        );

    for (final entry in _models.entries) {
      await queue.queueOperation(
        model: entry.key,
        method: 'write',
        recordId: entry.value.$2,
        values: const {'name': 'updated'},
      );
    }
    final client = MockOdooClient.online();
    for (final entry in _models.entries) {
      when(
        () => client.write(
          model: entry.key,
          ids: [entry.value.$2],
          values: any(named: 'values'),
        ),
      ).thenAnswer((_) async => true);
    }
    final service = _service(database, queue, client);

    final result = await service.processQueue();

    expect(result.synced, 3);
    await _expectSyncedRows(database);
    await service.shutdown();
    await database.close();
  });
}
