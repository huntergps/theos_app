import 'package:theos_pos_core/theos_pos_core.dart';

/// Composition-facing command port. UI supplies versioned core payloads;
/// runtime delegates to the durable orchestrator and never fabricates success.
final class RuntimeSaleCommandPort {
  final SaleOperationOrchestrator orchestrator;
  const RuntimeSaleCommandPort(this.orchestrator);

  Future<OperationOutcome<SaleOrderState>> confirm(
    SaleConfirmationPayload payload, {
    required String commandId,
  }) => orchestrator.confirm(payload, commandId: commandId);

  Future<OperationOutcome<SaleOrderState>> collect(
    SaleConfirmationPayload payload, {
    required String commandId,
    required bool ambiguousRetry,
  }) => orchestrator.collect(
    payload,
    commandId: commandId,
    ambiguousRetry: ambiguousRetry,
  );

  Future<OperationOutcome<SaleShiftState>> openShift(
    SaleShiftPayload payload, {
    required String commandId,
  }) => orchestrator.openShift(payload, commandId: commandId);

  Future<OperationOutcome<SaleShiftState>> closeShift(
    SaleShiftPayload payload, {
    required String commandId,
  }) => orchestrator.closeShift(payload, commandId: commandId);
}
