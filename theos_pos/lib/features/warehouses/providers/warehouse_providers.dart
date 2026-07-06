import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

/// Reactive stream of all warehouses from local DB.
///
/// Uses `warehouseManager.watchLocalSearch()` so UI auto-updates
/// when warehouses are synced, created, or modified locally.
final warehousesProvider = StreamProvider<List<Warehouse>>((ref) {
  return warehouseManager.watchLocalSearch();
});

/// Reactive stream of a warehouse by ID from local DB.
///
/// Uses `warehouseManager.watchLocalRecord(id)` so UI auto-updates
/// when the warehouse is modified or synced locally.
///
/// `autoDispose`: es `.family` por `warehouseId` transitorio (memory leak
/// corregido). Verificado: sin consumidores en todo el codebase hoy — cero
/// riesgo de romper algo.
final warehouseByIdProvider = StreamProvider.autoDispose.family<Warehouse?, int>((ref, warehouseId) {
  return warehouseManager.watchLocalRecord(warehouseId);
});

/// Get a warehouse name from cache. Derives from the warehouses stream.
///
/// `autoDispose`: es `.family` por `warehouseId` transitorio (memory leak
/// corregido). Verificado: sin consumidores en todo el codebase hoy.
final warehouseNameProvider = Provider.autoDispose.family<String, int?>((ref, warehouseId) {
  if (warehouseId == null) return '';
  final warehouses = ref.watch(warehousesProvider);
  return warehouses.when(
    data: (list) =>
        list.firstWhere((w) => w.id == warehouseId, orElse: () => list.first).name,
    loading: () => '...',
    error: (_, _) => '',
  );
});

/// Reactive stream of the current user's warehouse.
///
/// Watches the current user to get the warehouse ID, then watches
/// the warehouse record from the local DB.
final currentWarehouseProvider = StreamProvider<Warehouse?>((ref) async* {
  final currentUser = await userManager.getCurrentUser();

  if (currentUser?.warehouseId == null) {
    yield null;
    return;
  }

  yield* warehouseManager.watchLocalRecord(currentUser!.warehouseId!);
});
