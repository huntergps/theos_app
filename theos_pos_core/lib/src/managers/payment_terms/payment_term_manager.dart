/// PaymentTermManager extensions - Business methods beyond generated CRUD
///
/// The base PaymentTermManager is generated in payment_term.model.g.dart.
/// This file adds business-specific query methods.
library;

import '../../models/payment_terms/payment_term.model.dart';

/// Extension methods for PaymentTermManager
extension PaymentTermManagerBusiness on PaymentTermManager {
  /// Get all cash payment terms
  Future<List<PaymentTerm>> getCashTerms() async {
    return searchLocal(domain: [
      ['is_cash', '=', true],
      ['active', '=', true],
    ]);
  }

  /// Get all credit payment terms
  Future<List<PaymentTerm>> getCreditTerms() async {
    return searchLocal(domain: [
      ['is_credit', '=', true],
      ['active', '=', true],
    ]);
  }
}
