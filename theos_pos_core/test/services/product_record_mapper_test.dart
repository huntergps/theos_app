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

  test(
    // 🔴 Regresión (12-sep-2026, medida contra ERP2): Odoo manda `false`, no
    // `null` ni `''`, en cualquier campo de texto vacío (Char/Text/
    // Selection). `TypeError: false: type 'bool' is not a subtype of type
    // 'String'` tumbaba la lectura entera de Clientes porque
    // `PartnerRecordMapper` leía `d['vat'] as String?` sin filtrar `false`.
    // El mismo patrón estaba en TODOS los demás mapeos de catálogo — esta
    // prueba lo cubre en todos, no sólo en el que se vio primero.
    'catalog mappers accept the false Odoo sends for empty text fields',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await PartnerRecordMapper.upsert(db, {
        'id': 20,
        'name': 'Cliente sin datos',
        'ref': false,
        'vat': false,
        'email': false,
        'phone': false,
        'street': false,
        'lang': false,
        'comment': false,
      });
      final partner = (await (db.select(
        db.resPartner,
      )..where((t) => t.odooId.equals(20))).get()).single;
      expect(partner.vat, isNull);
      expect(partner.email, isNull);

      await WarehouseRecordMapper.upsert(db, {
        'id': 30,
        'name': 'Bodega',
        'code': false,
      });
      await PricelistRecordMapper.upsert(db, {'id': 31, 'name': false});
      expect(
        (await (db.select(
          db.productPricelist,
        )..where((t) => t.odooId.equals(31))).get()).single.name,
        '',
      );

      await JournalRecordMapper.upsert(db, {
        'id': 32,
        'name': false,
        'code': false,
        'type': false,
      });
      final journal = (await (db.select(
        db.accountJournal,
      )..where((t) => t.odooId.equals(32))).get()).single;
      expect(journal.name, '');
      expect(journal.type, 'general');

      await TaxRecordMapper.upsert(db, {
        'id': 33,
        'name': false,
        'type_tax_use': false,
        'amount_type': false,
      });
      final tax = (await (db.select(
        db.accountTax,
      )..where((t) => t.odooId.equals(33))).get()).single;
      expect(tax.typeTaxUse, 'sale');

      await UomRecordMapper.upsert(db, {'id': 34, 'name': false});
      await PaymentTermRecordMapper.upsert(db, {'id': 35, 'name': false});

      await CollectionConfigRecordMapper.upsert(db, {
        'id': 36,
        'name': false,
        'code': false,
        'current_session_state': false,
        'current_session_name': false,
        'collection_session_username': false,
        'current_session_state_display': false,
      });

      await CollectionSessionRecordMapper.upsert(db, {
        'id': 37,
        'name': false,
        'state': false,
        'session_uuid': 'uuid-37',
        'start_at': '2026-09-12 12:00:00',
        'currency_symbol': false,
      });

      await PaymentConfigRecordMapper.upsertCardBrand(db, {
        'id': 38,
        'name': false,
        'code': false,
      });
      await PaymentConfigRecordMapper.upsertCardDeadline(db, {
        'id': 39,
        'name': false,
        'type': false,
      });
      await PaymentConfigRecordMapper.upsertCardLote(db, {
        'id': 40,
        'name': false,
        'journal_id': [4, 'Banco'],
        'state': false,
      });
      await PaymentConfigRecordMapper.upsertPaymentMethodLine(db, {
        'id': 41,
        'name': false,
        'journal_id': [4, 'Banco'],
        'payment_method_id': [6, 'Electrónico'],
        'payment_type': false,
      });
    },
  );
}
