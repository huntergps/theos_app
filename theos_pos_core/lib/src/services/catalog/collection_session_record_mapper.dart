import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

abstract final class CollectionSessionRecordMapper {
  static const fields = <String>[
    'id',
    'session_uuid',
    'name',
    'state',
    'config_id',
    'company_id',
    'user_id',
    'currency_id',
    'currency_symbol',
    'cash_journal_id',
    'start_at',
    'stop_at',
    'cash_register_balance_start',
    'cash_register_balance_end_real',
    'cash_register_balance_end',
    'cash_register_difference',
    'total_payments_amount',
    'write_date',
  ];
  static Future<void> upsert(AppDatabase db, Map<String, dynamic> d) async {
    final id = d['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('collection.session id');
    }
    final start = odoo.parseOdooDateTime(d['start_at']);
    final uuid = d['session_uuid'];
    if (start == null || uuid is! String || uuid.trim().isEmpty) {
      throw const FormatException(
        'collection.session requires start_at/session_uuid',
      );
    }
    final c = CollectionSessionCompanion(
      odooId: Value(id),
      sessionUuid: Value(uuid),
      // 🔴 Mismo patrón que en `PartnerRecordMapper`: `as String?` no filtra
      // el `false` que Odoo manda para un texto vacío.
      name: Value(odoo.toStringOrNull(d['name']) ?? ''),
      state: Value(odoo.toStringOrNull(d['state']) ?? 'opening_control'),
      configId: Value(odoo.extractMany2oneId(d['config_id']) ?? 0),
      configName: Value(odoo.extractMany2oneName(d['config_id'])),
      companyId: Value(odoo.extractMany2oneId(d['company_id']) ?? 0),
      companyName: Value(odoo.extractMany2oneName(d['company_id'])),
      userId: Value(odoo.extractMany2oneId(d['user_id']) ?? 0),
      userName: Value(odoo.extractMany2oneName(d['user_id'])),
      currencyId: Value(odoo.extractMany2oneId(d['currency_id']) ?? 0),
      currencySymbol: Value(odoo.toStringOrNull(d['currency_symbol'])),
      cashJournalId: Value(odoo.extractMany2oneId(d['cash_journal_id'])),
      cashJournalName: Value(odoo.extractMany2oneName(d['cash_journal_id'])),
      startAt: Value(start),
      stopAt: Value(odoo.parseOdooDateTime(d['stop_at'])),
      cashRegisterBalanceStart: Value(
        (d['cash_register_balance_start'] as num?)?.toDouble() ?? 0,
      ),
      cashRegisterBalanceEndReal: Value(
        (d['cash_register_balance_end_real'] as num?)?.toDouble() ?? 0,
      ),
      cashRegisterBalanceEnd: Value(
        (d['cash_register_balance_end'] as num?)?.toDouble() ?? 0,
      ),
      cashRegisterDifference: Value(
        (d['cash_register_difference'] as num?)?.toDouble() ?? 0,
      ),
      totalPaymentsAmount: Value(
        (d['total_payments_amount'] as num?)?.toDouble() ?? 0,
      ),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    final old = await (db.select(
      db.collectionSession,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();
    if (old == null) {
      await db.into(db.collectionSession).insert(c);
    } else {
      await (db.update(
        db.collectionSession,
      )..where((t) => t.odooId.equals(id))).write(c);
    }
  }
}
