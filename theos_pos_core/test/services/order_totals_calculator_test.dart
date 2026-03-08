import 'package:test/test.dart';
import 'package:theos_pos_core/src/services/sales/order_totals_calculator.dart';
import 'package:theos_pos_core/src/models/sales/sale_order_line.model.dart';

void main() {
  const calculator = OrderTotalsCalculator();

  /// Helper to create a product line with amounts pre-calculated
  SaleOrderLine _makeLine({
    required double priceUnit,
    required double quantity,
    double discount = 0.0,
    double? priceSubtotal,
    double? priceTax,
    double? priceTotal,
    String? taxIds,
    String? taxNames,
    LineDisplayType displayType = LineDisplayType.product,
  }) {
    final sub = priceSubtotal ?? (priceUnit * quantity * (1 - discount / 100));
    final tax = priceTax ?? 0.0;
    final tot = priceTotal ?? (sub + tax);

    return SaleOrderLine(
      id: 0,
      orderId: 1,
      name: 'Test',
      priceUnit: priceUnit,
      productUomQty: quantity,
      discount: discount,
      priceSubtotal: sub,
      priceTax: tax,
      priceTotal: tot,
      taxIds: taxIds,
      taxNames: taxNames,
      displayType: displayType,
    );
  }

  group('OrderTotalsCalculator - calculate', () {
    test('empty lines returns zeroed result', () {
      final result = calculator.calculate(lines: []);

      expect(result.subtotalUndiscounted, equals(0.0));
      expect(result.totalDiscount, equals(0.0));
      expect(result.subtotal, equals(0.0));
      expect(result.total, equals(0.0));
      expect(result.taxGroups, isEmpty);
      expect(result.hasDiscount, isFalse);
    });

    test('single line without tax or discount', () {
      final result = calculator.calculate(
        lines: [
          _makeLine(priceUnit: 100.0, quantity: 2.0),
        ],
      );

      expect(result.subtotalUndiscounted, equals(200.0));
      expect(result.totalDiscount, equals(0.0));
      expect(result.subtotal, equals(200.0));
      expect(result.total, equals(200.0));
      expect(result.hasDiscount, isFalse);
    });

    test('single line with discount', () {
      final result = calculator.calculate(
        lines: [
          _makeLine(
            priceUnit: 100.0,
            quantity: 2.0,
            discount: 10.0,
            priceSubtotal: 180.0,
            priceTax: 27.0,
            priceTotal: 207.0,
          ),
        ],
      );

      expect(result.subtotalUndiscounted, equals(200.0));
      expect(result.totalDiscount, equals(20.0));
      expect(result.subtotal, equals(180.0));
      expect(result.total, equals(207.0));
      expect(result.hasDiscount, isTrue);
    });

    test('multiple lines aggregate correctly', () {
      final result = calculator.calculate(
        lines: [
          _makeLine(
            priceUnit: 100.0,
            quantity: 1.0,
            priceSubtotal: 100.0,
            priceTax: 15.0,
            priceTotal: 115.0,
            taxNames: 'IVA 15%',
          ),
          _makeLine(
            priceUnit: 50.0,
            quantity: 3.0,
            priceSubtotal: 150.0,
            priceTax: 22.5,
            priceTotal: 172.5,
            taxNames: 'IVA 15%',
          ),
        ],
      );

      expect(result.subtotalUndiscounted, equals(250.0));
      expect(result.subtotal, equals(250.0));
      expect(result.total, equals(287.5));
    });

    test('skips non-product lines (sections, notes)', () {
      final result = calculator.calculate(
        lines: [
          _makeLine(
            priceUnit: 100.0,
            quantity: 1.0,
            priceSubtotal: 100.0,
            priceTax: 15.0,
            priceTotal: 115.0,
          ),
          _makeLine(
            priceUnit: 0.0,
            quantity: 0.0,
            displayType: LineDisplayType.lineSection,
          ),
          _makeLine(
            priceUnit: 0.0,
            quantity: 0.0,
            displayType: LineDisplayType.lineNote,
          ),
        ],
      );

      expect(result.subtotal, equals(100.0));
      expect(result.total, equals(115.0));
    });
  });

  group('OrderTotalsCalculator - tax grouping', () {
    test('groups lines by tax name', () {
      final result = calculator.calculate(
        lines: [
          _makeLine(
            priceUnit: 100.0,
            quantity: 1.0,
            priceSubtotal: 100.0,
            priceTax: 15.0,
            priceTotal: 115.0,
            taxNames: 'IVA 15%',
          ),
          _makeLine(
            priceUnit: 50.0,
            quantity: 2.0,
            priceSubtotal: 100.0,
            priceTax: 15.0,
            priceTotal: 115.0,
            taxNames: 'IVA 15%',
          ),
          _makeLine(
            priceUnit: 200.0,
            quantity: 1.0,
            priceSubtotal: 200.0,
            priceTax: 0.0,
            priceTotal: 200.0,
            taxNames: 'IVA 0%',
          ),
        ],
      );

      expect(result.taxGroups.length, equals(2));

      final iva15 = result.taxGroups.firstWhere((g) => g.name.contains('15'));
      expect(iva15.base, equals(200.0));
      expect(iva15.amount, equals(30.0));

      final iva0 = result.taxGroups.firstWhere((g) => g.name.contains('0'));
      expect(iva0.base, equals(200.0));
      expect(iva0.amount, equals(0.0));
    });

    test('uses "IVA 0%" for lines with no tax name and zero tax', () {
      final result = calculator.calculate(
        lines: [
          _makeLine(
            priceUnit: 100.0,
            quantity: 1.0,
            priceSubtotal: 100.0,
            priceTax: 0.0,
            priceTotal: 100.0,
          ),
        ],
      );

      expect(result.taxGroups.length, equals(1));
      expect(result.taxGroups.first.name, equals('IVA 0%'));
    });

    test('uses "Impuestos" for lines with tax amount but no tax name', () {
      final result = calculator.calculate(
        lines: [
          _makeLine(
            priceUnit: 100.0,
            quantity: 1.0,
            priceSubtotal: 100.0,
            priceTax: 15.0,
            priceTotal: 115.0,
          ),
        ],
      );

      expect(result.taxGroups.length, equals(1));
      expect(result.taxGroups.first.name, equals('Impuestos'));
    });

    test('uses taxNameResolver when provided', () {
      final result = calculator.calculate(
        lines: [
          _makeLine(
            priceUnit: 100.0,
            quantity: 1.0,
            priceSubtotal: 100.0,
            priceTax: 15.0,
            priceTotal: 115.0,
            taxIds: '1,2',
          ),
        ],
        taxNameResolver: (taxIds, taxNames) => 'Custom IVA 15%',
      );

      expect(result.taxGroups.length, equals(1));
      expect(result.taxGroups.first.name, contains('Custom'));
    });

    test('does not group lines with zero subtotal', () {
      final result = calculator.calculate(
        lines: [
          _makeLine(
            priceUnit: 0.0,
            quantity: 1.0,
            priceSubtotal: 0.0,
            priceTax: 0.0,
            priceTotal: 0.0,
          ),
        ],
      );

      // Zero subtotal lines are skipped in tax grouping
      expect(result.taxGroups, isEmpty);
    });
  });

  group('OrderTotalsBreakdown', () {
    test('hasDiscount returns true when discount > 0', () {
      const breakdown = OrderTotalsBreakdown(
        subtotalUndiscounted: 200.0,
        totalDiscount: 20.0,
        subtotal: 180.0,
        total: 207.0,
        taxGroups: [],
      );

      expect(breakdown.hasDiscount, isTrue);
    });

    test('hasDiscount returns false when discount is 0', () {
      const breakdown = OrderTotalsBreakdown(
        subtotalUndiscounted: 200.0,
        totalDiscount: 0.0,
        subtotal: 200.0,
        total: 230.0,
        taxGroups: [],
      );

      expect(breakdown.hasDiscount, isFalse);
    });
  });

  group('TaxGroupTotal', () {
    test('stores name, base, and amount', () {
      const group = TaxGroupTotal(
        name: 'IVA 15%',
        base: 1000.0,
        amount: 150.0,
      );

      expect(group.name, equals('IVA 15%'));
      expect(group.base, equals(1000.0));
      expect(group.amount, equals(150.0));
    });
  });

  group('Global instance', () {
    test('orderTotalsCalculator is available', () {
      expect(orderTotalsCalculator, isA<OrderTotalsCalculator>());
    });
  });
}
