import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../core/database/repositories/repository_providers.dart';
import '../constants/user_groups.dart';
import 'user_provider.dart';

part 'credit_approval_provider.g.dart';

/// Devuelve true si el usuario actual es supervisor
@riverpod
bool isSupervisorUser(Ref ref) {
  final user = ref.watch(userProvider);
  final permissions = user?.permissions ?? [];
  return kSupervisorGroups.any((g) => permissions.contains(g));
}

/// Stream de órdenes en estado waitingApproval.
///
/// Usa Drift .watch() para actualizarse automáticamente cuando llega
/// una nueva orden vía WebSocket o sync.
@Riverpod(keepAlive: true)
Stream<List<SaleOrder>> pendingApprovalOrdersStream(Ref ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value([]);

  return saleOrderManager.watchLocalSearch(
    domain: [
      ['state', '=', 'waiting'],
    ],
    orderBy: 'date_order desc',
  );
}

/// Conteo reactivo de órdenes pendientes de aprobación.
///
/// Solo devuelve un valor > 0 cuando el usuario es supervisor.
/// Úsalo para el badge en el NavigationPane.
@riverpod
int pendingApprovalCount(Ref ref) {
  final isSupervisor = ref.watch(isSupervisorUserProvider);
  if (!isSupervisor) return 0;

  final ordersAsync = ref.watch(pendingApprovalOrdersStreamProvider);
  return ordersAsync.when(
    data: (orders) => orders.length,
    loading: () => 0,
    error: (_, _) => 0,
  );
}

/// Lista de órdenes pendientes de aprobación (solo para supervisores).
///
/// Devuelve lista vacía si el usuario no es supervisor.
@riverpod
List<SaleOrder> pendingApprovalOrders(Ref ref) {
  final isSupervisor = ref.watch(isSupervisorUserProvider);
  if (!isSupervisor) return [];

  final ordersAsync = ref.watch(pendingApprovalOrdersStreamProvider);
  return ordersAsync.when(
    data: (orders) => orders,
    loading: () => [],
    error: (_, _) => [],
  );
}
