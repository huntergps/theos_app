import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/sales/screens/fast_sale/widgets/pos_payment_tab.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  PaymentLine line(String uuid, double amount) => PaymentLine(
    id: 0,
    lineUuid: uuid,
    type: PaymentLineType.payment,
    date: DateTime(2026, 9, 5),
    amount: amount,
    journalId: 30,
  );

  test('existing invoice retry UUID is stable and order independent', () {
    final first = line('payment-b', 4);
    final second = line('payment-a', 6);

    final one = existingInvoiceCollectionOperationUuid(501, [first, second]);
    final retry = existingInvoiceCollectionOperationUuid(501, [second, first]);

    expect(one, isNotEmpty);
    expect(one, retry);
  });

  test('existing invoice retry UUID changes when a new line is added', () {
    final first = line('payment-a', 6);
    final second = line('payment-b', 4);

    expect(
      existingInvoiceCollectionOperationUuid(501, [first]),
      isNot(existingInvoiceCollectionOperationUuid(501, [first, second])),
    );
  });

  test('existing invoice adapter collects only new lines and never creates invoice', () async {
    final invoice = AccountMove(
      id: 501,
      name: 'FAC/501',
      moveType: 'out_invoice',
      state: 'posted',
      amountResidual: 10,
    );
    final old = line('already-queued', 2).copyWith(isSynced: true);
    final fresh = line('new-payment', 6);
    var calls = 0;
    List<PaymentLine>? received;
    String? operation;

    final result = await collectExistingInvoiceFromPos(
      saleOrderId: 42,
      invoice: invoice,
      collectionSessionId: 18,
      operatorId: 7,
      lines: [fresh],
      collector:
          ({
            required saleOrderId,
            required invoiceId,
            required collectionSessionId,
            required operatorId,
            required operationUuid,
            required lines,
          }) async {
            calls++;
            received = lines;
            operation = operationUuid;
            expect(invoiceId, 501);
            expect(saleOrderId, 42);
            return 9001;
          },
    );

    expect(result, 9001);
    expect(calls, 1);
    expect(received, [fresh]);
    expect(operation, existingInvoiceCollectionOperationUuid(501, [fresh]));
    expect(received, isNot(contains(old)));
  });

  test(
    'existing invoice adapter excludes a line already in the outbox',
    () async {
      final invoice = AccountMove(
        id: 501,
        name: 'FAC/501',
        moveType: 'out_invoice',
        state: 'posted',
        amountResidual: 10,
      );
      final queued = line('queued-operation-line', 2);
      final fresh = line('fresh-operation-line', 3);
      var calls = 0;
      List<PaymentLine>? received;

      await collectExistingInvoiceFromPos(
        saleOrderId: 42,
        invoice: invoice,
        collectionSessionId: 18,
        operatorId: 7,
        lines: [queued, fresh],
        queuedLineUuids: {queued.lineUuid!},
        collector:
            ({
              required saleOrderId,
              required invoiceId,
              required collectionSessionId,
              required operatorId,
              required operationUuid,
              required lines,
            }) async {
              calls++;
              received = lines;
              return 9002;
            },
      );

      expect(calls, 1);
      expect(received, [fresh]);
    },
  );

  test(
    'existing invoice adapter rejects exhausted balance and non-payment lines',
    () async {
      final invoice = AccountMove(
        id: 501,
        name: 'FAC/501',
        moveType: 'out_invoice',
        state: 'posted',
        amountResidual: 5,
      );
      Future<int> collector({
        required int saleOrderId,
        required int invoiceId,
        required int collectionSessionId,
        required int operatorId,
        required String operationUuid,
        required List<PaymentLine> lines,
      }) async => 1;

      await expectLater(
        collectExistingInvoiceFromPos(
          saleOrderId: 42,
          invoice: invoice,
          collectionSessionId: 18,
          operatorId: 7,
          lines: [line('over', 6)],
          collector: collector,
        ),
        throwsStateError,
      );
      await expectLater(
        collectExistingInvoiceFromPos(
          saleOrderId: 42,
          invoice: invoice,
          collectionSessionId: 18,
          operatorId: 7,
          lines: [line('advance', 1).copyWith(type: PaymentLineType.advance)],
          collector: collector,
        ),
        throwsStateError,
      );
    },
  );
}
