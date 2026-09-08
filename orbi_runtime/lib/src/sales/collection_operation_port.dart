import 'dart:async';
import 'dart:math' as math;

import 'package:theos_pos_core/theos_pos_core.dart' show CapabilitySnapshot;

import '../contracts.dart';
import '../session/session_runtime.dart';
import 'sale_runtime_adapters.dart';
import 'durable_collection_producers.dart';

enum CollectionOperationKind {
  advance,
  withholding,
  creditNote,
  cashOut,
  deposit,
}

enum CollectionOperationState {
  synced,
  queued,
  rejected,
  unavailable,
  ambiguous,
}

final class CollectionOperationResult {
  const CollectionOperationResult({
    required this.state,
    required this.message,
    this.remoteId,
  });

  final CollectionOperationState state;
  final String message;
  final int? remoteId;

  bool get accepted =>
      state == CollectionOperationState.synced ||
      state == CollectionOperationState.queued;
}

/// Boundary for collection wizards and accounting actions.
///
/// The wizard create+action pairs are deliberately kept here so the panel does
/// not reproduce Odoo model names, contexts, or amount conversions. None of
/// Fiscal wizards stay online-only until their native wizard lines can be
/// persisted atomically. Cash-out/deposit are the exception: their durable
/// producer uses existing POS tables and the generic outbox, and never claims
/// fiscal completion while queued.
final class RuntimeCollectionOperationPort {
  RuntimeCollectionOperationPort({
    required this.runtime,
    required this.capabilities,
    required this.actions,
    this.producer,
  });

  // CapabilityProvisioner materializes effective XML groups (not invented
  // per-button strings). Final authorization remains Odoo ACL/record rules.
  static const advancePermission = 'cashier';
  static const withholdingPermission = 'cashier';
  static const creditNotePermission = 'cashier';
  static const cashOutPermission = 'cashier';
  static const depositPermission = 'cashier';

  final SessionRuntime runtime;
  final CapabilitySnapshot capabilities;
  final SaleOdooActions actions;
  final DurableCollectionProducer? producer;
  final Map<String, Future<CollectionOperationResult>> _inFlight = {};
  // The business composition supplies the durable producer for every active
  // native scope. Keeping this guard explicit lets tests/alternate hosts
  // expose the operation as unavailable instead of silently issuing RPCs from
  // a graph that cannot recover its local intent.
  bool get _financialProducerExtracted => producer != null;

  Future<CollectionOperationResult> advance({
    required String commandId,
    required SessionLease lease,
    required int paymentWizardId,
    required int overpaymentMinor,
    int? partnerId,
    String? reference,
    int? journalId,
    int? collectionSessionId,
    bool offline = false,
  }) => _once(commandId, () async {
    if (offline) {
      final durable = producer;
      if (durable == null ||
          partnerId == null ||
          journalId == null ||
          reference == null ||
          collectionSessionId == null) {
        return _unsafe(
          'El anticipo offline requiere partner, diario, referencia y turno cacheados.',
        );
      }
      final result = await durable.createAndPostAdvance(
        commandId: commandId,
        partnerId: partnerId,
        reference: reference,
        journalId: journalId,
        amountMinor: overpaymentMinor,
        collectionSessionId: collectionSessionId,
      );
      return CollectionOperationResult(
        state: result.state == DurableCollectionState.queued
            ? CollectionOperationState.queued
            : CollectionOperationState.rejected,
        message: result.message,
        remoteId: result.localId,
      );
    }
    if (!_financialProducerExtracted) {
      return _unsafe('El anticipo requiere el productor durable del POS.');
    }
    // Kept below as the reviewed online contract for the future extracted
    // producer; it must not be reached until its atomic outbox exists.
    final guard = _guard(
      lease: lease,
      permission: advancePermission,
      offline: offline,
      id: paymentWizardId,
    );
    if (guard != null) return guard;
    if (overpaymentMinor <= 0) {
      return const CollectionOperationResult(
        state: CollectionOperationState.rejected,
        message: 'El sobrepago debe ser mayor que cero.',
      );
    }
    final result = await actions.call(
      model: 'l10n_ec_collection_box.confirm.advance.wizard',
      method: 'action_create_advance',
      ids: [paymentWizardId],
    );
    return _response(result, 'Anticipo procesado.');
  });

  Future<CollectionOperationResult> withholding({
    required String commandId,
    required SessionLease lease,
    required int wizardId,
    required int collectionSessionId,
    required int invoiceId,
    bool offline = false,
  }) => _once(commandId, () async {
    if (offline) {
      return _unsafe('La retención fiscal no está disponible sin conexión.');
    }
    if (!_financialProducerExtracted) {
      return _unsafe('La retención requiere confirmación del wizard oficial.');
    }
    final guard = _guard(
      lease: lease,
      permission: withholdingPermission,
      offline: offline,
      id: wizardId,
    );
    if (guard != null) return guard;
    final result = await _callWithContext(
      actions,
      model: 'collection.session.withhold.wizard',
      method: 'action_create_withhold',
      ids: [wizardId],
      context: {
        'active_model': 'account.move',
        'active_ids': [invoiceId],
        'default_session_id': collectionSessionId,
        'default_withhold_type': 'out_withhold',
      },
    );
    if (result is Map &&
        result['type'] == 'ir.actions.act_window' &&
        result['res_model'] == 'l10n_ec.wizard.account.withhold') {
      return const CollectionOperationResult(
        state: CollectionOperationState.ambiguous,
        message: 'El wizard oficial de retención requiere confirmación.',
      );
    }
    return _response(result, 'Retención solicitada.');
  });

  Future<CollectionOperationResult> creditNote({
    required String commandId,
    required SessionLease lease,
    required int paymentWizardId,
    required List<int> lineIds,
    bool offline = false,
  }) => _once(commandId, () async {
    if (offline) {
      return _unsafe('La nota de crédito no está disponible sin conexión.');
    }
    if (!_financialProducerExtracted) {
      return _unsafe(
        'La nota de crédito requiere líneas persistidas del wizard.',
      );
    }
    final guard = _guard(
      lease: lease,
      permission: creditNotePermission,
      offline: offline,
      id: paymentWizardId,
    );
    if (guard != null) return guard;
    if (lineIds.isEmpty) {
      return const CollectionOperationResult(
        state: CollectionOperationState.rejected,
        message: 'La nota de crédito requiere líneas.',
      );
    }
    final result = await actions.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'action_apply_and_create_invoice',
      ids: [paymentWizardId],
    );
    return _response(result, 'Nota de crédito procesada.');
  });

  Future<CollectionOperationResult> cashOut({
    required String commandId,
    required SessionLease lease,
    required int collectionSessionId,
    required int journalId,
    required int cashOutTypeId,
    required int amountMinor,
    required String note,
    bool offline = false,
  }) => _createThenAction(
    commandId: commandId,
    lease: lease,
    permission: cashOutPermission,
    model: 'l10n_ec.cash.out',
    action: 'action_accept_from_session',
    values: {
      'collection_session_id': collectionSessionId,
      'journal_id': journalId,
      'cash_out_type_id': cashOutTypeId,
      'amount': amountMinor / math.pow(10, 2),
      'note': note,
    },
    offline: offline,
  );

  Future<CollectionOperationResult> deposit({
    required String commandId,
    required SessionLease lease,
    required int collectionSessionId,
    required int bankJournalId,
    required String depositType,
    required int amountMinor,
    required String accountingDate,
    required int cashAmountMinor,
    required int checkAmountMinor,
    int checkCount = 0,
    bool offline = false,
  }) => _createThenAction(
    commandId: commandId,
    lease: lease,
    permission: depositPermission,
    model: 'collection.session.deposit',
    action: 'action_create_accounting_entry',
    values: {
      'collection_session_id': collectionSessionId,
      'amount': amountMinor / math.pow(10, 2),
      'deposit_type': depositType,
      'cash_amount': cashAmountMinor / 100,
      'check_amount': checkAmountMinor / 100,
      'bank_journal_id': bankJournalId,
      'accounting_date': accountingDate,
      'check_count': checkCount,
    },
    offline: offline,
  );

  Future<CollectionOperationResult> _createThenAction({
    required String commandId,
    required SessionLease lease,
    required String permission,
    required String model,
    required String action,
    required Map<String, dynamic> values,
    required bool offline,
  }) => _once(commandId, () async {
    final guard = _guard(
      lease: lease,
      permission: permission,
      offline: offline,
      id: values['collection_session_id'] as int?,
    );
    if (guard != null) return guard;
    if (model == 'l10n_ec.cash.out' && values['cash_out_type_id'] is! int ||
        model == 'l10n_ec.cash.out' &&
            (values['cash_out_type_id'] as int? ?? 0) <= 0) {
      return const CollectionOperationResult(
        state: CollectionOperationState.rejected,
        message: 'El tipo de salida de caja requiere un ID Odoo válido.',
      );
    }
    if (model == 'collection.session.deposit') {
      const validTypes = {'cash', 'check', 'mixed'};
      final type = values['deposit_type'];
      final count = values['check_count'];
      final checkCount = count is int ? count : -1;
      final amountMinor = _minor(values['amount']);
      final cashAmountMinor = _minor(values['cash_amount']);
      final checkAmountMinor = _minor(values['check_amount']);
      final componentsMatch =
          amountMinor != null &&
          cashAmountMinor != null &&
          checkAmountMinor != null &&
          cashAmountMinor >= 0 &&
          checkAmountMinor >= 0 &&
          cashAmountMinor + checkAmountMinor == amountMinor;
      final typeComponentsMatch = switch (type) {
        'cash' => cashAmountMinor == amountMinor && checkAmountMinor == 0,
        'check' => cashAmountMinor == 0 && checkAmountMinor == amountMinor,
        'mixed' =>
          cashAmountMinor != null &&
              checkAmountMinor != null &&
              cashAmountMinor > 0 &&
              checkAmountMinor > 0,
        _ => false,
      };
      if (type is! String ||
          !validTypes.contains(type) ||
          !componentsMatch ||
          !typeComponentsMatch ||
          checkCount < 0 ||
          (checkAmountMinor > 0 && checkCount <= 0) ||
          (checkAmountMinor == 0 && checkCount != 0)) {
        return const CollectionOperationResult(
          state: CollectionOperationState.rejected,
          message: 'El depósito requiere tipo y cantidad de cheques válidos.',
        );
      }
    }
    if (producer != null && model == 'l10n_ec.cash.out') {
      final result = await producer!.cashOut(
        commandId: commandId,
        sessionId: values['collection_session_id'] as int,
        journalId: values['journal_id'] as int,
        cashOutTypeId: values['cash_out_type_id'] as int,
        amountMinor: ((values['amount'] as num) * 100).round(),
        note: values['note'] as String,
      );
      return _durableResult(result);
    }
    if (producer != null && model == 'collection.session.deposit') {
      final result = await producer!.deposit(
        commandId: commandId,
        sessionId: values['collection_session_id'] as int,
        bankJournalId: values['bank_journal_id'] as int,
        depositType: values['deposit_type'] as String,
        amountMinor: ((values['amount'] as num) * 100).round(),
        cashAmountMinor: ((values['cash_amount'] as num) * 100).round(),
        checkAmountMinor: ((values['check_amount'] as num) * 100).round(),
        accountingDate: values['accounting_date'] as String,
        checkCount: values['check_count'] as int? ?? 0,
      );
      return _durableResult(result);
    }
    if (offline || !_financialProducerExtracted) {
      return _unsafe(
        'La operación compuesta requiere el productor durable del POS.',
      );
    }
    if (values['amount'] is num && (values['amount'] as num) <= 0) {
      return const CollectionOperationResult(
        state: CollectionOperationState.rejected,
        message: 'El monto debe ser mayor que cero.',
      );
    }
    final created = await actions.call(
      model: model,
      method: 'create',
      kwargs: values,
    );
    final id = _createdId(created);
    if (id == null) {
      return const CollectionOperationResult(
        state: CollectionOperationState.ambiguous,
        message: 'El servidor no confirmó la creación.',
      );
    }
    final result = await actions.call(model: model, method: action, ids: [id]);
    return _response(result, 'Operación de caja procesada.', remoteId: id);
  });

  static int? _minor(dynamic value) {
    if (value is! num || !value.isFinite || value < 0) return null;
    return (value * 100).round();
  }

  CollectionOperationResult? _guard({
    required SessionLease lease,
    required String permission,
    required bool offline,
    required int? id,
  }) {
    final active = runtime.active;
    if (id == null || id <= 0) {
      return const CollectionOperationResult(
        state: CollectionOperationState.rejected,
        message: 'Falta el identificador remoto.',
      );
    }
    if (active == null ||
        active.lease != lease ||
        active.scope.scopeKey != capabilities.scopeKey) {
      return const CollectionOperationResult(
        state: CollectionOperationState.rejected,
        message: 'La sesión de caja quedó fuera de ámbito.',
      );
    }
    if (!capabilities.permissions.contains(permission)) {
      return const CollectionOperationResult(
        state: CollectionOperationState.rejected,
        message: 'La capacidad requerida no está vigente.',
      );
    }
    return null;
  }

  static CollectionOperationResult _unsafe(String message) =>
      CollectionOperationResult(
        state: CollectionOperationState.unavailable,
        message: message,
      );

  static CollectionOperationResult _durableResult(
    DurableCollectionResult result,
  ) => CollectionOperationResult(
    state: result.state == DurableCollectionState.queued
        ? CollectionOperationState.queued
        : CollectionOperationState.rejected,
    message: result.message,
    remoteId: result.localId,
  );

  Future<dynamic> _callWithContext(
    SaleOdooActions actions, {
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
    required Map<String, dynamic> context,
  }) {
    final contextual = actions is ContextualSaleOdooActions ? actions : null;
    if (contextual == null) {
      return Future.error(
        StateError('El adaptador Odoo no soporta contexto JSON-2'),
      );
    }
    return contextual.callWithContext(
      model: model,
      method: method,
      ids: ids,
      kwargs: kwargs,
      context: context,
    );
  }

  Future<CollectionOperationResult> _once(
    String commandId,
    Future<CollectionOperationResult> Function() action,
  ) {
    if (commandId.trim().isEmpty) {
      return Future.value(
        const CollectionOperationResult(
          state: CollectionOperationState.rejected,
          message: 'Falta el identificador de intención.',
        ),
      );
    }
    return _inFlight.putIfAbsent(commandId, action);
  }

  static CollectionOperationResult _response(
    dynamic response,
    String successMessage, {
    int? remoteId,
  }) {
    if (response is Map &&
        (response['error'] != null || response['exception_type'] != null)) {
      return CollectionOperationResult(
        state: CollectionOperationState.rejected,
        message: response['error']?.toString() ?? 'La operación fue rechazada.',
        remoteId: remoteId,
      );
    }
    return CollectionOperationResult(
      state: CollectionOperationState.synced,
      message: successMessage,
      remoteId: remoteId,
    );
  }

  static int? _createdId(dynamic response) {
    if (response is int) return response > 0 ? response : null;
    if (response is List && response.length == 1) {
      return _createdId(response.first);
    }
    if (response is Map) {
      return _createdId(response['id'] ?? response['result']);
    }
    return null;
  }
}
