import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show MoneyRounding;

void main() {
  group('MoneyRounding', () {
    test('rounds correctly with default precision (2)', () {
      final rounding = MoneyRounding.fromDigits(2);

      expect(rounding.round(2.675), 2.68); // Half up
      expect(rounding.round(2.674), 2.67);
      expect(rounding.round(2.676), 2.68);
      expect(rounding.round(2.671), 2.67);
      expect(rounding.round(2.6), 2.60);
    });

    test('rounds correctly with precision 3', () {
      final rounding = MoneyRounding.fromDigits(3);

      expect(rounding.round(2.6755), closeTo(2.676, 0.00001));
      expect(rounding.round(2.6754), closeTo(2.675, 0.00001));
    });

    test('rounds negative numbers correctly', () {
      final rounding = MoneyRounding.fromDigits(2);

      expect(rounding.round(-2.675), -2.68);
      expect(rounding.round(-2.674), -2.67);
    });

    test('isZero works with epsilon', () {
      final rounding = MoneyRounding.fromDigits(2);

      expect(rounding.isZero(0.00001), isTrue);
      expect(rounding.isZero(0.01), isFalse);
    });

    test('compare works correctly', () {
      final rounding = MoneyRounding.fromDigits(2);

      expect(
        rounding.compare(10.001, 10.002),
        0,
      ); // Effectively equal at precision 2
      expect(rounding.compare(10.01, 10.02), -1);
      expect(rounding.compare(10.02, 10.01), 1);
    });

    test('roundTo works similar to round', () {
      // static method check
      expect(MoneyRounding.roundTo(2.675, 2), 2.68);
    });
  });
}
