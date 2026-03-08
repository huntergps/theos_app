/// AdvanceManager extensions - Business methods beyond generated CRUD
///
/// The base AdvanceManager is generated in advance.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/advances/advance.model.dart';

/// Extension methods for AdvanceManager
extension AdvanceManagerBusiness on AdvanceManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  // ═══════════════════════════════════════════════════════════════════════════
  // Business Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get advances by partner with available amount.
  ///
  /// Returns advances that are confirmed and have available balance.
  Future<List<Advance>> getAvailableByPartnerId(int partnerId) async {
    final rows = await (_db.select(_db.accountAdvance)
          ..where((t) =>
              t.partnerId.equals(partnerId) &
              t.amountAvailable.isBiggerThanValue(0) &
              t.state.equals('posted'))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
        .get();

    return rows.map((r) => fromDrift(r)).toList();
  }

  /// Get advances by state.
  Future<List<Advance>> getByState(AdvanceState state) async {
    final rows = await (_db.select(_db.accountAdvance)
          ..where((t) => t.state.equals(state.code))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
        .get();

    return rows.map((r) => fromDrift(r)).toList();
  }

  /// Get advances for a collection session.
  Future<List<Advance>> getByCollectionSession(int sessionId) async {
    final rows = await (_db.select(_db.accountAdvance)
          ..where((t) => t.collectionSessionId.equals(sessionId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
        .get();

    return rows.map((r) => fromDrift(r)).toList();
  }

  /// Get total available advance amount for a partner.
  Future<double> getTotalAvailableForPartner(int partnerId) async {
    final advances = await getAvailableByPartnerId(partnerId);
    double total = 0.0;
    for (final advance in advances) {
      total += advance.amountAvailable;
    }
    return total;
  }

  /// Get available inbound advances for a partner.
  ///
  /// Returns customer advances (inbound) that are posted or in_use
  /// and have available balance.
  Future<List<Advance>> getAvailableInboundByPartnerId(int partnerId) async {
    final rows = await (_db.select(_db.accountAdvance)
          ..where((t) =>
              t.partnerId.equals(partnerId) &
              t.advanceType.equals('inbound') &
              t.state.isIn(['posted', 'in_use']) &
              t.amountAvailable.isBiggerThanValue(0))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
        .get();

    return rows.map((r) => fromDrift(r)).toList();
  }

  /// Get advances for a sale order.
  Future<List<Advance>> getBySaleOrder(int saleOrderId) async {
    final rows = await (_db.select(_db.accountAdvance)
          ..where((t) => t.saleOrderId.equals(saleOrderId))
          ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
        .get();

    return rows.map((r) => fromDrift(r)).toList();
  }

  /// Delete all advances for a partner.
  Future<void> deleteByPartner(int partnerId) async {
    await (_db.delete(_db.accountAdvance)
          ..where((t) => t.partnerId.equals(partnerId)))
        .go();
  }

  /// Delete all advances for a collection session.
  Future<void> deleteBySession(int sessionId) async {
    await (_db.delete(_db.accountAdvance)
          ..where((t) => t.collectionSessionId.equals(sessionId)))
        .go();
  }
}
