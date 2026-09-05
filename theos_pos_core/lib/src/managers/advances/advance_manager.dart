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

  /// Reads an advance together with its locally persisted payment lines.
  /// The generated manager intentionally treats [Advance.lines] as local-only,
  /// so callers that need the complete offline detail must use this method.
  Future<Advance?> readLocalWithLines(int id) async {
    final db = _db;
    final headerManager = AdvanceManager()..initDb(db);
    final lineManager = AdvanceLineManager()..initDb(db);
    final advance = await headerManager.readLocal(id);
    if (advance == null) return null;
    final rows =
        await (db.select(db.advanceLinesTable)
              ..where((t) => t.advanceId.equals(id))
              ..orderBy([(t) => drift.OrderingTerm.asc(t.id)]))
            .get();
    return advance.copyWith(lines: rows.map(lineManager.fromDrift).toList());
  }

  /// Atomically replaces the locally cached child lines for an advance.
  Future<void> upsertLocalWithLines(Advance advance) async {
    final db = _db;
    final headerManager = AdvanceManager()..initDb(db);
    final lineManager = AdvanceLineManager()..initDb(db);
    await db.transaction(() async {
      await headerManager.upsertLocal(advance);
      await (db.delete(
        db.advanceLinesTable,
      )..where((t) => t.advanceId.equals(advance.id))).go();
      // Unsaved lines default to id=0. Give each a distinct local identity,
      // including across different advances, before using an upsert.
      final minimum = await db
          .customSelect(
            'SELECT COALESCE(MIN(odoo_id), 0) AS min_id FROM advance_lines',
          )
          .getSingle();
      final minId = minimum.read<int>('min_id');
      var nextLocalId = (minId < 0 ? minId : 0) - 1;
      for (final line in advance.lines) {
        await lineManager.upsertLocal(
          line.copyWith(
            id: line.id > 0 ? line.id : nextLocalId--,
            advanceId: advance.id,
          ),
        );
      }
    });
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Business Methods
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get advances by partner with available amount.
  ///
  /// Returns advances that are confirmed and have available balance.
  Future<List<Advance>> getAvailableByPartnerId(int partnerId) async {
    final rows =
        await (_db.select(_db.accountAdvance)
              ..where(
                (t) =>
                    t.partnerId.equals(partnerId) &
                    t.amountAvailable.isBiggerThanValue(0) &
                    t.state.equals('posted'),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
            .get();

    return rows.map((r) => fromDrift(r)).toList();
  }

  /// Get advances by state.
  Future<List<Advance>> getByState(AdvanceState state) async {
    final rows =
        await (_db.select(_db.accountAdvance)
              ..where((t) => t.state.equals(state.code))
              ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
            .get();

    return rows.map((r) => fromDrift(r)).toList();
  }

  /// Get advances for a collection session.
  Future<List<Advance>> getByCollectionSession(int sessionId) async {
    final rows =
        await (_db.select(_db.accountAdvance)
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
    final rows =
        await (_db.select(_db.accountAdvance)
              ..where(
                (t) =>
                    t.partnerId.equals(partnerId) &
                    t.advanceType.equals('inbound') &
                    t.state.isIn(['posted', 'in_use']) &
                    t.amountAvailable.isBiggerThanValue(0),
              )
              ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
            .get();

    return rows.map((r) => fromDrift(r)).toList();
  }

  /// Get advances for a sale order.
  Future<List<Advance>> getBySaleOrder(int saleOrderId) async {
    final rows =
        await (_db.select(_db.accountAdvance)
              ..where((t) => t.saleOrderId.equals(saleOrderId))
              ..orderBy([(t) => drift.OrderingTerm.desc(t.date)]))
            .get();

    return rows.map((r) => fromDrift(r)).toList();
  }

  /// Delete all advances for a partner.
  Future<void> deleteByPartner(int partnerId) async {
    await (_db.delete(
      _db.accountAdvance,
    )..where((t) => t.partnerId.equals(partnerId))).go();
  }

  /// Delete all advances for a collection session.
  Future<void> deleteBySession(int sessionId) async {
    await (_db.delete(
      _db.accountAdvance,
    )..where((t) => t.collectionSessionId.equals(sessionId))).go();
  }
}
