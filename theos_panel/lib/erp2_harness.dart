/// Safety and planning contracts for the opt-in ERP2 V01 journey.
///
/// This library contains no default credentials and makes no network request
/// when imported.  The integration test supplies the Odoo client only after
/// [Erp2HarnessConfig.requireWritePreflight] and the server-side read
/// preflight have completed.
library;

import 'package:orbi_runtime/orbi_runtime.dart';

enum Erp2Actor { seller, cashier, supervisor, warehouse }

enum Erp2FlowKind { cash, credit, mixed, fsc }

enum Erp2PanelMode { withPanel, withoutPanel }

enum Erp2ReplayState { applied, rejected, ambiguous }

/// Remote V01 calls can include invoice posting and accounting reconciliation;
/// the Dart test package's default 30-second timeout is not an adequate
/// boundary for that server transaction.
final class Erp2HarnessTiming {
  static const serverCallTimeout = Duration(minutes: 2);
  static const suiteTimeout = Duration(minutes: 10);
}

final class Erp2ActorCredentials {
  const Erp2ActorCredentials({
    required this.actor,
    required this.login,
    required this.userId,
  });

  final Erp2Actor actor;
  final String login;
  final int? userId;

  bool get configured => login.trim().isNotEmpty && userId != null;

  bool get isAdminLike {
    final normalized = login.trim().toLowerCase();
    return normalized == 'admin' || normalized == 'administrator';
  }

  Map<String, Object?> toRedactedJson() => {
    'actor': actor.name,
    'loginConfigured': login.trim().isNotEmpty,
    'userId': userId,
  };
}

/// Required capabilities are checked against Odoo's resolved group IDs, not
/// actor names or assumed roles.
final class Erp2ActorCapabilityContract {
  static const fscRequesterGroup =
      'l10n_ec_collection_box.group_facturar_sin_cobro';
  static const creditWizardCreateGroup = 'sales_team.group_sale_salesman';

  static const requiredGroups = <Erp2Actor, List<String>>{
    Erp2Actor.seller: ['sales_team.group_sale_salesman'],
    Erp2Actor.cashier: ['l10n_ec_collection_box.group_collection_user'],
    Erp2Actor.supervisor: [
      'l10n_ec_collection_box.group_collection_manager',
      'approvals.group_approval_user',
    ],
    Erp2Actor.warehouse: ['stock.group_stock_user'],
  };

  static List<String> errorsForRows(
    Map<Erp2Actor, Map<String, dynamic>> rows,
    Map<String, int> resolvedGroupIds,
  ) {
    final errors = <String>[];
    for (final entry in requiredGroups.entries) {
      final row = rows[entry.key];
      final ids = _ids(row?['all_group_ids']).toSet();
      for (final xmlId in entry.value) {
        final groupId = resolvedGroupIds[xmlId];
        if (groupId == null) {
          errors.add('required group $xmlId could not be resolved');
        } else if (!ids.contains(groupId)) {
          errors.add('${entry.key.name} lacks required group $xmlId');
        }
      }
    }
    return errors;
  }

  /// The FSC requester is a seller, but FSC has an additional permission that
  /// is not implied by the ordinary sales group. Keep it conditional: credit,
  /// cash and mixed flows must not require the exceptional no-collection
  /// permission.
  static List<String> errorsForFscRequester(
    Map<Erp2Actor, Map<String, dynamic>> rows,
    Map<String, int> resolvedGroupIds,
  ) {
    final groupId = resolvedGroupIds[fscRequesterGroup];
    if (groupId == null) {
      return ['required group $fscRequesterGroup could not be resolved'];
    }
    final ids = _ids(rows[Erp2Actor.seller]?['all_group_ids']).toSet();
    if (!ids.contains(groupId)) {
      return ['seller lacks required group $fscRequesterGroup'];
    }
    return const [];
  }

  /// The native credit wizard is protected by the salesman ACL (`cru`).
  /// Keep this check explicit because a collection user is not implicitly a
  /// salesman; a cash flow that unexpectedly hits credit control must fail
  /// closed before attempting to create the transient wizard.
  static List<String> errorsForCreditWizardActor(
    Erp2Actor actor,
    Map<Erp2Actor, Map<String, dynamic>> rows,
    Map<String, int> resolvedGroupIds,
  ) {
    final groupId = resolvedGroupIds[creditWizardCreateGroup];
    if (groupId == null) {
      return [
        'credit wizard ACL group $creditWizardCreateGroup could not be resolved',
      ];
    }
    final ids = _ids(rows[actor]?['all_group_ids']).toSet();
    if (!ids.contains(groupId)) {
      return [
        '${actor.name} lacks $creditWizardCreateGroup required to create '
            'credit.limit.exceeded.wizard',
      ];
    }
    return const [];
  }
}

/// Server state is authoritative for the unpaid FSC delivery gate. A native
/// picking validation can return a backorder/wizard action while leaving the
/// picking assigned or waiting; that is still a blocked delivery, never an
/// accepted shipment. Unknown structured responses fail closed.
final class Erp2FscDeliveryGateContract {
  static bool isBlocked({
    required dynamic response,
    required bool transportError,
    required String state,
  }) {
    if (state == 'done') return false;
    if (transportError || response == null || response == false) return true;
    if (response is Map) {
      if (response['success'] == false ||
          response['error'] != null ||
          response['warning'] != null) {
        return true;
      }
      // Backorder and confirmation dialogs are actions, not delivery success.
      if (response['type'] is String &&
          (response['type'] as String).startsWith('ir.actions.')) {
        return true;
      }
      return true;
    }
    // Even a bare true is not delivery success until the server read says
    // state=done; for an unpaid invoice, any non-done state remains blocked.
    return true;
  }
}

/// Classification used by the FSC runner after the server has generated its
/// native pickings.  The destination usage is authoritative for the payment
/// lock: an internal transfer moves stock between company locations, while a
/// picking whose destination is `customer` is the delivery that must remain
/// blocked until the invoice is paid.
enum Erp2FscPickingKind { internal, customerDelivery }

final class Erp2FscPickingContract {
  static Erp2FscPickingKind? classify(Map<String, dynamic> row) {
    final code = row['picking_type_code'];
    final usage = row['location_dest_usage'];
    if (code == 'internal' && usage != 'customer') {
      return Erp2FscPickingKind.internal;
    }
    if (usage == 'customer') {
      return Erp2FscPickingKind.customerDelivery;
    }
    return null;
  }

  static bool isKnownBackorderAction(dynamic response) {
    return response is Map &&
        response['type'] == 'ir.actions.act_window' &&
        response['res_model'] == 'stock.backorder.confirmation' &&
        response['context'] is Map &&
        ((response['context'] as Map)['button_validate_picking_ids'] is List) &&
        ((response['context'] as Map)['button_validate_picking_ids'] as List)
            .whereType<num>()
            .isNotEmpty;
  }

  static Map<String, dynamic>? backorderContext(dynamic response) {
    if (!isKnownBackorderAction(response)) return null;
    return Map<String, dynamic>.from(response['context'] as Map);
  }

  static bool retiringPartnerMatches(Map<String, dynamic> row) {
    final delivery = _manyId(row['partner_id']);
    final retiring = _manyId(row['partner_venta_id']);
    return delivery != null && retiring == delivery;
  }

  /// A sale is dispatched only when every customer-facing segment is done.
  /// Checking `any` segment would let a split delivery report success while a
  /// sibling customer picking is still waiting or has a different retirer.
  static bool allCustomerDeliveriesDone(Iterable<Map<String, dynamic>> rows) {
    var customerCount = 0;
    for (final row in rows) {
      final kind = classify(row);
      if (kind == Erp2FscPickingKind.internal) continue;
      if (kind != Erp2FscPickingKind.customerDelivery) return false;
      customerCount++;
      if (row['state'] != 'done' || !retiringPartnerMatches(row)) {
        return false;
      }
    }
    return customerCount > 0;
  }
}

final class Erp2FscApprovalInvocation {
  const Erp2FscApprovalInvocation({required this.model, required this.method});

  final String model;
  final String method;
}

/// Contract guard used by the mock test and immediately before the real FSC
/// approval call. FSC must have one native approval and no second generic
/// approval request for the same operation.
final class Erp2FscApprovalContract {
  static List<String> errors(
    List<Erp2FscApprovalInvocation> invocations,
    Erp2RpcContract rpc,
  ) {
    final errors = <String>[];
    final native = invocations
        .where(
          (call) =>
              call.model == 'sale.order' &&
              call.method == rpc.fscInvoiceAndDispatch,
        )
        .length;
    if (native != 1) errors.add('FSC requires exactly one native approval');
    final generic = invocations
        .where(
          (call) =>
              call.model == 'approval.request' &&
              call.method == rpc.approvalApprove,
        )
        .length;
    if (generic != 0) errors.add('FSC must not use generic approval twice');
    return errors;
  }
}

/// Contract for the native credit-control detour returned by
/// `sale.order.action_pos_confirm`.
///
/// The sale action does not create an `approval.request` itself when credit
/// control blocks it.  It returns an action for
/// `credit.limit.exceeded.wizard`; that transient wizard is the native public
/// path that creates the linked request.  Keeping this contract pure makes the
/// write runner testable without constructing an Odoo client or touching ERP2.
final class Erp2CreditApprovalContract {
  static const wizardModel = 'credit.limit.exceeded.wizard';

  static List<dynamic> pendingDomain(int orderId) => [
    ['sale_order_id', '=', orderId],
    ['approval_type', '=', 'credit'],
    [
      'request_status',
      'in',
      ['new', 'pending'],
    ],
  ];

  static Map<String, dynamic> wizardCreateContext(
    Map<String, dynamic> nativeContext, {
    required int paymentTermId,
  }) {
    if (paymentTermId <= 0) {
      throw ArgumentError.value(paymentTermId, 'paymentTermId');
    }
    return {...nativeContext, 'default_payment_term_id': paymentTermId};
  }

  static bool approvalMatchesOrder({
    required Map<String, dynamic> row,
    required int orderId,
    required int partnerId,
    required double amount,
    required int paymentTermId,
  }) {
    final rowAmount = row['amount'];
    return _manyId(row['sale_order_id']) == orderId &&
        _manyId(row['partner_id']) == partnerId &&
        rowAmount is num &&
        (rowAmount.toDouble() - amount).abs() <= 0.01 &&
        _manyId(row['payment_term_id']) == paymentTermId;
  }

  static List<String> supervisorAssignmentErrors(
    List<Map<String, dynamic>> approvers,
    int? supervisorId,
  ) {
    if (supervisorId == null || supervisorId <= 0) {
      return const ['supervisor user ID is required for approval'];
    }
    final assigned = approvers
        .where((row) => _manyId(row['user_id']) == supervisorId)
        .toList();
    final pending = assigned.where((row) => row['status'] == 'pending').length;
    if (assigned.length != 1 || pending != 1) {
      return const [
        'supervisor is not the unique pending approver for credit request',
      ];
    }
    return const [];
  }

  /// Returns the action context only for the exact native credit wizard.
  /// Malformed/other actions fail closed and are not treated as approval
  /// requests.
  static Map<String, dynamic>? creditWizardContext(
    dynamic response, {
    required int orderId,
  }) {
    if (response is! Map || response['approval_required'] != true) return null;
    final action = response['action'];
    if (action is! Map ||
        action['type'] != 'ir.actions.act_window' ||
        action['res_model'] != wizardModel) {
      return null;
    }
    final rawContext = action['context'];
    if (rawContext is! Map) return null;
    final context = <String, dynamic>{
      for (final entry in rawContext.entries)
        if (entry.key is String) entry.key as String: entry.value,
    };
    final contextOrder = _int(context['default_sale_order_id']);
    if (contextOrder != orderId ||
        _int(context['default_partner_id']) == null ||
        context['default_transaction_amount'] is! num ||
        context['default_check_type'] is! String) {
      return null;
    }
    return context;
  }

  /// Whether the original RPC still has work after supervisor approval.
  /// Credit approval's native hook normally confirms the order itself.  A
  /// bare `action_pos_confirm` must therefore not be replayed on `sale`; the
  /// cash-and-invoice endpoint may still need its invoice/payment phase.
  static bool shouldRetryAfterApproval({
    required bool verified,
    required String? orderState,
    required String method,
    required String confirmMethod,
    required String cashInvoiceMethod,
  }) {
    if (verified) return false;
    if (method == confirmMethod) {
      return orderState == 'waiting' || orderState == 'approved';
    }
    if (method == cashInvoiceMethod) return orderState == 'sale';
    return false;
  }

  static int? _int(Object? value) => value is num ? value.toInt() : null;
}

/// Payment evidence is accepted only when it belongs to one native operation
/// and every persisted line has a unique identity. A sale-wide sum is not
/// sufficient evidence because it can combine unrelated/replayed collections.
final class Erp2NativePaymentReconciliationContract {
  static List<String> errors(
    List<Map<String, dynamic>> rows, {
    required String operationUuid,
    required double expectedAmount,
  }) {
    final errors = <String>[];
    if (rows.isEmpty) return ['native payment operation was not found'];
    final lineUuids = <String>{};
    var total = 0.0;
    for (final payment in rows) {
      final amount = payment['amount'];
      final move = payment['move_id'];
      final lineUuid = payment['pos_collection_line_uuid'];
      if (payment['state'] != 'posted' ||
          amount is! num ||
          amount <= 0 ||
          move is! List ||
          move.isEmpty ||
          move.first is! num ||
          payment['pos_collection_op_uuid'] != operationUuid ||
          lineUuid is! String ||
          lineUuid.isEmpty ||
          !lineUuids.add(lineUuid)) {
        errors.add(
          'native payment has invalid or mismatched operation identity',
        );
        continue;
      }
      total += amount.toDouble();
    }
    if ((total - expectedAmount).abs() > 0.01) {
      errors.add('native payment amount does not match the operation');
    }
    return errors;
  }
}

/// A timed-out cash flow may have persisted a draft native payment after the
/// invoice was posted. Such a fixture is ambiguous and must be reconciled by
/// an operator before V01 is allowed to send another mutating call.
final class Erp2PartialPaymentContract {
  /// `state` is a non-stored/computed field on the deployed collection
  /// payment model and cannot be used in a JSON-2 search domain.  Keep the
  /// server query restricted to stored identity keys, then apply the state
  /// predicate to the returned rows locally.
  static List<List<Object?>> domainForSale(
    int saleId, {
    String? operationUuid,
  }) => [
    ['sale_id', '=', saleId],
    if (operationUuid != null) ['pos_collection_op_uuid', '=', operationUuid],
  ];

  static List<Map<String, dynamic>> activeRows(
    List<Map<String, dynamic>> rows,
  ) => rows.where((row) => row['state'] != 'cancel').toList();

  static List<String> errorsForRows(List<Map<String, dynamic>> rows) {
    final active = activeRows(rows);
    return [
      for (final row in active)
        'cash fixture has pre-existing collection payment '
            'id=${row['id'] ?? '?'} state=${row['state'] ?? '?'}; '
            'manual server reconciliation is required before retry',
    ];
  }
}

final class Erp2MixedPaymentContract {
  static List<String> errors({
    required bool invoiceAlreadyExists,
    required String method,
    required Erp2RpcContract rpc,
  }) {
    final expected = invoiceAlreadyExists
        ? rpc.existingInvoicePayment
        : rpc.mixedPaymentAndDispatch;
    return method == expected
        ? const []
        : [
            invoiceAlreadyExists
                ? 'mixed existing invoice requires action_apply_existing_invoice'
                : 'mixed invoice creation requires action_apply_and_create_invoice',
          ];
  }
}

/// Exact method names are an input to V01.  A missing method blocks before any
/// write; the harness never guesses a controller or an addon-specific RPC.
/// Methods proven by the current runtime/addon contract.  They are constants,
/// not environment variables: a missing or guessed RPC cannot reach ERP2.
final class Erp2RpcContract {
  const Erp2RpcContract();

  static Erp2RpcContract fromEnvironment(Map<String, String> _) =>
      const Erp2RpcContract();

  String get confirm => 'action_pos_confirm';
  String get cashInvoice => 'action_pos_confirm_and_invoice';
  String get fscInvoiceAndDispatch => 'action_l10n_ec_aprobar_fsc';
  String get fscRequest => 'action_l10n_ec_solicitar_facturar_sin_cobro';
  String get approvalApprove => 'action_approve';
  String get sessionOpen => 'action_session_open';
  String get sessionClose => 'close_control_session_pos';
  // Existing-invoice collection route implemented by the native payment
  // wizard; this is not a sale.order action and is resolved only after the
  // FSC invoice exists.
  // Existing-invoice collection is the POS extension's native route.  The
  // base wizard's action_apply only persists a pending line and does not
  // reconcile an already-posted invoice.
  String get existingInvoicePayment => 'action_apply_existing_invoice';
  // Official mixed-payment wizard route.  The supplied wizard already owns
  // its persisted lines; the harness never invents line commands or kwargs.
  String get mixedPaymentAndDispatch => 'action_apply_and_create_invoice';
  // Native wizard field: line_type belongs to the wizard, not its line model.
  // Odoo defines this selection with default='payment'; all three collection
  // routes below are ordinary payments (not advances/credits/withholds).
  String get paymentWizardLineType => 'payment';
  String get assignPicking => 'action_assign';
  String get validatePicking => 'button_validate';
  // Public stock.picking form action from l10n_ec_stock_base.  It has no
  // kwargs: the native method copies partner_id to partner_venta_id on the
  // singleton picking.  Keep it in the fixed contract so the harness cannot
  // drift into an invented field write or an alternate RPC name.
  String get copyRetiringPartner => 'action_copiar_quien_retira';
  // Core stock.backorder.confirmation method returned by button_validate when
  // a native backorder decision is required.  It is accepted only for the
  // exact model/action shape checked by Erp2FscPickingContract.
  String get createBackorderWizard => 'create';
  String get processBackorder => 'process';

  Map<String, String> toRedactedJson() => {
    'sale.order.confirm': confirm,
    'sale.order.cashInvoice': cashInvoice,
    'sale.order.fscInvoiceAndDispatch': fscInvoiceAndDispatch,
    'sale.order.fscRequest': fscRequest,
    'approval.request.approve': approvalApprove,
    'collection.session.open': sessionOpen,
    'collection.session.close': sessionClose,
    'payment.wizard.existingInvoice': existingInvoicePayment,
    'payment.wizard.mixedPaymentAndDispatch': mixedPaymentAndDispatch,
    'payment.wizard.lineType': paymentWizardLineType,
    'stock.picking.assign': assignPicking,
    'stock.picking.validate': validatePicking,
    'stock.picking.copyRetiringPartner': copyRetiringPartner,
    'stock.backorder.confirmation.create': createBackorderWizard,
    'stock.backorder.confirmation.process': processBackorder,
  };
}

/// Native schema contract for the collection payment wizard. Odoo's
/// `line_type` is a required field on the transient wizard itself; the
/// one2many line model has no such field. Keeping this distinction explicit
/// prevents sending a plausible-looking but invalid child command.
final class Erp2PaymentWizardContract {
  static List<String> errors({
    required Set<String> wizardFields,
    required Set<String> lineFields,
  }) {
    const wizardRequired = {
      'sale_id',
      'collection_session_id',
      'line_ids',
      'line_type',
    };
    const lineRequired = {
      'amount',
      'journal_id',
      'payment_method_line_id',
      'pos_collection_line_uuid',
    };
    final errors = <String>[];
    for (final field in wizardRequired) {
      if (!wizardFields.contains(field)) {
        errors.add(
          'l10n_ec_collection_box.sale.order.payment.wizard.$field '
          'is required for payment wizard',
        );
      }
    }
    for (final field in lineRequired) {
      if (!lineFields.contains(field)) {
        errors.add(
          'l10n_ec_collection_box.sale.order.payment.wizard.line.$field '
          'is required for payment wizard',
        );
      }
    }
    if (lineFields.contains('line_type')) {
      errors.add(
        'l10n_ec_collection_box.sale.order.payment.wizard.line.line_type '
        'must be sent on the parent wizard',
      );
    }
    return errors;
  }
}

final class Erp2FlowFixture {
  const Erp2FlowFixture({
    required this.kind,
    required this.orderId,
    required this.reference,
    this.approvalId,
  });

  final Erp2FlowKind kind;
  final int orderId;
  final String reference;
  final int? approvalId;

  bool get hasPositiveId => orderId > 0;

  Map<String, Object?> toRedactedJson() => {
    'kind': kind.name,
    'orderId': orderId,
    'reference': reference,
    'approvalId': approvalId,
  };
}

final class Erp2HarnessConfig {
  const Erp2HarnessConfig({
    required this.serverUrl,
    required this.database,
    required this.panelMode,
    required this.writeEnabled,
    required this.runEnabled,
    required this.writePrefix,
    required this.cleanupMode,
    required this.evidenceFile,
    required this.actors,
    required this.fixtures,
    required this.rpc,
    required this.cashSessionId,
    required this.cashJournalId,
    required this.cashPaymentMethodId,
    required this.mixedCashAmount,
  });

  final String serverUrl;
  final String database;
  final Erp2PanelMode? panelMode;
  final bool writeEnabled;
  final bool runEnabled;
  final String writePrefix;
  final String cleanupMode;
  final String evidenceFile;
  final Map<Erp2Actor, Erp2ActorCredentials> actors;
  final Map<Erp2FlowKind, Erp2FlowFixture> fixtures;
  final Erp2RpcContract rpc;
  final int? cashSessionId;
  final int? cashJournalId;
  final int? cashPaymentMethodId;
  final double? mixedCashAmount;

  static Erp2HarnessConfig fromEnvironment(Map<String, String> env) {
    Erp2ActorCredentials actor(Erp2Actor role, String key) =>
        Erp2ActorCredentials(
          actor: role,
          login: env['ORBI_ERP2_${key}_LOGIN']?.trim() ?? '',
          userId: _positiveInt(env['ORBI_ERP2_${key}_USER_ID']),
        );

    Erp2FlowFixture? fixture(Erp2FlowKind kind) {
      final key = kind.name.toUpperCase();
      final id = _positiveInt(env['ORBI_ERP2_${key}_ORDER_ID']);
      final reference = env['ORBI_ERP2_${key}_REFERENCE']?.trim() ?? '';
      if (id == null && reference.isEmpty) return null;
      final approvalKey = kind == Erp2FlowKind.fsc
          ? 'ORBI_ERP2_FSC_COMMERCIAL_APPROVAL_ID'
          : 'ORBI_ERP2_${key}_APPROVAL_ID';
      return Erp2FlowFixture(
        kind: kind,
        orderId: id ?? -1,
        reference: reference,
        approvalId: _positiveInt(env[approvalKey]),
      );
    }

    final mode = env['ORBI_ERP2_PANEL_MODE']?.trim().toLowerCase();
    final fixtures = <Erp2FlowKind, Erp2FlowFixture>{};
    for (final kind in Erp2FlowKind.values) {
      final item = fixture(kind);
      if (item != null) fixtures[kind] = item;
    }
    return Erp2HarnessConfig(
      serverUrl: env['ORBI_ERP2_SERVER_URL']?.trim() ?? '',
      database: env['ORBI_ERP2_DATABASE']?.trim() ?? '',
      panelMode: switch (mode) {
        'with-panel' => Erp2PanelMode.withPanel,
        'without-panel' => Erp2PanelMode.withoutPanel,
        _ => null,
      },
      writeEnabled:
          env['ORBI_ERP2_ENABLE_WRITES'] == 'I_UNDERSTAND_ORBI_E2E_WRITES',
      runEnabled: env['ORBI_ERP2_RUN_WRITES'] == 'I_UNDERSTAND_ORBI_E2E_WRITES',
      writePrefix: env['ORBI_ERP2_WRITE_PREFIX']?.trim() ?? '',
      cleanupMode: env['ORBI_ERP2_CLEANUP_MODE']?.trim() ?? '',
      evidenceFile: env['ORBI_ERP2_EVIDENCE_FILE']?.trim() ?? '',
      actors: {
        for (final pair in <Erp2Actor, String>{
          Erp2Actor.seller: 'SELLER',
          Erp2Actor.cashier: 'CASHIER',
          Erp2Actor.supervisor: 'SUPERVISOR',
          Erp2Actor.warehouse: 'WAREHOUSE',
        }.entries)
          pair.key: actor(pair.key, pair.value),
      },
      fixtures: fixtures,
      rpc: Erp2RpcContract.fromEnvironment(env),
      cashSessionId: _positiveInt(env['ORBI_ERP2_CASH_SESSION_ID']),
      cashJournalId: _positiveInt(env['ORBI_ERP2_CASH_JOURNAL_ID']),
      cashPaymentMethodId: _positiveInt(
        env['ORBI_ERP2_CASH_PAYMENT_METHOD_ID'],
      ),
      mixedCashAmount: _positiveDouble(env['ORBI_ERP2_MIXED_CASH_AMOUNT']),
    );
  }

  /// Read guard.  The empty result means the target may be queried, not that
  /// the ERP2 business contract has been certified.
  List<String> targetErrors() {
    final errors = <String>[];
    final uri = Uri.tryParse(serverUrl);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.toLowerCase() != 'erp2.tecnosmart.com.ec' ||
        uri.hasPort ||
        uri.userInfo.isNotEmpty ||
        uri.query.isNotEmpty ||
        uri.fragment.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      errors.add('ORBI_ERP2_SERVER_URL must be the exact ERP2 HTTPS host');
    }
    if (database.isEmpty) errors.add('ORBI_ERP2_DATABASE is required');
    if (serverUrl.toLowerCase().contains('newerp') ||
        database.toLowerCase().contains('newerp')) {
      errors.add('newerp is prohibited');
    }
    for (final actor in actors.values) {
      if (actor.login.trim().isEmpty) {
        errors.add('${actor.actor.name} login is required');
      }
      if (actor.isAdminLike) {
        errors.add('${actor.actor.name} must not use admin');
      }
    }
    return errors;
  }

  /// Write guard.  It is intentionally stricter than [targetErrors].
  /// Callers must run the server-side read preflight after this check and
  /// before reaching a mutating Odoo call.
  List<String> writeErrors() {
    final errors = [...targetErrors()];
    if (!writeEnabled) errors.add('explicit write sentinel is missing');
    if (!runEnabled) errors.add('explicit run sentinel is missing');
    if (!RegExp(r'^ORBI-E2E-[0-9a-f]{8,}$').hasMatch(writePrefix)) {
      errors.add('ORBI_ERP2_WRITE_PREFIX must match ORBI-E2E-<uuid>');
    }
    if (cleanupMode != 'retain-prefixed-fixtures') {
      errors.add('cleanup must be retain-prefixed-fixtures');
    }
    if (evidenceFile.isEmpty) errors.add('ORBI_ERP2_EVIDENCE_FILE is required');
    if (panelMode == null) errors.add('ORBI_ERP2_PANEL_MODE is required');
    for (final role in Erp2Actor.values) {
      final actor = actors[role]!;
      if (actor.userId == null || actor.userId! <= 0) {
        errors.add('${role.name} user ID is required');
      }
    }
    final configuredLogins = actors.values
        .map((actor) => actor.login.trim().toLowerCase())
        .where((login) => login.isNotEmpty)
        .toSet();
    if (configuredLogins.length != actors.length) {
      errors.add('seller, cashier, supervisor and warehouse must be distinct');
    }
    final configuredIds = actors.values
        .map((actor) => actor.userId)
        .whereType<int>()
        .toSet();
    if (configuredIds.length != actors.length) {
      errors.add(
        'seller, cashier, supervisor and warehouse IDs must be distinct',
      );
    }
    final warehouse = actors[Erp2Actor.warehouse]!;
    if (warehouse.login.trim().toLowerCase() != 'miguel.mora' ||
        warehouse.userId != 34) {
      errors.add('warehouse must be Miguel Mora (miguel.mora, user ID 34)');
    }
    if (fixtures.length != Erp2FlowKind.values.length) {
      errors.add('four prefixed flow fixtures are required');
    }
    for (final kind in Erp2FlowKind.values) {
      final fixture = fixtures[kind];
      if (fixture == null || !fixture.hasPositiveId) {
        errors.add('${kind.name} order ID is required');
      } else if (!fixture.reference.startsWith(writePrefix)) {
        errors.add('${kind.name} fixture is outside ORBI-E2E prefix');
      }
    }
    if (cashSessionId == null ||
        cashJournalId == null ||
        cashPaymentMethodId == null) {
      errors.add('cash session, journal and payment method IDs are required');
    }
    if (mixedCashAmount == null || mixedCashAmount! <= 0) {
      errors.add('mixed cash amount is required');
    }
    return errors;
  }

  void requireTargetPreflight() {
    final errors = targetErrors();
    if (errors.isNotEmpty) throw Erp2PreflightException(errors);
  }

  void requireWritePreflight() {
    final errors = writeErrors();
    if (errors.isNotEmpty) throw Erp2PreflightException(errors);
  }

  Map<String, Object?> toRedactedJson() => {
    'serverUrl': serverUrl,
    'database': database,
    'panelMode': panelMode?.name,
    'writeEnabled': writeEnabled,
    'runEnabled': runEnabled,
    'writePrefix': writePrefix,
    'cleanupMode': cleanupMode,
    'evidenceFileConfigured': evidenceFile.isNotEmpty,
    'actors': {
      for (final entry in actors.entries)
        entry.key.name: entry.value.toRedactedJson(),
    },
    'fixtures': {
      for (final entry in fixtures.entries)
        entry.key.name: entry.value.toRedactedJson(),
    },
    'rpc': rpc.toRedactedJson(),
    'mixedCashAmountConfigured': mixedCashAmount != null,
  };
}

final class Erp2FlowPlan {
  const Erp2FlowPlan({
    required this.kind,
    required this.actor,
    required this.confirmation,
    required this.invoice,
    required this.dispatch,
    required this.requiresApproval,
  });

  final Erp2FlowKind kind;
  final Erp2Actor actor;
  final String confirmation;
  final String invoice;
  final String dispatch;
  final bool requiresApproval;

  static const all = <Erp2FlowPlan>[
    Erp2FlowPlan(
      kind: Erp2FlowKind.cash,
      actor: Erp2Actor.cashier,
      confirmation: 'cashier cash-and-invoice',
      invoice: 'on-cobro',
      dispatch: 'on-cobro',
      requiresApproval: true,
    ),
    Erp2FlowPlan(
      kind: Erp2FlowKind.credit,
      actor: Erp2Actor.seller,
      confirmation: 'seller confirm after approval',
      invoice: 'on-confirm',
      dispatch: 'on-confirm',
      requiresApproval: true,
    ),
    Erp2FlowPlan(
      kind: Erp2FlowKind.mixed,
      actor: Erp2Actor.seller,
      confirmation: 'seller confirm after approval',
      invoice: 'on-confirm',
      dispatch: 'none at confirm; official payment wizard creates picking',
      requiresApproval: true,
    ),
    Erp2FlowPlan(
      kind: Erp2FlowKind.fsc,
      // The plan actor is the actor who requests the flow. The supervisor is
      // the separate approver used explicitly by the FSC execution branch.
      actor: Erp2Actor.seller,
      confirmation: 'seller requests; supervisor approves FSC',
      invoice: 'on-FSC-approval',
      dispatch: 'server-generated-picking; warehouse action_assign if needed',
      requiresApproval: true,
    ),
  ];
}

Erp2FlowKind? classifyPaymentTerm({
  required List<Map<String, dynamic>> lines,
  required bool isFsc,
}) {
  var immediate = false;
  var future = false;
  for (final line in lines) {
    final days = _lineDueDays(line);
    final delayType = (line['delay_type'] ?? '').toString();
    // A zero-day line is cash only when the server says it is a
    // days-after/immediate line. Looking only at the numeric offset would
    // misclassify end-of-month and other term semantics.
    final immediateLine = days == 0 && delayType == 'days_after';
    immediate |= immediateLine;
    future |= days > 0;
  }
  if (immediate && future) return Erp2FlowKind.mixed;
  if (immediate && !future) return isFsc ? Erp2FlowKind.fsc : Erp2FlowKind.cash;
  if (future && !immediate) return Erp2FlowKind.credit;
  return null;
}

int _lineDueDays(Map<String, dynamic> line) =>
    line['nb_days'] is num ? (line['nb_days'] as num).toInt() : -1;

int? _positiveInt(String? value) {
  final parsed = value == null ? null : int.tryParse(value.trim());
  return parsed != null && parsed > 0 ? parsed : null;
}

double? _positiveDouble(String? value) {
  final parsed = value == null ? null : double.tryParse(value.trim());
  return parsed != null && parsed.isFinite && parsed > 0 ? parsed : null;
}

final class Erp2ReplayObservation {
  const Erp2ReplayObservation({
    required this.transportSucceeded,
    required this.transportError,
    required this.serverStateMatches,
  });

  final bool? transportSucceeded;
  final bool transportError;
  final bool serverStateMatches;

  Erp2ReplayState get state {
    if (serverStateMatches) return Erp2ReplayState.applied;
    if (transportError || transportSucceeded == null) {
      return Erp2ReplayState.ambiguous;
    }
    if (transportSucceeded == false) return Erp2ReplayState.rejected;
    // A successful HTTP response is not evidence of a committed business
    // state; keep it replayable until a server read confirms the outcome.
    return Erp2ReplayState.ambiguous;
  }
}

final class Erp2ServerReadiness {
  const Erp2ServerReadiness({
    required this.errors,
    required this.actorRows,
    required this.resolvedGroupIds,
    required this.orders,
    required this.connectorInstalled,
    required this.panelPoliciesPresent,
  });

  final List<String> errors;
  final Map<Erp2Actor, Map<String, dynamic>> actorRows;
  final Map<String, int> resolvedGroupIds;
  final Map<Erp2FlowKind, Map<String, dynamic>> orders;
  final bool connectorInstalled;
  final bool panelPoliciesPresent;

  bool get ok => errors.isEmpty;

  Map<String, Object?> toRedactedJson() => {
    'ok': ok,
    'errors': errors,
    'connectorInstalled': connectorInstalled,
    'panelPoliciesPresent': panelPoliciesPresent,
    'actors': {
      for (final entry in actorRows.entries)
        entry.key.name: {
          'id': entry.value['id'],
          'companyId': _manyId(entry.value['company_id']),
        },
    },
    'orders': {
      for (final entry in orders.entries)
        entry.key.name: {
          'id': entry.value['id'],
          'reference': entry.value['client_order_ref'],
          'state': entry.value['state'],
          'termKind': entry.value['_termKind'],
          'creditSnapshot': entry.value['_creditSnapshot'],
        },
    },
  };
}

/// Read-only contract probe.  It is deliberately independent of the Flutter
/// widget driver so server state is the source of truth for every write.
final class Erp2ServerPreflight {
  const Erp2ServerPreflight({required this.client});

  final OdooClient client;

  Future<Erp2ServerReadiness> check(
    Erp2HarnessConfig config, {
    bool forWrites = false,
    bool requirePendingApprovals = true,
    bool requireDraftFixtures = true,
  }) async {
    final errors = <String>[];
    if (forWrites) {
      errors.addAll(config.writeErrors());
    } else {
      errors.addAll(config.targetErrors());
    }
    final actors = <Erp2Actor, Map<String, dynamic>>{};
    final orders = <Erp2FlowKind, Map<String, dynamic>>{};
    final resolvedGroupIds = <String, int>{};
    var connectorInstalled = false;
    var panelPoliciesPresent = false;
    if (errors.isNotEmpty && forWrites) {
      // A write guard must fail before even a discovery call that could be
      // confused with a successful write preflight.  Reads remain available
      // to explain the missing variables through the dedicated read mode.
      return Erp2ServerReadiness(
        errors: List.unmodifiable(errors),
        actorRows: actors,
        resolvedGroupIds: const {},
        orders: orders,
        connectorInstalled: connectorInstalled,
        panelPoliciesPresent: panelPoliciesPresent,
      );
    }
    try {
      for (final entry in config.actors.entries) {
        final credentials = entry.value;
        final rows = await client.searchRead(
          model: 'res.users',
          fields: const ['id', 'login', 'company_id', 'all_group_ids'],
          domain: [
            ['login', '=', credentials.login],
            ['active', '=', true],
          ],
          limit: 2,
        );
        if (rows.length != 1) {
          errors.add('${entry.key.name} login must resolve to one active user');
          continue;
        }
        final row = rows.single;
        if (credentials.userId != null && row['id'] != credentials.userId) {
          errors.add('${entry.key.name} user ID does not match login');
        }
        actors[entry.key] = row;
      }
      final capabilityXmlIds = <String>{
        ...Erp2ActorCapabilityContract.requiredGroups.values.expand(
          (groups) => groups,
        ),
        if (config.fixtures[Erp2FlowKind.fsc] != null)
          Erp2ActorCapabilityContract.fscRequesterGroup,
      };
      for (final xmlId in capabilityXmlIds) {
        final parts = xmlId.split('.');
        if (parts.length != 2) continue;
        final rows = await client.searchRead(
          model: 'ir.model.data',
          fields: const ['module', 'name', 'res_id'],
          domain: [
            ['module', '=', parts.first],
            ['name', '=', parts.last],
          ],
          limit: 1,
        );
        if (rows.length == 1 && rows.single['res_id'] is num) {
          resolvedGroupIds[xmlId] = (rows.single['res_id'] as num).toInt();
        }
      }
      errors.addAll(
        Erp2ActorCapabilityContract.errorsForRows(actors, resolvedGroupIds),
      );
      errors.addAll(
        Erp2ActorCapabilityContract.errorsForCreditWizardActor(
          Erp2Actor.seller,
          actors,
          resolvedGroupIds,
        ),
      );
      if (config.fixtures[Erp2FlowKind.fsc] != null) {
        errors.addAll(
          Erp2ActorCapabilityContract.errorsForFscRequester(
            actors,
            resolvedGroupIds,
          ),
        );
      }

      final orderFields = await client.getModelFields('sale.order');
      const requiredOrderFields = [
        'id',
        'client_order_ref',
        'state',
        'locked',
        'payment_term_id',
        'partner_id',
        'invoice_ids',
        'picking_ids',
        'amount_total',
      ];
      for (final field in requiredOrderFields) {
        if (!orderFields.containsKey(field)) {
          errors.add('sale.order.$field is required by V01');
        }
      }

      for (final kind in Erp2FlowKind.values) {
        final fixture = config.fixtures[kind];
        if (fixture == null || fixture.orderId <= 0) continue;
        final rows = await client.searchRead(
          model: 'sale.order',
          fields: [
            for (final field in requiredOrderFields)
              if (orderFields.containsKey(field)) field,
            if (orderFields.containsKey('exige_pago_total_entrega'))
              'exige_pago_total_entrega',
          ],
          domain: [
            ['id', '=', fixture.orderId],
          ],
          limit: 1,
        );
        if (rows.length != 1) {
          errors.add('${kind.name} fixture order was not found');
          continue;
        }
        final row = rows.single;
        final reference = row['client_order_ref'];
        if (reference is! String || !reference.startsWith(config.writePrefix)) {
          errors.add('${kind.name} fixture is outside ORBI-E2E prefix');
        }
        if (forWrites &&
            requireDraftFixtures &&
            !const ['draft', 'sent'].contains(row['state'])) {
          errors.add(
            '${kind.name} fixture must be draft/sent before V01 writes',
          );
        }
        if (forWrites && requireDraftFixtures && kind == Erp2FlowKind.cash) {
          const paymentModel = 'l10n_ec_collection_box.sale.order.payment';
          try {
            final paymentFields = await client.getModelFields(paymentModel);
            if (paymentFields.containsKey('sale_id')) {
              final paymentRows = await client.searchRead(
                model: paymentModel,
                fields: ['id', if (paymentFields.containsKey('state')) 'state'],
                domain: Erp2PartialPaymentContract.domainForSale(
                  fixture.orderId,
                ),
                limit: 20,
              );
              errors.addAll(
                Erp2PartialPaymentContract.errorsForRows(paymentRows),
              );
            }
          } catch (_) {
            errors.add(
              'cash fixture payment state could not be checked safely',
            );
          }
        }
        final termId = _manyId(row['payment_term_id']);
        if (termId == null) {
          errors.add('${kind.name} fixture has no payment term');
          continue;
        }
        final term = await _readTerm(termId);
        final lineIds = _ids(term['line_ids']);
        final lineFields = await client.getModelFields(
          'account.payment.term.line',
        );
        for (final field in const ['nb_days', 'delay_type']) {
          if (!lineFields.containsKey(field)) {
            errors.add('account.payment.term.line.$field is required');
          }
        }
        final readableLineFields = <String>[
          'id',
          for (final field in const ['nb_days', 'delay_type'])
            if (lineFields.containsKey(field)) field,
        ];
        final lines = lineIds.isEmpty
            ? const <Map<String, dynamic>>[]
            : await client.read(
                model: 'account.payment.term.line',
                ids: lineIds,
                fields: readableLineFields,
              );
        final termKind = classifyPaymentTerm(
          lines: lines,
          isFsc: kind == Erp2FlowKind.fsc,
        );
        if (termKind != kind) {
          errors.add(
            '${kind.name} fixture term classified as ${termKind?.name ?? 'unknown'}',
          );
        }
        if (kind == Erp2FlowKind.credit || kind == Erp2FlowKind.mixed) {
          final partnerId = _manyId(row['partner_id']);
          if (partnerId == null) {
            errors.add('${kind.name} fixture has no credit partner');
          } else {
            final credit = await _readCreditSnapshot(partnerId);
            if (credit == null) {
              errors.add('${kind.name} partner credit fields are unavailable');
            } else {
              row['_creditSnapshot'] = credit;
              if (credit['credit_check_bypassed'] == true) {
                errors.add('${kind.name} fixture bypasses credit controls');
              }
            }
          }
        }
        row['_termKind'] = termKind?.name;
        orders[kind] = row;
      }

      try {
        connectorInstalled = await client.hasField(
          'collection.config',
          'pos_app_contract_version',
        );
      } catch (_) {
        errors.add('collection.config capability metadata could not be read');
      }
      if (!connectorInstalled) {
        errors.add('collection.config connector contract is absent');
      }
      if (connectorInstalled) {
        final configs = await client.searchRead(
          model: 'collection.config',
          fields: const ['id', 'company_id', 'pos_app_contract_version'],
          domain: const [
            ['active', '=', true],
          ],
          limit: 1,
        );
        if (configs.isEmpty || configs.single['id'] is! num) {
          errors.add('collection.config connector requires an active config');
        } else {
          final payload = await client.call(
            model: 'collection.config',
            method: 'pos_app_capabilities',
            ids: [(configs.single['id'] as num).toInt()],
          );
          if (payload is! List ||
              payload.length != 1 ||
              payload.single is! Map) {
            errors.add('with-panel capability payload is incomplete');
          } else {
            final capability = payload.single as Map;
            if (!capability.containsKey('counter_policies')) {
              errors.add('panel capability counter_policies is missing');
            } else {
              final policies = capability['counter_policies'];
              if (policies is Map) {
                panelPoliciesPresent = true;
              } else if (policies == null) {
                panelPoliciesPresent = false;
              } else {
                errors.add(
                  'panel capability counter_policies has invalid shape',
                );
              }
            }
          }
        }
      }
      if (config.panelMode == Erp2PanelMode.withPanel &&
          !panelPoliciesPresent) {
        errors.add('with-panel requested but panel policies are absent');
      }
      if (config.panelMode == Erp2PanelMode.withoutPanel &&
          panelPoliciesPresent) {
        errors.add('without-panel requested but panel policies are present');
      }

      // The FSC approval and existing-invoice wizard are created only after
      // the order is confirmed/approved. Their IDs are therefore discovered
      // in the write stage, never required as stale preflight fixtures.
      if (forWrites) {
        const wizardModel = 'l10n_ec_collection_box.sale.order.payment.wizard';
        const lineModel =
            'l10n_ec_collection_box.sale.order.payment.wizard.line';
        final wizardFields = await client.getModelFields(wizardModel);
        for (final field in const [
          'pos_existing_invoice_id',
          'pos_collection_op_uuid',
        ]) {
          if (!wizardFields.containsKey(field)) {
            errors.add('$wizardModel.$field is required for FSC payment');
          }
        }
        final lineFields = await client.getModelFields(lineModel);
        errors.addAll(
          Erp2PaymentWizardContract.errors(
            wizardFields: wizardFields.keys.toSet(),
            lineFields: lineFields.keys.toSet(),
          ),
        );
      }
      if (forWrites && requirePendingApprovals) {
        for (final kind in Erp2FlowKind.values) {
          final fixture = config.fixtures[kind];
          final approvalId = fixture?.approvalId;
          if (fixture == null || approvalId == null) continue;
          final approvals = await client.searchRead(
            model: 'approval.request',
            fields: const ['id', 'sale_order_id', 'request_status'],
            domain: [
              ['id', '=', approvalId],
            ],
            limit: 1,
          );
          if (approvals.length != 1 ||
              _manyId(approvals.single['sale_order_id']) != fixture.orderId ||
              !const [
                'new',
                'pending',
              ].contains(approvals.single['request_status'])) {
            errors.add(
              '${kind.name} approval fixture is not pending for its order',
            );
          }
        }
      }
    } catch (_) {
      // Do not expose URL, authorization headers, or server exception payloads
      // in test output/evidence.  The caller can rerun with the same external
      // credentials after fixing the contract.
      errors.add('ERP2 server preflight failed while reading the contract');
    }
    return Erp2ServerReadiness(
      errors: List.unmodifiable(errors),
      actorRows: actors,
      resolvedGroupIds: Map.unmodifiable(resolvedGroupIds),
      orders: orders,
      connectorInstalled: connectorInstalled,
      panelPoliciesPresent: panelPoliciesPresent,
    );
  }

  Future<Map<String, dynamic>> _readTerm(int id) async {
    final rows = await client.searchRead(
      model: 'account.payment.term',
      fields: const ['id', 'line_ids'],
      domain: [
        ['id', '=', id],
      ],
      limit: 1,
    );
    if (rows.length != 1) throw StateError('payment term not found');
    return rows.single;
  }

  Future<Map<String, dynamic>?> _readCreditSnapshot(int partnerId) async {
    final fields = await client.getModelFields('res.partner');
    const candidates = [
      'credit_limit',
      'credit',
      'credit_to_invoice',
      'use_partner_credit_limit',
      'allow_over_credit',
      'total_overdue',
      'overdue_invoice_count',
      'credit_check_bypassed',
    ];
    final readable = [
      'id',
      for (final field in candidates)
        if (fields.containsKey(field)) field,
    ];
    final rows = await client.searchRead(
      model: 'res.partner',
      fields: readable,
      domain: [
        ['id', '=', partnerId],
      ],
      limit: 1,
    );
    if (rows.length != 1 ||
        !fields.containsKey('credit_limit') ||
        !fields.containsKey('total_overdue')) {
      return null;
    }
    return rows.single;
  }
}

/// Executes only configured, server-backed actions.  The class is not called
/// by ordinary unit tests; callers must explicitly opt in and pass one client
/// per actor.  A transport success never clears a replay until a fresh server
/// read satisfies the flow assertion.
final class Erp2WriteHarness {
  const Erp2WriteHarness({
    required this.config,
    required this.auditClient,
    required this.actorClients,
  });

  final Erp2HarnessConfig config;
  final OdooClient auditClient;
  final Map<Erp2Actor, OdooClient> actorClients;

  Future<Map<String, Object?>> run() async {
    final readiness = await Erp2ServerPreflight(client: auditClient)
        .check(config, forWrites: true);
    if (!readiness.ok) throw Erp2PreflightException(readiness.errors);
    final outcomes = <String, Object?>{};
    for (final plan in Erp2FlowPlan.all) {
      final fixture = config.fixtures[plan.kind]!;
      if (plan.kind == Erp2FlowKind.cash) {
        final order = readiness.orders[plan.kind]!;
        final amount = order['amount_total'];
        if (amount is! num || amount <= 0) {
          throw Erp2PreflightException(['cash amount_total is required']);
        }
        await _invokeWithCreditApproval(
          actor: Erp2Actor.cashier,
          actorRows: readiness.actorRows,
          resolvedGroupIds: readiness.resolvedGroupIds,
          orderId: fixture.orderId,
          model: 'sale.order',
          method: config.rpc.cashInvoice,
          kwargs: {
            'payment_lines': [
              {
                'line_type': config.rpc.paymentWizardLineType,
                'journal_id': config.cashJournalId,
                'payment_method_line_id': config.cashPaymentMethodId,
                'amount': amount,
              },
            ],
            'collection_session_id': config.cashSessionId,
            'client_op_uuid': '${config.writePrefix}-${plan.kind.name}',
          },
          verify: () =>
              _cashApplied(fixture.orderId, expectedAmount: amount.toDouble()),
        );
        await _prepareAndValidateSalePickings(fixture.orderId);
        if (!await _dispatchApplied(fixture.orderId)) {
          throw StateError('cash fixture dispatch was not server-verified');
        }
      } else if (plan.kind == Erp2FlowKind.fsc) {
        await _invokeWithCreditApproval(
          actor: Erp2Actor.seller,
          actorRows: readiness.actorRows,
          resolvedGroupIds: readiness.resolvedGroupIds,
          orderId: fixture.orderId,
          model: 'sale.order',
          method: config.rpc.confirm,
          preferredApprovalId: fixture.approvalId,
          verify: () => _orderConfirmed(fixture.orderId),
        );
        await _invokeAndVerify(
          actor: Erp2Actor.seller,
          model: 'sale.order',
          method: config.rpc.fscRequest,
          ids: [fixture.orderId],
          verify: () async =>
              await _findPendingFscApproval(fixture.orderId) != null,
        );
        final fscApprovalId = await _findPendingFscApproval(fixture.orderId);
        if (fscApprovalId == null) {
          throw Erp2PreflightException([
            'FSC approval request was not discoverable after solicitation',
          ]);
        }
        final fscApprovalErrors = Erp2FscApprovalContract.errors([
          Erp2FscApprovalInvocation(
            model: 'sale.order',
            method: config.rpc.fscInvoiceAndDispatch,
          ),
        ], config.rpc);
        if (fscApprovalErrors.isNotEmpty) {
          throw Erp2PreflightException(fscApprovalErrors);
        }
        await _invokeAndVerify(
          actor: Erp2Actor.supervisor,
          model: 'sale.order',
          method: config.rpc.fscInvoiceAndDispatch,
          ids: [fixture.orderId],
          verify: () => _fscApplied(fixture.orderId),
        );
        await _prepareFscInternalPickings(fixture.orderId);
        if (!await _fscApplied(fixture.orderId)) {
          throw StateError('FSC server state did not preserve payment gate');
        }
        await _assertFscDeliveryBlocked(fixture.orderId);
        final fscWizardId = await _createOrDiscoverFscPaymentWizard(
          orderId: fixture.orderId,
        );
        await _invokeAndVerify(
          actor: Erp2Actor.cashier,
          model: 'l10n_ec_collection_box.sale.order.payment.wizard',
          method: config.rpc.existingInvoicePayment,
          ids: [fscWizardId],
          verify: () async =>
              await _invoicePaidForOrder(fixture.orderId) &&
              await _postedNativePayment(
                fixture.orderId,
                expectedAmount: await _invoiceTotalForOrder(fixture.orderId),
                operationUuid: '${config.writePrefix}-fsc-existing',
              ),
        );
        await _validateFscDelivery(fixture.orderId);
      } else {
        await _invokeWithCreditApproval(
          actor: Erp2Actor.seller,
          actorRows: readiness.actorRows,
          resolvedGroupIds: readiness.resolvedGroupIds,
          orderId: fixture.orderId,
          model: 'sale.order',
          method: config.rpc.confirm,
          preferredApprovalId: fixture.approvalId,
          verify: () async {
            final confirmed = await _confirmed(
              fixture.orderId,
              requirePicking: plan.kind != Erp2FlowKind.mixed,
            );
            return confirmed &&
                (plan.kind == Erp2FlowKind.credit ||
                        plan.kind == Erp2FlowKind.mixed
                    ? await _creditControlsPresent(fixture.orderId)
                    : true);
          },
        );
        if (plan.kind == Erp2FlowKind.mixed) {
          final confirmed = await _order(fixture.orderId);
          if (_ids(confirmed['picking_ids']).isNotEmpty) {
            throw StateError(
              'mixed order received a picking before its official payment wizard',
            );
          }
          if (_ids(confirmed['invoice_ids']).isEmpty ||
              !await _invoicePostedForOrder(fixture.orderId)) {
            throw StateError(
              'mixed order must have a posted invoice at confirmation',
            );
          }
          final mixedRouteErrors = Erp2MixedPaymentContract.errors(
            invoiceAlreadyExists: true,
            method: config.rpc.existingInvoicePayment,
            rpc: config.rpc,
          );
          if (mixedRouteErrors.isNotEmpty) {
            throw Erp2PreflightException(mixedRouteErrors);
          }
          final mixedWizardId =
              await _createOrDiscoverExistingInvoicePaymentWizard(
                orderId: fixture.orderId,
                operation: '${config.writePrefix}-mixed-existing',
                expectedAmount: config.mixedCashAmount!,
              );
          await _invokeAndVerify(
            actor: Erp2Actor.cashier,
            model: 'l10n_ec_collection_box.sale.order.payment.wizard',
            method: config.rpc.existingInvoicePayment,
            ids: [mixedWizardId],
            verify: () => _mixedPaymentApplied(fixture.orderId),
          );
          await _prepareAndValidateSalePickings(fixture.orderId);
          if (!await _dispatchApplied(fixture.orderId)) {
            throw StateError('mixed fixture dispatch was not server-verified');
          }
        } else if (plan.kind == Erp2FlowKind.credit) {
          await _prepareAndValidateSalePickings(fixture.orderId);
          if (!await _dispatchApplied(fixture.orderId)) {
            throw StateError('credit fixture dispatch was not server-verified');
          }
        }
      }
      outcomes[plan.kind.name] = {
        'orderId': fixture.orderId,
        'status': 'server-verified',
      };
    }
    return {
      'prefix': config.writePrefix,
      'mode': config.panelMode?.name,
      'flows': outcomes,
    };
  }

  Future<Map<String, Object?>> retainPrefixedFixtures() async {
    final errors = config.writeErrors();
    if (errors.isNotEmpty) throw Erp2PreflightException(errors);
    final readiness = await Erp2ServerPreflight(client: auditClient).check(
      config,
      forWrites: true,
      requirePendingApprovals: false,
      requireDraftFixtures: false,
    );
    if (!readiness.ok) throw Erp2PreflightException(readiness.errors);
    final orderRows = await auditClient.searchRead(
      model: 'sale.order',
      fields: const ['id', 'client_order_ref', 'invoice_ids', 'picking_ids'],
      domain: [
        ['client_order_ref', '=like', '${config.writePrefix}%'],
      ],
      limit: 500,
    );
    return {
      'mode': 'retain-prefixed-fixtures',
      'retainedOrderIds': [
        for (final row in orderRows)
          if (row['id'] is num) (row['id'] as num).toInt(),
      ],
      'note':
          'ERP2 fixtures retained for audit; no archive or unlink was called',
    };
  }

  Future<void> _invokeAndVerify({
    required Erp2Actor actor,
    required String model,
    required String method,
    required List<int> ids,
    Map<String, dynamic>? kwargs,
    Map<String, dynamic>? context,
    required Future<bool> Function() verify,
  }) async {
    final client = actorClients[actor];
    if (client == null) {
      throw Erp2PreflightException(['${actor.name} client is required']);
    }
    dynamic response;
    Object? transportError;
    try {
      response = await client.call(
        model: model,
        method: method,
        ids: ids,
        kwargs: kwargs,
        context: context,
      );
    } catch (_) {
      transportError = Object();
    }
    final applied = await verify();
    final observation = Erp2ReplayObservation(
      transportSucceeded: transportError == null ? _accepted(response) : null,
      transportError: transportError != null,
      serverStateMatches: applied,
    );
    if (observation.state == Erp2ReplayState.applied) return;
    if (observation.state == Erp2ReplayState.rejected) {
      throw StateError('ERP2 action was rejected by the server');
    }
    throw StateError('ERP2 action result is ambiguous; replay remains pending');
  }

  Future<void> _invokeWithCreditApproval({
    required Erp2Actor actor,
    required Map<Erp2Actor, Map<String, dynamic>> actorRows,
    required Map<String, int> resolvedGroupIds,
    required int orderId,
    required String model,
    required String method,
    required Future<bool> Function() verify,
    int? preferredApprovalId,
    Map<String, dynamic>? kwargs,
  }) async {
    final client = actorClients[actor];
    if (client == null) {
      throw Erp2PreflightException(['${actor.name} client is required']);
    }
    dynamic response;
    Object? transportError;
    try {
      response = await client.call(
        model: model,
        method: method,
        ids: [orderId],
        kwargs: kwargs,
      );
    } catch (_) {
      transportError = Object();
    }
    if (await verify()) return;

    final identity = await _readCreditOrderIdentity(orderId);
    var approvalId = await _findPendingApproval(
      orderId,
      preferredId: preferredApprovalId,
      expectedPartnerId: identity.partnerId,
      expectedAmount: identity.amount,
      expectedPaymentTermId: identity.paymentTermId,
    );
    if (approvalId == null) {
      final wizardContext = Erp2CreditApprovalContract.creditWizardContext(
        response,
        orderId: orderId,
      );
      if (wizardContext != null) {
        final capabilityErrors =
            Erp2ActorCapabilityContract.errorsForCreditWizardActor(
              actor,
              actorRows,
              resolvedGroupIds,
            );
        if (capabilityErrors.isNotEmpty) {
          throw Erp2PreflightException(capabilityErrors);
        }
        approvalId = await _createOrDiscoverCreditApprovalRequest(
          actor: actor,
          orderId: orderId,
          wizardContext: wizardContext,
          identity: identity,
        );
      }
    }
    final resolvedApprovalId = approvalId;
    if (resolvedApprovalId == null) {
      final observation = Erp2ReplayObservation(
        transportSucceeded: transportError == null ? _accepted(response) : null,
        transportError: transportError != null,
        serverStateMatches: false,
      );
      throw StateError(
        observation.state == Erp2ReplayState.ambiguous
            ? 'ERP2 action result is ambiguous; approval request not discoverable'
            : 'ERP2 action was rejected and no linked approval is pending',
      );
    }
    await _requireSupervisorApprovalAssignment(resolvedApprovalId);
    await _invokeAndVerify(
      actor: Erp2Actor.supervisor,
      model: 'approval.request',
      method: config.rpc.approvalApprove,
      ids: [resolvedApprovalId],
      verify: () => _approvalApplied(resolvedApprovalId),
    );
    final appliedAfterApproval = await verify();
    if (appliedAfterApproval) return;
    final stateAfterApproval = (await _order(orderId))['state']?.toString();
    if (!Erp2CreditApprovalContract.shouldRetryAfterApproval(
      verified: appliedAfterApproval,
      orderState: stateAfterApproval,
      method: method,
      confirmMethod: config.rpc.confirm,
      cashInvoiceMethod: config.rpc.cashInvoice,
    )) {
      throw StateError(
        'credit approval was applied but the server did not complete the '
        'requested operation',
      );
    }
    await _invokeAndVerify(
      actor: actor,
      model: model,
      method: method,
      ids: [orderId],
      kwargs: kwargs,
      verify: verify,
    );
  }

  /// Materialize the exact transient wizard returned by native credit control,
  /// then let its public action create the linked approval request.  The
  /// request itself is the durable identity; a transient wizard ID is never
  /// persisted in fixtures and is reconciled after every uncertain RPC.
  Future<int?> _createOrDiscoverCreditApprovalRequest({
    required Erp2Actor actor,
    required int orderId,
    required Map<String, dynamic> wizardContext,
    required _CreditOrderIdentity identity,
  }) async {
    final alreadyPending = await _findPendingApproval(
      orderId,
      expectedPartnerId: identity.partnerId,
      expectedAmount: identity.amount,
      expectedPaymentTermId: identity.paymentTermId,
    );
    if (alreadyPending != null) return alreadyPending;

    final client = actorClients[actor];
    if (client == null) {
      throw Erp2PreflightException(['${actor.name} client is required']);
    }
    final partnerId =
        _manyId(wizardContext['default_partner_id']) ?? identity.partnerId;
    final amount = wizardContext['default_transaction_amount'] is num
        ? (wizardContext['default_transaction_amount'] as num).toDouble()
        : identity.amount;
    final checkType = wizardContext['default_check_type'];
    if (checkType is! String ||
        partnerId != identity.partnerId ||
        (amount.toDouble() - identity.amount).abs() > 0.01) {
      throw StateError('native credit wizard context is incomplete');
    }
    final paymentTermId = identity.paymentTermId;
    final values = <String, dynamic>{
      'partner_id': partnerId,
      'sale_order_id': orderId,
      'transaction_amount': amount,
      'current_credit_limit':
          wizardContext['default_current_credit_limit'] ?? 0.0,
      'authorization_type':
          wizardContext['default_authorization_type'] ?? checkType,
      'check_type': checkType,
      'payment_term_id': paymentTermId,
    };
    final createContext = Erp2CreditApprovalContract.wizardCreateContext(
      wizardContext,
      paymentTermId: paymentTermId,
    );

    int? wizardId;
    try {
      final created = await client.call(
        model: Erp2CreditApprovalContract.wizardModel,
        method: 'create',
        kwargs: {
          'vals_list': [values],
        },
        context: createContext,
      );
      if (created is List && created.length == 1 && created.single is num) {
        wizardId = (created.single as num).toInt();
      }
    } catch (_) {
      // Reconcile below; never blindly create a second transient wizard.
    }
    if (wizardId == null || wizardId <= 0) {
      final existing = await auditClient.searchRead(
        model: Erp2CreditApprovalContract.wizardModel,
        fields: const [
          'id',
          'sale_order_id',
          'partner_id',
          'transaction_amount',
          'payment_term_id',
        ],
        domain: [
          ['sale_order_id', '=', orderId],
        ],
        limit: 2,
      );
      if (existing.length > 1) {
        throw StateError('credit approval wizard identity is ambiguous');
      }
      if (existing.length == 1 && existing.single['id'] is num) {
        final wizard = existing.single;
        if (_manyId(wizard['partner_id']) != identity.partnerId ||
            wizard['transaction_amount'] is! num ||
            ((wizard['transaction_amount'] as num).toDouble() - identity.amount)
                    .abs() >
                0.01 ||
            _manyId(wizard['payment_term_id']) != identity.paymentTermId) {
          throw StateError('credit approval wizard identity is ambiguous');
        }
        wizardId = (existing.single['id'] as num).toInt();
      }
    }
    if (wizardId == null || wizardId <= 0) {
      throw StateError(
        'credit approval wizard creation is ambiguous; server reconciliation required',
      );
    }

    try {
      await client.call(
        model: Erp2CreditApprovalContract.wizardModel,
        method: 'action_create_approval_request',
        ids: [wizardId],
      );
    } catch (_) {
      // A lost response is resolved by the durable linked request below.
    }
    final requestId = await _findPendingApproval(
      orderId,
      expectedPartnerId: identity.partnerId,
      expectedAmount: identity.amount,
      expectedPaymentTermId: identity.paymentTermId,
    );
    if (requestId == null) {
      throw StateError(
        'credit approval request was not discoverable after wizard action',
      );
    }
    return requestId;
  }

  Future<_CreditOrderIdentity> _readCreditOrderIdentity(int orderId) async {
    final rows = await auditClient.searchRead(
      model: 'sale.order',
      fields: const ['id', 'partner_id', 'amount_total', 'payment_term_id'],
      domain: [
        ['id', '=', orderId],
      ],
      limit: 1,
    );
    if (rows.length != 1) {
      throw StateError(
        'credit approval order disappeared before wizard creation',
      );
    }
    final row = rows.single;
    final partnerId = _manyId(row['partner_id']);
    final amount = row['amount_total'];
    final paymentTermId = _manyId(row['payment_term_id']);
    if (partnerId == null ||
        amount is! num ||
        amount <= 0 ||
        paymentTermId == null) {
      throw StateError('credit approval order identity is incomplete');
    }
    return _CreditOrderIdentity(
      partnerId: partnerId,
      amount: amount.toDouble(),
      paymentTermId: paymentTermId,
    );
  }

  Future<void> _requireSupervisorApprovalAssignment(int requestId) async {
    final supervisorId = config.actors[Erp2Actor.supervisor]?.userId;
    final rows = await auditClient.searchRead(
      model: 'approval.approver',
      fields: const ['id', 'request_id', 'user_id', 'status'],
      domain: [
        ['request_id', '=', requestId],
      ],
      limit: 50,
    );
    final errors = Erp2CreditApprovalContract.supervisorAssignmentErrors(
      rows,
      supervisorId,
    );
    if (errors.isNotEmpty) throw Erp2PreflightException(errors);
  }

  Future<int?> _findPendingApproval(
    int orderId, {
    int? preferredId,
    required int expectedPartnerId,
    required double expectedAmount,
    required int expectedPaymentTermId,
  }) async {
    final requestFields = await auditClient.getModelFields('approval.request');
    if (!requestFields.containsKey('approval_type')) {
      throw StateError(
        'approval.request.approval_type is required for credit flow',
      );
    }
    for (final field in const ['partner_id', 'amount', 'payment_term_id']) {
      if (!requestFields.containsKey(field)) {
        throw StateError('approval.request.$field is required for credit flow');
      }
    }
    final domain = <dynamic>[
      ['sale_order_id', '=', orderId],
      ['approval_type', '=', 'credit'],
      [
        'request_status',
        'in',
        ['new', 'pending'],
      ],
    ];
    if (preferredId != null) domain.add(['id', '=', preferredId]);
    final rows = await auditClient.searchRead(
      model: 'approval.request',
      fields: [
        'id',
        'sale_order_id',
        'approval_type',
        'request_status',
        'partner_id',
        'amount',
        'payment_term_id',
        if (requestFields.containsKey('category_id')) 'category_id',
      ],
      domain: domain,
      limit: 20,
    );
    if (preferredId != null && rows.length != 1) return null;
    final ids = <int>[];
    for (final row in rows) {
      if (row['id'] is! num) continue;
      final categoryId = _manyId(row['category_id']);
      if (categoryId != null) {
        final categories = await auditClient.searchRead(
          model: 'approval.category',
          fields: const ['name'],
          domain: [
            ['id', '=', categoryId],
          ],
          limit: 1,
        );
        final name = categories.length == 1
            ? (categories.single['name'] ?? '').toString().toLowerCase()
            : '';
        if (name.contains('fsc') || name.contains('sin cobro')) continue;
      }
      if (!Erp2CreditApprovalContract.approvalMatchesOrder(
        row: row,
        orderId: orderId,
        partnerId: expectedPartnerId,
        amount: expectedAmount,
        paymentTermId: expectedPaymentTermId,
      )) {
        throw StateError('credit approval identity is ambiguous');
      }
      ids.add((row['id'] as num).toInt());
    }
    return ids.length == 1 ? ids.single : null;
  }

  Future<int?> _findPendingFscApproval(int orderId) async {
    final fields = await auditClient.getModelFields('approval.request');
    if (!fields.containsKey('category_id')) return null;
    final domain = <dynamic>[
      ['sale_order_id', '=', orderId],
      [
        'request_status',
        'in',
        ['new', 'pending'],
      ],
    ];
    final rows = await auditClient.searchRead(
      model: 'approval.request',
      fields: const ['id', 'category_id'],
      domain: domain,
      limit: 20,
    );
    final matches = <int>[];
    for (final row in rows) {
      final categoryId = _manyId(row['category_id']);
      if (categoryId == null) continue;
      final categories = await auditClient.searchRead(
        model: 'approval.category',
        fields: const ['name'],
        domain: [
          ['id', '=', categoryId],
        ],
        limit: 1,
      );
      final name = categories.length == 1
          ? (categories.single['name'] ?? '').toString().toLowerCase()
          : '';
      if ((name.contains('fsc') || name.contains('sin cobro')) &&
          row['id'] is num) {
        matches.add((row['id'] as num).toInt());
      }
    }
    return matches.length == 1 ? matches.single : null;
  }

  Future<bool> _approvalApplied(int id) async {
    final rows = await auditClient.searchRead(
      model: 'approval.request',
      fields: const ['request_status'],
      domain: [
        ['id', '=', id],
      ],
      limit: 1,
    );
    return rows.length == 1 && rows.single['request_status'] == 'approved';
  }

  Future<bool> _confirmed(int id, {bool requirePicking = true}) async {
    final row = await _order(id);
    return _orderConfirmedRow(row) &&
        _ids(row['invoice_ids']).isNotEmpty &&
        (!requirePicking || _ids(row['picking_ids']).isNotEmpty);
  }

  Future<bool> _orderConfirmed(int id) async {
    return _orderConfirmedRow(await _order(id));
  }

  Future<bool> _cashApplied(int id, {required double expectedAmount}) async {
    final row = await _order(id);
    if (!_confirmedRow(row) || _ids(row['picking_ids']).isEmpty) return false;
    return await _invoicePaidForOrder(id) &&
        await _invoiceHasClientOperation(id, '${config.writePrefix}-cash') &&
        await _hasSinglePostedPayment(id, expectedAmount: expectedAmount);
  }

  Future<bool> _mixedPaymentApplied(int id) async {
    final row = await _order(id);
    if (!_confirmedRow(row) || _ids(row['picking_ids']).isEmpty) return false;
    return await _invoiceHasResidualAfterNativePayment(
          id,
          expectedAmount: config.mixedCashAmount!,
        ) &&
        await _postedNativePayment(
          id,
          expectedAmount: config.mixedCashAmount!,
          operationUuid: '${config.writePrefix}-mixed-existing',
        );
  }

  Future<bool> _dispatchApplied(int id) async {
    final row = await _order(id);
    if (!_confirmedRow(row)) return false;
    final pickingIds = _ids(row['picking_ids']);
    final pickings = <Map<String, dynamic>>[];
    for (final pickingId in pickingIds) {
      pickings.add(await _readFscPickingAsWarehouse(pickingId));
    }
    return Erp2FscPickingContract.allCustomerDeliveriesDone(pickings);
  }

  Future<bool> _creditControlsPresent(int orderId) async {
    final row = await _order(orderId);
    final partnerId = _manyId(row['partner_id']);
    if (partnerId == null) return false;
    final snapshot = await Erp2ServerPreflight(client: auditClient)
        ._readCreditSnapshot(partnerId);
    if (snapshot == null || snapshot['credit_check_bypassed'] == true) {
      return false;
    }
    return snapshot['credit_limit'] is num && snapshot['total_overdue'] is num;
  }

  /// Follows the public warehouse route for FSC without manufacturing stock
  /// state in the client.  `stock.picking.read` is intentional: the custom
  /// stock module uses opening a picking as the native hook that auto-assigns
  /// an empty responsible user.  The read is performed with Miguel's client,
  /// never with the audit client or an administrator.
  Future<void> _prepareFscInternalPickings(int orderId) async {
    var row = await _order(orderId);
    var pickingIds = _ids(row['picking_ids']);
    if (pickingIds.isEmpty) {
      throw Erp2PreflightException([
        'FSC approval produced no server-generated stock.picking',
      ]);
    }

    var sawInternal = false;
    for (final pickingId in pickingIds) {
      final picking = await _readFscPickingAsWarehouse(pickingId);
      final kind = Erp2FscPickingContract.classify(picking);
      if (kind == null) {
        throw StateError(
          'FSC picking has an unsupported operation/destination shape',
        );
      }
      if (kind != Erp2FscPickingKind.internal) continue;
      sawInternal = true;
      if (picking['state'] == 'done') continue;
      if (picking['state'] == 'cancel') {
        throw StateError('FSC internal picking is cancelled');
      }
      await _assignFscPickingIfNeeded(pickingId, picking);
      await _invokeAndVerify(
        actor: Erp2Actor.warehouse,
        model: 'stock.picking',
        method: config.rpc.validatePicking,
        ids: [pickingId],
        verify: () async => (await _picking(pickingId))['state'] == 'done',
      );
    }

    // In a multi-step warehouse the customer picking is chained and is only
    // created/updated after the internal transfer is done.  Refresh the sale
    // order relation before applying the unpaid-delivery gate.
    if (sawInternal) {
      row = await _order(orderId);
      pickingIds = _ids(row['picking_ids']);
    }
    final customerPickings = <int>[];
    for (final pickingId in pickingIds) {
      final picking = await _readFscPickingAsWarehouse(pickingId);
      final kind = Erp2FscPickingContract.classify(picking);
      if (kind == Erp2FscPickingKind.customerDelivery) {
        customerPickings.add(pickingId);
      } else if (kind != Erp2FscPickingKind.internal) {
        throw StateError(
          'FSC refresh exposed an unsupported operation/destination shape',
        );
      }
    }
    if (customerPickings.isEmpty) {
      throw StateError(
        'FSC server did not expose a customer delivery after internal preparation',
      );
    }
    // Populate the native warehouse gate before the negative unpaid probe.  If
    // this were deferred until after payment, a missing partner_venta_id would
    // mask the invoice-payment lock with an unrelated validation error.
    for (final pickingId in customerPickings) {
      await _ensureFscRetiringPartner(pickingId);
    }
  }

  Future<void> _assignFscPickingIfNeeded(
    int pickingId,
    Map<String, dynamic> picking,
  ) async {
    final state = picking['state'];
    if (state == 'done' || state == 'cancel' || state == 'assigned') return;
    if (state != 'confirmed' &&
        state != 'waiting' &&
        state != 'partially_available') {
      throw StateError('FSC internal picking is not preparable');
    }
    await _invokeAndVerify(
      actor: Erp2Actor.warehouse,
      model: 'stock.picking',
      method: config.rpc.assignPicking,
      ids: [pickingId],
      verify: () async => (await _picking(pickingId))['state'] == 'assigned',
    );
  }

  Future<Map<String, dynamic>> _readFscPickingAsWarehouse(int id) async {
    final warehouse = actorClients[Erp2Actor.warehouse];
    if (warehouse == null) {
      throw Erp2PreflightException(['warehouse client is required for FSC']);
    }
    final rows = await warehouse.read(
      model: 'stock.picking',
      ids: [id],
      fields: const [
        'id',
        'state',
        'picking_type_code',
        'location_id',
        'location_dest_id',
        'user_id',
        'partner_id',
        'partner_venta_id',
      ],
    );
    if (rows.length != 1) throw StateError('FSC picking disappeared');
    final row = Map<String, dynamic>.from(rows.single);
    final destinationId = _manyId(row['location_dest_id']);
    if (destinationId == null) {
      throw StateError('FSC picking has no destination location');
    }
    final locations = await auditClient.searchRead(
      model: 'stock.location',
      fields: const ['id', 'usage'],
      domain: [
        ['id', '=', destinationId],
      ],
      limit: 1,
    );
    if (locations.length != 1 || locations.single['usage'] is! String) {
      throw StateError('FSC picking destination usage is unavailable');
    }
    row['location_dest_usage'] = locations.single['usage'];
    final expectedWarehouseId = config.actors[Erp2Actor.warehouse]?.userId;
    if (row['state'] != 'done' &&
        row['state'] != 'cancel' &&
        expectedWarehouseId != null &&
        _manyId(row['user_id']) != expectedWarehouseId) {
      throw StateError(
        'Miguel did not become the responsible user when opening FSC picking',
      );
    }
    return row;
  }

  /// Runs the native warehouse sequence for the ordinary flows:
  /// prepare each server-generated internal transfer, refresh the sale
  /// relation so chained customer pickings become visible, copy the delivery
  /// partner through the public stock action, and validate the customer
  /// delivery.  No picking is created, quantities are written, or sale-order
  /// dispatch method is guessed here.
  Future<void> _prepareAndValidateSalePickings(int orderId) async {
    var row = await _order(orderId);
    var pickingIds = _ids(row['picking_ids']);
    if (pickingIds.isEmpty) {
      throw Erp2PreflightException([
        'fixture has no server-generated stock.picking; '
            'no sale.order dispatch RPC is permitted',
      ]);
    }

    var sawInternal = false;
    for (final pickingId in pickingIds) {
      final picking = await _readFscPickingAsWarehouse(pickingId);
      final kind = Erp2FscPickingContract.classify(picking);
      if (kind == null) {
        throw StateError(
          'sale fixture has an unsupported operation/destination shape',
        );
      }
      if (kind != Erp2FscPickingKind.internal) continue;
      sawInternal = true;
      if (picking['state'] == 'cancel') {
        throw StateError('sale fixture internal picking is cancelled');
      }
      await _assignFscPickingIfNeeded(pickingId, picking);
      if ((await _picking(pickingId))['state'] != 'done') {
        await _validatePickingWithNativeBackorder(pickingId);
      }
    }

    // The outgoing picking in a two-step warehouse is chained and is not
    // necessarily in sale.order.picking_ids until the internal transfer is
    // done.  Always refresh after touching an internal segment.
    if (sawInternal) {
      row = await _order(orderId);
      pickingIds = _ids(row['picking_ids']);
    }

    var customerCount = 0;
    for (final pickingId in pickingIds) {
      final picking = await _readFscPickingAsWarehouse(pickingId);
      final kind = Erp2FscPickingContract.classify(picking);
      if (kind == Erp2FscPickingKind.internal) continue;
      if (kind != Erp2FscPickingKind.customerDelivery) {
        throw StateError(
          'sale fixture refresh exposed an unsupported picking shape',
        );
      }
      customerCount++;
      await _ensureFscRetiringPartner(pickingId);
      if (picking['state'] == 'cancel') {
        throw StateError('sale fixture customer picking is cancelled');
      }
      if (picking['state'] != 'done') {
        await _assignFscPickingIfNeeded(pickingId, picking);
        await _validatePickingWithNativeBackorder(pickingId);
      }
    }
    if (customerCount == 0) {
      throw StateError(
        'sale fixture has no server-generated customer delivery',
      );
    }
  }

  Future<Map<String, dynamic>> _picking(int id) async {
    final rows = await auditClient.searchRead(
      model: 'stock.picking',
      fields: const ['id', 'state'],
      domain: [
        ['id', '=', id],
      ],
      limit: 1,
    );
    if (rows.length != 1) throw StateError('ERP2 picking disappeared');
    return rows.single;
  }

  Future<bool> _fscApplied(int id) async {
    final row = await _order(id);
    final pickingIds = _ids(row['picking_ids']);
    if (!_confirmedRow(row) ||
        pickingIds.isEmpty ||
        row['exige_pago_total_entrega'] != true ||
        !await _invoicePostedForOrder(id) ||
        await _invoicePaidForOrder(id)) {
      return false;
    }
    // In a multi-step warehouse the first (internal) picking may already be
    // done when the chained customer picking is refreshed.  The FSC approval
    // assertion is therefore about the invoice/payment lock and the existence
    // of an active server picking, not about every segment having the same
    // state.
    final pickings = await Future.wait(pickingIds.map(_picking));
    return pickings.any(
      (picking) => picking['state'] != 'done' && picking['state'] != 'cancel',
    );
  }

  Future<bool> _invoicePaidForOrder(int orderId) async {
    final row = await _order(orderId);
    final invoiceIds = _ids(row['invoice_ids']);
    if (invoiceIds.isEmpty) return false;
    final invoices = await auditClient.searchRead(
      model: 'account.move',
      fields: const [
        'id',
        'state',
        'amount_total',
        'amount_residual',
        'payment_state',
      ],
      domain: [
        ['id', 'in', invoiceIds],
      ],
      limit: invoiceIds.length,
    );
    return invoices.length == invoiceIds.length &&
        invoices.every((invoice) {
          final total = invoice['amount_total'];
          final residual = invoice['amount_residual'];
          return invoice['state'] == 'posted' &&
              invoice['payment_state'] == 'paid' &&
              total is num &&
              residual is num &&
              residual.abs() <= 0.01 &&
              total > 0;
        });
  }

  Future<bool> _invoiceHasResidualAfterNativePayment(
    int orderId, {
    required double expectedAmount,
  }) async {
    final row = await _order(orderId);
    final invoiceIds = _ids(row['invoice_ids']);
    if (invoiceIds.length != 1 || expectedAmount <= 0) return false;
    final invoices = await auditClient.searchRead(
      model: 'account.move',
      fields: const [
        'id',
        'state',
        'amount_total',
        'amount_residual',
        'payment_state',
      ],
      domain: [
        ['id', '=', invoiceIds.single],
      ],
      limit: 1,
    );
    if (invoices.length != 1) return false;
    final invoice = invoices.single;
    final total = invoice['amount_total'];
    final residual = invoice['amount_residual'];
    if (invoice['state'] != 'posted' ||
        invoice['payment_state'] != 'partial' ||
        total is! num ||
        residual is! num ||
        total <= expectedAmount ||
        residual <= 0 ||
        (residual.toDouble() - (total.toDouble() - expectedAmount)).abs() >
            0.01) {
      return false;
    }
    return true;
  }

  Future<double> _invoiceTotalForOrder(int orderId) async {
    final row = await _order(orderId);
    final invoiceIds = _ids(row['invoice_ids']);
    if (invoiceIds.isEmpty) return 0;
    final invoices = await auditClient.searchRead(
      model: 'account.move',
      fields: const ['amount_total'],
      domain: [
        ['id', 'in', invoiceIds],
      ],
      limit: invoiceIds.length,
    );
    final totals = invoices
        .map((invoice) => invoice['amount_total'])
        .whereType<num>()
        .map((value) => value.toDouble())
        .where((value) => value > 0)
        .toList();
    return totals.length == 1 ? totals.single : 0;
  }

  Future<bool> _invoiceHasClientOperation(int orderId, String operation) async {
    final row = await _order(orderId);
    final invoiceIds = _ids(row['invoice_ids']);
    if (invoiceIds.isEmpty) return false;
    final invoices = await auditClient.searchRead(
      model: 'account.move',
      fields: const ['id', 'l10n_ec_pos_client_op_uuid'],
      domain: [
        ['id', 'in', invoiceIds],
      ],
      limit: invoiceIds.length,
    );
    final matches = invoices
        .where((invoice) => invoice['l10n_ec_pos_client_op_uuid'] == operation)
        .length;
    return invoices.length == invoiceIds.length && matches == 1;
  }

  Future<bool> _hasSinglePostedPayment(
    int orderId, {
    required double expectedAmount,
  }) async {
    final rows = await auditClient.searchRead(
      model: 'l10n_ec_collection_box.sale.order.payment',
      fields: const ['id', 'state', 'amount', 'move_id'],
      domain: Erp2PartialPaymentContract.domainForSale(orderId),
      limit: 100,
    );
    final posted = rows.where((payment) {
      final amount = payment['amount'];
      final move = payment['move_id'];
      return payment['state'] == 'posted' &&
          amount is num &&
          amount > 0 &&
          move is List &&
          move.isNotEmpty &&
          move.first is num;
    }).toList();
    if (posted.length != 1) return false;
    final amount = posted.single['amount'];
    return amount is num && (amount.toDouble() - expectedAmount).abs() <= 0.01;
  }

  Future<bool> _invoicePostedForOrder(int orderId) async {
    final row = await _order(orderId);
    final invoiceIds = _ids(row['invoice_ids']);
    if (invoiceIds.isEmpty) return false;
    final invoices = await auditClient.searchRead(
      model: 'account.move',
      fields: const ['id', 'state', 'amount_total', 'amount_residual'],
      domain: [
        ['id', 'in', invoiceIds],
      ],
      limit: invoiceIds.length,
    );
    return invoices.length == invoiceIds.length &&
        invoices.every((invoice) {
          final total = invoice['amount_total'];
          final residual = invoice['amount_residual'];
          return invoice['state'] == 'posted' &&
              total is num &&
              residual is num &&
              total > 0 &&
              residual >= -0.01 &&
              residual <= total + 0.01;
        });
  }

  Future<bool> _postedNativePayment(
    int orderId, {
    required double expectedAmount,
    required String operationUuid,
  }) async {
    final rows = await auditClient.searchRead(
      model: 'l10n_ec_collection_box.sale.order.payment',
      fields: const [
        'id',
        'state',
        'amount',
        'move_id',
        'pos_collection_op_uuid',
        'pos_collection_line_uuid',
      ],
      domain: Erp2PartialPaymentContract.domainForSale(
        orderId,
        operationUuid: operationUuid,
      ),
      limit: 100,
    );
    return Erp2NativePaymentReconciliationContract.errors(
      rows,
      operationUuid: operationUuid,
      expectedAmount: expectedAmount,
    ).isEmpty;
  }

  Future<void> _assertFscDeliveryBlocked(int orderId) async {
    final row = await _order(orderId);
    final pickingIds = _ids(row['picking_ids']);
    if (pickingIds.isEmpty || await _invoicePaidForOrder(orderId)) {
      throw StateError('FSC fixture must be unpaid before delivery gate test');
    }
    var customerCount = 0;
    for (final pickingId in pickingIds) {
      final picking = await _readFscPickingAsWarehouse(pickingId);
      final kind = Erp2FscPickingContract.classify(picking);
      if (kind == Erp2FscPickingKind.internal) continue;
      if (kind != Erp2FscPickingKind.customerDelivery) {
        throw StateError(
          'FSC delivery gate encountered an unsupported picking shape',
        );
      }
      customerCount++;
      dynamic response;
      Object? error;
      try {
        response = await actorClients[Erp2Actor.warehouse]!.call(
          model: 'stock.picking',
          method: config.rpc.validatePicking,
          ids: [pickingId],
        );
      } catch (_) {
        error = Object();
      }
      final state = (await _picking(pickingId))['state'];
      final rejected = Erp2FscDeliveryGateContract.isBlocked(
        response: response,
        transportError: error != null,
        state: state?.toString() ?? '',
      );
      if (!rejected) {
        throw StateError('FSC delivery was not rejected while unpaid');
      }
    }
    if (customerCount == 0) {
      throw StateError('FSC delivery gate found no customer picking');
    }
  }

  Future<void> _validateFscDelivery(int orderId) async {
    final row = await _order(orderId);
    final pickingIds = _ids(row['picking_ids']);
    if (pickingIds.isEmpty || !await _invoicePaidForOrder(orderId)) {
      throw StateError('FSC delivery requires a paid invoice');
    }
    var customerCount = 0;
    for (final pickingId in pickingIds) {
      final picking = await _readFscPickingAsWarehouse(pickingId);
      final kind = Erp2FscPickingContract.classify(picking);
      if (kind == Erp2FscPickingKind.internal) continue;
      if (kind != Erp2FscPickingKind.customerDelivery) {
        throw StateError(
          'FSC delivery validation encountered an unsupported picking shape',
        );
      }
      customerCount++;
      await _assignFscPickingIfNeeded(pickingId, picking);
      await _validatePaidCustomerPicking(pickingId);
    }
    if (customerCount == 0) {
      throw StateError('FSC delivery validation found no customer picking');
    }
  }

  Future<void> _validatePaidCustomerPicking(int pickingId) async {
    await _ensureFscRetiringPartner(pickingId);
    await _validatePickingWithNativeBackorder(pickingId);
  }

  /// Calls the native warehouse validation and, only for the exact backorder
  /// action returned by it, materializes/processes Odoo's own confirmation
  /// wizard.  This helper is shared by cash, credit, mixed, and FSC so every
  /// flow observes the same no-qty-write/no-skip-backorder policy.
  Future<void> _validatePickingWithNativeBackorder(int pickingId) async {
    final warehouse = actorClients[Erp2Actor.warehouse];
    if (warehouse == null) {
      throw Erp2PreflightException(['warehouse client is required']);
    }
    dynamic response;
    Object? transportError;
    try {
      response = await warehouse.call(
        model: 'stock.picking',
        method: config.rpc.validatePicking,
        ids: [pickingId],
      );
    } catch (_) {
      transportError = Object();
    }
    if ((await _picking(pickingId))['state'] == 'done') return;
    if (transportError != null) {
      throw StateError('warehouse picking validation failed on the server');
    }
    final context = Erp2FscPickingContract.backorderContext(response);
    if (context == null) {
      throw StateError(
        'warehouse validation returned an unknown action; refusing to guess a wizard',
      );
    }
    // JSON-2 returns the same action the web client opens, not a transient
    // `res_id`.  Materialize exactly that native wizard with the action context
    // so its `default_get` receives `button_validate_picking_ids`; do not use a
    // custom wizard or bypass the backorder decision with `skip_backorder`.
    final pickingIds = (context['button_validate_picking_ids'] as List)
        .whereType<num>()
        .map((id) => id.toInt())
        .toList(growable: false);
    if (pickingIds.isEmpty) {
      throw StateError('native backorder wizard has no picking ids');
    }
    // JSON-2 create does not run the action's default_get values.  Supply the
    // same pickings and the native default decision explicitly, otherwise
    // `process()` sees no lines and silently validates with an empty wizard.
    final wizardValues = <String, dynamic>{
      'pick_ids': [
        [6, 0, pickingIds],
      ],
      'backorder_confirmation_line_ids': [
        for (final pickingId in pickingIds)
          [
            0,
            0,
            {'to_backorder': true, 'picking_id': pickingId},
          ],
      ],
    };
    final created = await warehouse.call(
      model: 'stock.backorder.confirmation',
      method: config.rpc.createBackorderWizard,
      kwargs: {
        'vals_list': [wizardValues],
      },
      context: context,
    );
    final wizardId =
        created is List && created.length == 1 && created.single is num
        ? (created.single as num).toInt()
        : created is num
        ? created.toInt()
        : null;
    if (wizardId == null || wizardId <= 0) {
      throw StateError('native backorder wizard could not be materialized');
    }
    await _invokeAndVerify(
      actor: Erp2Actor.warehouse,
      model: 'stock.backorder.confirmation',
      method: config.rpc.processBackorder,
      ids: [wizardId],
      context: context,
      verify: () async => (await _picking(pickingId))['state'] == 'done',
    );
  }

  /// The Ecuador stock addon requires `partner_venta_id` on outgoing
  /// pickings.  The public UI action copies the delivery partner and is the
  /// supported path; writing this field from the harness would bypass the
  /// same contract used by the warehouse screen.
  Future<void> _ensureFscRetiringPartner(int pickingId) async {
    final warehouse = actorClients[Erp2Actor.warehouse];
    if (warehouse == null) {
      throw Erp2PreflightException(['warehouse client is required for FSC']);
    }
    var picking = await _readFscPickingAsWarehouse(pickingId);
    final deliveryPartnerId = _manyId(picking['partner_id']);
    if (deliveryPartnerId == null) {
      throw StateError('FSC customer picking has no delivery partner');
    }
    if (_manyId(picking['partner_venta_id']) == deliveryPartnerId) return;
    if (_manyId(picking['partner_venta_id']) != null) {
      throw StateError(
        'FSC customer picking has a mismatched retiring partner',
      );
    }
    await _invokeAndVerify(
      actor: Erp2Actor.warehouse,
      model: 'stock.picking',
      method: config.rpc.copyRetiringPartner,
      ids: [pickingId],
      verify: () async {
        picking = await _readFscPickingAsWarehouse(pickingId);
        return Erp2FscPickingContract.retiringPartnerMatches(picking);
      },
    );
  }

  /// Resolve the native existing-invoice wizard only after FSC has emitted its
  /// invoice. The wizard is transient, so its ID is not a stable fixture and
  /// must not be required by server preflight. A retry first reconciles by the
  /// operation UUID; otherwise it uses Odoo's standard transient-model create
  /// contract and the native existing-invoice action.
  Future<int> _createOrDiscoverFscPaymentWizard({required int orderId}) async {
    final order = await _order(orderId);
    final invoiceIds = _ids(order['invoice_ids']);
    if (invoiceIds.isEmpty) {
      throw StateError(
        'FSC invoice is required before creating its payment wizard',
      );
    }
    final invoices = await auditClient.searchRead(
      model: 'account.move',
      fields: const ['id', 'state', 'amount_residual'],
      domain: [
        ['id', 'in', invoiceIds],
      ],
      limit: invoiceIds.length,
    );
    final posted = invoices
        .where((invoice) {
          final residual = invoice['amount_residual'];
          return invoice['state'] == 'posted' &&
              residual is num &&
              residual > 0.01;
        })
        .toList(growable: false);
    if (posted.length != 1) {
      throw StateError(
        'FSC existing-invoice wizard requires exactly one posted invoice with residual',
      );
    }
    final invoiceId = (posted.single['id'] as num).toInt();
    final residual = (posted.single['amount_residual'] as num).toDouble();
    final operation = '${config.writePrefix}-fsc-existing';
    const wizardModel = 'l10n_ec_collection_box.sale.order.payment.wizard';
    final existing = await auditClient.searchRead(
      model: wizardModel,
      fields: const ['id', 'sale_id', 'pos_existing_invoice_id'],
      domain: [
        ['sale_id', '=', orderId],
        ['pos_existing_invoice_id', '=', invoiceId],
        ['pos_collection_op_uuid', '=', operation],
      ],
      limit: 2,
    );
    if (existing.length > 1) {
      throw StateError('FSC existing-invoice wizard identity is ambiguous');
    }
    if (existing.length == 1 && existing.single['id'] is num) {
      return (existing.single['id'] as num).toInt();
    }

    final cashier = actorClients[Erp2Actor.cashier];
    if (cashier == null) {
      throw Erp2PreflightException(['cashier client is required']);
    }
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final lineUuid = '$operation-line-0';
    int? created;
    try {
      created = await cashier.create(
        model: wizardModel,
        values: {
          'sale_id': orderId,
          'collection_session_id': config.cashSessionId,
          'line_type': config.rpc.paymentWizardLineType,
          'pos_existing_invoice_id': invoiceId,
          'pos_collection_op_uuid': operation,
          'line_ids': [
            [
              0,
              0,
              {
                'date': date,
                'amount': residual,
                'pos_collection_line_uuid': lineUuid,
                'journal_id': config.cashJournalId,
                'payment_method_line_id': config.cashPaymentMethodId,
              },
            ],
          ],
        },
      );
    } catch (_) {
      // Reconcile a lost response by the native operation identity before any
      // retry; never create a second wizard blindly.
    }
    if (created != null && created > 0) return created;
    final afterCreate = await auditClient.searchRead(
      model: wizardModel,
      fields: const ['id', 'sale_id', 'pos_existing_invoice_id'],
      domain: [
        ['sale_id', '=', orderId],
        ['pos_existing_invoice_id', '=', invoiceId],
        ['pos_collection_op_uuid', '=', operation],
      ],
      limit: 2,
    );
    if (afterCreate.length == 1 && afterCreate.single['id'] is num) {
      return (afterCreate.single['id'] as num).toInt();
    }
    throw StateError(
      'FSC payment wizard creation is ambiguous; server reconciliation required',
    );
  }

  /// Resolve the native existing-invoice wizard after confirmation has emitted
  /// the mixed invoice. A mixed payment is not an offline fiscal emission:
  /// setting `pos_client_op_uuid` would activate the POS fiscal-identity
  /// branch and incorrectly require sequential/access-key fields. The native
  /// existing-invoice route uses its own collection operation UUID instead.
  Future<int> _createOrDiscoverExistingInvoicePaymentWizard({
    required int orderId,
    required String operation,
    required double expectedAmount,
  }) async {
    if (expectedAmount <= 0) {
      throw Erp2PreflightException([
        'existing-invoice payment amount is required',
      ]);
    }
    final order = await _order(orderId);
    final invoiceIds = _ids(order['invoice_ids']);
    if (invoiceIds.length != 1) {
      throw StateError(
        'existing-invoice payment requires exactly one invoice after confirmation',
      );
    }
    final invoices = await auditClient.searchRead(
      model: 'account.move',
      fields: const ['id', 'state', 'amount_total', 'amount_residual'],
      domain: [
        ['id', '=', invoiceIds.single],
      ],
      limit: 1,
    );
    if (invoices.length != 1 ||
        invoices.single['state'] != 'posted' ||
        invoices.single['amount_residual'] is! num ||
        (invoices.single['amount_residual'] as num).toDouble() + 0.01 <
            expectedAmount) {
      throw StateError(
        'existing-invoice payment requires one posted invoice with sufficient residual',
      );
    }
    final invoiceId = invoiceIds.single;
    const wizardModel = 'l10n_ec_collection_box.sale.order.payment.wizard';
    final existing = await auditClient.searchRead(
      model: wizardModel,
      fields: const ['id', 'sale_id', 'pos_existing_invoice_id'],
      domain: [
        ['sale_id', '=', orderId],
        ['pos_existing_invoice_id', '=', invoiceId],
        ['pos_collection_op_uuid', '=', operation],
      ],
      limit: 2,
    );
    if (existing.length > 1) {
      throw StateError('existing-invoice payment wizard identity is ambiguous');
    }
    if (existing.length == 1 && existing.single['id'] is num) {
      return (existing.single['id'] as num).toInt();
    }

    final cashier = actorClients[Erp2Actor.cashier];
    if (cashier == null) {
      throw Erp2PreflightException(['cashier client is required']);
    }
    final date = DateTime.now().toIso8601String().substring(0, 10);
    int? created;
    try {
      created = await cashier.create(
        model: wizardModel,
        values: {
          'sale_id': orderId,
          'collection_session_id': config.cashSessionId,
          'line_type': config.rpc.paymentWizardLineType,
          'pos_existing_invoice_id': invoiceId,
          'pos_collection_op_uuid': operation,
          'line_ids': [
            [
              0,
              0,
              {
                'date': date,
                'amount': expectedAmount,
                'pos_collection_line_uuid': '$operation-line-0',
                'journal_id': config.cashJournalId,
                'payment_method_line_id': config.cashPaymentMethodId,
              },
            ],
          ],
        },
      );
    } catch (_) {
      // Reconcile a lost create response by the same native operation UUID.
    }
    if (created != null && created > 0) return created;
    final afterCreate = await auditClient.searchRead(
      model: wizardModel,
      fields: const ['id', 'sale_id', 'pos_existing_invoice_id'],
      domain: [
        ['sale_id', '=', orderId],
        ['pos_existing_invoice_id', '=', invoiceId],
        ['pos_collection_op_uuid', '=', operation],
      ],
      limit: 2,
    );
    if (afterCreate.length == 1 && afterCreate.single['id'] is num) {
      return (afterCreate.single['id'] as num).toInt();
    }
    throw StateError(
      'existing-invoice payment wizard creation is ambiguous; server reconciliation required',
    );
  }

  Future<Map<String, dynamic>> _order(int id) async {
    final rows = await auditClient.searchRead(
      model: 'sale.order',
      fields: const [
        'id',
        'state',
        'locked',
        'partner_id',
        'invoice_ids',
        'picking_ids',
        'exige_pago_total_entrega',
      ],
      domain: [
        ['id', '=', id],
      ],
      limit: 1,
    );
    if (rows.length != 1) throw StateError('ERP2 order disappeared');
    return rows.single;
  }

  static bool _confirmedRow(Map<String, dynamic> row) =>
      _orderConfirmedRow(row) && _ids(row['invoice_ids']).isNotEmpty;

  static bool _orderConfirmedRow(Map<String, dynamic> row) =>
      (row['state'] == 'sale' || row['state'] == 'done') &&
      row['locked'] == true;

  static bool _accepted(dynamic response) =>
      response != false &&
      !(response is Map &&
          (response['success'] == false ||
              response['error'] != null ||
              response['warning'] != null));
}

final class Erp2PreflightException implements Exception {
  const Erp2PreflightException(this.errors);
  final List<String> errors;

  @override
  String toString() => 'ERP2 preflight blocked: ${errors.join('; ')}';
}

final class _CreditOrderIdentity {
  const _CreditOrderIdentity({
    required this.partnerId,
    required this.amount,
    required this.paymentTermId,
  });

  final int partnerId;
  final double amount;
  final int paymentTermId;
}

List<int> _ids(Object? value) => value is List
    ? value.whereType<num>().map((item) => item.toInt()).toList()
    : const [];

int? _manyId(Object? value) => value is num
    ? value.toInt()
    : value is List && value.isNotEmpty && value.first is num
    ? (value.first as num).toInt()
    : null;
