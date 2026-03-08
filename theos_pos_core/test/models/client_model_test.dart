import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/clients/client.model.dart';

void main() {
  group('Client - VAT Validation (Ecuador)', () {
    test('valid cédula (10 digits, mod10) passes validation', () {
      // Known valid CI: 1710034065
      const client = Client(id: 1, name: 'Test', vat: '1710034065');
      final errors = client.validate();
      expect(errors.containsKey('vat'), isFalse, reason: errors['vat'] ?? '');
    });

    test('invalid cédula fails validation', () {
      const client = Client(id: 1, name: 'Test', vat: '1234567890');
      final errors = client.validate();
      expect(errors.containsKey('vat'), isTrue);
    });

    test('valid RUC natural person (13 digits) passes validation', () {
      // RUC is CI + "001"
      const client = Client(id: 1, name: 'Test', vat: '1710034065001');
      final errors = client.validate();
      expect(errors.containsKey('vat'), isFalse, reason: errors['vat'] ?? '');
    });

    test('consumidor final VAT is valid', () {
      const client = Client(id: 1, name: 'CF', vat: '9999999999999');
      final errors = client.validate();
      expect(errors.containsKey('vat'), isFalse);
    });

    test('consumidor final 10-digit is valid', () {
      const client = Client(id: 1, name: 'CF', vat: '9999999999');
      final errors = client.validate();
      expect(errors.containsKey('vat'), isFalse);
    });

    test('VAT with wrong length fails', () {
      const client = Client(id: 1, name: 'Test', vat: '12345');
      final errors = client.validate();
      expect(errors.containsKey('vat'), isTrue);
      expect(errors['vat'], contains('10'));
    });

    test('empty VAT passes validation (optional field)', () {
      const client = Client(id: 1, name: 'Test', vat: '');
      final errors = client.validate();
      expect(errors.containsKey('vat'), isFalse);
    });

    test('null VAT passes validation (optional field)', () {
      const client = Client(id: 1, name: 'Test');
      final errors = client.validate();
      expect(errors.containsKey('vat'), isFalse);
    });

    test('province code > 24 is invalid', () {
      const client = Client(id: 1, name: 'Test', vat: '2510034065');
      final errors = client.validate();
      expect(errors.containsKey('vat'), isTrue);
    });

    test('province code 00 is invalid', () {
      const client = Client(id: 1, name: 'Test', vat: '0010034065');
      final errors = client.validate();
      expect(errors.containsKey('vat'), isTrue);
    });
  });

  group('Client - Credit Computed Fields', () {
    test('creditAvailable returns null when no credit limit', () {
      const client = Client(
        id: 1,
        name: 'Test',
        usePartnerCreditLimit: false,
      );
      expect(client.creditAvailable, isNull);
    });

    test('creditAvailable calculates correctly', () {
      const client = Client(
        id: 1,
        name: 'Test',
        usePartnerCreditLimit: true,
        creditLimit: 1000.0,
        credit: 300.0,
        creditToInvoice: 200.0,
      );
      expect(client.creditAvailable, equals(500.0));
    });

    test('creditAvailable is negative when exceeded', () {
      const client = Client(
        id: 1,
        name: 'Test',
        usePartnerCreditLimit: true,
        creditLimit: 500.0,
        credit: 400.0,
        creditToInvoice: 200.0,
      );
      expect(client.creditAvailable, equals(-100.0));
      expect(client.creditExceeded, isTrue);
    });

    test('creditUsagePercentage calculates correctly', () {
      const client = Client(
        id: 1,
        name: 'Test',
        usePartnerCreditLimit: true,
        creditLimit: 1000.0,
        credit: 500.0,
        creditToInvoice: 0.0,
      );
      expect(client.creditUsagePercentage, equals(50.0));
    });

    test('creditUsagePercentage returns null without limit', () {
      const client = Client(id: 1, name: 'Test');
      expect(client.creditUsagePercentage, isNull);
    });

    test('creditStatus is noLimit when no credit limit', () {
      const client = Client(id: 1, name: 'Test');
      expect(client.creditStatus, equals(CreditStatus.noLimit));
    });

    test('creditStatus is ok when usage < 80%', () {
      const client = Client(
        id: 1,
        name: 'Test',
        usePartnerCreditLimit: true,
        creditLimit: 1000.0,
        credit: 500.0,
        creditToInvoice: 0.0,
      );
      expect(client.creditStatus, equals(CreditStatus.ok));
    });

    test('creditStatus is warning when usage >= 80%', () {
      const client = Client(
        id: 1,
        name: 'Test',
        usePartnerCreditLimit: true,
        creditLimit: 1000.0,
        credit: 800.0,
        creditToInvoice: 0.0,
      );
      expect(client.creditStatus, equals(CreditStatus.warning));
    });

    test('creditStatus is exceeded when over limit', () {
      const client = Client(
        id: 1,
        name: 'Test',
        usePartnerCreditLimit: true,
        creditLimit: 1000.0,
        credit: 1100.0,
        creditToInvoice: 0.0,
      );
      expect(client.creditStatus, equals(CreditStatus.exceeded));
    });

    test('creditStatus is overdueDebt when has overdue', () {
      const client = Client(
        id: 1,
        name: 'Test',
        usePartnerCreditLimit: true,
        creditLimit: 1000.0,
        credit: 200.0,
        totalOverdue: 500.0,
      );
      expect(client.creditStatus, equals(CreditStatus.overdueDebt));
    });
  });

  group('Client - Factory Methods', () {
    test('newCustomer creates unsaved client with id 0', () {
      final client = Client.newCustomer(name: 'Nuevo Cliente', vat: '1710034065');
      expect(client.id, equals(0));
      expect(client.name, equals('Nuevo Cliente'));
      expect(client.vat, equals('1710034065'));
      expect(client.isSynced, isFalse);
      expect(client.active, isTrue);
    });

    test('finalConsumer creates consumidor final', () {
      final client = Client.finalConsumer();
      expect(client.name, equals('Consumidor Final'));
      expect(client.vat, equals('9999999999999'));
      expect(client.isFinalConsumer, isTrue);
      expect(client.isSynced, isFalse);
    });

    test('fromOdoo parses many2one fields correctly', () {
      final json = {
        'id': 42,
        'name': 'Partner Test',
        'country_id': [63, 'Ecuador'],
        'state_id': [1, 'Guayaquil'],
        'parent_id': false,
        'is_company': false,
        'active': true,
        'credit_limit': 5000.0,
        'credit': 1000.0,
        'credit_to_invoice': 500.0,
        'use_partner_credit_limit': true,
        'allow_over_credit': false,
        'write_date': '2024-01-15 10:30:00',
      };
      final client = clientManager.fromOdoo(json);
      expect(client.id, equals(42));
      expect(client.name, equals('Partner Test'));
      expect(client.countryId, equals(63));
      expect(client.countryName, equals('Ecuador'));
      expect(client.stateId, equals(1));
      expect(client.parentId, isNull); // false -> null
      expect(client.creditLimit, equals(5000.0));
      // Generated fromOdoo sets isSynced to false
      expect(client.isSynced, isFalse);
    });
  });

  group('Client - Validation by Action', () {
    test('validateFor save only requires name', () {
      const client = Client(id: 1, name: 'Test');
      final errors = client.validateFor('save');
      expect(errors, isEmpty);
    });

    test('validateFor save fails without name', () {
      const client = Client(id: 1, name: '');
      final errors = client.validateFor('save');
      expect(errors.containsKey('name'), isTrue);
    });

    test('validateFor invoice requires VAT', () {
      const client = Client(id: 1, name: 'Test');
      final errors = client.validateFor('invoice');
      expect(errors.containsKey('vat'), isTrue);
    });

    test('validateFor invoice rejects consumidor final', () {
      final client = Client.finalConsumer();
      final errors = client.validateFor('invoice');
      expect(errors.containsKey('vat'), isTrue);
      expect(errors['vat'], contains('consumidor final'));
    });

    test('validateFor credit_sale fails when credit exceeded', () {
      const client = Client(
        id: 1,
        name: 'Test',
        usePartnerCreditLimit: true,
        creditLimit: 100.0,
        credit: 200.0,
        allowOverCredit: false,
      );
      final errors = client.validateFor('credit_sale');
      expect(errors.containsKey('credit'), isTrue);
    });

    test('validateFor credit_sale passes with allowOverCredit', () {
      const client = Client(
        id: 1,
        name: 'Test',
        vat: '1710034065',
        usePartnerCreditLimit: true,
        creditLimit: 100.0,
        credit: 200.0,
        allowOverCredit: true,
      );
      final errors = client.validateFor('credit_sale');
      expect(errors.containsKey('credit'), isFalse);
    });

    test('validateFor credit_sale fails with overdue debt', () {
      const client = Client(
        id: 1,
        name: 'Test',
        totalOverdue: 500.0,
        allowOverCredit: false,
      );
      final errors = client.validateFor('credit_sale');
      expect(errors.containsKey('credit'), isTrue);
    });
  });

  group('Client - Helper Methods', () {
    test('hasCreditLimit requires usePartnerCreditLimit and positive limit', () {
      expect(
        const Client(id: 1, name: 'T', usePartnerCreditLimit: true, creditLimit: 1000.0).hasCreditLimit,
        isTrue,
      );
      expect(
        const Client(id: 1, name: 'T', usePartnerCreditLimit: false, creditLimit: 1000.0).hasCreditLimit,
        isFalse,
      );
      expect(
        const Client(id: 1, name: 'T', usePartnerCreditLimit: true, creditLimit: 0.0).hasCreditLimit,
        isFalse,
      );
      expect(
        const Client(id: 1, name: 'T', usePartnerCreditLimit: true).hasCreditLimit,
        isFalse,
      );
    });

    test('canPurchaseOnCredit works correctly', () {
      // No limit -> can purchase
      const noLimit = Client(id: 1, name: 'T');
      expect(noLimit.canPurchaseOnCredit(99999), isTrue);

      // With limit and sufficient credit
      const hasCredit = Client(
        id: 1,
        name: 'T',
        usePartnerCreditLimit: true,
        creditLimit: 1000.0,
        credit: 0.0,
      );
      expect(hasCredit.canPurchaseOnCredit(500), isTrue);
      expect(hasCredit.canPurchaseOnCredit(1500), isFalse);

      // Allow over credit -> always can
      const overCredit = Client(
        id: 1,
        name: 'T',
        usePartnerCreditLimit: true,
        creditLimit: 100.0,
        credit: 200.0,
        allowOverCredit: true,
      );
      expect(overCredit.canPurchaseOnCredit(99999), isTrue);
    });

    test('effectivePhone returns phone or mobile', () {
      expect(const Client(id: 1, name: 'T', phone: '042000000').effectivePhone, '042000000');
      expect(const Client(id: 1, name: 'T', mobile: '0991234567').effectivePhone, '0991234567');
      expect(const Client(id: 1, name: 'T').effectivePhone, '');
    });

    test('isFinalConsumer detects correctly', () {
      expect(const Client(id: 1, name: 'T', vat: '9999999999999').isFinalConsumer, isTrue);
      expect(const Client(id: 1, name: 'T', vat: '1710034065').isFinalConsumer, isFalse);
      expect(const Client(id: 1, name: 'T').isFinalConsumer, isFalse);
    });
  });

  group('Client - Onchange Simulation', () {
    test('onIsCompanyChanged to company clears parent', () {
      const person = Client(id: 1, name: 'T', isCompany: false, parentId: 5, parentName: 'Parent');
      final company = person.onIsCompanyChanged(true);
      expect(company.isCompany, isTrue);
      expect(company.parentId, isNull);
      expect(company.parentName, isNull);
    });

    test('onIsCompanyChanged same value returns same instance', () {
      const person = Client(id: 1, name: 'T', isCompany: false);
      final result = person.onIsCompanyChanged(false);
      expect(identical(result, person), isTrue);
    });

    test('onCountryChanged resets state', () {
      const client = Client(id: 1, name: 'T', countryId: 63, stateName: 'Guayas', stateId: 1);
      final updated = client.onCountryChanged(234, 'Colombia');
      expect(updated.countryId, equals(234));
      expect(updated.countryName, equals('Colombia'));
      expect(updated.stateId, isNull);
      expect(updated.stateName, isNull);
    });

    test('onCountryChanged same country returns same instance', () {
      const client = Client(id: 1, name: 'T', countryId: 63);
      final result = client.onCountryChanged(63, 'Ecuador');
      expect(identical(result, client), isTrue);
    });
  });
}
