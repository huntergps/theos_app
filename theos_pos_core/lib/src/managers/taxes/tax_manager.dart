/// TaxManager extensions - Business methods beyond generated CRUD
library;

import '../../models/taxes/tax.model.dart';

/// Extension methods for TaxManager
extension TaxManagerBusiness on TaxManager {
  /// Get all active sale taxes
  Future<List<Tax>> getActiveSaleTaxes() async {
    return searchLocal(domain: [
      ['active', '=', true],
      ['type_tax_use', '=', 'sale'],
    ]);
  }

  /// Get all active purchase taxes
  Future<List<Tax>> getActivePurchaseTaxes() async {
    return searchLocal(domain: [
      ['active', '=', true],
      ['type_tax_use', '=', 'purchase'],
    ]);
  }

  /// Get tax by Odoo ID
  Future<Tax?> getById(int odooId) => readLocal(odooId);
}
