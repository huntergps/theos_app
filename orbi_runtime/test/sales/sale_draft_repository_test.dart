import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:orbi_runtime/src/sales/sale_draft_repository.dart';

void main() {
  test('persists local order, lines and replay dependencies atomically', () async {
    final file = File(
      '${Directory.systemTemp.path}/sale-draft-${DateTime.now().microsecondsSinceEpoch}.db',
    );
    var db = AppDatabase(NativeDatabase(file));
    addTearDown(() async {
      await db.close();
      if (file.existsSync()) await file.delete();
    });
    var repository = DriftSaleDraftRepository(db);
    final product = SaleCatalogProduct.fromMap({
      'localId': 'product-local',
      'id': 42,
      'name': 'Producto',
      'price': 12.5,
      'uomId': 1,
      'taxIds': [5],
    });

    final orderId = await repository.save(
      SaleDraftRecord(
        commandId: 'cmd-physical',
        name: 'offline-cmd-physical',
        lines: [
          SaleDraftLineRecord(
            lineUuid: 'line-1',
            product: product,
            quantity: 2,
          ),
        ],
      ),
    );
    expect(await (db.select(db.saleOrder)).get(), hasLength(1));
    expect(await (db.select(db.saleOrderLine)).get(), hasLength(1));
    final queue = await (db.select(db.offlineQueue)).get();
    expect(queue, hasLength(2));
    expect(
      queue.map((row) => row.operationKey),
      contains('cmd-physical:create'),
    );

    await db.close();
    db = AppDatabase(NativeDatabase(file));
    repository = DriftSaleDraftRepository(db);
    expect(await db.select(db.saleOrder).get(), hasLength(1));
    expect(await db.select(db.saleOrderLine).get(), hasLength(1));
    expect(await db.select(db.offlineQueue).get(), hasLength(2));

    expect(
      await repository.save(
        SaleDraftRecord(
          commandId: 'cmd-physical',
          name: 'ignored-retry',
          lines: [
            SaleDraftLineRecord(
              lineUuid: 'line-1',
              product: product,
              quantity: 2,
            ),
          ],
        ),
      ),
      orderId,
    );
    expect(await (db.select(db.saleOrder)).get(), hasLength(1));
  });
}
