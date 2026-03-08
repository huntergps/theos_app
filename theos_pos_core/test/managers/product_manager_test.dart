import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/products/product.model.dart';

void main() {
  late ProductManager manager;

  setUp(() {
    manager = ProductManager();
  });

  // ===========================================================================
  // 1. Metadata
  // ===========================================================================

  group('metadata', () {
    test('odooModel is product.product', () {
      expect(manager.odooModel, equals('product.product'));
    });

    test('tableName is product_products', () {
      expect(manager.tableName, equals('product_products'));
    });

    test('odooFields is a concrete list with essential fields', () {
      final fields = manager.odooFields;

      expect(fields, isA<List<String>>());
      expect(fields, isNotEmpty);
    });

    test('odooFields contains essential fields', () {
      final fields = manager.odooFields;

      expect(fields, contains('id'));
      expect(fields, contains('name'));
      expect(fields, contains('default_code'));
      expect(fields, contains('barcode'));
      expect(fields, contains('list_price'));
    });
  });

  // ===========================================================================
  // 2. fromOdoo
  // ===========================================================================

  group('fromOdoo', () {
    test('converts typical Odoo JSON to Product', () {
      final json = {
        'id': 42,
        'name': 'Laptop HP',
        'display_name': '[LAP001] Laptop HP',
        'default_code': 'LAP001',
        'barcode': '7861234567890',
        'type': 'consu',
        'sale_ok': true,
        'purchase_ok': true,
        'active': true,
        'list_price': 999.99,
        'standard_price': 750.0,
        'categ_id': [5, 'Electrónicos'],
        'uom_id': [1, 'Unidades'],
        'uom_po_id': [2, 'Cajas'],
        'taxes_id': [1, 2, 3],
        'supplier_taxes_id': [4],
        'description': 'Laptop de alta gama',
        'description_sale': 'Laptop HP 15 pulgadas',
        'product_tmpl_id': [10, 'Template'],
        'qty_available': 25.0,
        'virtual_available': 30.0,
        'tracking': 'serial',
        'is_storable': true,
        'write_date': '2024-06-15 10:30:00',
      };

      final product = manager.fromOdoo(json);

      expect(product, isA<Product>());
      expect(product.id, equals(42));
      expect(product.name, equals('Laptop HP'));
      expect(product.displayNameOdoo, equals('[LAP001] Laptop HP'));
      expect(product.defaultCode, equals('LAP001'));
      expect(product.barcode, equals('7861234567890'));
      expect(product.type, equals(ProductType.consu));
      expect(product.saleOk, isTrue);
      expect(product.purchaseOk, isTrue);
      expect(product.active, isTrue);
      expect(product.listPrice, equals(999.99));
      expect(product.standardPrice, equals(750.0));
      expect(product.categId, equals(5));
      expect(product.categName, equals('Electrónicos'));
      expect(product.uomId, equals(1));
      expect(product.uomName, equals('Unidades'));
      expect(product.uomPoId, equals(2));
      expect(product.uomPoName, equals('Cajas'));
      expect(product.qtyAvailable, equals(25.0));
      expect(product.virtualAvailable, equals(30.0));
      expect(product.tracking, equals(TrackingType.serial));
      expect(product.isStorable, isTrue);
      expect(product.writeDate, isNotNull);
    });

    test('handles minimal Odoo JSON', () {
      final json = {
        'id': 1,
        'name': 'Simple Product',
      };

      final product = manager.fromOdoo(json);

      expect(product.id, equals(1));
      expect(product.name, equals('Simple Product'));
      expect(product.defaultCode, isNull);
      expect(product.barcode, isNull);
      expect(product.listPrice, equals(0.0));
    });

    test('handles false values for optional fields', () {
      final json = {
        'id': 1,
        'name': 'Product',
        'default_code': false,
        'barcode': false,
        'categ_id': false,
        'description': false,
      };

      final product = manager.fromOdoo(json);

      expect(product.defaultCode, isNull);
      expect(product.barcode, isNull);
      expect(product.categId, isNull);
      expect(product.description, isNull);
    });
  });

  // ===========================================================================
  // 3. toOdoo
  // ===========================================================================

  group('toOdoo', () {
    test('converts Product to Odoo map', () {
      const product = Product(
        id: 42,
        name: 'Test Product',
        defaultCode: 'TP001',
        barcode: '7861234567890',
        type: ProductType.consu,
        saleOk: true,
        purchaseOk: false,
        active: true,
        listPrice: 100.0,
        standardPrice: 50.0,
        categId: 5,
        uomId: 1,
      );

      final map = manager.toOdoo(product);

      expect(map['name'], equals('Test Product'));
      expect(map['default_code'], equals('TP001'));
      expect(map['barcode'], equals('7861234567890'));
      expect(map['sale_ok'], isTrue);
      expect(map['purchase_ok'], isFalse);
      expect(map['active'], isTrue);
      expect(map['list_price'], equals(100.0));
      expect(map['standard_price'], equals(50.0));
      expect(map['categ_id'], equals(5));
      expect(map['uom_id'], equals(1));
    });

    test('includes null optional fields in Odoo map', () {
      const product = Product(
        id: 1,
        name: 'Minimal',
      );

      final map = manager.toOdoo(product);

      expect(map.containsKey('name'), isTrue);
      // Generated toOdoo includes all writable fields
      expect(map['name'], equals('Minimal'));
    });
  });

  // ===========================================================================
  // 4. Record Manipulation
  // ===========================================================================

  group('record manipulation', () {
    late Product sampleProduct;

    setUp(() {
      sampleProduct = const Product(
        id: 42,
        name: 'Laptop HP',
        defaultCode: 'LAP001',
        barcode: '7861234567890',
        listPrice: 999.99,
      );
    });

    test('getId returns record.id', () {
      expect(manager.getId(sampleProduct), equals(42));
    });

    test('getUuid returns null (no UUID support)', () {
      expect(manager.getUuid(sampleProduct), isNull);
    });

    test('withIdAndUuid sets id and ignores uuid', () {
      final updated = manager.withIdAndUuid(sampleProduct, 100, 'some-uuid');

      expect(updated.id, equals(100));
      expect(updated.name, equals('Laptop HP'));
      expect(updated.defaultCode, equals('LAP001'));
      expect(updated.listPrice, equals(999.99));
    });

    test('withIdAndUuid preserves all other fields', () {
      final updated = manager.withIdAndUuid(sampleProduct, 200, 'ignored');

      expect(updated.barcode, equals(sampleProduct.barcode));
      expect(updated.name, equals(sampleProduct.name));
      expect(updated.defaultCode, equals(sampleProduct.defaultCode));
      expect(updated.listPrice, equals(sampleProduct.listPrice));
    });

    test('withSyncStatus returns the same record (identity)', () {
      final result = manager.withSyncStatus(sampleProduct, true);
      expect(identical(result, sampleProduct), isTrue);

      final result2 = manager.withSyncStatus(sampleProduct, false);
      expect(identical(result2, sampleProduct), isTrue);
    });

    test('readLocalByUuid throws when no database is initialized', () async {
      expect(
        () => manager.readLocalByUuid('any-uuid'),
        throwsStateError,
      );
    });

    test('getUnsyncedRecords throws when no database is initialized', () async {
      expect(
        () => manager.getUnsyncedRecords(),
        throwsStateError,
      );
    });
  });
}
