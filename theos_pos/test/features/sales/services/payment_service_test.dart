import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_pos/features/advances/services/advance_service.dart';
import 'package:theos_pos/features/sales/services/payment_service.dart';

// Mock OdooService for testing
class MockOdooService {
  final Map<String, dynamic Function(Map<String, dynamic>)> _handlers = {};

  void when(String model, String method, dynamic Function(Map<String, dynamic>) handler) {
    _handlers['$model:$method'] = handler;
  }

  Future<dynamic> call({
    required String model,
    required String method,
    List<dynamic>? args,
    Map<String, dynamic>? kwargs,
  }) async {
    final key = '$model:$method';
    if (_handlers.containsKey(key)) {
      return _handlers[key]!({'args': args, 'kwargs': kwargs});
    }
    return null;
  }
}

void main() {
  group('PartnerCreditInfo', () {
    test('should calculate hasCreditLimit correctly', () {
      final withLimit = PartnerCreditInfo(
        creditLimit: 1000.0,
        creditUsed: 500.0,
        creditToInvoice: 100.0,
        totalOverdue: 0.0,
        unpaidInvoicesCount: 0,
        creditAvailable: 400.0,
        allowOverCredit: false,
      );

      final withoutLimit = PartnerCreditInfo(
        creditLimit: 0.0,
        creditUsed: 0.0,
        creditToInvoice: 0.0,
        totalOverdue: 0.0,
        unpaidInvoicesCount: 0,
        creditAvailable: 0.0,
        allowOverCredit: false,
      );

      expect(withLimit.hasCreditLimit, true);
      expect(withoutLimit.hasCreditLimit, false);
    });

    test('should calculate isCreditExceeded correctly', () {
      final exceeded = PartnerCreditInfo(
        creditLimit: 1000.0,
        creditUsed: 1200.0,
        creditToInvoice: 100.0,
        totalOverdue: 0.0,
        unpaidInvoicesCount: 0,
        creditAvailable: -300.0,
        allowOverCredit: false,
      );

      final notExceeded = PartnerCreditInfo(
        creditLimit: 1000.0,
        creditUsed: 500.0,
        creditToInvoice: 100.0,
        totalOverdue: 0.0,
        unpaidInvoicesCount: 0,
        creditAvailable: 400.0,
        allowOverCredit: false,
      );

      expect(exceeded.isCreditExceeded, true);
      expect(notExceeded.isCreditExceeded, false);
    });

    test('should calculate hasOverdueDebt correctly', () {
      final withOverdue = PartnerCreditInfo(
        creditLimit: 1000.0,
        creditUsed: 500.0,
        creditToInvoice: 0.0,
        totalOverdue: 200.0,
        unpaidInvoicesCount: 2,
        creditAvailable: 500.0,
        allowOverCredit: false,
      );

      final noOverdue = PartnerCreditInfo(
        creditLimit: 1000.0,
        creditUsed: 500.0,
        creditToInvoice: 0.0,
        totalOverdue: 0.0,
        unpaidInvoicesCount: 0,
        creditAvailable: 500.0,
        allowOverCredit: false,
      );

      expect(withOverdue.hasOverdueDebt, true);
      expect(noOverdue.hasOverdueDebt, false);
    });

    test('should calculate creditUsagePercentage correctly', () {
      final info = PartnerCreditInfo(
        creditLimit: 1000.0,
        creditUsed: 600.0,
        creditToInvoice: 100.0,
        totalOverdue: 0.0,
        unpaidInvoicesCount: 0,
        creditAvailable: 300.0,
        allowOverCredit: false,
      );

      // (600 + 100) / 1000 * 100 = 70%
      expect(info.creditUsagePercentage, 70.0);
    });

    test('should clamp creditUsagePercentage to 999', () {
      final info = PartnerCreditInfo(
        creditLimit: 100.0,
        creditUsed: 5000.0,
        creditToInvoice: 5000.0,
        totalOverdue: 0.0,
        unpaidInvoicesCount: 0,
        creditAvailable: -9900.0,
        allowOverCredit: false,
      );

      expect(info.creditUsagePercentage, 999.0);
    });

    test('should return 0 creditUsagePercentage when no limit', () {
      final info = PartnerCreditInfo(
        creditLimit: 0.0,
        creditUsed: 500.0,
        creditToInvoice: 0.0,
        totalOverdue: 0.0,
        unpaidInvoicesCount: 0,
        creditAvailable: 0.0,
        allowOverCredit: false,
      );

      expect(info.creditUsagePercentage, 0.0);
    });
  });

  group('WithholdingType', () {
    test('should format displayName correctly', () {
      final type = WithholdingType(
        id: 1,
        name: 'Retención IVA 30%',
        percentage: 30.0,
        code: '1',
      );

      expect(type.displayName, 'Retención IVA 30% (30.0%)');
    });
  });

  group('WithholdingLine', () {
    test('should create withholding line', () {
      final line = WithholdingLine(
        taxId: 1,
        base: 100.0,
        amount: 30.0,
      );

      expect(line.taxId, 1);
      expect(line.base, 100.0);
      expect(line.amount, 30.0);
    });
  });

  group('AdvanceResult', () {
    test('should create success result', () {
      final result = AdvanceResult(
        success: true,
        advanceId: 123,
        advanceName: 'ANT-001',
        amount: 500.0,
      );

      expect(result.success, true);
      expect(result.advanceId, 123);
      expect(result.advanceName, 'ANT-001');
      expect(result.amount, 500.0);
      expect(result.errorMessage, isNull);
    });

    test('should create failure result', () {
      final result = AdvanceResult(
        success: false,
        errorMessage: 'Error creating advance',
      );

      expect(result.success, false);
      expect(result.errorMessage, 'Error creating advance');
      expect(result.advanceId, isNull);
    });
  });

  group('WithholdingResult', () {
    test('should create success result', () {
      final result = WithholdingResult(
        success: true,
        withholdId: 456,
        withholdName: 'RET-001',
      );

      expect(result.success, true);
      expect(result.withholdId, 456);
      expect(result.withholdName, 'RET-001');
      expect(result.errorMessage, isNull);
    });

    test('should create failure result', () {
      final result = WithholdingResult(
        success: false,
        errorMessage: 'Error registering withholding',
      );

      expect(result.success, false);
      expect(result.errorMessage, 'Error registering withholding');
      expect(result.withholdId, isNull);
    });
  });

  group('CreditApprovalResult', () {
    test('should create success result', () {
      final result = CreditApprovalResult(
        success: true,
        approvalId: 789,
        approvalName: 'APR-001',
      );

      expect(result.success, true);
      expect(result.approvalId, 789);
      expect(result.approvalName, 'APR-001');
      expect(result.errorMessage, isNull);
    });

    test('should create failure result', () {
      final result = CreditApprovalResult(
        success: false,
        errorMessage: 'Error requesting approval',
      );

      expect(result.success, false);
      expect(result.errorMessage, 'Error requesting approval');
      expect(result.approvalId, isNull);
    });
  });

  group('CreditAuthorizationType', () {
    test('should have correct enum values', () {
      expect(CreditAuthorizationType.values.length, 3);
      expect(CreditAuthorizationType.overdueDebt.name, 'overdueDebt');
      expect(CreditAuthorizationType.creditLimitExceeded.name, 'creditLimitExceeded');
      expect(CreditAuthorizationType.temporaryCredit.name, 'temporaryCredit');
    });
  });

  group('AvailableBank', () {
    test('should parse from Odoo data', () {
      final data = {
        'id': 1,
        'name': 'Banco Pichincha',
      };

      final bank = AvailableBank.fromOdoo(data);

      expect(bank.id, 1);
      expect(bank.name, 'Banco Pichincha');
    });
  });

  group('PaymentLine validation', () {
    test('should validate advance amount does not exceed available', () {
      final advance = AvailableAdvance(
        id: 1,
        name: 'ANT-001',
        amountAvailable: 100.0,
        date: DateTime.now(),
      );

      const requestedAmount = 150.0;
      final isValid = requestedAmount <= advance.amountAvailable;

      expect(isValid, false);
    });

    test('should validate credit note amount does not exceed residual', () {
      final creditNote = AvailableCreditNote(
        id: 1,
        name: 'NC-001',
        amountResidual: 200.0,
        invoiceDate: DateTime.now(),
      );

      const requestedAmount = 150.0;
      final isValid = requestedAmount <= creditNote.amountResidual;

      expect(isValid, true);
    });
  });

  group('PaymentLine collection operations', () {
    test('should calculate total paid amount', () {
      final lines = [
        PaymentLine(
          id: -1,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 100.0,
        ),
        PaymentLine(
          id: -2,
          type: PaymentLineType.advance,
          date: DateTime.now(),
          amount: 50.0,
        ),
        PaymentLine(
          id: -3,
          type: PaymentLineType.creditNote,
          date: DateTime.now(),
          amount: 25.0,
        ),
      ];

      final totalPaid = lines.fold(0.0, (sum, line) => sum + line.amount);

      expect(totalPaid, 175.0);
    });

    test('should calculate pending amount', () {
      const orderTotal = 200.0;
      final lines = [
        PaymentLine(
          id: -1,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 100.0,
        ),
        PaymentLine(
          id: -2,
          type: PaymentLineType.advance,
          date: DateTime.now(),
          amount: 30.0,
        ),
      ];

      final totalPaid = lines.fold(0.0, (sum, line) => sum + line.amount);
      final pendingAmount = orderTotal - totalPaid;

      expect(pendingAmount, 70.0);
    });

    test('should detect overpayment', () {
      const orderTotal = 100.0;
      final lines = [
        PaymentLine(
          id: -1,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 120.0,
        ),
      ];

      final totalPaid = lines.fold(0.0, (sum, line) => sum + line.amount);
      final overpayment = totalPaid - orderTotal;

      expect(overpayment, 20.0);
      expect(overpayment > 0, true);
    });

    test('should filter lines by type', () {
      final lines = [
        PaymentLine(
          id: -1,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 100.0,
        ),
        PaymentLine(
          id: -2,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 50.0,
        ),
        PaymentLine(
          id: -3,
          type: PaymentLineType.advance,
          date: DateTime.now(),
          amount: 25.0,
        ),
      ];

      final paymentLines = lines.where((l) => l.type == PaymentLineType.payment).toList();
      final advanceLines = lines.where((l) => l.type == PaymentLineType.advance).toList();

      expect(paymentLines.length, 2);
      expect(advanceLines.length, 1);
    });

    test('should find non-cash payment for advance creation', () {
      final lines = [
        PaymentLine(
          id: -1,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 50.0,
          journalType: 'cash',
        ),
        PaymentLine(
          id: -2,
          type: PaymentLineType.payment,
          date: DateTime.now(),
          amount: 100.0,
          journalType: 'bank',
          journalId: 5,
        ),
      ];

      final nonCashPayment = lines.firstWhere(
        (l) => l.journalType != 'cash',
        orElse: () => lines.first,
      );

      expect(nonCashPayment.journalType, 'bank');
      expect(nonCashPayment.journalId, 5);
    });
  });

  group('Edge cases', () {
    test('should handle zero amount payment line', () {
      final line = PaymentLine(
        id: -1,
        type: PaymentLineType.payment,
        date: DateTime.now(),
        amount: 0.0,
      );

      expect(line.amount, 0.0);
    });

    test('should handle very large amounts', () {
      final line = PaymentLine(
        id: -1,
        type: PaymentLineType.payment,
        date: DateTime.now(),
        amount: 999999999.99,
      );

      expect(line.amount, 999999999.99);
    });

    test('should handle negative credit available', () {
      final info = PartnerCreditInfo(
        creditLimit: 1000.0,
        creditUsed: 1500.0,
        creditToInvoice: 200.0,
        totalOverdue: 0.0,
        unpaidInvoicesCount: 0,
        creditAvailable: -700.0,
        allowOverCredit: false,
      );

      expect(info.isCreditExceeded, true);
      expect(info.creditAvailable, -700.0);
    });
  });
}
