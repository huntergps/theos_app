import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show InvoiceStatus, SaleOrderState;

import '../../../helpers/test_model_factory.dart';

void main() {
  setUp(() => resetIdCounter());

  group('SaleOrder factory methods', () {
    test('draft() creates order in draft state', () {
      final order = SaleOrderFactory.draft();

      expect(order.state, SaleOrderState.draft);
      expect(order.userId, 1);
      expect(order.dateOrder, isNotNull);
      expect(order.name, startsWith('SO'));
    });

    test('draft() accepts custom parameters', () {
      final order = SaleOrderFactory.draft(
        id: 42,
        name: 'CUSTOM-001',
        partnerId: 10,
        userId: 5,
      );

      expect(order.id, 42);
      expect(order.name, 'CUSTOM-001');
      expect(order.partnerId, 10);
      expect(order.userId, 5);
      expect(order.state, SaleOrderState.draft);
    });

    test('withAmounts() creates order with correct amounts', () {
      final order = SaleOrderFactory.withAmounts(
        amountUntaxed: 200.0,
        amountTax: 30.0,
      );

      expect(order.amountUntaxed, 200.0);
      expect(order.amountTax, 30.0);
      expect(order.amountTotal, 230.0);
      expect(order.state, SaleOrderState.draft);
      expect(order.partnerId, isNotNull);
    });

    test('withAmounts() uses default amounts', () {
      final order = SaleOrderFactory.withAmounts();

      expect(order.amountUntaxed, 100.0);
      expect(order.amountTax, 15.0);
      expect(order.amountTotal, 115.0);
    });

    test('confirmed() creates order in sale state', () {
      final order = SaleOrderFactory.confirmed();

      expect(order.state, SaleOrderState.sale);
      expect(order.amountTotal, greaterThan(0));
    });

    test('cancelled() creates order in cancel state', () {
      final order = SaleOrderFactory.cancelled();

      expect(order.state, SaleOrderState.cancel);
    });
  });

  group('copyWith', () {
    test('changes state while preserving other fields', () {
      final draft = SaleOrderFactory.draft(partnerId: 10, userId: 5);
      final confirmed = draft.copyWith(state: SaleOrderState.sale);

      expect(confirmed.state, SaleOrderState.sale);
      expect(confirmed.partnerId, 10);
      expect(confirmed.userId, 5);
      expect(confirmed.name, draft.name);
      expect(confirmed.id, draft.id);
    });

    test('changes amounts while preserving state', () {
      final order = SaleOrderFactory.confirmed();
      final updated = order.copyWith(
        amountUntaxed: 500.0,
        amountTax: 75.0,
        amountTotal: 575.0,
      );

      expect(updated.state, SaleOrderState.sale);
      expect(updated.amountUntaxed, 500.0);
      expect(updated.amountTax, 75.0);
      expect(updated.amountTotal, 575.0);
    });

    test('changes partner fields', () {
      final order = SaleOrderFactory.draft(partnerId: 1);
      final updated = order.copyWith(
        partnerId: 99,
        partnerName: 'New Partner',
        partnerVat: '1234567890001',
      );

      expect(updated.partnerId, 99);
      expect(updated.partnerName, 'New Partner');
      expect(updated.partnerVat, '1234567890001');
    });
  });

  group('State checks', () {
    test('isDraft-like checks on draft order', () {
      final order = SaleOrderFactory.draft(partnerId: 1);

      expect(order.isQuotation, isTrue);
      expect(order.isConfirmed, isFalse);
      expect(order.isSaleOrder, isFalse);
      expect(order.isEditable, isTrue);
      expect(order.canConfirm, isTrue);
      expect(order.canCancel, isTrue);
      expect(order.canSendQuotation, isTrue);
    });

    test('state checks on confirmed (sale) order', () {
      final order = SaleOrderFactory.confirmed();

      expect(order.isConfirmed, isTrue);
      expect(order.isSaleOrder, isTrue);
      expect(order.isQuotation, isFalse);
      expect(order.isEditable, isFalse);
      expect(order.canConfirm, isFalse);
      expect(order.canCancel, isTrue);
      expect(order.canInvoice, isTrue);
      expect(order.canAddPayments, isTrue);
      expect(order.canSendQuotation, isFalse);
    });

    test('state checks on cancelled order', () {
      final order = SaleOrderFactory.cancelled();

      expect(order.state, SaleOrderState.cancel);
      expect(order.isConfirmed, isFalse);
      expect(order.isQuotation, isFalse);
      expect(order.canEdit, isFalse);
      expect(order.canConfirm, isFalse);
      expect(order.canCancel, isFalse);
      expect(order.canSetToQuotation, isTrue);
    });

    test('state checks on sent order', () {
      final order = SaleOrderFactory.draft().copyWith(
        state: SaleOrderState.sent,
      );

      expect(order.isQuotation, isTrue);
      expect(order.isEditable, isTrue);
      expect(order.canConfirm, isTrue);
      expect(order.canCancel, isTrue);
      expect(order.canSendQuotation, isFalse);
    });

    test('state checks on waitingApproval order', () {
      final order = SaleOrderFactory.draft().copyWith(
        state: SaleOrderState.waitingApproval,
      );

      expect(order.canReject, isTrue);
      expect(order.canConfirm, isFalse);
      expect(order.isEditable, isFalse);
      expect(order.canCancel, isTrue);
    });

    test('state checks on approved order', () {
      final order = SaleOrderFactory.draft().copyWith(
        state: SaleOrderState.approved,
      );

      expect(order.canConfirm, isTrue);
      expect(order.canCancel, isTrue);
      expect(order.isEditable, isFalse);
      expect(order.canReject, isFalse);
    });

    test('state checks on rejected order', () {
      final order = SaleOrderFactory.draft().copyWith(
        state: SaleOrderState.rejected,
      );

      expect(order.isRejected, isTrue);
      expect(order.canReactivateFromRejection, isTrue);
      expect(order.canSetToQuotation, isTrue);
      expect(order.canEdit, isFalse);
      expect(order.canConfirm, isFalse);
    });

    test('locked sale order restricts actions', () {
      final order = SaleOrderFactory.confirmed().copyWith(locked: true);

      expect(order.isConfirmed, isTrue);
      expect(order.canCancel, isFalse);
      expect(order.canEdit, isFalse);
      expect(order.isEditable, isFalse);
      expect(order.canLock, isFalse);
      expect(order.canUnlock, isTrue);
      expect(order.canSetToQuotation, isFalse);
    });

    test('canLock and canUnlock on sale order', () {
      final order = SaleOrderFactory.confirmed();

      expect(order.canLock, isTrue);
      expect(order.canUnlock, isFalse);

      final locked = order.copyWith(locked: true);
      expect(locked.canLock, isFalse);
      expect(locked.canUnlock, isTrue);
    });

    test('fully invoiced order cannot lock/unlock', () {
      final order = SaleOrderFactory.confirmed().copyWith(
        invoiceStatus: InvoiceStatus.invoiced,
      );

      expect(order.isFullyInvoiced, isTrue);
      expect(order.canLock, isFalse);
      expect(order.canUnlock, isFalse);
    });

    test('hasQueuedInvoice prevents payments and invoicing', () {
      final order = SaleOrderFactory.confirmed().copyWith(
        hasQueuedInvoice: true,
      );

      expect(order.canAddPayments, isFalse);
      expect(order.canInvoice, isFalse);
    });
  });

  group('Payment type checks', () {
    test('default is cash sale', () {
      final order = SaleOrderFactory.draft(partnerId: 1);

      expect(order.isCashSale, isTrue);
      expect(order.isCreditSale, isFalse);
    });

    test('credit sale when isCredit is true', () {
      final order = SaleOrderFactory.draft(partnerId: 1).copyWith(
        isCash: false,
        isCredit: true,
        paymentTermId: 5,
      );

      expect(order.isCashSale, isFalse);
      expect(order.isCreditSale, isTrue);
    });

    test('cash sale when no payment term', () {
      final order = SaleOrderFactory.draft(partnerId: 1).copyWith(
        isCash: false,
        paymentTermId: null,
      );

      // isCashSale checks isCash || paymentTermId == null
      expect(order.isCashSale, isTrue);
    });
  });

  group('Amount calculations', () {
    test('amountTotal equals amountUntaxed + amountTax', () {
      final order = SaleOrderFactory.withAmounts(
        amountUntaxed: 300.0,
        amountTax: 45.0,
      );

      expect(order.amountTotal, 345.0);
    });

    test('zero amounts by default on draft', () {
      final order = SaleOrderFactory.draft();

      expect(order.amountUntaxed, 0.0);
      expect(order.amountTax, 0.0);
      expect(order.amountTotal, 0.0);
    });

    test('amounts preserved through state transitions', () {
      final order = SaleOrderFactory.withAmounts(
        amountUntaxed: 500.0,
        amountTax: 75.0,
      );
      final confirmed = order.copyWith(state: SaleOrderState.sale);

      expect(confirmed.amountUntaxed, 500.0);
      expect(confirmed.amountTax, 75.0);
      expect(confirmed.amountTotal, 575.0);
    });
  });

  group('Date handling', () {
    test('dateOrder is set on factory creation', () {
      final before = DateTime.now();
      final order = SaleOrderFactory.draft();
      final after = DateTime.now();

      expect(order.dateOrder, isNotNull);
      expect(
        order.dateOrder!.isAfter(before.subtract(const Duration(seconds: 1))),
        isTrue,
      );
      expect(
        order.dateOrder!.isBefore(after.add(const Duration(seconds: 1))),
        isTrue,
      );
    });

    test('optional dates are null by default', () {
      final order = SaleOrderFactory.draft();

      expect(order.validityDate, isNull);
      expect(order.commitmentDate, isNull);
      expect(order.expectedDate, isNull);
    });

    test('dates can be set via copyWith', () {
      final order = SaleOrderFactory.draft();
      final validity = DateTime(2026, 12, 31);
      final commitment = DateTime(2026, 6, 15);

      final updated = order.copyWith(
        validityDate: validity,
        commitmentDate: commitment,
      );

      expect(updated.validityDate, validity);
      expect(updated.commitmentDate, commitment);
    });
  });

  group('Validation', () {
    test('validate() requires partner', () {
      final order = SaleOrderFactory.draft(partnerId: null);
      final errors = order.validate();

      expect(errors, contains('partner_id'));
    });

    test('validate() passes with valid partner', () {
      final order = SaleOrderFactory.draft(partnerId: 1);
      final errors = order.validate();

      expect(errors, isNot(contains('partner_id')));
    });

    test('validate() rejects negative total', () {
      final order = SaleOrderFactory.draft(partnerId: 1).copyWith(
        amountTotal: -10.0,
      );
      final errors = order.validate();

      expect(errors, contains('amount_total'));
    });

    test('validate() rejects validity date before order date', () {
      final order = SaleOrderFactory.draft(partnerId: 1).copyWith(
        dateOrder: DateTime(2026, 6, 15),
        validityDate: DateTime(2026, 6, 1),
      );
      final errors = order.validate();

      expect(errors, contains('validity_date'));
    });

    test('validateFor confirm requires positive total', () {
      final order = SaleOrderFactory.draft(partnerId: 1);
      final errors = order.validateFor('confirm');

      expect(errors, contains('amount_total'));
    });

    test('validateFor confirm passes with amounts', () {
      final order = SaleOrderFactory.withAmounts(partnerId: 1);
      final errors = order.validateFor('confirm');

      expect(errors, isNot(contains('amount_total')));
      expect(errors, isNot(contains('state')));
    });

    test('validateFor cancel fails on cancelled order', () {
      final order = SaleOrderFactory.cancelled(partnerId: 1);
      final errors = order.validateFor('cancel');

      expect(errors, contains('state'));
    });
  });

  group('Display names', () {
    test('stateDisplayName returns correct label for each state', () {
      expect(
        SaleOrderFactory.draft().stateDisplayName,
        'Cotizacion',
      );
      expect(
        SaleOrderFactory.confirmed().stateDisplayName,
        'Orden de Venta',
      );
      expect(
        SaleOrderFactory.cancelled().stateDisplayName,
        'Cancelado',
      );
    });

    test('displayState is alias for stateDisplayName', () {
      final order = SaleOrderFactory.draft();

      expect(order.displayState, order.stateDisplayName);
    });
  });
}
