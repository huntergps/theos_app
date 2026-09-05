import 'package:drift/native.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:theos_pos/core/services/handlers/model_record_handler.dart';
import 'package:theos_pos/features/sync/repositories/sale_order_sync_repository.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../mocks/mock_odoo_client.dart';

void main() {
  late AppDatabase db;
  late MockOdooClient client;
  late SaleOrderSyncRepository repository;
  late List<Map<String, dynamic>> remoteLines;
  late List<Map<String, dynamic>> remoteWithholds;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    client = MockOdooClient.online();
    repository = SaleOrderSyncRepository(
      db: db,
      odooClient: client,
      recordHandlerRegistry: ModelRecordHandlerRegistry(),
    );
    remoteLines = [_line(1001), _line(1002)];
    remoteWithholds = [_withhold(2001), _withhold(2002)];

    when(
      () => client.searchRead(
        model: 'sale.order',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer((_) async => [_order()]);
    when(
      () => client.searchRead(
        model: 'sale.order.line',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer((_) async => remoteLines);
    when(
      () => client.searchRead(
        model: 'sale.order.withhold.line',
        domain: any(named: 'domain'),
        fields: any(named: 'fields'),
        limit: any(named: 'limit'),
        offset: any(named: 'offset'),
        order: any(named: 'order'),
      ),
    ).thenAnswer((_) async => remoteWithholds);
  });

  tearDown(() => db.close());

  test('repeated search upserts children and removes obsolete rows', () async {
    expect(await repository.searchSaleOrdersWithLines('SO100'), hasLength(1));
    expect(await db.select(db.saleOrderLine).get(), hasLength(2));
    expect(await db.select(db.saleOrderWithholdLine).get(), hasLength(2));

    await db
        .into(db.saleOrderLine)
        .insert(
          SaleOrderLineCompanion.insert(
            odooId: const Value(-1),
            lineUuid: const Value('pending-line'),
            orderId: 100,
            name: 'Línea pendiente',
            isSynced: const Value(false),
          ),
        );
    await db
        .into(db.saleOrderWithholdLine)
        .insert(
          SaleOrderWithholdLineCompanion.insert(
            odooId: const Value(-2),
            lineUuid: const Value('pending-withhold'),
            orderId: 100,
            taxId: 70,
            taxName: 'Retención pendiente',
            withholdType: 'withhold_vat_sale',
            isSynced: const Value(false),
          ),
        );

    remoteLines = [_line(1002, quantity: 5)];
    remoteWithholds = [_withhold(2002, amount: 9)];

    expect(await repository.searchSaleOrdersWithLines('SO100'), hasLength(1));

    final lines = await db.select(db.saleOrderLine).get();
    expect(lines, hasLength(2));
    final syncedLine = lines.singleWhere((line) => line.odooId == 1002);
    expect(syncedLine.productUomQty, 5);
    expect(lines.any((line) => line.odooId == -1 && !line.isSynced), isTrue);

    final withholds = await db.select(db.saleOrderWithholdLine).get();
    expect(withholds, hasLength(2));
    final syncedWithhold = withholds.singleWhere((line) => line.odooId == 2002);
    expect(syncedWithhold.amount, 9);
    expect(
      withholds.any((line) => line.odooId == -2 && !line.isSynced),
      isTrue,
    );
  });

  test(
    'catalog sync propagates child failures and cannot advance state',
    () async {
      when(
        () => client.searchCount(
          model: 'sale.order',
          domain: any(named: 'domain'),
        ),
      ).thenAnswer((_) async => 1);
      when(
        () => client.searchRead(
          model: 'sale.order.line',
          domain: any(named: 'domain'),
          fields: any(named: 'fields'),
          limit: any(named: 'limit'),
          offset: any(named: 'offset'),
          order: any(named: 'order'),
        ),
      ).thenThrow(StateError('line sync failed'));

      await expectLater(
        repository.syncSaleOrders(),
        throwsA(isA<StateError>()),
      );
    },
  );
}

Map<String, dynamic> _order() => {
  'id': 100,
  'name': 'SO100',
  'state': 'draft',
  'date_order': '2026-08-26 10:00:00',
  'partner_id': [10, 'Cliente'],
  'user_id': [2, 'Administrator'],
  'company_id': [1, 'Compañía'],
  'amount_untaxed': 20.0,
  'amount_tax': 3.0,
  'amount_total': 23.0,
  'order_line': [1001, 1002],
  'withhold_line_ids': [2001, 2002],
  'write_date': '2026-08-26 10:00:00',
};

Map<String, dynamic> _line(int id, {double quantity = 1}) => {
  'id': id,
  'order_id': [100, 'SO100'],
  'name': 'Producto $id',
  'sequence': 10,
  'product_id': [50, 'Producto'],
  'product_uom_qty': quantity,
  'product_uom_id': [1, 'Unidad'],
  'price_unit': 10.0,
  'price_subtotal': 10.0,
  'price_tax': 1.5,
  'price_total': 11.5,
  'tax_ids': <int>[1],
  'state': 'draft',
  'write_date': '2026-08-26 10:00:00',
};

Map<String, dynamic> _withhold(int id, {double amount = 3}) => {
  'id': id,
  'sale_id': [100, 'SO100'],
  'sequence': 10,
  'tax_id': [70, 'Ret. IVA 30%'],
  'base': 10.0,
  'amount': amount,
  'write_date': '2026-08-26 10:00:00',
};
