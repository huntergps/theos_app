import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

final class _Actions implements SaleOdooActions {
  final calls = <String>[];
  final payloads = <Map<String, dynamic>>[];
  bool depositHasMove = true;
  String sessionState = 'opened';
  int paymentSearches = 0;
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    calls.add('$model.$method:${ids ?? []}');
    payloads.add({'model': model, 'method': method, 'kwargs': kwargs});
    if (model == 'collection.session' && method == 'search_read') {
      return [
        {'id': 8, 'state': sessionState},
      ];
    }
    if (model == 'collection.session' &&
        method == 'action_session_closing_control') {
      sessionState = 'closing_control';
    }
    if (model == 'collection.session' && method == 'action_session_close') {
      sessionState = 'closed';
    }
    if (method == 'create') return 501;
    if (method == 'search_read' && model == 'collection.session.deposit') {
      return [
        {
          'id': 501,
          'move_id': depositHasMove ? [22, 'MVE/1'] : false,
        },
      ];
    }
    if (model == 'l10n_ec_collection_box.sale.order.payment' &&
        method == 'search_read') {
      final domain = kwargs?['domain'];
      String? uuid;
      if (domain is List) {
        for (final raw in domain) {
          if (raw is List &&
              raw.length >= 3 &&
              raw[0] == 'pos_collection_op_uuid' &&
              raw[2] is String) {
            uuid = raw[2] as String;
          }
        }
      }
      if (uuid == null) return const <Map<String, dynamic>>[];
      if (paymentSearches++ == 0) return const <Map<String, dynamic>>[];
      return [
        {
          'id': 601,
          'sale_id': 42,
          'amount': 50.0,
          'state': 'posted',
          'move_id': [701, 'PAY/1'],
          'pos_collection_op_uuid': uuid,
          'pos_collection_line_uuid': '$uuid:payment:0',
        },
        {
          'id': 602,
          'sale_id': 42,
          'amount': 25.0,
          'state': 'posted',
          'move_id': [702, 'PAY/2'],
          'pos_collection_op_uuid': uuid,
          'pos_collection_line_uuid': '$uuid:payment:1',
        },
      ];
    }
    return const {'ok': true};
  }
}

void main() {
  test('collection producer rolls back payment rows when a native line insert fails', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await db
        .into(db.saleOrderWithholdLine)
        .insert(
          SaleOrderWithholdLineCompanion.insert(
            lineUuid: const drift.Value('rollback-withhold'),
            orderId: 42,
            taxId: 7,
            taxName: 'IVA retenido',
            withholdType: 'withhold_vat_sale',
            base: const drift.Value(100.0),
            amount: const drift.Value(10.0),
          ),
        );
    final queue = OfflineQueueDataSource(db);
    final producer = DurableCollectionProducer(db, queue);
    await expectLater(
      producer.enqueueCollectionIntent(
        commandId: 'rollback-collection',
        saleOrderId: 42,
        method: 'existingInvoice',
        amountMinor: 1000,
        paymentLines: const [
          DurablePaymentLineDraft(
            type: 'payment',
            amountMinor: 1000,
            journalId: 30,
          ),
        ],
        withholdLines: const [
          DurableWithholdLineDraft(
            uuid: 'rollback-withhold',
            taxId: 7,
            baseMinor: 10000,
            amountMinor: 1000,
          ),
        ],
      ),
      throwsA(isA<Exception>()),
    );
    expect(await db.select(db.saleOrderPaymentLine).get(), isEmpty);
    expect(await db.select(db.offlineQueue).get(), isEmpty);
  });

  test('cash-out and deposit snapshot plus outbox survive restart and dedupe', () async {
    final file = File(
      '${Directory.systemTemp.path}/orbi-u06-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final firstDb = AppDatabase(NativeDatabase(file));
    final firstQueue = OfflineQueueDataSource(firstDb);
    final producer = DurableCollectionProducer(firstDb, firstQueue);

    final cash = await producer.cashOut(
      commandId: 'cash-u06-1',
      sessionId: 8,
      journalId: 3,
      cashOutTypeId: 9,
      amountMinor: 1250,
      note: 'prueba',
    );
    final deposit = await producer.deposit(
      commandId: 'deposit-u06-1',
      sessionId: 8,
      bankJournalId: 4,
      depositType: 'cash',
      amountMinor: 2500,
      cashAmountMinor: 2500,
      checkAmountMinor: 0,
      accountingDate: '2026-09-07',
    );
    expect(cash.state, DurableCollectionState.queued);
    expect(deposit.state, DurableCollectionState.queued);
    await firstDb.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await reopened.close();
      if (file.existsSync()) await file.delete();
    });
    final queue = OfflineQueueDataSource(reopened);
    expect(
      (await queue.getOperationsForModel('l10n_ec.cash.out')),
      hasLength(2),
    );
    expect(
      (await queue.getOperationsForModel('collection.session.deposit')),
      hasLength(2),
    );
    expect((await reopened.select(reopened.cashOut).get()), hasLength(1));
    expect(
      (await reopened.select(reopened.collectionSessionDeposit).get()),
      hasLength(1),
    );
    final cashCreate = (await queue.getOperationsForModel('l10n_ec.cash.out'))
        .singleWhere((operation) => operation.method == 'create');
    expect(cashCreate.values['cash_out_type_id'], 9);
    expect(cashCreate.values.containsKey('cash_out_type'), isFalse);
    final depositCreate = (await queue.getOperationsForModel(
      'collection.session.deposit',
    )).singleWhere((operation) => operation.method == 'create');
    expect(depositCreate.values['deposit_type'], 'cash');
    expect(depositCreate.values.containsKey('cash_journal_id'), isFalse);
    final depositAccounting =
        (await queue.getOperationsForModel('collection.session.deposit'))
            .singleWhere(
              (operation) =>
                  operation.method == 'action_create_accounting_entry',
            );
    expect(depositAccounting.values['dependsOn'], [depositCreate.operationKey]);

    final retry = DurableCollectionProducer(reopened, queue);
    await retry.cashOut(
      commandId: 'cash-u06-1',
      sessionId: 8,
      journalId: 3,
      cashOutTypeId: 9,
      amountMinor: 1250,
      note: 'prueba',
    );
    expect(
      (await queue.getOperationsForModel('l10n_ec.cash.out')),
      hasLength(2),
    );
  });

  test('customer advance is atomic, survives restart and replays create/post once', () async {
    final file = File(
      '${Directory.systemTemp.path}/orbi-u06-advance-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final firstDb = AppDatabase(NativeDatabase(file));
    final firstQueue = OfflineQueueDataSource(firstDb);
    final command = 'advance-u06-0000000000000000000000000001';
    final first = await DurableCollectionProducer(firstDb, firstQueue)
        .createAndPostAdvance(
          commandId: command,
          partnerId: 17,
          reference: 'POS anticipo 2026-09-07 referencia durable',
          journalId: 4,
          amountMinor: 12500,
          collectionSessionId: 8,
        );
    expect(first.state, DurableCollectionState.queued);
    expect(await firstDb.select(firstDb.accountAdvance).get(), hasLength(1));
    expect(await firstDb.select(firstDb.advanceLinesTable).get(), hasLength(1));
    expect(await firstDb.select(firstDb.offlineQueue).get(), hasLength(2));
    await firstDb.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await reopened.close();
      if (file.existsSync()) await file.delete();
    });
    final queue = OfflineQueueDataSource(reopened);
    final duplicate = await DurableCollectionProducer(reopened, queue)
        .createAndPostAdvance(
          commandId: command,
          partnerId: 17,
          reference: 'POS anticipo 2026-09-07 referencia durable',
          journalId: 4,
          amountMinor: 12500,
          collectionSessionId: 8,
        );
    expect(duplicate.state, DurableCollectionState.queued);
    expect(await reopened.select(reopened.offlineQueue).get(), hasLength(2));
    final create = (await queue.getOperationsForModel('account.advance'))
        .singleWhere((operation) => operation.method == 'create');
    expect(create.values['external_id'], command);
    expect(create.values['advance_line_ids'], isA<List>());

    final actions = _Actions();
    final scope = AppScope(
      appId: 'panel',
      installationId: 'install',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 7,
    );
    final job = OperationsSyncJob(
      queue: queue,
      adapter: OdooOfflineOperationAdapter(
        actions: actions,
        database: reopened,
        scope: scope,
        queue: queue,
      ),
    );
    expect((await job.run(scope)).cursorConfirmed, isTrue);
    expect(actions.calls, contains('account.advance.create:[]'));
    expect(actions.calls, contains('account.advance.action_post:[501]'));
    expect(await reopened.select(reopened.offlineQueue).get(), isEmpty);
    await job.dispose();
  });

  test('collection lines live in native Drift tables and intent keeps only local IDs', () async {
    final file = File(
      '${Directory.systemTemp.path}/orbi-u06-lines-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final firstDb = AppDatabase(NativeDatabase(file));
    final firstQueue = OfflineQueueDataSource(firstDb);
    final result = await DurableCollectionProducer(firstDb, firstQueue)
        .enqueueCollectionIntent(
          commandId: 'collect-lines-u06',
          saleOrderId: 42,
          method: 'existingInvoice',
          amountMinor: 7500,
          wizardId: 52,
          paymentLines: const [
            DurablePaymentLineDraft(
              type: 'advance',
              amountMinor: 5000,
              advanceId: 91,
            ),
            DurablePaymentLineDraft(
              type: 'credit_note',
              amountMinor: 2500,
              creditNoteId: 73,
            ),
          ],
          withholdLines: const [
            DurableWithholdLineDraft(
              uuid: 'withhold-lines-u06',
              taxId: 7,
              baseMinor: 10000,
              amountMinor: 1000,
            ),
          ],
        );
    expect(result.state, DurableCollectionState.queued);
    expect(
      await firstDb.select(firstDb.saleOrderPaymentLine).get(),
      hasLength(2),
    );
    expect(
      await firstDb.select(firstDb.saleOrderWithholdLine).get(),
      hasLength(1),
    );
    final intent = (await firstQueue.getOperationsForModel(
      'l10n_ec_collection_box.sale.order.payment.wizard',
    )).single;
    expect(intent.values['paymentLineIds'], [1, 2]);
    expect(intent.values['withholdLineIds'], [1]);
    expect(intent.values.containsKey('paymentLines'), isFalse);
    await firstDb.close();
    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await reopened.close();
      if (file.existsSync()) await file.delete();
    });
    final retry =
        await DurableCollectionProducer(
          reopened,
          OfflineQueueDataSource(reopened),
        ).enqueueCollectionIntent(
          commandId: 'collect-lines-u06',
          saleOrderId: 42,
          method: 'existingInvoice',
          amountMinor: 7500,
          wizardId: 52,
          paymentLines: const [
            DurablePaymentLineDraft(
              type: 'advance',
              amountMinor: 5000,
              advanceId: 91,
            ),
            DurablePaymentLineDraft(
              type: 'credit_note',
              amountMinor: 2500,
              creditNoteId: 73,
            ),
          ],
          withholdLines: const [
            DurableWithholdLineDraft(
              uuid: 'withhold-lines-u06',
              taxId: 7,
              baseMinor: 10000,
              amountMinor: 1000,
            ),
          ],
        );
    expect(retry.state, DurableCollectionState.queued);
    expect(
      await reopened.select(reopened.saleOrderPaymentLine).get(),
      hasLength(2),
    );
    expect(
      await reopened.select(reopened.saleOrderWithholdLine).get(),
      hasLength(1),
    );
    expect(await reopened.select(reopened.offlineQueue).get(), hasLength(2));

    final actions = _Actions();
    final adapter = OdooOfflineOperationAdapter(
      actions: actions,
      database: reopened,
      scope: AppScope(
        appId: 'panel',
        installationId: 'install',
        normalizedServerUrl: 'https://erp.test',
        database: 'db',
        userId: 1,
      ),
      queue: OfflineQueueDataSource(reopened),
    );
    final job = OperationsSyncJob(
      queue: OfflineQueueDataSource(reopened),
      adapter: adapter,
    );
    addTearDown(job.dispose);
    expect(
      (await job.run(
        AppScope(
          appId: 'panel',
          installationId: 'install',
          normalizedServerUrl: 'https://erp.test',
          database: 'db',
          userId: 1,
        ),
      )).cursorConfirmed,
      isTrue,
    );
    expect(
      actions.calls.where(
        (call) => call == 'sale.order.withhold.line.create:[]',
      ),
      hasLength(1),
    );
    final withholdIndex = actions.calls.indexOf(
      'sale.order.withhold.line.create:[]',
    );
    final wizardIndex = actions.calls.indexWhere(
      (call) => call.contains(
        'l10n_ec_collection_box.sale.order.payment.wizard.action_apply',
      ),
    );
    expect(withholdIndex, lessThan(wizardIndex));
    expect(await reopened.select(reopened.offlineQueue).get(), isEmpty);
    expect(
      (await reopened.select(reopened.saleOrderWithholdLine).getSingle())
          .isSynced,
      isTrue,
    );
    final afterReplay =
        await DurableCollectionProducer(
          reopened,
          OfflineQueueDataSource(reopened),
        ).enqueueCollectionIntent(
          commandId: 'collect-lines-u06',
          saleOrderId: 42,
          method: 'existingInvoice',
          amountMinor: 7500,
          wizardId: 52,
          paymentLines: const [
            DurablePaymentLineDraft(
              type: 'advance',
              amountMinor: 5000,
              advanceId: 91,
            ),
            DurablePaymentLineDraft(
              type: 'credit_note',
              amountMinor: 2500,
              creditNoteId: 73,
            ),
          ],
          withholdLines: const [
            DurableWithholdLineDraft(
              uuid: 'withhold-lines-u06',
              taxId: 7,
              baseMinor: 10000,
              amountMinor: 1000,
            ),
          ],
        );
    expect(afterReplay.state, DurableCollectionState.queued);
    expect(await reopened.select(reopened.offlineQueue).get(), isEmpty);
    expect(
      await reopened.select(reopened.saleOrderPaymentLine).get(),
      hasLength(2),
    );
  });

  test('closing count is durable, ordered and idempotent across restart', () async {
    final file = File(
      '${Directory.systemTemp.path}/orbi-u06-close-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final firstDb = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      if (file.existsSync()) await file.delete();
    });
    await firstDb
        .into(firstDb.collectionSession)
        .insert(
          CollectionSessionCompanion.insert(
            odooId: 8,
            sessionUuid: 'session-8',
            name: 'Caja 8',
            configId: 2,
            companyId: 1,
            userId: 7,
            currencyId: 1,
            startAt: DateTime.utc(2026, 9, 7),
          ),
        );
    final queue = OfflineQueueDataSource(firstDb);
    final producer = DurableCollectionProducer(firstDb, queue);
    final count = DurableCashCount(
      bills100: 1,
      bills20: 1,
      coins50: 1,
      expectedBalanceMinor: 5000,
      notes: 'Cierre de prueba',
    );
    final first = await producer.closeWithCount(
      commandId: 'close-8',
      sessionId: 8,
      count: count,
    );
    expect(first.state, DurableCollectionState.queued);
    expect(first.cashTotalMinor, 12050);
    expect(first.differenceMinor, 7050);
    expect(
      await firstDb.select(firstDb.collectionSessionCash).get(),
      hasLength(1),
    );
    expect(await firstDb.select(firstDb.offlineQueue).get(), hasLength(3));
    await firstDb.close();

    final reopened = AppDatabase(NativeDatabase(file));
    addTearDown(reopened.close);
    final retry = await DurableCollectionProducer(
      reopened,
      OfflineQueueDataSource(reopened),
    ).closeWithCount(commandId: 'close-8', sessionId: 8, count: count);
    expect(retry.state, DurableCollectionState.queued);
    expect(await reopened.select(reopened.offlineQueue).get(), hasLength(3));
    final session = await (reopened.select(
      reopened.collectionSession,
    )..where((table) => table.odooId.equals(8))).getSingle();
    expect(session.state, 'closing_control');
    expect(session.cashRegisterBalanceEndReal, 120.50);
    expect(session.cashRegisterDifference, 70.50);
    final reopenedQueue = OfflineQueueDataSource(reopened);
    for (final operation in await reopenedQueue.getPendingOperations()) {
      await reopenedQueue.removeOperation(operation.id);
    }
    final completedRetry = await DurableCollectionProducer(
      reopened,
      reopenedQueue,
    ).closeWithCount(commandId: 'close-8', sessionId: 8, count: count);
    expect(completedRetry.state, DurableCollectionState.queued);
    expect(await reopened.select(reopened.offlineQueue).get(), hasLength(0));
    expect(
      await reopened.select(reopened.collectionSessionCash).get(),
      hasLength(1),
    );
  });

  test(
    'closing replay writes count before native session transitions',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = OfflineQueueDataSource(db);
      await DurableCollectionProducer(db, queue).closeWithCount(
        commandId: 'close-replay',
        sessionId: 8,
        count: const DurableCashCount(bills1: 10),
      );
      final actions = _Actions();
      final adapter = OdooOfflineOperationAdapter(
        actions: actions,
        database: db,
        scope: AppScope(
          appId: 'theos_panel',
          installationId: 'install',
          normalizedServerUrl: 'https://erp.test',
          database: 'db',
          userId: 7,
        ),
        queue: queue,
      );
      final operations = await queue.getOperationsForModel(
        'collection.session',
      );
      expect(operations.map((operation) => operation.method), [
        'session_closing_control',
        'session_close',
      ]);
      final countCreate = (await queue.getOperationsForModel(
        'collection.session.cash',
      )).single;
      await adapter.dispatch(countCreate);
      await adapter.dispatch(operations.first);
      expect(actions.calls, contains('collection.session.write:[8]'));
      expect(
        actions.calls,
        contains('collection.session.action_session_closing_control:[8]'),
      );
      expect(
        await adapter.reconcile(operations.first),
        isA<OperationApplied>(),
      );
      await adapter.dispatch(operations.last);
      expect(
        actions.calls,
        contains('collection.session.action_session_close:[8]'),
      );
      expect(await adapter.reconcile(operations.last), isA<OperationApplied>());
    },
  );

  test(
    'rejects invalid cheque deposit without queuing a remote-invalid row',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = OfflineQueueDataSource(db);
      final result = await DurableCollectionProducer(db, queue).deposit(
        commandId: 'deposit-invalid-check',
        sessionId: 8,
        bankJournalId: 4,
        depositType: 'check',
        amountMinor: 2500,
        cashAmountMinor: 0,
        checkAmountMinor: 2500,
        accountingDate: '2026-09-07',
        checkCount: 0,
      );
      expect(result.state, DurableCollectionState.rejected);
      expect(
        await queue.getOperationsForModel('collection.session.deposit'),
        isEmpty,
      );
      expect(await db.select(db.collectionSessionDeposit).get(), isEmpty);
    },
  );

  test('persists exact mixed cash and cheque components', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = OfflineQueueDataSource(db);
    final result = await DurableCollectionProducer(db, queue).deposit(
      commandId: 'deposit-mixed-1',
      sessionId: 8,
      bankJournalId: 4,
      depositType: 'mixed',
      amountMinor: 10000,
      cashAmountMinor: 4000,
      checkAmountMinor: 6000,
      accountingDate: '2026-09-07',
      checkCount: 2,
    );
    expect(result.state, DurableCollectionState.queued);
    final operation = (await queue.getOperationsForModel(
      'collection.session.deposit',
    )).singleWhere((operation) => operation.method == 'create');
    expect(operation.values['cash_amount'], 40.0);
    expect(operation.values['check_amount'], 60.0);

    final invalid = await DurableCollectionProducer(db, queue).deposit(
      commandId: 'deposit-mixed-invalid',
      sessionId: 8,
      bankJournalId: 4,
      depositType: 'mixed',
      amountMinor: 10000,
      cashAmountMinor: 10000,
      checkAmountMinor: 1000,
      accountingDate: '2026-09-07',
      checkCount: 1,
    );
    expect(invalid.state, DurableCollectionState.rejected);
  });

  test('cash-out replay rewrites action ID and ends posted', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = OfflineQueueDataSource(db);
    final producer = DurableCollectionProducer(db, queue);
    await producer.cashOut(
      commandId: 'cash-replay-1',
      sessionId: 8,
      journalId: 3,
      cashOutTypeId: 9,
      amountMinor: 1250,
      note: 'replay',
    );
    final scope = AppScope(
      appId: 'theos_panel',
      installationId: 'install',
      normalizedServerUrl: 'https://erp.test',
      database: 'db',
      userId: 7,
    );
    final actions = _Actions();
    final adapter = OdooOfflineOperationAdapter(
      actions: actions,
      database: db,
      scope: scope,
      queue: queue,
    );
    final create = (await queue.getOperationsForModel('l10n_ec.cash.out'))
        .firstWhere((operation) => operation.method == 'create');
    await adapter.dispatch(create);
    final action = (await queue.getOperationsForModel('l10n_ec.cash.out'))
        .firstWhere((operation) => operation.method == 'action_confirm');
    expect(action.recordId, 501);
    await adapter.dispatch(action);
    final row = await (db.select(
      db.cashOut,
    )..where((t) => t.id.equals(action.values['local_id'] as int))).getSingle();
    expect(row.state, 'posted');
    expect(actions.calls, contains('l10n_ec.cash.out.action_confirm:[501]'));
  });

  test(
    'deposit replay reconciles deposit_uuid and strips local fields',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = OfflineQueueDataSource(db);
      final producer = DurableCollectionProducer(db, queue);
      await producer.deposit(
        commandId: 'deposit-reconcile-1',
        sessionId: 8,
        bankJournalId: 4,
        depositType: 'cash',
        amountMinor: 2500,
        cashAmountMinor: 2500,
        checkAmountMinor: 0,
        accountingDate: '2026-09-07',
      );
      final actions = _Actions();
      final adapter = OdooOfflineOperationAdapter(
        actions: actions,
        database: db,
        scope: AppScope(
          appId: 'theos_panel',
          installationId: 'install',
          normalizedServerUrl: 'https://erp.test',
          database: 'db',
          userId: 7,
        ),
        queue: queue,
      );
      final create = (await queue.getOperationsForModel(
        'collection.session.deposit',
      )).singleWhere((operation) => operation.method == 'create');
      await adapter.dispatch(create);
      final createCall = actions.payloads.singleWhere(
        (call) =>
            call['model'] == 'collection.session.deposit' &&
            call['method'] == 'create',
      );
      final sent = (createCall['kwargs'] as Map)['vals_list'] as List;
      final sentFields = Map<String, dynamic>.from(sent.single as Map);
      expect(sentFields['deposit_uuid'], 'deposit-reconcile-1');
      expect(sentFields.containsKey('local_id'), isFalse);
      expect(sentFields.containsKey('_operation_key'), isFalse);
      expect(sentFields.containsKey('uuid'), isFalse);
      final persisted = create.values;
      expect(persisted['deposit_uuid'], 'deposit-reconcile-1');
      expect(persisted.containsKey('uuid'), isFalse);
      expect(persisted.containsKey('local_id'), isTrue);
      expect(persisted.containsKey('_operation_key'), isTrue);
      final accounting =
          (await queue.getOperationsForModel('collection.session.deposit'))
              .singleWhere(
                (operation) =>
                    operation.method == 'action_create_accounting_entry',
              );
      await adapter.dispatch(accounting);
      expect(
        actions.calls,
        contains(
          'collection.session.deposit.action_create_accounting_entry:[501]',
        ),
      );
      final row =
          await (db.select(db.collectionSessionDeposit)..where(
                (table) =>
                    table.id.equals(accounting.values['local_id'] as int),
              ))
              .getSingle();
      expect(row.moveId, 22);
      expect(row.state, 'posted');
      expect(await adapter.reconcile(accounting), isA<OperationApplied>());
    },
  );

  test('deposit accounting stays pending without a remote move', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = OfflineQueueDataSource(db);
    await DurableCollectionProducer(db, queue).deposit(
      commandId: 'deposit-no-move',
      sessionId: 8,
      bankJournalId: 4,
      depositType: 'cash',
      amountMinor: 2500,
      cashAmountMinor: 2500,
      checkAmountMinor: 0,
      accountingDate: '2026-09-07',
    );
    final actions = _Actions()..depositHasMove = false;
    final adapter = OdooOfflineOperationAdapter(
      actions: actions,
      database: db,
      scope: AppScope(
        appId: 'theos_panel',
        installationId: 'install',
        normalizedServerUrl: 'https://erp.test',
        database: 'db',
        userId: 7,
      ),
      queue: queue,
    );
    final create = (await queue.getOperationsForModel(
      'collection.session.deposit',
    )).singleWhere((operation) => operation.method == 'create');
    await adapter.dispatch(create);
    final accounting =
        (await queue.getOperationsForModel('collection.session.deposit'))
            .singleWhere(
              (operation) =>
                  operation.method == 'action_create_accounting_entry',
            );
    expect(await adapter.dispatch(accounting), isA<ConflictInfo>());
    final row =
        await (db.select(db.collectionSessionDeposit)..where(
              (table) => table.id.equals(accounting.values['local_id'] as int),
            ))
            .getSingle();
    expect(row.moveId, isNull);
    expect(row.state, 'draft');
  });
}
