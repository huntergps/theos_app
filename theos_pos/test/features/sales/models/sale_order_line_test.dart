import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        SaleOrderLine,
        LineDisplayType,
        SaleOrderLineListExtension;

import '../../../helpers/test_model_factory.dart';

void main() {
  setUp(() => resetIdCounter());

  group('SaleOrderLine', () {
    // =========================================================================
    // Display type checks
    // =========================================================================
    group('display type checks', () {
      test('isProductLine is true for default product lines', () {
        final line = SaleOrderLineFactory.create(orderId: 1);
        expect(line.isProductLine, isTrue);
        expect(line.isSection, isFalse);
        expect(line.isSubsection, isFalse);
        expect(line.isNote, isFalse);
        expect(line.isInfoLine, isFalse);
      });

      test('isSection is true for section lines', () {
        final line = SaleOrderLineFactory.section(orderId: 1);
        expect(line.isSection, isTrue);
        expect(line.isProductLine, isFalse);
        expect(line.isInfoLine, isTrue);
      });

      test('isSubsection is true for subsection lines', () {
        final line = SaleOrderLineFactory.create(
          orderId: 1,
          displayType: LineDisplayType.lineSubsection,
        );
        expect(line.isSubsection, isTrue);
        expect(line.isProductLine, isFalse);
        expect(line.isInfoLine, isTrue);
      });

      test('isNote is true for note lines', () {
        final line = SaleOrderLineFactory.note(orderId: 1);
        expect(line.isNote, isTrue);
        expect(line.isProductLine, isFalse);
        expect(line.isInfoLine, isTrue);
      });

      test('isInfoLine is true for section, subsection, and note', () {
        final section = SaleOrderLineFactory.section(orderId: 1);
        final subsection = SaleOrderLineFactory.create(
          orderId: 1,
          displayType: LineDisplayType.lineSubsection,
        );
        final note = SaleOrderLineFactory.note(orderId: 1);

        expect(section.isInfoLine, isTrue);
        expect(subsection.isInfoLine, isTrue);
        expect(note.isInfoLine, isTrue);
      });

      test('isInfoLine is false for product lines', () {
        final line = SaleOrderLineFactory.create(orderId: 1);
        expect(line.isInfoLine, isFalse);
      });
    });

    // =========================================================================
    // Factory methods
    // =========================================================================
    group('factory methods', () {
      group('newProductLine', () {
        test('creates a product line with correct defaults', () {
          final line = SaleOrderLine.newProductLine(
            orderId: 10,
            productId: 42,
            productName: 'Widget',
            priceUnit: 25.50,
          );

          expect(line.id, 0);
          expect(line.orderId, 10);
          expect(line.productId, 42);
          expect(line.productName, 'Widget');
          expect(line.name, 'Widget');
          expect(line.priceUnit, 25.50);
          expect(line.productUomQty, 1.0);
          expect(line.discount, 0.0);
          expect(line.displayType, LineDisplayType.product);
          expect(line.isSynced, isFalse);
        });

        test('accepts optional parameters', () {
          final line = SaleOrderLine.newProductLine(
            orderId: 10,
            productId: 42,
            productName: 'Widget',
            priceUnit: 25.50,
            quantity: 5.0,
            discount: 10.0,
            uomId: 3,
            uomName: 'Units',
            taxIds: '1,2',
            taxNames: 'IVA 15%',
            productCode: 'WDG-001',
            sequence: 20,
          );

          expect(line.productUomQty, 5.0);
          expect(line.discount, 10.0);
          expect(line.productUomId, 3);
          expect(line.productUomName, 'Units');
          expect(line.taxIds, '1,2');
          expect(line.taxNames, 'IVA 15%');
          expect(line.productCode, 'WDG-001');
          expect(line.sequence, 20);
        });
      });

      group('newSection', () {
        test('creates a section line', () {
          final section = SaleOrderLine.newSection(
            orderId: 10,
            name: 'Electronics',
          );

          expect(section.id, 0);
          expect(section.orderId, 10);
          expect(section.name, 'Electronics');
          expect(section.displayType, LineDisplayType.lineSection);
          expect(section.isSection, isTrue);
          expect(section.isSynced, isFalse);
        });

        test('uses custom sequence', () {
          final section = SaleOrderLine.newSection(
            orderId: 10,
            name: 'Section',
            sequence: 5,
          );
          expect(section.sequence, 5);
        });
      });

      group('newNote', () {
        test('creates a note line', () {
          final note = SaleOrderLine.newNote(
            orderId: 10,
            name: 'Special instructions',
          );

          expect(note.id, 0);
          expect(note.orderId, 10);
          expect(note.name, 'Special instructions');
          expect(note.displayType, LineDisplayType.lineNote);
          expect(note.isNote, isTrue);
          expect(note.isSynced, isFalse);
        });
      });
    });

    // =========================================================================
    // Business logic
    // =========================================================================
    group('business logic', () {
      group('calculateSubtotal', () {
        test('returns price * quantity with no discount', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            priceUnit: 100.0,
            productUomQty: 3.0,
          );
          expect(line.calculateSubtotal(), closeTo(300.0, 0.001));
        });

        test('applies discount correctly', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            priceUnit: 100.0,
            productUomQty: 2.0,
            discount: 10.0,
          );
          // 100 * (1 - 10/100) * 2 = 90 * 2 = 180
          expect(line.calculateSubtotal(), closeTo(180.0, 0.001));
        });

        test('handles 100% discount', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            priceUnit: 50.0,
            productUomQty: 5.0,
            discount: 100.0,
          );
          expect(line.calculateSubtotal(), closeTo(0.0, 0.001));
        });

        test('handles zero price', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            priceUnit: 0.0,
            productUomQty: 10.0,
          );
          expect(line.calculateSubtotal(), closeTo(0.0, 0.001));
        });
      });

      group('qtyPendingDelivery', () {
        test('returns difference between ordered and delivered', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            productUomQty: 10.0,
          ).copyWith(qtyDelivered: 3.0);
          expect(line.qtyPendingDelivery, closeTo(7.0, 0.001));
        });

        test('returns zero when fully delivered', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            productUomQty: 5.0,
          ).copyWith(qtyDelivered: 5.0);
          expect(line.qtyPendingDelivery, closeTo(0.0, 0.001));
        });
      });

      group('qtyPendingInvoice', () {
        test('returns difference between ordered and invoiced', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            productUomQty: 10.0,
          ).copyWith(qtyInvoiced: 4.0);
          expect(line.qtyPendingInvoice, closeTo(6.0, 0.001));
        });

        test('returns zero when fully invoiced', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            productUomQty: 5.0,
          ).copyWith(qtyInvoiced: 5.0);
          expect(line.qtyPendingInvoice, closeTo(0.0, 0.001));
        });
      });

      group('hasDiscount', () {
        test('returns true when discount > 0', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            discount: 5.0,
          );
          expect(line.hasDiscount, isTrue);
        });

        test('returns false when discount is zero', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            discount: 0.0,
          );
          expect(line.hasDiscount, isFalse);
        });
      });

      group('displayName', () {
        test('returns name when not empty', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            name: 'Custom Description',
          );
          expect(line.displayName, 'Custom Description');
        });

        test('returns productName when name is empty', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            name: '',
          ).copyWith(productName: 'Widget Pro');
          expect(line.displayName, 'Widget Pro');
        });

        test('returns Producto when both name and productName are empty', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            name: '',
          );
          // productName is null by default
          expect(line.displayName, 'Producto');
        });
      });

      group('isFullyDelivered', () {
        test('returns true when qtyDelivered >= productUomQty', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            productUomQty: 5.0,
          ).copyWith(qtyDelivered: 5.0);
          expect(line.isFullyDelivered, isTrue);
        });

        test('returns true when over-delivered', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            productUomQty: 5.0,
          ).copyWith(qtyDelivered: 7.0);
          expect(line.isFullyDelivered, isTrue);
        });

        test('returns false when partially delivered', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            productUomQty: 5.0,
          ).copyWith(qtyDelivered: 3.0);
          expect(line.isFullyDelivered, isFalse);
        });
      });

      group('isFullyInvoiced', () {
        test('returns true when qtyInvoiced >= productUomQty', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            productUomQty: 5.0,
          ).copyWith(qtyInvoiced: 5.0);
          expect(line.isFullyInvoiced, isTrue);
        });

        test('returns false when partially invoiced', () {
          final line = SaleOrderLineFactory.create(
            orderId: 1,
            productUomQty: 5.0,
          ).copyWith(qtyInvoiced: 2.0);
          expect(line.isFullyInvoiced, isFalse);
        });
      });
    });

    // =========================================================================
    // onProductChanged
    // =========================================================================
    group('onProductChanged', () {
      test('returns copy with updated product fields', () {
        final line = SaleOrderLineFactory.create(orderId: 1);

        final updated = line.onProductChanged(
          productId: 99,
          productName: 'New Product',
          productCode: 'NP-001',
          listPrice: 45.99,
          uomId: 2,
          uomName: 'Kg',
          taxIds: '1,3',
          taxNames: 'IVA 15%, ICE',
          productType: 'consu',
          categId: 5,
          categName: 'Hardware',
          isUnitProduct: false,
        );

        expect(updated.productId, 99);
        expect(updated.productName, 'New Product');
        expect(updated.productCode, 'NP-001');
        expect(updated.name, 'New Product');
        expect(updated.priceUnit, 45.99);
        expect(updated.productUomId, 2);
        expect(updated.productUomName, 'Kg');
        expect(updated.taxIds, '1,3');
        expect(updated.taxNames, 'IVA 15%, ICE');
        expect(updated.productType, 'consu');
        expect(updated.categId, 5);
        expect(updated.categName, 'Hardware');
        expect(updated.isUnitProduct, isFalse);
      });

      test('preserves original line id and orderId', () {
        final line = SaleOrderLineFactory.create(id: 42, orderId: 10);

        final updated = line.onProductChanged(
          productId: 99,
          productName: 'New Product',
          listPrice: 10.0,
        );

        expect(updated.id, 42);
        expect(updated.orderId, 10);
      });

      test('sets name to productName by default', () {
        final line = SaleOrderLineFactory.create(orderId: 1);

        final updated = line.onProductChanged(
          productId: 99,
          productName: 'Widget X',
          listPrice: 20.0,
        );

        expect(updated.name, 'Widget X');
      });
    });

    // =========================================================================
    // onAmountsChanged
    // =========================================================================
    group('onAmountsChanged', () {
      test('calculates amounts with no discount and no tax', () {
        final line = SaleOrderLineFactory.create(
          orderId: 1,
          priceUnit: 100.0,
          productUomQty: 2.0,
        );

        final updated = line.onAmountsChanged(taxPercent: 0.0);

        expect(updated.priceSubtotal, closeTo(200.0, 0.001));
        expect(updated.priceTax, closeTo(0.0, 0.001));
        expect(updated.priceTotal, closeTo(200.0, 0.001));
        expect(updated.discountAmount, closeTo(0.0, 0.001));
        expect(updated.priceReduce, closeTo(100.0, 0.001));
      });

      test('calculates amounts with tax', () {
        final line = SaleOrderLineFactory.create(
          orderId: 1,
          priceUnit: 100.0,
          productUomQty: 2.0,
        );

        final updated = line.onAmountsChanged(taxPercent: 15.0);

        // subtotal = 100 * 2 = 200
        // tax = 200 * 0.15 = 30
        // total = 200 + 30 = 230
        expect(updated.priceSubtotal, closeTo(200.0, 0.001));
        expect(updated.priceTax, closeTo(30.0, 0.001));
        expect(updated.priceTotal, closeTo(230.0, 0.001));
      });

      test('calculates amounts with discount and tax', () {
        final line = SaleOrderLineFactory.create(
          orderId: 1,
          priceUnit: 100.0,
          productUomQty: 2.0,
          discount: 10.0,
        );

        final updated = line.onAmountsChanged(taxPercent: 15.0);

        // discountedPrice = 100 * (1 - 10/100) = 90
        // subtotal = 90 * 2 = 180
        // tax = 180 * 0.15 = 27
        // total = 180 + 27 = 207
        // discountAmt = 100 * 2 * (10/100) = 20
        expect(updated.priceSubtotal, closeTo(180.0, 0.001));
        expect(updated.priceTax, closeTo(27.0, 0.001));
        expect(updated.priceTotal, closeTo(207.0, 0.001));
        expect(updated.discountAmount, closeTo(20.0, 0.001));
        expect(updated.priceReduce, closeTo(90.0, 0.001));
      });

      test('uses new values when provided', () {
        final line = SaleOrderLineFactory.create(
          orderId: 1,
          priceUnit: 50.0,
          productUomQty: 1.0,
        );

        final updated = line.onAmountsChanged(
          newQuantity: 3.0,
          newPriceUnit: 200.0,
          newDiscount: 25.0,
          taxPercent: 12.0,
        );

        // discountedPrice = 200 * (1 - 25/100) = 150
        // subtotal = 150 * 3 = 450
        // tax = 450 * 0.12 = 54
        // total = 450 + 54 = 504
        // discountAmt = 200 * 3 * (25/100) = 150
        expect(updated.productUomQty, closeTo(3.0, 0.001));
        expect(updated.priceUnit, closeTo(200.0, 0.001));
        expect(updated.discount, closeTo(25.0, 0.001));
        expect(updated.priceSubtotal, closeTo(450.0, 0.001));
        expect(updated.priceTax, closeTo(54.0, 0.001));
        expect(updated.priceTotal, closeTo(504.0, 0.001));
        expect(updated.discountAmount, closeTo(150.0, 0.001));
        expect(updated.priceReduce, closeTo(150.0, 0.001));
      });

      test('falls back to existing values when optionals not provided', () {
        final line = SaleOrderLineFactory.create(
          orderId: 1,
          priceUnit: 80.0,
          productUomQty: 4.0,
          discount: 5.0,
        );

        final updated = line.onAmountsChanged(taxPercent: 10.0);

        expect(updated.productUomQty, closeTo(4.0, 0.001));
        expect(updated.priceUnit, closeTo(80.0, 0.001));
        expect(updated.discount, closeTo(5.0, 0.001));

        // discountedPrice = 80 * 0.95 = 76
        // subtotal = 76 * 4 = 304
        // tax = 304 * 0.10 = 30.4
        // total = 304 + 30.4 = 334.4
        // discountAmt = 80 * 4 * 0.05 = 16
        expect(updated.priceSubtotal, closeTo(304.0, 0.001));
        expect(updated.priceTax, closeTo(30.4, 0.001));
        expect(updated.priceTotal, closeTo(334.4, 0.001));
        expect(updated.discountAmount, closeTo(16.0, 0.001));
      });
    });

    // =========================================================================
    // toOdoo
    // =========================================================================
    group('toOdoo', () {
      test('produces correct map with basic fields', () {
        final line = SaleOrderLineFactory.create(
          orderId: 10,
          name: 'Widget',
          priceUnit: 25.0,
          productUomQty: 3.0,
          discount: 5.0,
        );

        final map = line.toOdoo();

        expect(map['order_id'], 10);
        expect(map['name'], 'Widget');
        expect(map['price_unit'], 25.0);
        expect(map['product_uom_qty'], 3.0);
        expect(map['discount'], 5.0);
        expect(map['sequence'], isNotNull);
      });

      test('includes product_id when set', () {
        final line = SaleOrderLineFactory.create(
          orderId: 10,
          productId: 42,
        );

        final map = line.toOdoo();
        expect(map['product_id'], 42);
      });

      test('does not include product_id when null', () {
        final line = SaleOrderLineFactory.create(orderId: 10);

        final map = line.toOdoo();
        expect(map.containsKey('product_id'), isFalse);
      });

      test('includes display_type for non-product lines', () {
        final section = SaleOrderLineFactory.section(orderId: 10);

        final map = section.toOdoo();
        expect(map['display_type'], 'line_section');
      });

      test('does not include display_type for product lines', () {
        final line = SaleOrderLineFactory.create(orderId: 10);

        final map = line.toOdoo();
        expect(map.containsKey('display_type'), isFalse);
      });

      test('includes tax_ids in [(6,0,[ids])] format', () {
        final line = SaleOrderLineFactory.create(
          orderId: 10,
        ).copyWith(taxIds: '1,2,3');

        final map = line.toOdoo();

        expect(map['tax_ids'], isA<List>());
        final taxCommand = map['tax_ids'] as List;
        expect(taxCommand.length, 1);
        expect(taxCommand[0][0], 6);
        expect(taxCommand[0][1], 0);
        expect(taxCommand[0][2], [1, 2, 3]);
      });

      test('does not include tax_ids when null', () {
        final line = SaleOrderLineFactory.create(orderId: 10);

        final map = line.toOdoo();
        expect(map.containsKey('tax_ids'), isFalse);
      });

      test('does not include tax_ids when empty string', () {
        final line = SaleOrderLineFactory.create(
          orderId: 10,
        ).copyWith(taxIds: '');

        final map = line.toOdoo();
        expect(map.containsKey('tax_ids'), isFalse);
      });

      test('includes section settings for section lines', () {
        final section = SaleOrderLineFactory.section(orderId: 10).copyWith(
          collapsePrices: true,
          collapseComposition: true,
          isOptional: true,
        );

        final map = section.toOdoo();
        expect(map['collapse_prices'], isTrue);
        expect(map['collapse_composition'], isTrue);
        expect(map['is_optional'], isTrue);
      });

      test('does not include section settings for product lines', () {
        final line = SaleOrderLineFactory.create(orderId: 10);

        final map = line.toOdoo();
        expect(map.containsKey('collapse_prices'), isFalse);
        expect(map.containsKey('collapse_composition'), isFalse);
        expect(map.containsKey('is_optional'), isFalse);
      });
    });

    // =========================================================================
    // List extension methods (SaleOrderLineListExtension)
    // =========================================================================
    group('SaleOrderLineListExtension', () {
      group('sortedBySequence', () {
        test('returns lines sorted by sequence ascending', () {
          final lines = [
            SaleOrderLineFactory.create(
                id: 1, orderId: 1, name: 'C').copyWith(sequence: 30),
            SaleOrderLineFactory.create(
                id: 2, orderId: 1, name: 'A').copyWith(sequence: 10),
            SaleOrderLineFactory.create(
                id: 3, orderId: 1, name: 'B').copyWith(sequence: 20),
          ];

          final sorted = lines.sortedBySequence;

          expect(sorted[0].name, 'A');
          expect(sorted[1].name, 'B');
          expect(sorted[2].name, 'C');
        });

        test('does not mutate original list', () {
          final lines = [
            SaleOrderLineFactory.create(
                id: 1, orderId: 1, name: 'B').copyWith(sequence: 20),
            SaleOrderLineFactory.create(
                id: 2, orderId: 1, name: 'A').copyWith(sequence: 10),
          ];

          lines.sortedBySequence;

          expect(lines[0].name, 'B');
          expect(lines[1].name, 'A');
        });
      });

      group('getLinesInSection', () {
        test('returns product lines belonging to a section', () {
          final section = SaleOrderLineFactory.section(
            id: 1, orderId: 1, name: 'Section 1',
          ).copyWith(sequence: 10);
          final line1 = SaleOrderLineFactory.create(
            id: 2, orderId: 1, name: 'Product 1',
          ).copyWith(sequence: 20);
          final line2 = SaleOrderLineFactory.create(
            id: 3, orderId: 1, name: 'Product 2',
          ).copyWith(sequence: 30);

          final lines = [section, line1, line2];
          final result = lines.getLinesInSection(section);

          expect(result.length, 2);
          expect(result[0].name, 'Product 1');
          expect(result[1].name, 'Product 2');
        });

        test('stops at the next section', () {
          final section1 = SaleOrderLineFactory.section(
            id: 1, orderId: 1, name: 'Section 1',
          ).copyWith(sequence: 10);
          final line1 = SaleOrderLineFactory.create(
            id: 2, orderId: 1, name: 'Product 1',
          ).copyWith(sequence: 20);
          final section2 = SaleOrderLineFactory.section(
            id: 3, orderId: 1, name: 'Section 2',
          ).copyWith(sequence: 30);
          final line2 = SaleOrderLineFactory.create(
            id: 4, orderId: 1, name: 'Product 2',
          ).copyWith(sequence: 40);

          final lines = [section1, line1, section2, line2];
          final result = lines.getLinesInSection(section1);

          expect(result.length, 1);
          expect(result[0].name, 'Product 1');
        });

        test('returns empty list for a product line', () {
          final line = SaleOrderLineFactory.create(id: 1, orderId: 1);
          final lines = [line];
          final result = lines.getLinesInSection(line);

          expect(result, isEmpty);
        });

        test('includes note lines in section', () {
          final section = SaleOrderLineFactory.section(
            id: 1, orderId: 1, name: 'Section',
          ).copyWith(sequence: 10);
          final product = SaleOrderLineFactory.create(
            id: 2, orderId: 1, name: 'Product',
          ).copyWith(sequence: 20);
          final note = SaleOrderLineFactory.note(
            id: 3, orderId: 1, name: 'A note',
          ).copyWith(sequence: 30);

          final lines = [section, product, note];
          final result = lines.getLinesInSection(section);

          expect(result.length, 2);
          expect(result[0].name, 'Product');
          expect(result[1].name, 'A note');
        });

        test('returns empty list when section not found', () {
          final section = SaleOrderLineFactory.section(
            id: 99, orderId: 1, name: 'Ghost Section',
          );
          final line = SaleOrderLineFactory.create(id: 1, orderId: 1);

          final lines = [line];
          final result = lines.getLinesInSection(section);

          expect(result, isEmpty);
        });
      });

      group('getSectionSubtotal', () {
        test('sums priceSubtotal of product lines in section', () {
          final section = SaleOrderLineFactory.section(
            id: 1, orderId: 1, name: 'Section',
          ).copyWith(sequence: 10);
          final line1 = SaleOrderLineFactory.create(
            id: 2, orderId: 1, name: 'Product 1',
          ).copyWith(sequence: 20, priceSubtotal: 100.0);
          final line2 = SaleOrderLineFactory.create(
            id: 3, orderId: 1, name: 'Product 2',
          ).copyWith(sequence: 30, priceSubtotal: 50.0);
          final note = SaleOrderLineFactory.note(
            id: 4, orderId: 1, name: 'Note',
          ).copyWith(sequence: 25);

          final lines = [section, line1, note, line2];
          final subtotal = lines.getSectionSubtotal(section);

          // Only product lines: 100 + 50 = 150 (note excluded)
          expect(subtotal, closeTo(150.0, 0.001));
        });

        test('returns 0.0 for empty section', () {
          final section = SaleOrderLineFactory.section(
            id: 1, orderId: 1, name: 'Empty Section',
          ).copyWith(sequence: 10);
          final section2 = SaleOrderLineFactory.section(
            id: 2, orderId: 1, name: 'Next Section',
          ).copyWith(sequence: 20);

          final lines = [section, section2];
          final subtotal = lines.getSectionSubtotal(section);

          expect(subtotal, closeTo(0.0, 0.001));
        });
      });
    });
  });
}
