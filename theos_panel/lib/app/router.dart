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
import '../features/settings/settings_screen.dart';
import '../features/orders/orders_screen.dart';
import '../features/orders/orders_contracts.dart';
import '../features/clients/catalog_contracts.dart';
import '../features/clients/clients_screen.dart';
import '../features/products/products_screen.dart';
import 'preferences/app_preferences.dart';
import '../features/activities/activity_center.dart';
import '../features/reports/document_view.dart';
import '../features/sync/sync_center.dart';
import '../ui/home_page.dart';
import 'session_composition.dart';
import 'notification_scope_adapter.dart';
import 'u08_scope_adapters.dart';
import 'order_scope_repository.dart';
import 'collection_scope_composition.dart';
import 'scope_catalog_repository.dart';
import 'business_composition_factory.dart';

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
      final controller = CatalogController<SaleCatalogPartner>(
        repository: RuntimePartnerCatalogRepository(
          store: composition.store('partner'),
          scope: composition.activation.scope,
        ),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
final scopeProductsCatalogProvider =
    Provider<CatalogController<SaleCatalogProduct>?>((ref) {
      final composition = ref.watch(scopeCatalogCompositionProvider);
      final capabilities = ref.watch(capabilitySnapshotProvider);
      if (composition == null || capabilities == null) return null;
      final controller = CatalogController<SaleCatalogProduct>(
        repository: RuntimeProductCatalogRepository(
          store: composition.store('product'),
          scope: composition.activation.scope,
        ),
      );
      ref.onDispose(controller.dispose);
      return controller;
    });
final saleDraftStoreProvider = Provider<SaleDraftStore>(
  (ref) =>
      SharedPreferencesSaleDraftStore(ref.watch(sharedPreferencesProvider)),
);
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
      GoRoute(path: '/', builder: (context, state) => const HomePage()),
      GoRoute(
        path: '/sales',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final repository = ref.watch(scopeOrderRepositoryProvider);
            final capabilities = ref.watch(capabilitySnapshotProvider);
            final profile = ref.watch(authControllerProvider).profile;
            if (repository == null || capabilities == null || profile == null) {
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
          builder: (context, ref, _) => SaleEditorScreen(
            controller: ref.watch(saleDraftControllerProvider),
            presentation: SalePresentation.counter,
            clients: ref.watch(scopeClientsCatalogProvider),
            products: ref.watch(scopeProductsCatalogProvider),
            catalog: _saleCatalog(ref),
            canSelectWarehouse:
                ref
                    .watch(capabilitySnapshotProvider)
                    ?.permissions
                    .contains('warehouse_select') ??
                false,
          ),
        ),
      ),
      GoRoute(
        path: '/sales/consultive',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) => SaleEditorScreen(
            controller: ref.watch(saleDraftControllerProvider),
            presentation: SalePresentation.consultive,
            clients: ref.watch(scopeClientsCatalogProvider),
            products: ref.watch(scopeProductsCatalogProvider),
            catalog: _saleCatalog(ref),
            canSelectWarehouse:
                ref
                    .watch(capabilitySnapshotProvider)
                    ?.permissions
                    .contains('warehouse_select') ??
                false,
          ),
        ),
      ),
      GoRoute(
        path: '/clients',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final controller = ref.watch(scopeClientsCatalogProvider);
            return ClientsScreen<SaleCatalogPartner>(controller: controller);
          },
        ),
      ),
      GoRoute(
        path: '/products',
        builder: (context, state) => Consumer(
          builder: (context, ref, _) {
            final controller = ref.watch(scopeProductsCatalogProvider);
            return ProductsScreen<SaleCatalogProduct>(controller: controller);
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
            final journals = ref.watch(scopeCollectionJournalsFutureProvider);
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
            (composition.activities ?? ref.read(scopeActivityPortProvider)) ==
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
            overrides: [notificationInboxPortProvider.overrideWithValue(port)],
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
  );
});
