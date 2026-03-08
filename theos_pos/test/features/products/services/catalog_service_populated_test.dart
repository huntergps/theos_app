import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/products/services/catalog_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../helpers/test_model_factory.dart';

void main() {
  late CatalogService service;

  setUp(() {
    resetIdCounter();
    service = CatalogService();
  });

  // ===========================================================================
  // populateForTesting sanity checks
  // ===========================================================================
  group('populateForTesting', () {
    test('sets isLoaded to true after populating', () {
      service.populateForTesting(products: []);
      expect(service.isLoaded, isTrue);
    });

    test('sets needsRefresh to false right after populating', () {
      service.populateForTesting(products: []);
      expect(service.needsRefresh, isFalse);
    });

    test('populates product count correctly', () {
      final products = [
        ProductFactory.create(id: 1, name: 'A'),
        ProductFactory.create(id: 2, name: 'B'),
      ];
      service.populateForTesting(products: products);
      expect(service.productCount, 2);
    });

    test('populates UoM count correctly', () {
      final uoms = [
        UomFactory.create(id: 1, name: 'Units'),
        UomFactory.create(id: 2, name: 'Kg'),
      ];
      service.populateForTesting(uoms: uoms);
      expect(service.uomCount, 2);
    });

    test('populates category count correctly', () {
      final categories = [
        ProductCategoryFactory.create(id: 1, name: 'Electronics'),
      ];
      service.populateForTesting(categories: categories);
      expect(service.categoryCount, 1);
    });

    test('stats reflects all populated data', () {
      service.populateForTesting(
        products: [
          ProductFactory.create(id: 1, name: 'P1', barcode: '111', defaultCode: 'C1'),
          ProductFactory.create(id: 2, name: 'P2'),
        ],
        uoms: [UomFactory.create(id: 10, name: 'Units')],
        categories: [ProductCategoryFactory.create(id: 20, name: 'Cat')],
        taxes: [TaxFactory.create(id: 30, name: 'IVA')],
      );

      final s = service.stats;
      expect(s['products'], 2);
      expect(s['productsByBarcode'], 1);
      expect(s['productsByCode'], 1);
      expect(s['uoms'], 1);
      expect(s['categories'], 1);
      expect(s['taxes'], 1);
    });
  });

  // ===========================================================================
  // Product operations with populated cache
  // ===========================================================================
  group('Product operations (populated)', () {
    late Product laptop;
    late Product mouse;
    late Product service1;

    setUp(() {
      laptop = ProductFactory.create(
        id: 10,
        name: 'Laptop Pro',
        defaultCode: 'LAP-001',
        barcode: '7891234560001',
        listPrice: 1500.0,
      );
      mouse = ProductFactory.create(
        id: 20,
        name: 'Wireless Mouse',
        defaultCode: 'MOU-002',
        barcode: '7891234560002',
        listPrice: 25.0,
      );
      service1 = ProductFactory.create(
        id: 30,
        name: 'Installation Service',
        listPrice: 50.0,
      );
      service.populateForTesting(products: [laptop, mouse, service1]);
    });

    group('getProduct', () {
      test('returns product for existing ID', () {
        final result = service.getProduct(10);
        expect(result, isNotNull);
        expect(result!.name, 'Laptop Pro');
      });

      test('returns null for non-existent ID', () {
        expect(service.getProduct(999), isNull);
      });
    });

    group('getProductByBarcode', () {
      test('returns product for existing barcode', () {
        final result = service.getProductByBarcode('7891234560001');
        expect(result, isNotNull);
        expect(result!.name, 'Laptop Pro');
      });

      test('returns null for non-existent barcode', () {
        expect(service.getProductByBarcode('0000000000000'), isNull);
      });

      test('returns null for product without barcode', () {
        // service1 has no barcode
        expect(service.getProductByBarcode(null), isNull);
      });
    });

    group('getProductByCode', () {
      test('returns product for existing code (case-insensitive)', () {
        final result = service.getProductByCode('lap-001');
        expect(result, isNotNull);
        expect(result!.name, 'Laptop Pro');
      });

      test('returns product for existing code (uppercase)', () {
        final result = service.getProductByCode('LAP-001');
        expect(result, isNotNull);
        expect(result!.name, 'Laptop Pro');
      });

      test('returns null for non-existent code', () {
        expect(service.getProductByCode('XXX-999'), isNull);
      });

      test('returns null for product without code', () {
        // service1 has no defaultCode
        expect(service.getProductByCode(''), isNull);
      });
    });

    group('resolveProductName', () {
      test('returns local name when product exists', () {
        final name = service.resolveProductName(10, 'Fallback');
        expect(name, 'Laptop Pro');
      });

      test('returns local name ignoring embedded when product exists', () {
        final name = service.resolveProductName(10, 'Old Name');
        expect(name, 'Laptop Pro');
      });

      test('returns fallback when product does not exist', () {
        final name = service.resolveProductName(999, 'Fallback Product');
        expect(name, 'Fallback Product');
      });
    });

    group('resolveProductDisplayName', () {
      test('returns displayName from local product', () {
        // laptop has defaultCode: 'LAP-001', so displayName = '[LAP-001] Laptop Pro'
        final name = service.resolveProductDisplayName(10, 'Fallback');
        expect(name, '[LAP-001] Laptop Pro');
      });

      test('returns name for product without code', () {
        // service1 (id=30) has no defaultCode
        final name = service.resolveProductDisplayName(30);
        expect(name, 'Installation Service');
      });

      test('returns fallback when product does not exist', () {
        final name = service.resolveProductDisplayName(999, 'Fallback');
        expect(name, 'Fallback');
      });
    });

    group('resolveProductCode', () {
      test('returns code from local product', () {
        final code = service.resolveProductCode(10, 'OLD-CODE');
        expect(code, 'LAP-001');
      });

      test('returns null for product without code', () {
        final code = service.resolveProductCode(30);
        expect(code, isNull);
      });

      test('returns fallback for non-existent product', () {
        final code = service.resolveProductCode(999, 'FALLBACK');
        expect(code, 'FALLBACK');
      });
    });

    group('searchProducts', () {
      test('finds products by name substring', () {
        final results = service.searchProducts('Laptop');
        expect(results.length, 1);
        expect(results.first.name, 'Laptop Pro');
      });

      test('search is case-insensitive', () {
        final results = service.searchProducts('laptop');
        expect(results.length, 1);
        expect(results.first.name, 'Laptop Pro');
      });

      test('finds products by code', () {
        final results = service.searchProducts('MOU-002');
        expect(results.length, 1);
        expect(results.first.name, 'Wireless Mouse');
      });

      test('finds products by code (case-insensitive)', () {
        final results = service.searchProducts('mou-002');
        expect(results.length, 1);
        expect(results.first.name, 'Wireless Mouse');
      });

      test('finds products by barcode', () {
        final results = service.searchProducts('7891234560002');
        expect(results.length, 1);
        expect(results.first.name, 'Wireless Mouse');
      });

      test('returns multiple matches', () {
        // Both laptop and mouse have product names containing common substring
        // Let's search for a more general term
        final results = service.searchProducts('e');
        // 'Laptop Pro' does not have 'e', 'Wireless Mouse' has 'e', 'Installation Service' has 'e'
        expect(results.length, 2);
      });

      test('respects limit parameter', () {
        final results = service.searchProducts('e', limit: 1);
        expect(results.length, 1);
      });

      test('returns empty for no matches', () {
        final results = service.searchProducts('ZZZZZ');
        expect(results, isEmpty);
      });

      test('returns empty for empty query', () {
        final results = service.searchProducts('');
        expect(results, isEmpty);
      });
    });

    group('allUoms / allCategories / allTaxes', () {
      test('allUoms returns empty when no UoMs populated', () {
        expect(service.allUoms, isEmpty);
      });

      test('allCategories returns empty when no categories populated', () {
        expect(service.allCategories, isEmpty);
      });

      test('allTaxes returns empty when no taxes populated', () {
        expect(service.allTaxes, isEmpty);
      });
    });
  });

  // ===========================================================================
  // UoM operations with populated cache
  // ===========================================================================
  group('UoM operations (populated)', () {
    late Uom units;
    late Uom kg;

    setUp(() {
      units = UomFactory.create(id: 1, name: 'Units');
      kg = UomFactory.create(id: 2, name: 'Kg');
      service.populateForTesting(uoms: [units, kg]);
    });

    test('getUom returns UoM for existing ID', () {
      final result = service.getUom(1);
      expect(result, isNotNull);
      expect(result!.name, 'Units');
    });

    test('getUom returns null for non-existent ID', () {
      expect(service.getUom(999), isNull);
    });

    test('resolveUomName returns local name when UoM exists', () {
      final name = service.resolveUomName(2, 'fallback');
      expect(name, 'Kg');
    });

    test('resolveUomName returns fallback when UoM does not exist', () {
      final name = service.resolveUomName(999, 'litro');
      expect(name, 'litro');
    });

    test('resolveUomName returns "Unid." when UoM does not exist and no fallback', () {
      final name = service.resolveUomName(999);
      expect(name, 'Unid.');
    });

    test('allUoms returns all populated UoMs', () {
      final all = service.allUoms;
      expect(all.length, 2);
      expect(all.map((u) => u.name).toSet(), {'Units', 'Kg'});
    });
  });

  // ===========================================================================
  // Category operations with populated cache
  // ===========================================================================
  group('Category operations (populated)', () {
    late ProductCategory electronics;
    late ProductCategory tools;

    setUp(() {
      electronics = ProductCategoryFactory.create(
        id: 10,
        name: 'Electronics',
        completeName: 'All / Electronics',
      );
      tools = ProductCategoryFactory.create(
        id: 20,
        name: 'Tools',
      );
      service.populateForTesting(categories: [electronics, tools]);
    });

    test('getCategory returns category for existing ID', () {
      final result = service.getCategory(10);
      expect(result, isNotNull);
      expect(result!.name, 'Electronics');
    });

    test('getCategory returns null for non-existent ID', () {
      expect(service.getCategory(999), isNull);
    });

    test('resolveCategoryName returns displayName (completeName) when exists', () {
      final name = service.resolveCategoryName(10, 'Fallback');
      expect(name, 'All / Electronics');
    });

    test('resolveCategoryName returns name when completeName is null', () {
      final name = service.resolveCategoryName(20);
      expect(name, 'Tools');
    });

    test('resolveCategoryName returns fallback when category does not exist', () {
      final name = service.resolveCategoryName(999, 'Fallback Category');
      expect(name, 'Fallback Category');
    });

    test('allCategories returns all populated categories', () {
      final all = service.allCategories;
      expect(all.length, 2);
    });
  });

  // ===========================================================================
  // Tax operations with populated cache
  // ===========================================================================
  group('Tax operations (populated)', () {
    late Tax iva15;
    late Tax iva0;
    late Tax fixedTax;

    setUp(() {
      iva15 = TaxFactory.create(id: 1, name: 'VAT 15% G', amount: 15.0);
      iva0 = TaxFactory.zeroRated(id: 2, name: 'VAT 0%');
      fixedTax = TaxFactory.fixed(id: 3, name: 'ICE', amount: 2.50);
      service.populateForTesting(taxes: [iva15, iva0, fixedTax]);
    });

    group('getTax', () {
      test('returns tax for existing ID', () {
        final result = service.getTax(1);
        expect(result, isNotNull);
        expect(result!.name, 'VAT 15% G');
      });

      test('returns null for non-existent ID', () {
        expect(service.getTax(999), isNull);
      });
    });

    group('resolveTaxNames', () {
      test('resolves single tax ID to name', () {
        final result = service.resolveTaxNames('1');
        expect(result, 'VAT 15% G');
      });

      test('resolves multiple tax IDs to comma-separated names', () {
        final result = service.resolveTaxNames('1,2');
        expect(result, 'VAT 15% G, VAT 0%');
      });

      test('resolves with whitespace in CSV', () {
        final result = service.resolveTaxNames('1 , 2 , 3');
        expect(result, 'VAT 15% G, VAT 0%, ICE');
      });

      test('skips non-existent IDs and returns found ones', () {
        final result = service.resolveTaxNames('1,999');
        expect(result, 'VAT 15% G');
      });

      test('returns fallback when all IDs are non-existent', () {
        final result = service.resolveTaxNames('888,999', 'Embedded Tax Name');
        expect(result, 'Embedded Tax Name');
      });

      test('returns empty string when all IDs non-existent and no fallback', () {
        final result = service.resolveTaxNames('888,999');
        expect(result, '');
      });

      test('returns fallback for invalid (non-numeric) string', () {
        final result = service.resolveTaxNames('abc,def', 'Fallback');
        expect(result, 'Fallback');
      });

      test('returns empty string for null input', () {
        expect(service.resolveTaxNames(null), '');
      });

      test('returns fallback for empty input', () {
        expect(service.resolveTaxNames('', 'fallback'), 'fallback');
      });
    });

    group('resolveTaxGroupName', () {
      test('formats integer percentage as IVA N%', () {
        final result = service.resolveTaxGroupName('1');
        expect(result, 'IVA 15%');
      });

      test('formats zero percentage as IVA 0%', () {
        final result = service.resolveTaxGroupName('2');
        expect(result, 'IVA 0%');
      });

      test('formats decimal percentage correctly', () {
        // fixedTax has amount 2.5 — still formatted as IVA N%
        final result = service.resolveTaxGroupName('3');
        expect(result, 'IVA 2.5%');
      });

      test('deduplicates identical group names', () {
        // Two taxes with same amount=15 → only one "IVA 15%"
        // Add another 15% tax to the service
        final extraTax = TaxFactory.create(id: 4, name: 'VAT 15% S', amount: 15.0);
        service.populateForTesting(taxes: [iva15, extraTax]);

        final result = service.resolveTaxGroupName('1,4');
        expect(result, 'IVA 15%'); // deduplicated via toSet()
      });

      test('joins different group names', () {
        final result = service.resolveTaxGroupName('1,2');
        expect(result, 'IVA 15%, IVA 0%');
      });

      test('returns fallback when IDs not found', () {
        final result = service.resolveTaxGroupName('999', 'VAT fallback');
        expect(result, 'VAT fallback');
      });

      test('returns empty for null input', () {
        expect(service.resolveTaxGroupName(null), '');
      });

      test('returns fallback for empty input', () {
        expect(service.resolveTaxGroupName('', 'FB'), 'FB');
      });
    });

    test('allTaxes returns all populated taxes', () {
      final all = service.allTaxes;
      expect(all.length, 3);
    });
  });

  // ===========================================================================
  // needsRefresh / timing logic
  // ===========================================================================
  group('needsRefresh', () {
    test('returns true when not loaded', () {
      expect(service.needsRefresh, isTrue);
    });

    test('returns false right after populating', () {
      service.populateForTesting(products: []);
      expect(service.needsRefresh, isFalse);
    });

    test('returns true after clear()', () {
      service.populateForTesting(products: []);
      service.clear();
      expect(service.needsRefresh, isTrue);
    });
  });

  // ===========================================================================
  // clear() with populated data
  // ===========================================================================
  group('clear() after populate', () {
    test('resets all counts to zero', () {
      service.populateForTesting(
        products: [ProductFactory.create(id: 1)],
        uoms: [UomFactory.create(id: 1)],
        categories: [ProductCategoryFactory.create(id: 1)],
        taxes: [TaxFactory.create(id: 1)],
      );

      expect(service.productCount, 1);
      expect(service.uomCount, 1);
      expect(service.categoryCount, 1);

      service.clear();

      expect(service.productCount, 0);
      expect(service.uomCount, 0);
      expect(service.categoryCount, 0);
      expect(service.isLoaded, isFalse);
    });

    test('getProduct returns null after clear', () {
      service.populateForTesting(
        products: [ProductFactory.create(id: 42, name: 'Widget')],
      );
      expect(service.getProduct(42), isNotNull);

      service.clear();
      expect(service.getProduct(42), isNull);
    });
  });

  // ===========================================================================
  // Edge cases with populated data
  // ===========================================================================
  group('Edge cases', () {
    test('populating with duplicate IDs keeps last one', () {
      final p1 = ProductFactory.create(id: 1, name: 'First');
      final p2 = ProductFactory.create(id: 1, name: 'Second');
      service.populateForTesting(products: [p1, p2]);

      expect(service.productCount, 1);
      expect(service.getProduct(1)!.name, 'Second');
    });

    test('populating products only does not affect other caches', () {
      service.populateForTesting(
        products: [ProductFactory.create(id: 1)],
      );

      expect(service.productCount, 1);
      expect(service.uomCount, 0);
      expect(service.categoryCount, 0);
      expect(service.allTaxes, isEmpty);
    });

    test('barcode index maps products correctly', () {
      final p1 = ProductFactory.create(id: 1, name: 'A', barcode: 'BC001');
      final p2 = ProductFactory.create(id: 2, name: 'B', barcode: 'BC002');
      final p3 = ProductFactory.create(id: 3, name: 'C'); // no barcode
      service.populateForTesting(products: [p1, p2, p3]);

      expect(service.stats['productsByBarcode'], 2);
      expect(service.getProductByBarcode('BC001')!.name, 'A');
      expect(service.getProductByBarcode('BC002')!.name, 'B');
    });

    test('code index maps products case-insensitively', () {
      final p = ProductFactory.create(id: 1, name: 'Mixed', defaultCode: 'MiXeD-123');
      service.populateForTesting(products: [p]);

      expect(service.getProductByCode('mixed-123'), isNotNull);
      expect(service.getProductByCode('MIXED-123'), isNotNull);
      expect(service.getProductByCode('MiXeD-123'), isNotNull);
    });

    test('searchProducts matches on barcode exactly (case-sensitive for digits)', () {
      final p = ProductFactory.create(id: 1, name: 'Gadget', barcode: '12345');
      service.populateForTesting(products: [p]);

      expect(service.searchProducts('12345').length, 1);
      expect(service.searchProducts('1234').length, 1); // partial barcode match
      expect(service.searchProducts('99999'), isEmpty);
    });

    test('resolveTaxNames with mixed valid and invalid entries', () {
      service.populateForTesting(
        taxes: [TaxFactory.create(id: 5, name: 'Tax A', amount: 10.0)],
      );
      // "5,abc,6" - 5 is valid, abc is not a number (parsed to null, filtered), 6 does not exist
      final result = service.resolveTaxNames('5,abc,6');
      expect(result, 'Tax A');
    });
  });
}
