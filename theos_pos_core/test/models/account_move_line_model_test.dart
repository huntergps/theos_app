import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/invoices/account_move_line.model.dart';

void main() {
  group('AccountMoveLine - fromOdoo', () {
    test('parses typical product line', () {
      final json = {
        'id': 1,
        'move_id': [100, 'INV/2024/0001'],
        'name': '[LAP001] Laptop HP',
        'display_type': false,
        'sequence': 10,
        'product_id': [42, '[LAP001] Laptop HP ProBook'],
        'quantity': 2.0,
        'product_uom_id': [1, 'Unidades'],
        'price_unit': 500.0,
        'discount': 10.0,
        'price_subtotal': 900.0,
        'price_total': 1035.0,
        'tax_ids': [
          [1, 'IVA 15%'],
        ],
        'tax_line_id': false,
        'account_id': [5, '4.1.01 Ventas'],
        'collapse_composition': false,
        'collapse_prices': true,
      };

      final line = accountMoveLineManager.fromOdoo(json);

      expect(line.id, equals(1));
      expect(line.moveId, equals(100));
      expect(line.name, equals('[LAP001] Laptop HP'));
      expect(line.displayType, equals(InvoiceLineDisplayType.product));
      expect(line.sequence, equals(10));
      expect(line.productId, equals(42));
      // extractMany2oneName returns the name as-is (no bracket stripping)
      expect(line.productName, equals('[LAP001] Laptop HP ProBook'));
      // productCode is a local-only field, not populated by generated fromOdoo
      expect(line.productCode, isNull);
      expect(line.quantity, equals(2.0));
      expect(line.productUomId, equals(1));
      expect(line.productUomName, equals('Unidades'));
      expect(line.priceUnit, equals(500.0));
      expect(line.discount, equals(10.0));
      expect(line.priceSubtotal, equals(900.0));
      expect(line.priceTotal, equals(1035.0));
      // taxIds/taxNames are local-only fields, not populated by generated fromOdoo
      expect(line.taxIds, isNull);
      expect(line.taxNames, isNull);
      expect(line.accountId, equals(5));
      expect(line.accountName, equals('4.1.01 Ventas'));
      expect(line.collapseComposition, isFalse);
      expect(line.collapsePrices, isTrue);
    });

    test('parses product_id with code in brackets (name as-is)', () {
      final json = {
        'id': 1,
        'product_id': [10, '[CODE01] Product Name'],
      };

      final line = accountMoveLineManager.fromOdoo(json);
      expect(line.productId, equals(10));
      // productCode is local-only, not extracted from brackets
      expect(line.productCode, isNull);
      // productName is the full many2one name
      expect(line.productName, equals('[CODE01] Product Name'));
    });

    test('parses product_id without code brackets', () {
      final json = {
        'id': 1,
        'product_id': [10, 'Simple Product Name'],
      };

      final line = accountMoveLineManager.fromOdoo(json);
      expect(line.productId, equals(10));
      expect(line.productCode, isNull);
      expect(line.productName, equals('Simple Product Name'));
    });

    test('handles false product_id', () {
      final json = {
        'id': 1,
        'product_id': false,
      };

      final line = accountMoveLineManager.fromOdoo(json);
      expect(line.productId, isNull);
      expect(line.productName, isNull);
    });

    test('parses move_id as integer', () {
      final json = {
        'id': 1,
        'move_id': 50,
      };

      final line = accountMoveLineManager.fromOdoo(json);
      expect(line.moveId, equals(50));
    });

    test('taxIds is not populated by generated fromOdoo (local-only field)', () {
      final json = {
        'id': 1,
        'tax_ids': [
          [1, 'IVA 15%'],
          [2, 'ICE 10%'],
        ],
      };

      final line = accountMoveLineManager.fromOdoo(json);
      // taxIds/taxNames are local-only fields, not parsed by generated fromOdoo
      expect(line.taxIds, isNull);
      expect(line.taxNames, isNull);
    });

    test('taxIds remains null for plain integer list', () {
      final json = {
        'id': 1,
        'tax_ids': [1, 2, 3],
      };

      final line = accountMoveLineManager.fromOdoo(json);
      expect(line.taxIds, isNull);
    });

    test('handles empty tax_ids', () {
      final json = {
        'id': 1,
        'tax_ids': [],
      };

      final line = accountMoveLineManager.fromOdoo(json);
      expect(line.taxIds, isNull);
      expect(line.taxNames, isNull);
    });
  });

  group('AccountMoveLine - Display Type Parsing', () {
    test('false/null/empty maps to product', () {
      expect(
        AccountMoveLine.parseDisplayType(null),
        equals(InvoiceLineDisplayType.product),
      );
      expect(
        AccountMoveLine.parseDisplayType(''),
        equals(InvoiceLineDisplayType.product),
      );
    });

    test('line_section maps correctly', () {
      expect(
        AccountMoveLine.parseDisplayType('line_section'),
        equals(InvoiceLineDisplayType.lineSection),
      );
    });

    test('line_note maps correctly', () {
      expect(
        AccountMoveLine.parseDisplayType('line_note'),
        equals(InvoiceLineDisplayType.lineNote),
      );
    });

    test('tax maps correctly', () {
      expect(
        AccountMoveLine.parseDisplayType('tax'),
        equals(InvoiceLineDisplayType.tax),
      );
    });

    test('payment_term maps correctly', () {
      expect(
        AccountMoveLine.parseDisplayType('payment_term'),
        equals(InvoiceLineDisplayType.paymentTerm),
      );
    });

    test('cogs maps correctly', () {
      expect(
        AccountMoveLine.parseDisplayType('cogs'),
        equals(InvoiceLineDisplayType.cogs),
      );
    });

    test('unknown value defaults to product', () {
      expect(
        AccountMoveLine.parseDisplayType('unknown'),
        equals(InvoiceLineDisplayType.product),
      );
    });
  });

  group('AccountMoveLine - Computed Properties', () {
    test('isProductLine for default display type', () {
      const line = AccountMoveLine();
      expect(line.isProductLine, isTrue);
      expect(line.isSection, isFalse);
      expect(line.isNote, isFalse);
      expect(line.isTaxLine, isFalse);
    });

    test('isSection for line_section display type', () {
      const line = AccountMoveLine(displayType: InvoiceLineDisplayType.lineSection);
      expect(line.isSection, isTrue);
      expect(line.isProductLine, isFalse);
    });

    test('isNote for line_note display type', () {
      const line = AccountMoveLine(displayType: InvoiceLineDisplayType.lineNote);
      expect(line.isNote, isTrue);
    });

    test('isTaxLine for tax display type', () {
      const line = AccountMoveLine(displayType: InvoiceLineDisplayType.tax);
      expect(line.isTaxLine, isTrue);
    });

    test('isReportLine excludes cogs and payment_term', () {
      expect(const AccountMoveLine().isReportLine, isTrue);
      expect(
        const AccountMoveLine(displayType: InvoiceLineDisplayType.lineSection).isReportLine,
        isTrue,
      );
      expect(
        const AccountMoveLine(displayType: InvoiceLineDisplayType.cogs).isReportLine,
        isFalse,
      );
      expect(
        const AccountMoveLine(displayType: InvoiceLineDisplayType.paymentTerm).isReportLine,
        isFalse,
      );
    });

    test('displayTypeString roundtrip', () {
      for (final type in InvoiceLineDisplayType.values) {
        final line = AccountMoveLine(displayType: type);
        final str = line.displayTypeString;
        // Verify that all types produce a non-empty string
        expect(str, isNotEmpty, reason: '$type should have a string representation');
      }
    });
  });

  group('AccountMoveLine - Validation', () {
    test('validateFor invoice fails with zero quantity', () {
      const line = AccountMoveLine(
        displayType: InvoiceLineDisplayType.product,
        quantity: 0.0,
        priceUnit: 100.0,
      );
      final errors = line.validateFor('invoice');
      expect(errors.containsKey('quantity'), isTrue);
    });

    test('validateFor invoice fails with negative price', () {
      const line = AccountMoveLine(
        displayType: InvoiceLineDisplayType.product,
        quantity: 1.0,
        priceUnit: -10.0,
      );
      final errors = line.validateFor('invoice');
      expect(errors.containsKey('priceUnit'), isTrue);
    });

    test('validateFor invoice passes for valid product line', () {
      const line = AccountMoveLine(
        displayType: InvoiceLineDisplayType.product,
        quantity: 2.0,
        priceUnit: 50.0,
      );
      final errors = line.validateFor('invoice');
      expect(errors, isEmpty);
    });

    test('validateFor invoice skips non-product lines', () {
      const line = AccountMoveLine(
        displayType: InvoiceLineDisplayType.lineSection,
        name: 'Section Header',
        quantity: 0.0,
        priceUnit: 0.0,
      );
      final errors = line.validateFor('invoice');
      expect(errors, isEmpty);
    });
  });

  group('AccountMoveLine - toOdoo', () {
    test('produces correct Odoo format', () {
      const line = AccountMoveLine(
        name: 'Test Line',
        quantity: 3.0,
        priceUnit: 100.0,
        discount: 5.0,
        productId: 42,
        productUomId: 1,
      );

      final odoo = accountMoveLineManager.toOdoo(line);

      expect(odoo['name'], equals('Test Line'));
      expect(odoo['quantity'], equals(3.0));
      expect(odoo['price_unit'], equals(100.0));
      expect(odoo['discount'], equals(5.0));
      expect(odoo['product_id'], equals(42));
      expect(odoo['product_uom_id'], equals(1));
    });

    test('includes all fields (including null ones)', () {
      const line = AccountMoveLine(name: 'Test', quantity: 1.0, priceUnit: 10.0);
      final odoo = accountMoveLineManager.toOdoo(line);

      // Generated toOdoo includes all fields
      expect(odoo.containsKey('product_id'), isTrue);
      expect(odoo['product_id'], isNull);
      expect(odoo.containsKey('product_uom_id'), isTrue);
      expect(odoo['product_uom_id'], isNull);
    });
  });
}
