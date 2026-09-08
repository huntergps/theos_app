import 'package:drift/drift.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../core/services/handlers/model_record_handler.dart';

import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

/// Handler for account.tax records
class TaxRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'account.tax';

  @override
  List<String> get defaultFields => TaxRecordMapper.fields;

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    return TaxRecordMapper.exists(db, odooId);
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    return TaxRecordMapper.upsert(db, data);
  }
}

/// Handler for account.fiscal.position records
class FiscalPositionRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'account.fiscal.position';

  @override
  List<String> get defaultFields => const [
    'id',
    'name',
    'active',
    'company_id',
    'sequence',
    'note',
    'auto_apply',
    'country_id',
    'write_date',
  ];

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    final result = await (db.select(
      db.accountFiscalPosition,
    )..where((t) => t.odooId.equals(odooId))).getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'] as int;

    final existing = await (db.select(
      db.accountFiscalPosition,
    )..where((t) => t.odooId.equals(id))).getSingleOrNull();

    final companion = AccountFiscalPositionCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      active: Value(data['active'] as bool? ?? true),
      companyId: Value(odoo.extractMany2oneId(data['company_id'])),
      companyName: Value(odoo.extractMany2oneName(data['company_id'])),
      sequence: Value(data['sequence'] as int? ?? 10),
      note: Value(data['note'] is String ? data['note'] : null),
      autoApply: Value(data['auto_apply'] as bool? ?? false),
      countryId: Value(odoo.extractMany2oneId(data['country_id'])),
      countryName: Value(odoo.extractMany2oneName(data['country_id'])),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );

    if (existing != null) {
      await (db.update(
        db.accountFiscalPosition,
      )..where((t) => t.odooId.equals(id))).write(companion);
    } else {
      await db.into(db.accountFiscalPosition).insert(companion);
    }
  }
}

/// Handler for account.payment.term records
class PaymentTermRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'account.payment.term';

  @override
  List<String> get defaultFields => [
    'id',
    'name',
    'active',
    'note',
    'company_id',
    'sequence',
    'write_date',
  ];

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    return PaymentTermRecordMapper.exists(db, odooId);
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    return PaymentTermRecordMapper.upsert(db, data);
  }
}
