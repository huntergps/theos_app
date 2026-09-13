// The constructor selects adapter implementations, so private dependencies
// cannot use public initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show CapabilitySnapshot;

import '../contracts.dart';
import '../session/session_runtime.dart';
import 'api_key_renewal.dart';
import 'credential_store.dart';

/// Non-secret identity metadata retained for restore and offline start.
final class AuthProfile {
  const AuthProfile({
    required this.serverUrl,
    required this.database,
    required this.login,
    required this.userId,
    required this.installationId,
    required this.credentialReference,
    this.companyId,
    this.companyName,
    this.name,
    this.allowedCompanyIds = const [],
    this.apiKeyIssuedAt,
    this.apiKeyExpiresAt,
  });

  final String serverUrl;
  final String database;
  final String login;
  final int userId;
  final String installationId;
  final String credentialReference;
  final int? companyId;

  /// Cuándo se emitió la clave vigente y cuándo caduca, sólo cuando el
  /// camino de ingreso usado pudo conocerlo (auditoría de sesión,
  /// 13-sep-2026: renovación proactiva). `null`/`null` en un login con API
  /// key pegada a mano, o en cualquier perfil guardado antes de que este
  /// campo existiera — en esos casos simplemente no se evalúa la renovación
  /// proactiva, el respaldo reactivo ante un 401 sigue intacto.
  final DateTime? apiKeyIssuedAt;
  final DateTime? apiKeyExpiresAt;

  /// `res.company.name`, read alongside [companyId] (same `res.users` row on
  /// native, the same `/orbi/bootstrap` payload on web — see
  /// `OdooActiveIdentityReader.read` and `bootstrap.dart`'s web restore).
  /// `null` only when it was never fetched (offline-restored profile from
  /// before this field existed, or a reader that could not resolve it); the
  /// UI falls back to a placeholder itself, this class never invents one.
  final String? companyName;

  /// `res.users.name`, read alongside [companyId] the same way as
  /// [companyName] (see `OdooActiveIdentityReader.read`). `null` only for a
  /// profile saved before this field existed, or when the reader genuinely
  /// could not resolve one — the UI falls back to [login] itself, this class
  /// never invents a name.
  final String? name;
  final List<int> allowedCompanyIds;

  Map<String, Object> toJson() => {
    'serverUrl': serverUrl,
    'database': database,
    'login': login,
    'userId': userId,
    'installationId': installationId,
    'credentialReference': credentialReference,
    'companyId': ?companyId,
    'companyName': ?companyName,
    'name': ?name,
    if (allowedCompanyIds.isNotEmpty) 'allowedCompanyIds': allowedCompanyIds,
    'apiKeyIssuedAt': ?apiKeyIssuedAt?.toIso8601String(),
    'apiKeyExpiresAt': ?apiKeyExpiresAt?.toIso8601String(),
  };

  factory AuthProfile.fromJson(Map<String, dynamic> json) => AuthProfile(
    serverUrl: json['serverUrl'] as String,
    database: json['database'] as String,
    login: json['login'] as String,
    userId: (json['userId'] as num).toInt(),
    installationId: json['installationId'] as String,
    credentialReference: json['credentialReference'] as String,
    companyId: (json['companyId'] as num?)?.toInt(),
    companyName: json['companyName'] as String?,
    name: json['name'] as String?,
    allowedCompanyIds:
        (json['allowedCompanyIds'] as List?)
            ?.whereType<num>()
            .map((id) => id.toInt())
            .where((id) => id > 0)
            .toList(growable: false) ??
        const [],
    apiKeyIssuedAt: _parseUtc(json['apiKeyIssuedAt']),
    apiKeyExpiresAt: _parseUtc(json['apiKeyExpiresAt']),
  );

  static DateTime? _parseUtc(Object? value) {
    if (value is! String || value.isEmpty) return null;
    try {
      return DateTime.parse(value).toUtc();
    } catch (_) {
      return null;
    }
  }
}

enum AuthServiceStatus { authenticated, restored, unsupportedWeb, required }

final class AuthServiceResult {
  const AuthServiceResult({
    required this.status,
    this.scope,
    this.profile,
    this.capabilities,
  });

  final AuthServiceStatus status;
  final AppScope? scope;
  final AuthProfile? profile;
  final CapabilitySnapshot? capabilities;
}

abstract interface class ActiveIdentityReader {
  Future<
    ({
      int companyId,
      String? companyName,
      String? name,
      List<int> allowedCompanyIds,
    })
  >
  read(AppScope scope);
}

abstract interface class CapabilitySnapshotPort {
  Future<CapabilitySnapshot?> refresh(AppScope scope, int companyId);
  Future<CapabilitySnapshot?> offline(AppScope scope, int companyId);
}

typedef ApiKeyIdentityProbe = Future<({int userId, String login})> Function(
  OdooClient client,
);

abstract interface class AuthBootstrapPort {
  Future<NativeAuthBootstrapResult> authenticateAndCreateApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
  });

  /// Best-effort cleanup for a key [authenticateAndCreateApiKey] already
  /// issued when a *later* step (persisting it locally, activating the
  /// session) fails — otherwise that credential is orphaned on the server
  /// forever. Throws [NativeAuthBootstrapRevocationException] on failure;
  /// callers must catch that separately and never let it replace the error
  /// that triggered the cleanup.
  Future<void> revokeApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
    required int apiKeyId,
  });

  /// Best-effort self-revoke for the device's own bearer credential at
  /// logout, when no password is available to re-authenticate.
  ///
  /// [close] never has a password: it is never persisted anywhere (see
  /// [NativeAuthService] class doc), so the session-cookie + `check_identity`
  /// path behind [revokeApiKey] is unreachable from there. Odoo's JSON-2
  /// bearer transport (`save_session=false`) can never satisfy
  /// `check_identity` either, so `res.users.apikeys.remove` — the
  /// password-guarded endpoint — cannot be called with just [apiKey].
  ///
  /// Odoo does expose a second, password-free endpoint for exactly this:
  /// `res.users.apikeys.revoke(key)`, which lets a key authenticate and
  /// revoke *itself* (verified by hash match against the caller's own
  /// key material — never any other user's or any other key's). It is
  /// gated server-side by the `base.enable_programmatic_api_keys` system
  /// parameter (disabled by default) or by the caller being a system user;
  /// when neither holds it fails with a benign "not enabled" error.
  ///
  /// Callers must treat any failure here as informational only — logged,
  /// never surfaced, never blocking the logout it is part of — since there
  /// is no user-facing recovery for it at this point.
  Future<void> revokeOwnApiKey({
    required String baseUrl,
    required String database,
    required String apiKey,
  });

  /// Renovación proactiva (auditoría de sesión, 13-sep-2026): pide una clave
  /// NUEVA autenticándose con la ACTUAL — `res.users.apikeys.generate`, igual
  /// que [revokeOwnApiKey], es un método público que se autentica con la
  /// propia clave, sin el guardián `@check_identity` que sí protege a
  /// `.remove`. Nunca revoca [currentApiKey] por su cuenta: el llamador
  /// decide cuándo hacerlo, después de confirmar que la nueva ya quedó a
  /// salvo.
  ///
  /// Lanza [ApiKeyRenewalUnsupportedException] cuando el servidor contesta
  /// que las claves programáticas están desactivadas — el llamador debe
  /// tratarlo como informativo, nunca como un fallo de sesión.
  Future<ApiKeyRenewalResult> generateApiKey({
    required String baseUrl,
    required String database,
    required String currentApiKey,
    required String name,
    required DateTime expirationDate,
  });
}

final class NativeAuthBootstrapAdapter implements AuthBootstrapPort {
  NativeAuthBootstrapAdapter([NativeOdooAuthBootstrap? bootstrap])
    : _bootstrap = bootstrap ?? NativeOdooAuthBootstrap();
  final NativeOdooAuthBootstrap _bootstrap;

  @override
  Future<NativeAuthBootstrapResult> authenticateAndCreateApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
  }) => _bootstrap.authenticateAndCreateApiKey(
    baseUrl: baseUrl,
    database: database,
    login: login,
    password: password,
  );

  @override
  Future<void> revokeApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
    required int apiKeyId,
  }) => _bootstrap.revokeApiKey(
    baseUrl: baseUrl,
    database: database,
    login: login,
    password: password,
    apiKeyId: apiKeyId,
  );

  @override
  Future<void> revokeOwnApiKey({
    required String baseUrl,
    required String database,
    required String apiKey,
  }) async {
    // Deliberately a plain OdooClient (JSON-2 bearer), not
    // NativeOdooAuthBootstrap: `res.users.apikeys.revoke` is a normal public
    // RPC method (unlike `remove`, it carries no @check_identity guard), so
    // it needs none of the session-cookie machinery that class exists for.
    final client = OdooClient(
      config: OdooClientConfig(
        baseUrl: baseUrl,
        database: database,
        apiKey: apiKey,
      ),
    );
    await client.call(
      model: 'res.users.apikeys',
      method: 'revoke',
      kwargs: {'key': apiKey},
    );
  }

  @override
  Future<ApiKeyRenewalResult> generateApiKey({
    required String baseUrl,
    required String database,
    required String currentApiKey,
    required String name,
    required DateTime expirationDate,
  }) async {
    final client = OdooClient(
      config: OdooClientConfig(
        baseUrl: baseUrl,
        database: database,
        apiKey: currentApiKey,
      ),
    );
    dynamic response;
    try {
      response = await client.call(
        model: 'res.users.apikeys',
        method: 'generate',
        kwargs: {
          'key': currentApiKey,
          'scope': 'rpc',
          'name': name,
          'expiration_date': _formatOdooDatetime(expirationDate),
        },
      );
    } on OdooException catch (error) {
      // El servidor contesta con un mensaje legible cuando
      // `base.enable_programmatic_api_keys` está apagado para este host.
      // Esto NO es un rechazo de sesión: la clave actual sigue intacta y
      // sirviendo con normalidad, así que se traduce a una excepción propia
      // que el llamador debe tratar como puramente informativa.
      if (RegExp(
        r'programmatic',
        caseSensitive: false,
      ).hasMatch(error.message)) {
        throw ApiKeyRenewalUnsupportedException(error.message);
      }
      rethrow;
    }
    return _parseRenewalResponse(response);
  }

  static String _formatOdooDatetime(DateTime value) {
    final utc = value.toUtc();
    String pad(int v, [int width = 2]) => v.toString().padLeft(width, '0');
    return '${utc.year}-${pad(utc.month)}-${pad(utc.day)} '
        '${pad(utc.hour)}:${pad(utc.minute)}:${pad(utc.second)}';
  }

  /// Tolerante a forma: un secreto plano (igual que `make_key`) cuando el
  /// servidor no informa la expiración real, o un mapa con `key`/`api_key` y
  /// `expiration_date`/`expires_at` cuando sí la informa. Nunca se inventa
  /// una fecha aquí — si no viene, [ApiKeyRenewalResult.expiresAt] queda
  /// `null` y es el llamador quien decide cómo estimarla (ver
  /// `NativeAuthService.renewApiKeyIfNeeded`).
  static ApiKeyRenewalResult _parseRenewalResponse(dynamic response) {
    if (response is String && response.isNotEmpty) {
      return ApiKeyRenewalResult(apiKey: response);
    }
    if (response is Map) {
      final key = response['key'] ?? response['api_key'];
      if (key is String && key.isNotEmpty) {
        final rawExpiry = response['expiration_date'] ?? response['expires_at'];
        DateTime? expiresAt;
        if (rawExpiry is String && rawExpiry.isNotEmpty) {
          try {
            expiresAt = DateTime.parse(rawExpiry.replaceFirst(' ', 'T')).toUtc();
          } catch (_) {
            expiresAt = null;
          }
        }
        return ApiKeyRenewalResult(apiKey: key, expiresAt: expiresAt);
      }
    }
    throw StateError('res.users.apikeys.generate no devolvió una clave utilizable');
  }
}

abstract interface class SessionRuntimePort {
  Future<void> activate(AppScope scope, {String? apiKey});
  Future<void> close();
}

final class SessionRuntimeAdapter implements SessionRuntimePort {
  SessionRuntimeAdapter(this.runtime);
  final SessionRuntime runtime;

  @override
  Future<void> activate(AppScope scope, {String? apiKey}) async {
    await runtime.activate(scope, apiKey: apiKey);
  }

  @override
  Future<void> close() => runtime.close();
}

final class _MissingRuntime implements SessionRuntimePort {
  @override
  Future<void> activate(AppScope scope, {String? apiKey}) =>
      throw StateError('Session runtime is required');

  @override
  Future<void> close() async {}
}

/// Coordinates native bootstrap, namespaced credential storage and session
/// activation. Passwords and API keys never enter profile metadata or state.
final class NativeAuthService {
  NativeAuthService({
    NativeOdooAuthBootstrap? bootstrap,
    AuthBootstrapPort? bootstrapPort,
    required CredentialStore credentialStore,
    required SharedPreferences preferences,
    SessionRuntime? sessionRuntime,
    SessionRuntimePort? runtimePort,
    required InstallationIdStore installationIds,
    this.appId = 'theos_panel',
    this.identityReader,
    this.capabilityPort,
    ApiKeyIdentityProbe? apiKeyIdentityProbe,
  }) : _bootstrap = bootstrapPort ?? NativeAuthBootstrapAdapter(bootstrap),
       _credentialStore = credentialStore,
       _preferences = preferences,
       _sessionRuntime =
           runtimePort ??
           (sessionRuntime == null
               ? _MissingRuntime()
               : SessionRuntimeAdapter(sessionRuntime)),
       _installationIds = installationIds,
       _apiKeyIdentityProbe = apiKeyIdentityProbe ?? _probeApiKeyIdentity;

  final AuthBootstrapPort _bootstrap;
  final CredentialStore _credentialStore;
  final SharedPreferences _preferences;
  final SessionRuntimePort _sessionRuntime;
  final InstallationIdStore _installationIds;
  final String appId;
  final ActiveIdentityReader? identityReader;
  final CapabilitySnapshotPort? capabilityPort;
  final ApiKeyIdentityProbe _apiKeyIdentityProbe;

  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
    bool persistCredential = true,
  }) async {
    final previousProfile = await loadProfile();
    int? authenticatedUserId;
    int? issuedApiKeyId;
    String? previousSecret;
    AppScope? scope;
    try {
      final result = await _bootstrap.authenticateAndCreateApiKey(
        baseUrl: serverUrl,
        database: database,
        login: login,
        password: password,
      );
      final installationId = await _installationIds.loadOrCreate(appId);
      authenticatedUserId = result.userId;
      // From this point on the server already holds a real credential. Every
      // failure path below must revoke it instead of just discarding the
      // local copy — see the cleanup at the top of the `catch` block.
      issuedApiKeyId = result.apiKeyId;
      scope = AppScope(
        appId: appId,
        installationId: installationId,
        normalizedServerUrl: serverUrl,
        database: database,
        userId: result.userId,
      );
      const reference = 'api-key';
      previousSecret = await _credentialStore.read(scope, reference);
      if (persistCredential) {
        await _credentialStore.write(scope, reference, result.apiKey);
      }
      final profile = AuthProfile(
        serverUrl: scope.normalizedServerUrl,
        database: database,
        login: login,
        userId: result.userId,
        installationId: installationId,
        credentialReference: reference,
        apiKeyIssuedAt: DateTime.now().toUtc(),
        apiKeyExpiresAt: result.expiresAt,
      );
      await _saveProfile(profile);
      await _sessionRuntime.activate(scope, apiKey: result.apiKey);
      var effectiveProfile = profile;
      CapabilitySnapshot? capabilities;
      if (identityReader != null) {
        final identity = await identityReader!.read(scope);
        effectiveProfile = AuthProfile(
          serverUrl: profile.serverUrl,
          database: profile.database,
          login: profile.login,
          userId: profile.userId,
          installationId: profile.installationId,
          credentialReference: profile.credentialReference,
          companyId: identity.companyId,
          companyName: identity.companyName,
          name: identity.name,
          allowedCompanyIds: identity.allowedCompanyIds,
          apiKeyIssuedAt: profile.apiKeyIssuedAt,
          apiKeyExpiresAt: profile.apiKeyExpiresAt,
        );
        await _saveProfile(effectiveProfile);
        capabilities = await capabilityPort?.refresh(scope, identity.companyId);
      }
      if (!persistCredential) {
        await _credentialStore.delete(scope, reference);
      }
      return AuthServiceResult(
        status: AuthServiceStatus.authenticated,
        scope: scope,
        profile: effectiveProfile,
        capabilities: capabilities,
      );
    } on NativeAuthBootstrapException catch (error) {
      if (error.kind == NativeAuthBootstrapFailureKind.unsupportedPlatform) {
        return const AuthServiceResult(
          status: AuthServiceStatus.unsupportedWeb,
        );
      }
      rethrow;
    } catch (_) {
      // The server already created `issuedApiKeyId` before whatever just
      // failed. Revoking it is independent of every rollback step below —
      // it talks to the server, they only touch local state — and its own
      // failure must never replace the error this whole block is about to
      // rethrow, which is why it gets its own try/catch right here instead
      // of joining the others.
      final apiKeyId = issuedApiKeyId;
      if (apiKeyId != null) {
        try {
          await _bootstrap.revokeApiKey(
            baseUrl: serverUrl,
            database: database,
            login: login,
            password: password,
            apiKeyId: apiKeyId,
          );
        } catch (revokeError) {
          // Typically the same connectivity problem that caused the
          // original failure: revoking over the network fails for the same
          // reason persisting locally just did. The credential stays
          // orphaned on the server — that must not happen silently, so an
          // administrator has something to go on. Never the password or
          // the key itself.
          logger.e(
            '[NativeAuthService]',
            'Failed to revoke orphaned API key id=$apiKeyId for '
                'login=$login db=$database server=$serverUrl: $revokeError',
          );
        }
      }
      // Best-effort rollback prevents a failed activation from leaving a
      // credential/profile that claims to be usable.
      // Keep cleanup operations independent: a close failure must not prevent
      // restoring the previous same-scope credential.
      try {
        await _sessionRuntime.close();
      } catch (_) {}
      try {
        final activeScope = scope;
        if (activeScope != null) {
          if (previousSecret == null) {
            await _credentialStore.delete(activeScope, 'api-key');
          } else {
            await _credentialStore.write(
              activeScope,
              'api-key',
              previousSecret,
            );
          }
        } else {
          final installationId = await _installationIds.loadOrCreate(appId);
          final failedUserId = authenticatedUserId ?? previousProfile?.userId;
          if (failedUserId != null && failedUserId > 0) {
            final failedScope = AppScope(
              appId: appId,
              installationId: installationId,
              normalizedServerUrl: serverUrl,
              database: database,
              userId: failedUserId,
            );
            await _credentialStore.delete(failedScope, 'api-key');
          }
        }
      } catch (_) {}
      if (previousProfile == null) {
        await _preferences.remove(_lastProfileKey);
      } else {
        await _saveProfile(previousProfile);
      }
      rethrow;
    }
  }

  /// Activates a session with an already-issued API key. The key is accepted
  /// only by native clients and is immediately moved into CredentialStore;
  /// it never becomes profile metadata or a widget-owned session token.
  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
    bool persistCredential = true,
  }) async {
    if (serverUrl.trim().isEmpty ||
        database.trim().isEmpty ||
        login.trim().isEmpty ||
        apiKey.isEmpty) {
      throw ArgumentError('server, database, login and apiKey are required');
    }
    final previousProfile = await loadProfile();
    final previousLastProfileKey = _preferences.getString(_lastProfileKey);
    AppScope? scope;
    String? previousSecret;
    bool activated = false;
    try {
      final installationId = await _installationIds.loadOrCreate(appId);
      final probe = OdooClient(
        config: OdooClientConfig(
          baseUrl: serverUrl,
          database: database,
          apiKey: apiKey,
        ),
      );
      final identity = await _apiKeyIdentityProbe(probe);
      if (identity.userId <= 0 || identity.login.trim().isEmpty) {
        throw StateError('API key did not return an authenticated identity');
      }
      if (identity.login.trim() != login.trim()) {
        throw StateError('API key belongs to another Odoo user');
      }
      scope = AppScope(
        appId: appId,
        installationId: installationId,
        normalizedServerUrl: serverUrl,
        database: database,
        userId: identity.userId,
      );
      const reference = 'api-key';
      previousSecret = await _credentialStore.read(scope, reference);
      final profile = AuthProfile(
        serverUrl: scope.normalizedServerUrl,
        database: database,
        login: login.trim(),
        userId: scope.userId,
        installationId: installationId,
        credentialReference: reference,
      );
      if (persistCredential) {
        await _credentialStore.write(scope, reference, apiKey);
      }
      await _saveProfile(profile);
      await _sessionRuntime.activate(scope, apiKey: apiKey);
      activated = true;
      final effectiveProfile = await _enrichProfile(scope, profile);
      if (!persistCredential) {
        await _credentialStore.delete(scope, reference);
      }
      return AuthServiceResult(
        status: AuthServiceStatus.authenticated,
        scope: scope,
        profile: effectiveProfile,
        capabilities: await _capabilitiesFor(scope, effectiveProfile),
      );
    } catch (_) {
      try {
        if (scope != null) {
          if (previousSecret == null) {
            await _credentialStore.delete(scope, 'api-key');
          } else {
            await _credentialStore.write(scope, 'api-key', previousSecret);
          }
        }
        final attemptedKey = _profileKeyFor(serverUrl, database);
        if (previousProfile == null) {
          await _preferences.remove(attemptedKey);
          await _preferences.remove(_lastProfileKey);
        } else {
          final previousProfileKey = _profileKeyFor(
            previousProfile.serverUrl,
            previousProfile.database,
          );
          if (attemptedKey != previousProfileKey) {
            await _preferences.remove(attemptedKey);
          }
          await _saveProfile(previousProfile);
          if (previousLastProfileKey == null) {
            await _preferences.remove(_lastProfileKey);
          } else {
            await _preferences.setString(
              _lastProfileKey,
              previousLastProfileKey,
            );
          }
        }
      } catch (_) {
        // Rollback is best effort; preserve the original authentication error.
      }
      if (activated) {
        try {
          await _sessionRuntime.close();
        } catch (_) {}
      }
      rethrow;
    }
  }

  Future<AuthProfile> _enrichProfile(
    AppScope scope,
    AuthProfile profile,
  ) async {
    if (identityReader == null) return profile;
    final identity = await identityReader!.read(scope);
    final enriched = AuthProfile(
      serverUrl: profile.serverUrl,
      database: profile.database,
      login: profile.login,
      userId: profile.userId,
      installationId: profile.installationId,
      credentialReference: profile.credentialReference,
      companyId: identity.companyId,
      companyName: identity.companyName,
      name: identity.name,
      allowedCompanyIds: identity.allowedCompanyIds,
      apiKeyIssuedAt: profile.apiKeyIssuedAt,
      apiKeyExpiresAt: profile.apiKeyExpiresAt,
    );
    await _saveProfile(enriched);
    return enriched;
  }

  Future<CapabilitySnapshot?> _capabilitiesFor(
    AppScope scope,
    AuthProfile profile,
  ) async {
    final companyId = profile.companyId;
    return companyId == null ? null : capabilityPort?.refresh(scope, companyId);
  }

  Future<AuthServiceResult> restore({bool offline = false}) async {
    final profile = await loadProfile();
    if (profile == null) {
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
    final scope = AppScope(
      appId: appId,
      installationId: profile.installationId,
      normalizedServerUrl: profile.serverUrl,
      database: profile.database,
      userId: profile.userId,
    );
    final secret = await _credentialStore.read(
      scope,
      profile.credentialReference,
    );
    if (secret == null || secret.isEmpty) {
      return const AuthServiceResult(status: AuthServiceStatus.required);
    }
    // The bearer credential is intentionally only read to prove the vault
    // reference is available. Runtime transport composition consumes it later.
    if (offline) {
      await _sessionRuntime.activate(scope);
    } else {
      await _sessionRuntime.activate(scope, apiKey: secret);
      if (identityReader != null) {
        final identity = await identityReader!.read(scope);
        final refreshed = AuthProfile(
          serverUrl: profile.serverUrl,
          database: profile.database,
          login: profile.login,
          userId: profile.userId,
          installationId: profile.installationId,
          credentialReference: profile.credentialReference,
          companyId: identity.companyId,
          companyName: identity.companyName,
          name: identity.name,
          allowedCompanyIds: identity.allowedCompanyIds,
          apiKeyIssuedAt: profile.apiKeyIssuedAt,
          apiKeyExpiresAt: profile.apiKeyExpiresAt,
        );
        await _saveProfile(refreshed);
        return AuthServiceResult(
          status: AuthServiceStatus.restored,
          scope: scope,
          profile: refreshed,
          capabilities: await capabilityPort?.refresh(
            scope,
            identity.companyId,
          ),
        );
      }
    }
    return AuthServiceResult(
      status: AuthServiceStatus.restored,
      scope: scope,
      profile: profile,
      capabilities: offline && profile.companyId != null
          ? await capabilityPort?.offline(scope, profile.companyId!)
          : null,
    );
  }

  Future<void> close() async {
    // Keep non-secret identity metadata so the next actor can reuse the
    // endpoint/database/login, but revoke this device's bearer credential
    // before ending the runtime session. A subsequent restore must therefore
    // require an explicit login again.
    try {
      final profile = await loadProfile();
      if (profile != null) {
        final scope = AppScope(
          appId: appId,
          installationId: profile.installationId,
          normalizedServerUrl: profile.serverUrl,
          database: profile.database,
          userId: profile.userId,
        );
        // Order matters: read and attempt to revoke the secret *before*
        // deleting it locally. Once the local copy is gone there is nothing
        // left to authenticate a revoke with — no password is ever retained
        // (see class doc) — so this is the only point where revocation is
        // still possible at all.
        final secret = await _credentialStore.read(
          scope,
          profile.credentialReference,
        );
        if (secret != null && secret.isNotEmpty) {
          try {
            await _bootstrap.revokeOwnApiKey(
              baseUrl: profile.serverUrl,
              database: profile.database,
              apiKey: secret,
            );
          } catch (error) {
            // Best-effort: offline, the server not opting into
            // `base.enable_programmatic_api_keys`, or any other failure must
            // never block logout, and is never treated as if it succeeded —
            // the key stays orphaned on the server, same as before this
            // call existed, but now with a trace an administrator can act
            // on. Never the key itself.
            logger.w(
              '[NativeAuthService]',
              'Could not revoke this device\'s API key on logout for '
                  'login=${profile.login} db=${profile.database} '
                  'server=${profile.serverUrl}: $error',
            );
          }
        }
        await _credentialStore.delete(scope, profile.credentialReference);
      }
    } finally {
      await _sessionRuntime.close();
    }
  }

  /// Variante de [close] para cuando el SERVIDOR ya rechazó la clave (401 del
  /// sondeo, o de cualquier RPC) — nunca para una decisión del operador.
  /// Diferencias deliberadas con [close]:
  ///
  /// * nunca intenta [AuthBootstrapPort.revokeOwnApiKey]: la clave ya no es
  ///   válida, así que esa llamada sólo repetiría el mismo rechazo sin
  ///   lograr nada;
  /// * borra la copia local de la clave y cierra el runtime exactamente
  ///   igual que [close] — la base local, los borradores y la cola offline
  ///   NUNCA se tocan aquí, igual que nunca los toca [close]: ese borrado es
  ///   cosa de `RuntimeDatabaseOwner`/`SessionRuntime.close()`, que sólo
  ///   cierra la conexión, nunca borra el archivo;
  /// * deja el perfil no-secreto (servidor, base, usuario) intacto en
  ///   preferencias — igual que [close] — para que la pantalla de acceso lo
  ///   precargue sin que el operador tenga que volver a escribirlo.
  Future<void> closeExpired() async {
    try {
      final profile = await loadProfile();
      if (profile != null) {
        final scope = AppScope(
          appId: appId,
          installationId: profile.installationId,
          normalizedServerUrl: profile.serverUrl,
          database: profile.database,
          userId: profile.userId,
        );
        await _credentialStore.delete(scope, profile.credentialReference);
      }
    } finally {
      await _sessionRuntime.close();
    }
  }

  /// Permite a un camino de ingreso que SÍ conoce la vida real de la clave
  /// recién emitida (hoy: el web, que la recibe explícita en la respuesta de
  /// `/orbi/auth/token`) grabarla sobre el perfil que [loginWithApiKey] ya
  /// guardó. Nunca se infiere por su cuenta: sin esta llamada, el perfil
  /// queda con `apiKeyIssuedAt`/`apiKeyExpiresAt` en `null` y
  /// [renewApiKeyIfNeeded] simplemente no tiene nada que evaluar — el
  /// respaldo reactivo ante un 401 sigue intacto igual.
  Future<void> recordApiKeyLifetime({
    required DateTime issuedAt,
    required DateTime expiresAt,
  }) async {
    final profile = await loadProfile();
    if (profile == null) return;
    await _saveProfile(
      AuthProfile(
        serverUrl: profile.serverUrl,
        database: profile.database,
        login: profile.login,
        userId: profile.userId,
        installationId: profile.installationId,
        credentialReference: profile.credentialReference,
        companyId: profile.companyId,
        companyName: profile.companyName,
        name: profile.name,
        allowedCompanyIds: profile.allowedCompanyIds,
        apiKeyIssuedAt: issuedAt.toUtc(),
        apiKeyExpiresAt: expiresAt.toUtc(),
      ),
    );
  }

  /// El ciclo de renovación proactiva (diseño del dueño, 13-sep-2026): con la
  /// app en línea y la clave a menos del 25 % de su vida restante (o menos de
  /// 6 horas, lo que ocurra primero — ver [ApiKeyRenewalDecision]), emite una
  /// clave nueva, la deja a salvo en el mismo almacén cifrado, reactiva el
  /// runtime con ella y SÓLO DESPUÉS intenta revocar la vieja.
  ///
  /// No-op silencioso, sin lanzar nunca, en cualquiera de estos casos:
  /// * no hay perfil o no se conoce `apiKeyIssuedAt`/`apiKeyExpiresAt` (login
  ///   con clave pegada a mano, o un perfil anterior a este mecanismo);
  /// * todavía no toca renovar;
  /// * el servidor contesta que las claves programáticas están desactivadas
  ///   ([ApiKeyRenewalUnsupportedException]) — se registra y se sigue con la
  ///   clave actual hasta que caduque por sí sola;
  /// * cualquier otro fallo de red al intentar `generate` — se reintentará en
  ///   el siguiente ciclo, nunca bloquea la sesión actual.
  ///
  /// Si `revoke` de la clave vieja falla tras un `generate` exitoso, la
  /// sesión sigue funcionando con la clave NUEVA — ya quedó guardada y el
  /// runtime ya fue reactivado con ella antes de intentar revocar.
  Future<void> renewApiKeyIfNeeded({DateTime? now}) async {
    // `generateApiKey` es parte de `AuthBootstrapPort` en sí (ver esa
    // interfaz): cualquier implementación ya lo trae, nunca hace falta un
    // chequeo `is` aparte.
    final bootstrap = _bootstrap;
    final profile = await loadProfile();
    if (profile == null) return;
    final issuedAt = profile.apiKeyIssuedAt;
    final expiresAt = profile.apiKeyExpiresAt;
    if (issuedAt == null || expiresAt == null) return;
    final moment = (now ?? DateTime.now()).toUtc();
    if (!ApiKeyRenewalDecision.shouldRenew(
      issuedAt: issuedAt,
      expiresAt: expiresAt,
      now: moment,
    )) {
      return;
    }
    final scope = AppScope(
      appId: appId,
      installationId: profile.installationId,
      normalizedServerUrl: profile.serverUrl,
      database: profile.database,
      userId: profile.userId,
    );
    final currentKey = await _credentialStore.read(
      scope,
      profile.credentialReference,
    );
    if (currentKey == null || currentKey.isEmpty) return;

    final ApiKeyRenewalResult renewed;
    try {
      renewed = await bootstrap.generateApiKey(
        baseUrl: scope.normalizedServerUrl,
        database: scope.database,
        currentApiKey: currentKey,
        name: 'Orbi ERP renewal',
        // Lo que se PIDE es la misma duración total que tenía la clave
        // actual; lo que de verdad vale es lo que el servidor devuelva —
        // nunca se cablea aquí (ver doc de la clase).
        expirationDate: moment.add(expiresAt.difference(issuedAt)),
      );
    } on ApiKeyRenewalUnsupportedException catch (error) {
      logger.i(
        '[NativeAuthService]',
        'La renovación automática de llave no está habilitada en '
            'db=${scope.database} server=${scope.normalizedServerUrl}: '
            '$error. Se sigue con la llave actual hasta que caduque.',
      );
      return;
    } catch (error) {
      logger.w(
        '[NativeAuthService]',
        'No se pudo renovar la llave API (se reintentará en el próximo '
            'ciclo en línea) para db=${scope.database} '
            'server=${scope.normalizedServerUrl}: $error',
      );
      return;
    }

    // Orden obligatorio: la nueva clave queda a salvo y el runtime ya la usa
    // ANTES de tocar la vieja. Si lo que sigue (revocar la vieja) falla, la
    // sesión ya no depende de ello.
    await _credentialStore.write(scope, profile.credentialReference, renewed.apiKey);
    final newIssuedAt = moment;
    final newExpiresAt = renewed.expiresAt ?? moment.add(expiresAt.difference(issuedAt));
    await _saveProfile(
      AuthProfile(
        serverUrl: profile.serverUrl,
        database: profile.database,
        login: profile.login,
        userId: profile.userId,
        installationId: profile.installationId,
        credentialReference: profile.credentialReference,
        companyId: profile.companyId,
        companyName: profile.companyName,
        name: profile.name,
        allowedCompanyIds: profile.allowedCompanyIds,
        apiKeyIssuedAt: newIssuedAt,
        apiKeyExpiresAt: newExpiresAt,
      ),
    );
    await _sessionRuntime.activate(scope, apiKey: renewed.apiKey);

    try {
      await bootstrap.revokeOwnApiKey(
        baseUrl: scope.normalizedServerUrl,
        database: scope.database,
        apiKey: currentKey,
      );
    } catch (error) {
      // Best-effort: la sesión ya está a salvo con la clave nueva. La vieja
      // queda huérfana en el servidor hasta que caduque por sí misma — nunca
      // se reintenta aquí para no arriesgar la clave que sí funciona.
      logger.w(
        '[NativeAuthService]',
        'No se pudo revocar la llave anterior tras renovar para '
            'db=${scope.database} server=${scope.normalizedServerUrl}: '
            '$error',
      );
    }
  }

  Future<AuthProfile?> loadProfile() async {
    final selectedKey = _preferences.getString(_lastProfileKey);
    if (selectedKey == null) return null;
    return loadProfileForKey(selectedKey);
  }

  Future<AuthProfile?> loadProfileFor(String serverUrl, String database) =>
      loadProfileForKey(_profileKeyFor(serverUrl, database));

  Future<AuthProfile?> loadProfileForKey(String key) async {
    final encoded = _preferences.getString(key);
    if (encoded == null) return null;
    try {
      return AuthProfile.fromJson(jsonDecode(encoded) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  Future<void> _saveProfile(AuthProfile profile) async {
    await _preferences.setString(
      _profileKeyFor(profile.serverUrl, profile.database),
      jsonEncode(profile.toJson()),
    );
    await _preferences.setString(
      _lastProfileKey,
      _profileKeyFor(profile.serverUrl, profile.database),
    );
  }

  String get _lastProfileKey => 'orbi/auth/profile/$appId/last';

  String _profileKeyFor(String serverUrl, String database) {
    final normalized = AppScope(
      appId: appId,
      installationId: 'profile',
      normalizedServerUrl: serverUrl,
      database: database,
      userId: 1,
    );
    final encoded = base64Url
        .encode(utf8.encode('${normalized.normalizedServerUrl}|$database'))
        .replaceAll('=', '');
    return 'orbi/auth/profile/$appId/$encoded';
  }
}

Future<({int userId, String login})> _probeApiKeyIdentity(
  OdooClient client,
) async {
  // JSON-2 derives the current user from the bearer key. `context_get` is the
  // documented, read-only way to obtain that authenticated uid; never infer
  // identity by searching for the login supplied by the UI.
  final rawContext = await client.call(
    model: 'res.users',
    method: 'context_get',
  );
  final userId = rawContext is num
      ? rawContext.toInt()
      : rawContext is Map
      ? ((rawContext['uid'] ?? rawContext['user_id']) as num?)?.toInt()
      : null;
  if (userId == null || userId <= 0) {
    throw StateError('API key did not return an authenticated uid');
  }
  final users = await client.searchRead(
    model: 'res.users',
    fields: const ['id', 'login'],
    domain: [
      ['id', '=', userId],
    ],
    limit: 1,
  );
  if (users.length != 1 || users.single['id'] is! num) {
    throw StateError('Authenticated Odoo user could not be read');
  }
  return (
    userId: (users.single['id'] as num).toInt(),
    login: users.single['login']?.toString() ?? '',
  );
}
