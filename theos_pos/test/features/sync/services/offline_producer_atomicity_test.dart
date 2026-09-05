import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/core/managers/manager_providers.dart';
import 'package:theos_pos/features/banks/repositories/bank_repository.dart';
import 'package:theos_pos/features/collection/repositories/collection_repository.dart';
import 'package:theos_pos/features/sales/repositories/sales_repository.dart';
import 'package:theos_pos/features/users/repositories/user_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

class _MockUserRepository extends Mock implements UserRepository {}

/// Uses the real Drift store for reads but simulates a disk failure exactly at
/// the outbox insert boundary.
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
  }) => throw StateError('simulated outbox write failure');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late _FailingOfflineQueue queue;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    queue = _FailingOfflineQueue(database);
    await initializeModelManagers(db: database, queueStore: queue);
  });

  tearDown(() async {
    resetModelManagersSession();
    await database.close();
  });

  test(
    'sale order row rolls back when its durable intent cannot be queued',
    () async {
      final repository = SalesRepository(
        db: _MockDatabaseHelper(),
        appDb: database,
        offlineQueue: queue,
      );

      final id = await repository.create(partnerId: 101);

      expect(id, isNull);
      expect(await database.select(database.saleOrder).get(), isEmpty);
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );

  test('sale order line insert rolls back when its durable intent cannot be queued', () async {
    final repository = SalesRepository(
      db: _MockDatabaseHelper(),
      appDb: database,
      offlineQueue: queue,
    );

    await expectLater(
      repository.addLine(
        77,
        const SaleOrderLine(
          id: -1,
          orderId: 77,
          productId: 9,
          name: 'Atomic line',
          productUomQty: 2,
          priceUnit: 15,
        ),
      ),
      throwsA(isA<StateError>()),
    );

    expect(await database.select(database.saleOrderLine).get(), isEmpty);
    expect(await database.select(database.offlineQueue).get(), isEmpty);
  });

  test('sale order line update rolls back when its durable intent cannot be queued', () async {
    const original = SaleOrderLine(
      id: 701,
      orderId: 77,
      lineUuid: 'line-update-atomicity',
      name: 'Original line',
      productUomQty: 1,
      priceUnit: 10,
      isSynced: true,
    );
    await saleOrderLineManager.upsertLocal(original);
    final repository = SalesRepository(
      db: _MockDatabaseHelper(),
      appDb: database,
      offlineQueue: queue,
    );

    await expectLater(
      repository.updateLine(701, {'product_uom_qty': 3.0}),
      throwsA(isA<StateError>()),
    );

    final row = await saleOrderLineManager.readLocal(701);
    expect(row, isNotNull);
    expect(row!.productUomQty, 1);
    expect(row.isSynced, isTrue);
    expect(await database.select(database.offlineQueue).get(), isEmpty);
  });

  test(
    'sale order line delete rolls back when its unlink cannot be queued',
    () async {
      const original = SaleOrderLine(
        id: 702,
        orderId: 77,
        lineUuid: 'line-delete-atomicity',
        name: 'Keep this line',
        productUomQty: 1,
        priceUnit: 10,
        isSynced: true,
      );
      await saleOrderLineManager.upsertLocal(original);
      final repository = SalesRepository(
        db: _MockDatabaseHelper(),
        appDb: database,
        offlineQueue: queue,
      );

      await expectLater(repository.deleteLine(702), throwsA(isA<StateError>()));

      expect(await saleOrderLineManager.readLocal(702), original);
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );

  test('collection session row rolls back when its durable command cannot be queued', () async {
    final repository = CollectionRepository(
      odooClient: null,
      db: _MockDatabaseHelper(),
      userRepository: _MockUserRepository(),
      sessionManager: collectionSessionManager,
      paymentManager: accountPaymentManager,
      cashOutManager: cashOutManager,
      sessionCashManager: collectionSessionCashManager,
      sessionDepositManager: collectionSessionDepositManager,
      offlineQueue: queue,
    );

    await expectLater(
      repository.createCollectionSessionOffline(
        configId: 7,
        userId: 42,
        cashRegisterBalanceStart: 50,
        sessionUuid: 'session-atomicity-test',
      ),
      throwsA(isA<StateError>()),
    );

    expect(await database.select(database.collectionSession).get(), isEmpty);
    expect(await database.select(database.offlineQueue).get(), isEmpty);
  });

  test(
    'partner bank row rolls back when its create cannot be queued',
    () async {
      final repository = BankRepository(db: database, offlineQueue: queue);

      final result = await repository.createPartnerBank(
        partnerId: 101,
        accNumber: 'TEST-001',
      );

      expect(result, isNull);
      expect(await database.select(database.resPartnerBank).get(), isEmpty);
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );

  test(
    'partner bank update rolls back when its durable intent cannot be queued',
    () async {
      final id = await database
          .into(database.resPartnerBank)
          .insert(
            ResPartnerBankCompanion.insert(
              odooId: 501,
              partnerId: 101,
              accNumber: 'ORIGINAL',
            ),
          );
      final repository = BankRepository(db: database, offlineQueue: queue);

      final updated = await repository.updatePartnerBank(
        id: id,
        accNumber: 'CHANGED',
      );

      expect(updated, isFalse);
      final row = await (database.select(
        database.resPartnerBank,
      )..where((table) => table.id.equals(id))).getSingle();
      expect(row.accNumber, 'ORIGINAL');
      expect(row.isSynced, isTrue);
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );

  test('partner bank soft delete rolls back when its durable intent cannot be queued', () async {
    final id = await database
        .into(database.resPartnerBank)
        .insert(
          ResPartnerBankCompanion.insert(
            odooId: 502,
            partnerId: 101,
            accNumber: 'KEEP-ME',
          ),
        );
    final repository = BankRepository(db: database, offlineQueue: queue);

    final deleted = await repository.deletePartnerBank(id);

    expect(deleted, isFalse);
    final row = await (database.select(
      database.resPartnerBank,
    )..where((table) => table.id.equals(id))).getSingle();
    expect(row.active, isTrue);
    expect(row.isSynced, isTrue);
    expect(await database.select(database.offlineQueue).get(), isEmpty);
  });

  test(
    'deleting a local-only partner bank removes its create intent durably',
    () async {
      final durableQueue = OfflineQueueDataSource(database);
      final repository = BankRepository(
        db: database,
        offlineQueue: durableQueue,
      );
      final created = await repository.createPartnerBank(
        partnerId: 101,
        accNumber: 'LOCAL-ONLY',
      );
      expect(created, isNotNull);
      expect(created!.odooId, isNegative);
      expect(await durableQueue.getPendingCount(), 1);
      final createIntent = await durableQueue.getOperationsForRecord(
        'res.partner.bank',
        created.odooId,
      );
      expect(createIntent.single.replayPolicy, OfflineReplayPolicy.retrySafe);

      final deleted = await repository.deletePartnerBank(created.id);

      expect(deleted, isTrue);
      final row = await (database.select(
        database.resPartnerBank,
      )..where((table) => table.id.equals(created.id))).getSingle();
      expect(row.active, isFalse);
      expect(await durableQueue.getPendingCount(), 0);
      expect(
        await durableQueue.getOperationsForRecord(
          'res.partner.bank',
          created.odooId,
        ),
        isEmpty,
      );
    },
  );

  test(
    'offline payment row rolls back when its durable command cannot be queued',
    () async {
      final repository = CollectionRepository(
        odooClient: null,
        db: _MockDatabaseHelper(),
        userRepository: _MockUserRepository(),
        sessionManager: collectionSessionManager,
        paymentManager: accountPaymentManager,
        cashOutManager: cashOutManager,
        sessionCashManager: collectionSessionCashManager,
        sessionDepositManager: collectionSessionDepositManager,
        offlineQueue: queue,
      );

      await expectLater(
        repository.createPaymentOffline(
          collectionSessionId: 10,
          partnerId: 101,
          journalId: 7,
          amount: 25,
          paymentUuid: 'payment-atomicity-test',
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        await database.select(database.accountPaymentTable).get(),
        isEmpty,
      );
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );

  test(
    'offline partner row rolls back when its durable command cannot be queued',
    () async {
      final repository = CollectionRepository(
        odooClient: null,
        db: _MockDatabaseHelper(),
        userRepository: _MockUserRepository(),
        sessionManager: collectionSessionManager,
        paymentManager: accountPaymentManager,
        cashOutManager: cashOutManager,
        sessionCashManager: collectionSessionCashManager,
        sessionDepositManager: collectionSessionDepositManager,
        offlineQueue: queue,
      );

      await expectLater(
        repository.createPartnerOffline(
          name: 'Atomic Partner',
          partnerUuid: 'partner-atomicity-test',
          vat: '0999999999001',
        ),
        throwsA(isA<StateError>()),
      );

      expect(await database.select(database.resPartner).get(), isEmpty);
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );

  test(
    'offline session cash row rolls back when its outbox write fails',
    () async {
      final repository = CollectionRepository(
        odooClient: null,
        db: _MockDatabaseHelper(),
        userRepository: _MockUserRepository(),
        sessionManager: collectionSessionManager,
        paymentManager: accountPaymentManager,
        cashOutManager: cashOutManager,
        sessionCashManager: collectionSessionCashManager,
        sessionDepositManager: collectionSessionDepositManager,
        offlineQueue: queue,
      );

      await expectLater(
        repository.saveSessionCash(
          CollectionSessionCash.newOpening(collectionSessionId: 10),
        ),
        throwsA(isA<StateError>()),
      );

      expect(
        await database.select(database.collectionSessionCash).get(),
        isEmpty,
      );
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );
}
