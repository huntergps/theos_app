import 'package:drift/drift.dart';

import 'package:theos_pos_core/theos_pos_core.dart';
import '../../../core/services/handlers/model_record_handler.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

/// Handler for res.users records
class UserRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'res.users';

  @override
  List<String> get defaultFields => [
    'id',
    'name',
    'login',
    'email',
    'lang',
    'tz',
    'signature',
    'partner_id',
    'company_id',
    'notification_type',
    'write_date',
  ];

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    final result = await (db.select(db.resUsers)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'] as int;

    final existing = await (db.select(db.resUsers)
          ..where((t) => t.odooId.equals(id)))
        .getSingleOrNull();

    final companion = ResUsersCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      login: Value(data['login'] as String? ?? ''),
      email: Value(data['email'] is String ? data['email'] : null),
      lang: Value(data['lang'] is String ? data['lang'] : null),
      tz: Value(data['tz'] is String ? data['tz'] : null),
      signature: Value(data['signature'] is String ? data['signature'] : null),
      partnerId: Value(odoo.extractMany2oneId(data['partner_id'])),
      partnerName: Value(odoo.extractMany2oneName(data['partner_id'])),
      companyId: Value(odoo.extractMany2oneId(data['company_id'])),
      companyName: Value(odoo.extractMany2oneName(data['company_id'])),
      notificationType: Value(
        data['notification_type'] is String ? data['notification_type'] : null,
      ),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );

    if (existing != null) {
      await (db.update(db.resUsers)..where((t) => t.odooId.equals(id)))
          .write(companion);
    } else {
      await db.into(db.resUsers).insert(companion);
    }
  }
}
