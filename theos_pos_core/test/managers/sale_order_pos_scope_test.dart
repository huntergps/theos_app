import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  late AppDatabase database;
  late SaleOrderManager manager;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    manager = SaleOrderManager()..initDb(database);
  });

  tearDown(() => database.close());

  Future<void> insertOrder(
    int id, {
    required int userId,
    required int companyId,
    int? sessionId,
    String state = 'sale',
    String invoiceStatus = 'to invoice',
  }) {
    return database
        .into(database.saleOrder)
        .insert(
          SaleOrderCompanion.insert(
            odooId: id,
            name: 'SO$id',
            userId: Value(userId),
            companyId: Value(companyId),
            collectionSessionId: Value(sessionId),
            state: Value(state),
            invoiceStatus: Value(invoiceStatus),
          ),
        );
  }

  test(
    'cashier scope cannot leak company, session, state, or invoice status',
    () async {
      await insertOrder(1, userId: 43, companyId: 2, sessionId: 18);
      await insertOrder(2, userId: 44, companyId: 2);
      await insertOrder(3, userId: 43, companyId: 3, sessionId: 18);
      await insertOrder(4, userId: 43, companyId: 2, sessionId: 99);
      await insertOrder(
        5,
        userId: 43,
        companyId: 2,
        sessionId: 18,
        state: 'draft',
      );
      await insertOrder(
        6,
        userId: 43,
        companyId: 2,
        sessionId: 18,
        invoiceStatus: 'invoiced',
      );

      final orders = await manager.getSaleOrdersForPOS(
        companyIds: const [2],
        collectionSessionIds: const [18],
        states: const ['sale'],
        invoiceStatuses: const ['to invoice'],
      );

      expect(orders.map((order) => order.id), containsAll(<int>[1, 2]));
      expect(orders, hasLength(2));
      expect(
        await manager.countSaleOrdersForPOS(
          companyIds: const [2],
          collectionSessionIds: const [18],
          states: const ['sale'],
          invoiceStatuses: const ['to invoice'],
        ),
        2,
      );
      final searchResults = await manager.getEditableOrdersForPOS(
        companyIds: const [2],
        collectionSessionIds: const [18],
        states: const ['sale'],
        invoiceStatuses: const ['to invoice'],
        allUsers: true,
      );
      expect(
        searchResults.map((order) => order['id']),
        containsAll(<int>[1, 2]),
      );
      expect(searchResults, hasLength(2));
    },
  );

  test('seller mine scope preserves salesperson while all removes only that filter', () async {
    await insertOrder(1, userId: 43, companyId: 2);
    await insertOrder(2, userId: 44, companyId: 2);

    final mine = await manager.getSaleOrdersForPOS(userId: 43);
    final all = await manager.getSaleOrdersForPOS();

    expect(mine.map((order) => order.id), [1]);
    expect(all.map((order) => order.id), containsAll(<int>[1, 2]));
  });

  test('empty authorized company scope fails closed', () async {
    await insertOrder(1, userId: 43, companyId: 2);

    expect(await manager.getSaleOrdersForPOS(companyIds: const []), isEmpty);
    expect(await manager.countSaleOrdersForPOS(companyIds: const []), 0);
  });
}
