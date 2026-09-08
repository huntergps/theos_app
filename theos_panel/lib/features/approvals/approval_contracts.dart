import 'package:orbi_runtime/orbi_runtime.dart';

enum ApprovalTerms { cash, credit, mixed }

enum ApprovalStatus { requested, approved, rejected }

enum ApprovalDecision { approve, reject }

/// Actions are deliberately named after the F05/F07 operation boundary.
/// Implementations own authority checks and transport; the panel only renders
/// these outcomes and never calls an ERP method.
enum ApprovalAction { commercialRequest, fscInvoiceAndDispatch, delivery }

class ApprovalRequest {
  ApprovalRequest({
    required this.commandId,
    required this.orderDisplayName,
    this.approvalRequestRemoteId,
    this.saleOrderRemoteId,
    required this.terms,
    required this.fsc,
    required this.status,
    this.partnerId,
    this.transactionAmount,
    this.paymentTermId,
  }) {
    if (commandId.trim().isEmpty || orderDisplayName.trim().isEmpty) {
      throw ArgumentError('approval identity is required');
    }
    if (fsc && terms != ApprovalTerms.cash) {
      throw ArgumentError('FSC is only valid for cash terms');
    }
  }
  final String commandId;
  final String orderDisplayName;
  final int? approvalRequestRemoteId;
  final int? saleOrderRemoteId;
  final ApprovalTerms terms;
  final bool fsc;
  final ApprovalStatus status;
  final int? partnerId;
  final double? transactionAmount;
  final int? paymentTermId;
}

class ApprovalResult {
  const ApprovalResult({
    required this.accepted,
    required this.message,
    this.commandId,
    this.pendingAction,
  });
  final bool accepted;
  final String message;
  final String? commandId;
  final String? pendingAction;
}

/// F07 adapter port. `snapshot` is supplied on every decision so the adapter
/// can revalidate effective authority, including offline provision validity.
abstract interface class ApprovalPort {
  Future<List<ApprovalRequest>> pending();
  Future<ApprovalResult> request(ApprovalRequest request);
  Future<ApprovalResult> resolve({
    required ApprovalRequest request,
    required ApprovalDecision decision,
    required CapabilitySnapshot snapshot,
    required bool offline,
  });
  Future<ApprovalResult> performAction({
    required ApprovalRequest request,
    required ApprovalAction action,
    required CapabilitySnapshot snapshot,
    required bool offline,
  });
}

final class UnavailableApprovalPort implements ApprovalPort {
  const UnavailableApprovalPort();
  @override
  Future<List<ApprovalRequest>> pending() async => const [];
  @override
  Future<ApprovalResult> request(ApprovalRequest request) async =>
      const ApprovalResult(
        accepted: false,
        message: 'Aprobaciones no configuradas',
      );
  @override
  Future<ApprovalResult> resolve({
    required ApprovalRequest request,
    required ApprovalDecision decision,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async => const ApprovalResult(
    accepted: false,
    message: 'Aprobaciones no configuradas',
  );
  @override
  Future<ApprovalResult> performAction({
    required ApprovalRequest request,
    required ApprovalAction action,
    required CapabilitySnapshot snapshot,
    required bool offline,
  }) async => const ApprovalResult(
    accepted: false,
    message: 'Aprobaciones no configuradas',
  );
}
