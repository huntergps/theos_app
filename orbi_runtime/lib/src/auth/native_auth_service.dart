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
    this.lang,
    this.tz,
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

  /// `res.users.lang`/`res.users.tz`, read alongside [companyId] the same
  /// way as [companyName] (see `OdooActiveIdentityReader.read`). `null`
  /// means either a profile saved before these fields existed, or Odoo
  /// answering `false` — this class never invents `es_EC`/
  /// `America/Guayaquil` on its own; the caller ([NativeAuthService]) simply
  /// applies whatever came from the server.
  final String? lang;
  final String? tz;

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
    'lang': ?lang,
    'tz': ?tz,
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
    // Absent for a profile saved before these fields existed — stays null,
    // never defaulted to a hardcoded locale.
    lang: json['lang'] as String?,
    tz: json['tz'] as String?,
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
      String? lang,
      String? tz,
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

  /// Pushes the authenticated user's own `lang`/`tz`
  /// (`res.users.lang`/`res.users.tz`) onto the active session's client, so
  /// every RPC after this point carries them. A no-op when there is no
  /// active client (nothing activated yet, or the current activation is
  /// offline and has none — see `SessionRuntime.activate`). Never invents a
  /// locale of its own: `null`/empty arguments leave the client untouched
  /// (see `OdooClient.updateLocale`).
  void applyUserLocale({String? language, String? timezone});
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

  @override
  void applyUserLocale({String? language, String? timezone}) =>
      runtime.applyUserLocale(language: language, timezone: timezone);
}

final class _MissingRuntime implements SessionRuntimePort {
  @override
  Future<void> activate(AppScope scope, {String? apiKey}) =>
      throw StateError('Session runtime is required');

  @override
  Future<void> close() async {}

  @override
  void applyUserLocale({String? language, String? timezone}) {}
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

  /// La llave de la sesión activa, sólo cuando [close] tiene que revocarla:
  /// vino de una contraseña — por [login], o por [loginWithApiKey] con
  /// `passwordDerived: true`, el camino de la web — Y sin «Guardar clave».
  /// `null` en cualquier otro caso: con «Guardar clave» puesta, o cuando la
  /// llave es del operador ([loginWithApiKey] con `passwordDerived: false`,
  /// su valor por omisión — incluida la que reenvía
  /// [loginWithStoredCredential], que siempre persiste). Se fija al final de
  /// [login] y [loginWithApiKey], se limpia en [close] y [closeExpired].
  ({String baseUrl, String database, String apiKey})?
  _passwordSessionKeyPendingRevoke;

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
          lang: identity.lang,
          tz: identity.tz,
        );
        await _saveProfile(effectiveProfile);
        _sessionRuntime.applyUserLocale(
          language: identity.lang,
          timezone: identity.tz,
        );
        capabilities = await capabilityPort?.refresh(scope, identity.companyId);
      }
      if (!persistCredential) {
        await _credentialStore.delete(scope, reference);
      }
      // Sin «Guardar clave» no queda nada en el almacén para que `close()`
      // lo lea y revoque, así que la única copia que sobrevive hasta el
      // cierre es esta, en memoria — nunca en preferencias ni en disco.
      _passwordSessionKeyPendingRevoke = persistCredential
          ? null
          : (
              baseUrl: scope.normalizedServerUrl,
              database: database,
              apiKey: result.apiKey,
            );
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
  ///
  /// [passwordDerived] distingue de dónde vino la llave, para lo único que
  /// [close] necesita saberlo: si el operador la pegó a mano (`false`, el
  /// valor por omisión — su llave, `close()` nunca la revoca), o si el
  /// servidor la emitió a cambio de una contraseña, como hace la web al
  /// pedirla a `/orbi/auth/token` antes de llamar aquí (`true` — sin
  /// «Guardar clave», es exactamente la misma llave que en escritorio emite
  /// `login()`, y debe correr la misma suerte al cerrar sesión).
  Future<AuthServiceResult> loginWithApiKey({
    required String serverUrl,
    required String database,
    required String login,
    required String apiKey,
    bool persistCredential = true,
    bool passwordDerived = false,
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
      // Sólo una llave que el servidor emitió a cambio de una contraseña
      // (`passwordDerived`) y que además no se pidió guardar deja algo
      // pendiente de revocar en `close()` — una pegada a mano por el
      // operador (incluida la que reenvía `loginWithStoredCredential`,
      // que siempre persiste) nunca lo deja, con o sin «Guardar clave».
      _passwordSessionKeyPendingRevoke = (passwordDerived && !persistCredential)
          ? (
              baseUrl: scope.normalizedServerUrl,
              database: database,
              apiKey: apiKey,
            )
          : null;
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
      lang: identity.lang,
      tz: identity.tz,
    );
    await _saveProfile(enriched);
    _sessionRuntime.applyUserLocale(
      language: identity.lang,
      timezone: identity.tz,
    );
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
    // The bearer credential is otherwise only read to prove the vault
    // reference is available — activating with it here builds the client
    // object (no network call by itself; see `SessionRuntime.activate`) so
    // it is already usable, with the user's own locale applied below, the
    // moment connectivity actually allows a call.
    if (offline) {
      await _sessionRuntime.activate(scope, apiKey: secret);
      // No identity RPC offline: apply whatever locale this profile already
      // had persisted from a previous online login/restore. `null` fields
      // (never fetched, or Odoo answered `false`) are simply not applied —
      // never a hardcoded fallback.
      _sessionRuntime.applyUserLocale(language: profile.lang, timezone: profile.tz);
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
          lang: identity.lang,
          tz: identity.tz,
        );
        await _saveProfile(refreshed);
        _sessionRuntime.applyUserLocale(
          language: identity.lang,
          timezone: identity.tz,
        );
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

  /// 🔴 Revisado el 13-sep-2026 (decisión del dueño, «Recordar la llave tras
  /// salir», documentada en `W04-el-navegador-tambien-guarda.md`): hasta ese
  /// día, `close()` revocaba y borraba SIEMPRE la llave de este dispositivo
  /// cuando quedaba una copia en el almacén — que sólo ocurría con «Guardar
  /// clave» activo, porque sin el interruptor `login()`/`loginWithApiKey()`
  /// ya la borraban del almacén nada más emitirla. Es decir: la revocación
  /// de `close()` sólo se disparaba con «Guardar clave» puesto — justo el
  /// caso que el interruptor promete conservar — y sin el interruptor la
  /// llave NUNCA se revocaba, sólo quedaba huérfana en el servidor hasta
  /// vencer por su cuenta (`orbi.web_auth_key_days`). Ese era el bug real,
  /// anterior a esta decisión, no algo que ella introdujera.
  ///
  /// Ahora `close()` **nunca toca la llave guardada ni el perfil**: si el
  /// operador entró con «Guardar clave», [hasStoredCredential] sigue
  /// devolviendo `true` después de esto, y la pantalla de acceso puede
  /// ofrecer entrar de nuevo sin pedirla. Pero sí revoca, best effort, la
  /// llave EN MEMORIA de una sesión que entró con contraseña y SIN «Guardar
  /// clave» ([_passwordSessionKeyPendingRevoke], la única copia que le queda
  /// a esa sesión, porque el almacén ya la había borrado) — así el
  /// interruptor apagado sigue significando lo mismo que siempre significó:
  /// nada sobrevive al cierre, ni local ni en el servidor. Una llave pegada a
  /// mano (`loginWithApiKey`, incluida la que reenvía
  /// [loginWithStoredCredential]) nunca se revoca aquí: es del operador, no
  /// una que este servicio haya emitido.
  ///
  /// El único camino que borra o revoca una llave GUARDADA (persistida) es
  /// [forgetStoredCredential] («Olvidar la clave guardada», una decisión
  /// explícita del operador) o [closeExpired] (el propio servidor la
  /// rechazó).
  Future<void> close() async {
    final pending = _passwordSessionKeyPendingRevoke;
    _passwordSessionKeyPendingRevoke = null;
    try {
      if (pending != null) {
        try {
          await _bootstrap.revokeOwnApiKey(
            baseUrl: pending.baseUrl,
            database: pending.database,
            apiKey: pending.apiKey,
          );
        } catch (error) {
          // Best-effort, igual que el resto de revocaciones de esta clase:
          // sin red, o sin `base.enable_programmatic_api_keys`, la llave
          // queda huérfana hasta vencer por su cuenta, pero con constancia
          // en el registro. Nunca la llave misma.
          logger.w(
            '[NativeAuthService]',
            'No se pudo revocar al cerrar sesión la llave de una sesión sin '
                '"Guardar clave" (db=${pending.database} '
                'server=${pending.baseUrl}): $error',
          );
        }
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
    // El servidor ya rechazó esta llave: no hay nada que revocar, en el
    // almacén o en memoria — sólo dejar de acordarse de ella.
    _passwordSessionKeyPendingRevoke = null;
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
        lang: profile.lang,
        tz: profile.tz,
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
        lang: profile.lang,
        tz: profile.tz,
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

  /// Además del perfil "último por servidor+base" de siempre, guarda una
  /// copia indexada por servidor+base+**login** (decisión del dueño,
  /// 13-sep-2026: «Recordar la llave tras salir»). Con eso conviven las
  /// llaves de varios usuarios en el mismo equipo — elegir a Carlos en el
  /// desplegable nunca lee ni usa la llave de Erik, aunque los dos hayan
  /// entrado alguna vez al mismo servidor+base desde este dispositivo.
  Future<void> _saveProfile(AuthProfile profile) async {
    final encoded = jsonEncode(profile.toJson());
    await _preferences.setString(
      _profileKeyFor(profile.serverUrl, profile.database),
      encoded,
    );
    await _preferences.setString(
      _profileKeyForLogin(profile.serverUrl, profile.database, profile.login),
      encoded,
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

  /// Igual que [_profileKeyFor] pero además del login, para que dos usuarios
  /// del mismo servidor+base tengan cada uno su propio registro — nunca se
  /// pisan entre sí como sí lo hacía (y lo sigue haciendo, a propósito, para
  /// el precargado "último usuario") la clave de sólo servidor+base.
  String _profileKeyForLogin(String serverUrl, String database, String login) {
    final normalized = AppScope(
      appId: appId,
      installationId: 'profile',
      normalizedServerUrl: serverUrl,
      database: database,
      userId: 1,
    );
    final encoded = base64Url
        .encode(
          utf8.encode(
            '${normalized.normalizedServerUrl}|$database|${login.trim()}',
          ),
        )
        .replaceAll('=', '');
    return 'orbi/auth/profile/$appId/by-login/$encoded';
  }

  /// El perfil guardado para este login EXACTO en este servidor+base, o
  /// `null` si nunca se entró así desde este dispositivo. A diferencia de
  /// [loadProfileFor], no se ve afectado por cuál fue el ÚLTIMO usuario en
  /// entrar — cada login tiene su propio registro.
  Future<AuthProfile?> loadProfileForLogin(
    String serverUrl,
    String database,
    String login,
  ) => loadProfileForKey(_profileKeyForLogin(serverUrl, database, login));

  /// Si el almacén seguro todavía tiene una llave utilizable para [profile].
  /// Nunca lanza: un almacén que no responde se lee como "no hay llave", no
  /// como un error de login.
  Future<bool> hasStoredCredential(AuthProfile profile) async {
    final scope = AppScope(
      appId: appId,
      installationId: profile.installationId,
      normalizedServerUrl: profile.serverUrl,
      database: profile.database,
      userId: profile.userId,
    );
    try {
      final secret = await _credentialStore.read(
        scope,
        profile.credentialReference,
      );
      return secret != null && secret.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Lo que la pantalla de acceso necesita para mostrar «Clave guardada en
  /// este equipo»: el perfil de este login exacto, sólo si además su llave
  /// SIGUE en el almacén (un perfil puede sobrevivir a que su llave se haya
  /// olvidado explícitamente — [forgetStoredCredential] no borra el
  /// perfil, sólo la llave).
  Future<AuthProfile?> findRememberedCredential(
    String serverUrl,
    String database,
    String login,
  ) async {
    final profile = await loadProfileForLogin(serverUrl, database, login);
    if (profile == null) return null;
    return (await hasStoredCredential(profile)) ? profile : null;
  }

  /// Entra con la llave que ya está guardada para [profile], sin pedir
  /// contraseña. Delega en [loginWithApiKey] — mismo camino de activación,
  /// mismo respaldo ante un fallo.
  ///
  /// Decisión del dueño (`W04-el-navegador-tambien-guarda.md`, 13-sep-2026):
  /// un rechazo EXPLÍCITO del servidor (`OdooAuthenticationException`, la
  /// llave venció o fue revocada allá) borra esa llave aquí mismo — antes de
  /// relanzar la excepción, para que ningún llamador tenga que acordarse de
  /// hacerlo por su cuenta — y dejar así de ofrecerla la próxima vez. Sin
  /// conexión, o ante cualquier OTRO error, la llave se conserva intacta:
  /// un fallo de red nunca debe costar la llave guardada.
  ///
  /// `AuthServiceStatus.required` sin lanzar cuando, por una carrera, la
  /// llave desapareció entre que la pantalla la vio y que el operador tocó
  /// «Iniciar sesión» — nunca debería pasar en la práctica (nada más borra la
  /// llave salvo un «Olvidar» explícito), pero no hay nada que intentar.
  Future<AuthServiceResult> loginWithStoredCredential(
    AuthProfile profile,
  ) async {
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
    try {
      return await loginWithApiKey(
        serverUrl: profile.serverUrl,
        database: profile.database,
        login: profile.login,
        apiKey: secret,
        persistCredential: true,
      );
    } on OdooAuthenticationException {
      await _credentialStore.delete(scope, profile.credentialReference);
      rethrow;
    }
  }

  /// «Olvidar la clave guardada»: intenta revocarla en el servidor (best
  /// effort — sin red o sin `base.enable_programmatic_api_keys` simplemente
  /// no revoca nada allá, igual que el resto de revocaciones de esta clase)
  /// y SIEMPRE la borra del almacén local, para que [hasStoredCredential]
  /// vuelva a responder que no hay ninguna. El perfil (servidor/base/login)
  /// no se toca: sigue precargando el campo Usuario la próxima vez.
  Future<void> forgetStoredCredential(AuthProfile profile) async {
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
    if (secret != null && secret.isNotEmpty) {
      try {
        await _bootstrap.revokeOwnApiKey(
          baseUrl: profile.serverUrl,
          database: profile.database,
          apiKey: secret,
        );
      } catch (error) {
        logger.w(
          '[NativeAuthService]',
          'No se pudo revocar la llave olvidada de login=${profile.login} '
              'db=${profile.database} server=${profile.serverUrl}: $error',
        );
      }
    }
    await _credentialStore.delete(scope, profile.credentialReference);
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
