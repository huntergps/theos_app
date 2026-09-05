import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/src/database/database.dart';
import 'package:theos_pos_core/src/managers/sales/sale_order_line_manager.dart';
import 'package:theos_pos_core/src/models/sales/sale_order_line.model.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late SaleOrderLineManager manager;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    manager = SaleOrderLineManager()..initDb(database);
  });

  tearDown(() => database.close());

  test(
    'editable sales fields survive the offline-first local update',
    () async {
      await manager.upsertLocal(
        const SaleOrderLine(
          id: 10,
          orderId: 20,
          productId: 1,
          name: 'Original',
          isSynced: true,
        ),
      );

      await manager.updateSaleOrderLineValues(10, {
        'sequence': 30,
        'display_type': 'line_section',
        'product_id': false,
        'name': 'Servicios',
        'product_uom_qty': 2,
        'product_uom_id': [5, 'Horas'],
        'price_unit': 15,
        'discount': 10,
        'tax_ids': [
          [
            6,
            0,
            [2, 7],
          ],
        ],
        'price_subtotal': 27,
        'price_tax': 4.05,
        'price_total': 31.05,
        'collapse_prices': true,
        'collapse_composition': true,
        'is_optional': true,
      });

      final updated = await manager.readLocal(10);
      expect(updated, isNotNull);
      expect(updated!.sequence, 30);
      expect(updated.displayType, LineDisplayType.lineSection);
      expect(updated.productId, isNull);
      expect(updated.name, 'Servicios');
      expect(updated.productUomQty, 2);
      expect(updated.productUomId, 5);
      expect(updated.priceUnit, 15);
      expect(updated.discount, 10);
      expect(updated.taxIds, '2,7');
      expect(updated.priceSubtotal, 27);
      expect(updated.priceTax, 4.05);
      expect(updated.priceTotal, 31.05);
      expect(updated.collapsePrices, isTrue);
      expect(updated.collapseComposition, isTrue);
      expect(updated.isOptional, isTrue);
      expect(updated.isSynced, isFalse);
    },
  );
}
