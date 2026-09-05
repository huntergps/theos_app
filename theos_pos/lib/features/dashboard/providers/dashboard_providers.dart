/// Dashboard providers — derived metrics for SupervisorDashboard
///
/// All data comes from Drift local DB via existing stream providers.
/// No Odoo API calls are made here.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show SaleOrderManagerBusiness, SaleOrderPeriodMetrics, saleOrderManager;

import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../../../features/sync/providers/sync_provider.dart';

// ============================================================================
// DATA CLASSES
// ============================================================================

/// Conteos de ordenes agrupados por estado para el dia actual
class DailySaleMetrics {
  final int totalOrders;
  final double totalAmount;
  final int draftCount;
  final int confirmedCount;
  final int doneCount;
  final int cancelledCount;

  const DailySaleMetrics({
    this.totalOrders = 0,
    this.totalAmount = 0.0,
    this.draftCount = 0,
    this.confirmedCount = 0,
    this.doneCount = 0,
    this.cancelledCount = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DailySaleMetrics &&
          totalOrders == other.totalOrders &&
          totalAmount == other.totalAmount &&
          draftCount == other.draftCount &&
          confirmedCount == other.confirmedCount &&
          doneCount == other.doneCount &&
          cancelledCount == other.cancelledCount;

  @override
  int get hashCode => Object.hash(
    totalOrders,
    totalAmount,
    draftCount,
    confirmedCount,
    doneCount,
    cancelledCount,
  );
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Metricas de ventas del dia derivadas mediante un agregado SQL reactivo.
///
/// El rango se calcula en la zona horaria local y se expresa como intervalo
/// semiabierto para no contar dos veces una orden exactamente a medianoche.
final dailySaleMetricsProvider = StreamProvider.autoDispose<DailySaleMetrics>((
  ref,
) {
  ref.watch(appDatabaseProvider);
  final now = DateTime.now();
  final startOfDay = DateTime(now.year, now.month, now.day);
  final endOfDay = DateTime(now.year, now.month, now.day + 1);
  final dayRollover = Timer(endOfDay.difference(now), ref.invalidateSelf);
  ref.onDispose(dayRollover.cancel);

  return saleOrderManager
      .watchPeriodMetrics(startInclusive: startOfDay, endExclusive: endOfDay)
      .map(_toDailySaleMetrics)
      .distinct();
});

DailySaleMetrics _toDailySaleMetrics(SaleOrderPeriodMetrics metrics) {
  return DailySaleMetrics(
    totalOrders: metrics.totalOrders,
    totalAmount: metrics.totalAmount,
    draftCount: metrics.draftCount,
    confirmedCount: metrics.confirmedCount,
    doneCount: metrics.doneCount,
    cancelledCount: metrics.cancelledCount,
  );
}

/// Ultimo sync exitoso — fecha del item de sync mas reciente con estado success.
final lastSuccessfulSyncProvider = Provider<DateTime?>((ref) {
  // Sync progress and global flags change frequently while itemStates often
  // retain the same map. Selecting only this field prevents an O(n) scan of
  // all sync items for unrelated progress ticks.
  final itemStates = ref.watch(
    syncProvider.select((state) => state.itemStates),
  );

  DateTime? latest;
  for (final itemState in itemStates.values) {
    if (itemState.status == SyncStatus.success &&
        itemState.lastSyncDate != null) {
      if (latest == null || itemState.lastSyncDate!.isAfter(latest)) {
        latest = itemState.lastSyncDate;
      }
    }
  }
  return latest;
});
