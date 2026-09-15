import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    show OdooMethodNotFoundException, OdooNotFoundException;
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/account/user_preferences_dialog.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/login_failure_messages.dart';
import '../features/auth/pin_credential_store.dart';
import '../features/auth/route_access_messages.dart';
import '../ui/components/copyable_message.dart';
import '../features/auth/route_access_policy.dart';
import '../features/auth/workspace_unlock_store.dart';
import '../features/collection/collection_screen.dart';
import '../features/collection/collection_contracts.dart';
import '../features/collection/collection_session_hub_screen.dart';
import '../features/collection/collection_supervised_session_screen.dart';
import '../features/approvals/approval_contracts.dart';
import '../features/approvals/approvals_screen.dart';
import '../features/auth/saved_servers.dart';
import '../features/home/home_dashboard_providers.dart'
    show homeCashSessionsProvider;
import '../features/notifications/notification_inbox.dart';
import '../features/sales/sale_editor.dart';
import '../features/sales/durable_sale_draft_store.dart';
import '../features/sales/sale_draft_workspace.dart';
import '../features/sales/sale_draft_workspace_bar.dart';
import '../features/sales/legacy_draft_inspector.dart';
import '../features/sales/legacy_draft_notice.dart';
import '../features/settings/settings_screen.dart';
import 'device_name_store.dart';
import '../features/orders/orders_screen.dart';
import '../features/orders/orders_contracts.dart';
import '../features/warehouse/warehouse_screen.dart';
import '../features/warehouse/warehouse_existences_screen.dart';
import 'last_location_store.dart';
import 'warehouse_existences_composition.dart';
import '../features/clients/catalog_contracts.dart';
import '../features/clients/clients_screen.dart';
import '../features/products/products_screen.dart';
import 'preferences/app_preferences.dart';
import '../features/activities/activity_center.dart';
import '../features/reports/document_view.dart';
import '../features/sync/app_foreground_signal.dart';
import '../features/sync/network_signal_provider.dart';
import '../ui/export/export_listing.dart';
import '../ui/fluent/orbi_page.dart';
import '../features/sync/sync_center.dart';
import '../features/sync/sync_conflict_resolution_screen.dart';
import '../features/sync/offline_queue_screen.dart';
import '../features/sync/sync_data_screen.dart';
import '../ui/home_page.dart';
import '../ui/layouts/operational_shell.dart';
import '../ui/shell/desktop_close_guard.dart';
import 'session_composition.dart';
import 'notification_scope_adapter.dart';
import 'u08_scope_adapters.dart';
import 'order_scope_repository.dart';
import 'collection_scope_composition.dart';
import 'scope_catalog_repository.dart';
import 'business_composition_factory.dart';
import 'envases_composition.dart';

/// Pasado como `extra` a `context.go('/login', extra: startInPinModeExtra)`
/// para que "Cambiar de usuario" ([confirmSwitchWorkspaceUser]) pueda
/// aterrizar directo en la puerta de PIN (ACC-02) cuando queda al menos otro
/// usuario con PIN en esta base — NUNCA una dirección propia: `/login` sigue
/// siendo la única ruta previa a iniciar sesión que conoce
/// `RouteAccessPolicy` (ver la nota de clase de `pin_login_screen.dart`:
/// «PIN only ever makes sense as a sibling of this very form, never as an
/// address someone could type or bookmark on its own»). Un `context.go`
/// directo a `/login` sin este `extra` (o tecleando la URL) nunca lo
/// arrastra consigo.
const Object startInPinModeExtra = _StartInPinMode();

final class _StartInPinMode {
  const _StartInPinMode();
}

final businessCompositionFactoryProvider =
    Provider<OrbiBusinessCompositionFactory>(
      (ref) => OrbiBusinessCompositionFactory(
        // `ref.read` dentro del closure, no `ref.watch`: se evalúa recién
        // cuando `SessionApprovalPort.pending()` corre, no cuando se
        // construye la fábrica (una sola vez por sesión) — mismo motivo por
        // el que `redirect` en este archivo también usa `ref.read` para leer
        // estado que cambia durante la sesión.
        approvalsAvailable: () =>
            ref.read(serverFeaturesProvider).isAvailable(ServerFeature.approvals),
      ),
    );

/// Manual privacy gate for the operational shell (ACC-03, "bloquear").
/// Deliberately a plain, always-on provider outside [orbiRouterProvider]:
/// that provider builds a single, stable [GoRouter] for the whole session
/// (see its own comment and `_AuthRouterRefresh`) — a lock flag watched at
/// that level would sit next to state that legitimately triggers a
/// `redirect` re-evaluation, and a future edit could too easily fold it into
/// that same refresh. Keeping it in its own always-on provider, read only by
/// the inner `Consumer` that needs it, means locking/unlocking can never
/// touch navigation at all — not even a `redirect` re-check. It also must
/// never expire on its own — the shell spec is explicit that no new timeout
/// is invented here.
final workspaceLockProvider = NotifierProvider<WorkspaceLockNotifier, bool>(
  WorkspaceLockNotifier.new,
);

/// Where the workspace lock lives across reloads. Reported by the owner
/// (13-sep-2026): locking and then reloading the browser showed Home again
/// without asking for the password, because the lock only lived in process
/// memory and a real reload wipes it.
const _kWorkspaceLockedKey = 'orbi/workspace/locked';

class WorkspaceLockNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref.watch(sharedPreferencesProvider).getBool(_kWorkspaceLockedKey) ??
      false;

  void lock() {
    state = true;
    unawaited(
      ref.read(sharedPreferencesProvider).setBool(_kWorkspaceLockedKey, true),
    );
  }

  void unlock() {
    state = false;
    unawaited(
      ref.read(sharedPreferencesProvider).setBool(_kWorkspaceLockedKey, false),
    );
  }
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
  // «El PIN mantiene el tope de vendedor al entrar o cambiar de usuario»
  // (decisión del dueño, 14-sep-2026): si en esta MISMA base queda al menos
  // OTRO usuario con PIN retenido y enrolado en este equipo, "Cambiar de
  // usuario" aterriza directo en la puerta de PIN con su selector — nunca
  // el propio PIN de quien se está yendo, que ya cerró sesión arriba. Sin
  // otro candidato, cae al acceso normal exactamente como antes.
  final leavingProfile = ref.read(authControllerProvider).profile;
  ref.read(workspaceLockProvider.notifier).unlock();
  await ref.read(authControllerProvider.notifier).close();
  if (!context.mounted) return;
  var startInPin = false;
  if (leavingProfile != null) {
    final candidates = await ref
        .read(authControllerProvider.notifier)
        .pinRetainedProfilesFor(leavingProfile.serverUrl, leavingProfile.database);
    PinCredentialStore? pinStore;
    try {
      pinStore = ref.read(pinCredentialStoreProvider);
    } catch (_) {
      // Embedders/tests may intentionally omit the PIN store.
    }
    if (pinStore != null) {
      final resolvedStore = pinStore;
      startInPin = candidates.any(
        (candidate) =>
            candidate.login != leavingProfile.login &&
            resolvedStore.isEnrolled(
              pinScopeKeyFor(
                candidate.serverUrl,
                candidate.database,
                candidate.login,
              ),
            ),
      );
    }
  }
  if (!context.mounted) return;
  context.go('/login', extra: startInPin ? startInPinModeExtra : null);
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
  // ----- INICIO bloque aislado: renovación de clave (auditoría de sesión,
  // 13-sep-2026) — «la app en línea» de `ApiKeyRenewalDecision` es, en la
  // práctica, cada ciclo de este coordinador. `ref.read`, no `watch`: el
  // servicio de auth no cambia mientras la sesión está activa, y este
  // provider no debe reconstruirse por algo ajeno al scope/composición.
  final authService = ref.read(authServiceProvider);
  final apiKeyRenewal = authService is RenewableAuthServicePort
      ? (AppScope _) =>
            (authService as RenewableAuthServicePort).renewApiKeyIfNeeded()
      : null;
  // ----- FIN bloque aislado -----
  final coordinator = SyncCoordinatorImpl(
    jobs: composition.jobs.values,
    backendProbe: Json2BackendProbe(composition.reader),
    apiKeyRenewal: apiKeyRenewal,
  );
  unawaited(coordinator.start(active.scope));
  ref.onDispose(coordinator.dispose);
  return coordinator;
});

// --- Bloque aislado: re-sincronización automática (13-sep-2026) ----------
// Antes de esto, `requestSync` sólo corría una vez al abrir el scope y bajo
// el botón manual "Reintentar sincronización" de /sync — recuperar la red
// o volver a la app no revivía nada (auditoría de conectividad/sync del
// 13-sep-2026). `SyncAutoResyncTrigger` vive en `orbi_runtime` y es
// agnóstico de Flutter; aquí sólo se le conectan las dos señales reales que
// router.dart ya observa para el pie de página. Deliberadamente en su
// propio bloque, sin tocar nada más de este archivo, mientras otras
// auditorías siguen trabajando en el resto de router.dart.
final _appForegroundSignalProvider = Provider<AppForegroundSignal>((ref) {
  final signal = AppForegroundSignal();
  ref.onDispose(signal.dispose);
  return signal;
});

final scopeSyncAutoResyncTriggerProvider = Provider<SyncAutoResyncTrigger?>((
  ref,
) {
  final coordinator = ref.watch(scopeSyncCoordinatorProvider);
  if (coordinator == null) return null;
  final foreground = ref.watch(_appForegroundSignalProvider);
  // `StreamProvider` no expone su `Stream` crudo en esta versión de
  // Riverpod; `ref.listen` es el puente hacia el `Stream<bool>` que
  // `SyncAutoResyncTrigger` necesita, sin envolver nada en `AsyncValue`.
  final onlineController = StreamController<bool>.broadcast();
  ref.listen<AsyncValue<NetworkSignal>>(networkSignalProvider, (
    previous,
    next,
  ) {
    final signal = next.value;
    if (signal != null && !onlineController.isClosed) {
      onlineController.add(signal.hasNetwork);
    }
  }, fireImmediately: true);
  final trigger = SyncAutoResyncTrigger(
    coordinator: coordinator,
    online: onlineController.stream,
    foreground: foreground.stream,
  );
  ref.onDispose(() {
    trigger.dispose();
    unawaited(onlineController.close());
  });
  return trigger;
});
// --- Fin del bloque aislado ------------------------------------------------

// --- Bloque aislado: tiempo real (13-sep-2026) ------------------------------
// Un aviso `app_sync/changed` de Odoo (módulo `l10n_ec_app_sync`) es una PISTA:
// dispara la sincronización incremental SÓLO del catálogo afectado, por el mismo
// coordinador, así que se guarda en local y las pantallas se refrescan por sus
// `watch`. Si el servidor no tiene el módulo (404), queda `disabled` y la app
// sigue con la sincronización periódica. Ver orbi_runtime/lib/src/realtime/.
//
// Modelo de Odoo → `SyncJob` de catálogo. Verificado contra `RuntimeCatalogs` y
// contra lo que avisa el servidor (`_app_sync_tracked_models` en l10n_ec_app_sync
// y l10n_ec_collection_box_pos). Fuera a propósito: `product.template` (el
// servidor lo traduce a avisos de `product.product`) y `product.pricelist.item`
// (el catálogo de tarifas sólo lee cabeceras).
const _realtimeModelJobIds = <String, Set<String>>{
  // Bloque de sync-cuenta (13-sep-2026): un aviso de `res.partner` también
  // dispara el catálogo del PROPIO usuario (su `res.partner`, el que lee
  // «Mis preferencias»), y uno de `res.users` dispara el catálogo del
  // usuario mismo — ninguno de los dos existía antes de la presencia y las
  // preferencias personales.
  // Bloque de sync-cuenta (13-sep-2026): un aviso de `res.partner` también
  // dispara el catálogo del PROPIO usuario (su `res.partner`, el que lee
  // «Mis preferencias»), y uno de `res.users` dispara el catálogo del
  // usuario mismo — ninguno de los dos existía antes de la presencia y las
  // preferencias personales.
  'res.partner': {'catalog:partner', 'catalog:currentUserPartner'},
  'res.users': {'catalog:currentUser'},
  'product.product': {'catalog:product'},
  'account.payment.term': {'catalog:paymentTerm'},
  'uom.uom': {'catalog:uom'},
  'account.tax': {'catalog:tax'},
  'product.pricelist': {'catalog:pricelist'},
  'stock.warehouse': {'catalog:warehouse'},
  'account.journal': {'catalog:journal'},
  'account.credit.card.brand': {'catalog:cardBrand'},
  'account.credit.card.deadline': {'catalog:cardDeadline'},
  'account.card.lote': {'catalog:cardLote'},
  'account.payment.method.line': {'catalog:paymentMethodLine'},
  'collection.config': {'catalog:collectionConfig'},
  'collection.session': {'catalog:collectionSession'},
};

const _realtimeLastKey = 'realtime/last';

/// Sólo para pruebas: `_realtimeModelJobIds` es privado, y no hay otra forma
/// de comprobar el mapa sin montar un `RealtimeSyncCoordinator` completo.
@visibleForTesting
const realtimeModelJobIdsForTesting = _realtimeModelJobIds;

// --- Bloque aislado: Modo Ruta (13-sep-2026) --------------------------------
// La pausa por Modo Ruta la aplicaba sólo el callback de Configuración: con el
// Modo Ruta guardado como activo, al volver a abrir la app la sincronización NO
// quedaba en pausa. Ahora la aplica la preferencia persistida, esté abierta la
// pantalla que sea (el interruptor vive en Sincronización). Sólo actúa cuando el
// valor CAMBIA: así no reanuda la pausa de mantenimiento de la pantalla de
// Sincronización cuando cambia otra preferencia, como el tema.
final scopeRouteModePauseProvider = Provider<void>((ref) {
  final coordinator = ref.watch(scopeSyncCoordinatorProvider);
  if (coordinator == null) return;
  final preferences = ref.watch(
    appPreferencesProvider(ref.watch(preferencesScopeProvider)),
  );
  bool? applied;
  void apply() {
    final enabled = preferences.snapshot.routeMode;
    if (enabled == applied) return;
    applied = enabled;
    if (enabled) {
      unawaited(coordinator.pause(PauseReason('route_mode')));
    } else if (coordinator.isPaused) {
      unawaited(coordinator.resume());
    }
  }

  apply();
  preferences.addListener(apply);
  ref.onDispose(() => preferences.removeListener(apply));
});
// --- Fin del bloque aislado ------------------------------------------------

final scopeRealtimeSyncCoordinatorProvider = Provider<RealtimeSyncCoordinator?>(
  (ref) {
    final coordinator = ref.watch(scopeSyncCoordinatorProvider);
    final runtime = ref.watch(runtimeSessionProvider);
    final active = runtime?.active;
    if (coordinator == null || runtime == null || active == null) return null;
    final client = active.client;
    if (client == null) {
      // Sesión sin conexión: no hay socket que abrir.
      return null;
    }

    final metadata = RuntimeMetadataStore(runtime);
    final lease = active.lease;
    final authService = ref.read(authServiceProvider);
    final apiKeyRenewal = authService is RenewableAuthServicePort
        ? (AppScope _) =>
              (authService as RenewableAuthServicePort).renewApiKeyIfNeeded()
        : null;

    // Mismo puente red → Stream<bool> que el bloque de re-sincronización.
    final onlineController = StreamController<bool>.broadcast();
    ref.listen<AsyncValue<NetworkSignal>>(networkSignalProvider, (
      previous,
      next,
    ) {
      final signal = next.value;
      if (signal != null && !onlineController.isClosed) {
        onlineController.add(signal.hasNetwork);
      }
    }, fireImmediately: true);

    final realtime = RealtimeSyncCoordinator(
      syncCoordinator: coordinator,
      modelJobIds: _realtimeModelJobIds,
      sessionClientFor: (_) => OdooRealtimeSessionClient(client),
      readLastNotificationId: (_) async {
        final raw = await metadata.read(_realtimeLastKey, lease: lease);
        return raw == null ? null : int.tryParse(raw);
      },
      writeLastNotificationId: (_, value) async {
        // El `last` es del ámbito: si la sesión ya cambió, no se escribe.
        if (!runtime.accepts(lease)) {
          return;
        }
        await metadata.write(_realtimeLastKey, '$value', lease: lease);
      },
      online: onlineController.stream,
      activeCompanyId: () => ref.read(capabilitySnapshotProvider)?.companyId,
      apiKeyRenewal: apiKeyRenewal,
    );
    unawaited(realtime.start(active.scope));
    ref.onDispose(() {
      unawaited(realtime.dispose());
      unawaited(onlineController.close());
    });
    return realtime;
  },
);
// --- Fin del bloque aislado ------------------------------------------------

// --- Bloque aislado: respaldo periódico de sincronización (14-sep-2026,
// hueco 2 de la auditoría de tiempo real) -----------------------------------
// `SyncAutoResyncTrigger` sólo reacciona a FILOS (red que vuelve, app que
// vuelve al frente): si el socket de tiempo real se cae sin que ninguna de
// esas dos señales cambie, nada volvía a sincronizar solo hasta que la
// persona abriera «Sincronización» a mano. `SyncPeriodicBackupTrigger`
// (`orbi_runtime`) cubre ese hueco con un sondeo cada 5 minutos, pero SÓLO
// mientras el tiempo real no esté conectado — se arma y desarma solo según
// el estado que ya publica `scopeRealtimeSyncCoordinatorProvider`.
final scopeSyncPeriodicBackupTriggerProvider =
    Provider<SyncPeriodicBackupTrigger?>((ref) {
  final coordinator = ref.watch(scopeSyncCoordinatorProvider);
  if (coordinator == null) return null;
  final foreground = ref.watch(_appForegroundSignalProvider);
  final realtime = ref.watch(scopeRealtimeSyncCoordinatorProvider);

  // Mismo puente red → Stream<bool> que los otros dos bloques aislados de
  // este archivo (auto-resync y tiempo real): `ref.listen` es el único modo
  // de leer el `Stream<bool>` crudo de un `StreamProvider` en esta versión
  // de Riverpod.
  final onlineController = StreamController<bool>.broadcast();
  ref.listen<AsyncValue<NetworkSignal>>(networkSignalProvider, (
    previous,
    next,
  ) {
    final signal = next.value;
    if (signal != null && !onlineController.isClosed) {
      onlineController.add(signal.hasNetwork);
    }
  }, fireImmediately: true);

  // Sin coordinador de tiempo real (sesión sin conexión) el respaldo debe
  // poder armarse igual — se alimenta con un estado fijo de "no conectado",
  // nunca `live`, para que el temporizador nunca quede desarmado por falta
  // de señal.
  final realtimeStatusController = StreamController<RealtimeStatus>.broadcast();
  if (realtime != null) {
    final subscription = realtime.status.listen(realtimeStatusController.add);
    ref.onDispose(() => unawaited(subscription.cancel()));
    realtimeStatusController.add(realtime.currentStatus);
  } else {
    realtimeStatusController.add(RealtimeStatus.offline);
  }

  final trigger = SyncPeriodicBackupTrigger(
    coordinator: coordinator,
    online: onlineController.stream,
    foreground: foreground.stream,
    realtimeStatus: realtimeStatusController.stream,
  );
  ref.onDispose(() {
    unawaited(trigger.dispose());
    unawaited(onlineController.close());
    unawaited(realtimeStatusController.close());
  });
  return trigger;
});
// --- Fin del bloque aislado ------------------------------------------------

// --- Bloque aislado: hora del servidor (14-sep-2026) ------------------------
// `ClientPolicyService` (`orbi_runtime`) sincroniza la hora del servidor y
// los dos límites de sesión offline con `app.sync.client.policy.client_policy()`
// — un método de `l10n_ec_app_sync` 19.1.5 todavía SIN desplegar en ningún
// servidor: hasta que lo esté, cualquier Odoo responde "el modelo no existe"
// y el servicio cae solo a la hora del equipo (`ClientPolicyTimeSource.device`).
// `RuntimeMetadataStore` guarda lo último por scope, igual que ya hace el
// puente de tiempo real más arriba (`_realtimeLastKey`).
//
// `ClientPolicyService.snapshot` no es reactivo por su cuenta (es una clase
// de `orbi_runtime`, sin Riverpod): `_clientPolicyRevisionProvider` es el
// puente — cada sincronización real (al entrar, al volver a primer plano, o
// cada 15 minutos) lo incrementa, y `serverClockStatusProvider` lo observa
// para volver a leer el snapshot más fresco.
const _clientPolicyStateKey = 'client_policy/state';

final _clientPolicyRevisionProvider =
    NotifierProvider<_ClientPolicyRevisionNotifier, int>(
      _ClientPolicyRevisionNotifier.new,
    );

class _ClientPolicyRevisionNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state++;
}

/// Límite de sesión sin conexión (14-sep-2026): `OfflineAllowanceStore`
/// (`orbi_runtime`) vive sobre las mismas `SharedPreferences` que el resto de
/// la sesión — nunca en la base del scope, ver la doc de esa clase.
final _offlineAllowanceStoreProvider = Provider<OfflineAllowanceStore>(
  (ref) => OfflineAllowanceStore(ref.watch(sharedPreferencesProvider)),
);

final _clientPolicyServiceProvider = Provider<ClientPolicyService?>((ref) {
  final runtime = ref.watch(runtimeSessionProvider);
  final active = runtime?.active;
  if (runtime == null || active == null) return null;
  final metadata = RuntimeMetadataStore(runtime);
  final lease = active.lease;
  final profile = ref.watch(authControllerProvider).profile;
  final allowanceStore = ref.watch(_offlineAllowanceStoreProvider);
  final service = ClientPolicyService.fromSession(
    sessions: runtime,
    readState: () => metadata.read(_clientPolicyStateKey, lease: lease),
    writeState: (json) =>
        metadata.write(_clientPolicyStateKey, json, lease: lease),
    // Límite de sesión sin conexión (14-sep-2026): cada sincronización real
    // trae el `offline_max_days` que de verdad configuró ESTE servidor —
    // se registra junto con la conexión buena, para que el plazo use ese
    // valor en vez del por omisión (3) hasta la próxima sincronización.
    onServerSynced: profile == null
        ? null
        : (snapshot) => unawaited(
            allowanceStore.recordServerSync(
              serverUrl: profile.serverUrl,
              database: profile.database,
              userId: profile.userId,
              offlineMaxDays: snapshot.offlineMaxDays,
              nowUtc: DateTime.now().toUtc(),
            ),
          ),
  );

  // Tras entrar o restaurar SESIÓN EN LÍNEA: una sincronización inmediata,
  // sin esperar al primer tic de 15 minutos del disparador de abajo. Sólo
  // cuando hay cliente — `sync()` ya no hace nada sin uno («no client means
  // no rpc»), así que dispararlo offline sería un `unawaited` que nunca
  // sirve de nada. El servicio en sí SÍ se construye sin cliente: la
  // estimación sin conexión (`isEstimated`/`nowServer()`) necesita poder
  // leer lo último persistido igual, sesión sin conexión o no.
  // `ref.mounted` antes de tocar `ref` — revisión del dueño, 14-sep-2026:
  // `sync()` puede seguir en vuelo cuando la sesión ya cerró (el provider
  // se desechó), y Riverpod lanza si se usa un `ref` desechado.
  if (active.client != null) {
    unawaited(
      service.sync().then((_) {
        if (!ref.mounted) return;
        ref.read(_clientPolicyRevisionProvider.notifier).bump();
      }),
    );
  }
  return service;
});

final _clientPolicySyncTriggerProvider = Provider<ClientPolicySyncTrigger?>((
  ref,
) {
  final service = ref.watch(_clientPolicyServiceProvider);
  // Sesión sin conexión: no hay con qué sincronizar, así que ni siquiera se
  // arma el temporizador de 15 minutos — mismo patrón que
  // `scopeRealtimeSyncCoordinatorProvider` ("Sesión sin conexión: no hay
  // socket que abrir"). Medido el 14-sep-2026: sin esta comprobación, una
  // sesión sin `apiKey` (perfectamente válida y offline-first) terminaba
  // armando un `Timer.periodic` real que nunca hacía nada — y que, tras
  // corregir que el temporizador arrancara solo, dejaba un
  // "Timer is still pending" en cualquier prueba que montara el marco así.
  final client = ref.watch(runtimeSessionProvider)?.active?.client;
  if (service == null || client == null) return null;
  final foreground = ref.watch(_appForegroundSignalProvider);

  Future<void> syncAndBump() async {
    await service.sync();
    if (!ref.mounted) return;
    ref.read(_clientPolicyRevisionProvider.notifier).bump();
  }

  final onlineController = StreamController<bool>.broadcast();
  final trigger = ClientPolicySyncTrigger(
    sync: syncAndBump,
    online: onlineController.stream,
    foreground: foreground.stream,
  );

  // 🔴 El trigger ya está suscrito a `onlineController.stream` ANTES de
  // este `ref.listen` — revisión del dueño, 14-sep-2026: `fireImmediately:
  // true` llama al callback de forma SÍNCRONA, así que si el `ref.listen`
  // fuera antes de construir el trigger, ese primer `add()` se perdería —
  // un `StreamController.broadcast()` no guarda buffer para quien llegue
  // tarde a escuchar. `ClientPolicySyncTrigger` igual arranca su propio
  // temporizador al construirse (ver su constructor), así que este orden
  // es un refuerzo, no la única red de seguridad.
  ref.listen<AsyncValue<NetworkSignal>>(networkSignalProvider, (
    previous,
    next,
  ) {
    final signal = next.value;
    if (signal != null && !onlineController.isClosed) {
      onlineController.add(signal.hasNetwork);
    }
  }, fireImmediately: true);

  ref.onDispose(() {
    unawaited(trigger.dispose());
    unawaited(onlineController.close());
  });
  return trigger;
});

/// `ServerClockStatus` para el pie del armazón (`OperationalContext.serverClock`)
/// — `null` sin sesión activa, que deja el pie con la hora local cruda, el
/// comportamiento de antes de este bloque.
///
/// La zona horaria SIEMPRE sale de Odoo (`user_tz_offset_minutes`,
/// `ClientPolicySnapshot.userTzOffset`) cuando el servidor la trae. Revisión
/// del dueño, 14-sep-2026: la tabla fija de zonas conocidas que hacía esto
/// antes sólo servía para Ecuador y zonas sin horario de verano — Orbi debe
/// funcionar con cualquier Odoo. Cuando el servidor no la trae (módulo
/// viejo sin este campo, o "el modelo no existe"), se usa el desfase de la
/// zona DEL EQUIPO (`DateTime.now().timeZoneOffset`) — nunca un desfase
/// inventado — y `usesDeviceTzFallback` se lo dice al pie para que el
/// detalle aclare "en la zona de este equipo".
final serverClockStatusProvider = Provider<ServerClockStatus?>((ref) {
  final service = ref.watch(_clientPolicyServiceProvider);
  // Mantiene vivo el disparador periódico mientras haya sesión — su
  // resultado no se lee directamente, sólo a través de la revisión de abajo.
  ref.watch(_clientPolicySyncTriggerProvider);
  ref.watch(_clientPolicyRevisionProvider);
  if (service == null) return null;
  final snapshot = service.snapshot;
  final serverTzOffset = snapshot.userTzOffset;
  return ServerClockStatus(
    nowServer: service.nowServer,
    userTzOffset: serverTzOffset ?? DateTime.now().timeZoneOffset,
    usesDeviceTzFallback: serverTzOffset == null,
    source: snapshot.source,
    isEstimated: snapshot.isEstimated,
    rtt: snapshot.rtt,
    lastSyncAt: snapshot.lastSyncAt,
    lastOnlineAt: snapshot.lastOnlineAt,
    clockRollbackSuspected: snapshot.clockRollbackSuspected,
  );
});
// --- Fin del bloque aislado ------------------------------------------------

// --- Bloque aislado: límite de sesión sin conexión (14-sep-2026) -----------
// Decisión del dueño: máximo `offline_max_days` (3 por omisión,
// parametrizable en Odoo) sin hablar con el servidor. `OfflineAllowanceStore`
// (`orbi_runtime`) ya lo hace cumplir en el arranque
// (`NativeAuthService.restore(offline: true)`, que nunca activa la sesión
// vencida). Este bloque cubre el otro caso: la app se queda abierta SIN
// conexión hasta pasar el plazo — revisa cada minuto y bloquea el armazón
// con un mensaje, sin cerrar sesión ni tocar nada local. Se destraba solo en
// cuanto vuelve a sincronizar (`_offlineAllowanceStoreProvider.evaluate`
// vuelve a decir `allowed`).
/// Cada cuánto se repite la revisión — `null` por omisión APAGA el
/// temporizador (mismo patrón que `OperationalShell.clockTickInterval` para
/// `_FooterClock`): un `Timer.periodic` vivo nunca deja terminar a
/// `tester.pumpAndSettle()`, y la inmensa mayoría de las pruebas de este
/// paquete arman sesiones SIN conexión (`activate(scope)`, sin `apiKey`) a
/// propósito, para no tocar la red — justo el caso que arma este
/// temporizador. `bootstrap.dart` lo sobreescribe a un minuto en producción;
/// ninguna prueba de este paquete necesita tocarlo.
final offlineAllowanceCheckIntervalProvider = Provider<Duration?>(
  (ref) => null,
);

final _offlineAllowanceBlockMessageProvider =
    NotifierProvider<_OfflineAllowanceBlockNotifier, String?>(
      _OfflineAllowanceBlockNotifier.new,
    );

class _OfflineAllowanceBlockNotifier extends Notifier<String?> {
  Timer? _timer;

  @override
  String? build() {
    final runtime = ref.watch(runtimeSessionProvider);
    final active = runtime?.active;
    final profile = ref.watch(authControllerProvider).profile;
    final interval = ref.watch(offlineAllowanceCheckIntervalProvider);
    ref.onDispose(() => _timer?.cancel());
    _timer?.cancel();
    _timer = null;
    // En línea (hay cliente), o sin sesión activa: nada que vigilar aquí —
    // el caso "ya estaba vencida al abrir" lo rechaza `restore()` antes de
    // llegar a pintar este armazón.
    if (active == null || active.client != null || profile == null) {
      return null;
    }
    if (interval != null) {
      _timer = Timer.periodic(interval, (_) => unawaited(_check(profile)));
    }
    unawaited(_check(profile));
    return null;
  }

  Future<void> _check(AuthProfile profile) async {
    final store = ref.read(_offlineAllowanceStoreProvider);
    final allowance = await store.evaluate(
      serverUrl: profile.serverUrl,
      database: profile.database,
      userId: profile.userId,
      deviceNowUtc: DateTime.now().toUtc(),
    );
    if (!ref.mounted) return;
    state = _offlineAllowanceMessageFor(allowance);
  }
}

String? _offlineAllowanceMessageFor(OfflineAllowance allowance) {
  switch (allowance.status) {
    case OfflineAllowanceStatus.allowed:
      return null;
    case OfflineAllowanceStatus.expired:
      final days = allowance.daysOffline ?? allowance.maxDays ?? kDefaultOfflineAllowanceDays;
      final max = allowance.maxDays ?? kDefaultOfflineAllowanceDays;
      return 'Llevas $days días sin conectarte con Odoo (el máximo es $max). '
          'Conéctate a internet para seguir; tus datos y lo pendiente se '
          'conservan.';
    case OfflineAllowanceStatus.clockRollback:
      return 'La fecha de este equipo está atrasada; corrígela y '
          'conéctate a internet.';
  }
}
// --- Fin del bloque aislado ------------------------------------------------

// --- Bloque aislado: sesión expirada en caliente (auditoría de sesión,
// 13-sep-2026) ---------------------------------------------------------------
// El coordinador ya publica `SyncSnapshot.sessionExpired` (derivado de
// `SyncFailure.authStatus == AuthStatus.expired`) cada vez que el sondeo o un
// trabajo de sincronización se topan con un 401. Estos dos providers sólo le
// dan forma reactiva a Riverpod a ese stream que `SyncCoordinatorImpl` ya
// expone — el `ref.listen` que realmente actúa sobre la señal vive dentro del
// `Consumer` de más abajo, donde ya se construye `OperationalShell`.
final scopeSyncSnapshotStreamProvider = StreamProvider<SyncSnapshot>((ref) {
  final coordinator = ref.watch(scopeSyncCoordinatorProvider);
  if (coordinator == null) return const Stream<SyncSnapshot>.empty();
  return coordinator.snapshots;
});

final sessionExpiredSignalProvider = Provider<bool>((ref) {
  final snapshot = ref.watch(scopeSyncSnapshotStreamProvider).value;
  return snapshot?.sessionExpired ?? false;
});
// --- Fin del bloque aislado ------------------------------------------------

// --- Bloque aislado: estado del tiempo real visible (14-sep-2026, hueco 1
// de la auditoría de tiempo real) --------------------------------------------
// Mismo patrón que `scopeSyncSnapshotStreamProvider` justo arriba: le da
// forma reactiva de Riverpod al `Stream<RealtimeStatus>` que
// `RealtimeSyncCoordinator` ya expone, para que la píldora de la barra
// superior (`OperationalContext.realtimeStatus`) se repinte sola. Antes de
// esto, el único `ref.watch(scopeRealtimeSyncCoordinatorProvider)` del
// archivo sólo mantenía vivo al coordinador — nada leía su estado.
final scopeRealtimeStatusStreamProvider = StreamProvider<RealtimeStatus>((
  ref,
) {
  final realtime = ref.watch(scopeRealtimeSyncCoordinatorProvider);
  if (realtime == null) return const Stream<RealtimeStatus>.empty();
  return realtime.status;
});
// --- Fin del bloque aislado ------------------------------------------------

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

/// Clave de `SharedPreferences` para la última versión de Odoo conocida de
/// UN servidor+base — dos instancias no deben pisarse la versión guardada.
String _odooVersionPrefsKey(String serverUrl, String database) =>
    'orbi/server_version/$serverUrl|$database';

/// La versión de Odoo para el pie del armazón (`OperationalContext.odooVersion`).
///
/// Orden del dueño (13-sep-2026): «todo debe ser offline». `fetchVersion()`
/// necesita red; devolver `null` mientras no responde haría desaparecer el
/// segmento del pie cada vez que Orbi arranca sin conexión, aunque ya se
/// conociera la versión de una sesión anterior. Por eso este provider es un
/// `Notifier`, no un `FutureProvider`: `build()` devuelve enseguida la
/// última versión guardada en `SharedPreferences`
/// (`sharedPreferencesProvider`, la misma instancia que ya usa el router)
/// bajo `orbi/server_version/<url>|<db>`, y dispara `fetchVersion()` en
/// segundo plano — si responde, actualiza el estado y la guarda; si no
/// (sin red, o una sesión restaurada sin cliente), la guardada se queda tal
/// cual. La detección en sí ya existe en `odoo_sdk`
/// (`OdooClient.fetchVersion`/`.version`, el mismo mecanismo que usa
/// `theos_pos`,
/// `theos_pos/lib/shared/providers/server_info_provider.dart:108,164`).
final _odooVersionProvider = NotifierProvider<_OdooVersionNotifier, String?>(
  _OdooVersionNotifier.new,
);

class _OdooVersionNotifier extends Notifier<String?> {
  @override
  String? build() {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) return null;
    final prefs = ref.watch(sharedPreferencesProvider);
    final key = _odooVersionPrefsKey(profile.serverUrl, profile.database);
    final cached = prefs.getString(key);

    final client = ref.watch(runtimeSessionProvider)?.active?.client;
    if (client != null) {
      unawaited(_refresh(client, prefs, key));
    }
    return cached;
  }

  Future<void> _refresh(
    OdooClient client,
    SharedPreferences prefs,
    String key,
  ) async {
    final version = await client.fetchVersion();
    if (version.isUnknown) return;
    final resolved = version.toString();
    await prefs.setString(key, resolved);
    if (ref.mounted) state = resolved;
  }
}

/// Ambiente del servidor ACTIVO (`OperationalContext.environment`), buscado
/// por URL+base contra los accesos guardados (`SavedServersStore`) — el
/// mismo criterio de identidad que ya usa `upsert()` para detectar
/// duplicados. `null` sin perfil, sin acceso guardado que coincida, o si
/// nunca se marcó ambiente para ese acceso — nunca se adivina del nombre del
/// servidor (orden del dueño, 14-sep-2026).
ServerEnvironment? _environmentFor(
  SavedServersStore store,
  AuthProfile? profile,
) {
  if (profile == null) return null;
  try {
    final normalizedUrl = SavedServersStore.normalizeUrl(profile.serverUrl);
    for (final server in store.load()) {
      if (server.url == normalizedUrl && server.database == profile.database) {
        return server.environment;
      }
    }
  } catch (_) {
    // Una URL guardada que ya no normaliza, o un almacén corrupto: sin
    // ambiente que mostrar, nunca un error que tumbe el armazón.
  }
  return null;
}

/// Claves de `SharedPreferences` para la señal del SRI — misma forma que
/// `_odooVersionPrefsKey`/`_presenceSupportedPrefsKey`: una por servidor+base,
/// para que dos instancias no se pisen la lectura.
String _sriPendingSupportedPrefsKey(String serverUrl, String database) =>
    'orbi/sri_pending_supported/$serverUrl|$database';

String _sriPendingCountPrefsKey(String serverUrl, String database) =>
    'orbi/sri_pending_count/$serverUrl|$database';

final _sriPendingProvider =
    NotifierProvider<_SriPendingNotifier, SriPendingStatus?>(
      _SriPendingNotifier.new,
    );

/// Cuenta de comprobantes electrónicos pendientes del SRI, para la píldora
/// «N pendientes SRI» de la barra superior.
///
/// El campo verificado en el código de Odoo 19 es el genérico
/// `account.move.edi_state`
/// (`odoo/addons/account_edi/models/account_move.py:18-23`, calculado en
/// `_compute_edi_state`, líneas 42-55): `to_send` es un comprobante que
/// todavía no se envió a autorizar, `to_cancel` uno cuya anulación sigue
/// pendiente. `l10n_ec_edi` (`enterprise/l10n_ec_edi/__manifest__.py:17`)
/// depende de `account_edi` y no redefine ese campo — es el mismo que ya usa
/// el SRI ecuatoriano, así que no hacía falta un campo propio de
/// `l10n_ec_edi` (no lo hay: se buscó en todo `enterprise/l10n_ec_edi` y
/// `odoo/addons/l10n_ec*` sin encontrar un booleano o estado equivalente
/// específico de Ecuador).
///
/// Mismo patrón que `_PresenceSupportedNotifier`: primero se sonda si el
/// campo existe (`OdooClient.hasField`, que cachea por modelo) y se guarda
/// la respuesta; si no existe, la señal queda apagada para siempre en esa
/// sesión. Si existe, se cuenta con `searchCount` cuando hay cliente activo,
/// como mucho una vez cada 5 minutos, y el último valor se guarda para
/// mostrarlo sin conexión como «(última lectura)».
class _SriPendingNotifier extends Notifier<SriPendingStatus?> {
  DateTime? _lastProbe;

  @override
  SriPendingStatus? build() {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) return null;
    final prefs = ref.watch(sharedPreferencesProvider);
    final supportedKey = _sriPendingSupportedPrefsKey(
      profile.serverUrl,
      profile.database,
    );
    final countKey = _sriPendingCountPrefsKey(
      profile.serverUrl,
      profile.database,
    );
    if (prefs.getBool(supportedKey) == false) return null;

    final client = ref.watch(runtimeSessionProvider)?.active?.client;
    final now = DateTime.now();
    if (client != null &&
        (_lastProbe == null ||
            now.difference(_lastProbe!) >= const Duration(minutes: 5))) {
      _lastProbe = now;
      unawaited(_probe(client, prefs, supportedKey, countKey));
    }

    final cachedCount = prefs.getInt(countKey);
    if (cachedCount == null || cachedCount <= 0) return null;
    return SriPendingStatus(count: cachedCount, isLastReading: client == null);
  }

  Future<void> _probe(
    OdooClient client,
    SharedPreferences prefs,
    String supportedKey,
    String countKey,
  ) async {
    try {
      final hasField = await client.hasField('account.move', 'edi_state');
      await prefs.setBool(supportedKey, hasField);
      if (!hasField) {
        await prefs.remove(countKey);
        if (ref.mounted) state = null;
        return;
      }
      final count = await client.searchCount(
        model: 'account.move',
        domain: const [
          ['edi_state', 'in', ['to_send', 'to_cancel']],
        ],
      );
      final resolved = count ?? 0;
      await prefs.setInt(countKey, resolved);
      if (ref.mounted) {
        state = resolved <= 0
            ? null
            : SriPendingStatus(count: resolved, isLastReading: false);
      }
    } catch (_) {
      // Sin red, o el servidor falló al contar: se conserva la última
      // lectura guardada, nunca un error visible en la barra superior.
    }
  }
}

// --- Bloque aislado: presencia y preferencias personales (13-sep-2026) -----
// Los puertos de `orbi_runtime/lib/src/account/` armados con lo mismo que ya
// usa el resto del router para construir puertos de sesión — mismo patrón
// que `scopeCollectionSessionSupervisionActionsProvider` en
// `collection_scope_composition.dart`: `SaleOdooActions` del cliente activo
// (`null` sin cliente), `OfflineQueueDataSource`/`AppDatabase` de la base
// activa.

final _sessionActionsProvider = Provider<SaleOdooActions?>((ref) {
  final client = ref.watch(runtimeSessionProvider)?.active?.client;
  return client == null ? null : OdooClientSaleActions(client);
});

final _sessionDatabaseProvider = Provider<AppDatabase?>(
  (ref) => ref.watch(runtimeSessionProvider)?.active?.database.database,
);

final _sessionQueueProvider = Provider<OfflineQueueDataSource?>((ref) {
  final database = ref.watch(_sessionDatabaseProvider);
  return database == null ? null : OfflineQueueDataSource(database);
});

/// Espejo de `_UnavailableSaleActions` en `collection_scope_composition.dart`
/// (privada allí, no se puede reusar desde este archivo): un `call` que
/// siempre falla, para que `OdooUserSecurityActionsPort`/`UserPresencePort`
/// tengan algo que sostener sin sesión en línea sin volverse `null` — ya
/// gastan `isOnline`/el propio `null` del puerto para decidir si de verdad
/// intentan hablar con el servidor.
final class _UnavailableSaleActions implements SaleOdooActions {
  const _UnavailableSaleActions();
  @override
  Future<dynamic> call({
    required String model,
    required String method,
    List<int>? ids,
    Map<String, dynamic>? kwargs,
  }) => Future.error(StateError('Sin sesión en línea'));
}

/// 100% local — `LocalUserPreferencesPort` nunca necesita el cliente.
/// `null` sólo sin sesión activa (ni base ni cola que ofrecer).
final _userPreferencesPortProvider = Provider<UserPreferencesPort?>((ref) {
  final database = ref.watch(_sessionDatabaseProvider);
  final queue = ref.watch(_sessionQueueProvider);
  if (database == null || queue == null) return null;
  return LocalUserPreferencesPort(database: database, queue: queue);
});

final _userSecurityActionsPortProvider = Provider<UserSecurityActionsPort>((
  ref,
) {
  final actions = ref.watch(_sessionActionsProvider);
  return OdooUserSecurityActionsPort(
    actions: actions ?? const _UnavailableSaleActions(),
    isOnline: actions != null,
  );
});

/// `null` sólo sin sesión activa — a diferencia de `UserSecurityActionsPort`,
/// que sigue existiendo (`isOnline: false`) porque `changePassword`/etc.
/// necesitan devolver `.offline()`, `UserPresencePort` no distingue online
/// de offline por dentro (`set`/`readPending` son sólo cola local); sin
/// sesión activa no hay ni base para esa cola.
final _userPresencePortProvider = Provider<UserPresencePort?>((ref) {
  final queue = ref.watch(_sessionQueueProvider);
  if (queue == null) return null;
  final actions = ref.watch(_sessionActionsProvider);
  return UserPresencePort(
    actions: actions ?? const _UnavailableSaleActions(),
    queue: queue,
  );
});

String _presencePrefsKey(String serverUrl, String database, int userId) =>
    'orbi/presence/$serverUrl|$database|$userId';

String _presenceSupportedPrefsKey(String serverUrl, String database) =>
    'orbi/presence_supported/$serverUrl|$database';

final _presenceSupportedProvider =
    NotifierProvider<_PresenceSupportedNotifier, bool?>(
      _PresenceSupportedNotifier.new,
    );

/// Qué áreas de negocio (`ServerFeature`) tiene ESTE servidor+base — orden
/// del dueño, 14-sep-2026: «theos_panel debe ser universal, no sólo
/// funcionar con los módulos custom que tiene newerp» (Mepriga, por
/// ejemplo, no tiene ventas). El menú (más abajo) y el `redirect` de este
/// mismo router son los ÚNICOS llamadores que pasan un `ServerFeatures` real
/// a `RouteAccessPolicy` — cualquier otro sitio que la use sigue viendo
/// `null`, que la política trata como "sin evidencia, no restringe nada
/// nuevo" (ver el comentario de `RouteAccessPolicy.allows`).
final serverFeaturesProvider =
    NotifierProvider<_ServerFeaturesNotifier, ServerFeatures>(
      _ServerFeaturesNotifier.new,
    );

/// Mismo patrón que [_PresenceSupportedNotifier]: lo guardado en
/// `SharedPreferences` sirve sin conexión de inmediato (`build()` es
/// síncrono), y el sondeo real contra Odoo se dispara aparte, como mucho una
/// vez por `scopeKey` — cambiar de servidor o de usuario cuenta como una
/// sesión nueva y vuelve a sondear.
class _ServerFeaturesNotifier extends Notifier<ServerFeatures> {
  String? _probedScopeKey;

  @override
  ServerFeatures build() {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) return ServerFeatures.empty;
    final prefs = ref.watch(sharedPreferencesProvider);
    final store = ServerFeatureStore(
      preferences: prefs,
      serverUrl: profile.serverUrl,
      database: profile.database,
    );
    final cached = store.read();
    // Sólo hay algo que sondear con un cliente en línea: sin él (restore
    // offline) se sirve lo guardado tal cual, sin tocar la red — igual que
    // `RuntimeCatalogAvailability` (E02).
    final client = ref.watch(runtimeSessionProvider)?.active?.client;
    final scopeKey = ref.watch(capabilitySnapshotProvider)?.scopeKey;
    if (client != null && scopeKey != null && _probedScopeKey != scopeKey) {
      _probedScopeKey = scopeKey;
      unawaited(_probeAll(store, client));
    }
    return cached;
  }

  Future<void> _probeAll(ServerFeatureStore store, OdooClient client) async {
    final reader = OdooJson2ReadPort(client);
    var latest = store.read();
    for (final feature in ServerFeature.values) {
      latest = await store.probe(feature, reader);
    }
    if (ref.mounted) state = latest;
  }
}

/// Si el servidor tiene `mobile_set_im_status`
/// (`l10n_ec_app_sync/models/res_users.py` — falta, por
/// ejemplo, en Mepriga). `null` mientras no se sabe todavía: el submenú
/// «Estado» no se ofrece ni en un sentido ni en el otro hasta tener una
/// respuesta real — ver el uso de este provider más abajo
/// (`onPresenceChanged` sólo existe con `true`).
class _PresenceSupportedNotifier extends Notifier<bool?> {
  @override
  bool? build() {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) return null;
    final prefs = ref.watch(sharedPreferencesProvider);
    final key = _presenceSupportedPrefsKey(
      profile.serverUrl,
      profile.database,
    );
    final cached = prefs.getBool(key);
    if (cached != null) return cached;

    final actions = ref.watch(_sessionActionsProvider);
    final port = ref.watch(_userPresencePortProvider);
    if (actions != null && port != null) {
      unawaited(_probe(actions, port, profile.userId, prefs, key));
    }
    return null;
  }

  /// Sonda de una sola vez, sólo mientras no se sepa todavía. Lee el estado
  /// actual y lo reescribe TAL CUAL — idempotente, ningún estado distinto
  /// queda escrito — llamando al método real DIRECTO, no por
  /// `UserPresencePort.set` (que sólo encola: el fallo de
  /// `mobile_set_im_status`, si lo hay, tiene que llegar aquí mismo, no
  /// perderse en la cola durable).
  Future<void> _probe(
    SaleOdooActions actions,
    UserPresencePort port,
    int userId,
    SharedPreferences prefs,
    String key,
  ) async {
    try {
      final current = await port.read(userId);
      if (current == null) return; // Forma inesperada: se reintenta luego.
      await actions.call(
        model: 'res.users',
        method: 'mobile_set_im_status',
        kwargs: {'status': current.odooValue},
      );
      await prefs.setBool(key, true);
      if (ref.mounted) state = true;
    } on OdooMethodNotFoundException {
      await prefs.setBool(key, false);
      if (ref.mounted) state = false;
    } on OdooNotFoundException {
      await prefs.setBool(key, false);
      if (ref.mounted) state = false;
    } catch (_) {
      // Red o permisos: no decide disponibilidad, se reintenta con la
      // próxima sesión con red.
    }
  }
}

final _presenceProvider = NotifierProvider<_PresenceNotifier, OdooPresence?>(
  _PresenceNotifier.new,
);

/// `readPending` ?? la última guardada en preferencias ?? `read` en línea
/// (que luego se guarda). `readPending`/`read` son async y `build()` no
/// puede esperarlos, así que la guardada es lo que se muestra AL INSTANTE
/// (síncrona, de `SharedPreferences`) y las otras dos corrigen el estado en
/// cuanto resuelven — típicamente milisegundos después, nunca «sin dato»
/// mientras tanto.
class _PresenceNotifier extends Notifier<OdooPresence?> {
  @override
  OdooPresence? build() {
    final profile = ref.watch(authControllerProvider).profile;
    if (profile == null) return null;
    final prefs = ref.watch(sharedPreferencesProvider);
    final key = _presencePrefsKey(
      profile.serverUrl,
      profile.database,
      profile.userId,
    );
    final cached = OdooPresence.fromOdoo(prefs.getString(key));

    final port = ref.watch(_userPresencePortProvider);
    if (port != null) {
      final online = ref.watch(runtimeSessionProvider)?.active?.client != null;
      unawaited(_resolve(port, profile.userId, online, prefs, key));
    }
    return cached;
  }

  Future<void> _resolve(
    UserPresencePort port,
    int userId,
    bool online,
    SharedPreferences prefs,
    String key,
  ) async {
    // Gana la ÚLTIMA elección propia, todavía sin drenar — por delante de
    // lo guardado y de lo que diga el servidor.
    final pending = await port.readPending(userId);
    if (pending != null) {
      if (ref.mounted) state = pending;
      return;
    }
    if (!online) return;
    final remote = await port.read(userId);
    if (remote == null) return;
    await prefs.setString(key, remote.odooValue);
    if (ref.mounted) state = remote;
  }

  /// Cambio optimista: quien construye [OperationalShell] llama esto ANTES
  /// de que `UserPresencePort.set` termine de encolar, para que una
  /// reconstrucción de este subárbol por otro motivo no muestre el estado
  /// viejo mientras la cola drena.
  void applyOptimistic(OdooPresence status) {
    state = status;
  }
}
// --- Fin del bloque aislado -------------------------------------------------

/// Traduce la preferencia guardada al tipo real de Fluent. Vive aquí, no en
/// `operational_shell.dart`: el marco recibe tipos de Fluent por constructor
/// (orden del dueño, 13-sep-2026), sin conocer el modelo de preferencias —
/// igual que ya no conoce los colores, sólo los recibe compuestos.
/// El nombre real (`res.users.name`) cuando se conoce; si no, el login. «Usuario
/// no disponible» sólo cuando no hay perfil. Un perfil guardado antes de que
/// existiera `AuthProfile.name` llega sin nombre.
String _userLabelFor(AuthProfile? profile) {
  final name = profile?.name?.trim();
  if (name != null && name.isNotEmpty) return name;
  return profile?.login ?? 'Usuario no disponible';
}

PaneDisplayMode _paneDisplayModeFor(PreferenceNavigationDisplayMode mode) =>
    switch (mode) {
      PreferenceNavigationDisplayMode.auto => PaneDisplayMode.auto,
      PreferenceNavigationDisplayMode.expanded => PaneDisplayMode.expanded,
      PreferenceNavigationDisplayMode.compact => PaneDisplayMode.compact,
      PreferenceNavigationDisplayMode.minimal => PaneDisplayMode.minimal,
      PreferenceNavigationDisplayMode.top => PaneDisplayMode.top,
    };

Widget _navigationIndicatorFor(PreferenceNavigationIndicator indicator) =>
    switch (indicator) {
      PreferenceNavigationIndicator.sticky => const StickyNavigationIndicator(),
      PreferenceNavigationIndicator.end => const EndNavigationIndicator(),
    };

/// El `Listenable` que hace que `GoRouter.redirect` se vuelva a evaluar
/// cuando cambia la autenticación o las capacidades (viajan juntas en el
/// mismo `AuthViewState`) — SIN recrear el `GoRouter`. Antes de esto,
/// `orbiRouterProvider` hacía `ref.watch(authControllerProvider)` en la raíz
/// del propio provider, así que CUALQUIER cambio de sesión reconstruía TODO
/// el `GoRouter` — y con él, el árbol entero bajo `routerConfig` en
/// `orbi_app.dart`, la pantalla de acceso incluida, en mitad de un envío de
/// formulario (auditoría de router+login, 14-sep-2026).
class _AuthRouterRefresh extends ChangeNotifier {
  void refresh() => notifyListeners();
}

bool _isAuthenticated(AuthViewState auth) =>
    auth.status == AuthControllerStatus.authenticated ||
    auth.status == AuthControllerStatus.restored;

/// Nunca se muta: sólo sirve de valor por omisión mientras todavía no hay
/// una sesión de runtime (`RuntimeDatabaseOwner.storageMode` real) de la
/// que leer — para que el aviso de almacenamiento volátil nunca aparezca
/// antes de tener una medida de verdad.
final ValueNotifier<RuntimeStorageMode> _unknownStorageMode = ValueNotifier(
  RuntimeStorageMode.unknown,
);

final orbiRouterProvider = Provider<GoRouter>((ref) {
  // Lecturas de una sola vez: ninguna de las dos cambia durante una sesión
  // (`policy` es `const RouteAccessPolicy()`; `composition` se fija entera
  // por `overrideWithValue` al arrancar la app o una prueba, nunca a medio
  // vuelo). Lo que sí cambia durante la sesión —autenticación, capacidades—
  // se lee fresco en cada evaluación de `redirect`, nunca capturado aquí.
  final policy = ref.read(routeAccessPolicyProvider);
  final composition = ref.read(orbiSessionCompositionProvider);
  // Misma regla de lectura única que `policy`/`composition`:
  // `sharedPreferencesProvider` no cambia durante una sesión (ver su propia
  // declaración en `app_preferences.dart`).
  final lastLocationStore = LastLocationStore(ref.read(sharedPreferencesProvider));

  final refresh = _AuthRouterRefresh();
  final authSubscription = ref.listen<AuthViewState>(
    authControllerProvider,
    (previous, next) => refresh.refresh(),
  );
  ref.onDispose(() {
    authSubscription.close();
    refresh.dispose();
  });

  final router = GoRouter(
    initialLocation: '/login',
    refreshListenable: refresh,
    redirect: (context, state) {
      // Lectura fresca en cada evaluación: `redirect` vuelve a correr cada
      // vez que `refresh` avisa, así que esto ve SIEMPRE el estado actual,
      // nunca el que tenía la sesión cuando se construyó el GoRouter.
      final auth = ref.read(authControllerProvider);
      final capabilities = ref.read(capabilitySnapshotProvider);
      final features = ref.read(serverFeaturesProvider);
      final authenticated = _isAuthenticated(auth);
      final location = state.uri.path;
      if (!authenticated) {
        if (location == '/login') return null;
        return '/login?returnTo=${Uri.encodeComponent(state.uri.toString())}';
      }
      if (location == '/login') {
        // Sin `returnTo` explícito (reabrir el dominio a secas, un acceso
        // directo, una pestaña anclada) la última pantalla de ESTA identidad
        // es el candidato — `returnTo` sigue ganando cuando existe, porque
        // representa una intención más reciente y más específica (alguien
        // pulsó un enlace concreto). `destinationAfterLogin` ya valida
        // permisos sobre cualquiera de los dos: una última ubicación que ya
        // no está permitida cae a `/` igual que un `returnTo` rechazado.
        final returnTo = state.uri.queryParameters['returnTo'];
        final profile = auth.profile;
        final lastLocation = returnTo == null && profile != null
            ? lastLocationStore.read(profile)
            : null;
        return policy.destinationAfterLogin(
          returnTo ?? lastLocation,
          authenticated: true,
          capabilities: capabilities,
          features: features,
        );
      }
      if (!policy.allows(
        location,
        authenticated: true,
        capabilities: capabilities,
        features: features,
      )) {
        // El redirect no puede hablar; deja dicho POR QUÉ y la pantalla de
        // destino lo cuenta. Sin esto, el rechazo es indistinguible de que la
        // aplicación esté rota (ver route_access_messages.dart). Con
        // `features`, el aviso también distingue "no es tu permiso" de "este
        // servidor no tiene ese módulo".
        ref
            .read(routeAccessDenialProvider.notifier)
            .report(location, capabilities: capabilities, features: features);
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => LoginScreen(
          initialPinMode: state.extra == startInPinModeExtra,
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => Consumer(
          builder: (context, ref, _) {
            // Leídos aquí, con el `ref` del propio `Consumer`: cambian
            // durante la sesión y antes forzaban la reconstrucción de TODO
            // el `GoRouter` por estar en la raíz de `orbiRouterProvider` (ver
            // su comentario). Ahora sólo reconstruyen este subárbol.
            final auth = ref.watch(authControllerProvider);
            final capabilities = ref.watch(capabilitySnapshotProvider);
            final features = ref.watch(serverFeaturesProvider);
            final authenticated = _isAuthenticated(auth);
            final profile = auth.profile;
            // El menú y su indicador son preferencia (Ajustes), no estado de
            // sesión, así que se leen igual que el resto de preferencias:
            // `AppPreferencesController` es un `ChangeNotifier`, no algo que
            // Riverpod reconstruya solo con `ref.watch` (ver `OrbiApp`, que
            // usa el mismo patrón un nivel más arriba). El `AnimatedBuilder`
            // de más abajo es lo que hace que elegir "Compacto" en Ajustes
            // se vea en el marco sin recargar la aplicación.
            final preferencesController = ref.watch(
              appPreferencesProvider(ref.watch(preferencesScopeProvider)),
            );
            // Mismo patrón que `preferencesController`: un `ChangeNotifier`
            // por fuera de Riverpod, escuchado más abajo con
            // `AnimatedBuilder` para que editarlo en Ajustes se vea en el
            // pie sin recargar la aplicación.
            final deviceNameController = ref.watch(
              deviceNameControllerProvider,
            );
            // Locking lives in its own small `Consumer`, not in this
            // provider's outer scope: watching it up there would make every
            // lock/unlock rebuild the whole `GoRouter` (see
            // `workspaceLockProvider`'s doc comment).
            final locked = ref.watch(workspaceLockProvider);
            // El aviso de almacenamiento volátil (bloque B de la auditoría
            // de "se pierde todo lo que estaba haciendo", 14-sep-2026): el
            // `ValueNotifier` vive en `RuntimeDatabaseOwner`, no en
            // Riverpod, así que se escucha con `ValueListenableBuilder` más
            // abajo — nunca `null` cuando no hay sesión de runtime todavía,
            // sino la constante "desconocido" del módulo, que nunca pinta
            // el aviso.
            final storageModeListenable =
                ref.watch(runtimeSessionProvider)?.databaseOwner.storageMode ??
                _unknownStorageMode;
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
                        label: 'Existencias',
                        path: '/envases',
                        icon: FluentIcons.delivery_truck,
                        group: 'Envases',
                      ),
                      const OperationalDestination(
                        label: 'Por recibir',
                        path: '/envases/por-recibir',
                        icon: FluentIcons.inbox,
                        group: 'Envases',
                      ),
                      const OperationalDestination(
                        label: 'Enviar',
                        path: '/envases/enviar',
                        icon: FluentIcons.send,
                        group: 'Envases',
                      ),
                      const OperationalDestination(
                        label: 'Movimientos',
                        path: '/envases/movimientos',
                        icon: FluentIcons.history,
                        group: 'Envases',
                      ),
                      const OperationalDestination(
                        label: 'Saldo por tercero',
                        path: '/envases/saldo-terceros',
                        icon: FluentIcons.contact,
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
                        label: 'Cola offline',
                        path: '/sync/queue',
                        icon: FluentIcons.cloud_upload,
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
                        features: features,
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
            // Instancia (y mantiene vivo) el disparador de re-sincronización
            // automática mientras este subárbol exista; ver el bloque
            // aislado más arriba. Nunca se lee su valor aquí: basta con que
            // exista para que escuche red y ciclo de vida.
            ref.watch(scopeSyncAutoResyncTriggerProvider);
            // Igual que el disparador: basta con que exista para que el tiempo
            // real abra el socket del ámbito y lo cierre al salir. Se captura
            // el valor (a diferencia del resto de este bloque) porque su
            // `.status` alimenta la píldora de tiempo real de la barra
            // superior, más abajo.
            final realtime = ref.watch(scopeRealtimeSyncCoordinatorProvider);
            // Respaldo periódico (hueco 2, 14-sep-2026): basta con que exista
            // para que sondee cada 5 minutos mientras el tiempo real no esté
            // conectado. Nunca se lee su valor aquí.
            ref.watch(scopeSyncPeriodicBackupTriggerProvider);
            // El Modo Ruta guardado pausa la sincronización desde que se abre el ámbito.
            ref.watch(scopeRouteModePauseProvider);
            // Dos medidas, no una suposición: el transporte del aparato y la
            // respuesta del servidor al último sondeo. Si falta cualquiera de
            // las dos, el resultado dice «sin verificar», nunca «conectado».
            // Y en el navegador el transporte casi siempre existe aunque el
            // Odoo esté caído, así que por sí solo no basta para dar salud.
            final connectionStatus = const ConnectionStatusResolver().resolve(
              network: ref.watch(networkSignalProvider).value,
              backendProbe: coordinator?.lastProbe,
            );
            // El estado del tiempo real, para la píldora de la barra
            // superior. `.value` viene del stream (cambia cuando el socket
            // conecta/reintenta/se cae); `realtime?.currentStatus` es el
            // valor sincrónico ya conocido antes de que el `StreamProvider`
            // reciba su primer evento — sin este resguardo, el primer frame
            // pintaría `null` (sin píldora) aunque el coordinador ya tuviera
            // un estado real.
            final realtimeStatus =
                ref.watch(scopeRealtimeStatusStreamProvider).value ??
                realtime?.currentStatus;
            final noticesScope = ref
                .watch(runtimeSessionProvider)
                ?.active
                ?.scope;
            final noticesUnreadCount = noticesScope == null
                ? 0
                : ref.watch(
                    notificationUnreadCountProvider(
                      NotificationQueryKey(
                        scopeKey: noticesScope.scopeKey,
                        partitionKey: capabilities?.companyId == null
                            ? 'global'
                            : 'company:${capabilities!.companyId}',
                      ),
                    ),
                  );
            // Mismo puerto que lee la ruta `/activities` más abajo
            // (`composition.activities ?? ref.read(scopeActivityPortProvider)`):
            // se reutiliza la instancia, `ref.watch` no dispara una segunda
            // carga. Sirve sólo para el contador de la campana de
            // Actividades de la barra superior.
            final activityPort =
                composition.activities ?? ref.watch(scopeActivityPortProvider);
            final presence = ref.watch(_presenceProvider);
            final presenceSupported = ref.watch(_presenceSupportedProvider);
            // El controlador es el mismo `ChangeNotifier` de arriba: sólo se
            // reconstruye este subárbol, nunca el `GoRouter` entero. Mismo
            // motivo para el `ValueListenableBuilder` del modo de
            // almacenamiento: envuelve sólo esta rama, jamás el `GoRouter`.
            return ValueListenableBuilder<RuntimeStorageMode>(
              valueListenable: storageModeListenable,
              builder: (context, storageMode, _) => AnimatedBuilder(
              // `Listenable.merge` en vez de dos `AnimatedBuilder` anidados:
              // el nombre del equipo (`DeviceNameController`) necesita el
              // mismo redibujado en caliente que ya tenía `preferencesController`,
              // sin sumar otra capa de anidamiento a esta rama.
              animation: Listenable.merge([
                preferencesController,
                deviceNameController,
              ]),
              builder: (context, _) => StreamBuilder<SyncSnapshot>(
                stream:
                    coordinator?.snapshots ??
                    const Stream<SyncSnapshot>.empty(),
                initialData: coordinator?.snapshot ?? SyncSnapshot(),
                builder: (context, syncSnapshot) =>
                    StreamBuilder<List<ActivityItem>>(
                  stream: activityPort?.changes ?? const Stream.empty(),
                  initialData: activityPort?.snapshot ?? const [],
                  builder: (context, activitySnapshot) => DesktopCloseGuard(
                  child: OperationalShell(
                    destinations: destinations,
                    selectedPath: state.uri.path,
                    // «Configuración» (carril o pie) sigue navegando: es
                    // `SettingsScreen`, no las preferencias personales.
                    onNavigate: (path) => context.go(path),
                    // «Mis preferencias» del menú del avatar: un disparador
                    // PROPIO, separado de `onNavigate` — antes las dos
                    // llamaban a `onNavigate('/settings')` con la MISMA
                    // cadena, y no había forma de distinguirlas en
                    // `router.dart` (medido el 13-sep-2026, interceptar
                    // `/settings` apagaba también «Configuración»).
                    onOpenPreferences: () {
                      final currentProfile = ref
                          .read(authControllerProvider)
                          .profile;
                      final userPreferences = ref.read(
                        _userPreferencesPortProvider,
                      );
                      if (currentProfile == null || userPreferences == null) {
                        context.go('/settings');
                        return;
                      }
                      final security = ref.read(
                        _userSecurityActionsPortProvider,
                      );
                      unawaited(
                        showUserPreferencesDialog(
                          context,
                          userId: currentProfile.userId,
                          preferences: userPreferences,
                          security: security,
                        ).then((message) {
                          if (message == null || !context.mounted) return;
                          final durations = ref
                              .read(
                                appPreferencesProvider(
                                  ref.read(preferencesScopeProvider),
                                ),
                              )
                              .snapshot
                              .messageDurations;
                          showCopyableMessage(
                            context,
                            CopyableMessage(
                              title: 'Preferencias',
                              body: message,
                              severity: OrbiMessageSeverity.success,
                            ),
                            durations: durations,
                          );
                        }),
                      );
                    },
                    navigationDisplayMode: _paneDisplayModeFor(
                      preferencesController.snapshot.navigationDisplayMode,
                    ),
                    navigationIndicator: _navigationIndicatorFor(
                      preferencesController.snapshot.navigationIndicator,
                    ),
                    onToggleTheme: () => preferencesController.setTheme(
                      FluentTheme.of(context).brightness == Brightness.dark
                          ? PreferenceThemeMode.light
                          : PreferenceThemeMode.dark,
                    ),
                    presence: presence,
                    // `null` mientras no se sepa si el servidor soporta
                    // `mobile_set_im_status`, o si de plano no lo soporta:
                    // en los dos casos el submenú «Estado» no se ofrece
                    // (`presenceSupported != true`, no sólo `== false`, para
                    // cubrir también el `null` de "todavía no se sabe").
                    onPresenceChanged: presenceSupported != true
                        ? null
                        : (status) {
                            final currentProfile = ref
                                .read(authControllerProvider)
                                .profile;
                            final port = ref.read(_userPresencePortProvider);
                            if (currentProfile == null || port == null) {
                              return;
                            }
                            ref
                                .read(_presenceProvider.notifier)
                                .applyOptimistic(status);
                            unawaited(port.set(currentProfile.userId, status));
                            unawaited(
                              ref
                                  .read(sharedPreferencesProvider)
                                  .setString(
                                    _presencePrefsKey(
                                      currentProfile.serverUrl,
                                      currentProfile.database,
                                      currentProfile.userId,
                                    ),
                                    status.odooValue,
                                  ),
                            );
                          },
                    context: OperationalContext(
                      server: profile?.serverUrl ?? 'No disponible',
                      database: profile?.database ?? 'No disponible',
                      userLabel: _userLabelFor(profile),
                      // The real name travels in the very same response that
                      // already carries `companyId` (`res.users.company_id`,
                      // read via `OdooActiveIdentityReader.read` — see
                      // `bootstrap.dart`, the same path on native and web). The
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
                      realtimeStatus: realtimeStatus,
                      syncLabel: _syncStatusLabel(
                        coordinator,
                        syncSnapshot.data,
                      ),
                      // Misma clave que la ruta /notifications: la campana cuenta
                      // exactamente lo que la bandeja muestra sin leer.
                      noticesUnreadCount: noticesUnreadCount,
                      odooVersion: ref.watch(_odooVersionProvider),
                      // Misma cifra que ya lee /sync/queue: no se inventa un
                      // segundo conteo.
                      pendingOperationsCount:
                          syncSnapshot.data?.queuedCount ??
                          coordinator?.snapshot.queuedCount ??
                          0,
                      routeModeActive: preferencesController.snapshot.routeMode,
                      activitiesPendingCount: (activitySnapshot.data ?? const [])
                          .where((item) => item.status != ActivityStatus.done)
                          .length,
                      storageIsVolatile:
                          storageMode == RuntimeStorageMode.volatile,
                      serverClock: ref.watch(serverClockStatusProvider),
                      offlineBlockedMessage: ref.watch(
                        _offlineAllowanceBlockMessageProvider,
                      ),
                      environment: _environmentFor(
                        ref.watch(savedServersStoreProvider),
                        profile,
                      ),
                      deviceName: deviceNameController.name,
                      // Mismo lector que ya usa Inicio
                      // (`homeCashSessionsProvider`): sin duplicar la
                      // consulta, `.value` toma la última lista conocida
                      // aunque el `FutureProvider` esté recargando.
                      cashSessionOpen:
                          (ref.watch(homeCashSessionsProvider).value ??
                                  const [])
                              .isNotEmpty,
                      sriPending: ref.watch(_sriPendingProvider),
                    ),
                    onLogout: () async {
                      await ref.read(authControllerProvider.notifier).close();
                      if (context.mounted) context.go('/login');
                    },
                    locked: locked,
                    onLock: () =>
                        ref.read(workspaceLockProvider.notifier).lock(),
                    onUnlock: (password) =>
                        attemptWorkspaceUnlock(ref, password),
                    onSwitchUser: () =>
                        confirmSwitchWorkspaceUser(context, ref),
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
                          ref.listen<CopyableMessage?>(
                            routeAccessDenialProvider,
                            (_, next) {
                              if (next == null || !innerContext.mounted) return;
                              ref
                                  .read(routeAccessDenialProvider.notifier)
                                  .take();
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
                            },
                          );
                          // ----- INICIO bloque aislado: sesión expirada en
                          // caliente (auditoría de sesión, 13-sep-2026) -----
                          // El 401 del sondeo (o de cualquier trabajo de
                          // sincronización) llega aquí como
                          // `SyncSnapshot.sessionExpired`, una señal
                          // ESTRUCTURADA (`SyncFailure.authStatus`), nunca
                          // texto libre — ver sync_coordinator_impl.dart.
                          // `ref.listen` reacciona UNA sola vez en la
                          // transición false→true: en cuanto se dispare,
                          // `handleSessionExpired()` cambia `auth.status`, lo
                          // que hace que `orbiRouterProvider` redirija a
                          // `/login` y este subárbol completo se desmonte, así
                          // que no hay riesgo de repetir la llamada mientras
                          // el snapshot siga en ese estado.
                          ref.listen<bool>(sessionExpiredSignalProvider, (
                            previous,
                            next,
                          ) {
                            if (next && previous != true) {
                              ref
                                  .read(authControllerProvider.notifier)
                                  .handleSessionExpired();
                            }
                          });
                          // ----- FIN bloque aislado -----
                          return child;
                        },
                      ),
                    ),
                  ),
                ),
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
          // Turno de caja por id: el supervisor abre el de cualquier cajero de
          // su empresa. La compuerta real (dueño o `collection_supervisor`) vive
          // en `scopeCollectionSessionByIdFutureProvider`; la política de rutas
          // sólo exige `cashier` por estar bajo /collection/.
          GoRoute(
            path: '/collection/sessions/:id',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                final sessionId = int.tryParse(
                  state.pathParameters['id'] ?? '',
                );
                if (sessionId == null || sessionId <= 0) {
                  return const NotConfiguredPage(
                    title: 'Caja',
                    detail: 'Turno inválido.',
                  );
                }
                final lookup = ref.watch(
                  scopeCollectionSessionByIdFutureProvider(sessionId),
                );
                return lookup.when(
                  loading: () => const NotConfiguredPage(
                    title: 'Caja',
                    detail: 'Cargando el turno…',
                  ),
                  error: (error, stack) =>
                      NotConfiguredPage(title: 'Caja', detail: '$error'),
                  data: (view) => CollectionSupervisedSessionScreen(
                    sessionId: sessionId,
                    view: view,
                  ),
                );
              },
            ),
          ),
          GoRoute(
            path: '/envases',
            builder: (context, state) => const EnvasesExistenciasRoute(),
          ),
          GoRoute(
            path: '/envases/por-recibir',
            builder: (context, state) => const EnvasesPorRecibirRoute(),
          ),
          GoRoute(
            path: '/envases/por-recibir/:pickingId',
            builder: (context, state) {
              final pickingId = int.tryParse(
                state.pathParameters['pickingId'] ?? '',
              );
              if (pickingId == null || pickingId <= 0) {
                return const NotConfiguredPage(
                  title: 'Envases',
                  detail: 'Traslado inválido.',
                );
              }
              return EnvasesTrasladoDetalleRoute(
                pickingId: pickingId,
                extra: state.extra as EnvasesPorRecibirRow?,
              );
            },
          ),
          GoRoute(
            path: '/envases/por-recibir/:pickingId/recibir',
            builder: (context, state) {
              final pickingId = int.tryParse(
                state.pathParameters['pickingId'] ?? '',
              );
              if (pickingId == null || pickingId <= 0) {
                return const NotConfiguredPage(
                  title: 'Envases',
                  detail: 'Traslado inválido.',
                );
              }
              return EnvasesRecibirRoute(
                pickingId: pickingId,
                extra: state.extra as EnvasesPorRecibirRow?,
              );
            },
          ),
          GoRoute(
            path: '/envases/enviar',
            builder: (context, state) => const EnvasesEnviarRoute(),
          ),
          GoRoute(
            path: '/envases/movimientos',
            builder: (context, state) => const EnvasesMovimientosRoute(),
          ),
          GoRoute(
            path: '/envases/saldo-terceros',
            builder: (context, state) => const EnvasesSaldoTercerosRoute(),
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
                return SettingsScreen(
                  controller: preferences,
                  deviceNameController: ref.watch(
                    deviceNameControllerProvider,
                  ),
                  permissionAction: presenter == null
                      ? null
                      : NotificationPermissionAction(presenter),
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
                      // «Mías/Todas»: hoy el puerto sólo trae las del usuario
                      // de la sesión, así que el filtro aparece cuando traiga más.
                      currentUserId: ref
                          .read(authControllerProvider)
                          .profile
                          ?.userId,
                    ),
                  ),
          ),
          GoRoute(
            path: '/sync',
            builder: (context, state) {
              // Los catálogos y el coordinador del ÁMBITO (no
              // `composition.catalogs`, que sólo existe cuando una prueba lo
              // inyecta): la misma cola que lee la pantalla de conflictos
              // (SYN-03), nunca una segunda.
              final catalogs = ref.read(scopeCatalogCompositionProvider);
              final runtimeCoordinator = ref.read(scopeSyncCoordinatorProvider);
              final operationsJob =
                  (catalogs ?? composition.catalogs)?.jobs['operations']
                      as OperationsSyncJob?;
              void openConflicts() {
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
              }

              // Con runtime real: la pantalla de sincronización con el Modo
              // Ruta. En un `Consumer` para que la red y las preferencias no
              // reconstruyan el `GoRouter` entero.
              if (composition.sync == null &&
                  catalogs != null &&
                  runtimeCoordinator != null) {
                return Consumer(
                  builder: (context, ref, _) {
                    final preferences = ref.watch(
                      appPreferencesProvider(
                        ref.watch(preferencesScopeProvider),
                      ),
                    );
                    final capabilities = ref.watch(capabilitySnapshotProvider);
                    return SyncDataScreen(
                      port: RuntimeSyncDataPort(
                        coordinator: runtimeCoordinator,
                        catalogs: catalogs,
                        preferences: preferences,
                        operationsJob: operationsJob,
                        isOnline:
                            ref
                                .watch(networkSignalProvider)
                                .value
                                ?.hasNetwork ??
                            false,
                        userCanCollect:
                            capabilities?.permissions.contains('cashier') ??
                            false,
                      ),
                      onOpenConflicts: openConflicts,
                    );
                  },
                );
              }
              if (composition.sync == null && runtimeCoordinator == null) {
                return const NotConfiguredPage(title: 'Sincronización');
              }
              // Puerto inyectado (composición de pruebas o de negocio).
              return ProviderScope(
                overrides: [
                  syncCenterPortProvider.overrideWithValue(
                    composition.sync ??
                        CoordinatorSyncCenterPort(
                          runtimeCoordinator!,
                          operations: operationsJob,
                        ),
                  ),
                ],
                child: OrbiPage(
                  title: 'Sincronización',
                  child: SyncCenterView(onOpenConflicts: openConflicts),
                ),
              );
            },
          ),
          GoRoute(
            path: '/sync/queue',
            builder: (context, state) {
              final catalogs =
                  ref.read(scopeCatalogCompositionProvider) ??
                  composition.catalogs;
              final queue =
                  (catalogs?.jobs['operations'] as OperationsSyncJob?)?.queue;
              if (queue == null) {
                return const NotConfiguredPage(title: 'Cola offline');
              }
              final coordinator = ref.read(scopeSyncCoordinatorProvider);
              return OfflineQueueScreen(
                port: RuntimeOfflineQueuePort(
                  queue: queue,
                  isSyncing: coordinator?.snapshot.active ?? false,
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

  // Guarda la ubicación actual (path + query) cada vez que cambia y hay
  // sesión autenticada — el listener del `routerDelegate`, NO un segundo
  // `GoRouter` ni un `ref.watch` que reconstruya éste: el router de la
  // sesión es deliberadamente estable (ver el comentario de `refresh` más
  // arriba y `router_login_stability_test.dart`). `currentConfiguration.uri`
  // es la ubicación YA resuelta (después de cualquier redirect), la misma
  // que pintan el carril y el pie.
  void persistCurrentLocation() {
    final auth = ref.read(authControllerProvider);
    if (!_isAuthenticated(auth)) return;
    final profile = auth.profile;
    if (profile == null) return;
    final uri = router.routerDelegate.currentConfiguration.uri;
    // Nunca se guarda una ruta pública (hoy sólo `/login`, más `/splash` que
    // la política ya trata como pública): son pantallas de tránsito, no
    // "donde estaba trabajando".
    if (policy.allows(uri.path, authenticated: false)) return;
    lastLocationStore.save(profile, uri.toString());
  }

  router.routerDelegate.addListener(persistCurrentLocation);
  ref.onDispose(() => router.routerDelegate.removeListener(persistCurrentLocation));

  return router;
});
