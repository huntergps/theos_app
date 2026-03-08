import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/sales/services/withhold_service.dart';

/// Tests for WithholdService pure business logic:
/// - validateAuthorization() static method
/// - WithholdAuthorizationValidation data class
///
/// The existing withholding_dialog_test.dart tests basic calculation logic
/// but uses inline validation (auth.length == 49), not the actual service method.
/// These tests cover the real WithholdService.validateAuthorization() which
/// also handles whitespace/hyphen stripping and digit-only validation.
void main() {
  // ============================================================
  // WithholdAuthorizationValidation
  // ============================================================
  group('WithholdAuthorizationValidation', () {
    test('valid factory should create valid result', () {
      final v = WithholdAuthorizationValidation.valid();
      expect(v.isValid, isTrue);
      expect(v.errorMessage, isNull);
    });

    test('invalid factory should create invalid result with message', () {
      final v = WithholdAuthorizationValidation.invalid('Some error');
      expect(v.isValid, isFalse);
      expect(v.errorMessage, 'Some error');
    });
  });

  // ============================================================
  // validateAuthorization()
  // ============================================================
  group('WithholdService.validateAuthorization', () {
    group('valid cases', () {
      test('should accept null authorization', () {
        final result = WithholdService.validateAuthorization(null);
        expect(result.isValid, isTrue);
      });

      test('should accept empty authorization', () {
        final result = WithholdService.validateAuthorization('');
        expect(result.isValid, isTrue);
      });

      test('should accept exactly 49 digits', () {
        final auth = '1234567890123456789012345678901234567890123456789';
        expect(auth.length, 49); // Sanity check
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isTrue);
      });

      test('should accept 49 digits with spaces stripped', () {
        // 49 digits with spaces interspersed
        final auth = '12345678901234567890 12345678901234567890 123456789';
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isTrue);
      });

      test('should accept 49 digits with hyphens stripped', () {
        final auth = '1234567890-1234567890-1234567890-1234567890-123456789';
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isTrue);
      });

      test('should accept 49 digits with mixed spaces and hyphens', () {
        final auth = '123 456-789 012 345-678 901 234-567 890 123 456-789 012 345 6789';
        // After cleaning: remove spaces and hyphens, should be 49 digits
        final cleaned = auth.replaceAll(RegExp(r'[\s-]'), '');
        expect(cleaned.length, 49); // Sanity check
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isTrue);
      });

      test('should accept all-zero authorization', () {
        final auth = '0' * 49;
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isTrue);
      });

      test('should accept all-nine authorization', () {
        final auth = '9' * 49;
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isTrue);
      });
    });

    group('invalid length', () {
      test('should reject 48 digits (too short)', () {
        final auth = '1' * 48;
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('49'));
        expect(result.errorMessage, contains('48'));
      });

      test('should reject 50 digits (too long)', () {
        final auth = '1' * 50;
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('49'));
        expect(result.errorMessage, contains('50'));
      });

      test('should reject single digit', () {
        final result = WithholdService.validateAuthorization('5');
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('1'));
      });

      test('should reject 10 digits', () {
        final result = WithholdService.validateAuthorization('1234567890');
        expect(result.isValid, isFalse);
      });
    });

    group('invalid characters', () {
      test('should reject letters in authorization', () {
        // 49 chars but with letters
        final auth = 'A234567890123456789012345678901234567890123456789';
        expect(auth.length, 49);
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('dígitos numéricos'));
      });

      test('should reject special characters', () {
        final auth = '123456789012345678901234567890123456789012345678!';
        expect(auth.length, 49);
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isFalse);
      });

      test('should reject dots', () {
        // Dots are not stripped (only spaces and hyphens are)
        final auth = '1234567890.234567890123456789012345678901234567890';
        // After removing only spaces/hyphens, still has dot
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isFalse);
      });
    });

    group('edge cases', () {
      test('should handle whitespace-only string as length error', () {
        final result = WithholdService.validateAuthorization('   ');
        // After stripping spaces: empty string (length 0), but original was not empty
        // Length check: 0 != 49 → invalid
        expect(result.isValid, isFalse);
      });

      test('should handle hyphens-only string as length error', () {
        final result = WithholdService.validateAuthorization('---');
        expect(result.isValid, isFalse);
      });

      test('error message should mention the actual digit count', () {
        final auth = '1' * 30;
        final result = WithholdService.validateAuthorization(auth);
        expect(result.isValid, isFalse);
        expect(result.errorMessage, contains('30'));
      });
    });
  });
}
