import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

/// JSON-2 mappers for the payment configuration tables already present in
/// [AppDatabase]. They intentionally do not create or alter schema.
abstract final class PaymentConfigRecordMapper {
  static const cardBrandFields = <String>[
    'id',
    'name',
    'code',
    'active',
    'write_date',
  ];

  static const cardDeadlineFields = <String>[
    'id',
    'name',
    'deadline_days',
    'percentage',
    'active',
    'write_date',
  ];

  static const cardLoteFields = <String>[
    'id',
    'name',
    'journal_id',
    'state',
    'date',
    'numero_lote',
    'amount_total',
    'amount_balance',
    'payment_count',
    'is_pos_lote',
    'write_date',
  ];

  static const paymentMethodLineFields = <String>[
    'id',
    'journal_id',
    'payment_method_id',
    'name',
    'code',
    'payment_type',
    'write_date',
  ];

  static int _id(Object? value, String field) {
    if (value is! int || value <= 0) throw FormatException('$field id');
    return value;
  }

  static String? _string(Object? value) => value is String ? value : null;

  static Future<void> upsertCardBrand(
    AppDatabase db,
    Map<String, dynamic> data,
  ) async {
    final id = _id(data['id'], 'account.card.brand');
    final row = AccountCreditCardBrandCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      code: Value(_string(data['code'])),
      active: Value(data['active'] as bool? ?? true),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );
    await (db.update(
      db.accountCreditCardBrand,
    )..where((t) => t.odooId.equals(id))).write(row);
    if (await (db.select(
          db.accountCreditCardBrand,
        )..where((t) => t.odooId.equals(id))).getSingleOrNull() ==
        null) {
      await db.into(db.accountCreditCardBrand).insert(row);
    }
  }

  static Future<void> upsertCardDeadline(
    AppDatabase db,
    Map<String, dynamic> data,
  ) async {
    final id = _id(data['id'], 'account.card.deadline');
    final row = AccountCreditCardDeadlineCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      deadlineDays: Value(data['deadline_days'] as int? ?? 0),
      percentage: Value((data['percentage'] as num?)?.toDouble() ?? 0),
      active: Value(data['active'] as bool? ?? true),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );
    await (db.update(
      db.accountCreditCardDeadline,
    )..where((t) => t.odooId.equals(id))).write(row);
    if (await (db.select(
          db.accountCreditCardDeadline,
        )..where((t) => t.odooId.equals(id))).getSingleOrNull() ==
        null) {
      await db.into(db.accountCreditCardDeadline).insert(row);
    }
  }

  static Future<void> upsertCardLote(
    AppDatabase db,
    Map<String, dynamic> data,
  ) async {
    final id = _id(data['id'], 'account.card.lote');
    final journalId = odoo.extractMany2oneId(data['journal_id']);
    if (journalId == null || journalId <= 0) {
      throw const FormatException('account.card.lote journal_id');
    }
    final row = AccountCardLoteCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      journalId: Value(journalId),
      journalName: Value(odoo.extractMany2oneName(data['journal_id'])),
      state: Value(data['state'] as String? ?? 'open'),
      date: Value(odoo.parseOdooDateTime(data['date'])),
      numeroLote: Value(_string(data['numero_lote'])),
      amountTotal: Value((data['amount_total'] as num?)?.toDouble() ?? 0),
      amountBalance: Value((data['amount_balance'] as num?)?.toDouble() ?? 0),
      paymentCount: Value(data['payment_count'] as int? ?? 0),
      isPosLote: Value(data['is_pos_lote'] as bool? ?? false),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );
    await (db.update(
      db.accountCardLote,
    )..where((t) => t.odooId.equals(id))).write(row);
    if (await (db.select(
          db.accountCardLote,
        )..where((t) => t.odooId.equals(id))).getSingleOrNull() ==
        null) {
      await db.into(db.accountCardLote).insert(row);
    }
  }

  static Future<void> upsertPaymentMethodLine(
    AppDatabase db,
    Map<String, dynamic> data,
  ) async {
    final id = _id(data['id'], 'account.payment.method.line');
    final journalId = odoo.extractMany2oneId(data['journal_id']);
    final methodId = odoo.extractMany2oneId(data['payment_method_id']);
    if (journalId == null ||
        journalId <= 0 ||
        methodId == null ||
        methodId <= 0) {
      throw const FormatException('account.payment.method.line relation');
    }
    final paymentType =
        data['payment_type'] ?? data['payment_method_id.payment_type'];
    final row = AccountPaymentMethodLineCompanion(
      odooId: Value(id),
      name: Value(data['name'] as String? ?? ''),
      code: Value(
        _string(data['code']) ?? _string(data['payment_method_id.code']),
      ),
      paymentMethodId: Value(methodId),
      paymentMethodName: Value(
        odoo.extractMany2oneName(data['payment_method_id']),
      ),
      journalId: Value(journalId),
      journalName: Value(odoo.extractMany2oneName(data['journal_id'])),
      paymentType: Value(paymentType as String? ?? 'inbound'),
      active: const Value(true),
      writeDate: Value(odoo.parseOdooDateTime(data['write_date'])),
    );
    await (db.update(
      db.accountPaymentMethodLine,
    )..where((t) => t.odooId.equals(id))).write(row);
    if (await (db.select(
          db.accountPaymentMethodLine,
        )..where((t) => t.odooId.equals(id))).getSingleOrNull() ==
        null) {
      await db.into(db.accountPaymentMethodLine).insert(row);
    }
  }

  static Future<List<Map<String, dynamic>>> readCardBrands(
    AppDatabase db,
  ) async => (await db.select(db.accountCreditCardBrand).get())
      .map(
        (r) => {
          'id': r.odooId,
          'name': r.name,
          'code': r.code,
          'active': r.active,
        },
      )
      .toList(growable: false);

  static Future<List<Map<String, dynamic>>> readCardDeadlines(
    AppDatabase db,
  ) async => (await db.select(db.accountCreditCardDeadline).get())
      .map(
        (r) => {
          'id': r.odooId,
          'name': r.name,
          'deadline_days': r.deadlineDays,
          'percentage': r.percentage,
          'active': r.active,
        },
      )
      .toList(growable: false);

  static Future<List<Map<String, dynamic>>> readCardLotes(
    AppDatabase db,
  ) async => (await db.select(db.accountCardLote).get())
      .map(
        (r) => {
          'id': r.odooId,
          'name': r.name,
          'journal_id': r.journalId,
          'journal_name': r.journalName,
          'state': r.state,
          'date': r.date,
          'numero_lote': r.numeroLote,
          'amount_total': r.amountTotal,
          'amount_balance': r.amountBalance,
          'payment_count': r.paymentCount,
          'is_pos_lote': r.isPosLote,
        },
      )
      .toList(growable: false);

  static Future<List<Map<String, dynamic>>> readPaymentMethodLines(
    AppDatabase db,
  ) async => (await db.select(db.accountPaymentMethodLine).get())
      .map(
        (r) => {
          'id': r.odooId,
          'name': r.name,
          'code': r.code,
          'journal_id': r.journalId,
          'journal_name': r.journalName,
          'payment_method_id': r.paymentMethodId,
          'payment_method_name': r.paymentMethodName,
          'payment_type': r.paymentType,
          'active': r.active,
        },
      )
      .toList(growable: false);
}
