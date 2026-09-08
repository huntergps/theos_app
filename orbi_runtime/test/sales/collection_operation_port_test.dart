import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

final class _Actions implements ContextualSaleOdooActions {
  final calls = <Map<String, dynamic>>[];
  dynamic response = const {'ok': true};
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    calls.add({'model': model, 'method': method, 'ids': ids, 'kwargs': kwargs});
    if (method == 'create') return 501;
    return response;
  }

  @override
  Future<dynamic> callWithContext({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
  }) async {
    calls.add({
      'model': model,
      'method': method,
      'ids': ids,
      'kwargs': kwargs,
      'context': context,
    });
    return response;
  }
}

AppScope _scope(String server) => AppScope(
  appId: 'theos_panel',
  installationId: 'install',
  normalizedServerUrl: server,
  database: 'db',
  userId: 7,
);

CapabilitySnapshot _caps(AppScope scope) => CapabilitySnapshot(
  scopeKey: scope.scopeKey,
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026),
  permissions: const [
    RuntimeCollectionOperationPort.advancePermission,
    RuntimeCollectionOperationPort.withholdingPermission,
    RuntimeCollectionOperationPort.creditNotePermission,
    RuntimeCollectionOperationPort.cashOutPermission,
    RuntimeCollectionOperationPort.depositPermission,
  ],
);

void main() {
  test('blocks unsafe producers without RPC or orphan rows', () async {
    final scope = _scope('https://erp.test');
    final runtime = SessionRuntime(
      databaseOwner: RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      ),
    );
    final activation = await runtime.activate(scope, apiKey: 'key');
    final actions = _Actions();
    final port = RuntimeCollectionOperationPort(
      runtime: runtime,
      capabilities: _caps(scope),
      actions: actions,
    );
    final advance = await port.advance(
      commandId: 'advance-1',
      lease: activation.lease,
      paymentWizardId: 41,
      overpaymentMinor: 1250,
    );
    expect(advance.state, CollectionOperationState.unavailable);

    final cashOut = await port.cashOut(
      commandId: 'cash-out-1',
      lease: activation.lease,
      collectionSessionId: 10,
      journalId: 12,
      cashOutTypeId: 9,
      amountMinor: 2500,
      note: 'Retiro autorizado',
    );
    expect(cashOut.state, CollectionOperationState.unavailable);

    final deposit = await port.deposit(
      commandId: 'deposit-1',
      lease: activation.lease,
      collectionSessionId: 10,
      bankJournalId: 30,
      depositType: 'cash',
      amountMinor: 5000,
      cashAmountMinor: 5000,
      checkAmountMinor: 0,
      accountingDate: '2026-09-07',
    );
    expect(deposit.state, CollectionOperationState.unavailable);
    expect(actions.calls, isEmpty);
    await runtime.close();
  });

  test(
    'withholding and credit note keep wizard context and deduplicate taps',
    () async {
      final scope = _scope('https://erp.test');
      final runtime = SessionRuntime(
        databaseOwner: RuntimeDatabaseOwner(
          factory: (_) => AppDatabase(NativeDatabase.memory()),
        ),
      );
      final activation = await runtime.activate(scope, apiKey: 'key');
      final actions = _Actions();
      final port = RuntimeCollectionOperationPort(
        runtime: runtime,
        capabilities: _caps(scope),
        actions: actions,
      );
      final first = port.withholding(
        commandId: 'withhold-1',
        lease: activation.lease,
        wizardId: 52,
        collectionSessionId: 9,
        invoiceId: 77,
      );
      final second = port.withholding(
        commandId: 'withhold-1',
        lease: activation.lease,
        wizardId: 52,
        collectionSessionId: 9,
        invoiceId: 77,
      );
      expect(
        await Future.wait([first, second]),
        everyElement(
          predicate<CollectionOperationResult>(
            (r) => r.state == CollectionOperationState.unavailable,
          ),
        ),
      );
      expect(actions.calls, isEmpty);

      final creditNote = await port.creditNote(
        commandId: 'credit-note-1',
        lease: activation.lease,
        paymentWizardId: 52,
        lineIds: [3, 4],
      );
      expect(creditNote.state, CollectionOperationState.unavailable);
      expect(actions.calls, isEmpty);
      await runtime.close();
    },
  );

  test('rejects offline and stale scope without RPC', () async {
    final scope = _scope('https://erp.test');
    final runtime = SessionRuntime(
      databaseOwner: RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase.memory()),
      ),
    );
    final activation = await runtime.activate(scope, apiKey: 'key');
    final actions = _Actions();
    final port = RuntimeCollectionOperationPort(
      runtime: runtime,
      capabilities: _caps(scope),
      actions: actions,
    );
    final offline = await port.deposit(
      commandId: 'offline-1',
      lease: activation.lease,
      collectionSessionId: 10,
      bankJournalId: 30,
      depositType: 'cash',
      amountMinor: 5000,
      cashAmountMinor: 5000,
      checkAmountMinor: 0,
      accountingDate: '2026-09-07',
      offline: true,
    );
    expect(offline.state, CollectionOperationState.unavailable);
    final stale = await port.cashOut(
      commandId: 'stale-1',
      lease: SessionLease(
        scope: scope,
        generation: activation.lease.generation + 1,
      ),
      collectionSessionId: 10,
      journalId: 12,
      cashOutTypeId: 9,
      amountMinor: 100,
      note: 'x',
    );
    expect(stale.state, CollectionOperationState.rejected);
    expect(actions.calls, isEmpty);
    await runtime.close();
  });

  test('authorized offline cash-out queues; permission is rejected', () async {
    final scope = _scope('https://erp.test');
    final db = AppDatabase(NativeDatabase.memory());
    final runtime = SessionRuntime(
      databaseOwner: RuntimeDatabaseOwner(factory: (_) => db),
    );
    final activation = await runtime.activate(scope);
    final producer = DurableCollectionProducer(db, OfflineQueueDataSource(db));
    final authorized = RuntimeCollectionOperationPort(
      runtime: runtime,
      capabilities: _caps(scope),
      actions: _Actions(),
      producer: producer,
    );
    final queued = await authorized.cashOut(
      commandId: 'offline-authorized',
      lease: activation.lease,
      collectionSessionId: 10,
      journalId: 12,
      cashOutTypeId: 9,
      amountMinor: 100,
      note: 'offline',
      offline: true,
    );
    expect(queued.state, CollectionOperationState.queued);
    final denied = RuntimeCollectionOperationPort(
      runtime: runtime,
      capabilities: CapabilitySnapshot(
        scopeKey: scope.scopeKey,
        companyId: 1,
        revision: 1,
        fetchedAt: DateTime.utc(2026),
      ),
      actions: _Actions(),
      producer: producer,
    );
    final rejected = await denied.cashOut(
      commandId: 'offline-denied',
      lease: activation.lease,
      collectionSessionId: 10,
      journalId: 12,
      cashOutTypeId: 9,
      amountMinor: 100,
      note: 'offline',
      offline: true,
    );
    expect(rejected.state, CollectionOperationState.rejected);
    await runtime.close();
  });

  test(
    'online fiscal wizards use native contracts when the scope is durable',
    () async {
      final scope = _scope('https://erp.test');
      final db = AppDatabase(NativeDatabase.memory());
      final runtime = SessionRuntime(
        databaseOwner: RuntimeDatabaseOwner(factory: (_) => db),
      );
      final activation = await runtime.activate(scope, apiKey: 'key');
      final actions = _Actions();
      final port = RuntimeCollectionOperationPort(
        runtime: runtime,
        capabilities: _caps(scope),
        actions: actions,
        producer: DurableCollectionProducer(db, OfflineQueueDataSource(db)),
      );

      final advance = await port.advance(
        commandId: 'advance-online',
        lease: activation.lease,
        paymentWizardId: 41,
        overpaymentMinor: 1250,
      );
      expect(advance.state, CollectionOperationState.synced);
      expect(
        actions.calls.single['model'],
        'l10n_ec_collection_box.confirm.advance.wizard',
      );
      expect(actions.calls.single['method'], 'action_create_advance');

      final withholding = await port.withholding(
        commandId: 'withhold-online',
        lease: activation.lease,
        wizardId: 52,
        collectionSessionId: 9,
        invoiceId: 77,
      );
      expect(withholding.state, CollectionOperationState.synced);
      final withholdCall = actions.calls.last;
      expect(withholdCall['model'], 'collection.session.withhold.wizard');
      expect(withholdCall['method'], 'action_create_withhold');
      expect(withholdCall['context'], {
        'active_model': 'account.move',
        'active_ids': [77],
        'default_session_id': 9,
        'default_withhold_type': 'out_withhold',
      });

      final creditNote = await port.creditNote(
        commandId: 'credit-note-online',
        lease: activation.lease,
        paymentWizardId: 52,
        lineIds: [3],
      );
      expect(creditNote.state, CollectionOperationState.synced);
      expect(
        actions.calls.last['model'],
        'l10n_ec_collection_box.sale.order.payment.wizard',
      );
      expect(actions.calls.last['method'], 'action_apply_and_create_invoice');
      await runtime.close();
    },
  );
}
