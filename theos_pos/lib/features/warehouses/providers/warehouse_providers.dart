import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

/// Reactive stream of all warehouses from local DB.
///
/// Uses `warehouseManager.watchLocalSearch()` so UI auto-updates
/// when warehouses are synced, created, or modified locally.
final warehousesProvider = StreamProvider<List<Warehouse>>((ref) {
  return warehouseManager.watchLocalSearch();
});
