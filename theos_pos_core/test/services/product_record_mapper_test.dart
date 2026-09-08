import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  test('product mapper upserts and preserves one row', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final row = <String, dynamic>{
      'id': 7,
      'name': 'Producto',
      'list_price': 4.5,
    };
    await ProductRecordMapper.upsert(db, row);
    await ProductRecordMapper.upsert(db, {...row, 'name': 'Actualizado'});
    final rows = await (db.select(
      db.productProduct,
    )..where((t) => t.odooId.equals(7))).get();
    expect(rows, hasLength(1));
    expect(rows.single.name, 'Actualizado');
  });

  test('warehouse and pricelist mappers upsert existing rows', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await WarehouseRecordMapper.upsert(db, {'id': 2, 'name': 'Central'});
    await WarehouseRecordMapper.upsert(db, {'id': 2, 'name': 'Norte'});
    await PricelistRecordMapper.upsert(db, {'id': 3, 'name': 'Retail'});
    await PricelistRecordMapper.upsert(db, {'id': 3, 'name': 'Retail 2'});
    expect(
      (await (db.select(
        db.stockWarehouse,
      )..where((t) => t.odooId.equals(2))).get()).single.name,
      'Norte',
    );
    expect(
      (await (db.select(
        db.productPricelist,
      )..where((t) => t.odooId.equals(3))).get()).single.name,
      'Retail 2',
    );
  });

  test('partner mapper upserts and reads after restart boundary', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    await PartnerRecordMapper.upsert(db, {
      'id': 8,
      'name': 'Cliente',
      'vat': '999',
    });
    await PartnerRecordMapper.upsert(db, {
      'id': 8,
      'name': 'Cliente 2',
      'vat': '999',
    });
    final rows = await PartnerRecordMapper.read(db);
    expect(rows.single['name'], 'Cliente 2');
  });
}
