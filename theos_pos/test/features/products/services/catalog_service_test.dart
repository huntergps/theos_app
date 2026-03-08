import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/features/products/services/catalog_service.dart';

void main() {
  late CatalogService service;

  setUp(() {
    service = CatalogService();
  });

  group('General / initial state', () {
    test('isLoaded is false on creation', () {
      expect(service.isLoaded, isFalse);
    });

    test('needsRefresh is true on creation', () {
      expect(service.needsRefresh, isTrue);
    });

    test('productCount is 0 on creation', () {
      expect(service.productCount, 0);
    });

    test('uomCount is 0 on creation', () {
      expect(service.uomCount, 0);
    });

    test('categoryCount is 0 on creation', () {
      expect(service.categoryCount, 0);
    });

    test('stats returns all zeroes when empty', () {
      final s = service.stats;
      expect(s['products'], 0);
      expect(s['productsByBarcode'], 0);
      expect(s['productsByCode'], 0);
      expect(s['uoms'], 0);
      expect(s['categories'], 0);
      expect(s['taxes'], 0);
    });
  });

  group('clear()', () {
    test('resets isLoaded to false', () {
      // clear on a fresh service should keep isLoaded false
      service.clear();
      expect(service.isLoaded, isFalse);
    });

    test('resets needsRefresh to true after clear', () {
      service.clear();
      expect(service.needsRefresh, isTrue);
    });

    test('resets all counts to zero', () {
      service.clear();
      expect(service.productCount, 0);
      expect(service.uomCount, 0);
      expect(service.categoryCount, 0);
    });
  });

  group('Products', () {
    test('getProduct(null) returns null', () {
      expect(service.getProduct(null), isNull);
    });

    test('getProduct with non-existent ID returns null', () {
      expect(service.getProduct(999), isNull);
    });

    test('getProductByBarcode(null) returns null', () {
      expect(service.getProductByBarcode(null), isNull);
    });

    test('getProductByBarcode empty string returns null', () {
      expect(service.getProductByBarcode(''), isNull);
    });

    test('getProductByBarcode with non-existent barcode returns null', () {
      expect(service.getProductByBarcode('1234567890'), isNull);
    });

    test('getProductByCode(null) returns null', () {
      expect(service.getProductByCode(null), isNull);
    });

    test('getProductByCode empty string returns null', () {
      expect(service.getProductByCode(''), isNull);
    });

    test('getProductByCode with non-existent code returns null', () {
      expect(service.getProductByCode('NOEXIST'), isNull);
    });

    test('resolveProductName(null, null) returns empty string', () {
      expect(service.resolveProductName(null, null), '');
    });

    test('resolveProductName(null, fallback) returns fallback', () {
      expect(service.resolveProductName(null, 'fallback'), 'fallback');
    });

    test('resolveProductName(nonExistentId, fallback) returns fallback', () {
      expect(service.resolveProductName(999, 'fallback'), 'fallback');
    });

    test('resolveProductName(nonExistentId, null) returns empty string', () {
      expect(service.resolveProductName(999, null), '');
    });

    test('resolveProductDisplayName(null, null) returns empty string', () {
      expect(service.resolveProductDisplayName(null, null), '');
    });

    test('resolveProductDisplayName(null, fallback) returns fallback', () {
      expect(service.resolveProductDisplayName(null, 'My Product'), 'My Product');
    });

    test('resolveProductCode(null, null) returns null', () {
      expect(service.resolveProductCode(null, null), isNull);
    });

    test('resolveProductCode(null, fallback) returns fallback', () {
      expect(service.resolveProductCode(null, 'PROD-001'), 'PROD-001');
    });

    test('searchProducts with empty query returns empty list', () {
      expect(service.searchProducts(''), isEmpty);
    });

    test('searchProducts with non-empty query on empty cache returns empty list', () {
      expect(service.searchProducts('test'), isEmpty);
    });
  });

  group('UoMs', () {
    test('getUom(null) returns null', () {
      expect(service.getUom(null), isNull);
    });

    test('getUom with non-existent ID returns null', () {
      expect(service.getUom(999), isNull);
    });

    test('resolveUomName(null, null) returns "Unid."', () {
      expect(service.resolveUomName(null, null), 'Unid.');
    });

    test('resolveUomName(null, "kg") returns "kg"', () {
      expect(service.resolveUomName(null, 'kg'), 'kg');
    });

    test('resolveUomName(nonExistentId, null) returns "Unid."', () {
      expect(service.resolveUomName(999, null), 'Unid.');
    });

    test('resolveUomName(nonExistentId, "litro") returns "litro"', () {
      expect(service.resolveUomName(999, 'litro'), 'litro');
    });

    test('allUoms is empty on creation', () {
      expect(service.allUoms, isEmpty);
    });
  });

  group('Categories', () {
    test('getCategory(null) returns null', () {
      expect(service.getCategory(null), isNull);
    });

    test('getCategory with non-existent ID returns null', () {
      expect(service.getCategory(999), isNull);
    });

    test('resolveCategoryName(null, null) returns empty string', () {
      expect(service.resolveCategoryName(null, null), '');
    });

    test('resolveCategoryName(null, "Electro") returns "Electro"', () {
      expect(service.resolveCategoryName(null, 'Electro'), 'Electro');
    });

    test('resolveCategoryName(nonExistentId, null) returns empty string', () {
      expect(service.resolveCategoryName(999, null), '');
    });

    test('resolveCategoryName(nonExistentId, "Tools") returns "Tools"', () {
      expect(service.resolveCategoryName(999, 'Tools'), 'Tools');
    });

    test('allCategories is empty on creation', () {
      expect(service.allCategories, isEmpty);
    });
  });

  group('Taxes', () {
    test('getTax(null) returns null', () {
      expect(service.getTax(null), isNull);
    });

    test('getTax with non-existent ID returns null', () {
      expect(service.getTax(999), isNull);
    });

    test('resolveTaxNames(null, null) returns empty string', () {
      expect(service.resolveTaxNames(null, null), '');
    });

    test('resolveTaxNames(null, "IVA 15%") returns "IVA 15%"', () {
      expect(service.resolveTaxNames(null, 'IVA 15%'), 'IVA 15%');
    });

    test('resolveTaxNames("", null) returns empty string', () {
      expect(service.resolveTaxNames('', null), '');
    });

    test('resolveTaxNames("", "IVA 15%") returns "IVA 15%"', () {
      expect(service.resolveTaxNames('', 'IVA 15%'), 'IVA 15%');
    });

    test('resolveTaxNames with non-existent IDs returns fallback', () {
      expect(service.resolveTaxNames('999,888', 'fallback'), 'fallback');
    });

    test('resolveTaxNames with non-existent IDs and no fallback returns empty', () {
      expect(service.resolveTaxNames('999,888', null), '');
    });

    test('resolveTaxNames with invalid string returns fallback', () {
      expect(service.resolveTaxNames('abc,def', 'fallback'), 'fallback');
    });

    test('resolveTaxGroupName(null, null) returns empty string', () {
      expect(service.resolveTaxGroupName(null, null), '');
    });

    test('resolveTaxGroupName(null, "IVA 15%") returns "IVA 15%"', () {
      expect(service.resolveTaxGroupName(null, 'IVA 15%'), 'IVA 15%');
    });

    test('resolveTaxGroupName("", null) returns empty string', () {
      expect(service.resolveTaxGroupName('', null), '');
    });

    test('resolveTaxGroupName with non-existent IDs returns fallback', () {
      expect(service.resolveTaxGroupName('999', 'VAT 15%'), 'VAT 15%');
    });

    test('resolveTaxGroupName with non-existent IDs and no fallback returns empty', () {
      expect(service.resolveTaxGroupName('999', null), '');
    });

    test('allTaxes is empty on creation', () {
      expect(service.allTaxes, isEmpty);
    });
  });
}
