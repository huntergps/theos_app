/// FiscalPositionManager extensions - Business methods beyond generated CRUD
///
/// The base FiscalPositionManager is generated in fiscal_position.model.g.dart.
/// This file adds business-specific query methods via extension.
///
/// FiscalPositionTaxManager remains a full class because
/// FiscalPositionTax does not have @OdooModel and has no generated manager.
library;

import '../../database/database.dart';
import '../../models/taxes/fiscal_position.model.dart';

/// Extension methods for FiscalPositionManager (generated)
extension FiscalPositionManagerBusiness on FiscalPositionManager {
  /// Get fiscal position by Odoo ID (alias for readLocal)
  Future<FiscalPosition?> getById(int odooId) => readLocal(odooId);

  /// Get all active fiscal positions ordered by name
  Future<List<FiscalPosition>> getAll() async {
    return searchLocal(
      domain: [
        ['active', '=', true],
      ],
      orderBy: 'name asc',
    );
  }
}

/// Manager for account.fiscal.position.tax model
///
/// This is a manual manager because FiscalPositionTax does not have
/// @OdooModel annotation and therefore no code-generated manager.
class FiscalPositionTaxManager {
  final AppDatabase _db;

  FiscalPositionTaxManager(this._db);

  String get odooModel => FiscalPositionTax.odooModel;

  List<String> get odooFields => FiscalPositionTax.odooFields;

  /// Convert Odoo data to domain model
  FiscalPositionTax fromOdoo(Map<String, dynamic> data) {
    return FiscalPositionTax.fromOdoo(data);
  }

  /// Upsert fiscal position tax to local database
  Future<void> upsertLocal(FiscalPositionTax record) async {
    if (record.positionId == 0 || record.taxSrcId == 0) return;

    final companion = record.toCompanion();

    final existing = await (_db.select(_db.accountFiscalPositionTax)
          ..where((t) => t.odooId.equals(record.odooId)))
        .getSingleOrNull();

    if (existing != null) {
      await (_db.update(_db.accountFiscalPositionTax)
            ..where((t) => t.odooId.equals(record.odooId)))
          .write(companion);
    } else {
      await _db.into(_db.accountFiscalPositionTax).insert(companion);
    }
  }

  /// Get tax mappings for a fiscal position
  Future<List<AccountFiscalPositionTaxData>> getByPositionId(
      int positionId) async {
    return (_db.select(_db.accountFiscalPositionTax)
          ..where((t) => t.positionId.equals(positionId)))
        .get();
  }
}
