import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show logger;
import 'package:orbi_runtime/orbi_runtime.dart';

import 'unlock_backend_factory.dart';

import 'pin_credential_store.dart'
    show kSellerPinLockoutDuration, kSellerPinMaxAttempts;
import 'secret_derivation.dart';

/// What happened when the lock screen's password was checked against what is
/// stored on this device. Never carries the password, the derivation, or how
/// close a rejected attempt came to being right.
enum WorkspaceUnlockVerdict {
  /// This platform has nowhere safe to keep a derivation, so nothing was even
  /// looked at. Today: the web. The caller must fall back to the server.
  unavailable,

  /// Nothing is enrolled for this identity yet — the very first lock after a
  /// cold start, or after a logout wiped it. The caller must fall back to the
  /// server, which is also what enrols it.
  notEnrolled,

  /// The password matches the stored derivation. No network was used.
  unlocked,

  /// A derivation exists and the password does not match it. The caller may
  /// still try the server: this is exactly what a password changed on the
  /// server looks like from here.
  rejected,

  /// Too many consecutive wrong attempts. Refuse outright, including the
  /// server path: the point of the cap is that the app stops evaluating
  /// candidates at all.
  lockedOut,
}

/// The same ceiling and window the seller PIN uses (ACC-02). Deliberately
/// tracks those constants instead of inventing a second pair of numbers that
/// could silently drift from them — a password derivation at rest needs a cap
/// for the same reason a PIN does.
const int kWorkspaceUnlockMaxAttempts = kSellerPinMaxAttempts;
const Duration kWorkspaceUnlockLockoutDuration = kSellerPinLockoutDuration;

/// Scope key the workspace unlock derivation is stored under. Includes the
/// numeric `userId` on top of server/database/login, so two different Odoo
/// users who happen to share a login string on different databases — or the
/// same login re-pointed at a different user — can never verify against each
/// other's derivation. The key itself reveals none of those values (see
/// [secretScopeKey]).
String workspaceUnlockScopeKeyFor(AuthProfile profile) => secretScopeKey([
  profile.serverUrl,
  profile.database,
  profile.login,
  '${profile.userId}',
]);

/// Lets the operational shell's lock screen be opened with **no network**, by
/// checking the password against a derivation kept on the device instead of
/// re-authenticating against Odoo.
///
/// ## Why this exists
///
/// The lock screen is a privacy gate over a session that is *already*
/// authenticated — locking never ends the session, and unlocking is not a new
/// login (see `attemptWorkspaceUnlock`). Validating it through
/// `AuthService.login` meant the one app that advertises working offline had a
/// door that only opened with connectivity: an operator who locked the screen
/// in a warehouse basement could not get back to their own half-finished sale
/// except by logging out.
///
/// ## What is kept, and where
///
/// Only a [SecretDerivation] — salted, iterated, irreversible. Never the
/// password, in cleartext, in a reversible encoding, or in a log line.
///
/// **Every platform persists it** — the owner's decision of 11-sep-2026, «yo
/// he dicho que navegador también guarda igual que escritorio»
/// (`docs/orbi_panel/decisions/W04-el-navegador-tambien-guarda.md`). "Igual
/// que escritorio" is a guarantee, not a mechanism, and the two platforms
/// reach it differently:
///
/// * **native** — the operating system's secure store (Keychain on iOS/macOS,
///   Keystore-backed `EncryptedSharedPreferences` on Android, libsecret on
///   Linux, DPAPI on Windows), through the very same [CredentialBackend] the
///   runtime already uses for the Odoo API key; never `SharedPreferences`,
///   which is a plain file any process running as the user can read.
/// * **web** — `WebCryptoCredentialBackend`: the payload is AES-GCM encrypted
///   under a **non-extractable** key kept in IndexedDB, which the page's own
///   code can use but cannot read back. Deliberately NOT the default
///   mechanism of `flutter_secure_storage_web`, which keeps its AES key in the
///   same `localStorage` as the ciphertext — the key under the doormat.
///
/// Which one is compiled in is decided by `unlock_backend_factory.dart` at
/// compile time, so this class carries no platform branch of its own.
///
/// ## What it costs an attacker
///
/// Guessing against the stored payload costs [kSecretDerivationIterations]
/// HMAC rounds per candidate, and the app itself stops answering after
/// [kWorkspaceUnlockMaxAttempts] consecutive failures for
/// [kWorkspaceUnlockLockoutDuration].
///
/// ## Lifetime
///
/// Written on a successful password login that the user chose to persist, and
/// on a successful online unlock. Erased by `AuthNotifier.close()`, which is
/// the single path behind both "Cerrar sesión" and "Cambiar de usuario", so a
/// derivation is never left behind as an orphan credential for an identity
/// that is no longer on the device.
///
/// ## The residual risk, stated plainly
///
/// If the password is changed on the server while this device is offline, the
/// old derivation still opens the lock until the device is online again. The
/// device cannot learn about a server-side change without talking to the
/// server, so this cannot be closed from here. Three things bound it: the lock
/// only gates a session that is already open on this device (the old password
/// grants nothing the device's holder did not already have), the *new*
/// password works online and immediately overwrites the derivation, and the
/// derivation is erased on logout. A freshness bound ("refuse an offline
/// unlock against a derivation older than N days") would shrink the window
/// further at the cost of locking out genuinely offline operators; that is a
/// product decision, not one this class should make on its own.
///
/// Every method is failure-tolerant on purpose: a device whose secure store is
/// unavailable (no plugin, a locked Keychain, a test host) must degrade to
/// "unlocking needs the network", never break logging in.
final class WorkspaceUnlockStore {
  const WorkspaceUnlockStore(this._backend);

  /// `null` means this platform has nowhere safe to keep a derivation.
  final CredentialBackend? _backend;

  /// Whether this platform can keep a derivation at all. `false` on the web.
  bool get isSupported => _backend != null;

  String _hashKey(String scopeKey) => 'orbi/auth/unlock/hash/$scopeKey';
  String _attemptsKey(String scopeKey) => 'orbi/auth/unlock/attempts/$scopeKey';

  /// Enrols [password] for [scopeKey]. Returns whether it was actually stored:
  /// `false` on the web, and `false` when the secure store refuses. Never
  /// throws — a login must not fail because this optimization could not be
  /// saved.
  Future<bool> remember(String scopeKey, String password) async {
    final backend = _backend;
    if (backend == null) {
      _reportUnavailable(
        'no hay almacén durable en esta plataforma',
        null,
      );
      return false;
    }
    if (password.isEmpty) return false;
    try {
      await backend.write(
        _hashKey(scopeKey),
        SecretDerivation.fromSecret(password).encode(),
      );
      // A fresh enrolment always starts from a clean attempt count: whoever
      // proved the password just now must not inherit an earlier lockout.
      await backend.delete(_attemptsKey(scopeKey));
      return true;
    } catch (error) {
      _reportUnavailable('el almacén seguro rechazó la escritura', error);
      return false;
    }
  }

  /// Leaves a trace when the offline unlock silently stops existing.
  ///
  /// This branch is reached when the platform store refuses — a macOS keychain
  /// without the signing entitlements (`SecItemAdd` −34018), a browser with
  /// site data blocked, a device with no durable store at all. The feature
  /// then degrades safely to "unlocking needs the network", which is the
  /// problem: **safe and silent is the worst pair**, because nobody finds out
  /// the offline path is gone until an operator is stranded with no signal.
  ///
  /// The user is deliberately NOT told: there is nothing they can do about an
  /// entitlement or a browser policy, so a dialog would be noise. The
  /// application log is the right place, and it reaches release builds too
  /// (`AppLogger.minLevel` keeps `warning` there).
  ///
  /// It never names the password, the derivation, the scope key or the
  /// identity — only the reason the store refused. `AppLogger` additionally
  /// sanitizes every message it prints.
  void _reportUnavailable(String reason, Object? error) {
    logger.w(
      '[WorkspaceUnlock]',
      'Desbloqueo sin conexión INACTIVO: $reason. '
          'La pantalla de bloqueo seguirá exigiendo red'
          '${error == null ? '' : ' ($error)'}.',
    );
  }

  /// Removes the derivation and its attempt bookkeeping. Never throws: a
  /// logout must complete even if the secure store is unhappy.
  Future<void> forget(String scopeKey) async {
    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.delete(_hashKey(scopeKey));
    } catch (_) {
      // Fall through: still try to drop the attempt counter.
    }
    try {
      await backend.delete(_attemptsKey(scopeKey));
    } catch (_) {
      // Nothing else to do; the counter alone is not a credential.
    }
  }

  /// Whether an offline unlock is possible for [scopeKey] right now.
  Future<bool> isRemembered(String scopeKey) async {
    final backend = _backend;
    if (backend == null) return false;
    try {
      return await backend.read(_hashKey(scopeKey)) != null;
    } catch (_) {
      return false;
    }
  }

  /// Checks [password] against the stored derivation in constant time, with no
  /// network whatsoever. Never throws.
  Future<WorkspaceUnlockVerdict> verify(
    String scopeKey,
    String password, {
    DateTime? now,
  }) async {
    final backend = _backend;
    if (backend == null) return WorkspaceUnlockVerdict.unavailable;
    final moment = now ?? DateTime.now();
    final String? rawHash;
    final LocalAttemptState attempts;
    try {
      attempts = await _readAttempts(backend, scopeKey);
      if (attempts.isLockedAt(moment)) return WorkspaceUnlockVerdict.lockedOut;
      rawHash = await backend.read(_hashKey(scopeKey));
    } catch (_) {
      return WorkspaceUnlockVerdict.unavailable;
    }
    if (rawHash == null) return WorkspaceUnlockVerdict.notEnrolled;
    final SecretDerivation derivation;
    try {
      derivation = SecretDerivation.decode(rawHash);
    } catch (_) {
      // An unreadable payload is not a credential: drop it instead of leaving
      // a dead entry that can never verify and never expires.
      await forget(scopeKey);
      return WorkspaceUnlockVerdict.notEnrolled;
    }
    if (derivation.matches(password)) {
      try {
        await backend.delete(_attemptsKey(scopeKey));
      } catch (_) {
        // A surviving counter only costs the next attempt, never this one.
      }
      return WorkspaceUnlockVerdict.unlocked;
    }
    final next = attempts.afterFailure(
      maxAttempts: kWorkspaceUnlockMaxAttempts,
      lockout: kWorkspaceUnlockLockoutDuration,
      now: moment,
    );
    try {
      await backend.write(_attemptsKey(scopeKey), next.encode());
    } catch (_) {
      // A cap that cannot be recorded must not become a cap that cannot be
      // enforced either: report the lockout the state we just computed says.
    }
    return next.isLockedAt(moment)
        ? WorkspaceUnlockVerdict.lockedOut
        : WorkspaceUnlockVerdict.rejected;
  }

  Future<LocalAttemptState> _readAttempts(
    CredentialBackend backend,
    String scopeKey,
  ) async {
    final raw = await backend.read(_attemptsKey(scopeKey));
    if (raw == null) return const LocalAttemptState();
    try {
      return LocalAttemptState.decode(raw);
    } catch (_) {
      return const LocalAttemptState();
    }
  }
}

/// Where the workspace unlock derivation may be kept on this platform.
///
/// **Inert by default, and the composition root supplies the real one** — the
/// same shape `sharedPreferencesProvider` and `authServiceProvider` already
/// use in this app. `null` means "this platform has nowhere to keep a
/// derivation", which [WorkspaceUnlockStore] reports as
/// [WorkspaceUnlockVerdict.unavailable] so unlocking falls back to the server:
/// today's behaviour, never a broken one.
///
/// It must not default to the platform-backed store because **a plugin-backed
/// platform channel never completes inside a widget
/// test's fake-async zone.** `AuthNotifier.login` and `AuthNotifier.close`
/// await this store, so a live default deadlocks any widget test that does not
/// override it. That is not hypothetical: it hung
/// `test/app/workspace_switch_user_router_test.dart` for `pumpAndSettle`'s
/// entire ten-minute budget, a test that passes in two seconds otherwise.
/// Handing the platform-backed backend in from the composition root keeps every
/// test inert unless it asks for storage on purpose.
final workspaceUnlockBackendProvider = Provider<CredentialBackend?>(
  (ref) => null,
);

/// The override `bootstrap.dart` must register for the offline unlock to do
/// anything on a real device: `workspaceUnlockBackendOverride` in the root
/// `ProviderScope`'s `overrides`, alongside `sharedPreferencesProvider`.
///
/// Without it the app still works exactly as it did before offline unlock
/// existed — the lock screen simply keeps needing the network.
// Declared as an inferred `final` rather than returning a named override type,
// so this file never has to spell a Riverpod internal type name. Which backend
// `createUnlockCredentialBackend` returns is decided at compile time by
// `unlock_backend_factory.dart` — no `kIsWeb` branch lives here any more,
// because the web is no longer the platform that stores nothing.
final workspaceUnlockBackendOverride = workspaceUnlockBackendProvider
    .overrideWithValue(createUnlockCredentialBackend());

final workspaceUnlockStoreProvider = Provider<WorkspaceUnlockStore>(
  (ref) => WorkspaceUnlockStore(ref.watch(workspaceUnlockBackendProvider)),
);
