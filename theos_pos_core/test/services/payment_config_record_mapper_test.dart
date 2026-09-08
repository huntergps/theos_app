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
      await PaymentConfigRecordMapper.upsertCardDeadline(db, {
        'id': 2,
        'name': '30 días',
        'deadline_days': 30,
        'percentage': 2.5,
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
      expect(
        (await PaymentConfigRecordMapper.readCardDeadlines(db))
            .single['deadline_days'],
        30,
      );
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
