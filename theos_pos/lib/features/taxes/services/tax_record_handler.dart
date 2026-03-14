import 'package:drift/drift.dart';

import 'package:theos_pos_core/theos_pos_core.dart';
import '../../../core/services/handlers/model_record_handler.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

/// Handler for account.tax records
class TaxRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'account.tax';

  @override
  List<String> get defaultFields => [
    'id',
    'name',
    'description',
    'type_tax_use',
    'amount_type',
    'amount',
    'active',
    'price_include',
    'include_base_amount',
    'sequence',
    'company_id',
    'tax_group_id',
    'tax_group_l10n_ec_type',
    'write_date',
  ];

  @override
  Future<bool> exists(AppDatabase db, int odooId) async {
    final result = await (db.select(db.accountTax)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'] as int;

    final existing = await (db.select(db.accountTax)
          ..where((t) => t.odooId.equals(id)))
        .getSingleOrNull();

    final companion = AccountTaxCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      description: Value(
        data['description'] is String ? data['description'] : null,
      ),
      typeTaxUse: Value(data['type_tax_use'] as String? ?? 'sale'),
      amountType: Value(data['amount_type'] as String? ?? 'percent'),
      amount: Value((data['amount'] as num?)?.toDouble() ?? 0.0),
      active: Value(data['active'] as bool? ?? true),
      priceInclude: Value(data['price_include'] as bool? ?? false),
      includeBaseAmount: Value(data['include_base_amount'] as bool? ?? false),
      sequence: Value(data['sequence'] as int? ?? 1),
      companyId: Value(odoo.extractMany2oneId(data['company_id'])),
      companyName: Value(odoo.extractMany2oneName(data['company_id'])),
      taxGroupId: Value(odoo.extractMany2oneId(data['tax_group_id'])),
      taxGroupIdName: Value(odoo.extractMany2oneName(data['tax_group_id'])),
      taxGroupL10nEcType: Value(data['tax_group_l10n_ec_type'] is String ? data['tax_group_l10n_ec_type'] : null),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );

    if (existing != null) {
      await (db.update(db.accountTax)..where((t) => t.odooId.equals(id)))
          .write(companion);
    } else {
      await db.into(db.accountTax).insert(companion);
    }
  }
}

/// Handler for account.fiscal.position records
class FiscalPositionRecordHandler extends ModelRecordHandler {
  @override
  String get odooModel => 'account.fiscal.position';

  @override
  List<String> get defaultFields => [
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
    final result = await (db.select(db.accountFiscalPosition)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'] as int;

    final existing = await (db.select(db.accountFiscalPosition)
          ..where((t) => t.odooId.equals(id)))
        .getSingleOrNull();

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
      await (db.update(db.accountFiscalPosition)
            ..where((t) => t.odooId.equals(id)))
          .write(companion);
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
    final result = await (db.select(db.accountPaymentTerm)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
    return result != null;
  }

  @override
  Future<void> upsert(AppDatabase db, Map<String, dynamic> data) async {
    final id = data['id'] as int;

    final existing = await (db.select(db.accountPaymentTerm)
          ..where((t) => t.odooId.equals(id)))
        .getSingleOrNull();

    final companion = AccountPaymentTermCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      active: Value(data['active'] as bool? ?? true),
      note: Value(data['note'] is String ? data['note'] : null),
      companyId: Value(odoo.extractMany2oneId(data['company_id'])),
      sequence: Value(data['sequence'] as int? ?? 10),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );

    if (existing != null) {
      await (db.update(db.accountPaymentTerm)
            ..where((t) => t.odooId.equals(id)))
          .write(companion);
    } else {
      await db.into(db.accountPaymentTerm).insert(companion);
    }
  }
}
