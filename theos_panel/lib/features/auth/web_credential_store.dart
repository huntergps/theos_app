import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import 'workspace_unlock_store.dart' show workspaceUnlockBackendProvider;

/// What `POST /orbi/auth/token` hands back, and every part of it worth keeping.
///
/// The contract is `l10n_ec_collection_box_pos/WEB_AUTH.md` and
/// `controllers/web_token_auth.py`: exactly `database`, `uid`, `token_type`,
/// `scope`, `api_key`, `expires_at`. No name, no e-mail, no company, no groups
/// — so there is nothing here to leak beyond the credential itself.
final class WebAuthCredential {
  const WebAuthCredential({
    required this.database,
    required this.uid,
    required this.tokenType,
    required this.scope,
    required this.apiKey,
    required this.expiresAt,
  });

  /// Reads the route's 200 body. Throws [FormatException] on anything that is
  /// not exactly the documented shape: a credential we cannot fully understand
  /// is one we must not store, because we could not honour its expiry.
  factory WebAuthCredential.fromResponse(Map<String, dynamic> json) {
    final database = json['database'];
    final uid = json['uid'];
    final tokenType = json['token_type'];
    final scope = json['scope'];
    final apiKey = json['api_key'];
    final expiresAt = json['expires_at'];
    if (database is! String ||
        database.isEmpty ||
        uid is! int ||
        uid <= 0 ||
        tokenType is! String ||
        tokenType.isEmpty ||
        scope is! String ||
        scope.isEmpty ||
        apiKey is! String ||
        apiKey.isEmpty ||
        expiresAt is! String ||
        expiresAt.isEmpty) {
      throw const FormatException('respuesta de /orbi/auth/token inesperada');
    }
    return WebAuthCredential(
      database: database,
      uid: uid,
      tokenType: tokenType,
      scope: scope,
      apiKey: apiKey,
      expiresAt: parseServerExpiry(expiresAt),
    );
  }

  factory WebAuthCredential.decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error) {
      throw FormatException('credencial web ilegible: $error');
    }
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('credencial web de versión desconocida');
    }
    return WebAuthCredential(
      database: decoded['database'] as String,
      uid: decoded['uid'] as int,
      tokenType: decoded['token_type'] as String,
      scope: decoded['scope'] as String,
      apiKey: decoded['api_key'] as String,
      expiresAt: DateTime.parse(decoded['expires_at'] as String).toUtc(),
    );
  }

  final String database;
  final int uid;
  final String tokenType;

  /// Always `rpc` today. Kept verbatim rather than assumed, so a server that
  /// starts issuing a different scope is visible instead of silently trusted.
  final String scope;
  final String apiKey;

  /// Always UTC. See [parseServerExpiry] for why that is not a detail.
  final DateTime expiresAt;

  bool isExpiredAt(DateTime now) => !expiresAt.isAfter(now.toUtc());

  Duration remainingAt(DateTime now) {
    final left = expiresAt.difference(now.toUtc());
    return left.isNegative ? Duration.zero : left;
  }

  String encode() => jsonEncode({
    'version': 1,
    'database': database,
    'uid': uid,
    'token_type': tokenType,
    'scope': scope,
    'api_key': apiKey,
    // Written back as a real ISO-8601 instant with the Z, so our own round
    // trip can never be ambiguous the way the server's format is.
    'expires_at': expiresAt.toUtc().toIso8601String(),
  });

  /// Parses the server's `expires_at`, **forcing UTC when it carries no zone**.
  ///
  /// 🔴 This is not pedantry. Odoo serialises with
  /// `fields.Datetime.to_string`, which yields `'YYYY-MM-DD HH:MM:SS'` in UTC
  /// and with **no timezone marker at all**. `DateTime.parse` reads such a
  /// string as LOCAL time, so in Ecuador (UTC−5) the expiry would land five
  /// hours later than it really is and this client would keep using a dead key
  /// for five hours — failing every request and blaming the network.
  ///
  /// A value that does carry a zone (`Z` or `±HH:MM`) is respected as given, so
  /// the day the route switches to real ISO-8601 nothing here has to change.
  static DateTime parseServerExpiry(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) throw const FormatException('expires_at vacío');
    final iso = trimmed.contains('T')
        ? trimmed
        : trimmed.replaceFirst(' ', 'T');
    final zoned =
        iso.endsWith('Z') ||
        iso.endsWith('z') ||
        RegExp(r'[+-]\d{2}:?\d{2}$').hasMatch(iso);
    return DateTime.parse(zoned ? iso : '${iso}Z').toUtc();
  }
}

/// Keeps the web session's API key across reloads — the half of W04 that is
/// about the **credential**, next to the half about the unlock derivation.
///
/// Both ride the same platform-backed store, so on the web both end up AES-GCM
/// encrypted under the non-extractable IndexedDB key that the page can use and
/// cannot read (`WebCryptoCredentialBackend`). The difference between the two
/// payloads is worth keeping in mind: the derivation is not a credential and
/// cannot be replayed anywhere, while **this one is the real thing** — whoever
/// holds it can talk to Odoo as this user until it expires. That is exactly why
/// the route issues it with `scope: rpc` and a one-day expiry, and why the
/// three rules below are not optional.
///
/// 1. **The expiry is enforced here too, not only by the server.** [load]
///    returns `null` AND erases the record once `expires_at` has passed, so a
///    dead key is never presented and never lingers at rest. Nothing in this
///    class can extend it: there is no "refresh" and that is deliberate (see
///    `W04`). If a day turns out to be too short for the owner, the duration is
///    raised in Odoo — `api_key_duration` on the user's groups — with the
///    reason written down, never by softening this.
/// 2. **Cleared when the session ends.** The web auth service's `close()` is
///    the hook, which `AuthNotifier.close()` already calls, and that is the one
///    path behind both "Cerrar sesión" and "Cambiar de usuario".
/// 3. **Cleared when the server refuses it.** A rejected key is not a typo —
///    unlike a password, there is nobody mistyping it — so 401/403 against a
///    stored key means revoked or dead, and it must go.
final class WebCredentialStore {
  const WebCredentialStore(this._backend);

  final CredentialBackend? _backend;

  static const _key = 'orbi/auth/web/credential/v1';

  /// `false` where there is nowhere durable to keep it. The caller must then
  /// keep the key in memory only, and the session dies with the tab.
  bool get isSupported => _backend != null;

  /// Stores [credential]. Returns whether it was actually persisted; never
  /// throws, so a storage refusal degrades to "this session will not survive a
  /// reload" instead of breaking the login that just succeeded.
  ///
  /// An already-expired credential is refused outright: storing one would only
  /// create a record whose single purpose is to be deleted on next read.
  Future<bool> save(WebAuthCredential credential, {DateTime? now}) async {
    final backend = _backend;
    if (backend == null) return false;
    if (credential.isExpiredAt(now ?? DateTime.now())) return false;
    try {
      await backend.write(_key, credential.encode());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The stored credential, or `null` when there is none, it cannot be read, or
  /// **it has expired** — in which case it is erased on the way out.
  ///
  /// Pass [expectedDatabase] when the caller knows which database this host
  /// serves: a credential for another database is not usable here and is
  /// dropped rather than offered, which is the same refusal the route itself
  /// makes for a mismatching `db`.
  Future<WebAuthCredential?> load({
    DateTime? now,
    String? expectedDatabase,
  }) async {
    final backend = _backend;
    if (backend == null) return null;
    final String? raw;
    try {
      raw = await backend.read(_key);
    } catch (_) {
      return null;
    }
    if (raw == null) return null;
    final WebAuthCredential credential;
    try {
      credential = WebAuthCredential.decode(raw);
    } catch (_) {
      await clear();
      return null;
    }
    if (credential.isExpiredAt(now ?? DateTime.now())) {
      await clear();
      return null;
    }
    if (expectedDatabase != null && credential.database != expectedDatabase) {
      await clear();
      return null;
    }
    return credential;
  }

  /// Erases it. Never throws: a logout must finish even if the store is
  /// unhappy, and a credential we failed to delete is reported by [load]
  /// returning it again rather than by an exception nobody handles.
  Future<void> clear() async {
    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.delete(_key);
    } catch (_) {
      // Nothing else to try; the expiry still bounds the damage.
    }
  }
}

/// Shares the platform-backed secure store with the unlock derivation.
///
/// The provider it reads is still called `workspaceUnlockBackendProvider`
/// because that was its first user; it is the application's single
/// platform-backed secure store and a rename is a cheap follow-up, not a
/// behaviour change. Being inert by default matters here for the same reason
/// it does there: a plugin-backed platform channel never completes inside a
/// widget test's fake-async zone.
final webCredentialStoreProvider = Provider<WebCredentialStore>(
  (ref) => WebCredentialStore(ref.watch(workspaceUnlockBackendProvider)),
);
