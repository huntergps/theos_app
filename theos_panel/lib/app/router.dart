import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/route_access_policy.dart';
import '../features/collection/collection_screen.dart';
import '../features/collection/collection_contracts.dart';
import '../features/approvals/approval_contracts.dart';
import '../features/approvals/approvals_screen.dart';
import '../features/notifications/notification_inbox.dart';
import '../features/sales/sale_editor.dart';
import '../features/sales/durable_sale_draft_store.dart';
import '../features/sales/sale_draft_workspace.dart';
import '../features/sales/sale_draft_workspace_bar.dart';
import '../features/sales/legacy_draft_inspector.dart';
import '../features/sales/legacy_draft_notice.dart';
import '../features/settings/settings_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/orders/orders_contracts.dart';
import '../features/warehouse/warehouse_screen.dart';
import '../features/clients/catalog_contracts.dart';
import '../features/clients/clients_screen.dart';
import '../features/products/products_screen.dart';
import 'preferences/app_preferences.dart';
import '../features/activities/activity_center.dart';
import '../features/reports/document_view.dart';
import '../features/sync/sync_center.dart';
import '../ui/home_page.dart';
import '../ui/layouts/operational_shell.dart';
import 'session_composition.dart';
import 'notification_scope_adapter.dart';
import 'u08_scope_adapters.dart';
import 'order_scope_repository.dart';
import 'collection_scope_composition.dart';
import 'scope_catalog_repository.dart';
import 'business_composition_factory.dart';
import 'envases_composition.dart';

final businessCompositionFactoryProvider =
    Provider<OrbiBusinessCompositionFactory>(
      (ref) => OrbiBusinessCompositionFactory(),
    );

final businessCompositionProvider = Provider<OrbiBusinessComposition?>((ref) {
  final supplied = ref.watch(orbiSessionCompositionProvider).business;
  final runtime = ref.watch(runtimeSessionProvider);
  final capabilities = ref.watch(capabilitySnapshotProvider);
  final active = runtime?.active;
  if (active == null || capabilities == null) {
    return null;
  }
  if (supplied != null) {
    if (supplied.lease != active.lease ||
        supplied.capabilities.scopeKey != capabilities.scopeKey) {
      return null;
    }
    return supplied;
  }
  return ref
      .watch(businessCompositionFactoryProvider)
      .composeSync(runtime: runtime!, capabilities: capabilities);
});

final collectionFinancialActionsProvider = Provider<List<CollectionFinancialAction>>((
  ref,
) {
  final port = ref.watch(businessCompositionProvider)?.collectionOperations;
  final active = ref.watch(runtimeSessionProvider)?.active;
  final capabilities = ref.watch(capabilitySnapshotProvider);
  if (port == null || active == null || capabilities == null) {
    return const [];
  }
  final actions = <CollectionFinancialAction>[];
  if (capabilities.permissions.contains('cashier')) {
    actions.add(
      CollectionFinancialAction(
        capability: CollectionCapability.advances,
        label: 'Registrar anticipo offline',
        run: () async => CollectionResultState.conflict,
        runWithContext: (input) async {
          final partnerId = input.partnerId;
          final sessionId = int.tryParse(input.shift.id);
          final journalId = input.journalId;
          if (active.client != null ||
              partnerId == null ||
              sessionId == null ||
              journalId == null ||
              journalId <= 0 ||
              input.amountMinor <= 0) {
            // Online advance creation remains behind the existing native
            // wizard; this button is intentionally an offline producer only.
            return CollectionResultState.conflict;
          }
          final result = await port.advance(
            commandId:
                'advance-${active.scope.scopeKey}-$partnerId-$sessionId-${input.amountMinor}',
            lease: active.lease,
            paymentWizardId: input.selectedSale?.wizardId ?? 0,
            overpaymentMinor: input.amountMinor,
            partnerId: partnerId,
            reference:
                'Anticipo POS offline ${active.scope.scopeKey} $sessionId',
            journalId: journalId,
            collectionSessionId: sessionId,
            offline: true,
          );
          return result.state == CollectionOperationState.queued
              ? CollectionResultState.queued
              : CollectionResultState.conflict;
        },
      ),
    );
    actions.add(
      CollectionFinancialAction(
        capability: CollectionCapability.cashOuts,
        label: 'Registrar salida de caja',
        run: () async => CollectionResultState.conflict,
        runWithContext: (input) async {
          final sessionId = int.tryParse(input.shift.id);
          if (sessionId == null ||
              input.journalId == null ||
              input.cashOutTypeId == null ||
              input.cashOutTypeId! <= 0 ||
              input.amountMinor <= 0) {
            return CollectionResultState.conflict;
          }
          final result = await port.cashOut(
            commandId:
                'cash-out-${active.scope.scopeKey}-$sessionId-${input.amountMinor}',
            lease: active.lease,
            collectionSessionId: sessionId,
            journalId: input.journalId!,
            cashOutTypeId: input.cashOutTypeId!,
            amountMinor: input.amountMinor,
            note: 'Salida registrada desde Orbi ERP',
          );
          return result.state == CollectionOperationState.queued
              ? CollectionResultState.queued
              : CollectionResultState.conflict;
        },
      ),
    );
    actions.add(
      CollectionFinancialAction(
        capability: CollectionCapability.deposits,
        label: 'Guardar depósito (pendiente de contabilizar)',
        run: () async => CollectionResultState.conflict,
        runWithContext: (input) async {
          final sessionId = int.tryParse(input.shift.id);
          if (sessionId == null ||
              input.journalId == null ||
              input.amountMinor <= 0) {
            return CollectionResultState.conflict;
          }
          final result = await port.deposit(
            commandId:
                'deposit-${active.scope.scopeKey}-$sessionId-${input.amountMinor}',
            lease: active.lease,
            collectionSessionId: sessionId,
            bankJournalId: input.journalId!,
            depositType: 'cash',
            amountMinor: input.amountMinor,
            cashAmountMinor: input.amountMinor,
            checkAmountMinor: 0,
            accountingDate: DateTime.now().toIso8601String().substring(0, 10),
          );
          return result.state == CollectionOperationState.queued
              ? CollectionResultState.queued
              : CollectionResultState.conflict;
        },
      ),
    );
  }
  return List<CollectionFinancialAction>.unmodifiable(actions);
});

final scopeCatalogCompositionProvider = Provider<RuntimeCatalogComposition?>((
  ref,
) {
  final session = ref.watch(orbiSessionCompositionProvider);
  final supplied =
      ref.watch(businessCompositionProvider)?.catalogs ?? session.catalogs;
  if (supplied != null) return supplied;
  final runtime = ref.watch(runtimeSessionProvider);
  final active = runtime?.active;
  if (runtime == null || active == null || active.client == null) return null;
  return RuntimeCatalogComposition(
    activation: active,
    owner: runtime.databaseOwner,
  );
});
final scopeSyncCoordinatorProvider = Provider<SyncCoordinatorImpl?>((ref) {
  final composition = ref.watch(scopeCatalogCompositionProvider);
  final active = ref.watch(runtimeSessionProvider)?.active;
  if (composition == null || active == null) return null;
  final coordinator = SyncCoordinatorImpl(jobs: composition.jobs.values);
  unawaited(coordinator.start(active.scope));
  ref.onDispose(coordinator.dispose);
  return coordinator;
});
final scopeClientsCatalogProvider =
    Provider<CatalogController<SaleCatalogPartner>?>((ref) {
      final composition = ref.watch(scopeCatalogCompositionProvider);
      final capabilities = ref.watch(capabilitySnapshotProvider);
      if (composition == null || capabilities == null) return null;
      final repository = RuntimePartnerCatalogRepository(
        store: composition.store('partner'),
        scope: composition.activation.scope,
      );
      final controller = CatalogController<SaleCatalogPartner>(
        repository: repository,
      );
      // Retire both presentation and query subscriptions with this scope.
      // Disposing these owners must never delete the durable catalog.
      ref.onDispose(() {
        controller.dispose();
        unawaited(repository.dispose());
      });
      return controller;
    });
final scopeProductsCatalogProvider =
    Provider<CatalogController<SaleCatalogProduct>?>((ref) {
      final composition = ref.watch(scopeCatalogCompositionProvider);
      final capabilities = ref.watch(capabilitySnapshotProvider);
      if (composition == null || capabilities == null) return null;
      final repository = RuntimeProductCatalogRepository(
        store: composition.store('product'),
        scope: composition.activation.scope,
      );
      final controller = CatalogController<SaleCatalogProduct>(
        repository: repository,
      );
      ref.onDispose(() {
        controller.dispose();
        unawaited(repository.dispose());
      });
      return controller;
    });
final saleDraftStoreProvider = Provider<SaleDraftStore>((ref) {
  final runtime = ref.watch(runtimeSessionProvider);
  final active = runtime?.active;
  final capabilities = ref.watch(capabilitySnapshotProvider);
  if (runtime == null ||
      active == null ||
      capabilities == null ||
      active.scope.scopeKey != capabilities.scopeKey) {
    return const UnavailableSaleDraftStore();
  }
  return DurableSaleDraftStore(
    store: EditableDraftStore(
      owner: runtime.databaseOwner,
      lease: active.lease,
      company: CompanyContext(
        companyId: capabilities.companyId,
        allowedCompanyIds: [capabilities.companyId],
        scopeKey: capabilities.scopeKey,
        capabilityRevision: capabilities.revision,
      ),
    ),
    scopeKey: capabilities.scopeKey,
    // The existing route owns one editor. Multi-document navigation must
    // replace this slot with stable per-tab IDs, not command IDs.
    draftId: 'workspace-active-editor',
  );
});
SaleCatalogPort _saleCatalog(WidgetRef ref) {
  final composition = ref.watch(scopeCatalogCompositionProvider);
  final capabilities = ref.watch(capabilitySnapshotProvider);
  if (composition == null || capabilities == null) {
    return const UnavailableSaleCatalogPort();
  }
  return RuntimeSaleCatalogPort(
    store: composition.store('paymentTerm'),
    scope: composition.activation.scope,
  );
}

final saleEditorPortProvider = Provider<SaleEditorPort>((ref) {
  final capabilities = ref.watch(capabilitySnapshotProvider);
  final session = ref.watch(orbiSessionCompositionProvider);
  final commands =
      ref.watch(businessCompositionProvider)?.saleCommands ??
      session.saleCommands;
  if (capabilities == null || commands == null) return LocalSaleEditorPort();
  return RuntimeSaleEditorPort(commands, capabilities);
});
final approvalPortProvider = Provider<ApprovalPort>(
  (ref) =>
      (ref.watch(businessCompositionProvider)?.approvals ??
          ref.watch(orbiSessionCompositionProvider).approvals) ??
      const UnavailableApprovalPort(),
);
final saleDraftControllerProvider = Provider<SaleDraftController>((ref) {
  final capabilities = ref.watch(capabilitySnapshotProvider);
  final controller = SaleDraftController(
    port: ref.watch(saleEditorPortProvider),
    store: ref.watch(saleDraftStoreProvider),
    repository: ref.watch(runtimeSessionProvider)?.active == null
        ? null
        : DriftSaleDraftRepository(
            ref.watch(runtimeSessionProvider)!.active!.database.database,
          ),
    approvalPort: ref.watch(approvalPortProvider),
    capabilities: capabilities,
    scopeKey: capabilities?.scopeKey ?? 'unconfigured',
  );
  ref.onDispose(controller.dispose);
  return controller;
});

/// One owner per authenticated company. Individual editors are keyed by durable
/// draft ID, not by route, position or command identity. Switching presentation
/// therefore retains the same open documents without duplicating their buffers.
final saleDraftWorkspaceProvider = Provider<SaleDraftWorkspace?>((ref) {
  final durable = ref.watch(saleDraftStoreProvider);
  if (durable is! DurableSaleDraftStore) return null;
  final runtime = ref.watch(runtimeSessionProvider);
  final port = ref.watch(saleEditorPortProvider);
  final approvals = ref.watch(approvalPortProvider);
  final capabilities = ref.watch(capabilitySnapshotProvider);
  final database = runtime?.active?.database.database;
  final workspace = SaleDraftWorkspace(
    store: durable.store,
    scopeKey: durable.scopeKey,
    controllerFactory: (store) => SaleDraftController(
      port: port,
      store: store,
      repository: database == null ? null : DriftSaleDraftRepository(database),
      approvalPort: approvals,
      capabilities: capabilities,
      scopeKey: durable.scopeKey,
    ),
  );
  // The workspace exposes recovery errors in state. Never turn an invalid
  // local document into a fresh empty one or an unhandled async exception.
  unawaited(workspace.initialize().catchError((Object _) {}));
  ref.onDispose(() => unawaited(workspace.disposeAsync()));
  return workspace;
});

Widget _saleWorkspace(WidgetRef ref, SalePresentation presentation) {
  final workspace = ref.watch(saleDraftWorkspaceProvider);
  final clients = ref.watch(scopeClientsCatalogProvider);
  final products = ref.watch(scopeProductsCatalogProvider);
  final catalog = _saleCatalog(ref);
  final warehouse =
      ref
          .watch(capabilitySnapshotProvider)
          ?.permissions
          .contains('warehouse_select') ??
      false;
  if (workspace == null) return const NotConfiguredPage(title: 'Ventas');
  // Inspection is deliberately read-only: old preferences lack the company
  // and complete amounts needed for a trustworthy automatic migration.
  final legacy = LegacyDraftInspector(ref.watch(sharedPreferencesProvider))
      .inspect(workspace.scopeKey);
  return AnimatedBuilder(
    animation: workspace,
    builder: (context, _) {
      final controller = workspace.selectedController;
      return Material(
        child: SafeArea(
          child: Column(
            children: [
              SaleDraftWorkspaceBar(workspace: workspace),
              LegacyDraftNotice(inspection: legacy),
              if (workspace.error != null)
                const Padding(
                  padding: EdgeInsets.all(8),
                  child: Text(
                    'No se pudo recuperar o guardar el borrador. '
                    'Tus datos locales se conservan.',
                  ),
                ),
              Expanded(
                child: controller == null
                    ? Center(
                        child: workspace.busy
                            ? const CircularProgressIndicator()
                            : const Text(
                                'Selecciona un borrador o crea una venta.',
                              ),
                      )
                    : SaleEditorScreen(
                        key: ValueKey(workspace.selectedDraftId),
                        controller: controller,
                        presentation: presentation,
                        clients: clients,
                        products: products,
                        catalog: catalog,
                        canSelectWarehouse: warehouse,
                      ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

final orbiRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authControllerProvider);
  final capabilities = ref.watch(capabilitySnapshotProvider);
  final policy = ref.watch(routeAccessPolicyProvider);
  final composition = ref.watch(orbiSessionCompositionProvider);
  final authenticated =
      auth.status == AuthControllerStatus.authenticated ||
      auth.status == AuthControllerStatus.restored;
  return GoRouter(
    initialLocation: authenticated ? '/' : '/login',
    redirect: (context, state) {
      final location = state.uri.path;
      if (!authenticated) {
        if (location == '/login') return null;
        return '/login?returnTo=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (location == '/login') {
        return policy.destinationAfterLogin(
          state.uri.queryParameters['returnTo'],
          authenticated: true,
          capabilities: capabilities,
        );
      }
      if (!policy.allows(
        location,
        authenticated: true,
        capabilities: capabilities,
      )) {
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) {
          final profile = auth.profile;
          // Navigation shares the same gate as direct URLs. Missing context
          // remains explicit; an authenticated client is not proof of network
          // reachability, synchronization, or a fresh server clock.
          final destinations =
              <OperationalDestination>[
                    const OperationalDestination(
                      label: 'Inicio',
                      path: '/',
                      icon: Icons.home_outlined,
                      group: 'Workspace',
                    ),
                    const OperationalDestination(
                      label: 'Órdenes y cotizaciones',
                      path: '/sales',
                      icon: Icons.receipt_long_outlined,
                      group: 'Ventas',
                    ),
                    const OperationalDestination(
                      label: 'Mostrador',
                      path: '/sales/counter',
                      icon: Icons.point_of_sale_outlined,
                      group: 'Ventas',
                    ),
                    const OperationalDestination(
                      label: 'Venta consultiva',
                      path: '/sales/consultive',
                      icon: Icons.edit_note_outlined,
                      group: 'Ventas',
                    ),
                    const OperationalDestination(
                      label: 'Clientes',
                      path: '/clients',
                      icon: Icons.people_outline,
                      group: 'Ventas',
                    ),
                    const OperationalDestination(
                      label: 'Productos',
                      path: '/products',
                      icon: Icons.inventory_2_outlined,
                      group: 'Ventas',
                    ),
                    const OperationalDestination(
                      label: 'Punto de cobro',
                      path: '/collection',
                      icon: Icons.payments_outlined,
                      group: 'Caja',
                    ),
                    const OperationalDestination(
                      label: 'Operaciones de bodega',
                      path: '/warehouse',
                      icon: Icons.warehouse_outlined,
                      group: 'Bodega',
                    ),
                    const OperationalDestination(
                      label: 'Dashboard',
                      path: '/envases',
                      icon: Icons.local_shipping_outlined,
                      group: 'Envases',
                    ),
                    const OperationalDestination(
                      label: 'Solicitudes',
                      path: '/approvals',
                      icon: Icons.fact_check_outlined,
                      group: 'Aprobaciones',
                    ),
                    const OperationalDestination(
                      label: 'Actividades',
                      path: '/activities',
                      icon: Icons.event_note_outlined,
                      group: 'Sistema',
                    ),
                    const OperationalDestination(
                      label: 'Sincronización',
                      path: '/sync',
                      icon: Icons.sync,
                      group: 'Sistema',
                    ),
                    const OperationalDestination(
                      label: 'Avisos',
                      path: '/notifications',
                      icon: Icons.notifications_outlined,
                      group: 'Sistema',
                    ),
                    const OperationalDestination(
                      label: 'Configuración',
                      path: '/settings',
                      icon: Icons.settings_outlined,
                      group: 'Sistema',
                    ),
                  ]
                  .where(
                    (entry) => policy.allows(
                      entry.path,
                      authenticated: authenticated,
                      capabilities: capabilities,
                    ),
                  )
                  .toList(growable: false);
          return OperationalShell(
            destinations: destinations,
            selectedPath: state.uri.path,
            onNavigate: (path) => context.go(path),
            context: OperationalContext(
              server: profile?.serverUrl ?? 'No disponible',
              database: profile?.database ?? 'No disponible',
              userLabel: profile?.login ?? 'Usuario no disponible',
              companyLabel: profile?.companyId == null
                  ? 'Empresa no disponible'
                  : 'Empresa #${profile!.companyId}',
              connectionLabel: 'Red sin verificar',
              syncLabel: 'Sincronización no verificada',
            ),
            onLogout: () async {
              await ref.read(authControllerProvider.notifier).close();
              if (context.mounted) context.go('/login');
            },
            child: child,
          );
        },
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomePage()),
          GoRoute(
            path: '/sales',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                final repository = ref.watch(scopeOrderRepositoryProvider);
                final capabilities = ref.watch(capabilitySnapshotProvider);
                final profile = ref.watch(authControllerProvider).profile;
                if (repository == null ||
                    capabilities == null ||
                    profile == null) {
                  return const NotConfiguredPage(title: 'Ventas');
                }
                return OrdersScreen(
                  repository: repository,
                  filterStore: SharedPreferencesOrderFilterStore(
                    ref.watch(sharedPreferencesProvider),
                  ),
                  scopeKey: capabilities.scopeKey,
                  policy: OrderFilterPolicy(
                    userId: profile.userId,
                    capabilities: capabilities,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            path: '/sales/counter',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) =>
                  _saleWorkspace(ref, SalePresentation.counter),
            ),
          ),
          GoRoute(
            path: '/sales/consultive',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) =>
                  _saleWorkspace(ref, SalePresentation.consultive),
            ),
          ),
          GoRoute(
            path: '/clients',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                final controller = ref.watch(scopeClientsCatalogProvider);
                return ClientsScreen<SaleCatalogPartner>(
                  controller: controller,
                );
              },
            ),
          ),
          GoRoute(
            path: '/products',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                final controller = ref.watch(scopeProductsCatalogProvider);
                return ProductsScreen<SaleCatalogProduct>(
                  controller: controller,
                );
              },
            ),
          ),
          GoRoute(
            path: '/approvals',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                final snapshot = ref.watch(capabilitySnapshotProvider);
                if (snapshot == null ||
                    !snapshot.permissions.contains('approver')) {
                  return const NotConfiguredPage(title: 'Aprobaciones');
                }
                return ApprovalsScreen(
                  port: ref.watch(approvalPortProvider),
                  snapshot: snapshot,
                );
              },
            ),
          ),
          GoRoute(
            path: '/collection',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                final shift = ref.watch(scopeCollectionShiftFutureProvider);
                final pending = ref.watch(scopeCollectionPendingFutureProvider);
                final journals = ref.watch(
                  scopeCollectionJournalsFutureProvider,
                );
                final cashOutTypes = ref.watch(
                  scopeCollectionCashOutTypesFutureProvider,
                );
                return shift.when(
                  loading: () => const NotConfiguredPage(
                    title: 'Caja',
                    detail: 'Cargando turno y punto de cobro…',
                  ),
                  error: (error, stack) =>
                      NotConfiguredPage(title: 'Caja', detail: '$error'),
                  data: (currentShift) => pending.when(
                    loading: () => const NotConfiguredPage(
                      title: 'Caja',
                      detail: 'Cargando pendientes…',
                    ),
                    error: (error, stack) =>
                        NotConfiguredPage(title: 'Caja', detail: '$error'),
                    data: (sales) => journals.when(
                      loading: () => const NotConfiguredPage(
                        title: 'Caja',
                        detail: 'Cargando diarios permitidos…',
                      ),
                      error: (error, stack) =>
                          NotConfiguredPage(title: 'Caja', detail: '$error'),
                      data: (journalOptions) => CollectionScreen(
                        shift: currentShift,
                        pending: sales,
                        capabilities: ref.watch(
                          scopeCollectionCapabilitiesProvider,
                        ),
                        actions: ref.watch(scopeCollectionActionsProvider),
                        journals: journalOptions,
                        cashOutTypes: cashOutTypes.asData?.value ?? const [],
                        financialActions: ref.watch(
                          collectionFinancialActionsProvider,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          GoRoute(
            path: '/envases',
            builder: (context, state) => const EnvasesDashboardRoute(),
          ),
          GoRoute(
            path: '/warehouse',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                final repository = ref.watch(scopeOrderRepositoryProvider);
                final capabilities = ref.watch(capabilitySnapshotProvider);
                final profile = ref.watch(authControllerProvider).profile;
                if (repository == null ||
                    capabilities == null ||
                    profile == null) {
                  return const NotConfiguredPage(title: 'Bodega');
                }
                return WarehouseScreen(
                  repository: repository,
                  operations: RuntimeWarehouseOperationPort(
                    runtime: ref.watch(runtimeSessionProvider)!,
                    capabilities: capabilities,
                  ),
                  scopeKey: capabilities.scopeKey,
                  policy: OrderFilterPolicy(
                    userId: profile.userId,
                    capabilities: capabilities,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                final scope = ref.watch(preferencesScopeProvider);
                final preferences = ref.watch(appPreferencesProvider(scope));
                final presenter = ref.watch(notificationPresenterProvider);
                final coordinator = composition.syncCoordinator;
                return SettingsScreen(
                  controller: preferences,
                  permissionAction: presenter == null
                      ? null
                      : NotificationPermissionAction(presenter),
                  onRouteModeChanged: coordinator == null
                      ? null
                      : (enabled) => enabled
                            ? coordinator.pause(PauseReason('route_mode'))
                            : coordinator.resume(),
                );
              },
            ),
          ),
          GoRoute(
            path: '/activities',
            builder: (context, state) =>
                (composition.activities ??
                        ref.read(scopeActivityPortProvider)) ==
                    null
                ? const NotConfiguredPage(title: 'Actividades')
                : Scaffold(
                    appBar: AppBar(title: const Text('Actividades')),
                    body: ActivityCenterView(
                      port:
                          composition.activities ??
                          ref.read(scopeActivityPortProvider)!,
                    ),
                  ),
          ),
          GoRoute(
            path: '/sync',
            builder: (context, state) =>
                (composition.sync == null &&
                    ref.read(scopeSyncCoordinatorProvider) == null)
                ? const NotConfiguredPage(title: 'Sincronización')
                : ProviderScope(
                    overrides: [
                      syncCenterPortProvider.overrideWithValue(
                        composition.sync ??
                            CoordinatorSyncCenterPort(
                              ref.read(scopeSyncCoordinatorProvider)!,
                              operations:
                                  composition.catalogs?.jobs['operations']
                                      as OperationsSyncJob?,
                            ),
                      ),
                    ],
                    child: Scaffold(
                      appBar: AppBar(title: Text('Sincronización')),
                      body: SyncCenterView(
                        onOpenConflicts: () => showDialog<void>(
                          context: context,
                          builder: (context) => const AlertDialog(
                            title: Text('Conflictos de sincronización'),
                            content: Text(
                              'Hay operaciones que requieren revisión. '
                              'No se reintentará ni resolverá automáticamente.',
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
          GoRoute(
            path: '/notifications',
            builder: (context, state) {
              final port =
                  composition.notifications ??
                  ref.watch(sessionNotificationInboxPortProvider);
              final active = ref.watch(runtimeSessionProvider)?.active;
              final capabilities = ref.watch(capabilitySnapshotProvider);
              if (port == null || active == null) {
                return const NotConfiguredPage(title: 'Avisos');
              }
              final navigator =
                  composition.notificationNavigator ??
                  sessionNotificationNavigator(
                    runtime: active.database.lease == active.lease
                        ? ref.read(runtimeSessionProvider)!
                        : throw StateError('notification session changed'),
                    capabilities: capabilities,
                    opener: (target, scope) async {
                      if (target.type == 'document') {
                        context.go('/reports/${target.reference}');
                      } else if (target.type == 'activity') {
                        context.go('/activities');
                      } else {
                        context.go('/sales');
                      }
                    },
                  );
              final partition = capabilities?.companyId == null
                  ? 'global'
                  : 'company:${capabilities!.companyId}';
              return ProviderScope(
                overrides: [
                  notificationInboxPortProvider.overrideWithValue(port),
                ],
                child: Scaffold(
                  appBar: AppBar(title: const Text('Avisos')),
                  body: NotificationInboxView(
                    query: NotificationQueryKey(
                      scopeKey: active.scope.scopeKey,
                      partitionKey: partition,
                    ),
                    navigator: navigator,
                  ),
                ),
              );
            },
          ),
          GoRoute(
            path: '/reports/:documentId',
            builder: (context, state) =>
                (composition.documents ??
                        ref.read(scopeDocumentRenderPortProvider)) ==
                    null
                ? const NotConfiguredPage(title: 'Documentos')
                : Scaffold(
                    appBar: AppBar(title: const Text('Documento')),
                    body: DocumentView(
                      port:
                          composition.documents ??
                          ref.read(scopeDocumentRenderPortProvider)!,
                      documentId: state.pathParameters['documentId']!,
                    ),
                  ),
          ),
        ],
      ),
    ],
  );
});
