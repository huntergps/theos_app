import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/core/managers/manager_providers.dart';
import 'package:theos_pos/features/sales/repositories/sales_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

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
  }) => throw StateError('simulated invoice outbox failure');
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
    'invoice and accounting rows roll back when outbox insert fails',
    () async {
      await database
          .into(database.accountJournal)
          .insert(
            AccountJournalCompanion.insert(
              odooId: 10,
              name: 'Ventas',
              code: 'VTA',
              type: 'sale',
              companyId: const Value(7),
              l10nEcEntity: const Value('001'),
              l10nEcEmission: const Value('001'),
              numberedByClient: const Value(true),
              lastInvoiceSequence: const Value(8),
            ),
          );
      await database
          .into(database.collectionConfig)
          .insert(
            CollectionConfigCompanion.insert(
              odooId: 20,
              name: 'Caja principal',
              companyId: 7,
              journalId: const Value(10),
            ),
          );
      await database
          .into(database.collectionSession)
          .insert(
            CollectionSessionCompanion.insert(
              odooId: 30,
              sessionUuid: 'session-atomic-42',
              name: 'Sesión 42',
              configId: 20,
              companyId: 7,
              userId: 23,
              currencyId: 1,
              startAt: DateTime(2026, 9, 5),
            ),
          );
      await companyManager.upsertLocal(
        const Company(id: 7, name: 'Emisor', vat: '1790011223001'),
      );
      await saleOrderManager.upsertLocal(
        const SaleOrder(
          id: 42,
          orderUuid: 'invoice-atomic-order-42',
          name: 'SO42',
          state: SaleOrderState.sale,
          partnerId: 99,
          partnerVat: '0999999999001',
          companyId: 7,
          collectionSessionId: 30,
          amountTotal: 10,
        ),
      );

      final repository = SalesRepository(
        db: _MockDatabaseHelper(),
        appDb: database,
        offlineQueue: queue,
      );

      await expectLater(
        repository.queueInvoiceWithPayments(
          saleOrderId: 42,
          paymentLines: const [],
          collectionSessionId: 30,
        ),
        throwsA(isA<StateError>()),
      );

      expect(await database.select(database.offlineInvoice).get(), isEmpty);
      expect(await database.select(database.accountMove).get(), isEmpty);
      expect(await database.select(database.accountMoveLine).get(), isEmpty);
      final journal = await (database.select(
        database.accountJournal,
      )..where((table) => table.odooId.equals(10))).getSingle();
      expect(journal.lastInvoiceSequence, 8);
      final order = await (database.select(
        database.saleOrder,
      )..where((table) => table.odooId.equals(42))).getSingle();
      expect(order.hasQueuedInvoice, isFalse);
    },
  );
}
