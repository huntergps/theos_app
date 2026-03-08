/// CreditNoteManager - Manager for account.move (credit notes) model
///
/// Read-only manager for credit note data synced from Odoo.
/// Only handles credit notes with residual balance for payment application.
library;

import 'package:drift/drift.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as odoo;

import '../../database/database.dart';

/// Lightweight data class for credit note
class CreditNote {
  final int odooId;
  final String name;
  final int partnerId;
  final String? partnerName;
  final double amountTotal;
  final double amountResidual;
  final String moveType;
  final String state;
  final DateTime? invoiceDate;
  final int? companyId;
  final DateTime? writeDate;

  const CreditNote({
    required this.odooId,
    required this.name,
    required this.partnerId,
    this.partnerName,
    required this.amountTotal,
    required this.amountResidual,
    required this.moveType,
    required this.state,
    this.invoiceDate,
    this.companyId,
    this.writeDate,
  });
}

/// Manager for account.move (credit notes) model
class CreditNoteManager {
  final AppDatabase _db;

  CreditNoteManager(this._db);

  String get odooModel => 'account.move';

  List<String> get odooFields => [
        'id',
        'name',
        'partner_id',
        'amount_total',
        'amount_residual',
        'move_type',
        'state',
        'invoice_date',
        'company_id',
        'write_date',
      ];

  /// Domain for fetching credit notes with residual balance
  List<dynamic> get creditNoteDomain => [
        ['move_type', '=', 'out_refund'],
        ['state', '=', 'posted'],
        ['amount_residual', '>', 0],
      ];

  /// Convert Odoo data to domain model
  CreditNote fromOdoo(Map<String, dynamic> data) {
    final partnerId = odoo.extractMany2oneId(data['partner_id']);

    return CreditNote(
      odooId: data['id'] as int,
      name: data['name'] as String? ?? '',
      partnerId: partnerId ?? 0,
      partnerName: odoo.extractMany2oneName(data['partner_id']),
      amountTotal: (data['amount_total'] as num?)?.toDouble() ?? 0.0,
      amountResidual: (data['amount_residual'] as num?)?.toDouble() ?? 0.0,
      moveType: data['move_type'] as String? ?? 'out_refund',
      state: data['state'] as String? ?? 'posted',
      invoiceDate: odoo.parseOdooDateTime(data['invoice_date']),
      companyId: odoo.extractMany2oneId(data['company_id']),
      writeDate: odoo.parseOdooDateTime(data['write_date']),
    );
  }

  /// Upsert credit note to local database
  Future<void> upsertLocal(CreditNote record) async {
    if (record.partnerId == 0) return;

    final companion = AccountMoveCompanion(
      odooId: Value(record.odooId),
      name: Value(record.name),
      partnerId: Value(record.partnerId),
      partnerName: Value(record.partnerName),
      amountTotal: Value(record.amountTotal),
      amountResidual: Value(record.amountResidual),
      moveType: Value(record.moveType),
      state: Value(record.state),
      invoiceDate: Value(record.invoiceDate),
      companyId: Value(record.companyId),
      writeDate: Value(record.writeDate),
    );

    final existing = await (_db.select(_db.accountMove)
          ..where((t) => t.odooId.equals(record.odooId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.accountMove)
            ..where((t) => t.odooId.equals(record.odooId)))
          .write(companion);
    } else {
      await _db.into(_db.accountMove).insert(companion);
    }
  }

  /// Get credit notes by partner with residual balance
  Future<List<AccountMoveData>> getAvailableByPartnerId(int partnerId) async {
    return (_db.select(_db.accountMove)
          ..where((t) =>
              t.partnerId.equals(partnerId) &
              t.moveType.equals('out_refund') &
              t.state.equals('posted') &
              t.amountResidual.isBiggerThanValue(0))
          ..orderBy([(t) => OrderingTerm.desc(t.invoiceDate)]))
        .get();
  }
}
