import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/preferences/app_preferences.dart';
import 'secret_derivation.dart';

/// ACC-02 shows four dot indicators: the PIN is always exactly this long.
const int kSellerPinLength = 4;

/// Consecutive wrong PINs allowed before the device locks itself out, per
/// ACC-02's "Bloqueo parametrizado" state. Not a security-team target, just
/// the mockup's own contract; a real parametrization is a binding pending
/// against Odoo (see NAVIGATION_CAPABILITY_MATRIX.md, "Bindings pendientes").
const int kSellerPinMaxAttempts = 4;

/// ACC-02's lockout state reads "Se ha alcanzado el número máximo de
/// intentos. Intenta nuevamente en: 00:05:00".
const Duration kSellerPinLockoutDuration = Duration(minutes: 5);

/// `null` means the PIN is well-formed; otherwise the reason it is rejected.
String? validateSellerPin(String pin) {
  if (pin.length != kSellerPinLength) {
    return 'El PIN debe tener $kSellerPinLength dígitos';
  }
  if (!RegExp(r'^\d+$').hasMatch(pin)) return 'El PIN sólo admite números';
  return null;
}

/// Derives the per-account key PIN storage is scoped under, mirroring the
/// scoping `NativeAuthService` already uses for profiles: PIN is a property
/// of one login on one server/database, never shared across accounts sharing
/// a device.
String pinScopeKeyFor(String serverUrl, String database, String login) =>
    secretScopeKey([serverUrl, database, login]);

/// Local, per-scope lockout bookkeeping. Never carries the PIN itself.
///
/// An alias of the shared [LocalAttemptState] rather than a second copy of it:
/// the workspace lock screen needs the very same bookkeeping, and two
/// independent implementations of a lockout counter would be two places for it
/// to drift.
typedef SellerPinAttemptState = LocalAttemptState;

/// Stores only a salted, iterated hash of the seller PIN — never the PIN
/// itself, in cleartext, a reversible encoding, or a log line.
///
/// This is the non-negotiable rule from the coordinator handoff: a PIN is
/// weaker than a password precisely because it is short and numeric (this
/// store's own [kSellerPinLength] means at most 10,000 possibilities), so at
/// rest it must never become a recoverable secret. The hashing, salting,
/// iterating and constant-time comparison all live in [SecretDerivation] (see
/// `secret_derivation.dart`); this class only decides *where* the payload
/// goes and *when* the device locks itself out.
///
/// The PIN's payload lives in `SharedPreferences` and not in the operating
/// system's secure store, which is a deliberate difference from
/// `WorkspaceUnlockStore`: the PIN is a convenience door the device owner
/// enrolled locally and which `restrictSnapshotToSellerPin` clamps to the
/// seller ceiling, while the workspace unlock derivation stands in for the
/// Odoo account password itself.
final class PinCredentialStore {
  PinCredentialStore(this.preferences);

  final SharedPreferences preferences;

  String _hashKey(String scopeKey) => 'orbi/auth/pin/hash/$scopeKey';
  String _attemptsKey(String scopeKey) => 'orbi/auth/pin/attempts/$scopeKey';

  bool isEnrolled(String scopeKey) =>
      preferences.getString(_hashKey(scopeKey)) != null;

  Future<void> enroll(String scopeKey, String pin) async {
    final error = validateSellerPin(pin);
    if (error != null) throw FormatException(error);
    final payload = SecretDerivation.fromSecret(pin).encode();
    final ok = await preferences.setString(_hashKey(scopeKey), payload);
    if (!ok) throw StateError('El PIN no se pudo guardar');
    await clearAttempts(scopeKey);
  }

  Future<void> forget(String scopeKey) async {
    await preferences.remove(_hashKey(scopeKey));
    await clearAttempts(scopeKey);
  }

  /// Constant-time comparison against the stored derivation. Returns `false`
  /// for a scope with no enrolled PIN, never throws.
  bool verify(String scopeKey, String pin) {
    final raw = preferences.getString(_hashKey(scopeKey));
    if (raw == null) return false;
    try {
      return SecretDerivation.decode(raw).matches(pin);
    } catch (_) {
      return false;
    }
  }

  SellerPinAttemptState readAttempts(String scopeKey) {
    final raw = preferences.getString(_attemptsKey(scopeKey));
    if (raw == null) return const SellerPinAttemptState();
    try {
      return SellerPinAttemptState.decode(raw);
    } catch (_) {
      return const SellerPinAttemptState();
    }
  }

  Future<void> clearAttempts(String scopeKey) async {
    await preferences.remove(_attemptsKey(scopeKey));
  }

  /// Records one wrong PIN and returns the resulting state. Once
  /// [kSellerPinMaxAttempts] is reached the counter resets and a
  /// [kSellerPinLockoutDuration] lockout starts — the counter never keeps
  /// accumulating past the lock, so a stale high count can't shorten a later
  /// window.
  Future<SellerPinAttemptState> registerFailure(
    String scopeKey, {
    DateTime? now,
  }) async {
    final next = readAttempts(scopeKey).afterFailure(
      maxAttempts: kSellerPinMaxAttempts,
      lockout: kSellerPinLockoutDuration,
      now: now ?? DateTime.now(),
    );
    final ok = await preferences.setString(
      _attemptsKey(scopeKey),
      next.encode(),
    );
    if (!ok) throw StateError('El estado de intentos no se pudo guardar');
    return next;
  }
}

final pinCredentialStoreProvider = Provider<PinCredentialStore>(
  (ref) => PinCredentialStore(ref.watch(sharedPreferencesProvider)),
);
