import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

class FakeActions implements SaleOdooActions {
  final List<String> calls = [];
  final List<Map<String, dynamic>?> kwargsHistory = [];
  Map<String, dynamic>? lastKwargs;
  dynamic response = true;
  dynamic accountMoveResponse = const <Map<String, dynamic>>[];
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    calls.add('$model.$method');
    lastKwargs = kwargs;
    kwargsHistory.add(kwargs);
    if (model == 'account.move' && method == 'search_read') {
      return accountMoveResponse;
    }
    return response;
  }
}

class QueueActions implements SaleOdooActions {
  final List<String> calls = [];
  bool failFirstOrderCreate = false;
  bool _failedOrderCreate = false;

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    calls.add('$model.$method');
    if (model == 'sale.order' && method == 'create') {
      if (failFirstOrderCreate && !_failedOrderCreate) {
        _failedOrderCreate = true;
        throw const AmbiguousOperationException('create timeout');
      }
      return 701;
    }
    if (model == 'sale.order' && method == 'search_read') {
      return [
        {'id': 701},
      ];
    }
    if (model == 'sale.order.line' && method == 'create') return 801;
    return true;
  }
}

class FakeResolver implements SaleLocalOrderResolver {
  final int localId;
  final int version;
  const FakeResolver({this.localId = 1, this.version = 1});
  @override
  Future<SaleLocalOrderResolution> resolve(EntityReference reference) async =>
      SaleLocalOrderResolution(localId: localId, version: version);
}

class FakeShiftVersions implements SaleShiftVersionReader {
  @override
  Future<int> read(EntityReference shift) async => 2;
}

class FakeRemoteVersions implements SaleRemoteVersionReader {
  final int value;
  const FakeRemoteVersions([this.value = 2]);
  @override
  Future<int> read(EntityReference order) async => value;
}

class ThrowingActions extends FakeActions {
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) => Future<dynamic>.error(StateError('timeout'));
}

class ExpiringWizardActions extends FakeActions {
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    if (model == 'l10n_ec_collection_box.sale.order.payment.wizard' &&
        method == 'search_read') {
      calls.add('$model.$method');
      lastKwargs = kwargs;
      kwargsHistory.add(kwargs);
      return const <Map<String, dynamic>>[];
    }
    if (model == 'l10n_ec_collection_box.sale.order.payment.wizard' &&
        method == 'create') {
      calls.add('$model.$method');
      lastKwargs = kwargs;
      kwargsHistory.add(kwargs);
      return 777;
    }
    return super.call(model: model, method: method, ids: ids, kwargs: kwargs);
  }
}

class FakeStates implements SaleRemoteConfirmationReader {
  final SaleOrderState value;
  const FakeStates(this.value);
  @override
  Future<SaleOrderState?> read(EntityReference order) async => value;
}

void main() {
  test('withhold line replays official sale.order.withhold.line without a new table', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final rowId = await db
        .into(db.saleOrderWithholdLine)
        .insert(
          SaleOrderWithholdLineCompanion.insert(
            lineUuid: const drift.Value('withhold-u06'),
            orderId: 42,
            taxId: 7,
            taxName: 'IVA retenido',
            withholdType: 'withhold_vat_sale',
            base: const drift.Value(100.0),
            amount: const drift.Value(10.0),
          ),
        );
    final queue = OfflineQueueDataSource(db);
    await queue.queueOperation(
      model: 'sale.order.withhold.line',
      method: 'create',
      recordId: rowId,
      parentOrderId: 42,
      values: {
        'uuid': 'withhold-u06',
        'local_id': rowId,
        'sale_id': 42,
        'tax_id': 7,
        'base': 100.0,
        'amount': 10.0,
      },
      operationKey: 'withhold-u06',
      replayPolicy: OfflineReplayPolicy.retrySafe,
    );
    final actions = FakeActions()..response = 901;
    final scope = AppScope(
      appId: 'test',
      installationId: 'installation',
      normalizedServerUrl: 'https://example.test',
      database: 'db',
      userId: 1,
    );
    final adapter = OdooOfflineOperationAdapter(
      actions: actions,
      database: db,
      scope: scope,
      queue: queue,
    );
    final operation = (await queue.getPendingOperations()).single;
    expect(await adapter.dispatch(operation), isNull);
    expect(actions.calls, contains('sale.order.withhold.line.create'));
    final updated = await (db.select(
      db.saleOrderWithholdLine,
    )..where((table) => table.id.equals(rowId))).getSingle();
    expect(updated.odooId, 901);
    expect(updated.isSynced, isTrue);
  });

  test(
    'native payment wizard carries cached advance and credit-note lines',
    () async {
      final actions = FakeActions()..response = 71;
      final port = OdooSaleCollectionPort(actions);
      final result = await port.confirmAndInvoice(
        order: EntityReference(localId: 'sale-1', remoteId: 42),
        commandId: 'collect-u06-wizard',
        paymentLines: const [
          SalePaymentLinePayload(
            journalId: 0,
            amountMinor: 5000,
            type: 'advance',
            advanceId: 91,
          ),
          SalePaymentLinePayload(
            journalId: 0,
            amountMinor: 2500,
            type: 'credit_note',
            creditNoteId: 73,
          ),
        ],
        collectionSessionId: 8,
      );
      expect(result.syncState, OperationSyncState.synced);
      expect(actions.calls, [
        'l10n_ec_collection_box.sale.order.payment.wizard.create',
        'l10n_ec_collection_box.sale.order.payment.wizard.action_apply_and_create_invoice',
      ]);
      final wizard = actions.kwargsHistory.first!['vals_list'] as List;
      final values = (wizard.single as Map).cast<String, dynamic>();
      expect(values['pos_client_op_uuid'], 'collect-u06-wizard');
      final lines = values['line_ids'] as List;
      expect((lines[0] as List)[2], containsPair('line_type', 'advance'));
      expect((lines[0] as List)[2], containsPair('advance_id', 91));
      expect((lines[1] as List)[2], containsPair('line_type', 'credit_note'));
      expect((lines[1] as List)[2], containsPair('credit_note_id', 73));
    },
  );

  test('existing invoice replay rebuilds official wizard lines after restart', () async {
    final file = File(
      '${Directory.systemTemp.path}/orbi-u06-existing-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final firstDb = AppDatabase(NativeDatabase(file));
    final firstQueue = OfflineQueueDataSource(firstDb);
    await firstQueue.queueOperation(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'existingInvoice',
      recordId: 52,
      values: {
        'commandId': 'existing-u06-restart',
        'saleOrderRemoteId': 42,
        'wizardId': 52,
        'paymentLines': [
          {
            'type': 'advance',
            'amountMinor': 5000,
            'advanceId': 91,
            'journalId': 0,
          },
          {
            'type': 'credit_note',
            'amountMinor': 2500,
            'creditNoteId': 73,
            'journalId': 0,
          },
        ],
      },
      operationKey: 'existing-u06-restart',
      replayPolicy: OfflineReplayPolicy.retrySafe,
    );
    await firstDb.close();
    final db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) await file.delete();
    });
    final queue = OfflineQueueDataSource(db);
    final actions = FakeActions();
    final adapter = OdooOfflineOperationAdapter(
      actions: actions,
      database: db,
      scope: AppScope(
        appId: 'panel',
        installationId: 'install',
        normalizedServerUrl: 'https://erp.test',
        database: 'db',
        userId: 1,
      ),
      queue: queue,
    );
    final operation = (await queue.getPendingOperations()).single;
    expect(await adapter.dispatch(operation), isNull);
    expect(actions.calls, [
      'l10n_ec_collection_box.sale.order.payment.wizard.search_read',
      'l10n_ec_collection_box.sale.order.payment.wizard.write',
      'l10n_ec_collection_box.sale.order.payment.wizard.action_apply',
    ]);
    final write = actions.kwargsHistory[1]!['vals'] as Map;
    final lines = write['line_ids'] as List;
    expect((lines[1] as List)[2], containsPair('line_type', 'advance'));
    expect((lines[2] as List)[2], containsPair('line_type', 'credit_note'));
  });

  test('existing invoice replay recreates expired transient wizard', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final queue = OfflineQueueDataSource(db);
    await queue.queueOperation(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'existingInvoice',
      recordId: 52,
      values: {
        'commandId': 'existing-u06-expired',
        'saleOrderRemoteId': 42,
        'wizardId': 52,
        'paymentLines': [
          {
            'type': 'advance',
            'amountMinor': 5000,
            'advanceId': 91,
            'journalId': 0,
          },
        ],
      },
      operationKey: 'existing-u06-expired',
      replayPolicy: OfflineReplayPolicy.retrySafe,
    );
    final actions = ExpiringWizardActions();
    final adapter = OdooOfflineOperationAdapter(
      actions: actions,
      database: db,
      scope: AppScope(
        appId: 'panel',
        installationId: 'install',
        normalizedServerUrl: 'https://erp.test',
        database: 'db',
        userId: 1,
      ),
      queue: queue,
    );
    final operation = (await queue.getPendingOperations()).single;
    expect(await adapter.dispatch(operation), isNull);
    expect(actions.calls, [
      'l10n_ec_collection_box.sale.order.payment.wizard.search_read',
      'l10n_ec_collection_box.sale.order.payment.wizard.create',
      'l10n_ec_collection_box.sale.order.payment.wizard.action_apply',
    ]);
    final created = actions.kwargsHistory[1]!['vals_list'] as List;
    final values = (created.single as Map).cast<String, dynamic>();
    expect(values['sale_id'], 42);
    final lines = values['line_ids'] as List;
    expect(
      lines.whereType<List>().map((line) => line[2]).whereType<Map>(),
      anyElement(containsPair('advance_id', 91)),
    );
  });

  test('local confirmation is durable and operationKey deduplicates', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final order = await db
        .into(db.saleOrder)
        .insertReturning(SaleOrderCompanion.insert(odooId: 1, name: 'S01'));
    final store = DriftSaleCommandStore(db, FakeResolver(localId: order.id));
    final ref = EntityReference(localId: 'uuid-order-1', remoteId: 1);
    final outcome = OperationOutcome(
      commandId: 'cmd-1',
      entity: ref,
      businessState: SaleOrderState.sale,
      syncState: OperationSyncState.queued,
    );
    await store.commitAndEnqueueIfAbsent(
      commandId: 'cmd-1',
      entity: ref,
      expectedVersion: 1,
      outcome: outcome,
    );
    await store.commitAndEnqueueIfAbsent(
      commandId: 'cmd-1',
      entity: ref,
      expectedVersion: 1,
      outcome: outcome,
    );
    expect(await db.select(db.offlineQueue).get(), hasLength(1));
    expect((await db.select(db.saleOrder).getSingle()).state, 'sale');
    await db.close();
  });

  test('physical draft queue replays create, lines, then confirm', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final draft = DriftSaleDraftRepository(db);
    final localId = await draft.save(
      const SaleDraftRecord(
        commandId: 'order-uuid',
        name: 'S-LOCAL',
        lines: [
          SaleDraftLineRecord(
            lineUuid: 'line-uuid',
            product: SaleCatalogProduct(
              localId: 'product-local',
              remoteId: 9,
              name: 'Coffee',
              uomId: 1,
              price: 2.5,
            ),
            quantity: 2,
          ),
        ],
      ),
    );
    final resolver = FakeResolver(localId: localId);
    await DriftSaleCommandStore(db, resolver).commitAndEnqueueIfAbsent(
      commandId: 'confirm-order',
      entity: EntityReference(localId: 'order-uuid'),
      expectedVersion: 1,
      outcome: OperationOutcome(
        commandId: 'confirm-order',
        entity: EntityReference(localId: 'order-uuid'),
        businessState: SaleOrderState.sale,
        syncState: OperationSyncState.queued,
      ),
    );
    final actions = QueueActions();
    final scope = AppScope(
      appId: 'test',
      installationId: 'installation',
      normalizedServerUrl: 'https://example.test',
      database: 'db',
      userId: 1,
    );
    final job = OperationsSyncJob(
      queue: OfflineQueueDataSource(db),
      adapter: OdooOfflineOperationAdapter(
        actions: actions,
        database: db,
        scope: scope,
        queue: OfflineQueueDataSource(db),
      ),
    );
    expect((await job.run(scope)).cursorConfirmed, isTrue);
    expect(actions.calls, [
      'sale.order.create',
      'sale.order.line.create',
      'sale.order.action_pos_confirm',
    ]);
    expect((await db.select(db.saleOrder).getSingle()).odooId, 701);
    expect((await db.select(db.saleOrderLine).getSingle()).odooId, 801);
    expect(await db.select(db.offlineQueue).get(), isEmpty);
    await job.dispose();
  });

  test(
    'ambiguous order create reconciles by x_uuid without duplicate create',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      await DriftSaleDraftRepository(db).save(
        const SaleDraftRecord(
          commandId: 'ambiguous-order',
          name: 'S-AMBIGUOUS',
          lines: [
            SaleDraftLineRecord(
              lineUuid: 'ambiguous-line',
              product: SaleCatalogProduct(
                localId: 'product-local',
                remoteId: 9,
                name: 'Coffee',
              ),
              quantity: 1,
            ),
          ],
        ),
      );
      final actions = QueueActions()..failFirstOrderCreate = true;
      final scope = AppScope(
        appId: 'test',
        installationId: 'installation',
        normalizedServerUrl: 'https://example.test',
        database: 'db',
        userId: 1,
      );
      final job = OperationsSyncJob(
        queue: OfflineQueueDataSource(db),
        adapter: OdooOfflineOperationAdapter(
          actions: actions,
          database: db,
          scope: scope,
          queue: OfflineQueueDataSource(db),
        ),
      );
      expect((await job.run(scope)).cursorConfirmed, isTrue);
      expect(
        actions.calls.where((call) => call == 'sale.order.create'),
        hasLength(1),
      );
      expect(actions.calls, contains('sale.order.search_read'));
      expect((await db.select(db.saleOrder).getSingle()).odooId, 701);
      await job.dispose();
    },
  );

  test('temporary local order confirmation depends on create', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final order = await db
        .into(db.saleOrder)
        .insertReturning(
          SaleOrderCompanion.insert(odooId: -7, name: 'offline'),
        );
    final outcome = OperationOutcome(
      commandId: 'cmd-local',
      entity: EntityReference(localId: 'local-uuid'),
      businessState: SaleOrderState.sale,
      syncState: OperationSyncState.queued,
    );
    await DriftSaleCommandStore(
      db,
      FakeResolver(localId: order.id),
    ).commitAndEnqueueIfAbsent(
      commandId: 'cmd-local',
      entity: outcome.entity,
      expectedVersion: 1,
      outcome: outcome,
    );
    final values = jsonDecode(
      (await db.select(db.offlineQueue).getSingle()).values,
    );
    expect(values['dependsOn'], ['cmd-local:create']);
  });

  test('stale local version rolls back without queue entry', () async {
    final db = AppDatabase(NativeDatabase.memory());
    final order = await db
        .into(db.saleOrder)
        .insertReturning(SaleOrderCompanion.insert(odooId: 2, name: 'S02'));
    final store = DriftSaleCommandStore(
      db,
      FakeResolver(localId: order.id, version: 4),
    );
    final ref = EntityReference(localId: 'uuid-order-2', remoteId: 2);
    final outcome = OperationOutcome(
      commandId: 'stale',
      entity: ref,
      businessState: SaleOrderState.sale,
      syncState: OperationSyncState.queued,
    );
    await expectLater(
      store.commitAndEnqueueIfAbsent(
        commandId: 'stale',
        entity: ref,
        expectedVersion: 3,
        outcome: outcome,
      ),
      throwsStateError,
    );
    expect(await db.select(db.offlineQueue).get(), isEmpty);
    await db.close();
  });

  test(
    'turn adapter delegates exact custom methods and maps errors to conflict',
    () async {
      final fake = FakeActions();
      final adapter = OdooCollectionSessionStore(fake, FakeShiftVersions());
      final opened = await adapter.apply(
        commandId: 'open',
        shift: EntityReference(localId: 'uuid-shift-8', remoteId: 8),
        expectedVersion: 2,
        state: SaleShiftState.open,
      );
      expect(opened.syncState, OperationSyncState.queued);
      expect(fake.calls, contains('collection.session.action_session_open'));
    },
  );

  test(
    'confirmation uses POS facade and maps approval without completion',
    () async {
      final fake = FakeActions()
        ..response = {'success': false, 'approval_required': true};
      final adapter = OdooSaleConfirmationAdapter(
        fake,
        const FakeRemoteVersions(),
      );
      final result = await adapter.confirm(
        order: EntityReference(localId: 'uuid', remoteId: 41),
        commandId: 'confirm-1',
        expectedVersion: 2,
      );
      expect(fake.calls, ['sale.order.action_pos_confirm']);
      expect(result.pendingAction?.type, PendingActionType.approval);
      expect(result.syncState, OperationSyncState.conflict);
    },
  );

  test('collection sends exact UUID and payment kwargs', () async {
    final fake = FakeActions();
    final adapter = OdooSaleCollectionPort(fake);
    final result = await adapter.confirmAndInvoice(
      order: EntityReference(localId: 'uuid', remoteId: 41),
      commandId: 'pay-1',
      paymentLines: const [
        SalePaymentLinePayload(journalId: 7, amountMinor: 1250),
      ],
      collectionSessionId: 9,
      sequential: 12,
      emissionDate: '2026-09-06',
      accessKey: '123',
    );
    expect(result.syncState, OperationSyncState.synced);
    expect(fake.calls, ['sale.order.action_pos_confirm_and_invoice']);
    expect(fake.lastKwargs?['client_op_uuid'], 'pay-1');
    expect(fake.lastKwargs?['payment_lines'], isA<List<dynamic>>());
    expect(fake.lastKwargs?.containsKey('sequential'), isTrue);
  });

  test(
    'confirmation timeout reconciles locked remote order before retry',
    () async {
      final adapter = OdooSaleConfirmationAdapter(
        ThrowingActions(),
        const FakeRemoteVersions(),
        states: const FakeStates(SaleOrderState.sale),
      );
      final result = await adapter.confirm(
        order: EntityReference(localId: 'uuid', remoteId: 41),
        commandId: 'timeout',
        expectedVersion: 2,
      );
      expect(result.syncState, OperationSyncState.synced);
    },
  );

  test(
    'durable cash invoice requires and forwards offline fiscal identity',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final queue = OfflineQueueDataSource(db);
      final scope = AppScope(
        appId: 'panel',
        installationId: 'installation',
        normalizedServerUrl: 'https://example.test',
        database: 'db',
        userId: 1,
      );
      final adapter = OdooOfflineOperationAdapter(
        actions: FakeActions(),
        database: db,
        scope: scope,
        queue: queue,
      );
      await queue.queueOperation(
        model: 'sale.order',
        method: 'cashInvoice',
        recordId: 41,
        values: {
          'commandId': 'cash-fiscal-missing',
          'scopeKey': scope.scopeKey,
          'saleOrderRemoteId': 41,
          'numberedByClient': true,
          'paymentLines': [
            {'journalId': 7, 'amountMinor': 1250},
          ],
        },
        operationKey: 'cash-fiscal-missing',
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      final missing = (await queue.getOperationsForModel('sale.order')).single;
      await expectLater(adapter.dispatch(missing), throwsStateError);

      final actions = FakeActions();
      final validAdapter = OdooOfflineOperationAdapter(
        actions: actions,
        database: db,
        scope: scope,
        queue: queue,
      );
      final key = List.filled(49, '1').join();
      await queue.queueOperation(
        model: 'sale.order',
        method: 'cashInvoice',
        recordId: 42,
        values: {
          'commandId': 'cash-fiscal-valid',
          'scopeKey': scope.scopeKey,
          'saleOrderRemoteId': 42,
          'numberedByClient': true,
          'sequential': 12,
          'emissionDate': '2026-09-07',
          'accessKey': key,
          'paymentLines': [
            {'journalId': 7, 'amountMinor': 1250},
          ],
        },
        operationKey: 'cash-fiscal-valid',
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
      final valid = (await queue.getOperationsForModel('sale.order'))
          .singleWhere(
            (operation) => operation.values['commandId'] == 'cash-fiscal-valid',
          );
      await validAdapter.dispatch(valid);
      expect(actions.lastKwargs?['sequential'], 12);
      expect(actions.lastKwargs?['emission_date'], '2026-09-07');
      expect(actions.lastKwargs?['access_key'], key);
    },
  );

  test(
    'collection reconciliation rejects an invoice without completion marker',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);
      final scope = AppScope(
        appId: 'panel',
        installationId: 'installation',
        normalizedServerUrl: 'https://example.test',
        database: 'db',
        userId: 1,
      );
      final actions = FakeActions()
        ..accountMoveResponse = const [
          {
            'id': 88,
            'state': 'posted',
            'payment_state': 'paid',
            'amount_total': 12.50,
            'l10n_ec_pos_collection_completed': false,
          },
        ];
      final queue = OfflineQueueDataSource(db);
      final adapter = OdooOfflineOperationAdapter(
        actions: actions,
        database: db,
        scope: scope,
        queue: queue,
      );
      final operation = OfflineOperation(
        id: 1,
        model: 'sale.order',
        method: 'cashInvoice',
        recordId: 41,
        values: {
          'commandId': 'cash-reconcile-incomplete',
          'scopeKey': scope.scopeKey,
          'saleOrderRemoteId': 41,
          'paymentLines': [
            {'journalId': 7, 'amountMinor': 1250},
          ],
        },
        createdAt: DateTime.utc(2026, 9, 7),
      );
      expect(await adapter.reconcile(operation), isA<OperationNotApplied>());
    },
  );

  test('collection reconciliation requires the expected paid amount', () async {
    final actions = FakeActions()
      ..accountMoveResponse = const [
        {
          'id': 88,
          'state': 'posted',
          'payment_state': 'paid',
          'amount_total': 12.50,
          'l10n_ec_pos_collection_completed': true,
        },
      ];
    final order = EntityReference(localId: 'order-1', remoteId: 41);
    final port = OdooCollectionReconciliationPort(actions);
    expect(
      await port.findByCommandOrReference(
        order: order,
        commandId: 'cash-reconcile-amount',
        expectedAmountMinor: 1250,
      ),
      isA<OperationOutcome<SaleOrderState>>(),
    );
    expect(
      await port.findByCommandOrReference(
        order: order,
        commandId: 'cash-reconcile-amount',
        expectedAmountMinor: 1251,
      ),
      isNull,
    );
  });
}
