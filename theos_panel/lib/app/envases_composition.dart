import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/auth/auth_controller.dart';
import '../features/envases/envases_enviar_form.dart';
import '../features/envases/envases_existencias_contracts.dart';
import '../features/envases/envases_existencias_screen.dart';
import '../features/envases/envases_form_draft_port.dart';
import '../features/envases/envases_movimientos_screen.dart';
import '../features/envases/envases_por_recibir_screen.dart';
import '../features/envases/envases_recibir_form.dart';
import '../features/envases/envases_saldo_terceros_screen.dart';
import '../features/envases/envases_traslado_detalle.dart';
import 'notification_scope_adapter.dart';
import 'session_composition.dart';

// ---------------------------------------------------------------------
// Borradores de los formularios de envío y recepción.
// ---------------------------------------------------------------------

/// `null` sólo por convención con las demás factorías de este archivo: en la
/// práctica nunca hace falta comprobarlo, porque `UnavailableEnvasesFormDraftPort`
/// no hace nada y nunca lanza — sin sesión/empresa activa los formularios
/// simplemente quedan sin persistencia durable, igual que antes de que este
/// puerto existiera.
final envasesFormDraftPortProvider = Provider.autoDispose<EnvasesFormDraftPort>(
  (ref) {
    final runtime = ref.watch(runtimeSessionProvider);
    final capabilities = ref.watch(capabilitySnapshotProvider);
    final active = runtime?.active;
    if (runtime == null ||
        active == null ||
        capabilities == null ||
        capabilities.scopeKey != active.scope.scopeKey ||
        capabilities.companyId <= 0) {
      return const UnavailableEnvasesFormDraftPort();
    }
    final company = CompanyContext.forScope(
      scope: active.scope,
      companyId: capabilities.companyId,
      allowedCompanyIds: [capabilities.companyId],
      capabilityRevision: capabilities.revision,
    );
    return DurableEnvasesFormDraftPort(
      store: EditableDraftStore(
        owner: runtime.databaseOwner,
        lease: active.lease,
        company: company,
      ),
    );
  },
);

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

// ---------------------------------------------------------------------
// Escritura: EnvasesOperations y el permiso de gerencia.
// ---------------------------------------------------------------------

/// `DurableEnvasesOperations` real. Igual que `envasesExistenciasRepositoryProvider`,
/// `null` sólo por ausencia de sesión/compañía/permiso — pero a diferencia de
/// los lectores, funciona sin conexión: `actions` puede ser la variante que
/// siempre falla (`_UnavailableEnvasesActions`), porque
/// `DurableEnvasesOperations` ya trata ese fallo como señal de "sin
/// `envases_operacion_uuid` confirmado todavía" y cae a
/// `manualAfterAmbiguous` — guardar en local y encolar sigue funcionando
/// (decisión E01: «todo debe funcionar offline»).
final envasesOperationsProvider = Provider.autoDispose<EnvasesOperations?>((
  ref,
) {
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
  final client = active.client;
  return DurableEnvasesOperations(
    owner: runtime.databaseOwner,
    lease: active.lease,
    company: company,
    actions: client == null
        ? const _UnavailableEnvasesActions()
        : OdooClientSaleActions(client),
  );
});

/// «Dar por perdido» es sólo de gerencia (`group_envases_manager`) — decidido
/// aquí, nunca en la pantalla, para que el detalle sólo reciba un booleano ya
/// resuelto (ver docstring de `EnvasesTrasladoDetalle`).
final envasesCanManageProvider = Provider.autoDispose<bool>(
  (ref) =>
      ref.watch(capabilitySnapshotProvider)?.permissions.contains(
        'envases_manage',
      ) ??
      false,
);

final class _UnavailableEnvasesActions implements SaleOdooActions {
  const _UnavailableEnvasesActions();

  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) => Future.error(StateError('acciones Odoo no disponibles sin conexión'));
}

// ---------------------------------------------------------------------
// Por recibir
// ---------------------------------------------------------------------

final class _EnvasesPorRecibirController {
  const _EnvasesPorRecibirController({
    required this.cache,
    required this.readerFactory,
  });

  final EnvasesPorRecibirCache cache;
  final EnvasesPorRecibirReader Function() readerFactory;

  Stream<EnvasesPorRecibirSnapshot?> get snapshots => cache.watch();
  Future<void> refresh() => cache.refresh(readerFactory());
}

final envasesPorRecibirControllerProvider =
    Provider.autoDispose<_EnvasesPorRecibirController?>((ref) {
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
      return _EnvasesPorRecibirController(
        cache: EnvasesPorRecibirCache(
          owner: runtime.databaseOwner,
          lease: active.lease,
          company: company,
        ),
        readerFactory: () {
          final client = runtime.active?.client;
          if (client == null) {
            throw StateError(
              'No hay conexión activa para actualizar los envases por recibir',
            );
          }
          return EnvasesPorRecibirReader.fromClient(
            client: client,
            company: company,
          );
        },
      );
    });

final class EnvasesPorRecibirRoute extends ConsumerWidget {
  const EnvasesPorRecibirRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(envasesPorRecibirControllerProvider);
    final operations = ref.watch(envasesOperationsProvider);
    if (controller == null || operations == null) {
      return const NotConfiguredPage(
        title: 'Envases',
        detail: 'No tienes permiso para consultar los envases por recibir.',
      );
    }
    return EnvasesPorRecibirScreen(
      snapshots: controller.snapshots,
      operaciones: operations.watchOperaciones(),
      onOpenDetail: (row) =>
          context.push('/envases/por-recibir/${row.id}', extra: row),
      onRefresh: controller.refresh,
    );
  }
}

/// Resuelve la fila de "por recibir" para un `pickingId` de la ruta: usa
/// `extra` cuando la navegación ya la trae (el caso normal, desde la lista),
/// y si llega nula (enlace directo, recarga de página) la busca en la copia
/// local ya descargada — pidiendo un refresh si esa copia todavía no existe.
class _EnvasesPorRecibirRowResolver extends ConsumerStatefulWidget {
  const _EnvasesPorRecibirRowResolver({
    required this.pickingId,
    required this.extra,
    required this.builder,
  });

  final int pickingId;
  final EnvasesPorRecibirRow? extra;
  final Widget Function(BuildContext context, EnvasesPorRecibirRow row)
  builder;

  @override
  ConsumerState<_EnvasesPorRecibirRowResolver> createState() =>
      _EnvasesPorRecibirRowResolverState();
}

class _EnvasesPorRecibirRowResolverState
    extends ConsumerState<_EnvasesPorRecibirRowResolver> {
  bool _requestedRefresh = false;

  @override
  Widget build(BuildContext context) {
    final extra = widget.extra;
    if (extra != null) return widget.builder(context, extra);
    final controller = ref.watch(envasesPorRecibirControllerProvider);
    if (controller == null) {
      return const NotConfiguredPage(
        title: 'Envases',
        detail: 'No tienes permiso para consultar este traslado.',
      );
    }
    return StreamBuilder<EnvasesPorRecibirSnapshot?>(
      stream: controller.snapshots,
      builder: (context, snapshot) {
        final data = snapshot.data;
        if (data == null) {
          if (!_requestedRefresh) {
            _requestedRefresh = true;
            scheduleMicrotask(() => unawaited(controller.refresh()));
          }
          return const Center(
            child: ProgressRing(key: Key('envases-traslado-resolver-loading')),
          );
        }
        EnvasesPorRecibirRow? found;
        for (final row in data.rows) {
          if (row.id == widget.pickingId) {
            found = row;
            break;
          }
        }
        if (found == null) {
          return const NotConfiguredPage(
            title: 'Envases',
            detail: 'No se encontró el traslado.',
          );
        }
        return widget.builder(context, found);
      },
    );
  }
}

final class EnvasesTrasladoDetalleRoute extends ConsumerWidget {
  const EnvasesTrasladoDetalleRoute({
    super.key,
    required this.pickingId,
    this.extra,
  });

  final int pickingId;
  final EnvasesPorRecibirRow? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final operations = ref.watch(envasesOperationsProvider);
    final canManage = ref.watch(envasesCanManageProvider);
    if (operations == null) {
      return const NotConfiguredPage(
        title: 'Envases',
        detail: 'No tienes permiso para consultar este traslado.',
      );
    }
    return _EnvasesPorRecibirRowResolver(
      pickingId: pickingId,
      extra: extra,
      builder: (context, row) => EnvasesTrasladoDetalle(
        row: row,
        operaciones: operations.watchOperaciones(),
        operations: operations,
        canManage: canManage,
        onRegistrarRecepcion: () => context.push(
          '/envases/por-recibir/$pickingId/recibir',
          extra: row,
        ),
        onDarPorPerdido: () => context.pop(),
      ),
    );
  }
}

final class EnvasesRecibirRoute extends ConsumerWidget {
  const EnvasesRecibirRoute({
    super.key,
    required this.pickingId,
    this.extra,
  });

  final int pickingId;
  final EnvasesPorRecibirRow? extra;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final runtime = ref.watch(runtimeSessionProvider);
    final capabilities = ref.watch(capabilitySnapshotProvider);
    final operations = ref.watch(envasesOperationsProvider);
    final active = runtime?.active;
    if (operations == null ||
        runtime == null ||
        active == null ||
        capabilities == null ||
        capabilities.companyId <= 0) {
      return const NotConfiguredPage(
        title: 'Envases',
        detail: 'No tienes permiso para recibir envases.',
      );
    }
    final company = CompanyContext.forScope(
      scope: active.scope,
      companyId: capabilities.companyId,
      allowedCompanyIds: [capabilities.companyId],
      capabilityRevision: capabilities.revision,
    );
    return _EnvasesPorRecibirRowResolver(
      pickingId: pickingId,
      extra: extra,
      builder: (context, row) => EnvasesRecibirForm(
        row: row,
        lineasLoader: () {
          final client = runtime.active?.client;
          if (client == null) {
            throw StateError(
              'No hay conexión activa para leer las líneas del traslado',
            );
          }
          return EnvasesPickingLineasReader.fromClient(
            client: client,
            company: company,
          ).leer(row.id);
        },
        operations: operations,
        draftPort: ref.watch(envasesFormDraftPortProvider),
        onCompleted: () => context.pop(),
        onCancel: () => context.pop(),
      ),
    );
  }
}

// ---------------------------------------------------------------------
// Movimientos
// ---------------------------------------------------------------------

final class _EnvasesMovimientosController {
  const _EnvasesMovimientosController({
    required this.cache,
    required this.readerFactory,
  });

  final EnvasesMovimientosCache cache;
  final EnvasesMovimientosReader Function() readerFactory;

  Stream<EnvasesMovimientosSnapshot?> get snapshots => cache.watch();
  Future<void> refresh() => cache.refresh(readerFactory());
}

final envasesMovimientosControllerProvider =
    Provider.autoDispose<_EnvasesMovimientosController?>((ref) {
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
      return _EnvasesMovimientosController(
        cache: EnvasesMovimientosCache(
          owner: runtime.databaseOwner,
          lease: active.lease,
          company: company,
        ),
        readerFactory: () {
          final client = runtime.active?.client;
          if (client == null) {
            throw StateError(
              'No hay conexión activa para actualizar los movimientos de envases',
            );
          }
          return EnvasesMovimientosReader.fromClient(
            client: client,
            company: company,
          );
        },
      );
    });

final class EnvasesMovimientosRoute extends ConsumerWidget {
  const EnvasesMovimientosRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(envasesMovimientosControllerProvider);
    if (controller == null) {
      return const NotConfiguredPage(
        title: 'Envases',
        detail: 'No tienes permiso para consultar los movimientos de envases.',
      );
    }
    return EnvasesMovimientosScreen(
      snapshots: controller.snapshots,
      onRefresh: controller.refresh,
    );
  }
}

// ---------------------------------------------------------------------
// Saldo por tercero
// ---------------------------------------------------------------------

/// Gated by `envases_custodia`, NOT `envases_read` — see
/// `RouteAccessPolicy` and `OdooCapabilityReader.hasEnvasesCustodia`. A
/// custodian without the plain Envases group must still reach this
/// controller.
final class _EnvasesSaldoTercerosController {
  const _EnvasesSaldoTercerosController({
    required this.cache,
    required this.readerFactory,
  });

  final EnvasesSaldoTercerosCache cache;
  final EnvasesPartnerBalanceReader Function() readerFactory;

  Stream<EnvasesSaldoTercerosSnapshot?> get snapshots => cache.watch();
  Future<void> refresh() => cache.refresh(readerFactory());
}

final envasesSaldoTercerosControllerProvider =
    Provider.autoDispose<_EnvasesSaldoTercerosController?>((ref) {
      final runtime = ref.watch(runtimeSessionProvider);
      final capabilities = ref.watch(capabilitySnapshotProvider);
      final active = runtime?.active;
      if (runtime == null ||
          active == null ||
          capabilities == null ||
          capabilities.scopeKey != active.scope.scopeKey ||
          capabilities.companyId <= 0 ||
          !capabilities.permissions.contains('envases_custodia')) {
        return null;
      }
      final company = CompanyContext.forScope(
        scope: active.scope,
        companyId: capabilities.companyId,
        allowedCompanyIds: [capabilities.companyId],
        capabilityRevision: capabilities.revision,
      );
      return _EnvasesSaldoTercerosController(
        cache: EnvasesSaldoTercerosCache(
          owner: runtime.databaseOwner,
          lease: active.lease,
          company: company,
        ),
        readerFactory: () {
          final client = runtime.active?.client;
          if (client == null) {
            throw StateError(
              'No hay conexión activa para actualizar el saldo por tercero',
            );
          }
          return EnvasesPartnerBalanceReader.fromClient(
            client: client,
            company: company,
          );
        },
      );
    });

final class EnvasesSaldoTercerosRoute extends ConsumerWidget {
  const EnvasesSaldoTercerosRoute({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.watch(envasesSaldoTercerosControllerProvider);
    if (controller == null) {
      return const NotConfiguredPage(
        title: 'Envases',
        detail: 'No tienes permiso para consultar el saldo por tercero.',
      );
    }
    return EnvasesSaldoTercerosScreen(
      snapshots: controller.snapshots,
      onRefresh: controller.refresh,
    );
  }
}

// ---------------------------------------------------------------------
// Enviar: sedes + productos
// ---------------------------------------------------------------------

final class _EnvasesSedesController {
  const _EnvasesSedesController({
    required this.cache,
    required this.readerFactory,
  });

  final EnvasesSedesCache cache;
  final EnvasesSedesReader Function() readerFactory;

  Stream<EnvasesSedesSnapshot?> get snapshots => cache.watch();
  Future<void> refresh() => cache.refresh(readerFactory());
}

final envasesSedesControllerProvider =
    Provider.autoDispose<_EnvasesSedesController?>((ref) {
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
      return _EnvasesSedesController(
        cache: EnvasesSedesCache(
          owner: runtime.databaseOwner,
          lease: active.lease,
          company: company,
        ),
        readerFactory: () {
          final client = runtime.active?.client;
          if (client == null) {
            throw StateError(
              'No hay conexión activa para actualizar las sedes de envases',
            );
          }
          return EnvasesSedesReader.fromClient(
            client: client,
            company: company,
            userId: active.scope.userId,
          );
        },
      );
    });

final class _EnvasesProductosController {
  const _EnvasesProductosController({
    required this.cache,
    required this.readerFactory,
  });

  final EnvasesProductosCache cache;
  final EnvasesProductosReader Function() readerFactory;

  Stream<EnvasesProductosSnapshot?> get snapshots => cache.watch();
  Future<void> refresh() => cache.refresh(readerFactory());
}

final envasesProductosControllerProvider =
    Provider.autoDispose<_EnvasesProductosController?>((ref) {
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
      return _EnvasesProductosController(
        cache: EnvasesProductosCache(
          owner: runtime.databaseOwner,
          lease: active.lease,
          company: company,
        ),
        readerFactory: () {
          final client = runtime.active?.client;
          if (client == null) {
            throw StateError(
              'No hay conexión activa para actualizar el catálogo de envases',
            );
          }
          return EnvasesProductosReader.fromClient(
            client: client,
            company: company,
          );
        },
      );
    });

final class EnvasesEnviarRoute extends ConsumerStatefulWidget {
  const EnvasesEnviarRoute({super.key});

  @override
  ConsumerState<EnvasesEnviarRoute> createState() =>
      _EnvasesEnviarRouteState();
}

class _EnvasesEnviarRouteState extends ConsumerState<EnvasesEnviarRoute> {
  bool _requestedRefresh = false;

  @override
  Widget build(BuildContext context) {
    final sedes = ref.watch(envasesSedesControllerProvider);
    final productos = ref.watch(envasesProductosControllerProvider);
    final operations = ref.watch(envasesOperationsProvider);
    if (sedes == null || productos == null || operations == null) {
      return const NotConfiguredPage(
        title: 'Envases',
        detail: 'No tienes permiso para enviar envases.',
      );
    }
    if (!_requestedRefresh) {
      _requestedRefresh = true;
      scheduleMicrotask(() {
        unawaited(sedes.refresh());
        unawaited(productos.refresh());
      });
    }
    return StreamBuilder<EnvasesSedesSnapshot?>(
      stream: sedes.snapshots,
      builder: (context, sedesSnapshot) {
        return StreamBuilder<EnvasesProductosSnapshot?>(
          stream: productos.snapshots,
          builder: (context, productosSnapshot) {
            final sedesData = sedesSnapshot.data;
            final productosData = productosSnapshot.data;
            if (sedesData == null || productosData == null) {
              return const Center(
                child: ProgressRing(key: Key('envases-enviar-loading')),
              );
            }
            return EnvasesEnviarForm(
              sedesUsuario: [
                for (final sede in sedesData.propias)
                  EnvasesSedeOption(id: sede.id, name: sede.name),
              ],
              sedesDestinoPosibles: [
                for (final sede in sedesData.posibles)
                  EnvasesSedeOption(id: sede.id, name: sede.name),
              ],
              productos: [
                for (final producto in productosData.rows)
                  EnvasesProductoOption(
                    id: producto.id,
                    name: producto.name,
                    uomName: producto.uomName,
                  ),
              ],
              operations: operations,
              draftPort: ref.watch(envasesFormDraftPortProvider),
              onCompleted: () => context.pop(),
              onCancel: () => context.pop(),
            );
          },
        );
      },
    );
  }
}
