import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  const policy = SaleOperationContract();
  final order = EntityReference(localId: 'order-1');
  List<PaymentTermInstallment> terms({
    bool cash = false,
    bool credit = false,
  }) => [
    if (cash) PaymentTermInstallment(dueDays: 0),
    if (credit) PaymentTermInstallment(dueDays: 30),
  ];
  SaleConfirmationPayload confirmation({
    SaleTermsClassification classification = SaleTermsClassification.cash,
    SaleApprovalState approval = SaleApprovalState.approved,
    SaleOrderState state = SaleOrderState.approved,
    bool fsc = false,
    bool paid = false,
    SaleDeliveryGate gate = SaleDeliveryGate.blocked,
  }) => SaleConfirmationPayload(
    order: order,
    expectedState: state,
    expectedVersion: 1,
    approval: approval,
    fsc: fsc,
    fullyPaid: paid,
    classification: classification,
    deliveryGate: gate,
  );

  test('classification derives from installment due days', () {
    expect(
      SaleDraftPayload(
        order: order,
        installments: terms(cash: true),
        total: 10,
      ).classification,
      SaleTermsClassification.cash,
    );
    expect(
      SaleDraftPayload(
        order: order,
        installments: terms(credit: true),
        total: 10,
      ).classification,
      SaleTermsClassification.credit,
    );
    expect(
      SaleDraftPayload(
        order: order,
        installments: terms(cash: true, credit: true),
        total: 10,
      ).classification,
      SaleTermsClassification.mixed,
    );
  });
  test('approval gate and confirmed order lock confirmation', () {
    expect(
      policy
          .confirmationOutcome(
            confirmation(approval: SaleApprovalState.pending),
            commandId: 'c',
          )
          .hasIssues,
      isTrue,
    );
    expect(
      policy
          .confirmationOutcome(
            confirmation(approval: SaleApprovalState.required),
            commandId: 'c',
          )
          .hasIssues,
      isTrue,
    );
    expect(
      policy
          .confirmationOutcome(
            confirmation(state: SaleOrderState.sale),
            commandId: 'c',
          )
          .hasIssues,
      isTrue,
    );
  });
  test('fiscal timing, FSC, preparation, and delivery gate', () {
    expect(
      confirmation(classification: SaleTermsClassification.credit).fiscalAction,
      SaleFiscalAction.invoiceOnConfirm,
    );
    expect(
      confirmation(classification: SaleTermsClassification.cash).fiscalAction,
      SaleFiscalAction.invoiceOnCollection,
    );
    expect(
      confirmation(classification: SaleTermsClassification.mixed).fiscalAction,
      SaleFiscalAction.invoiceOnConfirm,
    );
    expect(
      () => confirmation(
        classification: SaleTermsClassification.credit,
        fsc: true,
      ),
      throwsArgumentError,
    );
    final fsc = confirmation(
      fsc: true,
      gate: SaleDeliveryGate.cashPaid,
      paid: true,
    );
    expect(fsc.fiscalAction, SaleFiscalAction.invoiceAndDispatchOnApproval);
    expect(fsc.canDeliver, isTrue);
    expect(
      confirmation(
        classification: SaleTermsClassification.credit,
        gate: SaleDeliveryGate.creditApproved,
      ).canDeliver,
      isTrue,
    );
    expect(
      confirmation(
        classification: SaleTermsClassification.mixed,
        gate: SaleDeliveryGate.mixedDueSettled,
      ).canDeliver,
      isTrue,
    );
    expect(
      policy.preparationOutcome(fsc, commandId: 'prepare').hasIssues,
      isFalse,
    );
    expect(
      policy.deliveryOutcome(fsc, commandId: 'deliver').hasIssues,
      isFalse,
    );
    expect(
      policy
          .deliveryOutcome(
            confirmation(fsc: true),
            commandId: 'deliver-blocked',
          )
          .hasIssues,
      isTrue,
    );
  });
  test('ambiguous collection has no fiscal authorization and is retryable', () {
    final outcome = policy.collectionOutcome(
      confirmation(),
      commandId: 'collect-1',
      ambiguous: true,
    );
    expect(outcome.syncState, OperationSyncState.conflict);
    expect(outcome.fiscalState, isNull);
    expect(outcome.issues.single.retryable, isTrue);
  });
  test('shift open and close preserve typed states', () {
    final shift = SaleShiftPayload(
      shift: EntityReference(localId: 'shift-1'),
      expectedVersion: 2,
    );
    expect(
      policy.openShiftOutcome(shift, commandId: 'open-1').businessState,
      SaleShiftState.open,
    );
    expect(
      policy.closeShiftOutcome(shift, commandId: 'close-1').businessState,
      SaleShiftState.closed,
    );
  });
}
