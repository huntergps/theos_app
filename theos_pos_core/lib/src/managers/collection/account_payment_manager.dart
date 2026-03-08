/// AccountPaymentManager extensions - Business methods beyond generated CRUD
///
/// The base AccountPaymentManager is generated in account_payment.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/collection/account_payment.model.dart';

/// Extension methods for AccountPaymentManager
extension AccountPaymentManagerBusiness on AccountPaymentManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  // ═══════════════════════════════════════════════════════════════════════════
  // Local Database Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all payments for a collection session
  Future<List<AccountPayment>> getBySessionId(int sessionId) async {
    final query = _db.select(_db.accountPayment)
      ..where((t) => t.collectionSessionId.equals(sessionId))
      ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]);

    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Get payments by origin type (invoice_day, debt, advance)
  Future<List<AccountPayment>> getByOriginType(
    int sessionId,
    String originType,
  ) async {
    final query = _db.select(_db.accountPayment)
      ..where((t) =>
          t.collectionSessionId.equals(sessionId) &
          t.paymentOriginType.equals(originType))
      ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]);

    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Get payments by method category (cash, card_credit, etc.)
  Future<List<AccountPayment>> getByMethodCategory(
    int sessionId,
    String category,
  ) async {
    final query = _db.select(_db.accountPayment)
      ..where((t) =>
          t.collectionSessionId.equals(sessionId) &
          t.paymentMethodCategory.equals(category))
      ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]);

    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Get total amount by session and optional filter
  Future<double> getTotalBySession(
    int sessionId, {
    String? originType,
    String? methodCategory,
  }) async {
    final query = _db.selectOnly(_db.accountPayment)
      ..addColumns([_db.accountPayment.amount.sum()]);

    query.where(_db.accountPayment.collectionSessionId.equals(sessionId));
    if (originType != null) {
      query
          .where(_db.accountPayment.paymentOriginType.equals(originType));
    }
    if (methodCategory != null) {
      query.where(
          _db.accountPayment.paymentMethodCategory.equals(methodCategory));
    }

    final result = await query.getSingleOrNull();
    return result?.read(_db.accountPayment.amount.sum()) ?? 0.0;
  }

  /// Get all payments for a sale order
  Future<List<AccountPayment>> getByOrderId(int orderId) async {
    final query = _db.select(_db.accountPayment)
      ..where((t) => t.saleId.equals(orderId))
      ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]);

    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Delete by UUID
  Future<void> deleteByUuid(String uuid) async {
    await (_db.delete(_db.accountPayment)
          ..where((t) => t.paymentUuid.equals(uuid)))
        .go();
  }

  /// Delete all payments for a session
  Future<void> deleteBySessionId(int sessionId) async {
    await (_db.delete(_db.accountPayment)
          ..where((t) => t.collectionSessionId.equals(sessionId)))
        .go();
  }

  /// Get unsynced payment records
  Future<List<AccountPayment>> getUnsyncedPayments() async {
    final query = _db.select(_db.accountPayment)
      ..where((t) => t.isSynced.equals(false));
    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Get last write date for incremental sync
  Future<DateTime?> getLastPaymentWriteDate() async {
    final query = _db.selectOnly(_db.accountPayment)
      ..addColumns([_db.accountPayment.writeDate])
      ..orderBy([drift.OrderingTerm.desc(_db.accountPayment.writeDate)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    return result?.read(_db.accountPayment.writeDate);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Helper Methods
  // ═══════════════════════════════════════════════════════════════════════════

  String formatPaymentDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
