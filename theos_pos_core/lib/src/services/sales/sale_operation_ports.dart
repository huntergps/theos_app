import '../operations/operation_outcome.dart';
import 'sale_operation_contracts.dart';
import '../../models/sales/sale_order_enums.dart';

/// Durable transaction boundary: absent-command check, local commit and queue
/// insertion are one atomic operation in the implementation.
abstract interface class SaleCommandStore {
  Future<OperationOutcome<SaleOrderState>> commitAndEnqueueIfAbsent({
    required String commandId,
    required EntityReference entity,
    required int expectedVersion,
    required OperationOutcome<SaleOrderState> outcome,
  });
}

abstract interface class CollectionReconciliationPort {
  Future<OperationOutcome<SaleOrderState>?> findByCommandOrReference({
    required String commandId,
    required EntityReference order,
    int? expectedAmountMinor,
  });
}

abstract interface class SaleCollectionPort {
  Future<OperationOutcome<SaleOrderState>> collect({
    required String commandId,
    required EntityReference order,
    required int expectedVersion,
  });
}

abstract interface class SaleShiftStore {
  Future<OperationOutcome<SaleShiftState>> apply({
    required String commandId,
    required EntityReference shift,
    required int expectedVersion,
    required SaleShiftState state,
  });
}

class SaleOperationOrchestrator {
  final SaleCommandStore commands;
  final CollectionReconciliationPort reconciliation;
  final SaleCollectionPort collection;
  final SaleShiftStore shifts;
  const SaleOperationOrchestrator({
    required this.commands,
    required this.reconciliation,
    required this.collection,
    required this.shifts,
  });

  Future<OperationOutcome<SaleOrderState>> confirm(
    SaleConfirmationPayload payload, {
    required String commandId,
  }) async {
    final outcome = const SaleOperationContract().confirmationOutcome(
      payload,
      commandId: commandId,
    );
    if (outcome.hasIssues) return outcome;
    return commands.commitAndEnqueueIfAbsent(
      commandId: commandId,
      entity: payload.order,
      expectedVersion: payload.expectedVersion,
      outcome: outcome,
    );
  }

  Future<OperationOutcome<SaleOrderState>> collect(
    SaleConfirmationPayload payload, {
    required String commandId,
    required bool ambiguousRetry,
    int? expectedAmountMinor,
  }) async {
    if (ambiguousRetry) {
      final observed = await reconciliation.findByCommandOrReference(
        commandId: commandId,
        order: payload.order,
        expectedAmountMinor: expectedAmountMinor,
      );
      if (observed != null) return observed;
    }
    return collection.collect(
      commandId: commandId,
      order: payload.order,
      expectedVersion: payload.expectedVersion,
    );
  }

  Future<OperationOutcome<SaleShiftState>> openShift(
    SaleShiftPayload payload, {
    required String commandId,
  }) => shifts.apply(
    commandId: commandId,
    shift: payload.shift,
    expectedVersion: payload.expectedVersion,
    state: SaleShiftState.open,
  );

  Future<OperationOutcome<SaleShiftState>> closeShift(
    SaleShiftPayload payload, {
    required String commandId,
  }) => shifts.apply(
    commandId: commandId,
    shift: payload.shift,
    expectedVersion: payload.expectedVersion,
    state: SaleShiftState.closed,
  );
}
