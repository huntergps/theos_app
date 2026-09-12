import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/login_failure_messages.dart';
import '../features/auth/route_access_messages.dart';
import '../ui/components/copyable_message.dart';
import '../features/auth/route_access_policy.dart';
import '../features/auth/workspace_unlock_store.dart';
import '../features/collection/collection_screen.dart';
import '../features/collection/collection_contracts.dart';
import '../features/collection/collection_session_hub_screen.dart';
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
import '../features/warehouse/warehouse_existences_screen.dart';
import 'warehouse_existences_composition.dart';
import '../features/clients/catalog_contracts.dart';
import '../features/clients/clients_screen.dart';
import '../features/products/products_screen.dart';
import 'preferences/app_preferences.dart';
import '../features/activities/activity_center.dart';
import '../features/reports/document_view.dart';
import '../features/sync/network_signal_provider.dart';
import '../ui/export/export_listing.dart';
import '../ui/fluent/orbi_page.dart';
import '../features/sync/sync_center.dart';
import '../features/sync/sync_conflict_resolution_screen.dart';
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

/// Manual privacy gate for the operational shell (ACC-03, "bloquear").
/// Deliberately a plain, always-on provider outside [orbiRouterProvider]:
/// that provider rebuilds the whole [GoRouter] (and therefore resets
/// navigation) whenever auth/capabilities change, so a lock flag watched
/// there would risk being silently dropped by an unrelated capability
/// refresh. It also must never expire on its own — the shell spec is
/// explicit that no new timeout is invented here.
final workspaceLockProvider = NotifierProvider<WorkspaceLockNotifier, bool>(
  WorkspaceLockNotifier.new,
);

class WorkspaceLockNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void lock() => state = true;

  void unlock() => state = false;
}

/// Revalidates the currently authenticated identity for
/// [OperationalShell.onUnlock], **without requiring a network** whenever this
/// device has a derivation of the password stored (see
/// [WorkspaceUnlockStore]).
///
/// Two independent reasons this never goes through
/// `authControllerProvider.notifier.login`:
///
/// * a wrong password during unlock must never clear the already-authenticated
///   profile/capabilities the way a failed `AuthNotifier.login()` would — see
///   its catch/error branch. Locking is reversible privacy, not a new
///   authentication attempt, so its failure must stay local to the lock
///   screen; and
/// * `NativeAuthService.login` does far more than check a password: it mints a
///   fresh API key, rewrites the stored credential and profile, and closes and
///   reactivates the session runtime. That is the right thing for a login and
///   the wrong thing for reopening a screen the same operator never left.
///
/// ## The order, and why
///
/// The local derivation is consulted **first**, and the server only as a
/// fallback. That is what makes the gate usable in a basement with no signal,
/// and it also keeps the common case from tearing the session down and
/// rebuilding it. The server is still reached in the three cases where the
/// local answer cannot be trusted as final:
///
/// * nothing is enrolled yet ([WorkspaceUnlockVerdict.notEnrolled]) — the
///   first unlock after a cold start, which is also what enrols it;
/// * the platform has nowhere safe to store one
///   ([WorkspaceUnlockVerdict.unavailable]) — the web; and
/// * the password does not match the derivation
///   ([WorkspaceUnlockVerdict.rejected]). This is exactly what a password
///   changed on the server looks like from here, so the *new* password is
///   given its chance online and, when the server accepts it, it replaces the
///   stale derivation on the spot.
///
/// [WorkspaceUnlockVerdict.lockedOut] is the one verdict that refuses outright,
/// server included: a cap on attempts that the network can step around is not
/// a cap. The operator is never stranded by it — "Cambiar de usuario" and
/// "Cerrar sesión" stay available on the lock screen and neither needs a
/// network.
Future<bool> attemptWorkspaceUnlock(WidgetRef ref, String password) async {
  final profile = ref.read(authControllerProvider).profile;
  if (profile == null) return false;
  final unlockStore = ref.read(workspaceUnlockStoreProvider);
  final scopeKey = workspaceUnlockScopeKeyFor(profile);
  final verdict = await unlockStore.verify(scopeKey, password);
  switch (verdict) {
    case WorkspaceUnlockVerdict.unlocked:
      ref.read(workspaceLockProvider.notifier).unlock();
      return true;
    case WorkspaceUnlockVerdict.lockedOut:
      return false;
    case WorkspaceUnlockVerdict.rejected:
    case WorkspaceUnlockVerdict.notEnrolled:
    case WorkspaceUnlockVerdict.unavailable:
      break;
  }
  try {
    final result = await ref
        .read(authServiceProvider)
        .login(
          serverUrl: profile.serverUrl,
          database: profile.database,
          login: profile.login,
          password: password,
        );
    final unlocked =
        result.status == AuthServiceStatus.authenticated ||
        result.status == AuthServiceStatus.restored;
    if (unlocked) {
      // Enrol (or replace) the derivation with the password the server just
      // accepted, so the next unlock needs no network — and so a password
      // changed on the server stops being able to be opened by the old one.
      await unlockStore.remember(scopeKey, password);
      ref.read(workspaceLockProvider.notifier).unlock();
    }
    return unlocked;
  } catch (error) {
    // A rejection the server is UNAMBIGUOUS about means this identity no
    // longer has access on this device, so the stored derivation must not
    // outlive it: an offline unlock that still opens for a revoked account is
    // a credential nobody can revoke.
    //
    // What is NOT in this list matters as much as what is.
    // [LoginFailureCause.invalidCredentials] is deliberately absent: the
    // server answers a mistyped password and a password changed elsewhere
    // with the SAME rejection, on purpose — telling them apart would be free
    // reconnaissance for whoever is trying logins. So a typo while online
    // must never cost a legitimate operator their offline unlock. That
    // ambiguity cannot be closed from the client; it is a property of the
    // server's answer, not a gap in ours.
    // Unified with `shouldDiscardStoredCredential` instead of keeping a second
    // copy of the rule here. The argument is the one `mensajes-acceso` used to
    // delete his own duplicate of the token contract, and it applies just as
    // well to this: two readings of one rule drift apart, and the field they
    // would drift on decides whether a legitimate operator keeps their offline
    // unlock. The six cases were measured to agree before swapping.
    //
    // `someoneTyped: true` is not a detail, it IS this call site's whole
    // contribution: the lock screen's password was typed by the operator a
    // second ago. That parameter is required precisely because an earlier
    // version of this function tried to infer it from the exception type, and
    // on this path it inferred wrong — a mistyped password deleted the
    // derivation. Measured, then fixed on his side.
    if (shouldDiscardStoredCredential(error, someoneTyped: true)) {
      await unlockStore.forget(scopeKey);
    }
    return false;
  }
}

/// "Cambiar de usuario": a distinct, explained action from "Cerrar sesión"
/// and from "Bloquear" (ORBI_PRODUCT_ARCHITECTURE_AND_UX_SPEC.md §8). Never
/// discards a draft or the offline queue — both stay durable and isolated
/// per scope (`AppScope.scopeKey` includes `userId`, so
/// `RuntimeDatabaseOwner` opens a distinct database per user;
/// `docs/orbi_panel/decisions/
/// B01-paridad-fiscal-offline-identidad-y-numeracion.md`). This dialog is
/// the explicit warning the spec requires before ending the current
/// identity's access; confirming closes that identity's session before any
/// other identity can authenticate, so the new person can never inherit it.
Future<void> confirmSwitchWorkspaceUser(
  BuildContext context,
  WidgetRef ref,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => ContentDialog(
      title: const Text('Cambiar de usuario'),
      content: const Text(
        'Se cerrará tu acceso a Workspace. Tu borrador y tus operaciones '
        'pendientes de sincronizar quedan guardados con tu propia '
        'identidad: nunca se envían ni se muestran con el usuario que '
        'entre después. ¿Deseas continuar?',
      ),
      actions: [
        Button(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          key: const Key('confirm-switch-user-button'),
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text('Cambiar de usuario'),
        ),
      ],
    ),
  );
  if (confirmed != true) return;
  ref.read(workspaceLockProvider.notifier).unlock();
  await ref.read(authControllerProvider.notifier).close();
  if (context.mounted) context.go('/login');
}

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
  // El sondeo del servidor ya no es nulo. Mientras lo fue, `BackendProbe` era
  // una interfaz que nadie implementaba y el pie sólo podía decir «sin
  // verificar», con el Odoo respondiendo perfectamente.
  final coordinator = SyncCoordinatorImpl(
    jobs: composition.jobs.values,
    backendProbe: Json2BackendProbe(composition.reader),
  );
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
      // `Material` sólo estaba aquí para dar una superficie donde pintar. En
      // Fluent la superficie la pone el tema, así que sobra un widget entero.
      return ColoredBox(
        color: FluentTheme.of(context).scaffoldBackgroundColor,
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
                            ? const ProgressRing()
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

/// Turns the coordinator's real state into the footer's one-line
/// "Sincronización" label. `null` coordinator (no scope/session yet) reads as
/// "no disponible", never as the old permanent "no verificada" — those are
/// different facts and the label should not conflate them.
String _syncStatusLabel(SyncCoordinatorImpl? coordinator, SyncSnapshot? raw) {
  if (coordinator == null) return 'Sincronización no disponible';
  final snapshot = raw ?? coordinator.snapshot;
  if (coordinator.isPaused) return 'Sincronización pausada';
  if (snapshot.active) return 'Sincronizando…';
  if (snapshot.failedCount > 0) {
    return '${snapshot.failedCount} con error';
  }
  if (snapshot.conflictCount > 0) {
    return '${snapshot.conflictCount} en conflicto';
  }
  if (snapshot.queuedCount > 0) {
    return '${snapshot.queuedCount} pendiente(s)';
  }
  return snapshot.lastCompletedAt == null ? 'Sin sincronizar aún' : 'Al día';
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
        // El redirect no puede hablar; deja dicho POR QUÉ y la pantalla de
        // destino lo cuenta. Sin esto, el rechazo es indistinguible de que la
        // aplicación esté rota (ver route_access_messages.dart).
        ref
            .read(routeAccessDenialProvider.notifier)
            .report(location, capabilities: capabilities);
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      ShellRoute(
        builder: (context, state, child) => Consumer(
          builder: (context, ref, _) {
            final profile = auth.profile;
            // Locking lives in its own small `Consumer`, not in this
            // provider's outer scope: watching it up there would make every
            // lock/unlock rebuild the whole `GoRouter` (see
            // `workspaceLockProvider`'s doc comment).
            final locked = ref.watch(workspaceLockProvider);
            // Navigation shares the same gate as direct URLs. Missing context
            // remains explicit; an authenticated client is not proof of network
            // reachability, synchronization, or a fresh server clock.
            final destinations =
                <OperationalDestination>[
                      const OperationalDestination(
                        label: 'Inicio',
                        path: '/',
                        icon: FluentIcons.home,
                        group: 'Workspace',
                      ),
                      const OperationalDestination(
                        label: 'Órdenes y cotizaciones',
                        path: '/sales',
                        icon: FluentIcons.script,
                        group: 'Ventas',
                      ),
                      const OperationalDestination(
                        label: 'Mostrador',
                        path: '/sales/counter',
                        icon: FluentIcons.shop,
                        group: 'Ventas',
                      ),
                      const OperationalDestination(
                        label: 'Venta consultiva',
                        path: '/sales/consultive',
                        icon: FluentIcons.edit_note,
                        group: 'Ventas',
                      ),
                      const OperationalDestination(
                        label: 'Clientes',
                        path: '/clients',
                        icon: FluentIcons.people,
                        group: 'Ventas',
                      ),
                      const OperationalDestination(
                        label: 'Productos',
                        path: '/products',
                        icon: FluentIcons.product,
                        group: 'Ventas',
                      ),
                      const OperationalDestination(
                        label: 'Punto de cobro',
                        path: '/collection',
                        icon: FluentIcons.payment_card,
                        group: 'Caja',
                      ),
                      const OperationalDestination(
                        label: 'Mi turno',
                        path: '/collection/hub',
                        icon: FluentIcons.date_time,
                        group: 'Caja',
                      ),
                      const OperationalDestination(
                        label: 'Operaciones de bodega',
                        path: '/warehouse',
                        icon: FluentIcons.bank_solid,
                        group: 'Bodega',
                      ),
                      const OperationalDestination(
                        label: 'Existencias',
                        path: '/warehouse/existences',
                        icon: FluentIcons.package,
                        group: 'Bodega',
                      ),
                      const OperationalDestination(
                        label: 'Dashboard',
                        path: '/envases',
                        icon: FluentIcons.delivery_truck,
                        group: 'Envases',
                      ),
                      const OperationalDestination(
                        label: 'Solicitudes',
                        path: '/approvals',
                        icon: FluentIcons.check_list,
                        group: 'Aprobaciones',
                      ),
                      const OperationalDestination(
                        label: 'Actividades',
                        path: '/activities',
                        icon: FluentIcons.calendar,
                        group: 'Sistema',
                      ),
                      const OperationalDestination(
                        label: 'Sincronización',
                        path: '/sync',
                        icon: FluentIcons.sync,
                        group: 'Sistema',
                      ),
                      const OperationalDestination(
                        label: 'Avisos',
                        path: '/notifications',
                        icon: FluentIcons.ringer,
                        group: 'Sistema',
                      ),
                      const OperationalDestination(
                        label: 'Configuración',
                        path: '/settings',
                        icon: FluentIcons.settings,
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
            // The footer's "Sincronización" used to be a literal string that
            // never changed regardless of what the coordinator was actually
            // doing — one more "no verificado" next to two others that,
            // unlike this one, really do lack a binding yet (server clock,
            // connectivity — see PENDIENTES.md). This one already has a real
            // source: `SyncCoordinatorImpl.snapshots`, the same stream `/sync`
            // reads. Watched here, not hoisted into `orbiRouterProvider`,
            // for the identical reason `workspaceLockProvider` is watched in
            // this same inner `Consumer`: it must never force the whole
            // `GoRouter` to rebuild.
            final coordinator = ref.watch(scopeSyncCoordinatorProvider);
            // Dos medidas, no una suposición: el transporte del aparato y la
            // respuesta del servidor al último sondeo. Si falta cualquiera de
            // las dos, el resultado dice «sin verificar», nunca «conectado».
            // Y en el navegador el transporte casi siempre existe aunque el
            // Odoo esté caído, así que por sí solo no basta para dar salud.
            final connectionStatus = const ConnectionStatusResolver().resolve(
              network: ref.watch(networkSignalProvider).value,
              backendProbe: coordinator?.lastProbe,
            );
            return StreamBuilder<SyncSnapshot>(
              stream:
                  coordinator?.snapshots ?? const Stream<SyncSnapshot>.empty(),
              initialData: coordinator?.snapshot ?? SyncSnapshot(),
              builder: (context, syncSnapshot) => OperationalShell(
                destinations: destinations,
                selectedPath: state.uri.path,
                onNavigate: (path) => context.go(path),
                context: OperationalContext(
                  server: profile?.serverUrl ?? 'No disponible',
                  database: profile?.database ?? 'No disponible',
                  userLabel: profile?.login ?? 'Usuario no disponible',
                  // The real name travels in the very same response that
                  // already carries `companyId` (`res.users.company_id` on
                  // native, `/orbi/bootstrap`'s `company` on web — see
                  // `OdooActiveIdentityReader.read` and `bootstrap.dart`). The
                  // numeric placeholder is now only what shows when a profile
                  // predates this field or the reader genuinely could not
                  // resolve one — never the default for an authenticated user.
                  companyLabel:
                      profile?.companyName ??
                      (profile?.companyId == null
                          ? 'Empresa no disponible'
                          : 'Empresa #${profile!.companyId}'),
                  // Ya no es una cadena escrita a mano. El estado sale de
                  // dos medidas: si el aparato tiene transporte de red, y si
                  // el Odoo contestó al último sondeo. Cuando falta cualquiera
                  // de las dos, el resultado es «sin verificar» —que es la
                  // verdad— y nunca «conectado».
                  connectionLabel: connectionStatusLabel(connectionStatus),
                  connectionStatus: connectionStatus,
                  syncLabel: _syncStatusLabel(coordinator, syncSnapshot.data),
                ),
                onLogout: () async {
                  await ref.read(authControllerProvider.notifier).close();
                  if (context.mounted) context.go('/login');
                },
                locked: locked,
                onLock: () => ref.read(workspaceLockProvider.notifier).lock(),
                onUnlock: (password) => attemptWorkspaceUnlock(ref, password),
                onSwitchUser: () => confirmSwitchWorkspaceUser(context, ref),
                // `Builder` gives the denial toast a BuildContext that is
                // actually a descendant of `OperationalShell`'s own
                // `Scaffold` — the outer `context` from this route builder
                // is not, so `ScaffoldMessenger.maybeOf` would find nothing.
                //
                // The nested `Consumer` (not a postFrameCallback keyed to
                // THIS widget rebuilding) is deliberate: a denial that
                // redirects back to the page already on screen — the exact
                // shape of "click a link to a forbidden area from Inicio" —
                // resolves to the SAME final location, so go_router does not
                // rebuild this subtree at all. `ref.listen` fires on the
                // provider's own state change, independent of whether
                // anything here rebuilds, so that case is not silently
                // dropped.
                child: Builder(
                  builder: (innerContext) => Consumer(
                    builder: (context, ref, _) {
                      ref.listen<CopyableMessage?>(routeAccessDenialProvider, (
                        _,
                        next,
                      ) {
                        if (next == null || !innerContext.mounted) return;
                        ref.read(routeAccessDenialProvider.notifier).take();
                        final durations = ref
                            .read(
                              appPreferencesProvider(
                                ref.read(preferencesScopeProvider),
                              ),
                            )
                            .snapshot
                            .messageDurations;
                        showCopyableMessage(
                          innerContext,
                          next,
                          durations: durations,
                        );
                      });
                      return child;
                    },
                  ),
                ),
              ),
            );
          },
        ),
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
                  onExport: (ctx, bytes, name) =>
                      exportListingBytes(ctx, ref, bytes, name),
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
                  // La exportación se cablea aquí y no dentro de la pantalla
                  // porque aquí es donde hay con qué leer la preferencia de
                  // cuánto dura el aviso.
                  onExport: (ctx, bytes, name) =>
                      exportListingBytes(ctx, ref, bytes, name),
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
                  onExport: (ctx, bytes, name) =>
                      exportListingBytes(ctx, ref, bytes, name),
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
            path: '/collection/hub',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                final shift = ref.watch(scopeCollectionShiftFutureProvider);
                final profile = ref.watch(authControllerProvider).profile;
                final capabilities = ref.watch(
                  scopeCollectionCapabilitiesProvider,
                );
                return shift.when(
                  loading: () => const NotConfiguredPage(
                    title: 'Caja',
                    detail: 'Cargando turno y punto de cobro…',
                  ),
                  error: (error, stack) =>
                      NotConfiguredPage(title: 'Caja', detail: '$error'),
                  data: (currentShift) => CollectionSessionHubScreen(
                    point: CollectionPointContext(
                      // No hay hoy un mapeo de `collection.session.config_id`
                      // a un nombre de punto (CAJA-BODEGA-01, sección
                      // CAJ-09-v2); se usa el rótulo genérico ya usado para
                      // esta área en el menú en vez de inventar uno.
                      pointLabel: 'Punto de cobro',
                      cashierLabel: profile?.login,
                    ),
                    shift: currentShift,
                    // Anticipo/depósito/salida de efectivo ya viven dentro de
                    // Caja (CAJ-05/06/07); retención SRI (CAJ-04-v2) sigue
                    // sin conectar a propósito, así que no aparece aquí.
                    turnActions: [
                      CollectionHubAction(
                        label: 'Anticipo',
                        description: 'Registrar un anticipo del cliente contra la sesión.',
                        icon: FluentIcons.money,
                        availability:
                            capabilities.supports(CollectionCapability.advances)
                            ? CollectionHubActionAvailability.available
                            : CollectionHubActionAvailability.forbidden,
                        onOpen: () => context.go('/collection'),
                      ),
                      CollectionHubAction(
                        label: 'Depósito',
                        description: 'Registrar un depósito de la sesión.',
                        icon: FluentIcons.bank,
                        availability:
                            capabilities.supports(CollectionCapability.deposits)
                            ? CollectionHubActionAvailability.available
                            : CollectionHubActionAvailability.forbidden,
                        onOpen: () => context.go('/collection'),
                      ),
                      CollectionHubAction(
                        label: 'Salida de efectivo',
                        description:
                            'Registrar una salida de efectivo de la sesión.',
                        icon: FluentIcons.share,
                        availability:
                            capabilities.supports(CollectionCapability.cashOuts)
                            ? CollectionHubActionAvailability.available
                            : CollectionHubActionAvailability.forbidden,
                        onOpen: () => context.go('/collection'),
                      ),
                    ],
                    // CAJ-02 (registros del turno) todavía no tiene pantalla
                    // propia: se deja sin `onOpen` a propósito, nunca un
                    // destino inventado.
                    recordActions: const [
                      CollectionHubAction(
                        label: 'Registros del turno',
                        description:
                            'Órdenes, facturas y pagos de la sesión abierta.',
                        icon: FluentIcons.bulleted_list,
                      ),
                    ],
                    closing: CollectionHubAction(
                      label: 'Ir a cierre',
                      description:
                          'Iniciar el control de cierre de la sesión actual.',
                      icon: FluentIcons.date_time,
                      onOpen: () => context.go('/collection'),
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
            path: '/warehouse/existences',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                final repository = ref.watch(
                  warehouseExistencesRepositoryProvider,
                );
                if (repository == null) {
                  return const NotConfiguredPage(title: 'Existencias');
                }
                return WarehouseExistencesScreen(repository: repository);
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
                : OrbiPage(
                    title: 'Actividades',
                    child: ActivityCenterView(
                      port:
                          composition.activities ??
                          ref.read(scopeActivityPortProvider)!,
                    ),
                  ),
          ),
          GoRoute(
            path: '/sync',
            builder: (context, state) {
              // Same queue the "Operaciones pendientes" catalog status reads
              // from (see `CoordinatorSyncCenterPort` below); the conflict
              // resolution screen (SYN-03) is built on top of the identical
              // live `OfflineQueueStore`, never a second one.
              final operationsJob =
                  composition.catalogs?.jobs['operations']
                      as OperationsSyncJob?;
              if (composition.sync == null &&
                  ref.read(scopeSyncCoordinatorProvider) == null) {
                return const NotConfiguredPage(title: 'Sincronización');
              }
              return ProviderScope(
                overrides: [
                  syncCenterPortProvider.overrideWithValue(
                    composition.sync ??
                        CoordinatorSyncCenterPort(
                          ref.read(scopeSyncCoordinatorProvider)!,
                          operations: operationsJob,
                        ),
                  ),
                ],
                child: OrbiPage(
                  title: 'Sincronización',
                  child: SyncCenterView(
                    onOpenConflicts: () {
                      final queue = operationsJob?.queue;
                      Navigator.of(context).push(
                        FluentPageRoute<void>(
                          builder: (_) => queue == null
                              ? const NotConfiguredPage(
                                  title: 'Resolver conflicto',
                                  detail:
                                      'Sin cola de operaciones disponible '
                                      'en este scope.',
                                )
                              : SyncConflictResolutionPage(queue: queue),
                        ),
                      );
                    },
                  ),
                ),
              );
            },
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
                child: OrbiPage(
                  title: 'Avisos',
                  child: NotificationInboxView(
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
                : OrbiPage(
                    title: 'Documento',
                    child: DocumentView(
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
