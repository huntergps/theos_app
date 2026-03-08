import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/sales/services/order_totals_calculator.dart';

import '../../../helpers/test_model_factory.dart';

void main() {
  const calculator = OrderTotalsCalculator();
  const orderId = 1;

  setUp(() {
    resetIdCounter();
  });

  group('OrderTotalsCalculator.calculate', () {
    group('empty and basic cases', () {
      test('empty list returns zeroes', () {
        final result = calculator.calculate(lines: []);

        expect(result.subtotalUndiscounted, closeTo(0.0, 0.001));
        expect(result.totalDiscount, closeTo(0.0, 0.001));
        expect(result.subtotal, closeTo(0.0, 0.001));
        expect(result.total, closeTo(0.0, 0.001));
        expect(result.taxGroups, isEmpty);
        expect(result.hasDiscount, isFalse);
      });

      test('single line no discount no tax', () {
        final line = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 25.0,
          productUomQty: 2.0,
        ).copyWith(
          priceSubtotal: 50.0,
          priceTax: 0.0,
          priceTotal: 50.0,
        );

        final result = calculator.calculate(lines: [line]);

        // baseAmount = 25 * 2 = 50
        expect(result.subtotalUndiscounted, closeTo(50.0, 0.001));
        expect(result.totalDiscount, closeTo(0.0, 0.001));
        expect(result.subtotal, closeTo(50.0, 0.001));
        expect(result.total, closeTo(50.0, 0.001));
        expect(result.hasDiscount, isFalse);
        // subtotal > 0, no taxNames, no tax => group "IVA 0%"
        expect(result.taxGroups, hasLength(1));
        expect(result.taxGroups.first.name, 'IVA 0%');
        expect(result.taxGroups.first.base, closeTo(50.0, 0.001));
        expect(result.taxGroups.first.amount, closeTo(0.0, 0.001));
      });
    });

    group('discount handling', () {
      test('single line with discount', () {
        // priceUnit=100, qty=1, discount=10%
        final line = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 100.0,
          productUomQty: 1.0,
          discount: 10.0,
        ).copyWith(
          priceSubtotal: 90.0,
          priceTax: 0.0,
          priceTotal: 90.0,
        );

        final result = calculator.calculate(lines: [line]);

        // baseAmount = 100 * 1 = 100
        // discountAmount = 100 * (10/100) = 10
        expect(result.subtotalUndiscounted, closeTo(100.0, 0.001));
        expect(result.totalDiscount, closeTo(10.0, 0.001));
        expect(result.subtotal, closeTo(90.0, 0.001));
        expect(result.total, closeTo(90.0, 0.001));
        expect(result.hasDiscount, isTrue);
      });

      test('hasDiscount returns true when totalDiscount > 0', () {
        final line = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 50.0,
          productUomQty: 1.0,
          discount: 5.0,
        ).copyWith(
          priceSubtotal: 47.5,
          priceTax: 0.0,
          priceTotal: 47.5,
        );

        final result = calculator.calculate(lines: [line]);
        expect(result.hasDiscount, isTrue);
        expect(result.totalDiscount, closeTo(2.5, 0.001));
      });
    });

    group('tax handling', () {
      test('single line with tax (priceTax > 0)', () {
        // priceUnit=100, qty=1, no discount, 15% tax
        final line = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 100.0,
          productUomQty: 1.0,
        ).copyWith(
          priceSubtotal: 100.0,
          priceTax: 15.0,
          priceTotal: 115.0,
          taxNames: 'IVA 15%',
        );

        final result = calculator.calculate(lines: [line]);

        expect(result.subtotalUndiscounted, closeTo(100.0, 0.001));
        expect(result.subtotal, closeTo(100.0, 0.001));
        expect(result.total, closeTo(115.0, 0.001));
        expect(result.taxGroups, hasLength(1));
        expect(result.taxGroups.first.name, 'IVA 15%');
        expect(result.taxGroups.first.base, closeTo(100.0, 0.001));
        expect(result.taxGroups.first.amount, closeTo(15.0, 0.001));
      });

      test('lines with zero subtotal do not create tax groups', () {
        final line = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 0.0,
          productUomQty: 1.0,
        ).copyWith(
          priceSubtotal: 0.0,
          priceTax: 0.0,
          priceTotal: 0.0,
        );

        final result = calculator.calculate(lines: [line]);

        expect(result.taxGroups, isEmpty);
      });

      test('tax group defaults to "Impuestos" when no taxNames but priceTax > 0',
          () {
        final line = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 100.0,
          productUomQty: 1.0,
        ).copyWith(
          priceSubtotal: 100.0,
          priceTax: 12.0,
          priceTotal: 112.0,
          // taxNames is null by default
        );

        final result = calculator.calculate(lines: [line]);

        expect(result.taxGroups, hasLength(1));
        expect(result.taxGroups.first.name, 'Impuestos');
      });
    });

    group('multiple lines aggregation', () {
      test('multiple lines are summed correctly', () {
        final line1 = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 30.0,
          productUomQty: 2.0,
        ).copyWith(
          priceSubtotal: 60.0,
          priceTax: 9.0,
          priceTotal: 69.0,
          taxNames: 'IVA 15%',
        );

        final line2 = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 50.0,
          productUomQty: 3.0,
          discount: 10.0,
        ).copyWith(
          priceSubtotal: 135.0,
          priceTax: 20.25,
          priceTotal: 155.25,
          taxNames: 'IVA 15%',
        );

        final result = calculator.calculate(lines: [line1, line2]);

        // line1: baseAmount = 30*2 = 60, discount = 0
        // line2: baseAmount = 50*3 = 150, discount = 150*0.10 = 15
        expect(result.subtotalUndiscounted, closeTo(210.0, 0.001));
        expect(result.totalDiscount, closeTo(15.0, 0.001));
        expect(result.subtotal, closeTo(195.0, 0.001));
        expect(result.total, closeTo(224.25, 0.001));
      });
    });

    group('section and note lines are skipped', () {
      test('section lines are ignored', () {
        final productLine = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 40.0,
          productUomQty: 1.0,
        ).copyWith(
          priceSubtotal: 40.0,
          priceTax: 0.0,
          priceTotal: 40.0,
        );

        final sectionLine = SaleOrderLineFactory.section(orderId: orderId);

        final result = calculator.calculate(lines: [sectionLine, productLine]);

        expect(result.subtotalUndiscounted, closeTo(40.0, 0.001));
        expect(result.subtotal, closeTo(40.0, 0.001));
        expect(result.total, closeTo(40.0, 0.001));
      });

      test('note lines are ignored', () {
        final productLine = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 20.0,
          productUomQty: 2.0,
        ).copyWith(
          priceSubtotal: 40.0,
          priceTax: 0.0,
          priceTotal: 40.0,
        );

        final noteLine = SaleOrderLineFactory.note(orderId: orderId);

        final result = calculator.calculate(lines: [noteLine, productLine]);

        expect(result.subtotalUndiscounted, closeTo(40.0, 0.001));
        expect(result.subtotal, closeTo(40.0, 0.001));
      });
    });

    group('tax grouping', () {
      test('lines with same tax name merge into one group', () {
        final line1 = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 100.0,
          productUomQty: 1.0,
        ).copyWith(
          priceSubtotal: 100.0,
          priceTax: 15.0,
          priceTotal: 115.0,
          taxNames: 'IVA 15%',
        );

        final line2 = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 200.0,
          productUomQty: 1.0,
        ).copyWith(
          priceSubtotal: 200.0,
          priceTax: 30.0,
          priceTotal: 230.0,
          taxNames: 'IVA 15%',
        );

        final result = calculator.calculate(lines: [line1, line2]);

        expect(result.taxGroups, hasLength(1));
        expect(result.taxGroups.first.name, 'IVA 15%');
        expect(result.taxGroups.first.base, closeTo(300.0, 0.001));
        expect(result.taxGroups.first.amount, closeTo(45.0, 0.001));
      });

      test('lines with different tax names create separate groups', () {
        final line15 = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 100.0,
          productUomQty: 1.0,
        ).copyWith(
          priceSubtotal: 100.0,
          priceTax: 15.0,
          priceTotal: 115.0,
          taxNames: 'IVA 15%',
        );

        final line0 = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 80.0,
          productUomQty: 1.0,
        ).copyWith(
          priceSubtotal: 80.0,
          priceTax: 0.0,
          priceTotal: 80.0,
          taxNames: 'IVA 0%',
        );

        final result = calculator.calculate(lines: [line15, line0]);

        expect(result.taxGroups, hasLength(2));

        final group15 =
            result.taxGroups.where((g) => g.name == 'IVA 15%').first;
        expect(group15.base, closeTo(100.0, 0.001));
        expect(group15.amount, closeTo(15.0, 0.001));

        final group0 =
            result.taxGroups.where((g) => g.name == 'IVA 0%').first;
        expect(group0.base, closeTo(80.0, 0.001));
        expect(group0.amount, closeTo(0.0, 0.001));
      });
    });

    group('taxNameResolver', () {
      test('taxNameResolver is used when taxNames is null', () {
        final line = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 100.0,
          productUomQty: 1.0,
        ).copyWith(
          priceSubtotal: 100.0,
          priceTax: 15.0,
          priceTotal: 115.0,
          taxIds: '3',
          // taxNames is null
        );

        String resolver(String? taxIds, String? taxNames) {
          if (taxIds == '3') return 'IVA 15%';
          return 'Desconocido';
        }

        final result = calculator.calculate(
          lines: [line],
          taxNameResolver: resolver,
        );

        expect(result.taxGroups, hasLength(1));
        expect(result.taxGroups.first.name, 'IVA 15%');
        expect(result.taxGroups.first.base, closeTo(100.0, 0.001));
        expect(result.taxGroups.first.amount, closeTo(15.0, 0.001));
      });

      test('taxNameResolver is not called when taxNames is present', () {
        bool resolverCalled = false;

        final line = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 100.0,
          productUomQty: 1.0,
        ).copyWith(
          priceSubtotal: 100.0,
          priceTax: 15.0,
          priceTotal: 115.0,
          taxNames: 'IVA 15%',
        );

        String resolver(String? taxIds, String? taxNames) {
          resolverCalled = true;
          return 'Should not be used';
        }

        final result = calculator.calculate(
          lines: [line],
          taxNameResolver: resolver,
        );

        expect(resolverCalled, isFalse);
        expect(result.taxGroups.first.name, 'IVA 15%');
      });

      test('taxNameResolver returning empty falls back to priceTax check', () {
        final line = SaleOrderLineFactory.create(
          orderId: orderId,
          priceUnit: 100.0,
          productUomQty: 1.0,
        ).copyWith(
          priceSubtotal: 100.0,
          priceTax: 12.0,
          priceTotal: 112.0,
        );

        String resolver(String? taxIds, String? taxNames) => '';

        final result = calculator.calculate(
          lines: [line],
          taxNameResolver: resolver,
        );

        // resolvedNames is empty, lineTax > 0 => "Impuestos"
        expect(result.taxGroups, hasLength(1));
        expect(result.taxGroups.first.name, 'Impuestos');
      });
    });
  });
}
