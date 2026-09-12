import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/preferences/app_preferences.dart';

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
String pinScopeKeyFor(String serverUrl, String database, String login) {
  final encoded = base64Url
      .encode(utf8.encode('$serverUrl|$database|$login'))
      .replaceAll('=', '');
  return encoded;
}

/// Local, per-scope lockout bookkeeping. Never carries the PIN itself.
final class SellerPinAttemptState {
  const SellerPinAttemptState({this.failedAttempts = 0, this.lockedUntil});

  final int failedAttempts;
  final DateTime? lockedUntil;

  bool isLockedAt(DateTime now) =>
      lockedUntil != null && lockedUntil!.isAfter(now);

  Duration remainingAt(DateTime now) {
    final until = lockedUntil;
    if (until == null || !until.isAfter(now)) return Duration.zero;
    return until.difference(now);
  }
}

/// Stores only a salted, iterated hash of the seller PIN — never the PIN
/// itself, in cleartext, a reversible encoding, or a log line.
///
/// This is the non-negotiable rule from the coordinator handoff: a PIN is
/// weaker than a password precisely because it is short and numeric (this
/// store's own [kSellerPinLength] means at most 10,000 possibilities), so at
/// rest it must never become a recoverable secret. Salting defeats
/// rainbow-table lookups across installs; iterating the hash (a minimal
/// manual PBKDF2-HMAC-SHA256 — `crypto` has no PBKDF2 of its own) raises the
/// per-guess cost of an offline dump read, on top of the online lockout in
/// [registerFailure]/[kSellerPinMaxAttempts].
final class PinCredentialStore {
  PinCredentialStore(this.preferences);

  final SharedPreferences preferences;

  /// Kept modest deliberately: [verify] runs synchronously on the UI isolate
  /// (no `compute()` boundary), so raising this trades away frame budget on
  /// every PIN attempt. A future task that needs a materially higher cost
  /// should move hashing off the UI isolate first, not just raise this
  /// number.
  static const _iterations = 10000;
  static const _saltLength = 16;

  String _hashKey(String scopeKey) => 'orbi/auth/pin/hash/$scopeKey';
  String _attemptsKey(String scopeKey) => 'orbi/auth/pin/attempts/$scopeKey';

  bool isEnrolled(String scopeKey) =>
      preferences.getString(_hashKey(scopeKey)) != null;

  Future<void> enroll(String scopeKey, String pin) async {
    final error = validateSellerPin(pin);
    if (error != null) throw FormatException(error);
    final salt = _randomSalt();
    final hash = _derive(pin, salt, _iterations);
    final payload = jsonEncode({
      'version': 1,
      'salt': base64Encode(salt),
      'hash': base64Encode(hash),
      'iterations': _iterations,
    });
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
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['version'] != 1) return false;
      final salt = base64Decode(json['salt'] as String);
      final storedHash = base64Decode(json['hash'] as String);
      final iterations = json['iterations'] as int;
      final candidate = _derive(pin, salt, iterations);
      return _constantTimeEquals(candidate, storedHash);
    } catch (_) {
      return false;
    }
  }

  SellerPinAttemptState readAttempts(String scopeKey) {
    final raw = preferences.getString(_attemptsKey(scopeKey));
    if (raw == null) return const SellerPinAttemptState();
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final failed = json['failedAttempts'] as int? ?? 0;
      final lockedRaw = json['lockedUntil'] as String?;
      return SellerPinAttemptState(
        failedAttempts: failed,
        lockedUntil: lockedRaw == null ? null : DateTime.parse(lockedRaw),
      );
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
    final current = readAttempts(scopeKey);
    final effectiveNow = now ?? DateTime.now();
    final failed = current.failedAttempts + 1;
    final locked = failed >= kSellerPinMaxAttempts;
    final next = SellerPinAttemptState(
      failedAttempts: locked ? 0 : failed,
      lockedUntil: locked ? effectiveNow.add(kSellerPinLockoutDuration) : null,
    );
    final ok = await preferences.setString(
      _attemptsKey(scopeKey),
      jsonEncode({
        'failedAttempts': next.failedAttempts,
        'lockedUntil': next.lockedUntil?.toIso8601String(),
      }),
    );
    if (!ok) throw StateError('El estado de intentos no se pudo guardar');
    return next;
  }

  static Uint8List _randomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _derive(String pin, Uint8List salt, int iterations) {
    // A manual iterated HMAC stretch (a minimal PBKDF2-HMAC-SHA256): every
    // round re-hashes the previous block keyed by the salt, so recovering a
    // PIN from what's on disk costs roughly as much work as it would against
    // a real KDF — never a single fast `sha256(pin)`, which a 4-digit PIN's
    // 10,000-value space would make trivial to brute-force offline.
    var block = Uint8List.fromList(utf8.encode(pin));
    for (var round = 0; round < iterations; round++) {
      block = Uint8List.fromList(Hmac(sha256, salt).convert(block).bytes);
    }
    return block;
  }

  static bool _constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

final pinCredentialStoreProvider = Provider<PinCredentialStore>(
  (ref) => PinCredentialStore(ref.watch(sharedPreferencesProvider)),
);
