import 'package:test/test.dart';
import 'package:theos_pos_core/src/services/taxes/tax_calculator_service.dart';

void main() {
  group('TaxCalculatorService - Static Utilities', () {
    group('simplifyTaxName', () {
      test('removes parenthetical percentage', () {
        expect(
          TaxCalculatorService.simplifyTaxName('IVA 15% (15%)'),
          equals('IVA 15%'),
        );
      });

      test('handles complex names', () {
        expect(
          TaxCalculatorService.simplifyTaxName('IVA 0% Venta Bienes (0%)'),
          equals('IVA 0% Venta Bienes'),
        );
      });

      test('returns same string if no parentheses', () {
        expect(
          TaxCalculatorService.simplifyTaxName('IVA 15%'),
          equals('IVA 15%'),
        );
      });

      test('handles empty string', () {
        expect(TaxCalculatorService.simplifyTaxName(''), equals(''));
      });
    });

    group('getFirstSimplifiedTaxName', () {
      test('returns first tax from comma-separated list', () {
        expect(
          TaxCalculatorService.getFirstSimplifiedTaxName('IVA 15% (15%), IVA 0% (0%)'),
          equals('IVA 15%'),
        );
      });

      test('handles null', () {
        expect(TaxCalculatorService.getFirstSimplifiedTaxName(null), equals(''));
      });

      test('handles empty string', () {
        expect(TaxCalculatorService.getFirstSimplifiedTaxName(''), equals(''));
      });

      test('handles single tax', () {
        expect(
          TaxCalculatorService.getFirstSimplifiedTaxName('IVA 12% (12%)'),
          equals('IVA 12%'),
        );
      });
    });

    group('simplifyAllTaxNames', () {
      test('simplifies all names in list', () {
        expect(
          TaxCalculatorService.simplifyAllTaxNames('IVA 15% (15%), IVA 0% (0%)'),
          equals('IVA 15%, IVA 0%'),
        );
      });

      test('handles null', () {
        expect(TaxCalculatorService.simplifyAllTaxNames(null), equals(''));
      });
    });

    group('parseTaxIds', () {
      test('parses comma-separated IDs', () {
        expect(TaxCalculatorService.parseTaxIds('1,2,3'), equals([1, 2, 3]));
      });

      test('handles spaces', () {
        expect(TaxCalculatorService.parseTaxIds('1, 2, 3'), equals([1, 2, 3]));
      });

      test('handles null', () {
        expect(TaxCalculatorService.parseTaxIds(null), isEmpty);
      });

      test('handles empty string', () {
        expect(TaxCalculatorService.parseTaxIds(''), isEmpty);
      });

      test('skips non-integer values', () {
        expect(TaxCalculatorService.parseTaxIds('1, abc, 3'), equals([1, 3]));
      });
    });

    group('taxIdsToString', () {
      test('converts list to comma-separated string', () {
        expect(TaxCalculatorService.taxIdsToString([1, 2, 3]), equals('1,2,3'));
      });

      test('handles empty list', () {
        expect(TaxCalculatorService.taxIdsToString([]), equals(''));
      });

      test('handles single ID', () {
        expect(TaxCalculatorService.taxIdsToString([42]), equals('42'));
      });
    });

    group('hasTaxes', () {
      test('returns true with tax list', () {
        expect(
          TaxCalculatorService.hasTaxes(
            taxList: [{'id': 1, 'name': 'IVA'}],
          ),
          isTrue,
        );
      });

      test('returns true with positive priceTax', () {
        expect(
          TaxCalculatorService.hasTaxes(priceTax: 15.0),
          isTrue,
        );
      });

      test('returns false with empty list and zero tax', () {
        expect(
          TaxCalculatorService.hasTaxes(taxList: [], priceTax: 0.0),
          isFalse,
        );
      });

      test('returns false with null values', () {
        expect(TaxCalculatorService.hasTaxes(), isFalse);
      });
    });

    group('buildTaxListForReport', () {
      test('builds list from taxDataMap', () {
        final result = TaxCalculatorService.buildTaxListForReport(
          taxIds: '1,2',
          taxDataMap: {
            1: {'name': 'IVA 15%', 'amount': 15.0},
            2: {'name': 'IVA 0%', 'amount': 0.0},
          },
        );
        expect(result, hasLength(2));
        expect(result[0]['name'], equals('IVA 15%'));
        expect(result[0]['amount'], equals(15.0));
        expect(result[1]['name'], equals('IVA 0%'));
      });

      test('falls back to taxNames when no taxDataMap', () {
        final result = TaxCalculatorService.buildTaxListForReport(
          taxIds: '1,2',
          taxNames: 'IVA 15%, IVA 0%',
        );
        expect(result, hasLength(2));
        expect(result[0]['name'], equals('IVA 15%'));
        expect(result[0]['id'], equals(1));
        expect(result[1]['name'], equals('IVA 0%'));
        expect(result[1]['id'], equals(2));
      });

      test('returns empty list with no data', () {
        final result = TaxCalculatorService.buildTaxListForReport();
        expect(result, isEmpty);
      });
    });

    group('groupTaxesByName', () {
      test('groups lines by tax name', () {
        final lines = [
          const TaxLineData(taxNames: 'IVA 15% (15%)', baseAmount: 100.0, taxAmount: 15.0),
          const TaxLineData(taxNames: 'IVA 15% (15%)', baseAmount: 200.0, taxAmount: 30.0),
          const TaxLineData(taxNames: 'IVA 0% (0%)', baseAmount: 50.0, taxAmount: 0.0),
        ];
        final groups = TaxCalculatorService.groupTaxesByName(lines);
        expect(groups, hasLength(2));
        expect(groups['IVA 15%']!.base, equals(300.0));
        expect(groups['IVA 15%']!.amount, equals(45.0));
        expect(groups['IVA 0%']!.base, equals(50.0));
        expect(groups['IVA 0%']!.amount, equals(0.0));
      });

      test('uses generic name for unnamed taxes with amount', () {
        final lines = [
          const TaxLineData(baseAmount: 100.0, taxAmount: 10.0),
        ];
        final groups = TaxCalculatorService.groupTaxesByName(lines);
        expect(groups.containsKey('Impuestos'), isTrue);
      });

      test('uses IVA 0% for unnamed taxes without amount', () {
        final lines = [
          const TaxLineData(baseAmount: 100.0, taxAmount: 0.0),
        ];
        final groups = TaxCalculatorService.groupTaxesByName(lines);
        expect(groups.containsKey('IVA 0%'), isTrue);
      });

      test('handles empty list', () {
        final groups = TaxCalculatorService.groupTaxesByName([]);
        expect(groups, isEmpty);
      });
    });
  });

  group('LineAmountResult', () {
    test('toString includes all fields', () {
      const result = LineAmountResult(
        priceSubtotal: 100.0,
        priceTax: 15.0,
        priceTotal: 115.0,
        discountAmount: 0.0,
        taxDetails: [],
      );
      final str = result.toString();
      expect(str, contains('100.0'));
      expect(str, contains('15.0'));
      expect(str, contains('115.0'));
    });
  });

  group('TaxInfo', () {
    test('empty factory creates zeroed instance', () {
      final info = TaxInfo.empty();
      expect(info.taxIds, isEmpty);
      expect(info.taxNames, isEmpty);
      expect(info.taxPercent, equals(0.0));
      expect(info.taxes, isEmpty);
      expect(info.isEmpty, isTrue);
      expect(info.isNotEmpty, isFalse);
    });
  });

  group('OrderTotalsResult', () {
    test('toString includes amounts', () {
      const totals = OrderTotalsResult(
        amountUntaxed: 1000.0,
        amountTax: 150.0,
        amountTotal: 1150.0,
        totalDiscountAmount: 50.0,
      );
      final str = totals.toString();
      expect(str, contains('1000.0'));
      expect(str, contains('150.0'));
      expect(str, contains('1150.0'));
    });
  });
}
