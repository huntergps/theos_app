/// JournalManager - Manager for account.journal model
///
/// Read-only manager for accounting journal data synced from Odoo.
library;

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

/// Lightweight data class for journal
class Journal {
  final int odooId;
  final String name;
  final String code;
  final String type;
  final int? companyId;
  final int? currencyId;
  final bool active;
  final DateTime? writeDate;

  const Journal({
    required this.odooId,
    required this.name,
    required this.code,
    required this.type,
    this.companyId,
    this.currencyId,
    this.active = true,
    this.writeDate,
  });
}

/// Manager for account.journal model
class JournalManager {
  final AppDatabase _db;

  JournalManager(this._db);

  String get odooModel => 'account.journal';

  List<String> get odooFields => [
        'id',
        'name',
        'code',
        'type',
        'company_id',
        'currency_id',
        'active',
        'write_date',
      ];

  /// Convert Odoo data to domain model
  Journal fromOdoo(Map<String, dynamic> data) {
    return Journal(
      odooId: data['id'] as int,
      name: data['name'] as String? ?? '',
      code: data['code'] as String? ?? '',
      type: data['type'] as String? ?? 'general',
      companyId: odoo.extractMany2oneId(data['company_id']),
      currencyId: odoo.extractMany2oneId(data['currency_id']),
      active: data['active'] as bool? ?? true,
      writeDate: odoo.parseOdooDateTime(data['write_date']),
    );
  }

  /// Upsert journal to local database
  Future<void> upsertLocal(Journal record) async {
    final companion = AccountJournalCompanion(
      odooId: Value(record.odooId),
      name: Value(record.name),
      code: Value(record.code),
      type: Value(record.type),
      companyId: Value(record.companyId),
      currencyId: Value(record.currencyId),
      active: Value(record.active),
      writeDate: Value(record.writeDate),
    );

    final existing = await (_db.select(_db.accountJournal)
          ..where((t) => t.odooId.equals(record.odooId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.accountJournal)
            ..where((t) => t.odooId.equals(record.odooId)))
          .write(companion);
    } else {
      await _db.into(_db.accountJournal).insert(companion);
    }
  }

  /// Get journal by Odoo ID
  Future<AccountJournalData?> getById(int odooId) async {
    return (_db.select(_db.accountJournal)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();
  }

  /// Get journals by type (cash, bank, sale, purchase, general)
  Future<List<AccountJournalData>> getByType(String type) async {
    return (_db.select(_db.accountJournal)
          ..where((t) => t.type.equals(type) & t.active.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  /// Get all active journals
  Future<List<AccountJournalData>> getAll() async {
    return (_db.select(_db.accountJournal)
          ..where((t) => t.active.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }
}

/// Lightweight data class for payment method line
class PaymentMethodLine {
  final int odooId;
  final int journalId;
  final String? journalName;
  final int paymentMethodId;
  final String? paymentMethodName;
  final String? name;
  final String? code;
  final String paymentType; // inbound, outbound
  final bool active;
  final DateTime? writeDate;

  const PaymentMethodLine({
    required this.odooId,
    required this.journalId,
    this.journalName,
    required this.paymentMethodId,
    this.paymentMethodName,
    this.name,
    this.code,
    required this.paymentType,
    this.active = true,
    this.writeDate,
  });
}

/// Manager for account.payment.method.line model
class PaymentMethodLineManager {
  final AppDatabase _db;

  PaymentMethodLineManager(this._db);

  String get odooModel => 'account.payment.method.line';

  List<String> get odooFields => [
        'id',
        'journal_id',
        'payment_method_id',
        'name',
        'code',
        'payment_type',
        'write_date',
      ];

  /// Convert Odoo data to domain model
  PaymentMethodLine fromOdoo(Map<String, dynamic> data) {
    final journalIdRaw = data['journal_id'];
    final journalId = odoo.extractMany2oneId(journalIdRaw);
    final journalName = journalIdRaw is List && journalIdRaw.length > 1
        ? journalIdRaw[1] as String?
        : null;

    final paymentMethodIdRaw = data['payment_method_id'];
    final paymentMethodId = odoo.extractMany2oneId(paymentMethodIdRaw);
    final paymentMethodName =
        paymentMethodIdRaw is List && paymentMethodIdRaw.length > 1
            ? paymentMethodIdRaw[1] as String?
            : null;

    // payment_type comes from related field payment_method_id.payment_type
    // In Odoo response it may be: 'payment_method_id.payment_type' or nested
    final paymentTypeRaw = data['payment_method_id.payment_type'] ??
                           data['payment_type'];
    final paymentType = paymentTypeRaw is String ? paymentTypeRaw : 'inbound';

    // code comes from related field payment_method_id.code
    final codeRaw = data['payment_method_id.code'] ?? data['code'];
    final code = codeRaw is String ? codeRaw : null;

    return PaymentMethodLine(
      odooId: data['id'] as int,
      journalId: journalId ?? 0,
      journalName: journalName,
      paymentMethodId: paymentMethodId ?? 0,
      paymentMethodName: paymentMethodName,
      name: data['name'] is String ? data['name'] as String : null,
      code: code,
      paymentType: paymentType,
      active: true, // account.payment.method.line doesn't have active field
      writeDate: odoo.parseOdooDateTime(data['write_date']),
    );
  }

  /// Upsert payment method line to local database
  Future<void> upsertLocal(PaymentMethodLine record) async {
    if (record.journalId == 0 || record.paymentMethodId == 0) return;

    final companion = AccountPaymentMethodLineCompanion(
      odooId: Value(record.odooId),
      journalId: Value(record.journalId),
      journalName: Value(record.journalName),
      paymentMethodId: Value(record.paymentMethodId),
      paymentMethodName: Value(record.paymentMethodName),
      name: Value(record.name ?? ''),
      code: Value(record.code),
      paymentType: Value(record.paymentType),
      active: Value(record.active),
      writeDate: Value(record.writeDate),
    );

    final existing = await (_db.select(_db.accountPaymentMethodLine)
          ..where((t) => t.odooId.equals(record.odooId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.accountPaymentMethodLine)
            ..where((t) => t.odooId.equals(record.odooId)))
          .write(companion);
    } else {
      await _db.into(_db.accountPaymentMethodLine).insert(companion);
    }
  }

  /// Get payment method lines by journal
  Future<List<AccountPaymentMethodLineData>> getByJournalId(
      int journalId) async {
    return (_db.select(_db.accountPaymentMethodLine)
          ..where((t) => t.journalId.equals(journalId)))
        .get();
  }
}
