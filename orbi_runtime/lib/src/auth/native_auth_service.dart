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
    this.allowedCompanyIds = const [],
  });

  final String serverUrl;
  final String database;
  final String login;
  final int userId;
  final String installationId;
  final String credentialReference;
  final int? companyId;
  final List<int> allowedCompanyIds;

  Map<String, Object> toJson() => {
    'serverUrl': serverUrl,
    'database': database,
    'login': login,
    'userId': userId,
    'installationId': installationId,
    'credentialReference': credentialReference,
    'companyId': ?companyId,
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
  Future<({int companyId, List<int> allowedCompanyIds})> read(AppScope scope);
}

abstract interface class CapabilitySnapshotPort {
  Future<CapabilitySnapshot?> refresh(AppScope scope, int companyId);
  Future<CapabilitySnapshot?> offline(AppScope scope, int companyId);
}

abstract interface class AuthBootstrapPort {
  Future<NativeAuthBootstrapResult> authenticateAndCreateApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
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
  }) : _bootstrap = bootstrapPort ?? NativeAuthBootstrapAdapter(bootstrap),
       _credentialStore = credentialStore,
       _preferences = preferences,
       _sessionRuntime =
           runtimePort ??
           (sessionRuntime == null
               ? _MissingRuntime()
               : SessionRuntimeAdapter(sessionRuntime)),
       _installationIds = installationIds;

  final AuthBootstrapPort _bootstrap;
  final CredentialStore _credentialStore;
  final SharedPreferences _preferences;
  final SessionRuntimePort _sessionRuntime;
  final InstallationIdStore _installationIds;
  final String appId;
  final ActiveIdentityReader? identityReader;
  final CapabilitySnapshotPort? capabilityPort;

  Future<AuthServiceResult> login({
    required String serverUrl,
    required String database,
    required String login,
    required String password,
  }) async {
    final previousProfile = await loadProfile();
    int? authenticatedUserId;
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
      scope = AppScope(
        appId: appId,
        installationId: installationId,
        normalizedServerUrl: serverUrl,
        database: database,
        userId: result.userId,
      );
      const reference = 'api-key';
      previousSecret = await _credentialStore.read(scope, reference);
      await _credentialStore.write(scope, reference, result.apiKey);
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
          allowedCompanyIds: identity.allowedCompanyIds,
        );
        await _saveProfile(effectiveProfile);
        capabilities = await capabilityPort?.refresh(scope, identity.companyId);
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

  Future<void> close() => _sessionRuntime.close();

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
