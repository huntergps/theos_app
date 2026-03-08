import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  group('PaymentLine', () {
    group('constructor', () {
      test('should create payment line with required fields', () {
        final line = PaymentLine(
          id: -1,
          type: PaymentLineType.payment,
          date: DateTime(2024, 1, 15),
          amount: 100.0,
        );

        expect(line.id, -1);
        expect(line.type, PaymentLineType.payment);
        expect(line.date, DateTime(2024, 1, 15));
        expect(line.amount, 100.0);
      });

      test('should preserve lineUuid if provided', () {
        final line = PaymentLine(
          id: -1,
          lineUuid: 'custom-uuid-123',
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 100.0,
        );

        expect(line.lineUuid, 'custom-uuid-123');
      });
    });

    group('description', () {
      test('should return advance description', () {
        final line = PaymentLine(
          id: -1,
          type: PaymentLineType.advance,
          date: DateTime.now(),
          amount: 50.0,
          advanceId: 123,
          advanceName: 'ANT-001',
        );

        expect(line.description, 'Anticipo ANT-001');
      });

      test('should return credit note description', () {
        final line = PaymentLine(
          id: -2,
          type: PaymentLineType.creditNote,
          date: DateTime.now(),
          amount: 75.0,
          creditNoteId: 456,
          creditNoteName: 'NC-001',
        );

        expect(line.description, 'NC NC-001');
      });

      test('should return payment description with journal name', () {
        final line = PaymentLine(
          id: -3,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 100.0,
          journalId: 1,
          journalName: 'Efectivo',
          journalType: 'cash',
          paymentMethodCode: 'manual',
        );

        expect(line.description, 'Efectivo');
      });

      test('should include card brand in payment description', () {
        final line = PaymentLine(
          id: -4,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 100.0,
          journalId: 1,
          journalName: 'Banco Pichincha',
          journalType: 'bank',
          paymentMethodCode: 'card_payment',
          cardBrandName: 'Visa',
          cardDeadlineName: 'Corriente',
        );

        expect(line.description, contains('Visa'));
        expect(line.description, contains('Corriente'));
      });

      test('should include check number in payment description', () {
        final line = PaymentLine(
          id: -5,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 100.0,
          journalId: 1,
          journalName: 'Banco Pichincha',
          journalType: 'bank',
          paymentMethodCode: 'cheque',
          reference: '12345',
        );

        expect(line.description, contains('Ch. 12345'));
      });

      test('should include transfer reference in payment description', () {
        final line = PaymentLine(
          id: -6,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 100.0,
          journalId: 1,
          journalName: 'Banco Pichincha',
          journalType: 'bank',
          paymentMethodCode: 'transferencia',
          reference: 'TRF-001',
        );

        expect(line.description, contains('Ref. TRF-001'));
      });
    });

    group('copyWith', () {
      test('should copy with new amount', () {
        final original = PaymentLine(
          id: -7,
          lineUuid: 'test-uuid',
          type: PaymentLineType.payment,
          date: DateTime(2024, 1, 15),
          amount: 100.0,
          journalId: 1,
          journalName: 'Efectivo',
        );

        final copied = original.copyWith(amount: 200.0);

        expect(copied.amount, 200.0);
        expect(copied.type, original.type);
        expect(copied.date, original.date);
        expect(copied.journalId, original.journalId);
        expect(copied.lineUuid, original.lineUuid);
      });

      test('should copy all fields when no changes', () {
        final original = PaymentLine(
          id: -8,
          type: PaymentLineType.advance,
          date: DateTime(2024, 1, 15),
          amount: 50.0,
          advanceId: 123,
          advanceName: 'ANT-001',
          advanceAvailable: 100.0,
        );

        final copied = original.copyWith();

        expect(copied.type, original.type);
        expect(copied.date, original.date);
        expect(copied.amount, original.amount);
        expect(copied.advanceId, original.advanceId);
        expect(copied.advanceName, original.advanceName);
        expect(copied.advanceAvailable, original.advanceAvailable);
      });
    });

    group('toOdoo', () {
      test('should convert payment line to Odoo values', () {
        final line = PaymentLine(
          id: -9,
          type: PaymentLineType.payment,
          date: DateTime(2024, 1, 15),
          amount: 100.0,
          journalId: 1,
          reference: 'REF-001',
        );

        final values = paymentLineManager.toOdoo(line);

        expect(values['date'], '2024-01-15');
        expect(values['amount'], 100.0);
        expect(values['journal_id'], 1);
        expect(values['payment_reference'], 'REF-001');
      });

      test('should convert advance line to Odoo values', () {
        final line = PaymentLine(
          id: -10,
          type: PaymentLineType.advance,
          date: DateTime(2024, 1, 15),
          amount: 50.0,
          advanceId: 123,
        );

        final values = paymentLineManager.toOdoo(line);

        expect(values['date'], '2024-01-15');
        expect(values['amount'], 50.0);
        expect(values['advance_id'], 123);
        // toOdoo() includes all fields; journal_id is null for advance lines
        expect(values.containsKey('journal_id'), true);
        expect(values['journal_id'], isNull);
      });

      test('should convert credit note line to Odoo values', () {
        final line = PaymentLine(
          id: -11,
          type: PaymentLineType.creditNote,
          date: DateTime(2024, 1, 15),
          amount: 75.0,
          creditNoteId: 456,
        );

        final values = paymentLineManager.toOdoo(line);

        expect(values['date'], '2024-01-15');
        expect(values['amount'], 75.0);
        expect(values['credit_note_id'], 456);
        // toOdoo() includes all fields; journal_id is null for credit note lines
        expect(values.containsKey('journal_id'), true);
        expect(values['journal_id'], isNull);
      });

      test('should include card payment fields', () {
        final line = PaymentLine(
          id: -12,
          type: PaymentLineType.payment,
          date: DateTime(2024, 1, 15),
          amount: 100.0,
          journalId: 1,
          bankId: 10,
          cardType: CardType.credit,
          cardBrandId: 20,
          cardDeadlineId: 30,
          loteId: 40,
          voucherDate: DateTime(2024, 1, 15),
        );

        final values = paymentLineManager.toOdoo(line);

        expect(values['journal_id'], 1);
        expect(values['bank_id'], 10);
        // card_type is @OdooLocalOnly, not included in toOdoo()
        expect(values.containsKey('card_type'), false);
        expect(values['card_brand_id'], 20);
        expect(values['card_deadline_id'], 30);
        expect(values['lote_id'], 40);
        expect(values['bank_reference_date'], '2024-01-15');
      });

      test('should include check payment fields', () {
        final line = PaymentLine(
          id: -13,
          type: PaymentLineType.payment,
          date: DateTime(2024, 1, 15),
          amount: 100.0,
          journalId: 1,
          partnerBankId: 50,
          effectiveDate: DateTime(2024, 2, 15),
        );

        final values = paymentLineManager.toOdoo(line);

        expect(values['journal_id'], 1);
        expect(values['partner_bank_id'], 50);
        expect(values['effective_date'], '2024-02-15');
      });
    });

    group('toString', () {
      test('should return formatted string representation', () {
        final line = PaymentLine(
          id: -14,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 100.0,
          journalName: 'Efectivo',
          journalType: 'cash',
          paymentMethodCode: 'manual',
        );

        final str = line.toString();

        expect(str, contains('PaymentLine'));
        expect(str, contains('payment'));
        expect(str, contains('100'));
      });
    });
  });

  group('AvailableJournal', () {
    test('should parse from Odoo data', () {
      final data = {
        'id': 1,
        'name': 'Efectivo',
        'type': 'cash',
        'payment_method_ids': [
          {'id': 1, 'name': 'Manual', 'code': 'manual'},
          {'id': 2, 'name': 'Tarjeta', 'code': 'card_payment'},
        ],
      };

      final journal = AvailableJournal.fromOdoo(data);

      expect(journal.id, 1);
      expect(journal.name, 'Efectivo');
      expect(journal.type, 'cash');
      expect(journal.isCash, true);
      expect(journal.isBank, false);
      expect(journal.paymentMethods.length, 2);
    });

    test('should handle empty payment methods', () {
      final data = {
        'id': 1,
        'name': 'Banco',
        'type': 'bank',
      };

      final journal = AvailableJournal.fromOdoo(data);

      expect(journal.paymentMethods, isEmpty);
    });
  });

  group('PaymentMethod', () {
    test('should parse from Odoo data', () {
      final data = {
        'id': 1,
        'name': 'Manual',
        'code': 'manual',
      };

      final method = PaymentMethod.fromOdoo(data);

      expect(method.id, 1);
      expect(method.name, 'Manual');
      expect(method.code, 'manual');
      expect(method.isCash, true);
      expect(method.isCard, false);
    });

    test('should detect card payment method', () {
      final method = PaymentMethod(id: 1, name: 'Tarjeta', code: 'card_payment');
      expect(method.isCard, true);
      expect(method.isCash, false);
    });

    test('should detect check payment method', () {
      final method = PaymentMethod(id: 1, name: 'Cheque', code: 'cheque_in');
      expect(method.isCheck, true);
      expect(method.isCash, false);
    });

    test('should detect transfer payment method', () {
      final method = PaymentMethod(id: 1, name: 'Transferencia', code: 'transferencia');
      expect(method.isTransfer, true);
      expect(method.isCash, false);
    });
  });

  group('AvailableAdvance', () {
    test('should parse from Odoo data', () {
      final data = {
        'id': 123,
        'name': 'ANT-001',
        'amount_available': 500.50,
        'date': '2024-01-15',
      };

      final advance = AvailableAdvance.fromOdoo(data);

      expect(advance.id, 123);
      expect(advance.name, 'ANT-001');
      expect(advance.amountAvailable, 500.50);
      expect(advance.date, DateTime(2024, 1, 15));
    });
  });

  group('AvailableCreditNote', () {
    test('should parse from Odoo data', () {
      final data = {
        'id': 456,
        'name': 'NC-001',
        'amount_residual': 250.75,
        'invoice_date': '2024-01-10',
      };

      final creditNote = AvailableCreditNote.fromOdoo(data);

      expect(creditNote.id, 456);
      expect(creditNote.name, 'NC-001');
      expect(creditNote.amountResidual, 250.75);
      expect(creditNote.invoiceDate, DateTime(2024, 1, 10));
    });

    test('should handle null invoice date', () {
      final data = {
        'id': 456,
        'name': 'NC-001',
        'amount_residual': 250.75,
        'invoice_date': null,
      };

      final creditNote = AvailableCreditNote.fromOdoo(data);

      expect(creditNote.invoiceDate, isNull);
    });
  });

  group('CardBrand', () {
    test('should parse from Odoo data', () {
      final data = {
        'id': 1,
        'name': 'Visa',
      };

      final brand = CardBrand.fromOdoo(data);

      expect(brand.id, 1);
      expect(brand.name, 'Visa');
    });
  });

  group('CardDeadline', () {
    test('should parse from Odoo data', () {
      final data = {
        'id': 1,
        'name': 'Corriente',
        'deadline_days': 30,
        'percentage': 5.0,
      };

      final deadline = CardDeadline.fromOdoo(data);

      expect(deadline.id, 1);
      expect(deadline.name, 'Corriente');
      expect(deadline.deadlineDays, 30);
      expect(deadline.percentage, 5.0);
    });

    test('should handle missing deadline_days/percentage', () {
      final data = {
        'id': 1,
        'name': 'Diferido',
      };

      final deadline = CardDeadline.fromOdoo(data);

      expect(deadline.deadlineDays, 0);
      expect(deadline.percentage, 0.0);
    });
  });

  group('CardLote', () {
    test('should parse from Odoo data with list journal_id', () {
      final data = {
        'id': 1,
        'name': 'LOTE-001',
        'journal_id': [5, 'Banco Pichincha'],
      };

      final lote = cardLoteManager.fromOdoo(data);

      expect(lote.id, 1);
      expect(lote.name, 'LOTE-001');
      expect(lote.journalId, 5);
    });

    test('should parse from Odoo data with int journal_id', () {
      final data = {
        'id': 1,
        'name': 'LOTE-001',
        'journal_id': 5,
      };

      final lote = cardLoteManager.fromOdoo(data);

      expect(lote.journalId, 5);
    });
  });
}
