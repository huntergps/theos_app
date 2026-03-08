/// SalesTeamManager extensions - Business methods beyond generated CRUD
///
/// The base SalesTeamManager is generated in sales_team.model.g.dart.
library;

import '../../models/sales/sales_team.model.dart';

/// Extension methods for SalesTeamManager
extension SalesTeamManagerBusiness on SalesTeamManager {
  /// Get team by Odoo ID
  Future<SalesTeam?> getById(int odooId) => readLocal(odooId);

  /// Get all active teams ordered by name
  Future<List<SalesTeam>> getAll() async {
    return searchLocal(domain: [
      ['active', '=', true],
    ]);
  }
}
