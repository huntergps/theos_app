import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

abstract final class CollectionConfigRecordMapper {
  static const fields = <String>[
    'id',
    'name',
    'code',
    'active',
    'company_id',
    'journal_id',
    'cash_journal_id',
    'allowed_journal_ids',
    'cash_difference_account_id',
    'set_maximum_difference',
    'amount_authorized_diff',
    'user_ids',
    'current_session_id',
    'current_session_state',
    'current_session_name',
    'number_of_opened_session',
    'last_session_closing_date',
    'last_session_closing_cash',
    'collection_session_username',
    'current_session_state_display',
    'number_of_rescue_session',
    'write_date',
  ];
  static Future<bool> exists(AppDatabase db, int id) async =>
      (await (db.select(
        db.collectionConfig,
      )..where((t) => t.odooId.equals(id))).getSingleOrNull()) !=
      null;
  static Future<void> upsert(AppDatabase db, Map<String, dynamic> d) async {
    final id = d['id'];
    if (id is! int || id <= 0) {
      throw const FormatException('collection.config id');
    }
    String? ids(Object? v) =>
        v is List ? jsonEncode(v.whereType<int>().toList()) : null;
    final c = CollectionConfigCompanion(
      odooId: Value(id),
      // 🔴 Igual que en `PartnerRecordMapper`: Odoo manda `false`, no `null`,
      // en cualquier campo de texto vacío, y `as String?` no filtra `false`.
      // `toStringOrNull` sí lo hace, y respeta `''` cuando de verdad es texto
      // vacío devuelto como tal.
      name: Value(odoo.toStringOrNull(d['name']) ?? ''),
      code: Value(odoo.toStringOrNull(d['code'])),
      active: Value(d['active'] as bool? ?? true),
      companyId: Value(odoo.extractMany2oneId(d['company_id']) ?? 0),
      companyName: Value(odoo.extractMany2oneName(d['company_id'])),
      journalId: Value(odoo.extractMany2oneId(d['journal_id'])),
      journalName: Value(odoo.extractMany2oneName(d['journal_id'])),
      cashJournalId: Value(odoo.extractMany2oneId(d['cash_journal_id'])),
      cashJournalName: Value(odoo.extractMany2oneName(d['cash_journal_id'])),
      allowedJournalIds: Value(ids(d['allowed_journal_ids'])),
      cashDifferenceAccountId: Value(
        odoo.extractMany2oneId(d['cash_difference_account_id']),
      ),
      setMaximumDifference: Value(
        d['set_maximum_difference'] as bool? ?? false,
      ),
      amountAuthorizedDiff: Value(
        (d['amount_authorized_diff'] as num?)?.toDouble() ?? 0,
      ),
      userIds: Value(ids(d['user_ids'])),
      posAppCapabilitiesJson: Value(
        odoo.toStringOrNull(d['pos_app_capabilities_json']),
      ),
      currentSessionId: Value(odoo.extractMany2oneId(d['current_session_id'])),
      currentSessionState: Value(odoo.toStringOrNull(d['current_session_state'])),
      currentSessionName: Value(odoo.toStringOrNull(d['current_session_name'])),
      numberOfOpenedSession: Value(d['number_of_opened_session'] as int? ?? 0),
      lastSessionClosingDate: Value(
        odoo.parseOdooDateTime(d['last_session_closing_date']),
      ),
      lastSessionClosingCash: Value(
        (d['last_session_closing_cash'] as num?)?.toDouble() ?? 0,
      ),
      collectionSessionUsername: Value(
        odoo.toStringOrNull(d['collection_session_username']),
      ),
      currentSessionStateDisplay: Value(
        odoo.toStringOrNull(d['current_session_state_display']),
      ),
      numberOfRescueSession: Value(d['number_of_rescue_session'] as int? ?? 0),
      writeDate: Value(odoo.parseOdooDateTime(d['write_date'])),
    );
    if (await exists(db, id)) {
      await (db.update(
        db.collectionConfig,
      )..where((t) => t.odooId.equals(id))).write(c);
    } else {
      await db.into(db.collectionConfig).insert(c);
    }
  }
}
