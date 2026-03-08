import 'package:test/test.dart';
import 'package:theos_pos_core/src/services/sales/line_calculator.dart';
import 'package:theos_pos_core/src/models/sales/sale_order_line.model.dart';

void main() {
  const calculator = SaleOrderLineCalculator();

  group('SaleOrderLineCalculator - calculateLine', () {
    test('basic calculation without discount', () {
      final result = calculator.calculateLine(
        priceUnit: 100.0,
        quantity: 2.0,
        discountPercent: 0.0,
        taxPercent: 15.0,
      );

      expect(result.priceSubtotal, equals(200.0));
      expect(result.priceTax, equals(30.0));
      expect(result.priceTotal, equals(230.0));
      expect(result.discountAmount, equals(0.0));
    });

    test('calculation with discount', () {
      final result = calculator.calculateLine(
        priceUnit: 100.0,
        quantity: 2.0,
        discountPercent: 10.0,
        taxPercent: 15.0,
      );

      expect(result.priceSubtotal, equals(180.0));
      expect(result.priceTax, equals(27.0));
      expect(result.priceTotal, equals(207.0));
      expect(result.discountAmount, equals(20.0));
    });

    test('calculation with 100% discount', () {
      final result = calculator.calculateLine(
        priceUnit: 100.0,
        quantity: 5.0,
        discountPercent: 100.0,
        taxPercent: 15.0,
      );

      expect(result.priceSubtotal, equals(0.0));
      expect(result.priceTax, equals(0.0));
      expect(result.priceTotal, equals(0.0));
      expect(result.discountAmount, equals(500.0));
    });

    test('calculation with 0% tax', () {
      final result = calculator.calculateLine(
        priceUnit: 50.0,
        quantity: 3.0,
        discountPercent: 0.0,
        taxPercent: 0.0,
      );

      expect(result.priceSubtotal, equals(150.0));
      expect(result.priceTax, equals(0.0));
      expect(result.priceTotal, equals(150.0));
    });

    test('calculation with fractional quantities', () {
      final result = calculator.calculateLine(
        priceUnit: 10.0,
        quantity: 2.5,
        discountPercent: 0.0,
        taxPercent: 12.0,
      );

      expect(result.priceSubtotal, equals(25.0));
      expect(result.priceTax, equals(3.0));
      expect(result.priceTotal, equals(28.0));
    });

    test('calculation with zero price', () {
      final result = calculator.calculateLine(
        priceUnit: 0.0,
        quantity: 10.0,
        discountPercent: 0.0,
        taxPercent: 15.0,
      );

      expect(result.priceSubtotal, equals(0.0));
      expect(result.priceTax, equals(0.0));
      expect(result.priceTotal, equals(0.0));
    });

    test('calculation with zero quantity', () {
      final result = calculator.calculateLine(
        priceUnit: 100.0,
        quantity: 0.0,
        discountPercent: 0.0,
        taxPercent: 15.0,
      );

      expect(result.priceSubtotal, equals(0.0));
      expect(result.priceTax, equals(0.0));
      expect(result.priceTotal, equals(0.0));
    });

    test('calculation with small values (precision)', () {
      final result = calculator.calculateLine(
        priceUnit: 0.01,
        quantity: 1.0,
        discountPercent: 0.0,
        taxPercent: 15.0,
      );

      expect(result.priceSubtotal, equals(0.01));
      expect(result.priceTax, closeTo(0.0015, 0.0001));
      expect(result.priceTotal, closeTo(0.0115, 0.0001));
    });

    test('calculation with large values', () {
      final result = calculator.calculateLine(
        priceUnit: 99999.99,
        quantity: 100.0,
        discountPercent: 5.0,
        taxPercent: 15.0,
      );

      const expectedSubtotal = 99999.99 * 100.0 * 0.95;
      const expectedTax = expectedSubtotal * 0.15;
      expect(result.priceSubtotal, closeTo(expectedSubtotal, 0.01));
      expect(result.priceTax, closeTo(expectedTax, 0.01));
      expect(result.priceTotal, closeTo(expectedSubtotal + expectedTax, 0.01));
    });

    test('taxDetails is empty list', () {
      final result = calculator.calculateLine(
        priceUnit: 100.0,
        quantity: 1.0,
        discountPercent: 0.0,
        taxPercent: 15.0,
      );

      expect(result.taxDetails, isEmpty);
    });
  });

  group('SaleOrderLineCalculator - updateLineCalculations', () {
    final baseLine = SaleOrderLine.newProductLine(
      orderId: 1,
      productId: 100,
      productName: 'Test Product',
      priceUnit: 50.0,
      quantity: 2.0,
      discount: 0.0,
    );

    test('updates with new quantity', () {
      final updated = calculator.updateLineCalculations(
        baseLine,
        newQuantity: 5.0,
        taxPercent: 15.0,
      );

      expect(updated.productUomQty, equals(5.0));
      expect(updated.priceUnit, equals(50.0));
      expect(updated.priceSubtotal, equals(250.0));
      expect(updated.priceTax, equals(37.5));
      expect(updated.priceTotal, equals(287.5));
    });

    test('updates with new price', () {
      final updated = calculator.updateLineCalculations(
        baseLine,
        newPriceUnit: 100.0,
        taxPercent: 15.0,
      );

      expect(updated.priceUnit, equals(100.0));
      expect(updated.productUomQty, equals(2.0));
      expect(updated.priceSubtotal, equals(200.0));
    });

    test('updates with new discount', () {
      final updated = calculator.updateLineCalculations(
        baseLine,
        newDiscount: 10.0,
        taxPercent: 15.0,
      );

      expect(updated.discount, equals(10.0));
      expect(updated.priceSubtotal, equals(90.0)); // 50*2 - 10%
      expect(updated.discountAmount, equals(10.0)); // 50*2 * 10%
    });

    test('updates all fields at once', () {
      final updated = calculator.updateLineCalculations(
        baseLine,
        newPriceUnit: 200.0,
        newQuantity: 3.0,
        newDiscount: 20.0,
        taxPercent: 12.0,
      );

      expect(updated.priceUnit, equals(200.0));
      expect(updated.productUomQty, equals(3.0));
      expect(updated.discount, equals(20.0));
      expect(updated.priceSubtotal, equals(480.0)); // 200*3 - 20%
      expect(updated.priceTax, closeTo(57.6, 0.001)); // 480 * 12%
      expect(updated.priceTotal, closeTo(537.6, 0.001));
      expect(updated.discountAmount, equals(120.0)); // 200*3 * 20%
    });

    test('preserves non-updated fields', () {
      final updated = calculator.updateLineCalculations(
        baseLine,
        newQuantity: 10.0,
        taxPercent: 0.0,
      );

      expect(updated.orderId, equals(baseLine.orderId));
      expect(updated.productId, equals(baseLine.productId));
      expect(updated.productName, equals(baseLine.productName));
      expect(updated.name, equals(baseLine.name));
    });

    test('uses existing values when no overrides provided', () {
      final updated = calculator.updateLineCalculations(
        baseLine,
        taxPercent: 15.0,
      );

      // Should use baseLine's existing values
      expect(updated.priceUnit, equals(50.0));
      expect(updated.productUomQty, equals(2.0));
      expect(updated.discount, equals(0.0));
      expect(updated.priceSubtotal, equals(100.0));
      expect(updated.priceTax, equals(15.0));
      expect(updated.priceTotal, equals(115.0));
    });
  });

  group('SaleOrderLineCalculator - global instance', () {
    test('saleOrderLineCalculator is const and available', () {
      expect(saleOrderLineCalculator, isA<SaleOrderLineCalculator>());
    });

    test('saleOrderLineCalculator produces same results', () {
      final result = saleOrderLineCalculator.calculateLine(
        priceUnit: 100.0,
        quantity: 1.0,
        discountPercent: 0.0,
        taxPercent: 15.0,
      );

      expect(result.priceSubtotal, equals(100.0));
      expect(result.priceTax, equals(15.0));
      expect(result.priceTotal, equals(115.0));
    });
  });
}
