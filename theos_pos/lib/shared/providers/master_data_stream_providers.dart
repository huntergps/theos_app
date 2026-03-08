import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        Warehouse,
        warehouseManager,
        Pricelist,
        pricelistManager,
        PaymentTerm,
        paymentTermManager,
        User,
        userManager;

/// Stream providers for master data tables
/// These providers automatically emit when data changes in SQLite
///
/// NOTE: These use manual StreamProvider (not @riverpod) because
/// ReactiveMasterSelector expects `StreamProvider<List<T>>` explicitly.
///
/// All providers use domain models from theos_pos_core via
/// OdooModelManager.watchLocalSearch() for reactive Drift streams.

// ============================================================================
// WAREHOUSES
// ============================================================================

/// Stream of all warehouses
final warehousesStreamProvider = StreamProvider<List<Warehouse>>((ref) {
  return warehouseManager.watchLocalSearch();
});

/// Single warehouse by ID
final warehouseStreamProvider =
    StreamProvider.family<Warehouse?, int>((ref, id) {
  return warehouseManager.watchLocalRecord(id);
});

// ============================================================================
// PRICELISTS
// ============================================================================

/// Stream of all active pricelists
final pricelistsStreamProvider = StreamProvider<List<Pricelist>>((ref) {
  return pricelistManager.watchLocalSearch(
    domain: [
      ['active', '=', true],
    ],
    orderBy: 'sequence asc',
  );
});

/// Single pricelist by ID
final pricelistStreamProvider =
    StreamProvider.family<Pricelist?, int>((ref, id) {
  return pricelistManager.watchLocalRecord(id);
});

// ============================================================================
// PAYMENT TERMS
// ============================================================================

/// Stream of all active payment terms
final paymentTermsStreamProvider = StreamProvider<List<PaymentTerm>>((ref) {
  return paymentTermManager.watchLocalSearch(
    domain: [
      ['active', '=', true],
    ],
  );
});

// ============================================================================
// SALESPEOPLE (Users)
// ============================================================================

/// Stream of all salespeople (users)
final salespeopleStreamProvider = StreamProvider<List<User>>((ref) {
  return userManager.watchLocalSearch();
});
