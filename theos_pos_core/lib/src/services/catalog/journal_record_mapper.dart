import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

abstract final class JournalRecordMapper {
  static const fields = <String>[
    'id',
    'name',
    'code',
    'type',
    'company_id',
    'currency_id',
    'l10n_ec_entity',
    'l10n_ec_emission',
    'active',
    'numbered_by_client',
    'write_date',
  ];
  static Future<bool> exists(AppDatabase db, int id) async =>
      (await (db.select(
        db.accountJournal,
      )..where((t) => t.odooId.equals(id))).getSingleOrNull()) !=
      null;
  static Future<void> upsert(AppDatabase db, Map<String, dynamic> d) async {
    final id = d['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('account.journal id');
    }
    final c = AccountJournalCompanion(
      odooId: Value(id),
      // 🔴 Mismo patrón que en `PartnerRecordMapper`: `as String?` no filtra
      // el `false` que Odoo manda para un texto vacío.
      name: Value(odoo.toStringOrNull(d['name']) ?? ''),
      code: Value(odoo.toStringOrNull(d['code']) ?? ''),
      type: Value(odoo.toStringOrNull(d['type']) ?? 'general'),
      companyId: Value(odoo.extractMany2oneId(d['company_id'])),
      currencyId: Value(odoo.extractMany2oneId(d['currency_id'])),
      l10nEcEntity: Value(
        d['l10n_ec_entity'] is String &&
                (d['l10n_ec_entity'] as String).isNotEmpty
            ? d['l10n_ec_entity']
            : null,
      ),
      l10nEcEmission: Value(
        d['l10n_ec_emission'] is String &&
                (d['l10n_ec_emission'] as String).isNotEmpty
            ? d['l10n_ec_emission']
            : null,
      ),
      active: Value(d['active'] as bool? ?? true),
      numberedByClient: Value(d['numbered_by_client'] as bool? ?? false),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    if (await exists(db, id)) {
      await (db.update(
        db.accountJournal,
      )..where((t) => t.odooId.equals(id))).write(c);
    } else {
      await db.into(db.accountJournal).insert(c);
    }
  }

  static Future<List<Map<String, dynamic>>> read(AppDatabase db) async =>
      (await db.select(db.accountJournal).get())
          .map(
            (r) => {
              'id': r.odooId,
              'name': r.name,
              'code': r.code,
              'type': r.type,
            },
          )
          .toList(growable: false);
}
