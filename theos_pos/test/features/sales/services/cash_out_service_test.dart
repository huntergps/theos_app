import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_pos/features/sales/services/cash_out_service.dart';

/// Tests for CashOutService pure business logic:
/// - CashOutResult data class
/// - SessionCashSummary data class & computed fields
/// - ExpenseAccount.fromOdoo and displayName
/// - CashOutType.fromOdoo, fromCode, predefined constants
/// - PendingWithhold.fromOdoo
/// - PendingCreditNote.fromOdoo
/// - PendingInvoice.fromOdoo
/// - CashOut model validation and computed fields
void main() {
  // ============================================================
  // CashOutResult
  // ============================================================
  group('CashOutResult', () {
    test('should create a successful result', () {
      final result = CashOutResult(
        success: true,
        cashOutId: 42,
        cashOutName: 'RET/2024/001',
        amount: 150.0,
      );

      expect(result.success, isTrue);
      expect(result.cashOutId, 42);
      expect(result.cashOutName, 'RET/2024/001');
      expect(result.amount, closeTo(150.0, 0.001));
      expect(result.errorMessage, isNull);
    });

    test('should create a failure result with error message', () {
      final result = CashOutResult(
        success: false,
        errorMessage: 'Saldo insuficiente en caja',
      );

      expect(result.success, isFalse);
      expect(result.cashOutId, isNull);
      expect(result.cashOutName, isNull);
      expect(result.amount, isNull);
      expect(result.errorMessage, 'Saldo insuficiente en caja');
    });

    test('should create a failure result with partial data', () {
      final result = CashOutResult(
        success: false,
        cashOutId: 10,
        errorMessage: 'Error confirming',
      );

      expect(result.success, isFalse);
      expect(result.cashOutId, 10);
      expect(result.errorMessage, 'Error confirming');
    });
  });

  // ============================================================
  // SessionCashSummary
  // ============================================================
  group('SessionCashSummary', () {
    test('should store all fields correctly', () {
      final summary = SessionCashSummary(
        balanceStart: 500.0,
        balanceEnd: 1200.0,
        balanceEndReal: 1190.0,
        difference: -10.0,
        totalCashOutAmount: 300.0,
        cashOutCount: 3,
      );

      expect(summary.balanceStart, closeTo(500.0, 0.001));
      expect(summary.balanceEnd, closeTo(1200.0, 0.001));
      expect(summary.balanceEndReal, closeTo(1190.0, 0.001));
      expect(summary.difference, closeTo(-10.0, 0.001));
      expect(summary.totalCashOutAmount, closeTo(300.0, 0.001));
      expect(summary.cashOutCount, 3);
    });

    test('availableCash should return balanceEnd', () {
      final summary = SessionCashSummary(
        balanceStart: 100.0,
        balanceEnd: 750.50,
        balanceEndReal: 750.0,
        difference: -0.50,
        totalCashOutAmount: 0.0,
        cashOutCount: 0,
      );

      expect(summary.availableCash, closeTo(750.50, 0.001));
    });

    test('should handle zero values', () {
      final summary = SessionCashSummary(
        balanceStart: 0.0,
        balanceEnd: 0.0,
        balanceEndReal: 0.0,
        difference: 0.0,
        totalCashOutAmount: 0.0,
        cashOutCount: 0,
      );

      expect(summary.availableCash, closeTo(0.0, 0.001));
      expect(summary.cashOutCount, 0);
    });
  });

  // ============================================================
  // ExpenseAccount
  // ============================================================
  group('ExpenseAccount', () {
    test('fromOdoo should parse correctly', () {
      final account = ExpenseAccount.fromOdoo({
        'id': 55,
        'code': '6.1.01.001',
        'name': 'Gastos de Oficina',
      });

      expect(account.id, 55);
      expect(account.code, '6.1.01.001');
      expect(account.name, 'Gastos de Oficina');
    });

    test('displayName should combine code and name', () {
      final account = ExpenseAccount(
        id: 1,
        code: '5.1.02',
        name: 'Materiales',
      );

      expect(account.displayName, '5.1.02 - Materiales');
    });
  });

  // ============================================================
  // CashOutType
  // ============================================================
  group('CashOutType', () {
    group('predefined constants', () {
      test('expense type should have correct code', () {
        expect(CashOutType.expense.code, 'expense');
        expect(CashOutType.expense.requiresPartner, isFalse);
        expect(CashOutType.expense.requiresLines, isFalse);
        expect(CashOutType.expense.createsSecurity, isFalse);
      });

      test('withhold type should require partner and lines', () {
        expect(CashOutType.withhold.code, 'withhold');
        expect(CashOutType.withhold.requiresPartner, isTrue);
        expect(CashOutType.withhold.requiresLines, isTrue);
      });

      test('refund type should require partner and lines', () {
        expect(CashOutType.refund.code, 'refund');
        expect(CashOutType.refund.requiresPartner, isTrue);
        expect(CashOutType.refund.requiresLines, isTrue);
      });

      test('security type should create security deposit', () {
        expect(CashOutType.security.code, 'security');
        expect(CashOutType.security.createsSecurity, isTrue);
      });

      test('invoice type should require partner and lines', () {
        expect(CashOutType.invoice.code, 'invoice');
        expect(CashOutType.invoice.requiresPartner, isTrue);
        expect(CashOutType.invoice.requiresLines, isTrue);
      });

      test('predefined list should contain all types', () {
        expect(CashOutType.predefined.length, 8);
        final codes =
            CashOutType.predefined.map((t) => t.code).toSet();
        expect(codes, containsAll([
          'expense', 'withhold', 'refund', 'commission',
          'invoice', 'general', 'security', 'other',
        ]));
      });
    });

    group('fromCode', () {
      test('should return matching predefined type', () {
        final type = CashOutType.fromCode('security');
        expect(type.code, 'security');
        expect(type.name, 'Retiro de Seguridad');
        expect(type.createsSecurity, isTrue);
      });

      test('should return "other" for null code', () {
        final type = CashOutType.fromCode(null);
        expect(type.code, 'other');
      });

      test('should return "other" for empty code', () {
        final type = CashOutType.fromCode('');
        expect(type.code, 'other');
      });

      test('should create custom type for unknown code', () {
        final type = CashOutType.fromCode('custom_xyz');
        expect(type.code, 'custom_xyz');
        expect(type.name, 'custom_xyz');
        expect(type.id, 0);
      });
    });

    group('fromOdoo', () {
      test('should parse Odoo data correctly', () {
        final type = CashOutType.fromOdoo({
          'id': 5,
          'name': 'Retiro de Seguridad',
          'code': 'security',
          'default_cash_flow': 'out',
        });

        expect(type.id, 5);
        expect(type.name, 'Retiro de Seguridad');
        expect(type.code, 'security');
        expect(type.defaultCashFlow, CashFlow.out);
        expect(type.createsSecurity, isTrue);
      });

      test('should set requiresPartner for withhold code', () {
        final type = CashOutType.fromOdoo({
          'id': 2,
          'name': 'Retencion',
          'code': 'withhold',
          'default_cash_flow': 'out',
        });

        expect(type.requiresPartner, isTrue);
        expect(type.requiresLines, isTrue);
      });

      test('should set requiresPartner for invoice code', () {
        final type = CashOutType.fromOdoo({
          'id': 3,
          'name': 'Factura',
          'code': 'invoice',
          'default_cash_flow': 'out',
        });

        expect(type.requiresPartner, isTrue);
        expect(type.requiresLines, isTrue);
      });

      test('should handle missing code gracefully', () {
        final type = CashOutType.fromOdoo({
          'id': 10,
          'name': 'Unknown',
        });

        expect(type.id, 10);
        expect(type.name, 'Unknown');
        expect(type.code, '');
        expect(type.requiresPartner, isFalse);
      });
    });
  });

  // ============================================================
  // CashOut model — validation & computed fields
  // ============================================================
  group('CashOut model', () {
    CashOut createTestCashOut({
      double amount = 100.0,
      int journalId = 1,
      CashOutState state = CashOutState.draft,
      CashFlow cashFlow = CashFlow.out,
      int? partnerId,
      String typeCode = 'expense',
      int? typeId,
      String? typeName,
      int? moveId,
    }) {
      return CashOut(
        date: DateTime(2024, 1, 15),
        amount: amount,
        journalId: journalId,
        state: state,
        cashFlow: cashFlow,
        partnerId: partnerId,
        typeCode: typeCode,
        typeId: typeId,
        typeName: typeName,
        moveId: moveId,
      );
    }

    group('validate()', () {
      test('should return no errors for valid cash out', () {
        final cashOut = createTestCashOut(amount: 100.0, journalId: 5);
        final errors = cashOut.validate();
        expect(errors, isEmpty);
      });

      test('should return error when amount is zero', () {
        final cashOut = createTestCashOut(amount: 0.0);
        final errors = cashOut.validate();
        expect(errors, containsPair('amount', 'El monto debe ser mayor a cero'));
      });

      test('should return error when amount is negative', () {
        final cashOut = createTestCashOut(amount: -50.0);
        final errors = cashOut.validate();
        expect(errors.containsKey('amount'), isTrue);
      });

      test('should return error when journalId is zero', () {
        final cashOut = createTestCashOut(journalId: 0);
        final errors = cashOut.validate();
        expect(errors, containsPair('journal', 'El diario es requerido'));
      });

      test('should return error when journalId is negative', () {
        final cashOut = createTestCashOut(journalId: -1);
        final errors = cashOut.validate();
        expect(errors.containsKey('journal'), isTrue);
      });

      test('should return multiple errors', () {
        final cashOut = createTestCashOut(amount: 0.0, journalId: 0);
        final errors = cashOut.validate();
        expect(errors.length, 2);
        expect(errors.containsKey('amount'), isTrue);
        expect(errors.containsKey('journal'), isTrue);
      });
    });

    group('validateFor()', () {
      test('post action should fail when state is not draft', () {
        final cashOut = createTestCashOut(state: CashOutState.posted);
        final errors = cashOut.validateFor('post');
        expect(errors.containsKey('state'), isTrue);
      });

      test('post action should succeed for valid draft cash out', () {
        final cashOut = createTestCashOut(
          amount: 100.0,
          journalId: 5,
          state: CashOutState.draft,
        );
        final errors = cashOut.validateFor('post');
        expect(errors, isEmpty);
      });

      test('post action should require partner for withhold type', () {
        final cashOut = createTestCashOut(
          typeCode: 'withhold',
          partnerId: null,
        );
        final errors = cashOut.validateFor('post');
        expect(errors.containsKey('partnerId'), isTrue);
      });

      test('post action should accept partner for withhold type', () {
        final cashOut = createTestCashOut(
          typeCode: 'withhold',
          partnerId: 10,
        );
        final errors = cashOut.validateFor('post');
        expect(errors.containsKey('partnerId'), isFalse);
      });

      test('cancel action should fail when state is draft', () {
        final cashOut = createTestCashOut(state: CashOutState.draft);
        final errors = cashOut.validateFor('cancel');
        expect(errors.containsKey('state'), isTrue);
      });

      test('cancel action should succeed when state is posted', () {
        final cashOut = createTestCashOut(state: CashOutState.posted);
        final errors = cashOut.validateFor('cancel');
        // Note: base validate() will pass (amount > 0, journalId > 0)
        // and cancel validation only checks canCancel (= isPosted)
        expect(errors.containsKey('state'), isFalse);
      });

      test('draft action should fail when state is not cancelled', () {
        final cashOut = createTestCashOut(state: CashOutState.posted);
        final errors = cashOut.validateFor('draft');
        expect(errors.containsKey('state'), isTrue);
      });

      test('draft action should succeed when state is cancelled', () {
        final cashOut = createTestCashOut(state: CashOutState.cancelled);
        final errors = cashOut.validateFor('draft');
        expect(errors.containsKey('state'), isFalse);
      });
    });

    group('computed fields', () {
      test('isPosted should be true only for posted state', () {
        expect(createTestCashOut(state: CashOutState.posted).isPosted, isTrue);
        expect(createTestCashOut(state: CashOutState.draft).isPosted, isFalse);
        expect(createTestCashOut(state: CashOutState.cancelled).isPosted, isFalse);
      });

      test('isDraft should be true only for draft state', () {
        expect(createTestCashOut(state: CashOutState.draft).isDraft, isTrue);
        expect(createTestCashOut(state: CashOutState.posted).isDraft, isFalse);
      });

      test('isCancelled should be true only for cancelled state', () {
        expect(createTestCashOut(state: CashOutState.cancelled).isCancelled, isTrue);
        expect(createTestCashOut(state: CashOutState.draft).isCancelled, isFalse);
      });

      test('canEdit should be true only for draft state', () {
        expect(createTestCashOut(state: CashOutState.draft).canEdit, isTrue);
        expect(createTestCashOut(state: CashOutState.posted).canEdit, isFalse);
      });

      test('canPost requires draft state, positive amount, and valid journal', () {
        expect(
          createTestCashOut(state: CashOutState.draft, amount: 100.0, journalId: 5).canPost,
          isTrue,
        );
        expect(
          createTestCashOut(state: CashOutState.posted, amount: 100.0, journalId: 5).canPost,
          isFalse,
        );
        expect(
          createTestCashOut(state: CashOutState.draft, amount: 0.0, journalId: 5).canPost,
          isFalse,
        );
        expect(
          createTestCashOut(state: CashOutState.draft, amount: 100.0, journalId: 0).canPost,
          isFalse,
        );
      });

      test('canCancel should be true only for posted state', () {
        expect(createTestCashOut(state: CashOutState.posted).canCancel, isTrue);
        expect(createTestCashOut(state: CashOutState.draft).canCancel, isFalse);
      });

      test('isOutflow and isInflow', () {
        expect(createTestCashOut(cashFlow: CashFlow.out).isOutflow, isTrue);
        expect(createTestCashOut(cashFlow: CashFlow.out).isInflow, isFalse);
        expect(createTestCashOut(cashFlow: CashFlow.inFlow).isInflow, isTrue);
        expect(createTestCashOut(cashFlow: CashFlow.inFlow).isOutflow, isFalse);
      });

      test('hasMove should be true when moveId is set and positive', () {
        expect(createTestCashOut(moveId: 10).hasMove, isTrue);
        expect(createTestCashOut(moveId: null).hasMove, isFalse);
        expect(createTestCashOut(moveId: 0).hasMove, isFalse);
        expect(createTestCashOut(moveId: -1).hasMove, isFalse);
      });

      test('type computed field with typeId', () {
        final cashOut = createTestCashOut(
          typeCode: 'security',
          typeId: 5,
          typeName: 'Seguridad Custom',
        );
        expect(cashOut.type.id, 5);
        expect(cashOut.type.name, 'Seguridad Custom');
        expect(cashOut.type.code, 'security');
      });

      test('type computed field without typeId falls back to fromCode', () {
        final cashOut = createTestCashOut(typeCode: 'expense');
        expect(cashOut.type.code, 'expense');
        expect(cashOut.type.name, 'Gasto');
      });
    });

    group('onTypeChanged', () {
      test('should update type fields and cash flow', () {
        final cashOut = createTestCashOut(typeCode: 'expense');
        final newType = CashOutType(
          id: 7,
          name: 'Retiro Seguridad',
          code: 'security',
          defaultCashFlow: CashFlow.out,
        );

        final updated = cashOut.onTypeChanged(newType);
        expect(updated.typeCode, 'security');
        expect(updated.typeId, 7);
        expect(updated.typeName, 'Retiro Seguridad');
        expect(updated.cashFlow, CashFlow.out);
      });
    });
  });

  // ============================================================
  // CashOutState enum
  // ============================================================
  group('CashOutState', () {
    test('fromCode should parse known states', () {
      expect(CashOutState.fromCode('draft'), CashOutState.draft);
      expect(CashOutState.fromCode('posted'), CashOutState.posted);
      expect(CashOutState.fromCode('cancelled'), CashOutState.cancelled);
    });

    test('fromCode should handle "cancel" as cancelled', () {
      expect(CashOutState.fromCode('cancel'), CashOutState.cancelled);
    });

    test('fromCode should default to draft for null', () {
      expect(CashOutState.fromCode(null), CashOutState.draft);
    });

    test('fromCode should default to draft for unknown code', () {
      expect(CashOutState.fromCode('unknown'), CashOutState.draft);
    });
  });

  // ============================================================
  // CashFlow enum
  // ============================================================
  group('CashFlow', () {
    test('fromCode should parse known flows', () {
      expect(CashFlow.fromCode('out'), CashFlow.out);
      expect(CashFlow.fromCode('in'), CashFlow.inFlow);
    });

    test('fromCode should default to out for null', () {
      expect(CashFlow.fromCode(null), CashFlow.out);
    });

    test('fromCode should default to out for unknown code', () {
      expect(CashFlow.fromCode('unknown'), CashFlow.out);
    });
  });

  // ============================================================
  // PendingWithhold.fromOdoo
  // ============================================================
  group('PendingWithhold.fromOdoo', () {
    test('should parse with List partner_id', () {
      final pw = PendingWithhold.fromOdoo({
        'id': 100,
        'name': 'RET/2024/0001',
        'amount_residual': 45.50,
        'date': '2024-06-15',
        'partner_id': [10, 'Acme Corp'],
      });

      expect(pw.id, 100);
      expect(pw.name, 'RET/2024/0001');
      expect(pw.amountPending, closeTo(45.50, 0.001));
      expect(pw.partnerId, 10);
      expect(pw.partnerName, 'Acme Corp');
    });

    test('should parse with int partner_id', () {
      final pw = PendingWithhold.fromOdoo({
        'id': 101,
        'name': 'RET/2024/0002',
        'amount_residual': 100.0,
        'date': '2024-07-20',
        'partner_id': 15,
      });

      expect(pw.partnerId, 15);
      expect(pw.partnerName, isNull);
    });

    test('should handle null amount_residual', () {
      final pw = PendingWithhold.fromOdoo({
        'id': 102,
        'name': 'RET/2024/0003',
        'amount_residual': null,
        'date': '2024-01-01',
        'partner_id': [1, 'Test'],
      });

      expect(pw.amountPending, closeTo(0.0, 0.001));
    });
  });

  // ============================================================
  // PendingCreditNote.fromOdoo
  // ============================================================
  group('PendingCreditNote.fromOdoo', () {
    test('should parse with List partner_id', () {
      final cn = PendingCreditNote.fromOdoo({
        'id': 200,
        'name': 'NC/2024/0001',
        'amount_residual': 200.0,
        'invoice_date': '2024-03-10',
        'partner_id': [20, 'Partner X'],
      });

      expect(cn.id, 200);
      expect(cn.name, 'NC/2024/0001');
      expect(cn.amountResidual, closeTo(200.0, 0.001));
      expect(cn.invoiceDate, DateTime.parse('2024-03-10'));
      expect(cn.partnerId, 20);
      expect(cn.partnerName, 'Partner X');
    });

    test('should handle null invoice_date', () {
      final cn = PendingCreditNote.fromOdoo({
        'id': 201,
        'name': 'NC/2024/0002',
        'amount_residual': 50.0,
        'invoice_date': null,
        'partner_id': [1, 'Test'],
      });

      expect(cn.invoiceDate, isNull);
    });
  });

  // ============================================================
  // PendingInvoice.fromOdoo
  // ============================================================
  group('PendingInvoice.fromOdoo', () {
    test('should parse with all fields', () {
      final inv = PendingInvoice.fromOdoo({
        'id': 300,
        'name': 'FACT/2024/0001',
        'amount_residual': 500.0,
        'invoice_date': '2024-02-01',
        'invoice_date_due': '2024-03-01',
        'partner_id': [30, 'Supplier Z'],
      });

      expect(inv.id, 300);
      expect(inv.name, 'FACT/2024/0001');
      expect(inv.amountResidual, closeTo(500.0, 0.001));
      expect(inv.invoiceDate, DateTime.parse('2024-02-01'));
      expect(inv.invoiceDateDue, DateTime.parse('2024-03-01'));
      expect(inv.partnerId, 30);
      expect(inv.partnerName, 'Supplier Z');
    });

    test('should handle null dates', () {
      final inv = PendingInvoice.fromOdoo({
        'id': 301,
        'name': 'FACT/2024/0002',
        'amount_residual': 75.0,
        'invoice_date': null,
        'invoice_date_due': null,
        'partner_id': [1, 'Test'],
      });

      expect(inv.invoiceDate, isNull);
      expect(inv.invoiceDateDue, isNull);
    });

    test('should handle int partner_id', () {
      final inv = PendingInvoice.fromOdoo({
        'id': 302,
        'name': 'FACT/2024/0003',
        'amount_residual': 10.0,
        'invoice_date': '2024-01-01',
        'invoice_date_due': '2024-02-01',
        'partner_id': 99,
      });

      expect(inv.partnerId, 99);
      expect(inv.partnerName, isNull);
    });
  });

  // ============================================================
  // CashOut.createLocal factory
  // ============================================================
  group('CashOut.createLocal', () {
    test('should create a local cash out with all fields', () {
      final type = CashOutType(
        id: 3,
        name: 'Test Type',
        code: 'test',
      );

      final cashOut = CashOut.createLocal(
        date: DateTime(2024, 6, 15),
        journalId: 10,
        amount: 250.0,
        type: type,
        partnerId: 5,
        partnerName: 'Partner',
        note: 'Test note',
        collectionSessionId: 7,
      );

      expect(cashOut.date, DateTime(2024, 6, 15));
      expect(cashOut.journalId, 10);
      expect(cashOut.amount, closeTo(250.0, 0.001));
      expect(cashOut.typeCode, 'test');
      expect(cashOut.typeId, 3);
      expect(cashOut.typeName, 'Test Type');
      expect(cashOut.partnerId, 5);
      expect(cashOut.partnerName, 'Partner');
      expect(cashOut.note, 'Test note');
      expect(cashOut.collectionSessionId, 7);
      expect(cashOut.uuid, isNotNull);
      expect(cashOut.uuid, isNotEmpty);
      expect(cashOut.isSynced, isFalse);
      expect(cashOut.state, CashOutState.draft);
    });

    test('should generate unique UUIDs', () {
      final type = CashOutType.expense;
      final a = CashOut.createLocal(date: DateTime.now(), journalId: 1, amount: 10, type: type);
      final b = CashOut.createLocal(date: DateTime.now(), journalId: 1, amount: 10, type: type);

      expect(a.uuid, isNot(equals(b.uuid)));
    });
  });

  // ============================================================
  // CashOutLine
  // ============================================================
  group('CashOutLine', () {
    test('fromOdoo should parse with List document field', () {
      final line = CashOutLine.fromOdoo({
        'id': 1,
        'withhold_id': [50, 'RET/001'],
        'reconcile_amount': 100.0,
        'amount_available': 200.0,
      }, 'withhold_id');

      expect(line.id, 1);
      expect(line.documentId, 50);
      expect(line.documentName, 'RET/001');
      expect(line.reconcileAmount, closeTo(100.0, 0.001));
      expect(line.amountAvailable, closeTo(200.0, 0.001));
    });

    test('fromOdoo should parse with int document field', () {
      final line = CashOutLine.fromOdoo({
        'id': 2,
        'invoice_id': 75,
        'reconcile_amount': 50.0,
      }, 'invoice_id');

      expect(line.documentId, 75);
      expect(line.documentName, isNull);
    });

    test('copyWith should preserve unchanged fields', () {
      final line = CashOutLine(
        id: 1,
        documentId: 10,
        documentName: 'DOC/001',
        reconcileAmount: 100.0,
        amountAvailable: 500.0,
      );

      final updated = line.copyWith(reconcileAmount: 200.0);
      expect(updated.documentId, 10);
      expect(updated.documentName, 'DOC/001');
      expect(updated.reconcileAmount, closeTo(200.0, 0.001));
      expect(updated.amountAvailable, closeTo(500.0, 0.001));
    });

    test('toOdooValues should return reconcile_amount', () {
      final line = CashOutLine(
        documentId: 10,
        reconcileAmount: 123.45,
      );

      final vals = line.toOdooValues();
      expect(vals['reconcile_amount'], closeTo(123.45, 0.001));
    });

    test('should generate UUID if not provided', () {
      final line = CashOutLine(documentId: 1, reconcileAmount: 10.0);
      expect(line.uuid, isNotEmpty);
    });
  });
}
