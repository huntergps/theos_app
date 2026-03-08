import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

// ═══════════════════════════════════════════════════════════════════════════
// PricelistItemManager Singleton
// ═══════════════════════════════════════════════════════════════════════════

/// Lazy singleton for PricelistItemManager.
///
/// PricelistItemManager is not @OdooModel-generated (no global singleton in
/// theos_pos_core). We create one here, initialized with the app database.
/// This avoids creating a new instance on every provider rebuild.
PricelistItemManager? _pricelistItemManagerInstance;

// ═══════════════════════════════════════════════════════════════════════════
// Pricelist Providers (StreamProvider — reactive via Drift)
// ═══════════════════════════════════════════════════════════════════════════

/// Reactive stream of all active pricelists from local DB.
///
/// Uses `pricelistManager.watchLocalSearch()` so UI auto-updates
/// when pricelists are synced, created, or modified locally.
final pricelistsProvider = StreamProvider<List<Pricelist>>((ref) {
  return pricelistManager.watchLocalSearch(
    domain: [['active', '=', true]],
    orderBy: 'sequence asc',
  );
});

/// Reactive stream of a pricelist by ID from local DB.
///
/// Uses `pricelistManager.watchLocalRecord(id)` so UI auto-updates
/// when the pricelist is modified or synced locally.
final pricelistByIdProvider = StreamProvider.family<Pricelist?, int>((ref, pricelistId) {
  return pricelistManager.watchLocalRecord(pricelistId);
});

/// Get a pricelist name from cache. Derives from the pricelists stream.
final pricelistNameProvider = Provider.family<String, int?>((ref, pricelistId) {
  if (pricelistId == null) return '';
  final pricelists = ref.watch(pricelistsProvider);
  return pricelists.when(
    data: (list) {
      final found = list.where((p) => p.id == pricelistId);
      return found.isNotEmpty ? found.first.name : '';
    },
    loading: () => '...',
    error: (_, _) => '',
  );
});

/// Default pricelist (first in the list). Derives from the pricelists stream.
final defaultPricelistProvider = Provider<Pricelist?>((ref) {
  final pricelists = ref.watch(pricelistsProvider);
  return pricelists.when(
    data: (list) => list.isNotEmpty ? list.first : null,
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Reactive stream of pricelist items for a given pricelist ID.
///
/// Uses a lazy singleton PricelistItemManager with `watchLocalSearch()`
/// so the UI auto-updates when pricelist items are synced or modified.
final pricelistItemsProvider = StreamProvider.family<List<PricelistItem>, int>((ref, pricelistId) {
  _pricelistItemManagerInstance ??= PricelistItemManager(ref.read(appDatabaseProvider));
  return _pricelistItemManagerInstance!.watchLocalSearch(
    domain: [['pricelist_id', '=', pricelistId]],
  );
});
