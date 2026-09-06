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

class _AuditLogger implements OfflineQueueAuditLogger {
  final operations = <String>[];

  @override
  Future<void> logConflict(OfflineOperation op, ConflictInfo conflict) async {}

  @override
  Future<void> logOperation(
    OfflineOperation op, {
    required String result,
    int? odooId,
    String? errorMessage,
  }) async {
    operations.add(result);
  }
}

void main() {
  late AppDatabase database;
  late OfflineQueueDataSource queue;
  late MockOdooClient client;
  late _AuditLogger audit;
  late OfflineSyncService service;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    queue = OfflineQueueDataSource(database);
    client = MockOdooClient.online();
    when(
      () => client.hasField(
        'l10n_ec_collection_box.sale.order.payment.wizard.line',
        'line_type',
      ),
    ).thenAnswer((_) async => true);
    audit = _AuditLogger();
    service = OfflineSyncService(
      db: _MockDatabaseHelper(),
      appDb: database,
      odooClient: client,
      offlineQueue: queue,
      sessionManager: collectionSessionManager,
      paymentManager: accountPaymentManager,
      auditLogger: audit,
    );
  });

  tearDown(() async {
    await service.shutdown();
    await database.close();
  });

  Future<void> insertPaymentLines() async {
    await database
        .into(database.saleOrderPaymentLine)
        .insert(
          SaleOrderPaymentLineCompanion.insert(
            orderId: 42,
            paymentType: const drift.Value('inbound'),
            journalId: const drift.Value(4),
            paymentMethodLineId: const drift.Value(6),
            amount: const drift.Value(10),
            date: drift.Value(DateTime(2026, 9, 5)),
            state: const drift.Value('draft'),
            lineUuid: const drift.Value('line-42'),
            isSynced: const drift.Value(false),
          ),
        );
    await database
        .into(database.accountPaymentTable)
        .insert(
          AccountPaymentCompanion.insert(
            paymentUuid: 'receipt-42:line-42',
            invoiceId: const drift.Value(901),
            saleId: const drift.Value(42),
            amount: const drift.Value(10),
            date: drift.Value(DateTime(2026, 9, 5)),
          ),
        );
    await database
        .into(database.saleOrderPaymentLine)
        .insert(
          SaleOrderPaymentLineCompanion.insert(
            orderId: 42,
            paymentType: const drift.Value('inbound'),
            amount: const drift.Value(5),
            state: const drift.Value('draft'),
            lineUuid: const drift.Value('line-other'),
            isSynced: const drift.Value(false),
          ),
        );
  }

  Future<int> enqueueCollection({
    String operationUuid = 'receipt-42',
    String lineUuid = 'line-42',
    double amount = 10.0,
  }) => queue.queueCommand(
    model: 'sale.order',
    command: OfflineLocalCommand.invoiceCollectExisting,
    parentOrderId: 42,
    values: {
      'sale_id': 42,
      'invoice_id': 901,
      'collection_session_id': 8,
      'collection_op_uuid': operationUuid,
      'payment_lines': [
        {
          'amount': amount,
          'journal_id': 4,
          'payment_method_line_id': 6,
          'date': '2026-09-05',
        },
      ],
      'payment_line_uuids': [lineUuid],
    },
  );

  void stubWizard({required Map<String, dynamic> result}) {
    when(
      () => client.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'create',
        ids: null,
        // ignore: deprecated_member_use
        args: null,
        kwargs: any(named: 'kwargs'),
      ),
    ).thenAnswer((_) async => 71);
    when(
      () => client.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'action_apply_existing_invoice',
        ids: [71],
        // ignore: deprecated_member_use
        args: null,
        kwargs: null,
      ),
    ).thenAnswer((_) async => result);
  }

  test(
    'collects existing invoice and syncs only its local payment line',
    () async {
      await insertPaymentLines();
      stubWizard(
        result: {
          'success': true,
          'operation_uuid': 'receipt-42',
          'invoice_id': 901,
          'payment_line_ids': [601],
          'payments': [
            {
              'line_uuid': 'line-42',
              'payment_line_id': 601,
              'payment_id': 701,
              'move_id': 801,
            },
          ],
          'amount_residual': 0.0,
        },
      );
      await enqueueCollection();

      final result = await service.processQueue();

      expect(result.errors, isEmpty);
      expect(result.synced, 1);
      expect(await queue.getPendingCount(), 0);
      final lines = await (database.select(
        database.saleOrderPaymentLine,
      )..where((row) => row.orderId.equals(42))).get();
      final matching = lines.singleWhere((row) => row.lineUuid == 'line-42');
      final unrelated = lines.singleWhere(
        (row) => row.lineUuid == 'line-other',
      );
      expect(matching.isSynced, isTrue);
      expect(matching.odooId, 601);
      expect(unrelated.isSynced, isFalse);
      expect(unrelated.odooId, isNull);
      final ledger =
          await (database.select(database.accountPaymentTable)
                ..where((row) => row.paymentUuid.equals('receipt-42:line-42')))
              .getSingle();
      expect(ledger.state, 'posted');
      expect(ledger.isSynced, isTrue);
      expect(ledger.odooId, 701);
      verifyNever(
        () => client.call(
          model: 'sale.order',
          method: 'action_apply_and_create_invoice',
          ids: any(named: 'ids'),
          // ignore: deprecated_member_use
          args: null,
          kwargs: any(named: 'kwargs'),
        ),
      );
    },
  );

  test(
    'retains collection when existing invoice response has no ledger metadata',
    () async {
      await insertPaymentLines();
      stubWizard(result: {'success': true, 'invoice_id': 901});
      final operationId = await enqueueCollection();

      final result = await service.processQueue();

      expect(result.synced, 0);
      expect(result.errors, hasLength(1));
      expect(audit.operations, hasLength(1));
      expect(await queue.getOperationById(operationId), isNotNull);
      expect(await queue.getPendingCount(), 1);
      final line = await (database.select(
        database.saleOrderPaymentLine,
      )..where((row) => row.lineUuid.equals('line-42'))).getSingle();
      expect(line.isSynced, isFalse);
      expect(line.odooId, isNull);
    },
  );

  test(
    'timeout after remote apply retries same UUID without duplicating ledger',
    () async {
      await insertPaymentLines();
      var applyCalls = 0;
      stubWizard(result: {'success': true, 'invoice_id': 901});
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'action_apply_existing_invoice',
          ids: [71],
          // ignore: deprecated_member_use
          args: null,
          kwargs: null,
        ),
      ).thenAnswer((_) async {
        applyCalls++;
        if (applyCalls == 1) throw const OdooTimeoutException();
        return {
          'success': true,
          'operation_uuid': 'receipt-42',
          'invoice_id': 901,
          'payment_line_ids': [601],
          'payments': [
            {
              'line_uuid': 'line-42',
              'payment_line_id': 601,
              'payment_id': 701,
              'move_id': 801,
            },
          ],
          'amount_residual': 0.0,
        };
      });
      final operationId = await enqueueCollection();

      final first = await service.processQueue();
      expect(first.errors, hasLength(1));
      expect(audit.operations, hasLength(1));
      expect(await queue.getOperationById(operationId), isNotNull);
      expect(await queue.getPendingCount(), 1);
      await queue.resetOperationRetry(operationId);

      final second = await service.processQueue();
      expect(second.errors, isEmpty);
      expect(second.synced, 1);
      expect(await queue.getOperationById(operationId), isNull);
      expect(await queue.getPendingCount(), 0);
      final createCalls = verify(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'create',
          ids: null,
          // ignore: deprecated_member_use
          args: null,
          kwargs: captureAny(named: 'kwargs'),
        ),
      ).captured;
      expect(createCalls, hasLength(2));
      for (final rawKwargs in createCalls) {
        final kwargs = rawKwargs as Map;
        final valsList = kwargs['vals_list'] as List;
        expect(
          (valsList.single as Map)['pos_collection_op_uuid'],
          'receipt-42',
        );
      }
      expect(applyCalls, 2);
      final line = await (database.select(
        database.saleOrderPaymentLine,
      )..where((row) => row.lineUuid.equals('line-42'))).getSingle();
      expect(line.odooId, 601);
      expect(line.isSynced, isTrue);
      final ledger = await (database.select(
        database.accountPaymentTable,
      )..where((row) => row.paymentUuid.equals('receipt-42:line-42'))).get();
      expect(ledger, hasLength(1));
      expect(ledger.single.odooId, 701);
      expect(ledger.single.isSynced, isTrue);
    },
  );

  test(
    'ACK for first of two collections preserves residual and pending ledger',
    () async {
      await insertPaymentLines();
      await database
          .into(database.accountMove)
          .insert(
            AccountMoveCompanion.insert(
              odooId: 901,
              moveType: 'out_invoice',
              state: const drift.Value('posted'),
              amountTotal: const drift.Value(20),
              amountResidual: const drift.Value(5),
            ),
          );
      await database
          .into(database.accountPaymentTable)
          .insert(
            AccountPaymentCompanion.insert(
              paymentUuid: 'receipt-other:line-other',
              invoiceId: const drift.Value(901),
              saleId: const drift.Value(42),
              amount: const drift.Value(5),
              date: drift.Value(DateTime(2026, 9, 5)),
            ),
          );
      var applyCalls = 0;
      stubWizard(result: const {});
      when(
        () => client.call(
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: 'action_apply_existing_invoice',
          ids: [71],
          // ignore: deprecated_member_use
          args: null,
          kwargs: null,
        ),
      ).thenAnswer((_) async {
        applyCalls++;
        if (applyCalls == 1) {
          return {
            'success': true,
            'operation_uuid': 'receipt-42',
            'invoice_id': 901,
            'payment_line_ids': [601],
            'payments': [
              {
                'line_uuid': 'line-42',
                'payment_line_id': 601,
                'payment_id': 701,
                'move_id': 801,
              },
            ],
            'amount_residual': 10.0,
          };
        }
        throw const OdooTimeoutException();
      });
      await enqueueCollection();
      final pendingId = await enqueueCollection(
        operationUuid: 'receipt-other',
        lineUuid: 'line-other',
        amount: 5,
      );

      final result = await service.processQueue();

      expect(result.synced, 1);
      expect(result.errors, hasLength(1));
      expect(await queue.getOperationById(pendingId), isNotNull);
      final invoice = await (database.select(
        database.accountMove,
      )..where((row) => row.odooId.equals(901))).getSingle();
      expect(invoice.amountResidual, 5);
      final ledger = await (database.select(
        database.accountPaymentTable,
      )..where((row) => row.invoiceId.equals(901))).get();
      expect(ledger, hasLength(2));
      final acknowledged = ledger.singleWhere(
        (row) => row.paymentUuid == 'receipt-42:line-42',
      );
      final pending = ledger.singleWhere(
        (row) => row.paymentUuid == 'receipt-other:line-other',
      );
      expect(acknowledged.odooId, 701);
      expect(acknowledged.isSynced, isTrue);
      expect(pending.odooId, isNull);
      expect(pending.isSynced, isFalse);
    },
  );

  test('payment_id false does not reconcile a normal payment ledger', () async {
    await insertPaymentLines();
    stubWizard(
      result: {
        'success': true,
        'operation_uuid': 'receipt-42',
        'invoice_id': 901,
        'payment_line_ids': [601],
        'payments': [
          {
            'line_uuid': 'line-42',
            'payment_line_id': 601,
            'payment_id': false,
            'move_id': 801,
          },
        ],
        'amount_residual': 0.0,
      },
    );
    final operationId = await enqueueCollection();

    final result = await service.processQueue();

    expect(result.synced, 0);
    expect(result.errors, hasLength(1));
    expect(await queue.getOperationById(operationId), isNotNull);
    final line = await (database.select(
      database.saleOrderPaymentLine,
    )..where((row) => row.lineUuid.equals('line-42'))).getSingle();
    expect(line.isSynced, isFalse);
    expect(line.odooId, isNull);
    final ledger =
        await (database.select(database.accountPaymentTable)
              ..where((row) => row.paymentUuid.equals('receipt-42:line-42')))
            .getSingle();
    expect(ledger.isSynced, isFalse);
    expect(ledger.odooId, isNull);
  });

  test(
    'rejects metadata correlated to a different remote payment line',
    () async {
      await insertPaymentLines();
      stubWizard(
        result: {
          'success': true,
          'operation_uuid': 'receipt-42',
          'invoice_id': 901,
          'payment_line_ids': [601],
          'payments': [
            {
              'line_uuid': 'line-42',
              'payment_line_id': 999,
              'payment_id': 701,
              'move_id': 801,
            },
          ],
          'amount_residual': 0.0,
        },
      );
      final operationId = await enqueueCollection();

      final result = await service.processQueue();
      expect(result.synced, 0);
      expect(result.errors, hasLength(1));
      expect(await queue.getOperationById(operationId), isNotNull);
      final line = await (database.select(
        database.saleOrderPaymentLine,
      )..where((row) => row.lineUuid.equals('line-42'))).getSingle();
      expect(line.isSynced, isFalse);
      final ledger =
          await (database.select(database.accountPaymentTable)
                ..where((row) => row.paymentUuid.equals('receipt-42:line-42')))
              .getSingle();
      expect(ledger.isSynced, isFalse);
    },
  );

  test(
    'correlates multiple payment media by UUID, not response order',
    () async {
      await insertPaymentLines();
      await database
          .into(database.accountPaymentTable)
          .insert(
            AccountPaymentCompanion.insert(
              paymentUuid: 'receipt-multi:line-42',
              invoiceId: const drift.Value(901),
              saleId: const drift.Value(42),
              amount: const drift.Value(10),
              date: drift.Value(DateTime(2026, 9, 5)),
            ),
          );
      await database
          .into(database.saleOrderPaymentLine)
          .insert(
            SaleOrderPaymentLineCompanion.insert(
              orderId: 42,
              paymentType: const drift.Value('inbound'),
              journalId: const drift.Value(4),
              paymentMethodLineId: const drift.Value(6),
              amount: const drift.Value(7),
              date: drift.Value(DateTime(2026, 9, 5)),
              state: const drift.Value('draft'),
              lineUuid: const drift.Value('line-43'),
              isSynced: const drift.Value(false),
            ),
          );
      await database
          .into(database.accountPaymentTable)
          .insert(
            AccountPaymentCompanion.insert(
              paymentUuid: 'receipt-multi:line-43',
              invoiceId: const drift.Value(901),
              saleId: const drift.Value(42),
              amount: const drift.Value(7),
              date: drift.Value(DateTime(2026, 9, 5)),
            ),
          );
      stubWizard(
        result: {
          'success': true,
          'operation_uuid': 'receipt-multi',
          'invoice_id': 901,
          'payment_line_ids': [602, 601],
          'payments': [
            {
              'line_uuid': 'line-43',
              'payment_line_id': 602,
              'payment_id': 702,
              'move_id': 802,
            },
            {
              'line_uuid': 'line-42',
              'payment_line_id': 601,
              'payment_id': 701,
              'move_id': 801,
            },
          ],
          'amount_residual': 3.0,
        },
      );
      await queue.queueCommand(
        model: 'sale.order',
        command: OfflineLocalCommand.invoiceCollectExisting,
        parentOrderId: 42,
        values: {
          'sale_id': 42,
          'invoice_id': 901,
          'collection_session_id': 8,
          'collection_op_uuid': 'receipt-multi',
          'payment_lines': [
            {
              'amount': 10.0,
              'journal_id': 4,
              'payment_method_line_id': 6,
              'date': '2026-09-05',
            },
            {
              'amount': 7.0,
              'journal_id': 4,
              'payment_method_line_id': 6,
              'date': '2026-09-05',
            },
          ],
          'payment_line_uuids': ['line-42', 'line-43'],
        },
      );

      final result = await service.processQueue();

      expect(result.errors, isEmpty);
      final lines = await database.select(database.saleOrderPaymentLine).get();
      expect(
        lines.singleWhere((line) => line.lineUuid == 'line-42').odooId,
        601,
      );
      expect(
        lines.singleWhere((line) => line.lineUuid == 'line-43').odooId,
        602,
      );
      final ledger = await database.select(database.accountPaymentTable).get();
      expect(
        ledger
            .singleWhere((row) => row.paymentUuid == 'receipt-multi:line-42')
            .odooId,
        701,
      );
      expect(
        ledger
            .singleWhere((row) => row.paymentUuid == 'receipt-multi:line-43')
            .odooId,
        702,
      );
      final createKwargs =
          verify(
                () => client.call(
                  model: 'l10n_ec_collection_box.sale.order.payment.wizard',
                  method: 'create',
                  ids: null,
                  // ignore: deprecated_member_use
                  args: null,
                  kwargs: captureAny(named: 'kwargs'),
                ),
              ).captured.single
              as Map;
      final commands =
          ((createKwargs['vals_list'] as List).single as Map)['line_ids']
              as List;
      expect(
        commands
            .map((command) => (command as List)[2] as Map)
            .map((values) => values['pos_collection_line_uuid']),
        ['line-42', 'line-43'],
      );
    },
  );

  test('legacy command without line UUIDs stays pending without RPC', () async {
    await insertPaymentLines();
    final operationId = await queue.queueCommand(
      model: 'sale.order',
      command: OfflineLocalCommand.invoiceCollectExisting,
      parentOrderId: 42,
      values: {
        'sale_id': 42,
        'invoice_id': 901,
        'collection_session_id': 8,
        'collection_op_uuid': 'legacy-without-lines',
        'payment_lines': [
          {
            'amount': 10.0,
            'journal_id': 4,
            'payment_method_line_id': 6,
            'date': '2026-09-05',
          },
        ],
      },
    );

    final result = await service.processQueue();

    expect(result.synced, 0);
    expect(result.errors, hasLength(1));
    expect(await queue.getOperationById(operationId), isNotNull);
    verifyNever(
      () => client.call(
        model: any(named: 'model'),
        method: any(named: 'method'),
        ids: any(named: 'ids'),
        // ignore: deprecated_member_use
        args: any(named: 'args'),
        kwargs: any(named: 'kwargs'),
      ),
    );
  });
}
