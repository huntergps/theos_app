/// Dashboard providers — derived metrics for SupervisorDashboard
///
/// All data comes from Drift local DB via existing stream providers.
/// No Odoo API calls are made here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show CollectionSession, SaleOrderState, SessionState;

import '../../../core/database/providers.dart'
    show activeSessionsProvider, saleOrdersStreamProvider;
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
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Metricas de ventas del dia derivadas de Drift local.
/// Reactivo via saleOrdersStreamProvider.
final dailySaleMetricsProvider = Provider<DailySaleMetrics>((ref) {
  final ordersAsync = ref.watch(saleOrdersStreamProvider);
  return ordersAsync.when(
    data: (orders) {
      final now = DateTime.now();
      final startOfDay = DateTime(now.year, now.month, now.day);

      final todayOrders = orders.where((o) {
        final orderDate = o.dateOrder;
        if (orderDate == null) return false;
        return orderDate.isAfter(startOfDay) ||
            orderDate.isAtSameMomentAs(startOfDay);
      }).toList();

      int draftCount = 0;
      int confirmedCount = 0;
      int doneCount = 0;
      int cancelledCount = 0;
      double totalAmount = 0.0;

      for (final order in todayOrders) {
        switch (order.state) {
          case SaleOrderState.draft:
          case SaleOrderState.sent:
          case SaleOrderState.waitingApproval:
          case SaleOrderState.approved:
          case SaleOrderState.rejected:
            draftCount++;
          case SaleOrderState.sale:
            confirmedCount++;
            totalAmount += order.amountTotal;
          case SaleOrderState.done:
            doneCount++;
            totalAmount += order.amountTotal;
          case SaleOrderState.cancel:
            cancelledCount++;
        }
      }

      return DailySaleMetrics(
        totalOrders: todayOrders.length,
        totalAmount: totalAmount,
        draftCount: draftCount,
        confirmedCount: confirmedCount,
        doneCount: doneCount,
        cancelledCount: cancelledCount,
      );
    },
    loading: () => const DailySaleMetrics(),
    error: (_, _) => const DailySaleMetrics(),
  );
});

// ============================================================================
// SESIONES ACTIVAS
// ============================================================================

/// Resumen de una sesion de caja activa
class ActiveSessionSummary {
  final bool hasActiveSession;
  final String? configName;
  final SessionState? sessionState;
  final String? userName;

  const ActiveSessionSummary({
    this.hasActiveSession = false,
    this.configName,
    this.sessionState,
    this.userName,
  });
}

/// Resumen de la sesion de caja activa para el dashboard.
/// Reactivo via activeSessionsProvider.
final activeSessionSummaryProvider = Provider<ActiveSessionSummary>((ref) {
  final sessionsAsync = ref.watch(activeSessionsProvider);
  return sessionsAsync.when(
    data: (sessions) {
      final active =
          sessions.where((s) => s.state != SessionState.closed).toList();

      if (active.isEmpty) {
        return const ActiveSessionSummary(hasActiveSession: false);
      }

      final session = active.first;
      return ActiveSessionSummary(
        hasActiveSession: true,
        configName: session.configName,
        sessionState: session.state,
        userName: session.userName,
      );
    },
    loading: () => const ActiveSessionSummary(),
    error: (_, _) => const ActiveSessionSummary(),
  );
});

/// Todas las sesiones activas para el dashboard multi-sesion del supervisor.
final allActiveSessionsProvider = Provider<List<CollectionSession>>((ref) {
  final sessionsAsync = ref.watch(activeSessionsProvider);
  return sessionsAsync.when(
    data: (sessions) =>
        sessions.where((s) => s.state != SessionState.closed).toList(),
    loading: () => [],
    error: (_, _) => [],
  );
});

/// Ultimo sync exitoso — fecha del item de sync mas reciente con estado success.
final lastSuccessfulSyncProvider = Provider<DateTime?>((ref) {
  final syncState = ref.watch(syncProvider);

  DateTime? latest;
  for (final itemState in syncState.itemStates.values) {
    if (itemState.status == SyncStatus.success &&
        itemState.lastSyncDate != null) {
      if (latest == null || itemState.lastSyncDate!.isAfter(latest)) {
        latest = itemState.lastSyncDate;
      }
    }
  }
  return latest;
});
