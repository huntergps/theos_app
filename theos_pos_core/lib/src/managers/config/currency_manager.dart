/// CurrencyManager extensions - Business methods beyond generated CRUD
///
/// The base CurrencyManager and DecimalPrecisionManager are generated
/// in currency.model.g.dart. This file adds business-specific query methods.
library;

import '../../models/config/currency.model.dart';

/// Extension methods for CurrencyManager
extension CurrencyManagerBusiness on CurrencyManager {
  /// Get a currency by Odoo ID (alias for readLocal)
  Future<Currency?> getById(int odooId) => readLocal(odooId);

  /// Get all active currencies
  Future<List<Currency>> getActiveCurrencies() async {
    return searchLocal(domain: [['active', '=', true]]);
  }

  /// Search currencies by name or symbol
  Future<List<Currency>> searchCurrencies(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];
    return searchLocal(
      domain: [
        ['active', '=', true],
        '|',
        ['name', 'ilike', query],
        ['symbol', 'ilike', query],
      ],
      limit: limit,
    );
  }
}

/// Extension methods for DecimalPrecisionManager
extension DecimalPrecisionManagerBusiness on DecimalPrecisionManager {
  /// Get precision by name
  Future<DecimalPrecision?> getByName(String name) async {
    final results = await searchLocal(domain: [['name', '=', name]], limit: 1);
    return results.firstOrNull;
  }

  /// Get all decimal precisions
  Future<List<DecimalPrecision>> getAll() async => searchLocal();
}
