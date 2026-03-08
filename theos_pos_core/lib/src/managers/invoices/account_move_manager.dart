/// AccountMoveManager extensions - Business methods beyond generated CRUD
///
/// The base AccountMoveManager is generated in account_move.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/invoices/account_move.model.dart';

/// Extension methods for AccountMoveManager
extension AccountMoveManagerBusiness on AccountMoveManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  // ═══════════════════════════════════════════════════════════════════════════
  // Invoice-specific methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get invoices for a specific sale order
  Future<List<AccountMove>> getForSaleOrder(int saleOrderId) async {
    final results = await (_db.select(_db.accountMove)
          ..where((t) => t.ref.contains('SO/$saleOrderId')))
        .get();
    return results.map((r) => fromDrift(r)).toList();
  }

  /// Get invoices for a specific partner
  Future<List<AccountMove>> getForPartner(int partnerId) async {
    final results = await (_db.select(_db.accountMove)
          ..where((t) => t.partnerId.equals(partnerId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.invoiceDate)]))
        .get();
    return results.map((r) => fromDrift(r)).toList();
  }

  /// Get unpaid invoices (with residual amount > 0)
  Future<List<AccountMove>> getUnpaid({int? partnerId}) async {
    var query = _db.select(_db.accountMove)
      ..where((t) => t.amountResidual.isBiggerThanValue(0))
      ..where((t) => t.state.equals('posted'))
      ..orderBy([(t) => drift.OrderingTerm.asc(t.invoiceDateDue)]);

    if (partnerId != null) {
      query = query..where((t) => t.partnerId.equals(partnerId));
    }

    final results = await query.get();
    return results.map((r) => fromDrift(r)).toList();
  }

  /// Get invoices by state
  Future<List<AccountMove>> getByState(String state) async {
    final results = await (_db.select(_db.accountMove)
          ..where((t) => t.state.equals(state))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.invoiceDate)]))
        .get();
    return results.map((r) => fromDrift(r)).toList();
  }

  /// Get credit notes (out_refund type)
  Future<List<AccountMove>> getCreditNotes({int? partnerId}) async {
    var query = _db.select(_db.accountMove)
      ..where((t) => t.moveType.equals('out_refund'))
      ..orderBy([(t) => drift.OrderingTerm.desc(t.invoiceDate)]);

    if (partnerId != null) {
      query = query..where((t) => t.partnerId.equals(partnerId));
    }

    final results = await query.get();
    return results.map((r) => fromDrift(r)).toList();
  }

  /// Search invoices with specific filters
  Future<List<AccountMove>> searchInvoices({
    String? moveType,
    String? state,
    int? partnerId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? limit,
  }) async {
    var query = _db.select(_db.accountMove);

    if (moveType != null) {
      query = query..where((t) => t.moveType.equals(moveType));
    }
    if (state != null) {
      query = query..where((t) => t.state.equals(state));
    }
    if (partnerId != null) {
      query = query..where((t) => t.partnerId.equals(partnerId));
    }
    if (dateFrom != null) {
      query = query
        ..where((t) => t.invoiceDate.isBiggerOrEqualValue(dateFrom));
    }
    if (dateTo != null) {
      query = query..where((t) => t.invoiceDate.isSmallerOrEqualValue(dateTo));
    }

    query = query..orderBy([(t) => drift.OrderingTerm.desc(t.invoiceDate)]);

    if (limit != null) {
      query = query..limit(limit);
    }

    final results = await query.get();
    return results.map((r) => fromDrift(r)).toList();
  }
}
