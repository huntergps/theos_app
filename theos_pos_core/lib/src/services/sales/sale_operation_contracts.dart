import '../operations/operation_outcome.dart';
import '../../models/sales/sale_order_enums.dart';

enum SaleTermsClassification { cash, credit, mixed }

enum SaleApprovalState { required, pending, approved, rejected }

enum SaleCommandType {
  confirm,
  collect,
  openShift,
  closeShift,
  prepareDispatch,
}

enum SaleFiscalAction {
  none,
  invoiceOnConfirm,
  invoiceOnCollection,
  invoiceAndDispatchOnApproval,
}

enum SaleShiftState { open, closed }

enum SaleDeliveryGate { blocked, creditApproved, cashPaid, mixedDueSettled }

class PaymentTermInstallment {
  final int dueDays;
  PaymentTermInstallment({required this.dueDays}) {
    if (dueDays < 0) throw ArgumentError('invalid payment installment');
  }
}

class SaleDraftPayload {
  final int version;
  final EntityReference order;
  final int? paymentTermId;
  final List<PaymentTermInstallment> installments;
  final double total;

  SaleDraftPayload({
    this.version = 1,
    required this.order,
    this.paymentTermId,
    required List<PaymentTermInstallment> installments,
    required this.total,
  }) : installments = List.unmodifiable(installments) {
    if (version != 1) throw ArgumentError.value(version, 'version');
    if (total < 0) throw ArgumentError.value(total, 'total');
    if (installments.isEmpty)
      throw ArgumentError('payment term requires installments');
  }

  SaleTermsClassification get classification {
    final cash = installments.any((i) => i.dueDays == 0);
    final credit = installments.any((i) => i.dueDays > 0);
    return cash && credit
        ? SaleTermsClassification.mixed
        : credit
        ? SaleTermsClassification.credit
        : SaleTermsClassification.cash;
  }
}

class SaleConfirmationPayload {
  final int version;
  final EntityReference order;
  final SaleOrderState expectedState;
  final int expectedVersion;
  final SaleApprovalState approval;
  final bool fsc;
  final bool fullyPaid;
  final SaleTermsClassification classification;
  final SaleDeliveryGate deliveryGate;

  SaleConfirmationPayload({
    this.version = 1,
    required this.order,
    required this.expectedState,
    required this.expectedVersion,
    required this.approval,
    required this.fsc,
    required this.fullyPaid,
    required this.classification,
    this.deliveryGate = SaleDeliveryGate.blocked,
  }) {
    if (version != 1) throw ArgumentError.value(version, 'version');
    if (expectedVersion < 0)
      throw ArgumentError.value(expectedVersion, 'expectedVersion');
    if (fsc && classification != SaleTermsClassification.cash) {
      throw ArgumentError('FSC is only valid for cash terms');
    }
  }

  bool get canConfirm =>
      approval == SaleApprovalState.approved &&
      expectedState != SaleOrderState.cancel &&
      expectedState != SaleOrderState.sale &&
      expectedState != SaleOrderState.done;

  bool get canDeliver => switch (classification) {
    SaleTermsClassification.cash => deliveryGate == SaleDeliveryGate.cashPaid,
    SaleTermsClassification.credit =>
      deliveryGate == SaleDeliveryGate.creditApproved,
    SaleTermsClassification.mixed =>
      deliveryGate == SaleDeliveryGate.mixedDueSettled,
  };

  SaleFiscalAction get fiscalAction =>
      fsc && classification == SaleTermsClassification.cash
      ? SaleFiscalAction.invoiceAndDispatchOnApproval
      : classification == SaleTermsClassification.cash
      ? SaleFiscalAction.invoiceOnCollection
      : SaleFiscalAction.invoiceOnConfirm;
}

/// Fiscal identity supplied by an offline point of emission.
///
/// Odoo's `numbered_by_client` journal makes the client responsible for the
/// exclusive sequential and emission date.  This value object intentionally
/// does not generate either value: an operation is rejected when the local
/// fiscal authority did not provision all required fields.
final class OfflineFiscalInvoicePayload {
  final int? sequential;
  final String? emissionDate;
  final String? accessKey;

  const OfflineFiscalInvoicePayload({
    this.sequential,
    this.emissionDate,
    this.accessKey,
  });

  bool get isComplete => validate().isEmpty;

  List<String> validate() {
    final errors = <String>[];
    if (sequential == null || sequential! <= 0) {
      errors.add('sequential');
    }
    if (emissionDate == null || emissionDate!.trim().isEmpty) {
      errors.add('emission_date');
    } else if (DateTime.tryParse(emissionDate!) == null) {
      errors.add('emission_date_format');
    }
    if (accessKey == null ||
        accessKey!.trim().length != 49 ||
        !RegExp(r'^\d{49}$').hasMatch(accessKey!.trim())) {
      errors.add('access_key');
    }
    return List.unmodifiable(errors);
  }

  Map<String, dynamic> toOdoo() {
    final errors = validate();
    if (errors.isNotEmpty) {
      throw FormatException(
        'Incomplete offline fiscal identity: ${errors.join(', ')}',
      );
    }
    return {
      'sequential': sequential,
      'emission_date': emissionDate,
      'access_key': accessKey,
    };
  }
}

class SaleShiftPayload {
  final int version;
  final EntityReference shift;
  final int expectedVersion;
  SaleShiftPayload({
    this.version = 1,
    required this.shift,
    required this.expectedVersion,
  }) {
    if (version != 1 || expectedVersion < 0)
      throw ArgumentError('invalid shift payload');
  }
}

class SaleOperationContract {
  const SaleOperationContract();

  OperationOutcome<SaleOrderState> draftOutcome(
    SaleDraftPayload payload, {
    required String commandId,
  }) => OperationOutcome(
    commandId: commandId,
    entity: payload.order,
    businessState: SaleOrderState.draft,
    syncState: OperationSyncState.localOnly,
  );

  OperationOutcome<SaleOrderState> confirmationOutcome(
    SaleConfirmationPayload payload, {
    required String commandId,
  }) {
    if (!payload.canConfirm) {
      return OperationOutcome(
        commandId: commandId,
        entity: payload.order,
        businessState: payload.approval == SaleApprovalState.rejected
            ? SaleOrderState.rejected
            : payload.expectedState,
        syncState: OperationSyncState.localOnly,
        pendingAction: payload.approval == SaleApprovalState.pending
            ? PendingAction(
                type: PendingActionType.approval,
                entity: payload.order,
              )
            : null,
        issues: [
          OperationIssue(
            code: 'confirmation_blocked',
            messageKey: 'sale.confirmation_blocked',
          ),
        ],
      );
    }
    return OperationOutcome(
      commandId: commandId,
      entity: payload.order,
      businessState: SaleOrderState.sale,
      syncState: OperationSyncState.queued,
    );
  }

  OperationOutcome<SaleOrderState> collectionOutcome(
    SaleConfirmationPayload payload, {
    required String commandId,
    bool ambiguous = false,
  }) => OperationOutcome(
    commandId: commandId,
    entity: payload.order,
    businessState: payload.expectedState,
    syncState: ambiguous
        ? OperationSyncState.conflict
        : OperationSyncState.queued,
    fiscalState: ambiguous
        ? null
        : (payload.fiscalAction == SaleFiscalAction.invoiceOnCollection
              ? FiscalState.submitted
              : null),
    issues: ambiguous
        ? [
            OperationIssue(
              code: 'collection_ambiguous',
              messageKey: 'sale.collection_ambiguous',
              retryable: true,
            ),
          ]
        : const [],
  );

  OperationOutcome<SaleOrderState> preparationOutcome(
    SaleConfirmationPayload payload, {
    required String commandId,
  }) => OperationOutcome(
    commandId: commandId,
    entity: payload.order,
    businessState: payload.expectedState,
    syncState: OperationSyncState.queued,
    issues: const [],
  );

  OperationOutcome<SaleOrderState> deliveryOutcome(
    SaleConfirmationPayload payload, {
    required String commandId,
  }) => OperationOutcome(
    commandId: commandId,
    entity: payload.order,
    businessState: payload.expectedState,
    syncState: payload.canDeliver
        ? OperationSyncState.queued
        : OperationSyncState.conflict,
    issues: payload.canDeliver
        ? const []
        : [
            OperationIssue(
              code: 'delivery_payment_required',
              messageKey: 'sale.delivery_payment_required',
            ),
          ],
  );

  OperationOutcome<SaleShiftState> openShiftOutcome(
    SaleShiftPayload payload, {
    required String commandId,
  }) => OperationOutcome(
    commandId: commandId,
    entity: payload.shift,
    businessState: SaleShiftState.open,
    syncState: OperationSyncState.queued,
  );

  OperationOutcome<SaleShiftState> closeShiftOutcome(
    SaleShiftPayload payload, {
    required String commandId,
  }) => OperationOutcome(
    commandId: commandId,
    entity: payload.shift,
    businessState: SaleShiftState.closed,
    syncState: OperationSyncState.queued,
  );
}
