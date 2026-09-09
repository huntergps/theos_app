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

  test('live runner timing and partial payment guard are explicit', () {
    expect(Erp2HarnessTiming.serverCallTimeout, const Duration(minutes: 2));
    expect(Erp2HarnessTiming.suiteTimeout, const Duration(minutes: 10));
    expect(
      Erp2PartialPaymentContract.errorsForRows([
        {'id': 405, 'state': 'draft'},
      ]),
      contains(contains('id=405 state=draft; manual server reconciliation')),
    );
    expect(
      Erp2PartialPaymentContract.errorsForRows([
        {'id': 406, 'state': 'cancel'},
      ]),
      isEmpty,
    );
  });

  test(
    'collection payment domains use stored identity and filter state locally',
    () {
      final domain = Erp2PartialPaymentContract.domainForSale(
        1929,
        operationUuid: 'ORBI-E2E-payment-1',
      );

      expect(
        domain.any((clause) => clause.isNotEmpty && clause.first == 'state'),
        isFalse,
      );
      expect(
        domain,
        contains(
          predicate<List<Object?>>((clause) {
            return clause.length == 3 &&
                clause[0] == 'sale_id' &&
                clause[1] == '=' &&
                clause[2] == 1929;
          }),
        ),
      );
      expect(
        domain,
        contains(
          predicate<List<Object?>>((clause) {
            return clause.length == 3 &&
                clause[0] == 'pos_collection_op_uuid' &&
                clause[1] == '=' &&
                clause[2] == 'ORBI-E2E-payment-1';
          }),
        ),
      );
      expect(
        Erp2PartialPaymentContract.activeRows([
          {'id': 1, 'state': 'draft'},
          {'id': 2, 'state': 'posted'},
          {'id': 3, 'state': 'cancel'},
        ]).map((row) => row['id']),
        containsAll(<int>[1, 2]),
      );
      expect(
        Erp2PartialPaymentContract.activeRows([
          {'id': 1, 'state': 'draft'},
          {'id': 2, 'state': 'posted'},
          {'id': 3, 'state': 'cancel'},
        ]).map((row) => row['id']),
        isNot(contains(3)),
      );
    },
  );

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
      config.rpc.copyRetiringPartner,
      'action_copiar_quien_retira',
    );
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
      expect(
        Erp2FlowPlan.all
            .singleWhere((plan) => plan.kind == Erp2FlowKind.fsc)
            .actor,
        Erp2Actor.seller,
      );
      expect(
        Erp2FlowPlan.all
            .singleWhere((plan) => plan.kind == Erp2FlowKind.fsc)
            .confirmation,
        contains('supervisor approves'),
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

  test('FSC capability requires the explicit no-collection seller group', () {
    const groupIds = {Erp2ActorCapabilityContract.fscRequesterGroup: 60};
    final rows = <Erp2Actor, Map<String, dynamic>>{
      Erp2Actor.seller: {'all_group_ids': <int>[]},
    };
    expect(
      Erp2ActorCapabilityContract.errorsForFscRequester(rows, groupIds),
      contains(
        'seller lacks required group '
        'l10n_ec_collection_box.group_facturar_sin_cobro',
      ),
    );
    rows[Erp2Actor.seller]!['all_group_ids'] = [60];
    expect(
      Erp2ActorCapabilityContract.errorsForFscRequester(rows, groupIds),
      isEmpty,
    );
  });

  test('FSC unpaid delivery gate fails closed on wizard actions', () {
    const backorderAction = {
      'type': 'ir.actions.act_window',
      'res_model': 'stock.backorder.confirmation',
    };
    expect(
      Erp2FscDeliveryGateContract.isBlocked(
        response: backorderAction,
        transportError: false,
        state: 'assigned',
      ),
      isTrue,
    );
    expect(
      Erp2FscDeliveryGateContract.isBlocked(
        response: {'unexpected': true},
        transportError: false,
        state: 'waiting',
      ),
      isTrue,
    );
    expect(
      Erp2FscDeliveryGateContract.isBlocked(
        response: true,
        transportError: false,
        state: 'done',
      ),
      isFalse,
    );
  });

  test(
    'FSC classifies internal and customer segments by destination usage',
    () {
      expect(
        Erp2FscPickingContract.classify({
          'picking_type_code': 'internal',
          'location_dest_usage': 'internal',
        }),
        Erp2FscPickingKind.internal,
      );
      expect(
        Erp2FscPickingContract.classify({
          'picking_type_code': 'outgoing',
          'location_dest_usage': 'customer',
        }),
        Erp2FscPickingKind.customerDelivery,
      );
      expect(
        Erp2FscPickingContract.classify({
          'picking_type_code': 'outgoing',
          'location_dest_usage': 'internal',
        }),
        isNull,
      );
    },
  );

  test('FSC retiring partner contract accepts the copied delivery partner', () {
    expect(
      Erp2FscPickingContract.retiringPartnerMatches({
        'partner_id': [30, 'Customer'],
        'partner_venta_id': [30, 'Customer'],
      }),
      isTrue,
    );
    expect(
      Erp2FscPickingContract.retiringPartnerMatches({
        'partner_id': [30, 'Customer'],
        'partner_venta_id': false,
      }),
      isFalse,
    );
    expect(
      Erp2FscPickingContract.retiringPartnerMatches({
        'partner_id': [30, 'Customer'],
        'partner_venta_id': [33, 'Other'],
      }),
      isFalse,
    );
  });

  test('FSC accepts only the native backorder wizard action', () {
    const rpc = Erp2RpcContract();
    const action = {
      'type': 'ir.actions.act_window',
      'res_model': 'stock.backorder.confirmation',
      'context': {
        'button_validate_picking_ids': [7],
        'default_pick_ids': [
          [4, 7],
        ],
      },
    };
    expect(Erp2FscPickingContract.isKnownBackorderAction(action), isTrue);
    expect(
      Erp2FscPickingContract.backorderContext(action),
      containsPair('button_validate_picking_ids', [7]),
    );
    expect(rpc.createBackorderWizard, 'create');
    expect(rpc.processBackorder, 'process');
    expect(
      Erp2FscPickingContract.isKnownBackorderAction({
        'type': 'ir.actions.act_window',
        'res_model': 'l10n_ec_stock_base.delivery_guide_popup_wizard',
        'res_id': 91,
        'context': {
          'button_validate_picking_ids': [7],
        },
      }),
      isFalse,
    );
    expect(
      Erp2FscPickingContract.isKnownBackorderAction({
        'type': 'ir.actions.act_window',
        'res_model': 'stock.backorder.confirmation',
        'context': const {},
      }),
      isFalse,
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

  test('credit action is materialized through the native wizard contract', () {
    final context = Erp2CreditApprovalContract.creditWizardContext({
      'success': false,
      'approval_required': true,
      'action': {
        'type': 'ir.actions.act_window',
        'res_model': Erp2CreditApprovalContract.wizardModel,
        'context': {
          'default_sale_order_id': 1929,
          'default_partner_id': 42203,
          'default_transaction_amount': 12.5,
          'default_check_type': 'credit_limit_exceeded',
          'default_authorization_type': 'credit_limit_exceeded',
        },
      },
    }, orderId: 1929);

    expect(context, isNotNull);
    expect(context!['default_partner_id'], 42203);
    expect(
      Erp2CreditApprovalContract.pendingDomain(1929),
      contains(
        predicate<List<Object?>>(
          (clause) =>
              clause.length == 3 &&
              clause[0] == 'approval_type' &&
              clause[1] == '=' &&
              clause[2] == 'credit',
        ),
      ),
    );
    expect(
      Erp2CreditApprovalContract.creditWizardContext({
        'success': false,
        'approval_required': true,
        'action': {
          'type': 'ir.actions.act_window',
          'res_model': 'credit.limit.exceeded.wizard',
          'context': {'default_sale_order_id': 1930},
        },
      }, orderId: 1930),
      isNull,
    );
  });

  test('credit wizard creation merges native defaults into create context', () {
    final context = Erp2CreditApprovalContract.wizardCreateContext({
      'default_sale_order_id': 1929,
      'default_partner_id': 42203,
      'default_transaction_amount': 12.5,
      'default_check_type': 'credit_limit_exceeded',
    }, paymentTermId: 33);

    expect(context['default_sale_order_id'], 1929);
    expect(context['default_partner_id'], 42203);
    expect(context['default_payment_term_id'], 33);
    expect(
      () => Erp2CreditApprovalContract.wizardCreateContext(
        const {},
        paymentTermId: 0,
      ),
      throwsArgumentError,
    );
  });

  test('credit wizard ACL rejects a cashier without salesman capability', () {
    const groupIds = {Erp2ActorCapabilityContract.creditWizardCreateGroup: 10};
    final rows = <Erp2Actor, Map<String, dynamic>>{
      Erp2Actor.seller: {
        'all_group_ids': [10],
      },
      Erp2Actor.cashier: {'all_group_ids': <int>[]},
    };

    expect(
      Erp2ActorCapabilityContract.errorsForCreditWizardActor(
        Erp2Actor.seller,
        rows,
        groupIds,
      ),
      isEmpty,
    );
    expect(
      Erp2ActorCapabilityContract.errorsForCreditWizardActor(
        Erp2Actor.cashier,
        rows,
        groupIds,
      ),
      contains(contains('cashier lacks sales_team.group_sale_salesman')),
    );
  });

  test('credit approval requires the supervisor assigned in approver_ids', () {
    final approvers = <Map<String, dynamic>>[
      {
        'id': 1,
        'user_id': [77, 'Erik'],
        'status': 'pending',
      },
    ];
    expect(
      Erp2CreditApprovalContract.supervisorAssignmentErrors(approvers, 77),
      isEmpty,
    );
    expect(
      Erp2CreditApprovalContract.supervisorAssignmentErrors(approvers, 78),
      contains(
        'supervisor is not the unique pending approver for credit request',
      ),
    );
    expect(
      Erp2CreditApprovalContract.supervisorAssignmentErrors([
        ...approvers,
        {
          'id': 2,
          'user_id': [77, 'Erik'],
          'status': 'pending',
        },
      ], 77),
      contains(
        'supervisor is not the unique pending approver for credit request',
      ),
    );
  });

  test('credit approval adoption requires order financial identity', () {
    final matching = <String, dynamic>{
      'sale_order_id': [1929, 'ORBI-E2E-CREDIT'],
      'partner_id': [42203, 'Customer'],
      'amount': 12.5,
      'payment_term_id': [33, '30 days'],
    };
    expect(
      Erp2CreditApprovalContract.approvalMatchesOrder(
        row: matching,
        orderId: 1929,
        partnerId: 42203,
        amount: 12.5,
        paymentTermId: 33,
      ),
      isTrue,
    );
    expect(
      Erp2CreditApprovalContract.approvalMatchesOrder(
        row: matching,
        orderId: 1929,
        partnerId: 42203,
        amount: 13.5,
        paymentTermId: 33,
      ),
      isFalse,
    );
    expect(
      Erp2CreditApprovalContract.approvalMatchesOrder(
        row: matching,
        orderId: 1929,
        partnerId: 42203,
        amount: 12.5,
        paymentTermId: 26,
      ),
      isFalse,
    );
  });

  test('credit approval does not replay a confirmed sale action', () {
    const rpc = Erp2RpcContract();
    expect(
      Erp2CreditApprovalContract.shouldRetryAfterApproval(
        verified: true,
        orderState: 'sale',
        method: rpc.confirm,
        confirmMethod: rpc.confirm,
        cashInvoiceMethod: rpc.cashInvoice,
      ),
      isFalse,
    );
    expect(
      Erp2CreditApprovalContract.shouldRetryAfterApproval(
        verified: false,
        orderState: 'sale',
        method: rpc.confirm,
        confirmMethod: rpc.confirm,
        cashInvoiceMethod: rpc.cashInvoice,
      ),
      isFalse,
    );
    expect(
      Erp2CreditApprovalContract.shouldRetryAfterApproval(
        verified: false,
        orderState: 'sale',
        method: rpc.cashInvoice,
        confirmMethod: rpc.confirm,
        cashInvoiceMethod: rpc.cashInvoice,
      ),
      isTrue,
    );
    expect(
      Erp2CreditApprovalContract.shouldRetryAfterApproval(
        verified: false,
        orderState: 'waiting',
        method: rpc.confirm,
        confirmMethod: rpc.confirm,
        cashInvoiceMethod: rpc.cashInvoice,
      ),
      isTrue,
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
