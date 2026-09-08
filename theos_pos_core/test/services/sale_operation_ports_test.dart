import 'dart:async';

import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

class AtomicFake implements SaleCommandStore {
  final Map<String, OperationOutcome<SaleOrderState>> saved = {};
  int writes = 0;
  Future<void> _tail = Future<void>.value();
  @override
  Future<OperationOutcome<SaleOrderState>> commitAndEnqueueIfAbsent({
    required String commandId,
    required EntityReference entity,
    required int expectedVersion,
    required OperationOutcome<SaleOrderState> outcome,
  }) {
    final result = Completer<OperationOutcome<SaleOrderState>>();
    _tail = _tail.then((_) {
      final prior = saved[commandId];
      if (prior != null) {
        result.complete(prior);
        return;
      }
      writes++;
      saved[commandId] = outcome;
      result.complete(outcome);
    });
    return result.future;
  }
}

class ReconFake implements CollectionReconciliationPort {
  OperationOutcome<SaleOrderState>? observed;
  int lookups = 0;
  @override
  Future<OperationOutcome<SaleOrderState>?> findByCommandOrReference({
    required String commandId,
    required EntityReference order,
    int? expectedAmountMinor,
  }) async {
    lookups++;
    return observed;
  }
}

class CollectionFake implements SaleCollectionPort {
  int calls = 0;
  @override
  Future<OperationOutcome<SaleOrderState>> collect({
    required String commandId,
    required EntityReference order,
    required int expectedVersion,
  }) async {
    calls++;
    return OperationOutcome(
      commandId: commandId,
      entity: order,
      businessState: SaleOrderState.sale,
      syncState: OperationSyncState.queued,
    );
  }
}

class ShiftFake implements SaleShiftStore {
  @override
  Future<OperationOutcome<SaleShiftState>> apply({
    required String commandId,
    required EntityReference shift,
    required int expectedVersion,
    required SaleShiftState state,
  }) async => OperationOutcome(
    commandId: commandId,
    entity: shift,
    businessState: state,
    syncState: OperationSyncState.conflict,
  );
}

void main() {
  final order = EntityReference(localId: 'order-1');
  SaleConfirmationPayload payload() => SaleConfirmationPayload(
    order: order,
    expectedState: SaleOrderState.approved,
    expectedVersion: 3,
    approval: SaleApprovalState.approved,
    fsc: false,
    fullyPaid: false,
    classification: SaleTermsClassification.credit,
    deliveryGate: SaleDeliveryGate.creditApproved,
  );

  test(
    'concurrent confirmations commit and enqueue once at durable boundary',
    () async {
      final store = AtomicFake();
      final orchestrator = SaleOperationOrchestrator(
        commands: store,
        reconciliation: ReconFake(),
        collection: CollectionFake(),
        shifts: ShiftFake(),
      );
      final results = await Future.wait([
        orchestrator.confirm(payload(), commandId: 'same'),
        orchestrator.confirm(payload(), commandId: 'same'),
      ]);
      expect(results[0].commandId, results[1].commandId);
      expect(store.writes, 1);
    },
  );

  test(
    'ambiguous collection reconciles before retry and never calls collect',
    () async {
      final recon = ReconFake();
      final collection = CollectionFake();
      final observed = OperationOutcome(
        commandId: 'pay',
        entity: order,
        businessState: SaleOrderState.sale,
        syncState: OperationSyncState.synced,
      );
      recon.observed = observed;
      final orchestrator = SaleOperationOrchestrator(
        commands: AtomicFake(),
        reconciliation: recon,
        collection: collection,
        shifts: ShiftFake(),
      );
      final result = await orchestrator.collect(
        payload(),
        commandId: 'pay',
        ambiguousRetry: true,
      );
      expect(result.syncState, OperationSyncState.synced);
      expect(recon.lookups, 1);
      expect(collection.calls, 0);
    },
  );
}
