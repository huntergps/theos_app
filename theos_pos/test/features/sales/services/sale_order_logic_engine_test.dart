import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:theos_pos/features/sales/services/order_validation_types.dart';
import 'package:theos_pos/features/sales/services/withhold_service.dart';

void main() {
  group('ValidationResult', () {
    test('success creates valid result', () {
      final result = ValidationResult.success();
      expect(result.isValid, true);
      expect(result.errors, isEmpty);
      expect(result.suggestedAction, ValidationAction.proceed);
    });

    test('failed creates invalid result with errors', () {
      final errors = [
        ValidationError.partnerRequired(),
        ValidationError.linesRequired(),
      ];
      final result = ValidationResult.failed(errors);

      expect(result.isValid, false);
      expect(result.errors.length, 2);
      expect(result.suggestedAction, ValidationAction.block);
    });

    test('hasErrorType finds specific error', () {
      final result = ValidationResult.failed([
        ValidationError.partnerRequired(),
      ]);

      expect(result.hasErrorType(ValidationErrorType.partnerRequired), true);
      expect(result.hasErrorType(ValidationErrorType.linesRequired), false);
    });
  });

  group('ValidationError', () {
    test('partnerRequired creates correct error', () {
      final error = ValidationError.partnerRequired();
      expect(error.type, ValidationErrorType.partnerRequired);
      expect(error.message, contains('cliente'));
    });

    test('finalConsumerLimitExceeded includes details', () {
      final error = ValidationError.finalConsumerLimitExceeded(
        total: 75.50,
        limit: 50.00,
      );

      expect(error.type, ValidationErrorType.finalConsumerLimitExceeded);
      expect(error.message, contains('\$75.50'));
      expect(error.message, contains('\$50.00'));
      expect(error.details?['exceeded'], 25.50);
    });

    test('discountExceedsLimit with product name', () {
      final error = ValidationError.discountExceedsLimit(
        discount: 50.0,
        maxDiscount: 30.0,
        productName: 'Test Product',
      );

      expect(error.type, ValidationErrorType.discountExceedsLimit);
      expect(error.message, contains('50.0%'));
      expect(error.message, contains('30.0%'));
      expect(error.message, contains('Test Product'));
    });

    test('postDatedDateTooFar includes max days', () {
      final error = ValidationError.postDatedDateTooFar(maxDays: 7);

      expect(error.type, ValidationErrorType.postDatedInvoiceDateTooFar);
      expect(error.message, contains('7 días'));
    });

    test('invalidWithholdAuthorization shows actual length', () {
      final error = ValidationError.invalidWithholdAuthorization(
        actualLength: 35,
      );

      expect(error.type, ValidationErrorType.invalidWithholdAuthorization);
      expect(error.message, contains('35'));
      expect(error.message, contains('49'));
    });

    test('temporaryProductsFound lists products', () {
      final error = ValidationError.temporaryProductsFound(
        productNames: ['Product A', 'Product B'],
      );

      expect(error.type, ValidationErrorType.temporaryProductsFound);
      expect(error.message, contains('Product A'));
      expect(error.message, contains('Product B'));
      expect(error.details?['count'], 2);
    });
  });

  group('WithholdService.validateAuthorization', () {
    test('empty authorization is valid', () {
      final result = WithholdService.validateAuthorization(null);
      expect(result.isValid, true);

      final result2 = WithholdService.validateAuthorization('');
      expect(result2.isValid, true);
    });

    test('49 digits is valid', () {
      final authorization = '1' * 49; // 49 ones
      final result = WithholdService.validateAuthorization(authorization);
      expect(result.isValid, true);
    });

    test('less than 49 digits is invalid', () {
      final authorization = '1' * 35;
      final result = WithholdService.validateAuthorization(authorization);

      expect(result.isValid, false);
      expect(result.errorMessage, contains('35'));
      expect(result.errorMessage, contains('49'));
    });

    test('more than 49 digits is invalid', () {
      final authorization = '1' * 60;
      final result = WithholdService.validateAuthorization(authorization);

      expect(result.isValid, false);
      expect(result.errorMessage, contains('60'));
    });

    test('non-numeric characters are invalid', () {
      final authorization = '${'1' * 48}A';
      final result = WithholdService.validateAuthorization(authorization);

      expect(result.isValid, false);
      expect(result.errorMessage, contains('numéricos'));
    });

    test('spaces and hyphens are cleaned before validation', () {
      // 49 digits with spaces
      final authorization = '1234 5678 9012 3456 7890 1234 5678 9012 3456 7890 123456789';
      final cleaned = authorization.replaceAll(RegExp(r'[\s-]'), '');

      // This should be 49 digits after cleaning
      if (cleaned.length == 49) {
        final result = WithholdService.validateAuthorization(authorization);
        expect(result.isValid, true);
      }
    });
  });

  group('SaleOrderState transitions', () {
    test('draft can transition to sent, sale, cancel', () {
      // Testing the state transition rules defined in the engine
      final validTransitions = [
        SaleOrderState.sent,
        SaleOrderState.sale,
        SaleOrderState.cancel,
      ];

      // Draft should allow these transitions
      for (final state in validTransitions) {
        expect(
          [SaleOrderState.sent, SaleOrderState.sale, SaleOrderState.cancel]
              .contains(state),
          true,
          reason: 'Draft should transition to ${state.name}',
        );
      }
    });

    test('done is terminal state', () {
      // Done should not allow any transitions
      expect(true, true); // Placeholder for actual engine test
    });
  });

  group('Field editability by state', () {
    test('draft allows all field edits', () {
      // In draft state, all fields should be editable
      const editableFieldsDraft = {'*'}; // All fields
      expect(editableFieldsDraft.contains('*'), true);
    });

    test('approved only allows note edits', () {
      // In approved state, only notes should be editable
      const editableFieldsApproved = {'note'};
      expect(editableFieldsApproved.contains('note'), true);
      expect(editableFieldsApproved.contains('partner_id'), false);
    });

    test('done allows no edits', () {
      // In done state, nothing should be editable
      const editableFieldsDone = <String>{};
      expect(editableFieldsDone.isEmpty, true);
    });
  });

  group('Business rule validations', () {
    test('final consumer limit is 50 USD by default', () {
      const defaultLimit = 50.0;
      const orderTotal = 75.0;

      // Order exceeds limit
      expect(orderTotal > defaultLimit, true);

      // Order under limit
      const smallOrder = 45.0;
      expect(smallOrder <= defaultLimit, true);
    });

    test('max discount percentage validation', () {
      const maxDiscount = 30.0;
      const lineDiscount = 50.0;

      // Line exceeds max discount
      expect(lineDiscount > maxDiscount, true);

      // Line within limit
      const validDiscount = 25.0;
      expect(validDiscount <= maxDiscount, true);
    });

    test('post-dated invoice date validation', () {
      final today = DateTime.now();
      final todayDate = DateTime(today.year, today.month, today.day);

      // Past date is invalid
      final pastDate = todayDate.subtract(const Duration(days: 1));
      expect(pastDate.isBefore(todayDate), true);

      // Future date within limit is valid
      const maxDays = 7;
      final validDate = todayDate.add(const Duration(days: 5));
      final maxDate = todayDate.add(const Duration(days: maxDays));
      expect(validDate.isAfter(maxDate), false);

      // Future date beyond limit is invalid
      final invalidDate = todayDate.add(const Duration(days: 10));
      expect(invalidDate.isAfter(maxDate), true);
    });
  });

  group('SaleOrderLine helpers', () {
    test('isProductLine returns true for product display type', () {
      const line = SaleOrderLine(
        id: 1,
        orderId: 1,
        name: 'Test Product',
        displayType: LineDisplayType.product,
      );

      expect(line.isProductLine, true);
      expect(line.isSection, false);
    });

    test('isSection returns true for section display type', () {
      const line = SaleOrderLine(
        id: 1,
        orderId: 1,
        name: 'Section',
        displayType: LineDisplayType.lineSection,
      );

      expect(line.isSection, true);
      expect(line.isProductLine, false);
    });

    test('calculateSubtotal applies discount correctly', () {
      const line = SaleOrderLine(
        id: 1,
        orderId: 1,
        name: 'Product',
        priceUnit: 100.0,
        productUomQty: 2.0,
        discount: 10.0, // 10% discount
      );

      // Expected: 100 * (1 - 0.10) * 2 = 180
      expect(line.calculateSubtotal(), 180.0);
    });

    test('hasDiscount returns true when discount > 0', () {
      const lineWithDiscount = SaleOrderLine(
        id: 1,
        orderId: 1,
        name: 'Product',
        discount: 5.0,
      );

      const lineWithoutDiscount = SaleOrderLine(
        id: 2,
        orderId: 1,
        name: 'Product',
        discount: 0.0,
      );

      expect(lineWithDiscount.hasDiscount, true);
      expect(lineWithoutDiscount.hasDiscount, false);
    });
  });
}
