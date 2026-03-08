import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show LineDisplayType, SaleOrderLineListExtension;

import '../../../helpers/test_model_factory.dart';

void main() {
  setUp(() => resetIdCounter());

  // ===========================================================================
  // shouldShowPrice
  // ===========================================================================
  group('shouldShowPrice', () {
    test('returns true for a product line with no parent section', () {
      final line = SaleOrderLineFactory.create(
        id: 1, orderId: 1, name: 'Product',
      ).copyWith(sequence: 10);
      final lines = [line];

      expect(lines.shouldShowPrice(line), isTrue);
    });

    test('returns false for a section line', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final lines = [section];

      expect(lines.shouldShowPrice(section), isFalse);
    });

    test('returns false for a subsection line', () {
      final subsection = SaleOrderLineFactory.create(
        id: 1, orderId: 1, name: 'Subsection',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 10);
      final lines = [subsection];

      expect(lines.shouldShowPrice(subsection), isFalse);
    });

    test('returns false for a note line', () {
      final note = SaleOrderLineFactory.note(
        id: 1, orderId: 1, name: 'Note',
      ).copyWith(sequence: 10);
      final lines = [note];

      expect(lines.shouldShowPrice(note), isFalse);
    });

    test('returns true when parent section does NOT have collapsePrices', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10, collapsePrices: false);
      final line = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Product',
      ).copyWith(sequence: 20);
      final lines = [section, line];

      expect(lines.shouldShowPrice(line), isTrue);
    });

    test('returns false when parent section has collapsePrices', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10, collapsePrices: true);
      final line = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Product',
      ).copyWith(sequence: 20);
      final lines = [section, line];

      expect(lines.shouldShowPrice(line), isFalse);
    });

    test('returns false when grandparent section has collapsePrices', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10, collapsePrices: true);
      final subsection = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Subsection',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 20, collapsePrices: false);
      final line = SaleOrderLineFactory.create(
        id: 3, orderId: 1, name: 'Product',
      ).copyWith(sequence: 30);
      final lines = [section, subsection, line];

      // Line's parent is subsection (collapsePrices=false),
      // but grandparent section has collapsePrices=true -> should hide
      expect(lines.shouldShowPrice(line), isFalse);
    });

    test('returns false when subsection parent has collapsePrices', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10, collapsePrices: false);
      final subsection = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Subsection',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 20, collapsePrices: true);
      final line = SaleOrderLineFactory.create(
        id: 3, orderId: 1, name: 'Product',
      ).copyWith(sequence: 30);
      final lines = [section, subsection, line];

      // Line's direct parent is subsection with collapsePrices=true
      expect(lines.shouldShowPrice(line), isFalse);
    });

    test('returns true when neither subsection nor section has collapsePrices', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10, collapsePrices: false);
      final subsection = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Subsection',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 20, collapsePrices: false);
      final line = SaleOrderLineFactory.create(
        id: 3, orderId: 1, name: 'Product',
      ).copyWith(sequence: 30);
      final lines = [section, subsection, line];

      expect(lines.shouldShowPrice(line), isTrue);
    });
  });

  // ===========================================================================
  // shouldShowLine
  // ===========================================================================
  group('shouldShowLine', () {
    test('sections always show', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final lines = [section];

      expect(lines.shouldShowLine(section), isTrue);
    });

    test('product line with no parent always shows', () {
      final line = SaleOrderLineFactory.create(
        id: 1, orderId: 1, name: 'Product',
      ).copyWith(sequence: 10);
      final lines = [line];

      expect(lines.shouldShowLine(line), isTrue);
    });

    test('returns false when parent has collapseComposition', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10, collapseComposition: true);
      final line = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Product',
      ).copyWith(sequence: 20);
      final lines = [section, line];

      expect(lines.shouldShowLine(line), isFalse);
    });

    test('returns true when parent does NOT have collapseComposition', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10, collapseComposition: false);
      final line = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Product',
      ).copyWith(sequence: 20);
      final lines = [section, line];

      expect(lines.shouldShowLine(line), isTrue);
    });

    test('returns false when grandparent section has collapseComposition', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10, collapseComposition: true);
      final subsection = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Subsection',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 20);
      final line = SaleOrderLineFactory.create(
        id: 3, orderId: 1, name: 'Product',
      ).copyWith(sequence: 30);
      final lines = [section, subsection, line];

      expect(lines.shouldShowLine(line), isFalse);
    });

    test('note line hidden when parent has collapseComposition', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10, collapseComposition: true);
      final note = SaleOrderLineFactory.note(
        id: 2, orderId: 1, name: 'A note',
      ).copyWith(sequence: 20);
      final lines = [section, note];

      expect(lines.shouldShowLine(note), isFalse);
    });

    test('subsection line hidden when parent section has collapseComposition', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10, collapseComposition: true);
      final subsection = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Subsection',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 20);
      final lines = [section, subsection];

      // Subsection's parent is the section with collapseComposition=true
      expect(lines.shouldShowLine(subsection), isFalse);
    });
  });

  // ===========================================================================
  // getParentSection
  // ===========================================================================
  group('getParentSection', () {
    test('returns null for a section (sections have no parent section)', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final lines = [section];

      expect(lines.getParentSection(section), isNull);
    });

    test('returns null for a product line with no preceding section', () {
      final line = SaleOrderLineFactory.create(
        id: 1, orderId: 1, name: 'Orphan Product',
      ).copyWith(sequence: 10);
      final lines = [line];

      expect(lines.getParentSection(line), isNull);
    });

    test('returns section for a product line after a section', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final line = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Product',
      ).copyWith(sequence: 20);
      final lines = [section, line];

      final parent = lines.getParentSection(line);
      expect(parent, isNotNull);
      expect(parent!.id, 1);
    });

    test('returns subsection when product follows subsection', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final subsection = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Subsection',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 20);
      final line = SaleOrderLineFactory.create(
        id: 3, orderId: 1, name: 'Product',
      ).copyWith(sequence: 30);
      final lines = [section, subsection, line];

      final parent = lines.getParentSection(line);
      expect(parent, isNotNull);
      expect(parent!.id, 2); // subsection, not section
    });

    test('returns section for a subsection', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final subsection = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Subsection',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 20);
      final lines = [section, subsection];

      final parent = lines.getParentSection(subsection);
      expect(parent, isNotNull);
      expect(parent!.id, 1); // the section is the parent of the subsection
    });

    test('returns null for a line not in the list', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final ghostLine = SaleOrderLineFactory.create(
        id: 99, orderId: 1, name: 'Ghost',
      ).copyWith(sequence: 50);
      final lines = [section];

      expect(lines.getParentSection(ghostLine), isNull);
    });

    test('returns latest section when multiple sections precede a line', () {
      final section1 = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section 1',
      ).copyWith(sequence: 10);
      final section2 = SaleOrderLineFactory.section(
        id: 2, orderId: 1, name: 'Section 2',
      ).copyWith(sequence: 20);
      final line = SaleOrderLineFactory.create(
        id: 3, orderId: 1, name: 'Product',
      ).copyWith(sequence: 30);
      final lines = [section1, section2, line];

      final parent = lines.getParentSection(line);
      expect(parent!.id, 2);
    });

    test('resets subsection tracking when new section encountered', () {
      final section1 = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section 1',
      ).copyWith(sequence: 10);
      final subsection = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Subsection',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 20);
      final section2 = SaleOrderLineFactory.section(
        id: 3, orderId: 1, name: 'Section 2',
      ).copyWith(sequence: 30);
      final line = SaleOrderLineFactory.create(
        id: 4, orderId: 1, name: 'Product',
      ).copyWith(sequence: 40);
      final lines = [section1, subsection, section2, line];

      // line is in section2 (no subsection under section2)
      final parent = lines.getParentSection(line);
      expect(parent!.id, 3); // section2, not the old subsection
    });

    test('returns section for note line inside a section', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final note = SaleOrderLineFactory.note(
        id: 2, orderId: 1, name: 'Important note',
      ).copyWith(sequence: 20);
      final lines = [section, note];

      final parent = lines.getParentSection(note);
      expect(parent, isNotNull);
      expect(parent!.id, 1);
    });
  });

  // ===========================================================================
  // getSectionTotal
  // ===========================================================================
  group('getSectionTotal', () {
    test('sums priceTotal of product lines in section', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final line1 = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'P1',
      ).copyWith(sequence: 20, priceTotal: 115.0);
      final line2 = SaleOrderLineFactory.create(
        id: 3, orderId: 1, name: 'P2',
      ).copyWith(sequence: 30, priceTotal: 230.0);
      final lines = [section, line1, line2];

      expect(lines.getSectionTotal(section), closeTo(345.0, 0.001));
    });

    test('excludes note lines from total', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final line = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'P1',
      ).copyWith(sequence: 20, priceTotal: 100.0);
      final note = SaleOrderLineFactory.note(
        id: 3, orderId: 1, name: 'Note',
      ).copyWith(sequence: 25);
      final lines = [section, line, note];

      expect(lines.getSectionTotal(section), closeTo(100.0, 0.001));
    });

    test('returns 0.0 for empty section', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Empty',
      ).copyWith(sequence: 10);
      final section2 = SaleOrderLineFactory.section(
        id: 2, orderId: 1, name: 'Next',
      ).copyWith(sequence: 20);
      final lines = [section, section2];

      expect(lines.getSectionTotal(section), closeTo(0.0, 0.001));
    });

    test('stops at the next section', () {
      final sec1 = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Sec 1',
      ).copyWith(sequence: 10);
      final line1 = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'P1',
      ).copyWith(sequence: 20, priceTotal: 50.0);
      final sec2 = SaleOrderLineFactory.section(
        id: 3, orderId: 1, name: 'Sec 2',
      ).copyWith(sequence: 30);
      final line2 = SaleOrderLineFactory.create(
        id: 4, orderId: 1, name: 'P2',
      ).copyWith(sequence: 40, priceTotal: 200.0);
      final lines = [sec1, line1, sec2, line2];

      expect(lines.getSectionTotal(sec1), closeTo(50.0, 0.001));
      expect(lines.getSectionTotal(sec2), closeTo(200.0, 0.001));
    });
  });

  // ===========================================================================
  // getSectionTax
  // ===========================================================================
  group('getSectionTax', () {
    test('sums priceTax of product lines in section', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final line1 = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'P1',
      ).copyWith(sequence: 20, priceTax: 15.0);
      final line2 = SaleOrderLineFactory.create(
        id: 3, orderId: 1, name: 'P2',
      ).copyWith(sequence: 30, priceTax: 7.5);
      final lines = [section, line1, line2];

      expect(lines.getSectionTax(section), closeTo(22.5, 0.001));
    });

    test('excludes note lines from tax sum', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final line = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'P1',
      ).copyWith(sequence: 20, priceTax: 12.0);
      final note = SaleOrderLineFactory.note(
        id: 3, orderId: 1, name: 'Note',
      ).copyWith(sequence: 25);
      final lines = [section, line, note];

      expect(lines.getSectionTax(section), closeTo(12.0, 0.001));
    });

    test('returns 0.0 for section with no product lines', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Empty',
      ).copyWith(sequence: 10);
      final note = SaleOrderLineFactory.note(
        id: 2, orderId: 1, name: 'Note',
      ).copyWith(sequence: 20);
      final lines = [section, note];

      expect(lines.getSectionTax(section), closeTo(0.0, 0.001));
    });

    test('stops at the next section', () {
      final sec1 = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Sec 1',
      ).copyWith(sequence: 10);
      final line1 = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'P1',
      ).copyWith(sequence: 20, priceTax: 10.0);
      final sec2 = SaleOrderLineFactory.section(
        id: 3, orderId: 1, name: 'Sec 2',
      ).copyWith(sequence: 30);
      final line2 = SaleOrderLineFactory.create(
        id: 4, orderId: 1, name: 'P2',
      ).copyWith(sequence: 40, priceTax: 25.0);
      final lines = [sec1, line1, sec2, line2];

      expect(lines.getSectionTax(sec1), closeTo(10.0, 0.001));
      expect(lines.getSectionTax(sec2), closeTo(25.0, 0.001));
    });
  });

  // ===========================================================================
  // getLinesInSection — additional cases
  // ===========================================================================
  group('getLinesInSection (additional)', () {
    test('subsection lines are skipped in parent section listing', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final line1 = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'P1',
      ).copyWith(sequence: 20);
      final subsection = SaleOrderLineFactory.create(
        id: 3, orderId: 1, name: 'Subsection',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 30);
      final line2 = SaleOrderLineFactory.create(
        id: 4, orderId: 1, name: 'P2',
      ).copyWith(sequence: 40);
      final lines = [section, line1, subsection, line2];

      // getLinesInSection for the parent section skips subsections
      final result = lines.getLinesInSection(section);
      expect(result.length, 2);
      expect(result[0].name, 'P1');
      expect(result[1].name, 'P2');
    });

    test('subsection collects its own product lines until next subsection', () {
      final section = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section',
      ).copyWith(sequence: 10);
      final sub1 = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Sub 1',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 20);
      final line1 = SaleOrderLineFactory.create(
        id: 3, orderId: 1, name: 'P1',
      ).copyWith(sequence: 30);
      final sub2 = SaleOrderLineFactory.create(
        id: 4, orderId: 1, name: 'Sub 2',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 40);
      final line2 = SaleOrderLineFactory.create(
        id: 5, orderId: 1, name: 'P2',
      ).copyWith(sequence: 50);
      final lines = [section, sub1, line1, sub2, line2];

      final sub1Lines = lines.getLinesInSection(sub1);
      expect(sub1Lines.length, 1);
      expect(sub1Lines[0].name, 'P1');

      final sub2Lines = lines.getLinesInSection(sub2);
      expect(sub2Lines.length, 1);
      expect(sub2Lines[0].name, 'P2');
    });

    test('subsection stops at next section boundary', () {
      final section1 = SaleOrderLineFactory.section(
        id: 1, orderId: 1, name: 'Section 1',
      ).copyWith(sequence: 10);
      final sub = SaleOrderLineFactory.create(
        id: 2, orderId: 1, name: 'Sub',
        displayType: LineDisplayType.lineSubsection,
      ).copyWith(sequence: 20);
      final line = SaleOrderLineFactory.create(
        id: 3, orderId: 1, name: 'P1',
      ).copyWith(sequence: 30);
      final section2 = SaleOrderLineFactory.section(
        id: 4, orderId: 1, name: 'Section 2',
      ).copyWith(sequence: 40);
      final line2 = SaleOrderLineFactory.create(
        id: 5, orderId: 1, name: 'P2',
      ).copyWith(sequence: 50);
      final lines = [section1, sub, line, section2, line2];

      final subLines = lines.getLinesInSection(sub);
      expect(subLines.length, 1);
      expect(subLines[0].name, 'P1');
    });
  });
}
