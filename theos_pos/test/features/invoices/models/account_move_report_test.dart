import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  group('AccountMove.toReportMap', () {
    test('should calculate totals from lines when header fields are zero', () {
      // Arrange
      final line1 = AccountMoveLine(
        id: 1,
        moveId: 1,
        name: 'Product 1',
        quantity: 2.0,
        priceUnit: 100.0,
        priceSubtotal: 200.0,
        priceTotal: 230.0, // 15% tax
      );

      final line2 = AccountMoveLine(
        id: 2,
        moveId: 1,
        name: 'Product 2',
        quantity: 1.0,
        priceUnit: 50.0,
        priceSubtotal: 50.0,
        priceTotal: 57.5, // 15% tax
      );

      final move = AccountMove(
        id: 0, // Local invoice
        name: 'INV/2024/0001',
        state: 'draft',
        // Header totals are ZERO (simulating the bug/offline state)
        amountUntaxed: 0.0,
        amountTax: 0.0,
        amountTotal: 0.0,
        lines: [line1, line2],
      );

      // Act
      final reportMap = move.toReportMap();

      // Assert
      // Expected totals:
      // Untaxed: 200 + 50 = 250
      // Tax: (230-200) + (57.5-50) = 30 + 7.5 = 37.5
      // Total: 230 + 57.5 = 287.5

      expect(reportMap['amount_untaxed'], 250.0);
      expect(reportMap['amount_tax'], 37.5);
      expect(reportMap['amount_total'], 287.5);

      // Verify formatted strings
      expect(reportMap['formatted_amount_untaxed'], '\$ 250,00');
      expect(reportMap['formatted_amount_tax'], '\$ 37,50');
      expect(reportMap['formatted_amount_total'], '\$ 287,50');

      // Verify tax totals structure
      final taxTotals = reportMap['tax_totals'] as Map<String, dynamic>;
      expect(taxTotals['amount_untaxed'], 250.0);
      expect(taxTotals['amount_total'], 287.5);

      final subtotals = taxTotals['subtotals'] as List;
      expect(subtotals.length, 1);
      final subtotal = subtotals[0] as Map<String, dynamic>;
      expect(subtotal['amount'], 250.0);

      final taxGroups = subtotal['tax_groups'] as List;
      expect(taxGroups.length, 1);
      expect(taxGroups[0]['tax_amount_currency'], 37.5);

      // Verify display_taxes flag
      expect(reportMap['display_taxes'], true);
    });

    test('should use header fields when they are present', () {
      // Arrange
      final line1 = AccountMoveLine(
        id: 1,
        moveId: 1,
        name: 'Product 1',
        quantity: 1.0,
        priceUnit: 100.0,
        priceSubtotal: 100.0,
        priceTotal: 100.0,
      );

      final move = AccountMove(
        id: 100, // Sync invoice
        name: 'INV/2024/0002',
        state: 'posted',
        // Header totals are SET
        amountUntaxed: 500.0,
        amountTax: 50.0,
        amountTotal: 550.0,
        lines: [
          line1,
        ], // Lines don't match header (unrealistic but good for test)
      );

      // Act
      final reportMap = move.toReportMap();

      // Assert
      // Should use header values, NOT calculated values from lines
      expect(reportMap['amount_untaxed'], 500.0);
      expect(reportMap['amount_tax'], 50.0);
      expect(reportMap['amount_total'], 550.0);
    });
  });
}
