import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  test('reads real local summary fields and observes SQLite changes', () async {
    final file = File(
      '${Directory.systemTemp.path}/runtime-order-reader-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    final owner = RuntimeDatabaseOwner(
      factory: (_) => AppDatabase(NativeDatabase(file)),
    );
    final sessions = SessionRuntime(databaseOwner: owner);
    addTearDown(() async {
      await sessions.close();
      if (file.existsSync()) await file.delete();
    });
    final activation = await sessions.activate(
      AppScope(
        appId: 'test',
        installationId: 'installation',
        normalizedServerUrl: 'https://example.test',
        database: 'db',
        userId: 1,
      ),
    );
    final db = activation.database.database;
    await db
        .into(db.saleOrder)
        .insert(
          SaleOrderCompanion.insert(
            odooId: 10,
            name: 'SO10',
            companyId: const Value(1),
            userId: const Value(7),
            partnerName: const Value('Cliente real'),
            amountTotal: const Value(42.5),
            dateOrder: Value(DateTime.utc(2026, 1, 2)),
            currencyId: const Value(2),
            currencySymbol: const Value('€'),
          ),
        );
    final reader = RuntimeLocalOrderReader(sessions);
    final query = OrderQuery(companyId: 1);
    final first = await reader.read(query);
    expect(first.rows.single['partner_name'], 'Cliente real');
    expect(first.rows.single['amount_total'], 42.5);
    expect(first.rows.single['currency_id'], 2);
    expect(first.rows.single['currency_symbol'], '€');

    final events = StreamIterator(reader.watch(query));
    expect(await events.moveNext(), isTrue);
    await (db.update(db.saleOrder)..where((row) => row.odooId.equals(10)))
        .write(const SaleOrderCompanion(amountTotal: Value(50.0)));
    expect(await events.moveNext(), isTrue);
    expect(events.current.rows.single['amount_total'], 50.0);
    await events.cancel();
  });
}
