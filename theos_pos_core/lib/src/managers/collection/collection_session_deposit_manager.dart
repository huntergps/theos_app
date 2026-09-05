/// CollectionSessionDepositManager extensions - Business methods beyond generated CRUD
///
/// The base CollectionSessionDepositManager is generated in
/// collection_session_deposit.model.g.dart.
/// This file adds business-specific query methods.
library;

import '../../database/database.dart';
import '../../models/collection/collection_session_deposit.model.dart';

/// Extension methods for CollectionSessionDepositManager
extension CollectionSessionDepositManagerBusiness
    on CollectionSessionDepositManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  // ═══════════════════════════════════════════════════════════════════════════
  // Local Database Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all deposits for a specific collection session
  Future<List<CollectionSessionDeposit>> getBySessionId(int sessionId) async {
    final results = await (_db.select(
      _db.collectionSessionDeposit,
    )..where((tbl) => tbl.collectionSessionId.equals(sessionId))).get();

    return results.map((row) => fromDrift(row)).toList();
  }

  /// Upsert a collection session deposit record
  Future<void> upsertDeposit(CollectionSessionDeposit deposit) async {
    // The generated mapper persists every local/offline field (UUID, session
    // UUID, accounting date, journal, notes and sync state). Keeping a second
    // partial companion here silently discarded those values on updates and
    // made durable replay impossible after a restart.
    await upsertLocal(deposit);
  }
}
