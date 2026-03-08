import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/sales/sale_order.model.dart';

void main() {
  /// Helper to create a minimal valid SaleOrder
  SaleOrder validOrder({
    SaleOrderState state = SaleOrderState.draft,
    int? partnerId = 1,
    double amountTotal = 100.0,
    InvoiceStatus invoiceStatus = InvoiceStatus.no,
    bool locked = false,
  }) {
    return SaleOrder(
      id: 1,
      name: 'SO001',
      state: state,
      partnerId: partnerId,
      amountTotal: amountTotal,
      invoiceStatus: invoiceStatus,
      locked: locked,
    );
  }

  group('SaleOrder - validate() base constraints', () {
    test('passes with valid data', () {
      final order = validOrder();
      expect(order.validate(), isEmpty);
    });

    test('fails without partner', () {
      final order = validOrder(partnerId: null);
      final errors = order.validate();
      expect(errors.containsKey('partner_id'), isTrue);
    });

    test('fails with negative total', () {
      final order = validOrder(amountTotal: -10.0);
      final errors = order.validate();
      expect(errors.containsKey('amount_total'), isTrue);
    });

    test('fails for final consumer exceeding limit without end customer name', () {
      const order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 1,
        isFinalConsumer: true,
        exceedsFinalConsumerLimit: true,
        endCustomerName: null,
      );
      final errors = order.validate();
      expect(errors.containsKey('end_customer_name'), isTrue);
    });

    test('passes for final consumer exceeding limit with end customer name', () {
      const order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 1,
        isFinalConsumer: true,
        exceedsFinalConsumerLimit: true,
        endCustomerName: 'Juan Pérez',
      );
      final errors = order.validate();
      expect(errors.containsKey('end_customer_name'), isFalse);
    });

    test('fails for postdated invoice without date', () {
      const order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 1,
        emitirFacturaFechaPosterior: true,
        fechaFacturar: null,
      );
      final errors = order.validate();
      expect(errors.containsKey('fecha_facturar'), isTrue);
    });

    test('fails when validity date before order date', () {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 1,
        dateOrder: DateTime(2024, 6, 15),
        validityDate: DateTime(2024, 6, 10),
      );
      final errors = order.validate();
      expect(errors.containsKey('validity_date'), isTrue);
    });

    test('fails when commitment date before order date', () {
      final order = SaleOrder(
        id: 1,
        name: 'SO001',
        state: SaleOrderState.draft,
        partnerId: 1,
        dateOrder: DateTime(2024, 6, 15),
        commitmentDate: DateTime(2024, 6, 10),
      );
      final errors = order.validate();
      expect(errors.containsKey('commitment_date'), isTrue);
    });
  });

  group('SaleOrder - validateFor("confirm")', () {
    test('passes for valid draft order', () {
      final order = validOrder(amountTotal: 50.0);
      final errors = order.validateFor('confirm');
      expect(errors.containsKey('state'), isFalse);
      expect(errors.containsKey('amount_total'), isFalse);
    });

    test('fails with zero amount', () {
      final order = validOrder(amountTotal: 0.0);
      final errors = order.validateFor('confirm');
      expect(errors.containsKey('amount_total'), isTrue);
    });

    test('fails when already confirmed (sale state)', () {
      final order = validOrder(state: SaleOrderState.sale);
      final errors = order.validateFor('confirm');
      expect(errors.containsKey('state'), isTrue);
    });

    test('can confirm from sent state', () {
      final order = validOrder(state: SaleOrderState.sent);
      final errors = order.validateFor('confirm');
      expect(errors.containsKey('state'), isFalse);
    });

    test('can confirm from approved state', () {
      final order = validOrder(state: SaleOrderState.approved);
      final errors = order.validateFor('confirm');
      expect(errors.containsKey('state'), isFalse);
    });

    test('fails from cancelled state', () {
      final order = validOrder(state: SaleOrderState.cancel);
      final errors = order.validateFor('confirm');
      expect(errors.containsKey('state'), isTrue);
    });
  });

  group('SaleOrder - validateFor("cancel")', () {
    test('can cancel from draft', () {
      final order = validOrder(state: SaleOrderState.draft);
      final errors = order.validateFor('cancel');
      expect(errors.containsKey('state'), isFalse);
    });

    test('can cancel from sent', () {
      final order = validOrder(state: SaleOrderState.sent);
      final errors = order.validateFor('cancel');
      expect(errors.containsKey('state'), isFalse);
    });

    test('cannot cancel from done', () {
      final order = validOrder(state: SaleOrderState.done);
      final errors = order.validateFor('cancel');
      expect(errors.containsKey('state'), isTrue);
    });
  });

  group('SaleOrder - validateFor("invoice")', () {
    test('can invoice from sale state', () {
      final order = validOrder(
        state: SaleOrderState.sale,
        invoiceStatus: InvoiceStatus.toInvoice,
      );
      final errors = order.validateFor('invoice');
      expect(errors.containsKey('state'), isFalse);
    });

    test('cannot invoice from draft state', () {
      final order = validOrder(state: SaleOrderState.draft);
      final errors = order.validateFor('invoice');
      expect(errors.containsKey('state'), isTrue);
    });

    test('fails when fully invoiced', () {
      final order = validOrder(
        state: SaleOrderState.sale,
        invoiceStatus: InvoiceStatus.invoiced,
      );
      final errors = order.validateFor('invoice');
      expect(errors.containsKey('invoice_status'), isTrue);
    });
  });

  group('SaleOrder - State Computed Properties', () {
    test('canConfirm for draft/sent/approved', () {
      expect(validOrder(state: SaleOrderState.draft).canConfirm, isTrue);
      expect(validOrder(state: SaleOrderState.sent).canConfirm, isTrue);
      expect(validOrder(state: SaleOrderState.approved).canConfirm, isTrue);
      expect(validOrder(state: SaleOrderState.sale).canConfirm, isFalse);
      expect(validOrder(state: SaleOrderState.cancel).canConfirm, isFalse);
    });

    test('canInvoice only from sale state', () {
      expect(validOrder(state: SaleOrderState.sale).canInvoice, isTrue);
      expect(validOrder(state: SaleOrderState.draft).canInvoice, isFalse);
    });

    test('isFullyInvoiced checks invoice status', () {
      expect(
        validOrder(invoiceStatus: InvoiceStatus.invoiced).isFullyInvoiced,
        isTrue,
      );
      expect(
        validOrder(invoiceStatus: InvoiceStatus.toInvoice).isFullyInvoiced,
        isFalse,
      );
    });

    test('canLock requires sale state, not locked, not fully invoiced', () {
      expect(
        validOrder(state: SaleOrderState.sale, locked: false).canLock,
        isTrue,
      );
      expect(
        validOrder(state: SaleOrderState.sale, locked: true).canLock,
        isFalse,
      );
      expect(
        validOrder(state: SaleOrderState.draft).canLock,
        isFalse,
      );
    });
  });
}
