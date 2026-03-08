/// BankManager extensions - Business methods beyond generated CRUD
///
/// The base BankManager and PartnerBankManager are generated
/// in bank.model.g.dart. This file adds business-specific query methods.
library;

import '../../models/banks/bank.model.dart';

/// Extension methods for BankManager
extension BankManagerBusiness on BankManager {
  /// Get a bank by Odoo ID (alias for readLocal)
  Future<Bank?> getById(int odooId) => readLocal(odooId);

  /// Get all active banks
  Future<List<Bank>> getActiveBanks() async {
    return searchLocal(domain: [
      ['active', '=', true],
    ]);
  }

  /// Search banks by name or BIC
  Future<List<Bank>> searchBanks(String query, {int limit = 50}) async {
    if (query.trim().isEmpty) return [];
    return searchLocal(
      domain: [
        ['active', '=', true],
        '|',
        ['name', 'ilike', query],
        ['bic', 'ilike', query],
      ],
      limit: limit,
    );
  }
}

/// Extension methods for PartnerBankManager
extension PartnerBankManagerBusiness on PartnerBankManager {
  /// Get partner bank accounts by partner ID
  Future<List<PartnerBank>> getByPartnerId(int partnerId) async {
    return searchLocal(domain: [
      ['partner_id', '=', partnerId],
    ]);
  }

  /// Get partner bank by account number
  Future<PartnerBank?> getByAccountNumber(String accNumber) async {
    if (accNumber.trim().isEmpty) return null;
    final results = await searchLocal(
      domain: [
        ['acc_number', '=', accNumber.trim()],
      ],
      limit: 1,
    );
    return results.firstOrNull;
  }
}
