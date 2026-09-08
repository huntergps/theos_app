import 'dart:async';

import 'package:theos_pos_core/theos_pos_core.dart';

import '../sync/operations_sync_job.dart';
import 'sale_runtime_adapters.dart';

/// Routes a verified portal payment transaction to the existing cashier line.
///
/// The adapter deliberately does not create or update financial records. The
/// only mutating RPC is the public Odoo button
/// `payment.transaction.action_l10n_ec_enviar_a_caja`; the native
/// `l10n_ec_collection_box.sale.order.payment` line is the idempotency and
/// reconciliation record created by that button.
final class PaymentTransactionCollectionPort {
  const PaymentTransactionCollectionPort(this.actions);

  final SaleOdooActions actions;

  static const _transactionFields = <String>[
    'id',
    'state',
    'amount',
    'reference',
    'provider_reference',
    'sale_order_ids',
    'invoice_ids',
    'payment_id',
    'l10n_ec_journal_id',
  ];

  static const _paymentLineFields = <String>[
    'id',
    'sale_id',
    'amount',
    'journal_id',
    'payment_method_line_id',
    'payment_reference',
    'state',
    'move_id',
    'collection_session_id',
    'l10n_ec_payment_transaction_id',
  ];

  /// Sends [transactionId] to the cashier workflow after validating the
  /// transaction's sale, verified journal, and amount.
  ///
  /// A pre-existing matching native payment line is treated as already
  /// applied. If the action response is lost, the native line is read again;
  /// no second action call is attempted by this method.
  Future<OperationOutcome<SaleOrderState>> sendToCash({
    required EntityReference order,
    required String commandId,
    required int transactionId,
    required int expectedSaleOrderId,
    required int expectedAmountMinor,
    int? expectedJournalId,
    int currencyDigits = 2,
  }) async {
    final entity = order;
    if (transactionId <= 0 || expectedSaleOrderId <= 0) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_preflight_invalid_id',
        messageKey: 'sale.payment_transaction_preflight_invalid_id',
      );
    }
    if (expectedAmountMinor <= 0 || currencyDigits < 0 || currencyDigits > 6) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_preflight_invalid_amount',
        messageKey: 'sale.payment_transaction_preflight_invalid_amount',
      );
    }
    if (order.remoteId != null && order.remoteId != expectedSaleOrderId) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_sale_mismatch',
        messageKey: 'sale.payment_transaction_sale_mismatch',
      );
    }

    final transactionRead = await _readTransaction(transactionId);
    if (!transactionRead.ok || transactionRead.rows.length != 1) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_preflight_unavailable',
        messageKey: 'sale.payment_transaction_preflight_unavailable',
        retryable: false,
      );
    }
    final transaction = transactionRead.rows.single;
    final transactionIdFromServer = _id(transaction['id']);
    final saleIds = _manyIds(transaction['sale_order_ids']);
    final journalId = _many2oneId(transaction['l10n_ec_journal_id']);
    final amountMinor = _minorUnits(transaction['amount'], currencyDigits);

    if (transactionIdFromServer != transactionId) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_preflight_invalid_id',
        messageKey: 'sale.payment_transaction_preflight_invalid_id',
      );
    }
    if (saleIds.length != 1 || saleIds.single != expectedSaleOrderId) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_sale_mismatch',
        messageKey: 'sale.payment_transaction_sale_mismatch',
      );
    }
    if (journalId == null ||
        journalId <= 0 ||
        (expectedJournalId != null && journalId != expectedJournalId)) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_journal_mismatch',
        messageKey: 'sale.payment_transaction_journal_mismatch',
      );
    }
    if (amountMinor == null ||
        amountMinor <= 0 ||
        amountMinor != expectedAmountMinor) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_amount_mismatch',
        messageKey: 'sale.payment_transaction_amount_mismatch',
      );
    }

    final before = await _readPaymentLines(transactionId);
    if (!before.ok) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_reconciliation_unavailable',
        messageKey: 'sale.payment_transaction_reconciliation_unavailable',
        retryable: false,
      );
    }
    final beforeAssessment = _assessLines(
      before.rows,
      transactionId: transactionId,
      saleOrderId: expectedSaleOrderId,
      amountMinor: expectedAmountMinor,
      journalId: journalId,
      currencyDigits: currencyDigits,
    );
    if (beforeAssessment.isConflict) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_line_conflict',
        messageKey: 'sale.payment_transaction_line_conflict',
      );
    }
    if (beforeAssessment.isApplied) {
      return _applied(commandId, entity);
    }
    if (transaction['state'] != 'pending') {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_not_pending',
        messageKey: 'sale.payment_transaction_not_pending',
      );
    }

    Object? actionError;
    var actionAmbiguous = false;
    dynamic actionResponse;
    try {
      actionResponse = await actions.call(
        model: 'payment.transaction',
        method: 'action_l10n_ec_enviar_a_caja',
        ids: [transactionId],
      );
    } on AmbiguousOperationException catch (error) {
      actionError = error;
      actionAmbiguous = true;
    } on TimeoutException catch (error) {
      actionError = error;
      actionAmbiguous = true;
    } catch (error) {
      actionError = error;
    }

    final afterLines = await _readPaymentLines(transactionId);
    final afterTransaction = await _readTransaction(transactionId);
    if (!afterLines.ok || !afterTransaction.ok) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_send_ambiguous',
        messageKey: 'sale.payment_transaction_send_ambiguous',
        retryable: false,
      );
    }
    final afterAssessment = _assessLines(
      afterLines.rows,
      transactionId: transactionId,
      saleOrderId: expectedSaleOrderId,
      amountMinor: expectedAmountMinor,
      journalId: journalId,
      currencyDigits: currencyDigits,
    );
    if (afterAssessment.isApplied) {
      return _applied(commandId, entity);
    }
    if (afterAssessment.isConflict) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_line_conflict',
        messageKey: 'sale.payment_transaction_line_conflict',
      );
    }
    if (actionError != null && !actionAmbiguous ||
        _rejectedResponse(actionResponse)) {
      return _outcome(
        commandId: commandId,
        entity: entity,
        code: 'payment_transaction_send_rejected',
        messageKey: 'sale.payment_transaction_send_rejected',
      );
    }

    // A successful-looking response without the native line is not proof of
    // application. Preserve the ambiguity and require reconciliation rather
    // than invoking the financial action a second time.
    return _outcome(
      commandId: commandId,
      entity: entity,
      code: 'payment_transaction_send_ambiguous',
      messageKey: 'sale.payment_transaction_send_ambiguous',
      retryable: false,
    );
  }

  Future<_Rows> _readTransaction(int transactionId) => _readRows(
    model: 'payment.transaction',
    domain: [
      ['id', '=', transactionId],
    ],
    fields: _transactionFields,
  );

  Future<_Rows> _readPaymentLines(int transactionId) => _readRows(
    model: 'l10n_ec_collection_box.sale.order.payment',
    domain: [
      ['l10n_ec_payment_transaction_id', '=', transactionId],
    ],
    fields: _paymentLineFields,
  );

  Future<_Rows> _readRows({
    required String model,
    required List<List<Object>> domain,
    required List<String> fields,
  }) async {
    try {
      final result = await actions.call(
        model: model,
        method: 'search_read',
        kwargs: {'domain': domain, 'fields': fields, 'limit': 100},
      );
      if (result is! List || result.any((row) => row is! Map)) {
        return const _Rows.failed();
      }
      return _Rows.success(
        result
            .map((row) => Map<String, dynamic>.from(row as Map))
            .toList(growable: false),
      );
    } catch (_) {
      return const _Rows.failed();
    }
  }

  _LineAssessment _assessLines(
    List<Map<String, dynamic>> rows, {
    required int transactionId,
    required int saleOrderId,
    required int amountMinor,
    required int journalId,
    required int currencyDigits,
  }) {
    if (rows.length > 1) return const _LineAssessment.conflict();
    if (rows.isEmpty) return const _LineAssessment.none();
    final line = rows.single;
    final lineTransactionId = _many2oneId(
      line['l10n_ec_payment_transaction_id'],
    );
    final lineSaleId = _many2oneId(line['sale_id']);
    final lineJournalId = _many2oneId(line['journal_id']);
    final lineAmountMinor = _minorUnits(line['amount'], currencyDigits);
    final state = line['state'];
    if (lineTransactionId != transactionId ||
        lineSaleId != saleOrderId ||
        lineJournalId != journalId ||
        lineAmountMinor != amountMinor ||
        state == 'cancel') {
      return const _LineAssessment.conflict();
    }
    return const _LineAssessment.applied();
  }

  OperationOutcome<SaleOrderState> _applied(
    String commandId,
    EntityReference entity,
  ) => OperationOutcome(
    commandId: commandId,
    entity: entity,
    businessState: SaleOrderState.sale,
    syncState: OperationSyncState.synced,
  );

  OperationOutcome<SaleOrderState> _outcome({
    required String commandId,
    required EntityReference entity,
    required String code,
    required String messageKey,
    bool retryable = false,
  }) => OperationOutcome(
    commandId: commandId,
    entity: entity,
    businessState: SaleOrderState.sale,
    syncState: OperationSyncState.conflict,
    issues: [
      OperationIssue(code: code, messageKey: messageKey, retryable: retryable),
    ],
  );
}

final class _Rows {
  const _Rows.success(this.rows) : ok = true;
  const _Rows.failed() : ok = false, rows = const [];

  final bool ok;
  final List<Map<String, dynamic>> rows;
}

final class _LineAssessment {
  const _LineAssessment.none() : isApplied = false, isConflict = false;
  const _LineAssessment.applied() : isApplied = true, isConflict = false;
  const _LineAssessment.conflict() : isApplied = false, isConflict = true;

  final bool isApplied;
  final bool isConflict;
}

int? _id(Object? value) {
  if (value is int) return value > 0 ? value : null;
  if (value is num) {
    final integer = value.toInt();
    return value == integer && integer > 0 ? integer : null;
  }
  final parsed = int.tryParse(value?.toString() ?? '');
  return parsed != null && parsed > 0 ? parsed : null;
}

int? _many2oneId(Object? value) {
  if (value is List && value.isNotEmpty) return _id(value.first);
  if (value is Map) return _id(value['id']);
  return _id(value);
}

List<int> _manyIds(Object? value) {
  if (value is! List) return const [];
  return value.map(_many2oneId).whereType<int>().toList(growable: false);
}

int? _minorUnits(Object? value, int currencyDigits) {
  final amount = value is num
      ? value.toDouble()
      : num.tryParse(value?.toString() ?? '')?.toDouble();
  if (amount == null) return null;
  var factor = 1;
  for (var index = 0; index < currencyDigits; index++) {
    factor *= 10;
  }
  return (amount * factor).round();
}

bool _rejectedResponse(Object? response) {
  if (response == false) return true;
  if (response is! Map) return false;
  return response['success'] == false || response.containsKey('error');
}
