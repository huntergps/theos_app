import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

abstract final class TaxRecordMapper {
  static const fields = <String>[
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
  static Future<bool> exists(AppDatabase db, int id) async =>
      (await (db.select(
        db.accountTax,
      )..where((t) => t.odooId.equals(id))).getSingleOrNull()) !=
      null;
  static Future<void> upsert(AppDatabase db, Map<String, dynamic> d) async {
    final id = d['id'];
    if (id is! int || id <= 0) throw const FormatException('account.tax id');
    final c = AccountTaxCompanion(
      odooId: Value(id),
      name: Value(d['name'] as String? ?? ''),
      description: Value(d['description'] is String? ? d['description'] : null),
      typeTaxUse: Value(d['type_tax_use'] as String? ?? 'sale'),
      amountType: Value(d['amount_type'] as String? ?? 'percent'),
      amount: Value((d['amount'] as num?)?.toDouble() ?? 0),
      active: Value(d['active'] as bool? ?? true),
      priceInclude: Value(d['price_include'] as bool? ?? false),
      includeBaseAmount: Value(d['include_base_amount'] as bool? ?? false),
      sequence: Value(d['sequence'] as int? ?? 1),
      companyId: Value(odoo.extractMany2oneId(d['company_id'])),
      companyName: Value(odoo.extractMany2oneName(d['company_id'])),
      taxGroupId: Value(odoo.extractMany2oneId(d['tax_group_id'])),
      taxGroupName: Value(odoo.extractMany2oneName(d['tax_group_id'])),
      taxGroupL10nEcType: Value(
        d['tax_group_l10n_ec_type'] is String?
            ? d['tax_group_l10n_ec_type']
            : null,
      ),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    if (await exists(db, id)) {
      await (db.update(
        db.accountTax,
      )..where((t) => t.odooId.equals(id))).write(c);
    } else {
      await db.into(db.accountTax).insert(c);
    }
  }
}
