import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_panel/features/sales/sale_editor.dart';

final class _Commands implements SaleCommandStore {
  _Commands(this.result);
  final OperationOutcome<SaleOrderState> result;
  @override
  Future<OperationOutcome<SaleOrderState>> commitAndEnqueueIfAbsent({
    required String commandId,
    required EntityReference entity,
    required int expectedVersion,
    required OperationOutcome<SaleOrderState> outcome,
  }) async => result;
}

final class _Reconciliation implements CollectionReconciliationPort {
  @override
  Future<OperationOutcome<SaleOrderState>?> findByCommandOrReference({
    required String commandId,
    required EntityReference order,
    int? expectedAmountMinor,
  }) async => null;
}

final class _Collection implements SaleCollectionPort {
  @override
  Future<OperationOutcome<SaleOrderState>> collect({
    required String commandId,
    required EntityReference order,
    required int expectedVersion,
  }) => throw UnimplementedError();
}

final class _Shifts implements SaleShiftStore {
  @override
  Future<OperationOutcome<SaleShiftState>> apply({
    required String commandId,
    required EntityReference shift,
    required int expectedVersion,
    required SaleShiftState state,
  }) => throw UnimplementedError();
}

RuntimeSaleCommandPort _commands(OperationOutcome<SaleOrderState> result) =>
    RuntimeSaleCommandPort(
      SaleOperationOrchestrator(
        commands: _Commands(result),
        reconciliation: _Reconciliation(),
        collection: _Collection(),
        shifts: _Shifts(),
      ),
    );

CapabilitySnapshot _capabilities() => CapabilitySnapshot(
  scopeKey: 'scope-a',
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026),
);

SaleDraftSnapshot _draft({
  SaleApprovalState approval = SaleApprovalState.approved,
}) => SaleDraftSnapshot(
  scopeKey: 'scope-a',
  commandId: 'command-a',
  orderLocalId: 'local-a',
  orderRemoteId: 7,
  expectedVersion: 3,
  approval: approval,
);

OperationOutcome<SaleOrderState> _outcome({
  required SaleOrderState business,
  required OperationSyncState sync,
  List<OperationIssue> issues = const [],
}) => OperationOutcome(
  commandId: 'command-a',
  entity: EntityReference(localId: 'local-a', remoteId: 7),
  businessState: business,
  syncState: sync,
  issues: issues,
);

void main() {
  test('queued outcome keeps transport and business states', () async {
    final result = await RuntimeSaleEditorPort(
      _commands(
        _outcome(
          business: SaleOrderState.sale,
          sync: OperationSyncState.queued,
        ),
      ),
      _capabilities(),
    ).submit(_draft());

    expect(result.accepted, isTrue);
    expect(result.message, 'Venta encolada');
    expect(result.businessState, SaleOrderState.sale);
    expect(result.syncState, OperationSyncState.queued);
    expect(result.pendingAction, isFalse);
  });

  test(
    'rejection preserves the runtime issue message and failed state',
    () async {
      final result = await RuntimeSaleEditorPort(
        _commands(
          _outcome(
            business: SaleOrderState.rejected,
            sync: OperationSyncState.failed,
            issues: [
              OperationIssue(
                code: 'confirmation_rejected',
                messageKey: 'sale.confirmation.rejected',
              ),
            ],
          ),
        ),
        _capabilities(),
      ).submit(_draft());

      expect(result.accepted, isFalse);
      expect(result.message, 'No se pudo confirmar la venta');
      expect(result.syncState, OperationSyncState.failed);
      expect(result.approval, SaleApprovalState.approved);
      expect(result.issues.single.code, 'confirmation_rejected');
    },
  );

  test(
    'conflict preserves issue and does not masquerade as approval',
    () async {
      final result = await RuntimeSaleEditorPort(
        _commands(
          _outcome(
            business: SaleOrderState.approved,
            sync: OperationSyncState.conflict,
            issues: [
              OperationIssue(
                code: 'confirmation_version_conflict',
                messageKey: 'sale.version_conflict',
              ),
            ],
          ),
        ),
        _capabilities(),
      ).submit(_draft());

      expect(result.accepted, isFalse);
      expect(result.message, 'La venta cambió y requiere revisión');
      expect(result.syncState, OperationSyncState.conflict);
      expect(result.pendingAction, isFalse);
      expect(result.approval, SaleApprovalState.approved);
    },
  );

  test(
    'approval pending is derived only from an approval pending action',
    () async {
      final result = await RuntimeSaleEditorPort(
        _commands(
          _outcome(
            business: SaleOrderState.approved,
            sync: OperationSyncState.conflict,
            issues: [
              OperationIssue(
                code: 'confirmation_blocked',
                messageKey: 'sale.confirmation_blocked',
              ),
            ],
          ),
        ),
        _capabilities(),
      ).submit(_draft(approval: SaleApprovalState.pending));

      expect(result.accepted, isFalse);
      expect(result.message, 'La venta no puede confirmarse todavía');
      expect(result.approval, SaleApprovalState.pending);
      expect(result.pendingAction, isTrue);
    },
  );

  test(
    'synced outcome describes transport without assuming confirmation',
    () async {
      final result = await RuntimeSaleEditorPort(
        _commands(
          _outcome(
            business: SaleOrderState.sale,
            sync: OperationSyncState.synced,
          ),
        ),
        _capabilities(),
      ).submit(_draft());

      expect(result.accepted, isTrue);
      expect(result.message, 'Venta sincronizada');
      expect(result.message, isNot('Venta encolada'));
      expect(result.syncState, OperationSyncState.synced);
    },
  );
}
