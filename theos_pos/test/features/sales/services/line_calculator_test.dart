import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/sales/services/line_calculator.dart';

import '../../../helpers/test_model_factory.dart';

void main() {
  const calculator = SaleOrderLineCalculator();
  const tolerance = 1e-6;

  setUp(() {
    resetIdCounter();
  });

  group('calculateLine', () {
    test('basic calculation: no discount, no tax', () {
      final result = calculator.calculateLine(
        priceUnit: 25.0,
        quantity: 2.0,
        discountPercent: 0.0,
        taxPercent: 0.0,
      );

      expect(result.priceSubtotal, closeTo(50.0, tolerance));
      expect(result.priceTax, closeTo(0.0, tolerance));
      expect(result.priceTotal, closeTo(50.0, tolerance));
      expect(result.discountAmount, closeTo(0.0, tolerance));
      expect(result.taxDetails, isEmpty);
    });

    test('with discount only', () {
      final result = calculator.calculateLine(
        priceUnit: 100.0,
        quantity: 1.0,
        discountPercent: 10.0,
        taxPercent: 0.0,
      );

      expect(result.priceSubtotal, closeTo(90.0, tolerance));
      expect(result.priceTax, closeTo(0.0, tolerance));
      expect(result.priceTotal, closeTo(90.0, tolerance));
      expect(result.discountAmount, closeTo(10.0, tolerance));
    });

    test('with tax only', () {
      final result = calculator.calculateLine(
        priceUnit: 100.0,
        quantity: 1.0,
        discountPercent: 0.0,
        taxPercent: 15.0,
      );

      expect(result.priceSubtotal, closeTo(100.0, tolerance));
      expect(result.priceTax, closeTo(15.0, tolerance));
      expect(result.priceTotal, closeTo(115.0, tolerance));
      expect(result.discountAmount, closeTo(0.0, tolerance));
    });

    test('with both discount and tax', () {
      final result = calculator.calculateLine(
        priceUnit: 200.0,
        quantity: 1.0,
        discountPercent: 10.0,
        taxPercent: 15.0,
      );

      // subtotalBeforeDiscount = 200
      // discountAmount = 200 * 0.10 = 20
      // subtotal = 180
      // tax = 180 * 0.15 = 27
      // total = 180 + 27 = 207
      expect(result.priceSubtotal, closeTo(180.0, tolerance));
      expect(result.priceTax, closeTo(27.0, tolerance));
      expect(result.priceTotal, closeTo(207.0, tolerance));
      expect(result.discountAmount, closeTo(20.0, tolerance));
    });

    test('zero quantity', () {
      final result = calculator.calculateLine(
        priceUnit: 50.0,
        quantity: 0.0,
        discountPercent: 10.0,
        taxPercent: 15.0,
      );

      expect(result.priceSubtotal, closeTo(0.0, tolerance));
      expect(result.priceTax, closeTo(0.0, tolerance));
      expect(result.priceTotal, closeTo(0.0, tolerance));
      expect(result.discountAmount, closeTo(0.0, tolerance));
    });

    test('zero price', () {
      final result = calculator.calculateLine(
        priceUnit: 0.0,
        quantity: 5.0,
        discountPercent: 10.0,
        taxPercent: 15.0,
      );

      expect(result.priceSubtotal, closeTo(0.0, tolerance));
      expect(result.priceTax, closeTo(0.0, tolerance));
      expect(result.priceTotal, closeTo(0.0, tolerance));
      expect(result.discountAmount, closeTo(0.0, tolerance));
    });

    test('100% discount', () {
      final result = calculator.calculateLine(
        priceUnit: 100.0,
        quantity: 3.0,
        discountPercent: 100.0,
        taxPercent: 15.0,
      );

      // subtotalBeforeDiscount = 300
      // discountAmount = 300
      // subtotal = 0
      // tax = 0
      // total = 0
      expect(result.priceSubtotal, closeTo(0.0, tolerance));
      expect(result.priceTax, closeTo(0.0, tolerance));
      expect(result.priceTotal, closeTo(0.0, tolerance));
      expect(result.discountAmount, closeTo(300.0, tolerance));
    });

    test('multiple quantities', () {
      final result = calculator.calculateLine(
        priceUnit: 25.50,
        quantity: 4.0,
        discountPercent: 5.0,
        taxPercent: 12.0,
      );

      // subtotalBeforeDiscount = 25.50 * 4 = 102.0
      // discountAmount = 102.0 * 0.05 = 5.1
      // subtotal = 102.0 - 5.1 = 96.9
      // tax = 96.9 * 0.12 = 11.628
      // total = 96.9 + 11.628 = 108.528
      expect(result.priceSubtotal, closeTo(96.9, tolerance));
      expect(result.priceTax, closeTo(11.628, tolerance));
      expect(result.priceTotal, closeTo(108.528, tolerance));
      expect(result.discountAmount, closeTo(5.1, tolerance));
    });

    test('high tax rate', () {
      final result = calculator.calculateLine(
        priceUnit: 80.0,
        quantity: 2.0,
        discountPercent: 0.0,
        taxPercent: 50.0,
      );

      // subtotal = 160
      // tax = 160 * 0.50 = 80
      // total = 160 + 80 = 240
      expect(result.priceSubtotal, closeTo(160.0, tolerance));
      expect(result.priceTax, closeTo(80.0, tolerance));
      expect(result.priceTotal, closeTo(240.0, tolerance));
      expect(result.discountAmount, closeTo(0.0, tolerance));
    });
  });

  group('updateLineCalculations', () {
    test('updates all fields when provided', () {
      final line = SaleOrderLineFactory.create(
        orderId: 1,
        priceUnit: 10.0,
        productUomQty: 1.0,
        discount: 0.0,
      );

      final updated = calculator.updateLineCalculations(
        line,
        newPriceUnit: 100.0,
        newQuantity: 3.0,
        newDiscount: 10.0,
        taxPercent: 15.0,
      );

      // subtotalBeforeDiscount = 100 * 3 = 300
      // discountAmount = 300 * 0.10 = 30
      // subtotal = 270
      // tax = 270 * 0.15 = 40.5
      // total = 270 + 40.5 = 310.5
      expect(updated.priceUnit, closeTo(100.0, tolerance));
      expect(updated.productUomQty, closeTo(3.0, tolerance));
      expect(updated.discount, closeTo(10.0, tolerance));
      expect(updated.discountAmount, closeTo(30.0, tolerance));
      expect(updated.priceSubtotal, closeTo(270.0, tolerance));
      expect(updated.priceTax, closeTo(40.5, tolerance));
      expect(updated.priceTotal, closeTo(310.5, tolerance));
    });

    test('uses line values when no overrides', () {
      final line = SaleOrderLineFactory.create(
        orderId: 1,
        priceUnit: 50.0,
        productUomQty: 2.0,
        discount: 5.0,
      );

      final updated = calculator.updateLineCalculations(
        line,
        taxPercent: 12.0,
      );

      // subtotalBeforeDiscount = 50 * 2 = 100
      // discountAmount = 100 * 0.05 = 5
      // subtotal = 95
      // tax = 95 * 0.12 = 11.4
      // total = 95 + 11.4 = 106.4
      expect(updated.priceUnit, closeTo(50.0, tolerance));
      expect(updated.productUomQty, closeTo(2.0, tolerance));
      expect(updated.discount, closeTo(5.0, tolerance));
      expect(updated.discountAmount, closeTo(5.0, tolerance));
      expect(updated.priceSubtotal, closeTo(95.0, tolerance));
      expect(updated.priceTax, closeTo(11.4, tolerance));
      expect(updated.priceTotal, closeTo(106.4, tolerance));
    });

    test('only overrides priceUnit', () {
      final line = SaleOrderLineFactory.create(
        orderId: 1,
        priceUnit: 10.0,
        productUomQty: 2.0,
        discount: 0.0,
      );

      final updated = calculator.updateLineCalculations(
        line,
        newPriceUnit: 75.0,
        taxPercent: 15.0,
      );

      // subtotalBeforeDiscount = 75 * 2 = 150
      // no discount
      // subtotal = 150
      // tax = 150 * 0.15 = 22.5
      // total = 172.5
      expect(updated.priceUnit, closeTo(75.0, tolerance));
      expect(updated.productUomQty, closeTo(2.0, tolerance));
      expect(updated.discount, closeTo(0.0, tolerance));
      expect(updated.priceSubtotal, closeTo(150.0, tolerance));
      expect(updated.priceTax, closeTo(22.5, tolerance));
      expect(updated.priceTotal, closeTo(172.5, tolerance));
    });

    test('only overrides quantity', () {
      final line = SaleOrderLineFactory.create(
        orderId: 1,
        priceUnit: 30.0,
        productUomQty: 1.0,
        discount: 0.0,
      );

      final updated = calculator.updateLineCalculations(
        line,
        newQuantity: 5.0,
        taxPercent: 12.0,
      );

      // subtotalBeforeDiscount = 30 * 5 = 150
      // no discount
      // subtotal = 150
      // tax = 150 * 0.12 = 18
      // total = 168
      expect(updated.priceUnit, closeTo(30.0, tolerance));
      expect(updated.productUomQty, closeTo(5.0, tolerance));
      expect(updated.discount, closeTo(0.0, tolerance));
      expect(updated.priceSubtotal, closeTo(150.0, tolerance));
      expect(updated.priceTax, closeTo(18.0, tolerance));
      expect(updated.priceTotal, closeTo(168.0, tolerance));
    });

    test('only overrides discount', () {
      final line = SaleOrderLineFactory.create(
        orderId: 1,
        priceUnit: 200.0,
        productUomQty: 1.0,
        discount: 0.0,
      );

      final updated = calculator.updateLineCalculations(
        line,
        newDiscount: 25.0,
        taxPercent: 15.0,
      );

      // subtotalBeforeDiscount = 200 * 1 = 200
      // discountAmount = 200 * 0.25 = 50
      // subtotal = 150
      // tax = 150 * 0.15 = 22.5
      // total = 172.5
      expect(updated.priceUnit, closeTo(200.0, tolerance));
      expect(updated.productUomQty, closeTo(1.0, tolerance));
      expect(updated.discount, closeTo(25.0, tolerance));
      expect(updated.discountAmount, closeTo(50.0, tolerance));
      expect(updated.priceSubtotal, closeTo(150.0, tolerance));
      expect(updated.priceTax, closeTo(22.5, tolerance));
      expect(updated.priceTotal, closeTo(172.5, tolerance));
    });
  });
}
