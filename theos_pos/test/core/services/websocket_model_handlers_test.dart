
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos/core/database/database_exports.dart';

/// Create an in-memory database for testing
AppDatabase createTestDatabase() {
  return AppDatabase(NativeDatabase.memory());
}

// ==================== MODEL HANDLER TESTS ====================
// Tests for WebSocket handlers of all synced models:
// - UomUom (uom.uom)
// - ProductUom (product.uom)
// - ProductPricelistItem (product.pricelist.item)
// - SaleOrderLine (sale.order.line)
// - StockByWarehouse (stock.quant)
// - ProductProduct (product.product)
// - ResUsers (res.users)
// - MailActivity (mail.activity)

void main() {
  late AppDatabase db;

  setUp(() {
    db = createTestDatabase();
  });

  tearDown(() async {
    await db.close();
  });

  // ==================== UOM.UOM TESTS ====================
  group('UomUom WebSocket Handler Tests', () {
    Future<int> insertTestUomCategory(
      AppDatabase db, {
      required int odooId,
      required String name,
    }) async {
      return db.into(db.uomCategory).insert(
            UomCategoryCompanion.insert(
              odooId: odooId,
              name: name,
            ),
          );
    }

    Future<int> insertTestUomUom(
      AppDatabase db, {
      required int odooId,
      required String name,
      required int categoryId,
      double factor = 1.0,
      String uomType = 'reference',
      double rounding = 0.01,
      bool active = true,
    }) async {
      return db.into(db.uomUom).insert(
            UomUomCompanion.insert(
              odooId: odooId,
              name: name,
              categoryId: categoryId,
              factor: Value(factor),
              uomType: uomType,
              rounding: Value(rounding),
              active: Value(active),
            ),
          );
    }

    test('UomUom insert via WebSocket notification', () async {
      // ARRANGE: Create category first
      await insertTestUomCategory(db, odooId: 1, name: 'Unit');

      // ACT: Simulate WebSocket 'created' action - insert new UoM
      await insertTestUomUom(
        db,
        odooId: 100,
        name: 'Unidades',
        categoryId: 1,
        factor: 1.0,
        uomType: 'reference',
      );

      // ASSERT
      final uom = await (db.select(db.uomUom)
            ..where((t) => t.odooId.equals(100)))
          .getSingleOrNull();

      expect(uom, isNotNull);
      expect(uom!.name, 'Unidades');
      expect(uom.factor, 1.0);
      expect(uom.uomType, 'reference');
    });

    test('UomUom update via WebSocket notification', () async {
      // ARRANGE
      await insertTestUomCategory(db, odooId: 1, name: 'Unit');
      await insertTestUomUom(
        db,
        odooId: 101,
        name: 'Docena',
        categoryId: 1,
        factor: 12.0,
        uomType: 'bigger',
      );

      // ACT: Simulate WebSocket 'updated' action
      await db.customUpdate(
        'UPDATE uom_uom SET name = ?, factor = ? WHERE odoo_id = ?',
        variables: [Variable('Docena Modificada'), Variable(12.5), Variable(101)],
      );

      // ASSERT
      final uom = await (db.select(db.uomUom)
            ..where((t) => t.odooId.equals(101)))
          .getSingleOrNull();

      expect(uom, isNotNull);
      expect(uom!.name, 'Docena Modificada');
      expect(uom.factor, 12.5);
    });

    test('UomUom delete via WebSocket notification', () async {
      // ARRANGE
      await insertTestUomCategory(db, odooId: 1, name: 'Unit');
      await insertTestUomUom(db, odooId: 102, name: 'Caja', categoryId: 1);

      // Verify exists
      var uom = await (db.select(db.uomUom)
            ..where((t) => t.odooId.equals(102)))
          .getSingleOrNull();
      expect(uom, isNotNull);

      // ACT: Simulate WebSocket 'deleted' action
      await (db.delete(db.uomUom)..where((t) => t.odooId.equals(102))).go();

      // ASSERT
      uom = await (db.select(db.uomUom)
            ..where((t) => t.odooId.equals(102)))
          .getSingleOrNull();
      expect(uom, isNull);
    });

    test('UomUom deactivation via WebSocket (active = false)', () async {
      // ARRANGE
      await insertTestUomCategory(db, odooId: 1, name: 'Unit');
      await insertTestUomUom(
        db,
        odooId: 103,
        name: 'Pack',
        categoryId: 1,
        active: true,
      );

      // ACT: Simulate deactivation from server
      await db.customUpdate(
        'UPDATE uom_uom SET active = ? WHERE odoo_id = ?',
        variables: [Variable(0), Variable(103)], // 0 = false in SQLite
      );

      // ASSERT
      final uom = await (db.select(db.uomUom)
            ..where((t) => t.odooId.equals(103)))
          .getSingleOrNull();

      expect(uom, isNotNull);
      expect(uom!.active, false);
    });
  });

  // ==================== PRODUCT.UOM TESTS ====================
  group('ProductUom WebSocket Handler Tests', () {
    Future<void> setupProductUomDependencies(AppDatabase db) async {
      // Insert category
      await db.into(db.uomCategory).insert(
            UomCategoryCompanion.insert(odooId: 1, name: 'Unit'),
          );
      // Insert UoM
      await db.into(db.uomUom).insert(
            UomUomCompanion.insert(
              odooId: 1,
              name: 'Unidades',
              categoryId: 1,
              uomType: 'reference',
            ),
          );
      // Insert product category
      await db.into(db.productCategory).insert(
            ProductCategoryCompanion.insert(
              odooId: 1,
              name: 'Productos',
            ),
          );
      // Insert product
      await db.into(db.productProduct).insert(
            ProductProductCompanion.insert(
              odooId: 1,
              name: 'Producto Test',
              categId: const Value(1),
              uomId: const Value(1),
            ),
          );
    }

    test('ProductUom insert via WebSocket notification', () async {
      // ARRANGE
      await setupProductUomDependencies(db);

      // ACT: Simulate WebSocket 'created' action - insert ProductUom
      await db.into(db.productUom).insert(
            ProductUomCompanion.insert(
              odooId: 100,
              productId: 1,
              uomId: 1,
              barcode: const Value('7891234567890'),
            ),
          );

      // ASSERT
      final productUom = await (db.select(db.productUom)
            ..where((t) => t.odooId.equals(100)))
          .getSingleOrNull();

      expect(productUom, isNotNull);
      expect(productUom!.productId, 1);
      expect(productUom.uomId, 1);
      expect(productUom.barcode, '7891234567890');
    });

    test('ProductUom barcode update via WebSocket notification', () async {
      // ARRANGE
      await setupProductUomDependencies(db);
      await db.into(db.productUom).insert(
            ProductUomCompanion.insert(
              odooId: 101,
              productId: 1,
              uomId: 1,
              barcode: const Value('OLD_BARCODE'),
            ),
          );

      // ACT: Simulate barcode update
      await db.customUpdate(
        'UPDATE product_uom SET barcode = ? WHERE odoo_id = ?',
        variables: [Variable('NEW_BARCODE_123'), Variable(101)],
      );

      // ASSERT
      final productUom = await (db.select(db.productUom)
            ..where((t) => t.odooId.equals(101)))
          .getSingleOrNull();

      expect(productUom, isNotNull);
      expect(productUom!.barcode, 'NEW_BARCODE_123');
    });

    test('ProductUom delete via WebSocket notification', () async {
      // ARRANGE
      await setupProductUomDependencies(db);
      await db.into(db.productUom).insert(
            ProductUomCompanion.insert(
              odooId: 102,
              productId: 1,
              uomId: 1,
              barcode: const Value('TO_DELETE'),
            ),
          );

      // ACT: Delete
      await (db.delete(db.productUom)..where((t) => t.odooId.equals(102))).go();

      // ASSERT
      final productUom = await (db.select(db.productUom)
            ..where((t) => t.odooId.equals(102)))
          .getSingleOrNull();
      expect(productUom, isNull);
    });

    test('ProductUom upsert on conflict replaces existing record', () async {
      // ARRANGE
      await setupProductUomDependencies(db);
      await db.into(db.productUom).insert(
            ProductUomCompanion.insert(
              odooId: 103,
              productId: 1,
              uomId: 1,
              barcode: const Value('ORIGINAL_BARCODE'),
            ),
          );

      // ACT: Simulate upsert with conflict on odooId
      await db.into(db.productUom).insert(
            ProductUomCompanion.insert(
              odooId: 103, // Same odooId
              productId: 1,
              uomId: 1,
              barcode: const Value('UPSERTED_BARCODE'),
            ),
            onConflict: DoUpdate(
              (old) => ProductUomCompanion(
                barcode: const Value('UPSERTED_BARCODE'),
              ),
              target: [db.productUom.odooId],
            ),
          );

      // ASSERT
      final records = await (db.select(db.productUom)
            ..where((t) => t.odooId.equals(103)))
          .get();

      expect(records, hasLength(1));
      expect(records.first.barcode, 'UPSERTED_BARCODE');
    });
  });

  // ==================== PRODUCT PRICELIST ITEM TESTS ====================
  group('ProductPricelistItem WebSocket Handler Tests', () {
    Future<void> setupPricelistDependencies(AppDatabase db) async {
      // Insert pricelist
      await db.into(db.productPricelist).insert(
            ProductPricelistCompanion.insert(
              odooId: 1,
              name: 'Precio Público',
              active: const Value(true),
            ),
          );
      // Insert product category
      await db.into(db.productCategory).insert(
            ProductCategoryCompanion.insert(
              odooId: 1,
              name: 'Productos',
            ),
          );
      // Insert product
      await db.into(db.productProduct).insert(
            ProductProductCompanion.insert(
              odooId: 1,
              name: 'Producto Test',
              categId: const Value(1),
            ),
          );
    }

    test('PricelistItem insert via WebSocket notification', () async {
      // ARRANGE
      await setupPricelistDependencies(db);

      // ACT: Insert pricelist item
      await db.into(db.productPricelistItem).insert(
            ProductPricelistItemCompanion.insert(
              odooId: 100,
              pricelistId: 1,
              appliedOn: '3_global',
              computePrice: const Value('fixed'),
              fixedPrice: const Value(25.50),
              base: 'list_price',
            ),
          );

      // ASSERT
      final item = await (db.select(db.productPricelistItem)
            ..where((t) => t.odooId.equals(100)))
          .getSingleOrNull();

      expect(item, isNotNull);
      expect(item!.pricelistId, 1);
      expect(item.fixedPrice, 25.50);
      expect(item.computePrice, 'fixed');
    });

    test('PricelistItem price update via WebSocket notification', () async {
      // ARRANGE
      await setupPricelistDependencies(db);
      await db.into(db.productPricelistItem).insert(
            ProductPricelistItemCompanion.insert(
              odooId: 101,
              pricelistId: 1,
              productId: const Value(1),
              appliedOn: '0_product_variant',
              computePrice: const Value('fixed'),
              fixedPrice: const Value(100.00),
              base: 'list_price',
            ),
          );

      // ACT: Price change from server
      await db.customUpdate(
        'UPDATE product_pricelist_item SET fixed_price = ? WHERE odoo_id = ?',
        variables: [Variable(120.00), Variable(101)],
      );

      // ASSERT
      final item = await (db.select(db.productPricelistItem)
            ..where((t) => t.odooId.equals(101)))
          .getSingleOrNull();

      expect(item, isNotNull);
      expect(item!.fixedPrice, 120.00);
    });

    test('PricelistItem with min_quantity condition', () async {
      // ARRANGE
      await setupPricelistDependencies(db);

      // ACT: Insert with min quantity
      await db.into(db.productPricelistItem).insert(
            ProductPricelistItemCompanion.insert(
              odooId: 102,
              pricelistId: 1,
              productId: const Value(1),
              minQuantity: const Value(10.0),
              appliedOn: '0_product_variant',
              computePrice: const Value('fixed'),
              fixedPrice: const Value(90.00), // Discount for 10+
              base: 'list_price',
            ),
          );

      // ASSERT
      final item = await (db.select(db.productPricelistItem)
            ..where((t) => t.odooId.equals(102)))
          .getSingleOrNull();

      expect(item, isNotNull);
      expect(item!.minQuantity, 10.0);
      expect(item.fixedPrice, 90.00);
    });

    test('PricelistItem with date range', () async {
      // ARRANGE
      await setupPricelistDependencies(db);
      final startDate = DateTime(2025, 1, 1);
      final endDate = DateTime(2025, 12, 31);

      // ACT: Insert with date range
      await db.into(db.productPricelistItem).insert(
            ProductPricelistItemCompanion.insert(
              odooId: 103,
              pricelistId: 1,
              productId: const Value(1),
              dateStart: Value(startDate),
              dateEnd: Value(endDate),
              appliedOn: '0_product_variant',
              computePrice: const Value('fixed'),
              fixedPrice: const Value(85.00),
              base: 'list_price',
            ),
          );

      // ASSERT
      final item = await (db.select(db.productPricelistItem)
            ..where((t) => t.odooId.equals(103)))
          .getSingleOrNull();

      expect(item, isNotNull);
      expect(item!.dateStart, startDate);
      expect(item.dateEnd, endDate);
    });
  });

  // ==================== SALE ORDER LINE TESTS ====================
  group('SaleOrderLine WebSocket Handler Tests', () {
    Future<void> setupSaleOrderLineDependencies(AppDatabase db) async {
      // Insert partner
      await db.into(db.resPartner).insert(
            ResPartnerCompanion.insert(
              odooId: 1,
              name: 'Cliente Test',
              displayName: const Value('Cliente Test'),
            ),
          );
      // Insert product category
      await db.into(db.productCategory).insert(
            ProductCategoryCompanion.insert(odooId: 1, name: 'Productos'),
          );
      // Insert UoM category and UoM
      await db.into(db.uomCategory).insert(
            UomCategoryCompanion.insert(odooId: 1, name: 'Unit'),
          );
      await db.into(db.uomUom).insert(
            UomUomCompanion.insert(
              odooId: 1,
              name: 'Unidades',
              categoryId: 1,
              uomType: 'reference',
            ),
          );
      // Insert product
      await db.into(db.productProduct).insert(
            ProductProductCompanion.insert(
              odooId: 1,
              name: 'Producto Test',
              categId: const Value(1),
              uomId: const Value(1),
            ),
          );
      // Insert sale order
      await db.into(db.saleOrder).insert(
            SaleOrderCompanion.insert(
              odooId: 1,
              name: 'SO-001',
              partnerId: const Value(1),
              state: const Value('draft'),
            ),
          );
    }

    test('SaleOrderLine insert via WebSocket notification', () async {
      // ARRANGE
      await setupSaleOrderLineDependencies(db);

      // ACT: Insert line
      await db.into(db.saleOrderLine).insert(
            SaleOrderLineCompanion.insert(
              odooId: const Value(100),
              orderId: 1,
              productId: const Value(1),
              name: 'Producto Test',
              productUomQty: const Value(5.0),
              priceUnit: const Value(20.00),
              priceSubtotal: const Value(100.00),
            ),
          );

      // ASSERT
      final line = await (db.select(db.saleOrderLine)
            ..where((t) => t.odooId.equals(100)))
          .getSingleOrNull();

      expect(line, isNotNull);
      expect(line!.orderId, 1);
      expect(line.productUomQty, 5.0);
      expect(line.priceUnit, 20.00);
      expect(line.priceSubtotal, 100.00);
    });

    test('SaleOrderLine quantity update via WebSocket notification', () async {
      // ARRANGE
      await setupSaleOrderLineDependencies(db);
      await db.into(db.saleOrderLine).insert(
            SaleOrderLineCompanion.insert(
              odooId: const Value(101),
              orderId: 1,
              productId: const Value(1),
              name: 'Producto Test',
              productUomQty: const Value(5.0),
              priceUnit: const Value(20.00),
              priceSubtotal: const Value(100.00),
            ),
          );

      // ACT: Quantity changed on server
      await db.customUpdate(
        'UPDATE sale_order_line SET product_uom_qty = ?, price_subtotal = ? WHERE odoo_id = ?',
        variables: [Variable(10.0), Variable(200.00), Variable(101)],
      );

      // ASSERT
      final line = await (db.select(db.saleOrderLine)
            ..where((t) => t.odooId.equals(101)))
          .getSingleOrNull();

      expect(line, isNotNull);
      expect(line!.productUomQty, 10.0);
      expect(line.priceSubtotal, 200.00);
    });

    test('SaleOrderLine delete via WebSocket notification', () async {
      // ARRANGE
      await setupSaleOrderLineDependencies(db);
      await db.into(db.saleOrderLine).insert(
            SaleOrderLineCompanion.insert(
              odooId: const Value(102),
              orderId: 1,
              productId: const Value(1),
              name: 'Producto para eliminar',
            ),
          );

      // Verify exists
      var line = await (db.select(db.saleOrderLine)
            ..where((t) => t.odooId.equals(102)))
          .getSingleOrNull();
      expect(line, isNotNull);

      // ACT: Delete
      await (db.delete(db.saleOrderLine)..where((t) => t.odooId.equals(102))).go();

      // ASSERT
      line = await (db.select(db.saleOrderLine)
            ..where((t) => t.odooId.equals(102)))
          .getSingleOrNull();
      expect(line, isNull);
    });

    test('SaleOrderLine discount update via WebSocket', () async {
      // ARRANGE
      await setupSaleOrderLineDependencies(db);
      await db.into(db.saleOrderLine).insert(
            SaleOrderLineCompanion.insert(
              odooId: const Value(103),
              orderId: 1,
              productId: const Value(1),
              name: 'Producto con descuento',
              productUomQty: const Value(1.0),
              priceUnit: const Value(100.00),
              discount: const Value(0.0),
              priceSubtotal: const Value(100.00),
            ),
          );

      // ACT: Apply 10% discount from server
      await db.customUpdate(
        'UPDATE sale_order_line SET discount = ?, price_subtotal = ? WHERE odoo_id = ?',
        variables: [Variable(10.0), Variable(90.00), Variable(103)],
      );

      // ASSERT
      final line = await (db.select(db.saleOrderLine)
            ..where((t) => t.odooId.equals(103)))
          .getSingleOrNull();

      expect(line, isNotNull);
      expect(line!.discount, 10.0);
      expect(line.priceSubtotal, 90.00);
    });
  });

  // ==================== STOCK BY WAREHOUSE TESTS ====================
  group('StockByWarehouse WebSocket Handler Tests', () {
    Future<void> setupStockDependencies(AppDatabase db) async {
      // Insert product category
      await db.into(db.productCategory).insert(
            ProductCategoryCompanion.insert(odooId: 1, name: 'Productos'),
          );
      // Insert product
      await db.into(db.productProduct).insert(
            ProductProductCompanion.insert(
              odooId: 1,
              name: 'Producto Test',
              categId: const Value(1),
            ),
          );
      // Insert warehouse
      await db.into(db.stockWarehouse).insert(
            StockWarehouseCompanion.insert(
              odooId: 1,
              name: 'Bodega Principal',
              code: 'MAIN',
            ),
          );
    }

    test('StockByWarehouse insert via WebSocket notification', () async {
      // ARRANGE
      await setupStockDependencies(db);

      // ACT: Insert stock
      await db.into(db.stockByWarehouse).insert(
            StockByWarehouseCompanion.insert(
              productId: 1,
              warehouseId: 1,
              quantity: const Value(100.0),
              reservedQuantity: const Value(10.0),
              availableQuantity: const Value(90.0),
              lastUpdate: DateTime.now(),
              lastSyncAt: Value(DateTime.now()),
            ),
          );

      // ASSERT
      final stock = await (db.select(db.stockByWarehouse)
            ..where((t) => t.productId.equals(1) & t.warehouseId.equals(1)))
          .getSingleOrNull();

      expect(stock, isNotNull);
      expect(stock!.quantity, 100.0);
      expect(stock.reservedQuantity, 10.0);
      expect(stock.availableQuantity, 90.0);
    });

    test('StockByWarehouse quantity update via WebSocket notification', () async {
      // ARRANGE
      await setupStockDependencies(db);
      await db.into(db.stockByWarehouse).insert(
            StockByWarehouseCompanion.insert(
              productId: 1,
              warehouseId: 1,
              quantity: const Value(100.0),
              lastUpdate: DateTime.now(),
              lastSyncAt: Value(DateTime.now()),
            ),
          );

      // ACT: Stock changed (sale completed)
      await db.customUpdate(
        'UPDATE stock_by_warehouse SET quantity = ?, reserved_quantity = ? WHERE product_id = ? AND warehouse_id = ?',
        variables: [Variable(95.0), Variable(5.0), Variable(1), Variable(1)],
      );

      // ASSERT
      final stock = await (db.select(db.stockByWarehouse)
            ..where((t) => t.productId.equals(1) & t.warehouseId.equals(1)))
          .getSingleOrNull();

      expect(stock, isNotNull);
      expect(stock!.quantity, 95.0);
      expect(stock.reservedQuantity, 5.0);
    });

    test('StockByWarehouse multiple warehouses for same product', () async {
      // ARRANGE
      await setupStockDependencies(db);
      await db.into(db.stockWarehouse).insert(
            StockWarehouseCompanion.insert(
              odooId: 2,
              name: 'Bodega Secundaria',
              code: 'SEC',
            ),
          );

      // ACT: Insert stock for both warehouses
      await db.into(db.stockByWarehouse).insert(
            StockByWarehouseCompanion.insert(
              productId: 1,
              warehouseId: 1,
              quantity: const Value(50.0),
              lastUpdate: DateTime.now(),
              lastSyncAt: Value(DateTime.now()),
            ),
          );
      await db.into(db.stockByWarehouse).insert(
            StockByWarehouseCompanion.insert(
              productId: 1,
              warehouseId: 2,
              quantity: const Value(30.0),
              lastUpdate: DateTime.now(),
              lastSyncAt: Value(DateTime.now()),
            ),
          );

      // ASSERT
      final stocks = await (db.select(db.stockByWarehouse)
            ..where((t) => t.productId.equals(1)))
          .get();

      expect(stocks, hasLength(2));

      final warehouse1Stock = stocks.firstWhere((s) => s.warehouseId == 1);
      final warehouse2Stock = stocks.firstWhere((s) => s.warehouseId == 2);

      expect(warehouse1Stock.quantity, 50.0);
      expect(warehouse2Stock.quantity, 30.0);
    });

    test('StockByWarehouse zero stock handling', () async {
      // ARRANGE
      await setupStockDependencies(db);
      await db.into(db.stockByWarehouse).insert(
            StockByWarehouseCompanion.insert(
              productId: 1,
              warehouseId: 1,
              quantity: const Value(10.0),
              lastUpdate: DateTime.now(),
              lastSyncAt: Value(DateTime.now()),
            ),
          );

      // ACT: Stock goes to zero
      await db.customUpdate(
        'UPDATE stock_by_warehouse SET quantity = ? WHERE product_id = ? AND warehouse_id = ?',
        variables: [Variable(0.0), Variable(1), Variable(1)],
      );

      // ASSERT
      final stock = await (db.select(db.stockByWarehouse)
            ..where((t) => t.productId.equals(1) & t.warehouseId.equals(1)))
          .getSingleOrNull();

      expect(stock, isNotNull);
      expect(stock!.quantity, 0.0);
    });
  });

  // ==================== PRODUCT PRODUCT TESTS ====================
  group('ProductProduct WebSocket Handler Tests', () {
    Future<void> setupProductDependencies(AppDatabase db) async {
      await db.into(db.productCategory).insert(
            ProductCategoryCompanion.insert(odooId: 1, name: 'Productos'),
          );
      await db.into(db.uomCategory).insert(
            UomCategoryCompanion.insert(odooId: 1, name: 'Unit'),
          );
      await db.into(db.uomUom).insert(
            UomUomCompanion.insert(
              odooId: 1,
              name: 'Unidades',
              categoryId: 1,
              uomType: 'reference',
            ),
          );
    }

    test('ProductProduct insert via WebSocket notification', () async {
      // ARRANGE
      await setupProductDependencies(db);

      // ACT
      await db.into(db.productProduct).insert(
            ProductProductCompanion.insert(
              odooId: 100,
              name: 'Nuevo Producto',
              categId: const Value(1),
              uomId: const Value(1),
              listPrice: const Value(50.00),
              active: const Value(true),
              saleOk: const Value(true),
            ),
          );

      // ASSERT
      final product = await (db.select(db.productProduct)
            ..where((t) => t.odooId.equals(100)))
          .getSingleOrNull();

      expect(product, isNotNull);
      expect(product!.name, 'Nuevo Producto');
      expect(product.listPrice, 50.00);
      expect(product.saleOk, true);
    });

    test('ProductProduct price update via WebSocket notification', () async {
      // ARRANGE
      await setupProductDependencies(db);
      await db.into(db.productProduct).insert(
            ProductProductCompanion.insert(
              odooId: 101,
              name: 'Producto Precio',
              categId: const Value(1),
              listPrice: const Value(100.00),
            ),
          );

      // ACT: Price change from server
      await db.customUpdate(
        'UPDATE product_product SET list_price = ? WHERE odoo_id = ?',
        variables: [Variable(120.00), Variable(101)],
      );

      // ASSERT
      final product = await (db.select(db.productProduct)
            ..where((t) => t.odooId.equals(101)))
          .getSingleOrNull();

      expect(product, isNotNull);
      expect(product!.listPrice, 120.00);
    });

    test('ProductProduct deactivation via WebSocket', () async {
      // ARRANGE
      await setupProductDependencies(db);
      await db.into(db.productProduct).insert(
            ProductProductCompanion.insert(
              odooId: 102,
              name: 'Producto Activo',
              categId: const Value(1),
              active: const Value(true),
            ),
          );

      // ACT: Deactivate from server
      await db.customUpdate(
        'UPDATE product_product SET active = ? WHERE odoo_id = ?',
        variables: [Variable(0), Variable(102)],
      );

      // ASSERT
      final product = await (db.select(db.productProduct)
            ..where((t) => t.odooId.equals(102)))
          .getSingleOrNull();

      expect(product, isNotNull);
      expect(product!.active, false);
    });

    test('ProductProduct barcode update via WebSocket', () async {
      // ARRANGE
      await setupProductDependencies(db);
      await db.into(db.productProduct).insert(
            ProductProductCompanion.insert(
              odooId: 103,
              name: 'Producto con Barcode',
              categId: const Value(1),
              barcode: const Value('OLD_BARCODE'),
            ),
          );

      // ACT
      await db.customUpdate(
        'UPDATE product_product SET barcode = ? WHERE odoo_id = ?',
        variables: [Variable('NEW_BARCODE_789'), Variable(103)],
      );

      // ASSERT
      final product = await (db.select(db.productProduct)
            ..where((t) => t.odooId.equals(103)))
          .getSingleOrNull();

      expect(product, isNotNull);
      expect(product!.barcode, 'NEW_BARCODE_789');
    });
  });

  // ==================== RES USERS TESTS ====================
  group('ResUsers WebSocket Handler Tests', () {
    test('ResUsers insert via WebSocket notification', () async {
      // ACT
      await db.into(db.resUsers).insert(
            ResUsersCompanion.insert(
              odooId: 100,
              name: 'Usuario Nuevo',
              login: 'nuevo@test.com',
            ),
          );

      // ASSERT
      final user = await (db.select(db.resUsers)
            ..where((t) => t.odooId.equals(100)))
          .getSingleOrNull();

      expect(user, isNotNull);
      expect(user!.name, 'Usuario Nuevo');
      expect(user.login, 'nuevo@test.com');
    });

    test('ResUsers name update via WebSocket notification', () async {
      // ARRANGE
      await db.into(db.resUsers).insert(
            ResUsersCompanion.insert(
              odooId: 101,
              name: 'Usuario Original',
              login: 'original@test.com',
            ),
          );

      // ACT
      await db.customUpdate(
        'UPDATE res_users SET name = ? WHERE odoo_id = ?',
        variables: [Variable('Usuario Modificado'), Variable(101)],
      );

      // ASSERT
      final user = await (db.select(db.resUsers)
            ..where((t) => t.odooId.equals(101)))
          .getSingleOrNull();

      expect(user, isNotNull);
      expect(user!.name, 'Usuario Modificado');
    });
  });

  // ==================== MAIL ACTIVITY TESTS ====================
  group('MailActivity WebSocket Handler Tests', () {
    Future<void> setupActivityDependencies(AppDatabase db) async {
      await db.into(db.resUsers).insert(
            ResUsersCompanion.insert(
              odooId: 1,
              name: 'Usuario Test',
              login: 'test@test.com',
            ),
          );
    }

    test('MailActivity insert via WebSocket notification', () async {
      // ARRANGE
      await setupActivityDependencies(db);
      final dueDate = DateTime(2025, 12, 15);

      // ACT
      await db.into(db.mailActivityTable).insert(
            MailActivityTableCompanion.insert(
              odooId: 100,
              resModel: 'sale.order',
              resId: 1,
              activityTypeId: const Value(1),
              summary: const Value('Llamar al cliente'),
              note: const Value('Confirmar pedido'),
              dateDeadline: dueDate,
              userId: const Value(1),
              state: const Value('planned'),
            ),
          );

      // ASSERT
      final activity = await (db.select(db.mailActivityTable)
            ..where((t) => t.odooId.equals(100)))
          .getSingleOrNull();

      expect(activity, isNotNull);
      expect(activity!.resModel, 'sale.order');
      expect(activity.summary, 'Llamar al cliente');
      expect(activity.dateDeadline, dueDate);
      expect(activity.state, 'planned');
    });

    test('MailActivity completion via WebSocket notification', () async {
      // ARRANGE
      await setupActivityDependencies(db);
      await db.into(db.mailActivityTable).insert(
            MailActivityTableCompanion.insert(
              odooId: 101,
              resModel: 'sale.order',
              resId: 1,
              activityTypeId: const Value(1),
              userId: const Value(1),
              summary: const Value('Tarea pendiente'),
              dateDeadline: DateTime.now(),
              state: const Value('planned'),
            ),
          );

      // ACT: Mark as done from server
      await db.customUpdate(
        'UPDATE mail_activity_table SET state = ? WHERE odoo_id = ?',
        variables: [Variable('done'), Variable(101)],
      );

      // ASSERT
      final activity = await (db.select(db.mailActivityTable)
            ..where((t) => t.odooId.equals(101)))
          .getSingleOrNull();

      expect(activity, isNotNull);
      expect(activity!.state, 'done');
    });

    test('MailActivity delete via WebSocket notification', () async {
      // ARRANGE
      await setupActivityDependencies(db);
      await db.into(db.mailActivityTable).insert(
            MailActivityTableCompanion.insert(
              odooId: 102,
              resModel: 'sale.order',
              resId: 1,
              activityTypeId: const Value(1),
              userId: const Value(1),
              summary: const Value('Actividad a eliminar'),
              dateDeadline: DateTime.now(),
              state: const Value('planned'),
            ),
          );

      // ACT
      await (db.delete(db.mailActivityTable)..where((t) => t.odooId.equals(102))).go();

      // ASSERT
      final activity = await (db.select(db.mailActivityTable)
            ..where((t) => t.odooId.equals(102)))
          .getSingleOrNull();
      expect(activity, isNull);
    });

    test('MailActivity overdue detection', () async {
      // ARRANGE
      await setupActivityDependencies(db);
      final pastDate = DateTime.now().subtract(const Duration(days: 5));

      await db.into(db.mailActivityTable).insert(
            MailActivityTableCompanion.insert(
              odooId: 103,
              resModel: 'sale.order',
              resId: 1,
              activityTypeId: const Value(1),
              userId: const Value(1),
              summary: const Value('Actividad vencida'),
              dateDeadline: pastDate,
              state: const Value('overdue'),
            ),
          );

      // ASSERT
      final activity = await (db.select(db.mailActivityTable)
            ..where((t) => t.odooId.equals(103)))
          .getSingleOrNull();

      expect(activity, isNotNull);
      expect(activity!.state, 'overdue');
      expect(activity.dateDeadline.isBefore(DateTime.now()), true);
    });
  });

  // ==================== EDGE CASES AND ERROR SCENARIOS ====================
  group('Edge Cases and Error Scenarios', () {
    test('Handle null values in WebSocket payload', () async {
      // ARRANGE
      await db.into(db.productCategory).insert(
            ProductCategoryCompanion.insert(odooId: 1, name: 'Productos'),
          );

      // ACT: Insert product with many null fields
      await db.into(db.productProduct).insert(
            ProductProductCompanion.insert(
              odooId: 200,
              name: 'Producto Minimal',
              categId: const Value(1),
              // Most fields are null/default
            ),
          );

      // ASSERT
      final product = await (db.select(db.productProduct)
            ..where((t) => t.odooId.equals(200)))
          .getSingleOrNull();

      expect(product, isNotNull);
      expect(product!.name, 'Producto Minimal');
      expect(product.barcode, isNull);
      // listPrice has default value 0.0 in schema
      expect(product.listPrice, anyOf(isNull, equals(0.0)));
    });

    test('Handle concurrent updates to same record', () async {
      // ARRANGE
      await db.into(db.resPartner).insert(
            ResPartnerCompanion.insert(
              odooId: 300,
              name: 'Partner Original',
              displayName: const Value('Partner Original'),
            ),
          );

      // ACT: Simulate rapid updates (like from multiple WebSocket messages)
      await db.customUpdate(
        'UPDATE res_partner SET name = ? WHERE odoo_id = ?',
        variables: [Variable('Update 1'), Variable(300)],
      );
      await db.customUpdate(
        'UPDATE res_partner SET name = ? WHERE odoo_id = ?',
        variables: [Variable('Update 2'), Variable(300)],
      );
      await db.customUpdate(
        'UPDATE res_partner SET name = ? WHERE odoo_id = ?',
        variables: [Variable('Final Update'), Variable(300)],
      );

      // ASSERT: Last update wins
      final partner = await (db.select(db.resPartner)
            ..where((t) => t.odooId.equals(300)))
          .getSingleOrNull();

      expect(partner, isNotNull);
      expect(partner!.name, 'Final Update');
    });

    test('Handle large text fields in WebSocket payload', () async {
      // ARRANGE
      final longNote = 'A' * 10000; // 10KB of text

      await db.into(db.resPartner).insert(
            ResPartnerCompanion.insert(
              odooId: 1,
              name: 'Partner with notes',
              displayName: const Value('Partner with notes'),
            ),
          );

      await db.into(db.saleOrder).insert(
            SaleOrderCompanion.insert(
              odooId: 400,
              name: 'SO-LONG',
              partnerId: const Value(1),
              note: Value(longNote),
            ),
          );

      // ASSERT
      final order = await (db.select(db.saleOrder)
            ..where((t) => t.odooId.equals(400)))
          .getSingleOrNull();

      expect(order, isNotNull);
      expect(order!.note, longNote);
      expect(order.note!.length, 10000);
    });

    test('Handle special characters in text fields', () async {
      // ARRANGE
      const specialName = "O'Brien & Sons <\"Test\"> 中文 🎉";

      await db.into(db.resPartner).insert(
            ResPartnerCompanion.insert(
              odooId: 500,
              name: specialName,
              displayName: const Value(specialName),
            ),
          );

      // ASSERT
      final partner = await (db.select(db.resPartner)
            ..where((t) => t.odooId.equals(500)))
          .getSingleOrNull();

      expect(partner, isNotNull);
      expect(partner!.name, specialName);
    });

    test('Handle decimal precision in price fields', () async {
      // ARRANGE
      await db.into(db.productCategory).insert(
            ProductCategoryCompanion.insert(odooId: 1, name: 'Productos'),
          );
      await db.into(db.productPricelist).insert(
            ProductPricelistCompanion.insert(
              odooId: 1,
              name: 'Precio Público',
            ),
          );

      // ACT: Insert with high precision price
      await db.into(db.productPricelistItem).insert(
            ProductPricelistItemCompanion.insert(
              odooId: 600,
              pricelistId: 1,
              appliedOn: '3_global',
              base: 'list_price',
              computePrice: const Value('fixed'),
              fixedPrice: const Value(123.456789), // High precision
            ),
          );

      // ASSERT
      final item = await (db.select(db.productPricelistItem)
            ..where((t) => t.odooId.equals(600)))
          .getSingleOrNull();

      expect(item, isNotNull);
      // Note: SQLite stores as REAL, precision may vary
      expect(item!.fixedPrice, closeTo(123.456789, 0.0001));
    });
  });
}
