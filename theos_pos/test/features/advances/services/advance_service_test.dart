import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/features/advances/services/advance_service.dart'
    show AdvanceResult, AdvanceService, PartnerBank;
import 'package:theos_pos/features/banks/repositories/bank_repository.dart';
import 'package:theos_pos/core/services/odoo_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide PartnerBank;

// ============================================================
// Mocks
// ============================================================

class MockOdooService extends Mock implements OdooService {}

class MockBankRepository extends Mock implements BankRepository {}

/// Tests for AdvanceService — focusing on testable pure logic:
///
/// Data classes:
/// - AdvanceResult — success/failure result
/// - PartnerBank — from Odoo data parsing + displayName
///
/// Validation logic in createAdvance():
/// - Reference length validation (must be >= 30 chars)
/// - Lines not empty validation
/// - Total lines amount > 0 validation
///
/// NOTE: Methods that call Odoo API (getAvailableAdvances, postAdvance,
/// cancelAdvance, getAvailableJournals, getBanks, getCardBrands,
/// getCardDeadlines, getDefaultDueDays, getMinReferenceLength) are NOT
/// tested here since they require a live Odoo connection or complex
/// manager/database mocking with global singletons.
void main() {
  // ============================================================
  // AdvanceResult data class
  // ============================================================
  group('AdvanceResult', () {
    test('should create success result with all fields', () {
      final result = AdvanceResult(
        success: true,
        advanceId: 42,
        advanceName: 'ANT/2024/001',
        amount: 1500.0,
      );

      expect(result.success, isTrue);
      expect(result.advanceId, 42);
      expect(result.advanceName, 'ANT/2024/001');
      expect(result.amount, 1500.0);
      expect(result.errorMessage, isNull);
    });

    test('should create failure result with error message', () {
      final result = AdvanceResult(
        success: false,
        errorMessage: 'La referencia debe tener al menos 30 caracteres',
      );

      expect(result.success, isFalse);
      expect(result.advanceId, isNull);
      expect(result.advanceName, isNull);
      expect(result.amount, isNull);
      expect(result.errorMessage, contains('referencia'));
    });

    test('should create minimal success result', () {
      final result = AdvanceResult(success: true);

      expect(result.success, isTrue);
      expect(result.advanceId, isNull);
      expect(result.advanceName, isNull);
      expect(result.amount, isNull);
      expect(result.errorMessage, isNull);
    });
  });

  // ============================================================
  // PartnerBank data class
  // ============================================================
  group('PartnerBank', () {
    group('fromOdoo()', () {
      test('should parse bank data with bank_id as list', () {
        final data = {
          'id': 10,
          'acc_number': '2200012345',
          'bank_id': [5, 'Banco Pichincha'],
        };

        final bank = PartnerBank.fromOdoo(data);

        expect(bank.id, 10);
        expect(bank.accountNumber, '2200012345');
        expect(bank.bankId, 5);
        expect(bank.bankName, 'Banco Pichincha');
      });

      test('should parse bank data without bank_id', () {
        final data = {
          'id': 11,
          'acc_number': '3300098765',
          'bank_id': false,
        };

        final bank = PartnerBank.fromOdoo(data);

        expect(bank.id, 11);
        expect(bank.accountNumber, '3300098765');
        expect(bank.bankId, isNull);
        expect(bank.bankName, isNull);
      });

      test('should parse bank data with empty bank_id list', () {
        final data = {
          'id': 12,
          'acc_number': '1100011111',
          'bank_id': <dynamic>[],
        };

        final bank = PartnerBank.fromOdoo(data);

        expect(bank.id, 12);
        expect(bank.accountNumber, '1100011111');
        expect(bank.bankId, isNull);
        expect(bank.bankName, isNull);
      });

      test('should parse bank data with single-element bank_id list', () {
        // Edge case: list with only ID, no name
        final data = {
          'id': 13,
          'acc_number': '5500055555',
          'bank_id': [7],
        };

        final bank = PartnerBank.fromOdoo(data);

        expect(bank.id, 13);
        expect(bank.accountNumber, '5500055555');
        // List has only 1 element (length < 2), so bank info not extracted
        expect(bank.bankId, isNull);
        expect(bank.bankName, isNull);
      });
    });

    group('displayName', () {
      test('should show bank name and account number when bank is set', () {
        final bank = PartnerBank(
          id: 1,
          accountNumber: '2200012345',
          bankId: 5,
          bankName: 'Banco Pichincha',
        );

        expect(bank.displayName, 'Banco Pichincha - 2200012345');
      });

      test('should show only account number when no bank name', () {
        final bank = PartnerBank(
          id: 1,
          accountNumber: '2200012345',
        );

        expect(bank.displayName, '2200012345');
      });

      test('should show only account number when bank name is null', () {
        final bank = PartnerBank(
          id: 1,
          accountNumber: '9900099999',
          bankId: 5,
          bankName: null,
        );

        expect(bank.displayName, '9900099999');
      });
    });

    group('constructor', () {
      test('should create with all fields', () {
        final bank = PartnerBank(
          id: 10,
          accountNumber: '2200012345',
          bankId: 5,
          bankName: 'Banco Guayaquil',
        );

        expect(bank.id, 10);
        expect(bank.accountNumber, '2200012345');
        expect(bank.bankId, 5);
        expect(bank.bankName, 'Banco Guayaquil');
      });

      test('should create with required fields only', () {
        final bank = PartnerBank(
          id: 1,
          accountNumber: '0000000000',
        );

        expect(bank.id, 1);
        expect(bank.accountNumber, '0000000000');
        expect(bank.bankId, isNull);
        expect(bank.bankName, isNull);
      });
    });
  });

  // ============================================================
  // AdvanceService.createAdvance() — validation logic
  // ============================================================
  group('AdvanceService.createAdvance() — validation', () {
    late MockOdooService mockOdoo;
    late MockBankRepository mockBankRepo;
    late AdvanceService service;

    setUp(() {
      mockOdoo = MockOdooService();
      mockBankRepo = MockBankRepository();
      service = AdvanceService(mockOdoo, mockBankRepo);
    });

    test('should fail when reference is too short', () async {
      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'short ref',
        amount: 100.0,
        lines: [
          const AdvanceLine(
            id: -1,
            journalId: 1,
            amount: 100.0,
          ),
        ],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('30 caracteres'));
      // Should not call Odoo
      verifyNever(() => mockOdoo.call(
            model: any(named: 'model'),
            method: any(named: 'method'),
            kwargs: any(named: 'kwargs'),
          ));
    });

    test('should fail when lines are empty', () async {
      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30, // Exactly 30 chars
        amount: 100.0,
        lines: const [],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('método de pago'));
    });

    test('should fail when total line amount is zero', () async {
      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30,
        amount: 0.0,
        lines: [
          const AdvanceLine(
            id: -1,
            journalId: 1,
            amount: 0.0,
          ),
        ],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('mayor a cero'));
    });

    test('should fail when total line amount is negative', () async {
      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30,
        amount: -50.0,
        lines: [
          const AdvanceLine(
            id: -1,
            journalId: 1,
            amount: -50.0,
          ),
        ],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('mayor a cero'));
    });

    test('should accept reference with exactly 30 characters and valid lines',
        () async {
      // This test verifies that validation passes and the service attempts
      // to call Odoo (which we mock to return an ID).
      when(() => mockOdoo.call(
            model: any(named: 'model'),
            method: any(named: 'method'),
            kwargs: any(named: 'kwargs'),
          )).thenAnswer((_) async => [99]);

      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'R' * 30,
        amount: 500.0,
        lines: [
          const AdvanceLine(
            id: -1,
            journalId: 1,
            amount: 500.0,
          ),
        ],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isTrue);
      expect(result.advanceId, 99);
    });

    test('should accept reference longer than 30 characters', () async {
      when(() => mockOdoo.call(
            model: any(named: 'model'),
            method: any(named: 'method'),
            kwargs: any(named: 'kwargs'),
          )).thenAnswer((_) async => 77);

      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'REF-${'X' * 50}',
        amount: 200.0,
        lines: [
          const AdvanceLine(
            id: -1,
            journalId: 1,
            amount: 200.0,
          ),
        ],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isTrue);
      expect(result.advanceId, 77);
    });

    test('should handle Odoo returning null from create', () async {
      when(() => mockOdoo.call(
            model: any(named: 'model'),
            method: any(named: 'method'),
            kwargs: any(named: 'kwargs'),
          )).thenAnswer((_) async => null);

      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30,
        amount: 100.0,
        lines: [
          const AdvanceLine(
            id: -1,
            journalId: 1,
            amount: 100.0,
          ),
        ],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Failed to create'));
    });

    test('should handle Odoo exception during create', () async {
      when(() => mockOdoo.call(
            model: any(named: 'model'),
            method: any(named: 'method'),
            kwargs: any(named: 'kwargs'),
          )).thenThrow(Exception('Connection refused'));

      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30,
        amount: 100.0,
        lines: [
          const AdvanceLine(
            id: -1,
            journalId: 1,
            amount: 100.0,
          ),
        ],
      );

      final result = await service.createAdvance(advance);

      expect(result.success, isFalse);
      expect(result.errorMessage, contains('Connection refused'));
    });

    test('should sum multiple line amounts for validation', () async {
      when(() => mockOdoo.call(
            model: any(named: 'model'),
            method: any(named: 'method'),
            kwargs: any(named: 'kwargs'),
          )).thenAnswer((_) async => [55]);

      final advance = Advance(
        date: DateTime.now(),
        dateEstimated: DateTime.now().add(const Duration(days: 30)),
        advanceType: AdvanceType.inbound,
        partnerId: 1,
        reference: 'A' * 30,
        amount: 300.0,
        lines: [
          const AdvanceLine(id: -1, journalId: 1, amount: 150.0),
          const AdvanceLine(id: -2, journalId: 2, amount: 150.0),
        ],
      );

      final result = await service.createAdvance(advance);

      // Total lines = 300.0 > 0, validation passes
      expect(result.success, isTrue);
    });
  });
}
