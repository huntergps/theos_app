import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/erp2_harness.dart';

void main() {
  test('target guard accepts only the exact ERP2 host and rejects admin', () {
    final config = Erp2HarnessConfig.fromEnvironment({
      ..._baseEnvironment,
      'ORBI_ERP2_SERVER_URL': 'https://newerp.tecnosmart.com.ec',
      'ORBI_ERP2_SELLER_LOGIN': 'admin',
    });

    final errors = config.targetErrors();

    expect(
      errors,
      contains('ORBI_ERP2_SERVER_URL must be the exact ERP2 HTTPS host'),
    );
    expect(errors, contains('newerp is prohibited'));
    expect(errors, contains('seller must not use admin'));
  });

  test('native payment wizard keeps line_type on parent, not child', () {
    const rpc = Erp2RpcContract();
    expect(rpc.paymentWizardLineType, 'payment');
    expect(
      Erp2PaymentWizardContract.errors(
        wizardFields: {
          'sale_id',
          'collection_session_id',
          'line_ids',
          'line_type',
        },
        lineFields: {
          'amount',
          'journal_id',
          'payment_method_line_id',
          'pos_collection_line_uuid',
        },
      ),
      isEmpty,
    );
    expect(
      Erp2PaymentWizardContract.errors(
        wizardFields: {'sale_id', 'collection_session_id', 'line_ids'},
        lineFields: {
          'line_type',
          'amount',
          'journal_id',
          'payment_method_line_id',
          'pos_collection_line_uuid',
        },
      ),
      containsAll(<String>[
        'l10n_ec_collection_box.sale.order.payment.wizard.line_type '
            'is required for payment wizard',
        'l10n_ec_collection_box.sale.order.payment.wizard.line.line_type '
            'must be sent on the parent wizard',
      ]),
    );
  });

  test('write guard requires four prefixed fixtures, actors and RPC', () {
    final config = Erp2HarnessConfig.fromEnvironment({
      ..._baseEnvironment,
      'ORBI_ERP2_ENABLE_WRITES': 'I_UNDERSTAND_ORBI_E2E_WRITES',
      'ORBI_ERP2_RUN_WRITES': 'I_UNDERSTAND_ORBI_E2E_WRITES',
      'ORBI_ERP2_WRITE_PREFIX': 'ORBI-E2E-0123456789abcdef',
      'ORBI_ERP2_CLEANUP_MODE': 'retain-prefixed-fixtures',
      'ORBI_ERP2_PANEL_MODE': 'without-panel',
      'ORBI_ERP2_EVIDENCE_FILE': '/tmp/orbi-e2e-evidence.json',
      'ORBI_ERP2_SELLER_USER_ID': '1',
      'ORBI_ERP2_CASHIER_USER_ID': '2',
      'ORBI_ERP2_SUPERVISOR_USER_ID': '3',
      'ORBI_ERP2_WAREHOUSE_USER_ID': '34',
      'ORBI_ERP2_WAREHOUSE_LOGIN': 'miguel.mora',
      'ORBI_ERP2_CASH_ORDER_ID': '10',
      'ORBI_ERP2_CASH_REFERENCE': 'ORBI-E2E-0123456789abcdef-cash',
      'ORBI_ERP2_CASH_APPROVAL_ID': '19',
      'ORBI_ERP2_CREDIT_ORDER_ID': '11',
      'ORBI_ERP2_CREDIT_REFERENCE': 'ORBI-E2E-0123456789abcdef-credit',
      'ORBI_ERP2_CREDIT_APPROVAL_ID': '20',
      'ORBI_ERP2_MIXED_ORDER_ID': '12',
      'ORBI_ERP2_MIXED_REFERENCE': 'ORBI-E2E-0123456789abcdef-mixed',
      'ORBI_ERP2_MIXED_APPROVAL_ID': '21',
      'ORBI_ERP2_FSC_ORDER_ID': '13',
      'ORBI_ERP2_FSC_REFERENCE': 'ORBI-E2E-0123456789abcdef-fsc',
      'ORBI_ERP2_FSC_COMMERCIAL_APPROVAL_ID': '22',
      'ORBI_ERP2_CASH_SESSION_ID': '14',
      'ORBI_ERP2_CASH_JOURNAL_ID': '15',
      'ORBI_ERP2_CASH_PAYMENT_METHOD_ID': '16',
      'ORBI_ERP2_MIXED_CASH_AMOUNT': '10.00',
    });

    expect(config.writeErrors(), isEmpty);
    expect(config.rpc.confirm, 'action_pos_confirm');
    expect(config.rpc.cashInvoice, 'action_pos_confirm_and_invoice');
    expect(
      config.rpc.fscRequest,
      'action_l10n_ec_solicitar_facturar_sin_cobro',
    );
    expect(config.rpc.existingInvoicePayment, 'action_apply_existing_invoice');
    expect(config.rpc.assignPicking, 'action_assign');
    expect(config.rpc.validatePicking, 'button_validate');
    expect(
      config.rpc.mixedPaymentAndDispatch,
      'action_apply_and_create_invoice',
    );
    expect(config.fixtures[Erp2FlowKind.fsc]!.approvalId, 22);
    expect(config.toRedactedJson().toString(), isNot(contains('PASSWORD')));
  });

  test(
    'write guard fixes warehouse identity and discovers FSC IDs in-flow',
    () {
      final config = Erp2HarnessConfig.fromEnvironment({
        ..._baseEnvironment,
        'ORBI_ERP2_ENABLE_WRITES': 'I_UNDERSTAND_ORBI_E2E_WRITES',
        'ORBI_ERP2_RUN_WRITES': 'I_UNDERSTAND_ORBI_E2E_WRITES',
        'ORBI_ERP2_WRITE_PREFIX': 'ORBI-E2E-0123456789abcdef',
        'ORBI_ERP2_CLEANUP_MODE': 'retain-prefixed-fixtures',
        'ORBI_ERP2_PANEL_MODE': 'without-panel',
        'ORBI_ERP2_EVIDENCE_FILE': '/tmp/orbi-e2e-evidence.json',
        'ORBI_ERP2_SELLER_USER_ID': '9',
        'ORBI_ERP2_CASHIER_USER_ID': '23',
        'ORBI_ERP2_SUPERVISOR_USER_ID': '14',
        'ORBI_ERP2_WAREHOUSE_USER_ID': '34',
        'ORBI_ERP2_CASH_ORDER_ID': '10',
        'ORBI_ERP2_CASH_REFERENCE': 'ORBI-E2E-0123456789abcdef-cash',
        'ORBI_ERP2_CREDIT_ORDER_ID': '11',
        'ORBI_ERP2_CREDIT_REFERENCE': 'ORBI-E2E-0123456789abcdef-credit',
        'ORBI_ERP2_MIXED_ORDER_ID': '12',
        'ORBI_ERP2_MIXED_REFERENCE': 'ORBI-E2E-0123456789abcdef-mixed',
        'ORBI_ERP2_FSC_ORDER_ID': '13',
        'ORBI_ERP2_FSC_REFERENCE': 'ORBI-E2E-0123456789abcdef-fsc',
        'ORBI_ERP2_CASH_SESSION_ID': '18',
        'ORBI_ERP2_CASH_JOURNAL_ID': '30',
        'ORBI_ERP2_CASH_PAYMENT_METHOD_ID': '44',
        'ORBI_ERP2_MIXED_CASH_AMOUNT': '10.00',
      });

      expect(config.writeErrors(), isEmpty);
      expect(
        config.toRedactedJson().containsKey('fscApprovalConfigured'),
        isFalse,
      );
    },
  );

  test('write guard rejects a different warehouse identity', () {
    final config = Erp2HarnessConfig.fromEnvironment({
      ..._baseEnvironment,
      'ORBI_ERP2_ENABLE_WRITES': 'I_UNDERSTAND_ORBI_E2E_WRITES',
      'ORBI_ERP2_RUN_WRITES': 'I_UNDERSTAND_ORBI_E2E_WRITES',
      'ORBI_ERP2_WRITE_PREFIX': 'ORBI-E2E-0123456789abcdef',
      'ORBI_ERP2_CLEANUP_MODE': 'retain-prefixed-fixtures',
      'ORBI_ERP2_PANEL_MODE': 'without-panel',
      'ORBI_ERP2_EVIDENCE_FILE': '/tmp/orbi-e2e-evidence.json',
      'ORBI_ERP2_WAREHOUSE_USER_ID': '43',
      'ORBI_ERP2_WAREHOUSE_LOGIN': 'sebastian.rodriguez',
    });

    expect(
      config.writeErrors(),
      contains('warehouse must be Miguel Mora (miguel.mora, user ID 34)'),
    );
  });

  test(
    'flow plans preserve distinct term-driven invoice and dispatch timing',
    () {
      expect(
        Erp2FlowPlan.all.map((plan) => plan.kind),
        containsAll([
          Erp2FlowKind.cash,
          Erp2FlowKind.credit,
          Erp2FlowKind.mixed,
          Erp2FlowKind.fsc,
        ]),
      );
      expect(
        Erp2FlowPlan.all
            .singleWhere((plan) => plan.kind == Erp2FlowKind.cash)
            .dispatch,
        'on-cobro',
      );
      expect(
        Erp2FlowPlan.all
            .singleWhere((plan) => plan.kind == Erp2FlowKind.mixed)
            .dispatch,
        'none at confirm; official payment wizard creates picking',
      );
      expect(
        Erp2FlowPlan.all
            .singleWhere((plan) => plan.kind == Erp2FlowKind.fsc)
            .invoice,
        'on-FSC-approval',
      );
    },
  );

  test('payment term classification does not use legacy is_cash_sale', () {
    expect(
      classifyPaymentTerm(
        lines: [
          {'nb_days': 0, 'delay_type': 'days_after'},
        ],
        isFsc: false,
      ),
      Erp2FlowKind.cash,
    );
    expect(
      classifyPaymentTerm(
        lines: [
          {'nb_days': 0, 'delay_type': 'days_after'},
          {'nb_days': 30, 'delay_type': 'days_after'},
        ],
        isFsc: false,
      ),
      Erp2FlowKind.mixed,
    );
    expect(
      classifyPaymentTerm(
        lines: [
          {'nb_days': 30, 'delay_type': 'days_after'},
        ],
        isFsc: false,
      ),
      Erp2FlowKind.credit,
    );
    expect(
      classifyPaymentTerm(
        lines: [
          {'nb_days': 0, 'delay_type': 'days_after'},
        ],
        isFsc: true,
      ),
      Erp2FlowKind.fsc,
    );
    expect(
      classifyPaymentTerm(
        lines: [
          {'nb_days': 0, 'delay_type': 'day_of_the_month'},
        ],
        isFsc: false,
      ),
      isNull,
    );
  });

  test('mixed flow does not require offline fiscal identity fields', () {
    final config = Erp2HarnessConfig.fromEnvironment({
      ..._baseEnvironment,
      'ORBI_ERP2_MIXED_ORDER_ID': '12',
      'ORBI_ERP2_MIXED_REFERENCE': 'ORBI-E2E-test-mixed',
    });
    expect(
      config.writeErrors(),
      isNot(contains('mixed backend fiscal identity is required')),
    );
    expect(config.toRedactedJson().toString(), isNot(contains('accessKey')));
  });

  test('mixed existing invoice rejects create-invoice route', () {
    const rpc = Erp2RpcContract();

    expect(
      Erp2MixedPaymentContract.errors(
        invoiceAlreadyExists: true,
        method: rpc.mixedPaymentAndDispatch,
        rpc: rpc,
      ),
      contains('mixed existing invoice requires action_apply_existing_invoice'),
    );
    expect(
      Erp2MixedPaymentContract.errors(
        invoiceAlreadyExists: true,
        method: rpc.existingInvoicePayment,
        rpc: rpc,
      ),
      isEmpty,
    );
  });

  test('actor capabilities reject a user with the wrong real groups', () {
    const groupIds = {
      'sales_team.group_sale_salesman': 10,
      'l10n_ec_collection_box.group_collection_user': 20,
      'l10n_ec_collection_box.group_collection_manager': 30,
      'approvals.group_approval_user': 40,
      'stock.group_stock_user': 50,
    };
    final rows = <Erp2Actor, Map<String, dynamic>>{
      for (final actor in Erp2Actor.values)
        actor: {
          'all_group_ids': [groupIds.values.first],
        },
    };
    final errors = Erp2ActorCapabilityContract.errorsForRows(rows, groupIds);
    expect(
      errors,
      contains(
        'cashier lacks required group '
        'l10n_ec_collection_box.group_collection_user',
      ),
    );
    expect(
      errors,
      contains(
        'supervisor lacks required group '
        'approvals.group_approval_user',
      ),
    );
    expect(
      errors,
      contains('warehouse lacks required group stock.group_stock_user'),
    );
  });

  test('FSC mock contract permits one native approval only', () {
    const rpc = Erp2RpcContract();
    final native = [
      Erp2FscApprovalInvocation(
        model: 'sale.order',
        method: rpc.fscInvoiceAndDispatch,
      ),
    ];
    expect(Erp2FscApprovalContract.errors(native, rpc), isEmpty);
    expect(
      Erp2FscApprovalContract.errors([
        ...native,
        Erp2FscApprovalInvocation(
          model: 'approval.request',
          method: rpc.approvalApprove,
        ),
      ], rpc),
      contains('FSC must not use generic approval twice'),
    );
    expect(
      Erp2FscApprovalContract.errors([], rpc),
      contains('FSC requires exactly one native approval'),
    );
  });

  test('native payment reconciliation rejects a sale-wide aggregate', () {
    final row = <String, dynamic>{
      'state': 'posted',
      'amount': 10.0,
      'move_id': [101, 'move'],
      'pos_collection_op_uuid': 'other-operation',
      'pos_collection_line_uuid': 'other-line',
    };
    expect(
      Erp2NativePaymentReconciliationContract.errors(
        [row],
        operationUuid: 'target-operation',
        expectedAmount: 10,
      ),
      contains('native payment has invalid or mismatched operation identity'),
    );
    expect(
      Erp2NativePaymentReconciliationContract.errors(
        [
          {...row, 'pos_collection_op_uuid': 'target-operation'},
          {...row, 'pos_collection_op_uuid': 'target-operation'},
        ],
        operationUuid: 'target-operation',
        expectedAmount: 20,
      ),
      contains('native payment has invalid or mismatched operation identity'),
    );
  });

  test(
    'replay keeps an ambiguous response pending until server verification',
    () {
      expect(
        const Erp2ReplayObservation(
          transportSucceeded: null,
          transportError: true,
          serverStateMatches: false,
        ).state,
        Erp2ReplayState.ambiguous,
      );
      expect(
        const Erp2ReplayObservation(
          transportSucceeded: null,
          transportError: true,
          serverStateMatches: true,
        ).state,
        Erp2ReplayState.applied,
      );
      expect(
        const Erp2ReplayObservation(
          transportSucceeded: false,
          transportError: false,
          serverStateMatches: false,
        ).state,
        Erp2ReplayState.rejected,
      );
    },
  );
}

const _baseEnvironment = <String, String>{
  'ORBI_ERP2_SERVER_URL': 'https://erp2.tecnosmart.com.ec',
  'ORBI_ERP2_DATABASE': 'erp2_test',
  'ORBI_ERP2_SELLER_LOGIN': 'seller',
  'ORBI_ERP2_CASHIER_LOGIN': 'cashier',
  'ORBI_ERP2_SUPERVISOR_LOGIN': 'supervisor',
  'ORBI_ERP2_WAREHOUSE_LOGIN': 'miguel.mora',
};
