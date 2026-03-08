/// CollectionSessionCashManager extensions - Business methods beyond generated CRUD
///
/// The base CollectionSessionCashManager is generated in
/// collection_session_cash.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/collection/collection_session_cash.model.dart';

/// Extension methods for CollectionSessionCashManager
extension CollectionSessionCashManagerBusiness on CollectionSessionCashManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  // ═══════════════════════════════════════════════════════════════════════════
  // Local Database Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get cash details for a session by type (opening or closing)
  ///
  /// Returns the most recent record matching the session and cash type.
  Future<CollectionSessionCash?> getBySessionAndType({
    required int sessionId,
    required String cashType,
  }) async {
    final query = _db.select(_db.collectionSessionCash)
      ..where((tbl) => tbl.collectionSessionId.equals(sessionId))
      ..where((tbl) => tbl.cashType.equals(cashType))
      ..orderBy([(tbl) => drift.OrderingTerm.desc(tbl.id)])
      ..limit(1);

    final result = await query.getSingleOrNull();
    if (result == null) return null;

    return fromDrift(result);
  }

  /// Upsert a collection session cash record
  Future<void> upsertSessionCash(CollectionSessionCash cash) async {
    await _db
        .into(_db.collectionSessionCash)
        .insert(
          CollectionSessionCashCompanion.insert(
            odooId: cash.id,
            sessionId: cash.collectionSessionId ?? 0,
            collectionSessionId: cash.collectionSessionId ?? 0,
            cashType: drift.Value(cash.cashType == CashType.closing
                ? 'closing'
                : 'opening'),
            bills100: drift.Value(cash.bills100),
            bills50: drift.Value(cash.bills50),
            bills20: drift.Value(cash.bills20),
            bills10: drift.Value(cash.bills10),
            bills5: drift.Value(cash.bills5),
            bills1: drift.Value(cash.bills1),
            coins1: drift.Value(cash.coins1),
            coins50: drift.Value(cash.coins50),
            coins25: drift.Value(cash.coins25),
            coins10: drift.Value(cash.coins10),
            coins5: drift.Value(cash.coins5),
            coins1Cent: drift.Value(cash.coins1Cent),
            notes: drift.Value(cash.notes),
          ),
          onConflict: drift.DoUpdate(
            (old) => CollectionSessionCashCompanion.custom(
              bills100: drift.Variable(cash.bills100),
              bills50: drift.Variable(cash.bills50),
              bills20: drift.Variable(cash.bills20),
              bills10: drift.Variable(cash.bills10),
              bills5: drift.Variable(cash.bills5),
              bills1: drift.Variable(cash.bills1),
              coins1: drift.Variable(cash.coins1),
              coins50: drift.Variable(cash.coins50),
              coins25: drift.Variable(cash.coins25),
              coins10: drift.Variable(cash.coins10),
              coins5: drift.Variable(cash.coins5),
              coins1Cent: drift.Variable(cash.coins1Cent),
              notes: drift.Variable(cash.notes),
            ),
            target: [
              _db.collectionSessionCash.odooId,
            ],
          ),
        );
  }
}
