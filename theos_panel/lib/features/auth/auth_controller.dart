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

/// «Recordar la llave tras salir» (decisión del dueño, 13-sep-2026, ver
/// `docs/orbi_panel/decisions/W04-el-navegador-tambien-guarda.md`): lo que la
/// pantalla de acceso necesita para ofrecer «Clave guardada en este equipo» y
/// entrar sin volver a escribir la contraseña. Extensión opcional, igual que
/// [CredentialPolicyAuthServicePort]: un servicio de prueba/embebido que no
/// la implementa simplemente nunca ofrece la opción — no es un error.
abstract interface class StoredCredentialAuthServicePort {
  /// El perfil guardado para (server, database, login) SÓLO si su llave
  /// sigue en el almacén — `null` en cualquier otro caso, incluyendo un login
  /// que nunca se guardó o cuya llave ya se olvidó explícitamente.
  Future<AuthProfile?> findRememberedCredential(
    String serverUrl,
    String database,
    String login,
  );

  /// Entra con la llave ya guardada de [profile], sin contraseña. Un rechazo
  /// EXPLÍCITO del servidor (`OdooAuthenticationException`: la llave venció o
  /// fue revocada allá) borra esa llave por su cuenta antes de relanzar —
  /// nunca hace falta que el llamador se acuerde de limpiarla. Cualquier otro
  /// error (sin red, servidor caído) conserva la llave intacta.
  Future<AuthServiceResult> loginWithStoredCredential(AuthProfile profile);

  /// «Olvidar la clave guardada»: revoca en el servidor si hay red (best
  /// effort) y siempre borra la llave local. Nunca lanza.
  Future<void> forgetStoredCredential(AuthProfile profile);

  /// Si el almacén todavía tiene una llave utilizable para [profile]. La usa
  /// [AuthNotifier.close] para decidir si esta salida debe o no olvidar el
  /// derivado de [WorkspaceUnlockStore] — misma regla que la llave misma.
  Future<bool> hasStoredCredential(AuthProfile profile);
}

/// «El PIN mantiene el tope de vendedor al entrar o cambiar de usuario»
/// (decisión del dueño, 14-sep-2026): reutiliza la llave RETENIDA para el PIN
/// de [AuthProfile] — nunca la contraseña, nunca `restore()` — para volver a
/// entrar sin red adicional más allá del sondeo de identidad que el propio
/// login ya necesita. Optional extension, igual que
/// [StoredCredentialAuthServicePort]: un servicio de prueba/embebido que no
/// la implementa simplemente no puede ofrecer PIN (ver
/// [AuthNotifier.loginWithSellerPin]).
abstract interface class SellerPinAuthServicePort {
  /// Marca (o desmarca) la llave de [profile] como retenida para el PIN —
  /// ver `NativeAuthService.retainCredentialForPin`. `true` al enrolar un
  /// PIN, `false` al quitarlo.
  Future<void> retainCredentialForPin(AuthProfile profile, bool retained);

  /// Entra con la llave retenida de [profile], sin contraseña — ver
  /// `NativeAuthService.loginWithPinCredential`. `offline: true` reactiva sin
  /// red, sujeto al límite de días de `OfflineAllowanceStore` — ver esa
  /// clase y `AuthNotifier.loginWithSellerPin`, que decide cuándo reintentar
  /// así.
  Future<AuthServiceResult> loginWithPinCredential(
    AuthProfile profile, {
    bool offline = false,
  });

  /// Los perfiles de este servidor+base con llave retenida para el PIN —
  /// lo que el selector de `PinLoginScreen` necesita para ofrecer «elegir
  /// entre los usuarios con PIN de este equipo». Ver
  /// `NativeAuthService.pinRetainedProfilesFor`.
  Future<List<AuthProfile>> pinRetainedProfilesFor(
    String serverUrl,
    String database,
  );

  /// Todos los perfiles de este servidor+base cuya llave SIGUE físicamente
  /// en el almacén — sin filtrar por retención. El "método de lectura del
  /// servicio" que `migrateLegacyPinRetention`
  /// (`legacy_pin_retention_migration.dart`) usa para encontrar cuentas que
  /// enrolaron un PIN ANTES de que existiera la retención — ver
  /// `NativeAuthService.profilesWithStoredKeyFor`.
  Future<List<AuthProfile>> profilesWithStoredKeyFor(
    String serverUrl,
    String database,
  );
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

/// Primero en línea; si falla con algo que NO es un rechazo EXPLÍCITO de la
/// credencial ([_isExplicitCredentialRejection] — el MISMO clasificador que
/// [restoreOnce] usa para `restore()`, nunca duplicado aquí), reintenta sin
/// conexión, sujeto al mismo límite de días que `restore(offline: true)`
/// aplica (`OfflineAllowanceStore`, `orbi_runtime`). Un rechazo explícito se
/// relanza tal cual — nunca cae al respaldo offline, igual que [restoreOnce].
Future<AuthServiceResult> _loginWithPinOnlineThenOffline(
  SellerPinAuthServicePort service,
  AuthProfile profile,
) async {
  try {
    return await service.loginWithPinCredential(profile);
  } catch (error) {
    if (_isExplicitCredentialRejection(error)) rethrow;
    return service.loginWithPinCredential(profile, offline: true);
  }
}

class NativeAuthServicePort
    implements
        AuthServicePort,
        ApiKeyAuthServicePort,
        CredentialPolicyAuthServicePort,
        ExpirableAuthServicePort,
        RenewableAuthServicePort,
        StoredCredentialAuthServicePort,
        SellerPinAuthServicePort {
  NativeAuthServicePort(this.service);
  final NativeAuthService service;
  @override
  Future<void> closeExpired() => service.closeExpired();
  @override
  Future<void> retainCredentialForPin(AuthProfile profile, bool retained) =>
      service.retainCredentialForPin(profile, retained);
  @override
  Future<AuthServiceResult> loginWithPinCredential(
    AuthProfile profile, {
    bool offline = false,
  }) => service.loginWithPinCredential(profile, offline: offline);
  @override
  Future<List<AuthProfile>> pinRetainedProfilesFor(
    String serverUrl,
    String database,
  ) => service.pinRetainedProfilesFor(serverUrl, database);
  @override
  Future<List<AuthProfile>> profilesWithStoredKeyFor(
    String serverUrl,
    String database,
  ) => service.profilesWithStoredKeyFor(serverUrl, database);
  @override
  Future<void> renewApiKeyIfNeeded() => service.renewApiKeyIfNeeded();
  @override
  Future<AuthProfile?> findRememberedCredential(
    String serverUrl,
    String database,
    String login,
  ) => service.findRememberedCredential(serverUrl, database, login);
  @override
  Future<AuthServiceResult> loginWithStoredCredential(AuthProfile profile) =>
      service.loginWithStoredCredential(profile);
  @override
  Future<void> forgetStoredCredential(AuthProfile profile) =>
      service.forgetStoredCredential(profile);
  @override
  Future<bool> hasStoredCredential(AuthProfile profile) =>
      service.hasStoredCredential(profile);
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

  /// Límite de sesión sin conexión (decisión del dueño, 14-sep-2026): un
  /// `restore(offline: true)` que [OfflineAllowanceStore.evaluate]
  /// (`orbi_runtime`) rechazó — nunca se activó la sesión, y nada se borró
  /// (llave, marca de sesión abierta, base local, cola offline). Distinto de
  /// [error]: no es un fallo, es un plazo — [AuthViewState.message] ya trae
  /// el texto exacto que debe verse ([offlineAllowanceMessageFor]).
  offlineExpired,
}

/// El mensaje para la pantalla de acceso cuando `restore(offline: true)`
/// devolvió [AuthServiceStatus.offlineExpired] — orden del dueño,
/// 14-sep-2026: distingue el reloj atrasado (nunca sirve para estirar el
/// plazo) del vencimiento normal, con los días y el máximo reales.
String offlineAllowanceMessageFor(OfflineAllowance? allowance) {
  if (allowance?.status == OfflineAllowanceStatus.clockRollback) {
    return 'La fecha de este equipo está atrasada; corrígela y conéctate a '
        'internet.';
  }
  final days = allowance?.daysOffline ?? allowance?.maxDays ?? kDefaultOfflineAllowanceDays;
  final max = allowance?.maxDays ?? kDefaultOfflineAllowanceDays;
  return 'Llevas $days días sin conectarte con Odoo (el máximo es $max). '
      'Conéctate a internet para seguir; tus datos y lo pendiente se '
      'conservan.';
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

  /// Entra por PIN de vendedor reutilizando la llave RETENIDA de [profile]
  /// (`SellerPinAuthServicePort.loginWithPinCredential`) — nunca `restore()`,
  /// que sigue siendo el camino de [restoreForSellerPin] para quien todavía
  /// lo use. Reemplaza a `restoreForSellerPin` como puerta de
  /// `PinLoginScreen` porque ahora hay más de un usuario con PIN posible en
  /// el mismo dispositivo (selector, decisión del dueño 14-sep-2026): la
  /// pantalla ya no puede asumir que «el último perfil» es a quien el PIN
  /// tecleado pertenece.
  ///
  /// Aplica EXACTAMENTE el mismo tope de vendedor que [restoreForSellerPin]:
  /// [snapshotAllowsSellerPin] decide si se puede entrar en absoluto, y
  /// [restrictSnapshotToSellerPin] recorta el resultado — un usuario
  /// multirrol nunca sale de aquí con Caja, Aprobaciones o Administración
  /// sólo por haber entrado con PIN.
  ///
  /// 🔴 Ampliado el 14-sep-2026 («Orbi debe funcionar offline: el cambio de
  /// usuario con PIN también»): primero intenta en línea
  /// (`loginWithPinCredential(profile)`); si eso falla con un error que NO
  /// es un rechazo EXPLÍCITO de la credencial, reintenta con
  /// `offline: true` — la MISMA regla que [restoreOnce] aplica a
  /// `restore()`, reutilizando su propio clasificador
  /// ([_isExplicitCredentialRejection]) en vez de duplicarlo. Un rechazo
  /// explícito se relanza tal cual y cae al mismo `catch` de abajo. El tope
  /// de vendedor de más abajo se aplica igual sobre el resultado de
  /// cualquiera de los dos caminos, y `offlineExpired` llega hasta
  /// [_fromAttempt]/[_fromResult], que ya lo traduce con el mismo mensaje
  /// que usa el acceso normal ([offlineAllowanceMessageFor]).
  Future<void> loginWithSellerPin(AuthProfile profile) async {
    state = const AuthViewState(status: AuthControllerStatus.loading);
    final service = _service;
    if (service is! SellerPinAuthServicePort) {
      state = const AuthViewState(
        status: AuthControllerStatus.error,
        message: 'El PIN no está disponible en esta plataforma.',
      );
      return;
    }
    final pinService = service as SellerPinAuthServicePort;
    try {
      final result = await _loginWithPinOnlineThenOffline(
        pinService,
        profile,
      );
      if (!ref.mounted) return;
      final restored = _fromAttempt(result);
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
      // Mismas causas que [login]/[restore]: nada aquí se deriva del PIN
      // mismo, así que no filtra qué PIN existe o no.
      state = AuthViewState(
        status: AuthControllerStatus.error,
        message: describeLoginFailure(error).flatten(),
      );
    }
  }

  /// Marca (o desmarca) la llave de [profile] como retenida para el PIN de
  /// vendedor — `null`-safe: en una plataforma sin
  /// [SellerPinAuthServicePort] simplemente no hace nada (ningún PIN que
  /// ofrecer ahí tampoco).
  Future<void> retainCredentialForPin(AuthProfile profile, bool retained) async {
    if (_service case final SellerPinAuthServicePort port) {
      await port.retainCredentialForPin(profile, retained);
    }
  }

  /// Los perfiles de [serverUrl]/[database] con llave retenida para el PIN —
  /// lo que `PinLoginScreen` cruza contra `PinCredentialStore.isEnrolled`
  /// para construir su selector. Lista vacía, nunca un error, en cualquier
  /// plataforma sin [SellerPinAuthServicePort].
  Future<List<AuthProfile>> pinRetainedProfilesFor(
    String serverUrl,
    String database,
  ) async {
    if (_service case final SellerPinAuthServicePort port) {
      return port.pinRetainedProfilesFor(serverUrl, database);
    }
    return const [];
  }

  /// Los perfiles de [serverUrl]/[database] cuya llave sigue físicamente en
  /// el almacén, SIN filtrar por retención — lo que
  /// `migrateLegacyPinRetention` (`legacy_pin_retention_migration.dart`) usa
  /// para encontrar credenciales de un PIN enrolado ANTES de que existiera
  /// la retención. Lista vacía, nunca un error, en cualquier plataforma sin
  /// [SellerPinAuthServicePort].
  Future<List<AuthProfile>> profilesWithStoredKeyFor(
    String serverUrl,
    String database,
  ) async {
    if (_service case final SellerPinAuthServicePort port) {
      return port.profilesWithStoredKeyFor(serverUrl, database);
    }
    return const [];
  }

  /// Ends the session. This is the single path behind both "Cerrar sesión" and
  /// "Cambiar de usuario" (see `confirmSwitchWorkspaceUser`).
  ///
  /// 🔴 Revocado en parte el 13-sep-2026 (decisión del dueño, «Recordar la
  /// llave tras salir», `W04-el-navegador-tambien-guarda.md`): esto solía
  /// borrar SIEMPRE la derivación de [WorkspaceUnlockStore], sin importar si
  /// el operador había activado «Guardar clave». Ahora sigue la MISMA regla
  /// que la propia llave API (que `NativeAuthService.close()` sólo revoca y
  /// borra cuando NO se pidió «Guardar clave» — ver el comentario de esa
  /// clase, auditoría de sesión, 14-sep-2026): si todavía hay una llave
  /// guardada para este perfil, esta salida tampoco olvida su derivado de
  /// desbloqueo sin conexión — las dos cosas sobreviven juntas, porque las
  /// dos existen por la misma promesa de «recuérdame en este equipo». Si NO
  /// hay llave guardada (el operador nunca activó el interruptor), se borra
  /// exactamente como antes: no hay nada nuevo que preservar ahí.
  Future<void> close() async {
    final profile = state.profile;
    final unlockStore = ref.read(workspaceUnlockStoreProvider);
    if (profile != null) {
      var keepsCredential = false;
      if (_service case final StoredCredentialAuthServicePort port) {
        keepsCredential = await port.hasStoredCredential(profile);
      }
      if (!keepsCredential) {
        await unlockStore.forget(workspaceUnlockScopeKeyFor(profile));
      }
    }
    await _service.close();
    if (!ref.mounted) return;
    // Drop profile/capabilities immediately so providers cannot retain the
    // previous user's company scope after teardown.
    state = const AuthViewState();
  }

  /// Lo que la pantalla de acceso necesita para mostrar «Clave guardada en
  /// este equipo» para el servidor/base/usuario elegidos ahora mismo. `null`
  /// en cualquier plataforma que no implemente
  /// [StoredCredentialAuthServicePort] (ningún interruptor que ofrecer,
  /// nunca un error) y en cualquier combinación sin llave guardada.
  Future<AuthProfile?> findRememberedCredential(
    String serverUrl,
    String database,
    String login,
  ) async {
    if (_service case final StoredCredentialAuthServicePort port) {
      return port.findRememberedCredential(serverUrl, database, login);
    }
    return null;
  }

  /// Entra con la llave guardada de [profile], sin que el operador haya
  /// escrito nada. Un rechazo explícito del servidor (la llave venció o fue
  /// revocada) se traduce en [LoginFailureCause.storedCredentialExpired] —
  /// nunca en «el usuario o la contraseña no coinciden», que sería mentira
  /// aquí: nadie tecleó una contraseña equivocada. La llave ya quedó borrada
  /// por el propio servicio antes de que este catch se ejecute.
  Future<void> loginWithStoredCredential(AuthProfile profile) async {
    state = const AuthViewState(status: AuthControllerStatus.loading);
    if (_service case final StoredCredentialAuthServicePort port) {
      try {
        final result = await port.loginWithStoredCredential(profile);
        if (!ref.mounted) return;
        state = _fromAttempt(result);
      } on OdooAuthenticationException {
        if (!ref.mounted) return;
        state = AuthViewState(
          status: AuthControllerStatus.error,
          message: loginFailureMessageFor(
            LoginFailureCause.storedCredentialExpired,
          ).flatten(),
        );
      } catch (error) {
        if (!ref.mounted) return;
        state = AuthViewState(
          status: AuthControllerStatus.error,
          message: describeLoginFailure(error).flatten(),
        );
      }
      return;
    }
    state = const AuthViewState(
      status: AuthControllerStatus.error,
      message: 'Esta plataforma no puede reutilizar una llave guardada.',
    );
  }

  /// «Olvidar la clave guardada»: nunca lanza, y no cambia el estado de
  /// autenticación — se llama tanto desde la pantalla de acceso (sin sesión)
  /// como, potencialmente, con una sesión ya abierta.
  Future<void> forgetStoredCredential(AuthProfile profile) async {
    if (_service case final StoredCredentialAuthServicePort port) {
      await port.forgetStoredCredential(profile);
    }
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
        AuthServiceStatus.offlineExpired => AuthViewState(
          status: AuthControllerStatus.offlineExpired,
          message: offlineAllowanceMessageFor(result.offlineAllowance),
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
      AuthServiceStatus.offlineExpired => AuthViewState(
        status: AuthControllerStatus.offlineExpired,
        message: offlineAllowanceMessageFor(result.offlineAllowance),
      ),
    };
