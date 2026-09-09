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
    required this.orders,
    required this.connectorInstalled,
    required this.panelPoliciesPresent,
  });

  final List<String> errors;
  final Map<Erp2Actor, Map<String, dynamic>> actorRows;
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
    var connectorInstalled = false;
    var panelPoliciesPresent = false;
    if (errors.isNotEmpty && forWrites) {
      // A write guard must fail before even a discovery call that could be
      // confused with a successful write preflight.  Reads remain available
      // to explain the missing variables through the dedicated read mode.
      return Erp2ServerReadiness(
        errors: List.unmodifiable(errors),
        actorRows: actors,
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
      final resolvedGroupIds = <String, int>{};
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
      } else if (plan.kind == Erp2FlowKind.fsc) {
        await _invokeWithCreditApproval(
          actor: Erp2Actor.seller,
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
        await _preparePickingsIfNeeded(fixture.orderId);
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
          await _preparePickingsIfNeeded(fixture.orderId);
          if (!await _dispatchApplied(fixture.orderId)) {
            throw StateError('mixed fixture dispatch was not server-verified');
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

    final approvalId = await _findPendingApproval(
      orderId,
      preferredId: preferredApprovalId,
    );
    if (approvalId == null) {
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
    await _invokeAndVerify(
      actor: Erp2Actor.supervisor,
      model: 'approval.request',
      method: config.rpc.approvalApprove,
      ids: [approvalId],
      verify: () => _approvalApplied(approvalId),
    );
    await _invokeAndVerify(
      actor: actor,
      model: model,
      method: method,
      ids: [orderId],
      kwargs: kwargs,
      verify: verify,
    );
  }

  Future<int?> _findPendingApproval(int orderId, {int? preferredId}) async {
    final requestFields = await auditClient.getModelFields('approval.request');
    final domain = <dynamic>[
      ['sale_order_id', '=', orderId],
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
        'request_status',
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
    return _confirmedRow(row) && _ids(row['picking_ids']).isNotEmpty;
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

  Future<void> _preparePickingsIfNeeded(int orderId) async {
    final row = await _order(orderId);
    final pickingIds = _ids(row['picking_ids']);
    if (pickingIds.isEmpty) {
      throw Erp2PreflightException([
        'fixture has no server-generated stock.picking; '
            'no sale.order dispatch RPC is permitted',
      ]);
    }
    for (final pickingId in pickingIds) {
      final picking = await _picking(pickingId);
      final state = picking['state'];
      if (state == 'done' || state == 'cancel' || state == 'assigned') continue;
      await _invokeAndVerify(
        actor: Erp2Actor.warehouse,
        model: 'stock.picking',
        method: config.rpc.assignPicking,
        ids: [pickingId],
        verify: () async => (await _picking(pickingId))['state'] == 'assigned',
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
    final pickings = await Future.wait(pickingIds.map(_picking));
    return pickings.every(
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
    for (final pickingId in pickingIds) {
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
  }

  Future<void> _validateFscDelivery(int orderId) async {
    final row = await _order(orderId);
    final pickingIds = _ids(row['picking_ids']);
    if (pickingIds.isEmpty || !await _invoicePaidForOrder(orderId)) {
      throw StateError('FSC delivery requires a paid invoice');
    }
    for (final pickingId in pickingIds) {
      await _invokeAndVerify(
        actor: Erp2Actor.warehouse,
        model: 'stock.picking',
        method: config.rpc.validatePicking,
        ids: [pickingId],
        verify: () async => (await _picking(pickingId))['state'] == 'done',
      );
    }
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

List<int> _ids(Object? value) => value is List
    ? value.whereType<num>().map((item) => item.toInt()).toList()
    : const [];

int? _manyId(Object? value) => value is num
    ? value.toInt()
    : value is List && value.isNotEmpty && value.first is num
    ? (value.first as num).toInt()
    : null;
