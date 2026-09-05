import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos/core/database/database_helper.dart';
import 'package:theos_pos/core/managers/manager_providers.dart';
import 'package:theos_pos/features/sales/repositories/sales_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

class _MockDatabaseHelper extends Mock implements DatabaseHelper {}

void main() {
  late AppDatabase database;
  late OfflineQueueDataSource queue;
  late SalesRepository repository;

  setUp(() async {
    database = AppDatabase(NativeDatabase.memory());
    queue = OfflineQueueDataSource(database);
    await initializeModelManagers(db: database, queueStore: queue);
    repository = SalesRepository(
      db: _MockDatabaseHelper(),
      appDb: database,
      offlineQueue: queue,
    );
  });

  tearDown(() async {
    resetModelManagersSession();
    await database.close();
  });

  Future<void> insertSriJournal({bool numberedByClient = true}) async {
    await collectionConfigManager.upsertLocal(
      const CollectionConfig(
        id: 5,
        name: 'Caja campo',
        code: 'CAMPO',
        companyId: 7,
        journalId: 10,
      ),
    );
    await collectionSessionManager.upsertLocal(
      CollectionSession(
        id: 15,
        sessionUuid: 'fiscal-test-session-15',
        userId: 23,
        currencyId: 1,
        startAt: DateTime(2026, 9, 5),
        name: 'Turno campo',
        state: SessionState.opened,
        configId: 5,
        companyId: 7,
      ),
    );
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
            numberedByClient: Value(numberedByClient),
          ),
        );
  }

  SaleOrder order({required int id, int? companyId}) => SaleOrder(
    id: id,
    orderUuid: 'order-$id-uuid',
    name: 'SO$id',
    state: SaleOrderState.sale,
    partnerId: 99,
    partnerName: 'Cliente',
    partnerVat: '0999999999001',
    companyId: companyId,
    amountTotal: 12.34,
  );

  test(
    'uses issuer company VAT, local environment, and one persisted fiscal date',
    () async {
      await insertSriJournal();
      await companyManager.upsertLocal(
        const Company(
          id: 7,
          name: 'Emisor local',
          vat: '1790011223001',
          l10nEcProductionEnv: true,
        ),
      );
      await saleOrderManager.upsertLocal(order(id: 42, companyId: 7));

      final invoice = await repository.queueInvoiceWithPayments(
        saleOrderId: 42,
        collectionSessionId: 15,
        paymentLines: const [],
      );

      expect(invoice, isNotNull);
      final key = invoice!.accessKey!;
      expect(key, hasLength(49));
      expect(key.substring(10, 23), '1790011223001');
      expect(key.substring(10, 23), isNot('0999999999001'));
      expect(key.substring(23, 24), '2');

      final persisted = await (database.select(
        database.offlineInvoice,
      )..where((t) => t.orderId.equals(42))).getSingle();
      final move = await (database.select(
        database.accountMove,
      )..where((t) => t.saleOrderId.equals(42))).getSingle();
      expect(persisted.invoiceDate, invoice.invoiceDate);
      expect(move.invoiceDate, invoice.invoiceDate);
      expect(
        key.substring(0, 8),
        '${invoice.invoiceDate!.day.toString().padLeft(2, '0')}'
        '${invoice.invoiceDate!.month.toString().padLeft(2, '0')}'
        '${invoice.invoiceDate!.year}',
      );

      final operation = (await queue.getOperationsForSaleOrder(42)).single;
      expect(
        operation.values['emission_date'],
        invoice.invoiceDate!.toIso8601String().split('T').first,
      );
    },
  );

  test(
    'refuses an invoice when the issuer company is unavailable locally',
    () async {
      await insertSriJournal();
      await saleOrderManager.upsertLocal(order(id: 43, companyId: 7));

      final invoice = await repository.queueInvoiceWithPayments(
        saleOrderId: 43,
        collectionSessionId: 15,
        paymentLines: const [],
      );

      expect(invoice, isNull);
      expect(await database.select(database.offlineInvoice).get(), isEmpty);
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );

  test(
    'regeneration persists the historical date encoded in the access key',
    () async {
      await insertSriJournal();
      await saleOrderManager.upsertLocal(order(id: 44, companyId: 7));
      final historicalDate = DateTime(2024, 2, 29);
      final name = SRIKeyGenerator.generateInvoiceName(
        entity: '001',
        emission: '001',
        sequence: 9,
      );
      final key = SRIKeyGenerator.generateAccessKey(
        date: historicalDate,
        documentType: '01',
        ruc: '1790011223001',
        environment: '1',
        emissionType: '1',
        invoiceName: name,
      );

      final invoice = await repository.queueInvoiceWithPayments(
        saleOrderId: 44,
        collectionSessionId: 15,
        paymentLines: const [],
        existingInvoiceName: name,
        existingAccessKey: key,
      );

      expect(invoice, isNotNull);
      expect(invoice!.invoiceDate, historicalDate);
      final persisted = await (database.select(
        database.offlineInvoice,
      )..where((t) => t.orderId.equals(44))).getSingle();
      final move = await (database.select(
        database.accountMove,
      )..where((t) => t.saleOrderId.equals(44))).getSingle();
      expect(persisted.invoiceDate, historicalDate);
      expect(move.invoiceDate, historicalDate);
      final operation = (await queue.getOperationsForSaleOrder(44)).single;
      expect(operation.values['emission_date'], '2024-02-29');
    },
  );

  test(
    'uses assigned journal even when a different SRI journal is first',
    () async {
      await database
          .into(database.accountJournal)
          .insert(
            AccountJournalCompanion.insert(
              odooId: 9,
              name: 'Otra empresa',
              code: 'OTHER',
              type: 'sale',
              companyId: const Value(99),
              l10nEcEntity: const Value('099'),
              l10nEcEmission: const Value('099'),
              lastInvoiceSequence: const Value(999),
            ),
          );
      await insertSriJournal();
      await companyManager.upsertLocal(
        const Company(id: 7, name: 'Emisor', vat: '1790011223001'),
      );
      await saleOrderManager.upsertLocal(order(id: 45, companyId: 7));
      final invoice = await repository.queueInvoiceWithPayments(
        saleOrderId: 45,
        collectionSessionId: 15,
        paymentLines: const [],
      );
      expect(invoice, isNotNull);
      expect(invoice!.invoiceName, '001-001-000000001');
      final move = await database.select(database.accountMove).getSingle();
      expect(move.journalId, 10);
      expect(move.companyId, 7);
    },
  );

  test(
    'refuses offline emission for a server-numbered journal without effects',
    () async {
      await insertSriJournal(numberedByClient: false);
      await companyManager.upsertLocal(
        const Company(id: 7, name: 'Emisor', vat: '1790011223001'),
      );
      await saleOrderManager.upsertLocal(order(id: 49, companyId: 7));

      final invoice = await repository.queueInvoiceWithPayments(
        saleOrderId: 49,
        collectionSessionId: 15,
        paymentLines: const [],
      );

      expect(invoice, isNull);
      expect(await database.select(database.offlineInvoice).get(), isEmpty);
      expect(await database.select(database.accountMove).get(), isEmpty);
      expect(await queue.getOperationsForSaleOrder(49), isEmpty);
      final journal = await (database.select(database.accountJournal)
            ..where((table) => table.odooId.equals(10)))
          .getSingle();
      expect(journal.lastInvoiceSequence, 0);
    },
  );

  test(
    'does not substitute another session when the assigned one is absent',
    () async {
      await insertSriJournal();
      await saleOrderManager.upsertLocal(order(id: 46, companyId: 7));
      final invoice = await repository.queueInvoiceWithPayments(
        saleOrderId: 46,
        collectionSessionId: -999,
        paymentLines: const [],
      );
      expect(invoice, isNull);
      expect(await database.select(database.offlineInvoice).get(), isEmpty);
      expect(await database.select(database.offlineQueue).get(), isEmpty);
    },
  );

  for (final (paid, residual, state) in [
    (0.0, 12.34, 'not_paid'),
    (5.0, 7.34, 'partial'),
    (12.34, 0.0, 'paid'),
  ]) {
    test('local payment state reflects applied amount $paid', () async {
      await insertSriJournal();
      await companyManager.upsertLocal(
        const Company(id: 7, name: 'Emisor', vat: '1790011223001'),
      );
      await saleOrderManager.upsertLocal(order(id: 47, companyId: 7));
      final invoice = await repository.queueInvoiceWithPayments(
        saleOrderId: 47,
        collectionSessionId: 15,
        paymentLines: [
          {'amount': paid},
        ],
      );
      expect(invoice, isNotNull);
      final move = await database.select(database.accountMove).getSingle();
      expect(move.amountResidual, closeTo(residual, 0.000001));
      expect(move.paymentState, state);
    });
  }

  test(
    'local withholding reduces residual without inventing a cash payment',
    () async {
      await insertSriJournal();
      await companyManager.upsertLocal(
        const Company(id: 7, name: 'Emisor', vat: '1790011223001'),
      );
      await saleOrderManager.upsertLocal(order(id: 48, companyId: 7));
      await database
          .into(database.saleOrderWithholdLine)
          .insert(
            SaleOrderWithholdLineCompanion.insert(
              orderId: 48,
              taxId: 1,
              taxName: 'Retención',
              withholdType: 'withhold_income_sale',
              amount: const Value(2.0),
            ),
          );
      final invoice = await repository.queueInvoiceWithPayments(
        saleOrderId: 48,
        collectionSessionId: 15,
        paymentLines: [
          {'amount': 10.34},
        ],
      );
      expect(invoice, isNotNull);
      final move = await database.select(database.accountMove).getSingle();
      expect(move.amountResidual, 0);
      expect(move.paymentState, 'paid');
    },
  );
}
