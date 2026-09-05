import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase database;
  late SaleOrderManager manager;
  final start = DateTime(2026, 8, 26);
  final end = DateTime(2026, 8, 27);

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    manager = SaleOrderManager()..initDb(database);
  });

  tearDown(() => database.close());

  Future<void> insertOrder(
    int id,
    String state,
    DateTime date, {
    double amount = 0,
  }) {
    return database
        .into(database.saleOrder)
        .insert(
          SaleOrderCompanion.insert(
            odooId: id,
            name: 'SO$id',
            state: Value(state),
            dateOrder: Value(date),
            amountTotal: Value(amount),
          ),
        );
  }

  test('aggregates only the requested period and sale/done amounts', () async {
    await insertOrder(1, 'draft', start, amount: 10);
    await insertOrder(2, 'sent', start.add(const Duration(hours: 1)));
    await insertOrder(
      3,
      'sale',
      start.add(const Duration(hours: 2)),
      amount: 125.50,
    );
    await insertOrder(
      4,
      'done',
      start.add(const Duration(hours: 3)),
      amount: 25,
    );
    await insertOrder(5, 'cancel', start.add(const Duration(hours: 4)));
    await insertOrder(6, 'sale', start.subtract(const Duration(seconds: 1)));
    await insertOrder(7, 'sale', end, amount: 999);

    final metrics = await manager
        .watchPeriodMetrics(startInclusive: start, endExclusive: end)
        .first;

    expect(metrics.totalOrders, 5);
    expect(metrics.totalAmount, 150.50);
    expect(metrics.draftCount, 2);
    expect(metrics.confirmedCount, 1);
    expect(metrics.doneCount, 1);
    expect(metrics.cancelledCount, 1);
  });

  test('reacts to local database changes without loading model rows', () async {
    final stream = manager.watchPeriodMetrics(
      startInclusive: start,
      endExclusive: end,
    );

    final nextMetrics = stream.firstWhere(
      (metrics) => metrics.totalOrders == 1,
    );
    await insertOrder(1, 'sale', start, amount: 42);

    final metrics = await nextMetrics;
    expect(metrics.confirmedCount, 1);
    expect(metrics.totalAmount, 42);
  });

  test('rejects an empty or inverted interval', () {
    expect(
      manager.watchPeriodMetrics(startInclusive: start, endExclusive: start),
      emitsError(isA<ArgumentError>()),
    );
  });
}
