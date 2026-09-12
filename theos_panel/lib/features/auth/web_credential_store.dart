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

/// Records WHEN the stored API key dies — and nothing else.
///
/// 🔴 **It deliberately does not keep the key.** The key is already persisted
/// by `NativeAuthService` under its own scoped reference (`'api-key'`), riding
/// the very same platform backend. An earlier version of this class kept a
/// second copy, which is not "belt and braces": **two live copies of one
/// credential is strictly worse than one**, because every copy is another
/// place to leak from and another place a logout has to remember to erase.
///
/// What `NativeAuthService` does NOT track is the expiry, and that is the gap
/// worth filling. `POST /orbi/auth/token` issues a key that dies in a day
/// (`WEB_AUTH.md`); without this record the client presents a dead key, spends
/// a request, and shows the operator an error we could have avoided knowing.
///
/// Everything here is non-secret: which database, which user, and an instant.
/// Losing it costs one wasted request, never a session.
final class WebCredentialExpiry {
  const WebCredentialExpiry({
    required this.database,
    required this.uid,
    required this.expiresAt,
  });

  /// Takes only the three non-secret fields; the key is pointedly left behind.
  factory WebCredentialExpiry.of(WebAuthCredential credential) =>
      WebCredentialExpiry(
        database: credential.database,
        uid: credential.uid,
        expiresAt: credential.expiresAt,
      );

  factory WebCredentialExpiry.decode(String raw) {
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (error) {
      throw FormatException('registro de caducidad ilegible: $error');
    }
    if (decoded is! Map<String, dynamic> || decoded['version'] != 1) {
      throw const FormatException('registro de caducidad desconocido');
    }
    return WebCredentialExpiry(
      database: decoded['database'] as String,
      uid: decoded['uid'] as int,
      expiresAt: DateTime.parse(decoded['expires_at'] as String).toUtc(),
    );
  }

  final String database;
  final int uid;

  /// Always UTC. See [WebAuthCredential.parseServerExpiry].
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
    'expires_at': expiresAt.toUtc().toIso8601String(),
  });
}

/// Knows when the web session's stored API key dies, so a dead one is never
/// presented. See [WebCredentialExpiry] for why it holds no key.
///
/// Three rules, and none of them is optional:
///
/// 1. **The expiry is honoured here too, not only by the server.** [load]
///    returns `null` AND erases the record once it has passed. Nothing here can
///    extend it: there is no "refresh" and that is deliberate (`W04`). If a day
///    is too short, the duration is raised in Odoo — `api_key_duration` on the
///    user's groups — with the reason written down, never by softening this.
/// 2. **Cleared when the session ends**, through the web auth service's
///    `close()`, which `AuthNotifier.close()` already calls — the one path
///    behind both "Cerrar sesión" and "Cambiar de usuario".
/// 3. **Cleared when the server refuses the key.** A rejected key is not a
///    typo: nobody types a key.
final class WebCredentialStore {
  const WebCredentialStore(this._backend);

  final CredentialBackend? _backend;

  static const _key = 'orbi/auth/web/expiry/v1';

  bool get isSupported => _backend != null;

  /// Records when [credential] dies. Never throws, and never writes the key.
  /// An already-dead credential is refused: the record would exist only to be
  /// deleted on the next read.
  Future<bool> remember(WebAuthCredential credential, {DateTime? now}) async {
    final backend = _backend;
    if (backend == null) return false;
    final expiry = WebCredentialExpiry.of(credential);
    if (expiry.isExpiredAt(now ?? DateTime.now())) return false;
    try {
      await backend.write(_key, expiry.encode());
      return true;
    } catch (_) {
      return false;
    }
  }

  /// The record, or `null` when there is none, it cannot be read, or it has
  /// passed — in which case it is erased on the way out.
  ///
  /// [expectedDatabase] drops a record for another database, the same refusal
  /// the route itself makes for a mismatching `db`.
  Future<WebCredentialExpiry?> load({
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
    final WebCredentialExpiry expiry;
    try {
      expiry = WebCredentialExpiry.decode(raw);
    } catch (_) {
      await clear();
      return null;
    }
    if (expiry.isExpiredAt(now ?? DateTime.now())) {
      await clear();
      return null;
    }
    if (expectedDatabase != null && expiry.database != expectedDatabase) {
      await clear();
      return null;
    }
    return expiry;
  }

  /// Never throws: a logout must finish even if the store is unhappy.
  Future<void> clear() async {
    final backend = _backend;
    if (backend == null) return;
    try {
      await backend.delete(_key);
    } catch (_) {
      // Nothing else to try; the server still enforces the real expiry.
    }
  }
}

/// Shares the platform-backed secure store with the unlock derivation.
///
/// The provider it reads is still called `workspaceUnlockBackendProvider`
/// because that was its first user; it is the application's single
/// platform-backed secure store and a rename is a cheap follow-up, not a
/// behaviour change.
final webCredentialStoreProvider = Provider<WebCredentialStore>(
  (ref) => WebCredentialStore(ref.watch(workspaceUnlockBackendProvider)),
);
