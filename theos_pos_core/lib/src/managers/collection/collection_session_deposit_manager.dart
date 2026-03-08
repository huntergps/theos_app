/// CollectionSessionDepositManager extensions - Business methods beyond generated CRUD
///
/// The base CollectionSessionDepositManager is generated in
/// collection_session_deposit.model.g.dart.
/// This file adds business-specific query methods.
library;

import 'package:drift/drift.dart' as drift;

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
  Future<List<CollectionSessionDeposit>> getBySessionId(
    int sessionId,
  ) async {
    final results = await (_db.select(
      _db.collectionSessionDeposit,
    )..where((tbl) => tbl.collectionSessionId.equals(sessionId)))
        .get();

    return results.map((row) => fromDrift(row)).toList();
  }

  /// Upsert a collection session deposit record
  Future<void> upsertDeposit(
    CollectionSessionDeposit deposit,
  ) async {
    await _db
        .into(_db.collectionSessionDeposit)
        .insert(
          CollectionSessionDepositCompanion.insert(
            odooId: drift.Value(deposit.id),
            sessionId: deposit.collectionSessionId ?? 0,
            collectionSessionId: deposit.collectionSessionId ?? 0,
            depositType: deposit.depositType.name,
            depositDate: deposit.depositDate ?? DateTime.now(),
            amount: drift.Value(deposit.amount),
            reference: drift.Value(deposit.number),
            bankId: drift.Value(deposit.bankId ?? deposit.bankJournalId),
            bankName:
                drift.Value(deposit.bankName ?? deposit.bankJournalName),
            state: drift.Value(deposit.state ?? 'draft'),
            writeDate: drift.Value(deposit.writeDate),
          ),
          onConflict: drift.DoUpdate(
            (old) => CollectionSessionDepositCompanion.custom(
              amount: drift.Variable(deposit.amount),
              reference: drift.Variable(deposit.number),
              state: drift.Variable(deposit.state ?? 'draft'),
            ),
            target: [_db.collectionSessionDeposit.odooId],
          ),
        );
  }
}
