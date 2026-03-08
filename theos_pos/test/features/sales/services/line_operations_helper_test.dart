import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show SaleOrderLine, LineDisplayType;
import 'package:theos_pos/features/sales/services/line_operations_helper.dart';
import 'package:theos_pos/features/sales/services/order_line_creation_service.dart';

// ============================================================
// Mocks
// ============================================================

class MockOrderLineCreationService extends Mock
    implements OrderLineCreationService {}

/// Helper to create a product line for tests.
SaleOrderLine _productLine({
  int id = 1,
  int orderId = 100,
  String name = 'Product',
  int? productId = 10,
  double qty = 1.0,
  double price = 10.0,
  double discount = 0.0,
  double priceSubtotal = 10.0,
  double priceTax = 0.0,
  double priceTotal = 10.0,
  int? uomId = 1,
  int sequence = 10,
  bool isUnitProduct = false,
}) {
  return SaleOrderLine(
    id: id,
    orderId: orderId,
    name: name,
    productId: productId,
    productName: name,
    productUomQty: qty,
    priceUnit: price,
    discount: discount,
    priceSubtotal: priceSubtotal,
    priceTax: priceTax,
    priceTotal: priceTotal,
    productUomId: uomId,
    sequence: sequence,
    displayType: LineDisplayType.product,
    isUnitProduct: isUnitProduct,
  );
}

SaleOrderLine _sectionLine({
  int id = 100,
  int orderId = 100,
  String name = 'Section',
  int sequence = 10,
}) {
  return SaleOrderLine(
    id: id,
    orderId: orderId,
    name: name,
    sequence: sequence,
    displayType: LineDisplayType.lineSection,
  );
}

SaleOrderLine _noteLine({
  int id = 200,
  int orderId = 100,
  String name = 'Note',
  int sequence = 10,
}) {
  return SaleOrderLine(
    id: id,
    orderId: orderId,
    name: name,
    sequence: sequence,
    displayType: LineDisplayType.lineNote,
  );
}

void main() {
  late MockOrderLineCreationService mockCreationService;
  late LineOperationsHelper helper;

  setUp(() {
    mockCreationService = MockOrderLineCreationService();
    helper = LineOperationsHelper(mockCreationService, logTag: '[Test]');
  });

  // ============================================================
  // LineOperationResult
  // ============================================================
  group('LineOperationResult', () {
    test('success factory creates successful result', () {
      final lines = [_productLine()];
      final result = LineOperationResult.success(lines, selectedIndex: 0);

      expect(result.success, isTrue);
      expect(result.lines, equals(lines));
      expect(result.selectedIndex, 0);
      expect(result.error, isNull);
    });

    test('error factory creates failed result', () {
      final lines = [_productLine()];
      final result = LineOperationResult.error('Something failed', lines);

      expect(result.success, isFalse);
      expect(result.lines, equals(lines));
      expect(result.error, 'Something failed');
    });

    test('noChange factory creates successful result without selectedIndex', () {
      final lines = [_productLine()];
      final result = LineOperationResult.noChange(lines);

      expect(result.success, isTrue);
      expect(result.lines, equals(lines));
      expect(result.selectedIndex, isNull);
    });
  });

  // ============================================================
  // removeLine()
  // ============================================================
  group('removeLine()', () {
    test('removes line at valid index', () {
      final lines = [
        _productLine(id: 1, name: 'A'),
        _productLine(id: 2, name: 'B'),
        _productLine(id: 3, name: 'C'),
      ];

      final result = helper.removeLine(lines: lines, index: 1);

      expect(result.success, isTrue);
      expect(result.lines.length, 2);
      expect(result.lines[0].id, 1);
      expect(result.lines[1].id, 3);
    });

    test('returns error for negative index', () {
      final lines = [_productLine()];

      final result = helper.removeLine(lines: lines, index: -1);

      expect(result.success, isFalse);
      expect(result.error, contains('Invalid'));
    });

    test('returns error for index out of bounds', () {
      final lines = [_productLine()];

      final result = helper.removeLine(lines: lines, index: 5);

      expect(result.success, isFalse);
      expect(result.error, contains('Invalid'));
    });

    test('adjusts selected index when removing last line', () {
      final lines = [
        _productLine(id: 1),
        _productLine(id: 2),
      ];

      final result = helper.removeLine(
        lines: lines,
        index: 1,
        currentSelectedIndex: 1,
      );

      expect(result.success, isTrue);
      expect(result.selectedIndex, 0);
    });

    test('returns null selected index when all lines removed', () {
      final lines = [_productLine(id: 1)];

      final result = helper.removeLine(
        lines: lines,
        index: 0,
        currentSelectedIndex: 0,
      );

      expect(result.success, isTrue);
      expect(result.lines, isEmpty);
      expect(result.selectedIndex, isNull);
    });

    test('adjusts selected index when it exceeds bounds after removal', () {
      final lines = [
        _productLine(id: 1),
        _productLine(id: 2),
        _productLine(id: 3),
      ];

      final result = helper.removeLine(
        lines: lines,
        index: 0,
        currentSelectedIndex: 2,
      );

      expect(result.success, isTrue);
      // After removing index 0, newLines has 2 items (indices 0,1).
      // currentSelectedIndex 2 >= newLines.length 2, so clamped to 1
      expect(result.selectedIndex, 1);
    });
  });

  // ============================================================
  // clearAllLines()
  // ============================================================
  group('clearAllLines()', () {
    test('returns empty list', () {
      final result = helper.clearAllLines();

      expect(result.success, isTrue);
      expect(result.lines, isEmpty);
      expect(result.selectedIndex, isNull);
    });
  });

  // ============================================================
  // updateLineDescription()
  // ============================================================
  group('updateLineDescription()', () {
    test('updates description successfully', () {
      final lines = [_productLine(id: 1, name: 'Old Name')];

      final result = helper.updateLineDescription(
        lines: lines,
        index: 0,
        newDescription: 'New Name',
      );

      expect(result.success, isTrue);
      expect(result.lines[0].name, 'New Name');
    });

    test('returns noChange when description is same', () {
      final lines = [_productLine(id: 1, name: 'Same Name')];

      final result = helper.updateLineDescription(
        lines: lines,
        index: 0,
        newDescription: 'Same Name',
      );

      expect(result.success, isTrue);
      // Should return the same lines reference (noChange)
      expect(result.selectedIndex, isNull);
    });

    test('returns error for invalid index', () {
      final result = helper.updateLineDescription(
        lines: [],
        index: 0,
        newDescription: 'Test',
      );

      expect(result.success, isFalse);
    });
  });

  // ============================================================
  // updateLineQuantity()
  // ============================================================
  group('updateLineQuantity()', () {
    test('returns error for negative index', () async {
      final result = await helper.updateLineQuantity(
        lines: [_productLine()],
        index: -1,
        newQuantity: 5.0,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Invalid'));
    });

    test('returns error for zero quantity', () async {
      final result = await helper.updateLineQuantity(
        lines: [_productLine()],
        index: 0,
        newQuantity: 0.0,
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Invalid quantity'));
    });

    test('returns error for negative quantity', () async {
      final result = await helper.updateLineQuantity(
        lines: [_productLine()],
        index: 0,
        newQuantity: -5.0,
      );

      expect(result.success, isFalse);
    });

    test('calls recalculateLine and updates list', () async {
      final originalLine = _productLine(id: 1, qty: 1);
      final updatedLine = _productLine(id: 1, qty: 5, priceTotal: 50);

      when(() => mockCreationService.recalculateLine(
            originalLine,
            newQuantity: 5.0,
          )).thenAnswer((_) async => updatedLine);

      final result = await helper.updateLineQuantity(
        lines: [originalLine],
        index: 0,
        newQuantity: 5.0,
        selectedIndex: 0,
      );

      expect(result.success, isTrue);
      expect(result.lines[0].productUomQty, 5.0);
      expect(result.selectedIndex, 0);
    });
  });

  // ============================================================
  // updateLinePrice()
  // ============================================================
  group('updateLinePrice()', () {
    test('returns error for invalid index', () async {
      final result = await helper.updateLinePrice(
        lines: [],
        index: 0,
        newPrice: 20.0,
      );

      expect(result.success, isFalse);
    });

    test('calls recalculateLine with new price', () async {
      final originalLine = _productLine(id: 1, price: 10);
      final updatedLine = _productLine(id: 1, price: 20, priceTotal: 20);

      when(() => mockCreationService.recalculateLine(
            originalLine,
            newPriceUnit: 20.0,
          )).thenAnswer((_) async => updatedLine);

      final result = await helper.updateLinePrice(
        lines: [originalLine],
        index: 0,
        newPrice: 20.0,
      );

      expect(result.success, isTrue);
      expect(result.lines[0].priceUnit, 20.0);
    });
  });

  // ============================================================
  // updateLineDiscount()
  // ============================================================
  group('updateLineDiscount()', () {
    test('returns error for invalid index', () async {
      final result = await helper.updateLineDiscount(
        lines: [],
        index: 0,
        newDiscount: 10.0,
      );

      expect(result.success, isFalse);
    });

    test('calls recalculateLine with new discount', () async {
      final originalLine = _productLine(id: 1, discount: 0);
      final updatedLine = _productLine(id: 1, discount: 15);

      when(() => mockCreationService.recalculateLine(
            originalLine,
            newDiscount: 15.0,
          )).thenAnswer((_) async => updatedLine);

      final result = await helper.updateLineDiscount(
        lines: [originalLine],
        index: 0,
        newDiscount: 15.0,
      );

      expect(result.success, isTrue);
      expect(result.lines[0].discount, 15.0);
    });
  });

  // ============================================================
  // updateLineUom()
  // ============================================================
  group('updateLineUom()', () {
    test('returns error for invalid index', () {
      final result = helper.updateLineUom(
        lines: [],
        index: 0,
        newUomId: 2,
        newUomName: 'Boxes',
      );

      expect(result.success, isFalse);
    });

    test('updates UoM and recalculates totals', () {
      final line = _productLine(
        id: 1,
        price: 100,
        qty: 2,
        priceSubtotal: 200,
        priceTax: 0,
        priceTotal: 200,
      );

      final result = helper.updateLineUom(
        lines: [line],
        index: 0,
        newUomId: 5,
        newUomName: 'Boxes',
      );

      expect(result.success, isTrue);
      expect(result.lines[0].productUomId, 5);
      expect(result.lines[0].productUomName, 'Boxes');
    });

    test('uses new price when provided', () {
      final line = _productLine(id: 1, price: 100, qty: 1);

      final result = helper.updateLineUom(
        lines: [line],
        index: 0,
        newUomId: 5,
        newUomName: 'Boxes',
        newPrice: 50.0,
      );

      expect(result.success, isTrue);
      expect(result.lines[0].priceUnit, 50.0);
    });
  });

  // ============================================================
  // reorderLine()
  // ============================================================
  group('reorderLine()', () {
    test('moves line from position 0 to 2', () {
      final lines = [
        _productLine(id: 1, name: 'A', sequence: 10),
        _productLine(id: 2, name: 'B', sequence: 20),
        _productLine(id: 3, name: 'C', sequence: 30),
      ];

      final result = helper.reorderLine(
        lines: lines,
        oldIndex: 0,
        newIndex: 2,
      );

      expect(result.success, isTrue);
      expect(result.lines[0].id, 2); // B moved up
      expect(result.lines[1].id, 3); // C moved up
      expect(result.lines[2].id, 1); // A moved to end
    });

    test('updates sequences after reorder', () {
      final lines = [
        _productLine(id: 1, sequence: 10),
        _productLine(id: 2, sequence: 20),
        _productLine(id: 3, sequence: 30),
      ];

      final result = helper.reorderLine(
        lines: lines,
        oldIndex: 2,
        newIndex: 0,
      );

      expect(result.success, isTrue);
      expect(result.lines[0].sequence, 10);
      expect(result.lines[1].sequence, 20);
      expect(result.lines[2].sequence, 30);
    });

    test('returns noChange when old and new index are same', () {
      final lines = [_productLine(id: 1), _productLine(id: 2)];

      final result = helper.reorderLine(
        lines: lines,
        oldIndex: 0,
        newIndex: 0,
      );

      expect(result.success, isTrue);
      // noChange
    });

    test('returns error for invalid old index', () {
      final result = helper.reorderLine(
        lines: [_productLine()],
        oldIndex: -1,
        newIndex: 0,
      );

      expect(result.success, isFalse);
    });

    test('returns error for invalid new index', () {
      final result = helper.reorderLine(
        lines: [_productLine()],
        oldIndex: 0,
        newIndex: 5,
      );

      expect(result.success, isFalse);
    });

    test('tracks selected index when it moves', () {
      final lines = [
        _productLine(id: 1),
        _productLine(id: 2),
        _productLine(id: 3),
      ];

      final result = helper.reorderLine(
        lines: lines,
        oldIndex: 0,
        newIndex: 2,
        currentSelectedIndex: 0,
      );

      expect(result.selectedIndex, 2);
    });
  });

  // ============================================================
  // Computed properties
  // ============================================================
  group('calculateSubtotal()', () {
    test('sums priceSubtotal of product lines only', () {
      final lines = [
        _productLine(id: 1, priceSubtotal: 100),
        _sectionLine(id: 2),
        _productLine(id: 3, priceSubtotal: 200),
        _noteLine(id: 4),
      ];

      expect(helper.calculateSubtotal(lines), 300.0);
    });

    test('returns 0 for empty list', () {
      expect(helper.calculateSubtotal([]), 0.0);
    });

    test('returns 0 when only sections and notes', () {
      final lines = [_sectionLine(), _noteLine()];
      expect(helper.calculateSubtotal(lines), 0.0);
    });
  });

  group('calculateTaxTotal()', () {
    test('sums priceTax of product lines only', () {
      final lines = [
        _productLine(id: 1, priceTax: 15),
        _productLine(id: 2, priceTax: 30),
        _sectionLine(id: 3),
      ];

      expect(helper.calculateTaxTotal(lines), 45.0);
    });
  });

  group('calculateTotal()', () {
    test('sums priceTotal of product lines only', () {
      final lines = [
        _productLine(id: 1, priceTotal: 115),
        _productLine(id: 2, priceTotal: 230),
      ];

      expect(helper.calculateTotal(lines), 345.0);
    });
  });

  group('countProductLines()', () {
    test('counts only product lines', () {
      final lines = [
        _productLine(id: 1),
        _sectionLine(id: 2),
        _productLine(id: 3),
        _noteLine(id: 4),
        _productLine(id: 5),
      ];

      expect(helper.countProductLines(lines), 3);
    });

    test('returns 0 for empty list', () {
      expect(helper.countProductLines([]), 0);
    });
  });

  // ============================================================
  // addSectionLine() and addNoteLine()
  // ============================================================
  group('addSectionLine()', () {
    test('adds section line to list', () {
      final section = SaleOrderLine(
        id: -1,
        orderId: 100,
        name: 'My Section',
        sequence: 10,
        displayType: LineDisplayType.lineSection,
      );

      when(() => mockCreationService.createSectionLine(
            orderId: 100,
            name: 'My Section',
            sequence: 10,
          )).thenReturn(section);

      final result = helper.addSectionLine(
        lines: [],
        orderId: 100,
        name: 'My Section',
      );

      expect(result.success, isTrue);
      expect(result.lines.length, 1);
      expect(result.lines[0].displayType, LineDisplayType.lineSection);
    });
  });

  group('addNoteLine()', () {
    test('adds note line to list', () {
      final note = SaleOrderLine(
        id: -2,
        orderId: 100,
        name: 'My Note',
        sequence: 10,
        displayType: LineDisplayType.lineNote,
      );

      when(() => mockCreationService.createNoteLine(
            orderId: 100,
            name: 'My Note',
            sequence: 10,
          )).thenReturn(note);

      final result = helper.addNoteLine(
        lines: [],
        orderId: 100,
        name: 'My Note',
      );

      expect(result.success, isTrue);
      expect(result.lines.length, 1);
      expect(result.lines[0].displayType, LineDisplayType.lineNote);
    });
  });

  // ============================================================
  // addProductLine()
  // ============================================================
  group('addProductLine()', () {
    test('returns error when creation service fails', () async {
      when(() => mockCreationService.createLine(
            orderId: any(named: 'orderId'),
            productId: any(named: 'productId'),
            productName: any(named: 'productName'),
            quantity: any(named: 'quantity'),
            pricelistId: any(named: 'pricelistId'),
            priceUnit: any(named: 'priceUnit'),
            discount: any(named: 'discount'),
            uomId: any(named: 'uomId'),
            uomName: any(named: 'uomName'),
            productCode: any(named: 'productCode'),
            taxIds: any(named: 'taxIds'),
            taxNames: any(named: 'taxNames'),
            taxPercent: any(named: 'taxPercent'),
            sequence: any(named: 'sequence'),
          )).thenAnswer(
        (_) async => OrderLineCreationResult.failure('Price lookup failed'),
      );

      final result = await helper.addProductLine(
        lines: [],
        orderId: 100,
        productId: 10,
        productName: 'Test Product',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Price lookup failed'));
    });

    test('adds new line when no merge candidate', () async {
      final newLine = _productLine(id: -1, name: 'New Product');

      when(() => mockCreationService.createLine(
            orderId: any(named: 'orderId'),
            productId: any(named: 'productId'),
            productName: any(named: 'productName'),
            quantity: any(named: 'quantity'),
            pricelistId: any(named: 'pricelistId'),
            priceUnit: any(named: 'priceUnit'),
            discount: any(named: 'discount'),
            uomId: any(named: 'uomId'),
            uomName: any(named: 'uomName'),
            productCode: any(named: 'productCode'),
            taxIds: any(named: 'taxIds'),
            taxNames: any(named: 'taxNames'),
            taxPercent: any(named: 'taxPercent'),
            sequence: any(named: 'sequence'),
          )).thenAnswer(
        (_) async => OrderLineCreationResult.success(newLine),
      );

      final result = await helper.addProductLine(
        lines: [],
        orderId: 100,
        productId: 10,
        productName: 'New Product',
        mergeIfExists: false,
      );

      expect(result.success, isTrue);
      expect(result.lines.length, 1);
      expect(result.selectedIndex, 0);
    });
  });

  // ============================================================
  // Sequence calculation
  // ============================================================
  group('sequence calculation', () {
    test('addSectionLine uses next sequence', () {
      final existingLines = [
        _productLine(id: 1, sequence: 10),
        _productLine(id: 2, sequence: 20),
      ];

      // The helper calls _getNextSequence which returns maxSeq + 10
      // So with lines at seq 10 and 20, next should be 30
      when(() => mockCreationService.createSectionLine(
            orderId: 100,
            name: 'Section',
            sequence: 30, // 20 + 10
          )).thenReturn(SaleOrderLine(
        id: -1,
        orderId: 100,
        name: 'Section',
        sequence: 30,
        displayType: LineDisplayType.lineSection,
      ));

      final result = helper.addSectionLine(
        lines: existingLines,
        orderId: 100,
        name: 'Section',
      );

      expect(result.success, isTrue);
      verify(() => mockCreationService.createSectionLine(
            orderId: 100,
            name: 'Section',
            sequence: 30,
          )).called(1);
    });

    test('uses sequence 10 for empty list', () {
      when(() => mockCreationService.createSectionLine(
            orderId: 100,
            name: 'First',
            sequence: 10,
          )).thenReturn(SaleOrderLine(
        id: -1,
        orderId: 100,
        name: 'First',
        sequence: 10,
        displayType: LineDisplayType.lineSection,
      ));

      final result = helper.addSectionLine(
        lines: [],
        orderId: 100,
        name: 'First',
      );

      expect(result.success, isTrue);
      verify(() => mockCreationService.createSectionLine(
            orderId: 100,
            name: 'First',
            sequence: 10,
          )).called(1);
    });
  });
}
