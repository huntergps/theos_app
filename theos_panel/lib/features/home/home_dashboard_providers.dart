import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show SessionRuntime;

import '../../app/notification_scope_adapter.dart' show runtimeSessionProvider;
import '../auth/auth_controller.dart' show authControllerProvider, capabilitySnapshotProvider;
import '../sync/sync_center.dart' show syncCenterPortProvider;
import 'home_dashboard_contracts.dart';

final homeSalesMetricsReaderProvider = Provider<HomeSalesMetricsReader?>((
  ref,
) {
  final sessions = ref.watch(runtimeSessionProvider);
  return sessions == null ? null : _RuntimeHomeSalesMetricsReader(sessions);
});

final homeCashSessionsReaderProvider = Provider<HomeCashSessionsReader?>((
  ref,
) {
  final sessions = ref.watch(runtimeSessionProvider);
  return sessions == null ? null : _RuntimeHomeCashSessionsReader(sessions);
});

/// Cambia cuando termina un drenaje real (`SyncSnapshot.lastCompletedAt`), lo
/// que hace que los indicadores se vuelvan a leer después de sincronizar en
/// vez de quedarse mostrando la cifra de antes del sync.
final homeSyncTickProvider = StreamProvider.autoDispose<DateTime?>((ref) {
  final port = ref.watch(syncCenterPortProvider);
  return port.snapshots
      .map((snapshot) => snapshot.sync.lastCompletedAt)
      .distinct();
});

final homeSalesMetricsProvider = FutureProvider.autoDispose<HomeSalesSummary?>(
  (ref) async {
    ref.watch(homeSyncTickProvider);
    final capabilities = ref.watch(capabilitySnapshotProvider);
    if (capabilities == null || !capabilities.permissions.contains('seller')) {
      return null;
    }
    final reader = ref.watch(homeSalesMetricsReaderProvider);
    final profile = ref.watch(authControllerProvider).profile;
    if (reader == null || profile == null) return null;
    return reader.loadToday(
      companyId: capabilities.companyId,
      userId: profile.userId,
      viewAll: capabilities.permissions.contains('orders.view_all'),
    );
  },
);

final homeCashSessionsProvider =
    FutureProvider.autoDispose<List<HomeCashSession>?>((ref) async {
      ref.watch(homeSyncTickProvider);
      final capabilities = ref.watch(capabilitySnapshotProvider);
      if (capabilities == null ||
          !capabilities.permissions.contains('cashier')) {
        return null;
      }
      final reader = ref.watch(homeCashSessionsReaderProvider);
      if (reader == null) return null;
      return reader.loadActive(companyId: capabilities.companyId);
    });

/// Resumen del propio turno de caja: sólo las sesiones cuyo `cashierUserId`
/// es el de la persona autenticada, nunca las de otro cajero.
final class HomeMyCashSummary {
  const HomeMyCashSummary({required this.paymentCount, required this.totalAmount});
  final int paymentCount;
  final double totalAmount;
}

/// Nulo cuando la persona no tiene un turno de caja propio abierto ahora
/// mismo — igual que el resto de tarjetas de Inicio, sin turno no se rellena
/// con un cero fabricado.
final homeMyCashSummaryProvider = FutureProvider.autoDispose<HomeMyCashSummary?>(
  (ref) async {
    final sessions = await ref.watch(homeCashSessionsProvider.future);
    if (sessions == null) return null;
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) return null;
    final mine = sessions.where(
      (session) => session.cashierUserId == profile.userId,
    );
    if (mine.isEmpty) return null;
    final paymentCount = mine.fold<int>(0, (total, s) => total + s.paymentCount);
    final totalAmount = mine.fold<double>(
      0,
      (total, s) => total + s.totalPaymentsAmount,
    );
    return HomeMyCashSummary(paymentCount: paymentCount, totalAmount: totalAmount);
  },
);

final class _RuntimeHomeSalesMetricsReader implements HomeSalesMetricsReader {
  _RuntimeHomeSalesMetricsReader(this.sessions);
  final SessionRuntime sessions;

  @override
  Future<HomeSalesSummary> loadToday({
    required int companyId,
    required int userId,
    required bool viewAll,
  }) async {
    final active = sessions.active;
    if (active == null) return const HomeSalesSummary();
    final lease = active.lease;
    final db = active.database.database;
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    var predicate =
        db.saleOrder.companyId.equals(companyId) &
        db.saleOrder.dateOrder.isBiggerOrEqualValue(startOfDay) &
        db.saleOrder.dateOrder.isSmallerThanValue(endOfDay);
    if (!viewAll) predicate = predicate & db.saleOrder.userId.equals(userId);
    final countExpr = db.saleOrder.id.count();
    final amountExpr = db.saleOrder.amountTotal.sum();
    final rows = await (db.selectOnly(db.saleOrder)
          ..addColumns([db.saleOrder.state, countExpr, amountExpr])
          ..where(predicate)
          ..groupBy([db.saleOrder.state]))
        .get();
    if (!sessions.accepts(lease)) return const HomeSalesSummary();
    var totalOrders = 0;
    var totalAmount = 0.0;
    var draftCount = 0;
    var confirmedCount = 0;
    var doneCount = 0;
    for (final row in rows) {
      final count = row.read(countExpr) ?? 0;
      final amount = row.read(amountExpr) ?? 0.0;
      totalOrders += count;
      totalAmount += amount;
      switch (row.read(db.saleOrder.state)) {
        case 'draft':
          draftCount += count;
        case 'sale':
          confirmedCount += count;
        case 'done':
          doneCount += count;
      }
    }
    return HomeSalesSummary(
      totalAmount: totalAmount,
      totalOrders: totalOrders,
      draftCount: draftCount,
      confirmedCount: confirmedCount,
      doneCount: doneCount,
    );
  }
}

final class _RuntimeHomeCashSessionsReader implements HomeCashSessionsReader {
  _RuntimeHomeCashSessionsReader(this.sessions);
  final SessionRuntime sessions;

  @override
  Future<List<HomeCashSession>> loadActive({required int companyId}) async {
    final active = sessions.active;
    if (active == null) return const [];
    final lease = active.lease;
    final db = active.database.database;
    final rows =
        await (db.select(db.collectionSession)
              ..where(
                (row) =>
                    row.companyId.equals(companyId) &
                    row.state.isNotIn(const ['closed']),
              )
              ..orderBy([(row) => OrderingTerm.desc(row.startAt)]))
            .get();
    if (!sessions.accepts(lease)) return const [];
    return [
      for (final row in rows)
        HomeCashSession(
          id: '${row.odooId}',
          name: row.name,
          configName: row.configName,
          cashierUserId: row.userId,
          cashierName: row.userName,
          startAt: row.startAt,
          stateCode: row.state,
          paymentCount: row.paymentCount,
          totalPaymentsAmount: row.totalPaymentsAmount,
        ),
    ];
  }
}
