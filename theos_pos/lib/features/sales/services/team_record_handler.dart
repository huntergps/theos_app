import 'package:drift/drift.dart';

import 'package:theos_pos_core/theos_pos_core.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;
import '../../../core/services/handlers/model_record_handler.dart';

/// Handler for crm.team records
class TeamRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'crm.team';

  @override
  List<String> get defaultFields => [
    'id',
    'name',
    'active',
    'company_id',
    'user_id',
    'sequence',
    'write_date',
  ];

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    final result = await (db.select(db.crmTeam)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'] as int;

    final existing = await (db.select(db.crmTeam)
          ..where((t) => t.odooId.equals(id)))
        .getSingleOrNull();

    final companion = CrmTeamCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      active: Value(data['active'] as bool? ?? true),
      companyId: Value(odoo.extractMany2oneId(data['company_id'])),
      companyName: Value(odoo.extractMany2oneName(data['company_id'])),
      userId: Value(odoo.extractMany2oneId(data['user_id'])),
      userName: Value(odoo.extractMany2oneName(data['user_id'])),
      sequence: Value(data['sequence'] as int? ?? 10),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );

    if (existing != null) {
      await (db.update(db.crmTeam)..where((t) => t.odooId.equals(id)))
          .write(companion);
    } else {
      await db.into(db.crmTeam).insert(companion);
    }
  }
}
