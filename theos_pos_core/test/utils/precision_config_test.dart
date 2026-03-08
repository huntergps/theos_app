import 'package:test/test.dart';
import 'package:theos_pos_core/src/utils/precision_config.dart';

void main() {
  group('PrecisionConfig - ecuadorDefaults', () {
    late PrecisionConfig config;

    setUp(() {
      config = PrecisionConfig.ecuadorDefaults();
    });

    test('quantityDigits is 3', () {
      expect(config.quantityDigits, equals(3));
    });

    test('priceDigits is 2', () {
      expect(config.priceDigits, equals(2));
    });

    test('discountDigits is 3', () {
      expect(config.discountDigits, equals(3));
    });

    test('accountDigits is 2', () {
      expect(config.accountDigits, equals(2));
    });

    test('currencySymbol is dollar sign', () {
      expect(config.currencySymbol, equals('\$'));
    });

    test('taxRoundingMethod is roundPerLine', () {
      expect(config.taxRoundingMethod, equals(TaxRoundingMethod.roundPerLine));
    });
  });

  group('PrecisionConfig - precisionFor', () {
    late PrecisionConfig config;

    setUp(() {
      config = PrecisionConfig.ecuadorDefaults();
    });

    test('returns correct precision for known usage', () {
      expect(config.precisionFor('Product Unit'), equals(3));
      expect(config.precisionFor('Product Price'), equals(2));
      expect(config.precisionFor('Discount'), equals(3));
      expect(config.precisionFor('Account'), equals(2));
    });

    test('returns default 2 for unknown usage', () {
      expect(config.precisionFor('Unknown'), equals(2));
      expect(config.precisionFor(''), equals(2));
    });
  });

  group('PrecisionConfig - MoneyRounding objects', () {
    late PrecisionConfig config;

    setUp(() {
      config = PrecisionConfig.ecuadorDefaults();
    });

    test('quantityRounding rounds to 3 decimal places', () {
      final rounding = config.quantityRounding;
      expect(rounding.round(1.2345), closeTo(1.235, 0.0001));
      expect(rounding.round(1.2344), closeTo(1.234, 0.0001));
    });

    test('priceRounding rounds to 2 decimal places', () {
      final rounding = config.priceRounding;
      expect(rounding.round(1.235), closeTo(1.24, 0.001));
      expect(rounding.round(1.234), closeTo(1.23, 0.001));
    });

    test('discountRounding rounds to 3 decimal places', () {
      final rounding = config.discountRounding;
      expect(rounding.round(10.1234), closeTo(10.123, 0.0001));
    });

    test('amountRounding rounds to 2 decimal places', () {
      final rounding = config.amountRounding;
      expect(rounding.round(99.999), closeTo(100.0, 0.001));
      expect(rounding.round(99.994), closeTo(99.99, 0.001));
    });
  });

  group('TaxRoundingMethod', () {
    test('has roundPerLine value', () {
      expect(TaxRoundingMethod.roundPerLine, isNotNull);
    });

    test('has roundGlobally value', () {
      expect(TaxRoundingMethod.roundGlobally, isNotNull);
    });

    test('values are distinct', () {
      expect(
        TaxRoundingMethod.roundPerLine,
        isNot(equals(TaxRoundingMethod.roundGlobally)),
      );
    });
  });
}
