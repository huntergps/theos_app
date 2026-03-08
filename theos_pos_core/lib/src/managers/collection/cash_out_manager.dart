/// CashOutManager extensions - Business methods beyond generated CRUD
///
/// The base CashOutManager is generated in cash_out.model.g.dart.
/// This file adds business-specific query methods and CashOutType
/// local database helpers (CashOutType has no @OdooModel annotation).
library;

import 'package:drift/drift.dart' as drift;

import '../../database/database.dart';
import '../../models/collection/cash_out.model.dart';

/// Extension methods for CashOutManager
extension CashOutManagerBusiness on CashOutManager {
  /// Cast database to AppDatabase for direct Drift queries
  AppDatabase get _db => database as AppDatabase;

  // ═══════════════════════════════════════════════════════════════════════════
  // CashOut Local Database Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all cash outs for a specific collection session
  Future<List<CashOut>> getBySessionId(int sessionId) async {
    final query = _db.select(_db.cashOut)
      ..where((t) => t.collectionSessionId.equals(sessionId));

    final results = await query.get();
    return results.map((row) => fromDrift(row)).toList();
  }

  /// Get cash out by Odoo ID
  Future<CashOut?> getByOdooId(int odooId) async {
    final row = await (_db.select(_db.cashOut)
          ..where((t) => t.odooId.equals(odooId)))
        .getSingleOrNull();

    if (row == null) return null;
    return fromDrift(row);
  }

  /// Upsert a single cash out from Odoo data (marks as synced)
  Future<void> upsertFromOdoo(CashOut cashOut) async {
    if (cashOut.id == 0) return;

    final synced = cashOut.copyWith(
      isSynced: true,
      lastSyncDate: DateTime.now(),
    );

    final companion = createDriftCompanion(synced) as drift.Insertable<CashOutData>;
    await _db.into(_db.cashOut).insertOnConflictUpdate(companion);
  }

  /// Upsert multiple cash outs from Odoo
  Future<void> upsertBatchFromOdoo(List<CashOut> cashOuts) async {
    for (final cashOut in cashOuts) {
      await upsertFromOdoo(cashOut);
    }
  }

  /// Upsert a single cash out (for local operations)
  Future<void> upsertCashOut(CashOut cashOut) async {
    final companion = createDriftCompanion(cashOut) as drift.Insertable<CashOutData>;
    await _db.into(_db.cashOut).insertOnConflictUpdate(companion);
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // CashOutType Local Database Operations
  // ═══════════════════════════════════════════════════════════════════════════

  /// Get all active cash out types
  Future<List<CashOutType>> getCashOutTypes() async {
    final rows = await (_db.select(_db.cashOutType)
          ..where((t) => t.active.equals(true))
          ..orderBy([
            (t) => drift.OrderingTerm(expression: t.sequence),
          ]))
        .get();

    return rows.map(_mapRowToCashOutType).toList();
  }

  /// Get cash out type by code
  Future<CashOutType?> getCashOutTypeByCode(String code) async {
    final row = await (_db.select(_db.cashOutType)
          ..where((t) => t.code.equals(code)))
        .getSingleOrNull();

    if (row == null) return null;
    return _mapRowToCashOutType(row);
  }

  /// Upsert a single cash out type
  Future<void> upsertCashOutType(CashOutType type) async {
    final companion = CashOutTypeCompanion(
      odooId: drift.Value(type.id),
      name: drift.Value(type.name),
      code: drift.Value(type.code),
      active: const drift.Value(true),
      writeDate: drift.Value(DateTime.now()),
    );
    await _db.into(_db.cashOutType).insert(
          companion,
          onConflict: drift.DoUpdate(
            (old) => companion,
            target: [_db.cashOutType.odooId],
          ),
        );
  }

  /// Upsert multiple cash out types
  Future<void> upsertCashOutTypes(List<CashOutType> types) async {
    for (final type in types) {
      await upsertCashOutType(type);
    }
  }

  /// Map database row to CashOutType model
  CashOutType _mapRowToCashOutType(CashOutTypeData row) {
    return CashOutType(
      id: row.odooId,
      name: row.name,
      code: row.code,
    );
  }
}
