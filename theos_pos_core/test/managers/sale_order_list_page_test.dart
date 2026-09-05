import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late SaleOrderManager manager;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    manager = SaleOrderManager()..initDb(database);
  });

  tearDown(() => database.close());

  Future<void> insertOrder({
    required int id,
    required String state,
    required int userId,
    bool synced = true,
  }) {
    return database
        .into(database.saleOrder)
        .insert(
          SaleOrderCompanion.insert(
            odooId: id,
            name: 'SO${id.toString().padLeft(4, '0')}',
            state: Value(state),
            userId: Value(userId),
            partnerName: Value(id.isEven ? 'Acme' : 'Globex'),
            dateOrder: Value(DateTime(2026, 1, 1).add(Duration(minutes: id))),
            isSynced: Value(synced),
          ),
        );
  }

  test('returns a bounded SQL page with matching state facets', () async {
    for (var id = 1; id <= 205; id++) {
      await insertOrder(
        id: id,
        state: id % 3 == 0 ? 'sale' : 'draft',
        userId: id.isEven ? 7 : 9,
        synced: id != 1,
      );
    }

    final page = await manager
        .watchListPage(userId: 7, state: 'draft', pageIndex: 1, pageSize: 20)
        .first;

    expect(page.rows, hasLength(20));
    expect(page.rows.every((order) => order.userId == 7), isTrue);
    expect(
      page.rows.every((order) => order.state == SaleOrderState.draft),
      isTrue,
    );
    expect(page.totalCount, 68);
    expect(page.countsByState['all'], 102);
    expect(page.countsByState['draft'], 68);
    expect(page.countsByState['sale'], 34);
    expect(page.unsyncedCount, 1);
    expect(page.rows.first.id, 142);
  });

  test('search is case-insensitive and reacts to inserts', () async {
    final matchingPage = manager
        .watchListPage(searchQuery: 'acme', pageSize: 10)
        .firstWhere((page) => page.totalCount == 1);

    await insertOrder(id: 2, state: 'draft', userId: 7);

    final page = await matchingPage;
    expect(page.rows.single.partnerName, 'Acme');
    expect(page.countsByState['draft'], 1);
  });

  test('watches pending approval count with canonical Odoo state', () async {
    final onePending = manager
        .watchStateCount('waiting')
        .firstWhere((count) => count == 1);

    await insertOrder(id: 10, state: 'waiting', userId: 7);

    expect(await onePending, 1);
  });
}
