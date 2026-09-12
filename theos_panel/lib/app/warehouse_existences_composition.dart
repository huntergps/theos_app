import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/auth/auth_controller.dart';
import '../features/warehouse/warehouse_existences_contracts.dart';
import 'notification_scope_adapter.dart';

/// BOD-01 (inventario de existencias) composition: the screen never touches
/// `RuntimeDatabaseOwner`, `StockQuantCache` or an `OdooClient` itself, same
/// boundary discipline as every other scoped screen wired through this
/// package (see `envases_composition.dart`, the closest sibling — the cache
/// backing this provider is deliberately shaped like
/// `EnvasesDashboardCache`).
///
/// A `null` result means "nothing to show yet" (no active session, no
/// resolved company, or the `warehouse` capability is absent) — the route
/// renders [NotConfiguredPage] in that case rather than a broken screen.
final warehouseExistencesRepositoryProvider =
    Provider.autoDispose<WarehouseExistencesRepository?>((ref) {
      final runtime = ref.watch(runtimeSessionProvider);
      final capabilities = ref.watch(capabilitySnapshotProvider);
      final active = runtime?.active;
      if (runtime == null ||
          active == null ||
          capabilities == null ||
          capabilities.scopeKey != active.scope.scopeKey ||
          capabilities.companyId <= 0 ||
          !capabilities.permissions.contains('warehouse')) {
        return null;
      }
      final company = CompanyContext.forScope(
        scope: active.scope,
        companyId: capabilities.companyId,
        allowedCompanyIds: [capabilities.companyId],
        capabilityRevision: capabilities.revision,
      );
      return RuntimeWarehouseExistencesRepository(
        cache: StockQuantCache(
          owner: runtime.databaseOwner,
          lease: active.lease,
          company: company,
        ),
        // A fresh reader per refresh, never a captured one: the cache
        // rejects a reader built before a session/company change, and the
        // client can legitimately be absent (offline) at refresh time —
        // `refresh()` then fails and the screen surfaces that as its own
        // retryable error state, never a crash.
        readerFactory: () {
          final client = runtime.active?.client;
          if (client == null) {
            throw StateError(
              'No hay conexión activa para actualizar existencias',
            );
          }
          return StockQuantReader.fromClient(client: client, company: company);
        },
      );
    });
