import 'package:drift/native.dart';
import 'package:test/test.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

void main() {
  test(
    'payment configuration JSON records upsert into existing tables',
    () async {
      final db = AppDatabase(NativeDatabase.memory());
      addTearDown(db.close);

      await PaymentConfigRecordMapper.upsertCardBrand(db, {
        'id': 1,
        'name': 'Visa',
        'code': 'visa',
      });
      // El plazo va en MESES. `deadline_days` y `percentage` no existen en
      // Odoo, y esta prueba los daba por buenos mientras el catálogo real
      // fallaba entero contra el servidor.
      await PaymentConfigRecordMapper.upsertCardDeadline(db, {
        'id': 2,
        'name': '3 meses',
        'meses': 3,
        'type': 'deferred',
        'interes': true,
      });
      await PaymentConfigRecordMapper.upsertCardLote(db, {
        'id': 3,
        'name': 'Lote 1',
        'journal_id': [4, 'Banco'],
        'state': 'open',
        'amount_total': 12.5,
        'amount_balance': 12.5,
        'payment_count': 1,
        'is_pos_lote': true,
      });
      await PaymentConfigRecordMapper.upsertPaymentMethodLine(db, {
        'id': 5,
        'name': 'Tarjeta',
        'code': 'card_credit_in',
        'journal_id': [4, 'Banco'],
        'payment_method_id': [6, 'Electrónico'],
        'payment_type': 'inbound',
      });

      expect(
        (await PaymentConfigRecordMapper.readCardBrands(db)).single['name'],
        'Visa',
      );
      final plazo = (await PaymentConfigRecordMapper.readCardDeadlines(
        db,
      )).single;
      expect(plazo['meses'], 3);
      expect(plazo['type'], 'deferred');
      expect(plazo['interes'], isTrue);
      expect(
        (await PaymentConfigRecordMapper.readCardLotes(db))
            .single['journal_id'],
        4,
      );
      expect(
        (await PaymentConfigRecordMapper.readPaymentMethodLines(db))
            .single['payment_method_id'],
        6,
      );
    },
  );
}
