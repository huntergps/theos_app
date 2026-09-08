import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

abstract final class PaymentTermRecordMapper {
  static const fields = <String>[
    'id',
    'name',
    'active',
    'note',
    'company_id',
    'sequence',
    'write_date',
  ];
  static Future<bool> exists(AppDatabase db, int id) async =>
      (await (db.select(
        db.accountPaymentTerm,
      )..where((t) => t.odooId.equals(id))).getSingleOrNull()) !=
      null;
  static Future<void> upsert(AppDatabase db, Map<String, dynamic> d) async {
    final id = d['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('account.payment.term id');
    }
    final c = AccountPaymentTermCompanion(
      odooId: Value(id),
      name: Value(d['name'] as String? ?? ''),
      active: Value(d['active'] as bool? ?? true),
      note: Value(d['note'] is String? ? d['note'] : null),
      companyId: Value(odoo.extractMany2oneId(d['company_id'])),
      sequence: Value(d['sequence'] as int? ?? 10),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    if (await exists(db, id)) {
      await (db.update(
        db.accountPaymentTerm,
      )..where((t) => t.odooId.equals(id))).write(c);
    } else {
      await db.into(db.accountPaymentTerm).insert(c);
    }
  }
}
