import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  test('author filter can be removed without changing other predicates', () {
    final query = OrderQuery(
      companyId: 7,
      authorFilter: 42,
      text: 'acme',
      states: {SaleOrderState.draft},
      limit: 25,
      workQueue: OrderWorkQueue.cashierPending,
    );
    final broad = query.withoutAuthorFilter();
    expect(broad.authorFilter, isNull);
    expect(broad.companyId, query.companyId);
    expect(broad.text, query.text);
    expect(broad.states, query.states);
    expect(broad.limit, query.limit);
    expect(broad.workQueue, OrderWorkQueue.cashierPending);
  });

  test('outcome keeps business, sync, fiscal and pending states separate', () {
    final outcome = OperationOutcome<SaleOrderState>(
      commandId: 'cmd-1',
      entity: EntityReference(localId: 'local-1', remoteId: 9),
      businessState: SaleOrderState.waitingApproval,
      syncState: OperationSyncState.queued,
      fiscalState: FiscalState.emittedLocal,
      pendingAction: PendingAction(
        type: PendingActionType.approval,
        entity: EntityReference(localId: 'local-1', remoteId: 9),
      ),
    );
    expect(outcome.businessState, SaleOrderState.waitingApproval);
    expect(outcome.syncState, OperationSyncState.queued);
    expect(outcome.fiscalState, FiscalState.emittedLocal);
    expect(outcome.pendingAction?.type, PendingActionType.approval);
  });

  test('query has deterministic keyset ordering', () {
    expect(OrderQuery(companyId: 1).stableOrder, 'date_order:desc,id:desc');
  });

  test('outcome supports collection SessionState without parallel enums', () {
    final outcome = OperationOutcome<SessionState>(
      commandId: 'cash-open',
      entity: EntityReference(localId: 'session-1'),
      businessState: SessionState.opened,
      syncState: OperationSyncState.synced,
    );
    expect(outcome.businessState, SessionState.opened);
  });

  test('contracts defensively copy collections and validate at runtime', () {
    final queryStates = <SaleOrderState>{SaleOrderState.draft};
    final query = OrderQuery(companyId: 1, states: queryStates);
    queryStates.add(SaleOrderState.sale);
    expect(query.states, {SaleOrderState.draft});
    expect(() => OrderQuery(companyId: 1, limit: 0), throwsArgumentError);
    expect(
      () => OrderQuery(
        companyId: 1,
        dateFrom: DateTime(2026, 2),
        dateTo: DateTime(2026, 1),
      ),
      throwsArgumentError,
    );
    expect(() => CommandScope(scopeKey: '', companyId: 1), throwsArgumentError);
    expect(
      () => CreateOrder(
        scope: CommandScope(scopeKey: 'scope', companyId: 1),
        commandId: '',
        target: CommandTarget(entity: EntityReference(localId: 'local')),
      ),
      throwsArgumentError,
    );
    expect(
      () => CommandTarget(
        entity: EntityReference(localId: 'local'),
        expectedVersion: -1,
      ),
      throwsArgumentError,
    );
  });

  test('capability, pending context and issues are immutable snapshots', () {
    final permissions = <String>{'sale'};
    final context = <String, String>{'reason': 'offline'};
    final args = <String, String>{'field': 'amount'};
    final issue = OperationIssue(code: 'E', messageKey: 'error', args: args);
    final capability = CapabilitySnapshot(
      scopeKey: 'scope',
      companyId: 1,
      revision: 1,
      fetchedAt: DateTime(2026),
      permissions: permissions,
    );
    final pending = PendingAction(
      type: PendingActionType.sync,
      entity: EntityReference(localId: 'local'),
      context: context,
    );
    permissions.add('cash');
    context['other'] = 'value';
    args['other'] = 'value';
    expect(capability.permissions, {'sale'});
    expect(pending.context, {'reason': 'offline'});
    expect(issue.args, {'field': 'amount'});
    expect(capability.fetchedAt.isUtc, isTrue);
  });
}
