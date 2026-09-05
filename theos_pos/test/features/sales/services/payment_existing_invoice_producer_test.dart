import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show OfflineReplayPolicy;
import 'package:theos_pos/core/services/odoo_service.dart';
import 'package:theos_pos/features/sales/services/payment_line_persistence_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

void main() {
  test(
    'producer atomically stores existing-invoice collection and one outbox',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.db.close);

      final id = await fixture.service.collectExistingInvoiceOffline(
        saleOrderId: 42,
        invoiceId: 901,
        collectionSessionId: 8,
        operatorId: 23,
        operationUuid: 'receipt-42',
        lines: [fixture.line(amount: 20, uuid: 'line-42')],
      );

      expect(id, greaterThan(0));
      expect(await fixture.residual(901), 0);
      expect(await fixture.payments(), hasLength(1));
      expect(await fixture.lines(), hasLength(1));
      expect(await fixture.queue.getPendingCount(), 1);
    },
  );

  test('retry exact UUID is idempotent', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.db.close);
    final line = fixture.line(amount: 20, uuid: 'line-42');

    await fixture.collect(operationUuid: 'receipt-42', lines: [line]);
    final retry = await fixture.collect(
      operationUuid: 'receipt-42',
      lines: [line],
    );

    expect(retry, isTrue);
    expect(await fixture.payments(), hasLength(1));
    expect(await fixture.lines(), hasLength(1));
    expect(await fixture.queue.getPendingCount(), 1);
    expect(await fixture.residual(901), 0);
  });

  test('same operation UUID rejects changed payload, invoice, or session without mutation', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.db.close);
    final original = fixture.line(amount: 5, uuid: 'line-original');
    expect(
      await fixture.collect(operationUuid: 'same-operation', lines: [original]),
      isTrue,
    );
    final originalPayments = await fixture.payments();
    final originalLines = await fixture.lines();

    expect(
      await fixture.collect(
        operationUuid: 'same-operation',
        lines: [fixture.line(amount: 6, uuid: 'line-original')],
      ),
      isFalse,
    );
    expect(
      await fixture.collect(
        operationUuid: 'same-operation',
        invoiceId: 902,
        lines: [original],
      ),
      isFalse,
    );
    expect(
      await fixture.collect(
        operationUuid: 'same-operation',
        collectionSessionId: 9,
        lines: [original],
      ),
      isFalse,
    );

    expect(await fixture.residual(901), 15);
    expect(await fixture.residual(902), 20);
    expect(await fixture.payments(), originalPayments);
    expect(await fixture.lines(), originalLines);
    expect(await fixture.queue.getPendingCount(), 1);
  });

  test('concurrent collections cannot exceed or overwrite residual', () async {
    final fixture = await _Fixture.create();
    addTearDown(fixture.db.close);

    final results = await Future.wait([
      fixture.collect(
        operationUuid: 'concurrent-a',
        lines: [fixture.line(amount: 15, uuid: 'concurrent-line-a')],
      ),
      fixture.collect(
        operationUuid: 'concurrent-b',
        lines: [fixture.line(amount: 15, uuid: 'concurrent-line-b')],
      ),
    ]);

    expect(results.where((accepted) => accepted), hasLength(1));
    expect(await fixture.residual(901), 5);
    expect(await fixture.payments(), hasLength(1));
    expect(await fixture.lines(), hasLength(1));
    expect(await fixture.queue.getPendingCount(), 1);
  });

  test('queue failure rolls back invoice, ledger, lines, and outbox', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final fixture = await _Fixture.create(
      db: db,
      queue: _FailingOfflineQueue(db),
    );
    addTearDown(db.close);

    final accepted = await fixture.collect(
      operationUuid: 'queue-fails',
      lines: [fixture.line(amount: 10, uuid: 'queue-fails-line')],
    );

    expect(accepted, isFalse);
    expect(await fixture.residual(901), 20);
    expect(await fixture.payments(), isEmpty);
    expect(await fixture.lines(), isEmpty);
    expect(await db.select(db.offlineQueue).get(), isEmpty);
  });

  test(
    'line UUID owned by another operation is rejected without overwrite',
    () async {
      final fixture = await _Fixture.create();
      addTearDown(fixture.db.close);
      await fixture.db
          .into(fixture.db.saleOrderPaymentLine)
          .insert(
            SaleOrderPaymentLineCompanion.insert(
              lineUuid: const Value('already-owned'),
              orderId: 42,
              paymentType: const Value('inbound'),
              amount: const Value(3),
              paymentReference: const Value('original-owner'),
            ),
          );

      final accepted = await fixture.collect(
        operationUuid: 'new-operation',
        lines: [fixture.line(amount: 10, uuid: 'already-owned')],
      );

      expect(accepted, isFalse);
      expect(await fixture.residual(901), 20);
      expect(await fixture.payments(), isEmpty);
      expect(await fixture.queue.getPendingCount(), 0);
      final persisted = await fixture.db
          .select(fixture.db.saleOrderPaymentLine)
          .getSingle();
      expect(persisted.amount, 3);
      expect(persisted.paymentReference, 'original-owner');
    },
  );
}

class _Fixture {
  _Fixture(this.db, this.queue)
    : service = PaymentLinePersistenceService(OdooService(), queue, db);

  final AppDatabase db;
  final OfflineQueueDataSource queue;
  final PaymentLinePersistenceService service;

  static Future<_Fixture> create({
    AppDatabase? db,
    OfflineQueueDataSource? queue,
  }) async {
    final database = db ?? AppDatabase(NativeDatabase.memory());
    final fixture = _Fixture(
      database,
      queue ?? OfflineQueueDataSource(database),
    );
    await fixture._seed();
    return fixture;
  }

  Future<void> _seed() async {
    await db
        .into(db.saleOrder)
        .insert(
          SaleOrderCompanion.insert(
            odooId: 42,
            name: 'SO42',
            companyId: const Value(7),
          ),
        );
    for (final invoiceId in [901, 902]) {
      await db
          .into(db.accountMove)
          .insert(
            AccountMoveCompanion.insert(
              odooId: invoiceId,
              moveType: 'out_invoice',
              saleOrderId: const Value(42),
              state: const Value('posted'),
              companyId: const Value(7),
              currencyId: const Value(1),
              amountResidual: const Value(20),
              amountTotal: const Value(20),
            ),
          );
    }
    await db
        .into(db.collectionConfig)
        .insert(
          CollectionConfigCompanion.insert(
            odooId: 5,
            name: 'Caja',
            companyId: 7,
            allowedJournalIds: const Value('[4]'),
          ),
        );
    for (final sessionId in [8, 9]) {
      await db
          .into(db.collectionSession)
          .insert(
            CollectionSessionCompanion.insert(
              odooId: sessionId,
              sessionUuid: 's$sessionId',
              name: 'S$sessionId',
              configId: 5,
              companyId: 7,
              userId: 23,
              currencyId: 1,
              startAt: DateTime(2026, 9, 5),
              state: const Value('opened'),
            ),
          );
    }
    await db
        .into(db.accountJournal)
        .insert(
          AccountJournalCompanion.insert(
            odooId: 4,
            name: 'Caja',
            code: 'CJ',
            type: 'cash',
            companyId: const Value(7),
          ),
        );
    await db
        .into(db.accountPaymentMethodLine)
        .insert(
          AccountPaymentMethodLineCompanion.insert(
            odooId: 6,
            name: 'Efectivo',
            paymentMethodId: 1,
            journalId: 4,
            paymentType: 'inbound',
          ),
        );
  }

  PaymentLine line({required double amount, required String uuid}) =>
      PaymentLine(
        type: PaymentLineType.payment,
        date: DateTime(2026, 9, 5),
        amount: amount,
        journalId: 4,
        paymentMethodLineId: 6,
        lineUuid: uuid,
      );

  Future<bool> collect({
    required String operationUuid,
    required List<PaymentLine> lines,
    int invoiceId = 901,
    int collectionSessionId = 8,
  }) => service.collectExistingInvoice(
    saleOrderId: 42,
    invoiceId: invoiceId,
    collectionSessionId: collectionSessionId,
    collectionOpUuid: operationUuid,
    lines: lines,
    operatorId: 23,
  );

  Future<double> residual(int invoiceId) async => (await (db.select(
    db.accountMove,
  )..where((row) => row.odooId.equals(invoiceId))).getSingle()).amountResidual;

  Future<List<AccountPaymentData>> payments() =>
      db.select(db.accountPaymentTable).get();

  Future<List<SaleOrderPaymentLineData>> lines() =>
      db.select(db.saleOrderPaymentLine).get();
}

class _FailingOfflineQueue extends OfflineQueueDataSource {
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
  }) => throw StateError('forced queue failure');
}
