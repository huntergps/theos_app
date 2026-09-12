/// Storage-agnostic mechanism for keeping a *derivation* of a secret on the
/// device instead of the secret itself.
///
/// Extracted verbatim from `pin_credential_store.dart`, which invented it for
/// the seller PIN: the workspace lock screen needs exactly the same three
/// properties, so the mechanism lives here once rather than twice.
///
/// 1. **Never the secret.** Only a salted, iterated hash is ever written, so
///    a dump of what is at rest does not hand anybody the secret back.
/// 2. **A fresh random salt per enrolment**, which defeats rainbow tables and
///    makes two devices (or two users) that happen to share a secret look
///    completely different at rest.
/// 3. **Constant-time comparison**, so the time a rejection takes leaks
///    nothing about how much of the candidate was right.
///
/// Where the encoded payload is persisted is deliberately *not* decided here:
/// the PIN keeps it in `SharedPreferences`, the workspace unlock derivation
/// keeps it in the operating system's secure store. See
/// `workspace_unlock_store.dart` for why that difference matters.
library;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Kept modest deliberately: [SecretDerivation.matches] runs synchronously on
/// the UI isolate (no `compute()` boundary), so raising this trades away frame
/// budget on every attempt. A future task that needs a materially higher cost
/// should move hashing off the UI isolate first, not just raise this number.
const int kSecretDerivationIterations = 10000;

const int _saltLength = 16;

/// Derives the key a per-account secret is stored under. Never embeds the raw
/// server, database, login or user id: the key itself is as visible as the
/// payload, and a key that spelled out `login` would leak who uses the device
/// to anything that can list stored keys.
String secretScopeKey(List<String> parts) => base64Url
    .encode(utf8.encode(parts.join('|')))
    .replaceAll('=', '');

/// A salted, iterated hash of a secret, plus the parameters needed to check a
/// candidate against it. Carries the secret only transiently, inside
/// [SecretDerivation.fromSecret] and [matches]; never as a field.
final class SecretDerivation {
  const SecretDerivation({
    required this.salt,
    required this.hash,
    required this.iterations,
  });

  /// Enrols [secret] under a freshly drawn random salt.
  factory SecretDerivation.fromSecret(
    String secret, {
    int iterations = kSecretDerivationIterations,
  }) {
    final salt = _randomSalt();
    return SecretDerivation(
      salt: salt,
      hash: _derive(secret, salt, iterations),
      iterations: iterations,
    );
  }

  /// Reads back a payload written by [encode]. Throws [FormatException] on
  /// anything it does not recognise — including a future payload version, so
  /// an older build never "verifies" against a format it cannot evaluate.
  factory SecretDerivation.decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error) {
      throw FormatException('unreadable secret derivation payload: $error');
    }
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('secret derivation payload is not an object');
    }
    if (decoded['version'] != 1) {
      throw const FormatException('unknown secret derivation version');
    }
    final salt = decoded['salt'];
    final hash = decoded['hash'];
    final iterations = decoded['iterations'];
    if (salt is! String || hash is! String || iterations is! int) {
      throw const FormatException('invalid secret derivation payload');
    }
    if (iterations <= 0) {
      throw const FormatException('secret derivation iterations must be > 0');
    }
    return SecretDerivation(
      salt: Uint8List.fromList(base64Decode(salt)),
      hash: Uint8List.fromList(base64Decode(hash)),
      iterations: iterations,
    );
  }

  final Uint8List salt;
  final Uint8List hash;
  final int iterations;

  /// The payload to persist. [iterations] travels with it so raising the cost
  /// later never invalidates what is already enrolled.
  String encode() => jsonEncode({
    'version': 1,
    'salt': base64Encode(salt),
    'hash': base64Encode(hash),
    'iterations': iterations,
  });

  /// Constant-time check of [candidate] against this derivation.
  bool matches(String candidate) =>
      _constantTimeEquals(_derive(candidate, salt, iterations), hash);

  static Uint8List _randomSalt() {
    final random = Random.secure();
    return Uint8List.fromList(
      List<int>.generate(_saltLength, (_) => random.nextInt(256)),
    );
  }

  static Uint8List _derive(String secret, Uint8List salt, int iterations) {
    // A manual iterated HMAC stretch (a minimal PBKDF2-HMAC-SHA256 — `crypto`
    // has no PBKDF2 of its own): every round re-hashes the previous block
    // keyed by the salt, so recovering the secret from what's on disk costs
    // roughly as much work as it would against a real KDF — never a single
    // fast `sha256(secret)`, which a four-digit PIN's 10,000-value space
    // would make trivial to brute-force offline.
    var block = Uint8List.fromList(utf8.encode(secret));
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

/// Local, per-scope lockout bookkeeping for repeated wrong attempts against a
/// stored [SecretDerivation]. Never carries the secret itself.
///
/// A derivation at rest is attackable at the attacker's own pace unless the
/// *app* refuses to keep evaluating candidates, which is what this is for: the
/// iteration cost raises the price of each guess, this caps how many guesses
/// the app itself will perform.
final class LocalAttemptState {
  const LocalAttemptState({this.failedAttempts = 0, this.lockedUntil});

  /// Reads back a payload written by [encode]; a corrupt or absent payload
  /// reads as "no failures", never as a permanent lockout that would strand
  /// the operator.
  factory LocalAttemptState.decode(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('attempt payload is not an object');
    }
    final lockedRaw = decoded['lockedUntil'] as String?;
    return LocalAttemptState(
      failedAttempts: decoded['failedAttempts'] as int? ?? 0,
      lockedUntil: lockedRaw == null ? null : DateTime.parse(lockedRaw),
    );
  }

  final int failedAttempts;
  final DateTime? lockedUntil;

  bool isLockedAt(DateTime now) =>
      lockedUntil != null && lockedUntil!.isAfter(now);

  Duration remainingAt(DateTime now) {
    final until = lockedUntil;
    if (until == null || !until.isAfter(now)) return Duration.zero;
    return until.difference(now);
  }

  String encode() => jsonEncode({
    'failedAttempts': failedAttempts,
    'lockedUntil': lockedUntil?.toIso8601String(),
  });

  /// The state after one more wrong attempt. Once [maxAttempts] is reached the
  /// counter resets and a [lockout] window starts — the counter never keeps
  /// accumulating past the lock, so a stale high count can't shorten a later
  /// window.
  LocalAttemptState afterFailure({
    required int maxAttempts,
    required Duration lockout,
    required DateTime now,
  }) {
    final failed = failedAttempts + 1;
    final locked = failed >= maxAttempts;
    return LocalAttemptState(
      failedAttempts: locked ? 0 : failed,
      lockedUntil: locked ? now.add(lockout) : null,
    );
  }
}
