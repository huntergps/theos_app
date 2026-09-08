import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

final class _Call {
  const _Call({
    required this.model,
    required this.method,
    this.ids,
    this.kwargs,
  });

  final String model;
  final String method;
  final List<int>? ids;
  final Map<String, dynamic>? kwargs;
}

final class _FakeActions implements SaleOdooActions {
  final List<_Call> calls = [];
  Map<String, dynamic> transaction = _transaction();
  List<Map<String, dynamic>> linesBefore = [];
  List<Map<String, dynamic>> linesAfter = [];
  dynamic actionResponse = true;
  Object? actionError;
  bool actionCalled = false;

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) async {
    calls.add(_Call(model: model, method: method, ids: ids, kwargs: kwargs));
    if (model == 'payment.transaction' && method == 'search_read') {
      return [transaction];
    }
    if (model == 'l10n_ec_collection_box.sale.order.payment' &&
        method == 'search_read') {
      return actionCalled ? linesAfter : linesBefore;
    }
    if (model == 'payment.transaction' &&
        method == 'action_l10n_ec_enviar_a_caja') {
      actionCalled = true;
      final error = actionError;
      if (error != null) throw error;
      return actionResponse;
    }
    throw StateError('unexpected RPC: $model.$method');
  }
}

Map<String, dynamic> _transaction({
  int saleId = 42,
  int journalId = 9,
  num amount = 125.50,
  String state = 'pending',
}) => {
  'id': 77,
  'state': state,
  'amount': amount,
  'reference': 'TX-77',
  'provider_reference': 'BANK-77',
  'sale_order_ids': [saleId],
  'invoice_ids': const [],
  'payment_id': false,
  'l10n_ec_journal_id': [journalId, 'Banco ERP2'],
};

Map<String, dynamic> _line({
  int transactionId = 77,
  int saleId = 42,
  int journalId = 9,
  num amount = 125.50,
  String state = 'draft',
}) => {
  'id': 501,
  'sale_id': [saleId, 'SO-42'],
  'amount': amount,
  'journal_id': [journalId, 'Banco ERP2'],
  'payment_method_line_id': [13, 'Transferencia'],
  'payment_reference': 'BANK-77',
  'state': state,
  'move_id': false,
  'collection_session_id': false,
  'l10n_ec_payment_transaction_id': [transactionId, 'TX-77'],
};

PaymentTransactionCollectionPort _port(_FakeActions actions) =>
    PaymentTransactionCollectionPort(actions);

EntityReference _order() =>
    EntityReference(localId: 'sale-local-42', remoteId: 42);

Future<OperationOutcome<SaleOrderState>> _send(
  PaymentTransactionCollectionPort port,
) => port.sendToCash(
  order: _order(),
  commandId: 'route-tx-77',
  transactionId: 77,
  expectedSaleOrderId: 42,
  expectedAmountMinor: 12550,
  expectedJournalId: 9,
);

void main() {
  test(
    'calls only the public payment transaction action and reconciles its line',
    () async {
      final actions = _FakeActions()..linesAfter = [_line()];

      final result = await _send(_port(actions));

      expect(result.syncState, OperationSyncState.synced);
      expect(result.issues, isEmpty);
      expect(actions.calls.map((call) => '${call.model}.${call.method}'), [
        'payment.transaction.search_read',
        'l10n_ec_collection_box.sale.order.payment.search_read',
        'payment.transaction.action_l10n_ec_enviar_a_caja',
        'l10n_ec_collection_box.sale.order.payment.search_read',
        'payment.transaction.search_read',
      ]);
      final action = actions.calls[2];
      expect(action.ids, [77]);
      expect(action.kwargs, isNull);
    },
  );

  test(
    'existing matching native line is idempotent and skips the action',
    () async {
      final actions = _FakeActions()..linesBefore = [_line()];

      final result = await _send(_port(actions));

      expect(result.syncState, OperationSyncState.synced);
      expect(actions.calls.map((call) => call.method), [
        'search_read',
        'search_read',
      ]);
      expect(actions.actionCalled, isFalse);
    },
  );

  test(
    'cancelled transaction with matching native line is already applied',
    () async {
      final actions = _FakeActions()
        ..transaction = _transaction(state: 'cancel')
        ..linesBefore = [_line()];

      final result = await _send(_port(actions));

      expect(result.syncState, OperationSyncState.synced);
      expect(result.issues, isEmpty);
      expect(actions.actionCalled, isFalse);
    },
  );

  test(
    'preflight rejects sale, journal, and amount mismatches before mutation',
    () async {
      final cases = <Map<String, dynamic>>[
        {'transaction': _transaction(saleId: 43)},
        {'transaction': _transaction(journalId: 10)},
        {'transaction': _transaction(amount: 126.50)},
      ];

      for (final values in cases) {
        final actions = _FakeActions()
          ..transaction = values['transaction'] as Map<String, dynamic>;
        final result = await _send(_port(actions));

        expect(result.syncState, OperationSyncState.conflict);
        expect(actions.actionCalled, isFalse);
        expect(
          actions.calls.where(
            (call) => call.method == 'action_l10n_ec_enviar_a_caja',
          ),
          isEmpty,
        );
      }
    },
  );

  test(
    'ambiguous action without native evidence is not retried blindly',
    () async {
      final actions = _FakeActions()
        ..actionError = const AmbiguousOperationException('transport timeout');

      final result = await _send(_port(actions));

      expect(result.syncState, OperationSyncState.conflict);
      expect(result.issues.single.code, 'payment_transaction_send_ambiguous');
      expect(result.issues.single.retryable, isFalse);
      expect(actions.actionCalled, isTrue);
      expect(
        actions.calls.where(
          (call) => call.method == 'action_l10n_ec_enviar_a_caja',
        ),
        hasLength(1),
      );
    },
  );

  test(
    'duplicate/rejected action is applied when native line proves it',
    () async {
      final actions = _FakeActions()
        ..actionError = StateError('already sent')
        ..linesAfter = [_line()];

      final result = await _send(_port(actions));

      expect(result.syncState, OperationSyncState.synced);
      expect(result.issues, isEmpty);
    },
  );

  test(
    'mismatching native line is a conflict, never an applied result',
    () async {
      final actions = _FakeActions()..linesAfter = [_line(journalId: 10)];

      final result = await _send(_port(actions));

      expect(result.syncState, OperationSyncState.conflict);
      expect(result.issues.single.code, 'payment_transaction_line_conflict');
    },
  );
}
