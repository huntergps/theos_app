// The constructor selects adapter implementations, so private dependencies
// cannot use public initializing formals.
// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show CapabilitySnapshot;

import '../contracts.dart';
import '../session/session_runtime.dart';
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
    this.allowedCompanyIds = const [],
  });

  final String serverUrl;
  final String database;
  final String login;
  final int userId;
  final String installationId;
  final String credentialReference;
  final int? companyId;

  /// `res.company.name`, read alongside [companyId] (same `res.users` row on
  /// native, the same `/orbi/bootstrap` payload on web — see
  /// `OdooActiveIdentityReader.read` and `bootstrap.dart`'s web restore).
  /// `null` only when it was never fetched (offline-restored profile from
  /// before this field existed, or a reader that could not resolve it); the
  /// UI falls back to a placeholder itself, this class never invents one.
  final String? companyName;
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
    if (allowedCompanyIds.isNotEmpty) 'allowedCompanyIds': allowedCompanyIds,
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
    allowedCompanyIds:
        (json['allowedCompanyIds'] as List?)
            ?.whereType<num>()
            .map((id) => id.toInt())
            .where((id) => id > 0)
            .toList(growable: false) ??
        const [],
  );
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
  Future<({int companyId, String? companyName, List<int> allowedCompanyIds})>
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
          allowedCompanyIds: identity.allowedCompanyIds,
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
      allowedCompanyIds: identity.allowedCompanyIds,
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
          allowedCompanyIds: identity.allowedCompanyIds,
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
        await _credentialStore.delete(scope, profile.credentialReference);
      }
    } finally {
      await _sessionRuntime.close();
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
