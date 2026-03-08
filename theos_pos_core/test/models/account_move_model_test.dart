import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/invoices/account_move.model.dart';

void main() {
  group('AccountMove - fromOdoo', () {
    test('parses typical invoice data', () {
      final json = {
        'id': 100,
        'name': 'INV/2024/0001',
        'move_type': 'out_invoice',
        'state': 'posted',
        'payment_state': 'not_paid',
        'invoice_date': '2024-06-15',
        'invoice_date_due': '2024-07-15',
        'date': '2024-06-15',
        'partner_id': [42, 'Test Partner'],
        'partner_vat': '1710034065001',
        'journal_id': [1, 'Facturas'],
        'amount_untaxed': 100.0,
        'amount_tax': 15.0,
        'amount_total': 115.0,
        'amount_residual': 115.0,
        'company_id': [1, 'My Company'],
        'currency_id': [2, 'USD'],
        'invoice_origin': 'SO001',
        'ref': 'REF001',
        'l10n_ec_authorization_number': '1234567890123456789012345678901234567890123456789',
        'l10n_latam_document_number': '001-001-000000001',
        'l10n_latam_document_type_id': [10, 'Factura'],
        'write_date': '2024-06-15 10:30:00',
      };

      final move = accountMoveManager.fromOdoo(json);

      expect(move.id, equals(100));
      expect(move.name, equals('INV/2024/0001'));
      expect(move.moveType, equals('out_invoice'));
      expect(move.state, equals('posted'));
      expect(move.paymentState, equals('not_paid'));
      expect(move.invoiceDate, isNotNull);
      expect(move.invoiceDateDue, isNotNull);
      expect(move.partnerId, equals(42));
      expect(move.partnerName, equals('Test Partner'));
      expect(move.partnerVat, equals('1710034065001'));
      expect(move.journalId, equals(1));
      expect(move.journalName, equals('Facturas'));
      expect(move.amountUntaxed, equals(100.0));
      expect(move.amountTax, equals(15.0));
      expect(move.amountTotal, equals(115.0));
      expect(move.amountResidual, equals(115.0));
      expect(move.companyId, equals(1));
      expect(move.currencyId, equals(2));
      expect(move.currencySymbol, equals('USD'));
      expect(move.invoiceOrigin, equals('SO001'));
      expect(move.ref, equals('REF001'));
      expect(move.l10nEcAuthorizationNumber, equals('1234567890123456789012345678901234567890123456789'));
      expect(move.l10nLatamDocumentNumber, equals('001-001-000000001'));
      expect(move.l10nLatamDocumentTypeId, equals(10));
      expect(move.l10nLatamDocumentTypeName, equals('Factura'));
    });

    test('handles false/null Odoo values', () {
      final json = {
        'id': 1,
        'name': 'INV/001',
        'partner_id': false,
        'journal_id': false,
        'partner_vat': false,
        'invoice_date': false,
        'invoice_date_due': false,
        'l10n_ec_authorization_number': false,
        'l10n_latam_document_number': false,
        'l10n_latam_document_type_id': false,
        'currency_id': false,
        'company_id': false,
        'invoice_origin': false,
        'ref': false,
        'write_date': false,
      };

      final move = accountMoveManager.fromOdoo(json);

      expect(move.partnerId, isNull);
      expect(move.partnerName, isNull);
      expect(move.journalId, isNull);
      expect(move.invoiceDate, isNull);
      expect(move.l10nEcAuthorizationNumber, isNull);
      expect(move.currencyId, isNull);
      expect(move.companyId, isNull);
      expect(move.invoiceOrigin, isNull);
      expect(move.ref, isNull);
    });

    test('handles partner_id as integer (not Many2one)', () {
      final json = {
        'id': 1,
        'name': 'INV/001',
        'partner_id': 42,
      };

      final move = accountMoveManager.fromOdoo(json);
      expect(move.partnerId, equals(42));
      expect(move.partnerName, isNull);
    });

    test('handles l10n_latam_document_type_id with translated map name', () {
      final json = {
        'id': 1,
        'name': 'INV/001',
        'l10n_latam_document_type_id': [10, {'es_EC': 'Factura', 'en_US': 'Invoice'}],
      };

      final move = accountMoveManager.fromOdoo(json);
      expect(move.l10nLatamDocumentTypeId, equals(10));
      // extractMany2oneName returns the map's toString when name is a Map
      expect(move.l10nLatamDocumentTypeName, equals('{es_EC: Factura, en_US: Invoice}'));
    });
  });

  group('AccountMove - State Machine', () {
    test('isDraft returns true for draft state', () {
      const move = AccountMove(state: 'draft');
      expect(move.isDraft, isTrue);
      expect(move.isPosted, isFalse);
      expect(move.isCancelled, isFalse);
    });

    test('isPosted returns true for posted state', () {
      const move = AccountMove(state: 'posted');
      expect(move.isPosted, isTrue);
      expect(move.isDraft, isFalse);
    });

    test('isCancelled returns true for cancel state', () {
      const move = AccountMove(state: 'cancel');
      expect(move.isCancelled, isTrue);
    });

    test('canPost only when draft', () {
      expect(const AccountMove(state: 'draft').canPost, isTrue);
      expect(const AccountMove(state: 'posted').canPost, isFalse);
      expect(const AccountMove(state: 'cancel').canPost, isFalse);
    });

    test('canCancel when posted and not paid', () {
      expect(
        const AccountMove(state: 'posted', paymentState: 'not_paid').canCancel,
        isTrue,
      );
      expect(
        const AccountMove(state: 'posted', paymentState: 'paid').canCancel,
        isFalse,
      );
      expect(
        const AccountMove(state: 'draft').canCancel,
        isFalse,
      );
    });

    test('canPrint only when posted', () {
      expect(const AccountMove(state: 'posted').canPrint, isTrue);
      expect(const AccountMove(state: 'draft').canPrint, isFalse);
    });

    test('hasResidual when amount > 0', () {
      expect(const AccountMove(amountResidual: 100.0).hasResidual, isTrue);
      expect(const AccountMove(amountResidual: 0.0).hasResidual, isFalse);
    });
  });

  group('AccountMove - Payment States', () {
    test('isPaid returns true for paid state', () {
      const move = AccountMove(paymentState: 'paid');
      expect(move.isPaid, isTrue);
    });

    test('isPaid returns false for other states', () {
      expect(const AccountMove(paymentState: 'not_paid').isPaid, isFalse);
      expect(const AccountMove(paymentState: 'partial').isPaid, isFalse);
      expect(const AccountMove(paymentState: 'in_payment').isPaid, isFalse);
    });

    test('stateDisplay returns Spanish labels', () {
      expect(const AccountMove(state: 'draft').stateDisplay, equals('Borrador'));
      expect(const AccountMove(state: 'posted').stateDisplay, equals('Publicada'));
      expect(const AccountMove(state: 'cancel').stateDisplay, equals('Cancelada'));
    });

    test('paymentStateDisplay returns Spanish labels', () {
      expect(
        const AccountMove(paymentState: 'not_paid').paymentStateDisplay,
        equals('No pagada'),
      );
      expect(
        const AccountMove(paymentState: 'paid').paymentStateDisplay,
        equals('Pagada'),
      );
      expect(
        const AccountMove(paymentState: 'partial').paymentStateDisplay,
        equals('Parcial'),
      );
      expect(
        const AccountMove(paymentState: 'in_payment').paymentStateDisplay,
        equals('En pago'),
      );
      expect(
        const AccountMove(paymentState: 'reversed').paymentStateDisplay,
        equals('Reversada'),
      );
    });

    test('documentTypeDisplay returns correct labels', () {
      expect(
        const AccountMove(moveType: 'out_invoice').documentTypeDisplay,
        equals('Factura'),
      );
      expect(
        const AccountMove(moveType: 'out_refund').documentTypeDisplay,
        equals('Nota de Credito'),
      );
      expect(
        const AccountMove(moveType: 'in_invoice').documentTypeDisplay,
        equals('Factura Proveedor'),
      );
      expect(
        const AccountMove(moveType: 'in_refund').documentTypeDisplay,
        equals('Nota de Credito Proveedor'),
      );
    });
  });

  group('AccountMove - SRI Authorization', () {
    test('isSriAuthorized requires 49 character authorization', () {
      const authorized = AccountMove(
        l10nEcAuthorizationNumber: '1234567890123456789012345678901234567890123456789',
      );
      expect(authorized.isSriAuthorized, isTrue);
      expect(authorized.l10nEcAuthorizationNumber!.length, equals(49));
    });

    test('isSriAuthorized false for short authorization', () {
      const notAuthorized = AccountMove(
        l10nEcAuthorizationNumber: '12345',
      );
      expect(notAuthorized.isSriAuthorized, isFalse);
    });

    test('isSriAuthorized false when null', () {
      const noAuth = AccountMove();
      expect(noAuth.isSriAuthorized, isFalse);
    });
  });

  group('AccountMove - validateFor', () {
    test('validateFor post fails when not draft', () {
      const move = AccountMove(
        state: 'posted',
        partnerId: 1,
        amountTotal: 100.0,
      );
      final errors = move.validateFor('post');
      expect(errors.containsKey('state'), isTrue);
    });

    test('validateFor post fails without partner', () {
      const move = AccountMove(state: 'draft', amountTotal: 100.0);
      final errors = move.validateFor('post');
      expect(errors.containsKey('partnerId'), isTrue);
    });

    test('validateFor post passes with valid draft invoice', () {
      const move = AccountMove(
        state: 'draft',
        partnerId: 42,
        amountTotal: 100.0,
        lines: [
          AccountMoveLine(
            id: 1,
            quantity: 1.0,
            priceUnit: 100.0,
            priceSubtotal: 100.0,
            priceTotal: 115.0,
          ),
        ],
      );
      final errors = move.validateFor('post');
      expect(errors.containsKey('state'), isFalse);
      expect(errors.containsKey('partnerId'), isFalse);
    });

    test('validateFor cancel fails when paid', () {
      const move = AccountMove(state: 'posted', paymentState: 'paid');
      final errors = move.validateFor('cancel');
      expect(errors.containsKey('paymentState'), isTrue);
    });

    test('validateFor draft fails when not cancelled', () {
      const move = AccountMove(state: 'posted');
      final errors = move.validateFor('draft');
      expect(errors.containsKey('state'), isTrue);
    });

    test('validateFor register_payment fails without residual', () {
      const move = AccountMove(state: 'posted', amountResidual: 0.0);
      final errors = move.validateFor('register_payment');
      expect(errors.containsKey('amountResidual'), isTrue);
    });

    test('validateFor credit_note fails when not posted', () {
      const move = AccountMove(state: 'draft');
      final errors = move.validateFor('credit_note');
      expect(errors.containsKey('state'), isTrue);
    });
  });
}
