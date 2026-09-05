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
/// una nueva orden vía sincronización.
@Riverpod(keepAlive: true)
Stream<List<SaleOrder>> pendingApprovalOrdersStream(Ref ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value([]);

  return saleOrderManager.watchLocalSearch(
    domain: [
      ['state', '=', 'waiting'],
    ],
    orderBy: 'date_order desc',
    limit: 200,
  );
}

/// Conteo SQL reactivo sin cargar todas las órdenes pendientes en memoria.
@Riverpod(keepAlive: true)
Stream<int> pendingApprovalCountStream(Ref ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value(0);
  return saleOrderManager.watchStateCount('waiting');
}

/// Conteo reactivo de órdenes pendientes de aprobación.
///
/// Solo devuelve un valor > 0 cuando el usuario es supervisor.
/// Úsalo para el badge en el NavigationPane.
@riverpod
AsyncValue<int> pendingApprovalCount(Ref ref) {
  final isSupervisor = ref.watch(isSupervisorUserProvider);
  if (!isSupervisor) return const AsyncValue.data(0);

  return ref.watch(pendingApprovalCountStreamProvider);
}

/// Lista de órdenes pendientes de aprobación (solo para supervisores).
///
/// Devuelve lista vacía si el usuario no es supervisor.
@riverpod
AsyncValue<List<SaleOrder>> pendingApprovalOrders(Ref ref) {
  final isSupervisor = ref.watch(isSupervisorUserProvider);
  if (!isSupervisor) return const AsyncValue.data([]);

  return ref.watch(pendingApprovalOrdersStreamProvider);
}
