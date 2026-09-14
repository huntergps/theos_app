import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/auth/auth_controller.dart';
import '../features/envases/envases_existencias_contracts.dart';
import '../features/envases/envases_existencias_screen.dart';
import 'notification_scope_adapter.dart';
import 'session_composition.dart';

/// ENV-01 (Existencias de envases) composition: the screen never touches
/// `RuntimeDatabaseOwner`, `EnvasesExistenciasCache` or an `OdooClient`
/// itself, same boundary discipline as every other scoped screen wired
/// through this package (see `warehouse_existences_composition.dart`, the
/// closest sibling — the cache backing this provider is deliberately shaped
/// like `StockQuantCache`).
///
/// `readerFactory` is a factory, not a stored reader: a fresh reader must be
/// built for every refresh, so the cache always rejects one captured before
/// a session/company change, and the client can legitimately be absent
/// (offline) at refresh time — `refresh()` then fails explicitly and the
/// screen surfaces that as its own retryable error state, never a silent
/// `reader = null`.
///
/// A `null` result means "nothing to show yet" (no active session, no
/// resolved company, or the `envases_read` permission is absent) — the
/// route renders [NotConfiguredPage] in that case rather than a broken
/// screen.
final envasesExistenciasRepositoryProvider =
    Provider.autoDispose<EnvasesExistenciasRepository?>((ref) {
      final runtime = ref.watch(runtimeSessionProvider);
      final capabilities = ref.watch(capabilitySnapshotProvider);
      final active = runtime?.active;
      if (runtime == null ||
          active == null ||
          capabilities == null ||
          capabilities.scopeKey != active.scope.scopeKey ||
          capabilities.companyId <= 0 ||
          !capabilities.permissions.contains('envases_read')) {
        return null;
      }
      final company = CompanyContext.forScope(
        scope: active.scope,
        companyId: capabilities.companyId,
        allowedCompanyIds: [capabilities.companyId],
        capabilityRevision: capabilities.revision,
      );
      return RuntimeEnvasesExistenciasRepository(
        cache: EnvasesExistenciasCache(
          owner: runtime.databaseOwner,
          lease: active.lease,
          company: company,
        ),
        readerFactory: () {
          final client = runtime.active?.client;
          if (client == null) {
            throw StateError(
              'No hay conexión activa para actualizar existencias de envases',
            );
          }
          return EnvasesExistenciasReader.fromClient(
            client: client,
            company: company,
          );
        },
      );
    });

/// Composition route: capability/session absence is explicit, while the
/// screen itself remains a read-only cached surface.
final class EnvasesExistenciasRoute extends ConsumerWidget {
  const EnvasesExistenciasRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repository = ref.watch(envasesExistenciasRepositoryProvider);
    if (repository == null) {
      return const NotConfiguredPage(
        title: 'Envases',
        detail: 'No tienes permiso para consultar existencias de envases.',
      );
    }
    final active = ref.watch(runtimeSessionProvider)?.active;
    return EnvasesExistenciasScreen(
      key: ValueKey(
        '${active?.scope.scopeKey}:${active?.lease.generation}:${ref.read(capabilitySnapshotProvider)?.companyId}',
      ),
      repository: repository,
    );
  }
}
