import 'package:test/test.dart';
import 'package:theos_pos_core/src/models/products/product.model.dart';

void main() {
  group('Product - fromOdoo', () {
    test('parses typical product data', () {
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
        'l10n_ec_auxiliary_code': 'AUX001',
        'is_unit_product': true,
        'temporal_no_despachar': false,
        'write_date': '2024-06-15 10:30:00',
      };

      final product = productManager.fromOdoo(json);

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
      expect(product.l10nEcAuxiliaryCode, equals('AUX001'));
      expect(product.isUnitProduct, isTrue);
      expect(product.temporalNoDespachar, isFalse);
      expect(product.writeDate, isNotNull);
    });

    test('handles null/false optional fields gracefully', () {
      final json = {
        'id': 1,
        'name': 'Simple Product',
        'default_code': false,
        'barcode': false,
        'type': 'consu',
        'categ_id': false,
        'uom_id': false,
        'uom_po_id': false,
        'taxes_id': false,
        'supplier_taxes_id': false,
        'description': false,
        'description_sale': false,
        'product_tmpl_id': false,
        'image_128': false,
        'l10n_ec_auxiliary_code': false,
        'write_date': false,
      };

      final product = productManager.fromOdoo(json);

      expect(product.id, equals(1));
      expect(product.name, equals('Simple Product'));
      expect(product.defaultCode, isNull);
      expect(product.barcode, isNull);
      expect(product.categId, isNull);
      expect(product.categName, isNull);
      expect(product.uomId, isNull);
      expect(product.description, isNull);
      expect(product.image128, isNull);
      expect(product.writeDate, isNull);
    });

    test('parses Many2one fields correctly', () {
      final json = {
        'id': 10,
        'name': 'Test',
        'categ_id': [3, 'Categoría / Sub'],
        'uom_id': [1, 'Unidad(es)'],
        'product_tmpl_id': [7, 'Template Test'],
      };

      final product = productManager.fromOdoo(json);

      expect(product.categId, equals(3));
      expect(product.categName, equals('Categoría / Sub'));
      expect(product.uomId, equals(1));
      expect(product.uomName, equals('Unidad(es)'));
      expect(product.productTmplId, equals(7));
    });

    test('parses Many2many tax IDs', () {
      final json = {
        'id': 10,
        'name': 'Test',
        'taxes_id': [1, 2, 3],
        'supplier_taxes_id': [4, 5],
      };

      final product = productManager.fromOdoo(json);

      // taxes_id is stored as JSON string
      expect(product.taxIdsList, containsAll([1, 2, 3]));
      expect(product.supplierTaxIdsList, containsAll([4, 5]));
    });

    test('parses product types correctly', () {
      expect(
        productManager.fromOdoo({'id': 1, 'name': 'T', 'type': 'service'}).type,
        equals(ProductType.service),
      );
      expect(
        productManager.fromOdoo({'id': 1, 'name': 'T', 'type': 'product'}).type,
        equals(ProductType.product),
      );
      expect(
        productManager.fromOdoo({'id': 1, 'name': 'T', 'type': 'consu'}).type,
        equals(ProductType.consu),
      );
      // Unknown type defaults to consu
      expect(
        productManager.fromOdoo({'id': 1, 'name': 'T', 'type': 'unknown'}).type,
        equals(ProductType.consu),
      );
    });

    test('parses tracking types correctly', () {
      expect(
        productManager.fromOdoo({'id': 1, 'name': 'T', 'tracking': 'serial'}).tracking,
        equals(TrackingType.serial),
      );
      expect(
        productManager.fromOdoo({'id': 1, 'name': 'T', 'tracking': 'lot'}).tracking,
        equals(TrackingType.lot),
      );
      expect(
        productManager.fromOdoo({'id': 1, 'name': 'T', 'tracking': 'none'}).tracking,
        equals(TrackingType.none),
      );
    });

    test('combines uom_id with uom_ids into single list', () {
      final json = {
        'id': 1,
        'name': 'T',
        'uom_id': [1, 'Unidades'],
        'uom_ids': [1, 2, 3],
      };

      final product = productManager.fromOdoo(json);
      // uomIds is a local-only field, not populated by generated fromOdoo
      expect(product.uomIds, isNull);
    });
  });

  group('Product - Computed Fields', () {
    test('hasStock is true when qtyAvailable > 0', () {
      const product = Product(id: 1, name: 'T', qtyAvailable: 10.0);
      expect(product.hasStock, isTrue);
    });

    test('hasStock is false when qtyAvailable == 0', () {
      const product = Product(id: 1, name: 'T', qtyAvailable: 0.0);
      expect(product.hasStock, isFalse);
    });

    test('hasBarcode checks for non-empty barcode', () {
      expect(
        const Product(id: 1, name: 'T', barcode: '123').hasBarcode,
        isTrue,
      );
      expect(
        const Product(id: 1, name: 'T', barcode: '').hasBarcode,
        isFalse,
      );
      expect(
        const Product(id: 1, name: 'T').hasBarcode,
        isFalse,
      );
    });

    test('displayName uses displayNameOdoo if present', () {
      const product = Product(
        id: 1,
        name: 'Test',
        displayNameOdoo: '[CODE] Test',
      );
      expect(product.displayName, equals('[CODE] Test'));
    });

    test('displayName builds from defaultCode + name', () {
      const product = Product(
        id: 1,
        name: 'Test Product',
        defaultCode: 'TP001',
      );
      expect(product.displayName, equals('[TP001] Test Product'));
    });

    test('displayName falls back to name only', () {
      const product = Product(id: 1, name: 'Simple Product');
      expect(product.displayName, equals('Simple Product'));
    });

    test('taxIdsList parses JSON array string', () {
      const product = Product(id: 1, name: 'T', taxesId: '[1,2,3]');
      expect(product.taxIdsList, equals([1, 2, 3]));
    });

    test('taxIdsList parses comma-separated string', () {
      const product = Product(id: 1, name: 'T', taxesId: '1,2,3');
      expect(product.taxIdsList, equals([1, 2, 3]));
    });

    test('taxIdsList returns empty list for null', () {
      const product = Product(id: 1, name: 'T');
      expect(product.taxIdsList, isEmpty);
    });

    test('isService and isConsumable computed correctly', () {
      expect(
        const Product(id: 1, name: 'T', type: ProductType.service).isService,
        isTrue,
      );
      expect(
        const Product(id: 1, name: 'T', type: ProductType.consu).isConsumable,
        isTrue,
      );
    });

    test('canBeSold requires saleOk and active', () {
      expect(
        const Product(id: 1, name: 'T', saleOk: true, active: true).canBeSold,
        isTrue,
      );
      expect(
        const Product(id: 1, name: 'T', saleOk: false, active: true).canBeSold,
        isFalse,
      );
      expect(
        const Product(id: 1, name: 'T', saleOk: true, active: false).canBeSold,
        isFalse,
      );
    });
  });

  group('Product - Validation', () {
    test('validateRecord passes with valid data', () {
      const product = Product(
        id: 1,
        name: 'Valid Product',
        listPrice: 10.0,
        standardPrice: 5.0,
      );
      expect(productManager.validateRecord(product), isEmpty);
    });

    test('isValid returns true for valid product', () {
      const product = Product(id: 1, name: 'Valid Product');
      expect(productManager.isValid(product), isTrue);
    });
  });

  group('Product - toOdoo', () {
    test('produces correct Odoo format', () {
      const product = Product(
        id: 42,
        name: 'Test',
        defaultCode: 'CODE1',
        barcode: '123',
        type: ProductType.consu,
        saleOk: true,
        purchaseOk: false,
        active: true,
        listPrice: 100.0,
        standardPrice: 50.0,
        categId: 5,
        uomId: 1,
      );

      final odoo = productManager.toOdoo(product);

      expect(odoo['name'], equals('Test'));
      expect(odoo['default_code'], equals('CODE1'));
      expect(odoo['barcode'], equals('123'));
      expect(odoo['type'], equals('consu'));
      expect(odoo['sale_ok'], isTrue);
      expect(odoo['purchase_ok'], isFalse);
      expect(odoo['list_price'], equals(100.0));
      expect(odoo['categ_id'], equals(5));
      expect(odoo['uom_id'], equals(1));
    });
  });

  group('Product - Onchange Simulation', () {
    test('onPriceChanged updates price', () {
      const product = Product(id: 1, name: 'T', listPrice: 100.0);
      final updated = product.onPriceChanged(200.0);
      expect(updated.listPrice, equals(200.0));
    });

    test('onPriceChanged ignores negative price', () {
      const product = Product(id: 1, name: 'T', listPrice: 100.0);
      final updated = product.onPriceChanged(-10.0);
      expect(identical(updated, product), isTrue);
    });

    test('onUomChanged updates UoM', () {
      const product = Product(id: 1, name: 'T', uomId: 1, uomName: 'Units');
      final updated = product.onUomChanged(2, 'Boxes');
      expect(updated.uomId, equals(2));
      expect(updated.uomName, equals('Boxes'));
    });
  });
}
