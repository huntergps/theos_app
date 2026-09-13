import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import 'login_failure_messages.dart';
import 'pin_capability_limiter.dart';
import 'workspace_unlock_store.dart';

abstract interface class AuthServicePort {
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  });
  Future<AuthServiceResult> restore({bool offline});
  Future<AuthProfile?> loadProfile();
  Future<AuthProfile?> loadProfileFor(String serverUrl, String database);
  Future<void> close();
}

abstract interface class ApiKeyAuthServicePort {
  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
  });
}

/// Optional extension for services that can close a session the SERVER
/// already rejected (401/caducidad) without attempting to revoke it — ver
/// `NativeAuthService.closeExpired`. Auditoría de sesión, 13-sep-2026.
/// Legacy test/embedded services keep the original `AuthServicePort.close`.
abstract interface class ExpirableAuthServicePort {
  Future<void> closeExpired();
}

/// Optional extension for services that can run the proactive API-key
/// renewal cycle — ver `NativeAuthService.renewApiKeyIfNeeded`. Auditoría de
/// sesión, 13-sep-2026. `scopeSyncCoordinatorProvider` (router.dart) lo
/// conecta como el disparador «la app en línea» de cada ciclo de
/// sincronización.
abstract interface class RenewableAuthServicePort {
  Future<void> renewApiKeyIfNeeded();
}

/// Optional extension for services that can enforce the UI's explicit
/// credential-retention choice. Legacy test/embedded services keep the
/// original AuthServicePort contract.
abstract interface class CredentialPolicyAuthServicePort {
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
    bool persistCredential,
  });

  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
    bool persistCredential,
  });
}

/// Performs exactly one online restore and, only when that attempt fails, one
/// explicit offline restore. Callers own when this is invoked (normally cold
/// start); it never schedules a retry loop.
///
/// 🔴 El `catch` del intento en línea usado a distinguir dos causas muy
/// distintas: sin red, y clave rechazada por el servidor (401/
/// `OdooAuthenticationException`, la misma excepción que
/// `odoo_error_mapper.dart` lanza para ese caso real). Medido el
/// 13-sep-2026 (`restore_rejects_expired_key_test.dart`): con la clave ya
/// vencida (p. ej. `orbi.web_auth_key_days` cumplido), caer sin distinguir al
/// fallback offline devolvía `restored` con lo que ya había en disco — el
/// operador veía "sesión restaurada" con una clave que el propio servidor ya
/// había invalidado, indistinguible de una caída de wifi cualquiera.
///
/// La regla ahora: un rechazo EXPLÍCITO del servidor (el servidor respondió,
/// y la respuesta fue "esta credencial no vale") nunca cae al respaldo
/// offline — se resuelve en `required` directo, para que el router lleve al
/// acceso. Cualquier OTRO error (sin red, timeout, DNS, servidor caído) sigue
/// cayendo al respaldo offline exactamente como antes: ahí SÍ tiene sentido
/// seguir trabajando sin conexión hasta que vuelva la red.
Future<AuthServiceResult> restoreOnce(AuthServicePort service) async {
  try {
    return await service.restore();
  } catch (error) {
    if (_isExplicitCredentialRejection(error)) {
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
    try {
      return await service.restore(offline: true);
    } catch (_) {
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
  }
}

/// El servidor respondió y dijo explícitamente que esta credencial no vale —
/// nunca una inferencia sobre un error de transporte/red, que debe seguir
/// cayendo al respaldo offline.
bool _isExplicitCredentialRejection(Object error) =>
    error is OdooAuthenticationException;

class NativeAuthServicePort
    implements
        AuthServicePort,
        ApiKeyAuthServicePort,
        CredentialPolicyAuthServicePort,
        ExpirableAuthServicePort,
        RenewableAuthServicePort {
  NativeAuthServicePort(this.service);
  final NativeAuthService service;
  @override
  Future<void> closeExpired() => service.closeExpired();
  @override
  Future<void> renewApiKeyIfNeeded() => service.renewApiKeyIfNeeded();
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
    bool persistCredential = true,
  }) => service.login(
    serverUrl: serverUrl,
    database: database,
    login: login,
    password: password,
    persistCredential: persistCredential,
  );
  @override
  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
    bool persistCredential = true,
  }) => service.loginWithApiKey(
    serverUrl: serverUrl,
    database: database,
    login: login,
    apiKey: apiKey,
    persistCredential: persistCredential,
  );
  @override
  Future<AuthServiceResult> restore({bool offline = false}) =>
      service.restore(offline: offline);
  @override
  Future<AuthProfile?> loadProfile() => service.loadProfile();
  @override
  Future<AuthProfile?> loadProfileFor(String serverUrl, String database) =>
      service.loadProfileFor(serverUrl, database);
  @override
  Future<void> close() => service.close();
}

enum AuthControllerStatus {
  required,
  loading,
  authenticated,
  restored,
  unsupportedWeb,
  error,
}

final class AuthViewState {
  const AuthViewState({
    this.status = AuthControllerStatus.required,
    this.profile,
    this.message,
    this.capabilities,
  });
  final AuthControllerStatus status;
  final AuthProfile? profile;
  final String? message;
  final CapabilitySnapshot? capabilities;
  bool get isBusy => status == AuthControllerStatus.loading;
}

final authServiceProvider = Provider<AuthServicePort>((ref) {
  return const _UnavailableAuthService();
});

final authInitialStateProvider = Provider<AuthViewState>(
  (ref) => const AuthViewState(),
);

final class _UnavailableAuthService implements AuthServicePort {
  const _UnavailableAuthService();
  @override
  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async => const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthServiceResult> restore({bool offline = false}) async =>
      const AuthServiceResult(status: AuthServiceStatus.required);
  @override
  Future<AuthProfile?> loadProfile() async => null;
  @override
  Future<AuthProfile?> loadProfileFor(
    String serverUrl,
    String database,
  ) async => null;
  @override
  Future<void> close() async {}
}

/// Composition owns capability provisioning; routing and menus consume this
/// one provider instead of inventing per-screen permission snapshots.
final capabilitySnapshotProvider = Provider<CapabilitySnapshot?>(
  (ref) => ref.watch(authControllerProvider).capabilities,
);

final authControllerProvider = NotifierProvider<AuthNotifier, AuthViewState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthViewState> {
  AuthServicePort get _service => ref.read(authServiceProvider);
  AuthViewState get currentState => state;

  @override
  AuthViewState build() => ref.watch(authInitialStateProvider);

  Future<void> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
    bool persistCredential = true,
  }) async {
    // Read before the first await: a ref that gets unmounted mid-login must
    // not stop the derivation from being written (or, on close, erased).
    final unlockStore = ref.read(workspaceUnlockStoreProvider);
    state = const AuthViewState(status: AuthControllerStatus.loading);
    try {
      final service = _service;
      late final AuthServiceResult result;
      if (service case final CredentialPolicyAuthServicePort policy) {
        result = await policy.login(
          serverUrl: serverUrl,
          database: database,
          login: login,
          password: password,
          persistCredential: persistCredential,
        );
      } else {
        result = await service.login(
          serverUrl: serverUrl,
          database: database,
          login: login,
          password: password,
        );
      }
      if (!ref.mounted) return;
      final next = _fromAttempt(result);
      state = next;
      await _rememberUnlockSecret(
        unlockStore,
        next,
        password,
        persistCredential: persistCredential,
      );
    } catch (error) {
      if (!ref.mounted) return;
      state = AuthViewState(
        status: AuthControllerStatus.error,
        message: describeLoginFailure(error).flatten(),
      );
    }
  }

  /// Enrols the just-proven password with [WorkspaceUnlockStore] so the shell's
  /// lock screen can later be opened with no network at all.
  ///
  /// Only ever a derivation, never the password — see that class for what is
  /// stored, where, and why the web stores nothing. Two refusals are
  /// deliberate:
  ///
  /// * a login that did not actually succeed enrols nothing, so a rejected
  ///   password can never become an offline unlock; and
  /// * `persistCredential: false` enrols nothing either. That checkbox is the
  ///   user saying "do not leave my credential on this device", and a
  ///   derivation of their password is exactly the kind of thing they were
  ///   declining. It costs them the offline unlock, which is the trade they
  ///   asked for.
  ///
  /// Never throws: failing to save an optimization must not fail the login.
  Future<void> _rememberUnlockSecret(
    WorkspaceUnlockStore store,
    AuthViewState authenticated,
    String password, {
    required bool persistCredential,
  }) async {
    if (!persistCredential) return;
    final profile = authenticated.profile;
    if (profile == null) return;
    if (authenticated.status != AuthControllerStatus.authenticated &&
        authenticated.status != AuthControllerStatus.restored) {
      return;
    }
    await store.remember(workspaceUnlockScopeKeyFor(profile), password);
  }

  Future<void> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
    bool persistCredential = true,
  }) async {
    final service = _service;
    if (service is! ApiKeyAuthServicePort) {
      state = const AuthViewState(
        status: AuthControllerStatus.error,
        message: 'El modo API key no está configurado en esta plataforma.',
      );
      return;
    }
    final apiService = service as ApiKeyAuthServicePort;
    state = const AuthViewState(status: AuthControllerStatus.loading);
    try {
      late final AuthServiceResult result;
      if (service case final CredentialPolicyAuthServicePort policy) {
        result = await policy.loginWithApiKey(
          serverUrl: serverUrl,
          database: database,
          login: login,
          apiKey: apiKey,
          persistCredential: persistCredential,
        );
      } else {
        result = await apiService.loginWithApiKey(
          serverUrl: serverUrl,
          database: database,
          login: login,
          apiKey: apiKey,
        );
      }
      if (!ref.mounted) return;
      state = _fromAttempt(result);
    } catch (error) {
      if (!ref.mounted) return;
      state = AuthViewState(
        status: AuthControllerStatus.error,
        message: describeLoginFailure(error).flatten(),
      );
    }
  }

  Future<void> restore({bool offline = false}) async {
    state = const AuthViewState(status: AuthControllerStatus.loading);
    try {
      final result = await _service.restore(offline: offline);
      if (!ref.mounted) return;
      state = _fromResult(result);
    } catch (error) {
      if (!ref.mounted) return;
      // Same flattening the login path had: "No se pudo restaurar la sesión"
      // said nothing about whether to wait for the wifi, sign in again, or
      // call an administrator. describeSessionRestoreFailure re-words the
      // credential cases for a session nobody typed — see that function.
      state = AuthViewState(
        status: AuthControllerStatus.error,
        message: describeSessionRestoreFailure(error).flatten(),
      );
    }
  }

  /// Restores the session exactly like [restore] does, then clamps whatever
  /// capabilities come back to the seller-only ceiling PIN mode may ever
  /// grant — see pin_capability_limiter.dart. This is the ONLY path the PIN
  /// screen (ACC-02) may use to reach an authenticated state: it never calls
  /// [login] or [restore] directly, so a multirole cashier+seller account
  /// can never surface Caja/Aprobaciones/Administración permissions just by
  /// coming in through PIN instead of Workspace credentials.
  ///
  /// A restored session without the seller permission is reported as
  /// [AuthControllerStatus.error] rather than as a successful restore with an
  /// empty permission set: PIN is the declared door for the seller role, and
  /// a user without it has no door to walk through, not merely nothing to
  /// see once inside.
  Future<void> restoreForSellerPin({bool offline = false}) async {
    state = const AuthViewState(status: AuthControllerStatus.loading);
    try {
      final result = await _service.restore(offline: offline);
      if (!ref.mounted) return;
      final restored = _fromResult(result);
      if (restored.status != AuthControllerStatus.authenticated &&
          restored.status != AuthControllerStatus.restored) {
        state = restored;
        return;
      }
      final capabilities = restored.capabilities;
      if (capabilities == null || !snapshotAllowsSellerPin(capabilities)) {
        state = const AuthViewState(
          status: AuthControllerStatus.error,
          message: 'Este usuario no tiene acceso de vendedor por PIN.',
        );
        return;
      }
      state = AuthViewState(
        status: restored.status,
        profile: restored.profile,
        capabilities: restrictSnapshotToSellerPin(capabilities),
      );
    } catch (error) {
      if (!ref.mounted) return;
      // Reports the same causes as [restore]: nothing here is derived from
      // the PIN itself, so it leaks nothing about which PINs exist. The
      // seller-permission refusal above stays its own separate message.
      state = AuthViewState(
        status: AuthControllerStatus.error,
        message: describeSessionRestoreFailure(error).flatten(),
      );
    }
  }

  /// Ends the session. This is the single path behind both "Cerrar sesión" and
  /// "Cambiar de usuario" (see `confirmSwitchWorkspaceUser`), which is exactly
  /// why the workspace unlock derivation is erased here: whichever of the two
  /// the operator chose, leaving a derivation of the previous identity's
  /// password behind would be an orphan credential for someone who is no
  /// longer on this device. Neither exit needs the network, and erasing a
  /// local entry does not change that.
  Future<void> close() async {
    final profile = state.profile;
    final unlockStore = ref.read(workspaceUnlockStoreProvider);
    if (profile != null) {
      await unlockStore.forget(workspaceUnlockScopeKeyFor(profile));
    }
    await _service.close();
    if (!ref.mounted) return;
    // Drop profile/capabilities immediately so providers cannot retain the
    // previous user's company scope after teardown.
    state = const AuthViewState();
  }

  /// Cierra la sesión en memoria porque el propio SERVIDOR rechazó la clave
  /// (401 del sondeo, o de cualquier RPC que el runtime haya corrido) —
  /// nunca porque el operador decidió salir. Auditoría de sesión,
  /// 13-sep-2026.
  ///
  /// Tres diferencias deliberadas con [close]/"Cambiar de usuario":
  ///
  /// * nunca intenta revocar la clave — ya no es válida, revocarla sólo
  ///   repetiría el mismo rechazo sin lograr nada (ver
  ///   `NativeAuthService.closeExpired`);
  /// * nunca toca la base local, los borradores ni la cola offline — sólo
  ///   cierra la conexión del runtime, igual que [close] ya hacía; medido con
  ///   `session_expiry_preserves_local_data_test.dart`;
  /// * NO borra la derivación de desbloqueo sin conexión
  ///   ([WorkspaceUnlockStore]): a diferencia de un logout deliberado, aquí
  ///   el MISMO operador sigue siendo el dueño legítimo de este dispositivo —
  ///   sólo el servidor dejó de reconocer la credencial. Borrarla le
  ///   costaría el desbloqueo sin red la próxima vez, por algo que no eligió.
  ///
  /// El perfil no-secreto (servidor, base, usuario) queda intacto en
  /// preferencias — `LoginScreen` ya lo precarga por su cuenta
  /// (`loadProfile`/`loadProfileFor`), así que no hace falta llevarlo en
  /// [AuthViewState.profile] para que la pantalla de acceso lo recupere.
  Future<void> handleSessionExpired() async {
    if (state.status != AuthControllerStatus.authenticated &&
        state.status != AuthControllerStatus.restored) {
      return; // ya no hay una sesión activa que cerrar
    }
    final service = _service;
    try {
      if (service case final ExpirableAuthServicePort expirable) {
        await expirable.closeExpired();
      } else {
        // Respaldo: mejor intentar revocar que dejar una sesión abierta sin
        // ninguna forma de cerrarla.
        await service.close();
      }
    } catch (_) {
      // Best-effort — nunca debe impedir volver a la pantalla de acceso.
    }
    if (!ref.mounted) return;
    state = AuthViewState(
      status: AuthControllerStatus.error,
      message: loginFailureMessageFor(LoginFailureCause.sessionExpired)
          .flatten(),
    );
  }

  Future<AuthProfile?> loadProfile() async {
    return _service.loadProfile();
  }

  Future<AuthProfile?> loadProfileFor(String serverUrl, String database) =>
      _service.loadProfileFor(serverUrl, database);

  /// 🔴 A deliberate sign-in attempt that comes back [AuthServiceStatus
  /// .required] did NOT succeed, and it is not the neutral "you are signed
  /// out" state either — it is an attempt that produced nothing. `required`
  /// carries no message, so rendering it as-is made the browser's login clear
  /// the password field and say absolutely nothing: no request, no error, no
  /// words. Measured against ERP2.
  ///
  /// This is the backstop, not the fix: the real repair is for the web
  /// service to actually call the server. But a backstop is what guarantees
  /// that no path — including one nobody anticipated — can end in silence.
  AuthViewState _fromAttempt(AuthServiceResult result) {
    if (result.status != AuthServiceStatus.required) return _fromResult(result);
    return AuthViewState(
      status: AuthControllerStatus.error,
      message: loginFailureMessageFor(
        LoginFailureCause.loginNotAttempted,
      ).flatten(),
    );
  }

  AuthViewState _fromResult(AuthServiceResult result) =>
      switch (result.status) {
        AuthServiceStatus.authenticated => AuthViewState(
          status: AuthControllerStatus.authenticated,
          profile: result.profile,
          capabilities: result.capabilities,
        ),
        AuthServiceStatus.restored => AuthViewState(
          status: AuthControllerStatus.restored,
          profile: result.profile,
          capabilities: result.capabilities,
        ),
        AuthServiceStatus.unsupportedWeb => const AuthViewState(
          status: AuthControllerStatus.unsupportedWeb,
          message: 'El acceso web con contraseña está pendiente de W01.',
        ),
        AuthServiceStatus.required => const AuthViewState(
          status: AuthControllerStatus.required,
        ),
      };
}

AuthViewState authViewStateFromResult(AuthServiceResult result) =>
    switch (result.status) {
      AuthServiceStatus.authenticated => AuthViewState(
        status: AuthControllerStatus.authenticated,
        profile: result.profile,
        capabilities: result.capabilities,
      ),
      AuthServiceStatus.restored => AuthViewState(
        status: AuthControllerStatus.restored,
        profile: result.profile,
        capabilities: result.capabilities,
      ),
      AuthServiceStatus.unsupportedWeb => const AuthViewState(
        status: AuthControllerStatus.unsupportedWeb,
        message: 'El acceso web con contraseña está pendiente de W01.',
      ),
      AuthServiceStatus.required => const AuthViewState(
        status: AuthControllerStatus.required,
      ),
    };
