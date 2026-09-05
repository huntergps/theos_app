import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:odoo_sdk/odoo_sdk.dart' show logger;

import 'package:odoo_sdk/odoo_sdk.dart'
    show CredentialKeys, SecureCredentialStore;

import '../../../core/security/platform_credential_store.dart';
import '../../../core/security/development_credentials.dart';
import '../../../core/session/session_scope.dart';

part 'server_service.g.dart';

/// One credential backend per provider container.
///
/// On Web this preserves secrets only for the current page lifetime; a refresh
/// still creates a fresh container and intentionally requires login again.
final secureCredentialStoreProvider = Provider<SecureCredentialStore>(
  (ref) => createPlatformCredentialStore(),
);

/// Async preferences dependency, exposed so persistence failures can be
/// reproduced deterministically without touching a platform backend.
final serverPreferencesProvider = Provider<Future<SharedPreferences>>(
  (ref) => SharedPreferences.getInstance(),
);

/// Clock used to enforce the offline credential lifetime.
final serverClockProvider = Provider<DateTime Function()>(
  (ref) => DateTime.now,
);

final class SessionPersistenceException implements Exception {
  const SessionPersistenceException({
    required this.operation,
    required this.cause,
    this.rollbackCauses = const <Object>[],
  });

  final String operation;
  final Object cause;
  final List<Object> rollbackCauses;

  @override
  String toString() =>
      'SessionPersistenceException($operation, rollbackErrors: '
      '${rollbackCauses.length})';
}

class ServerConfig {
  final String name;
  final String url;
  final String database;
  final String? apiKey;
  final int? partnerId;
  final String? imStatusAccessToken;

  ServerConfig({
    required this.name,
    required this.url,
    required this.database,
    this.apiKey,
    this.partnerId,
    this.imStatusAccessToken,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'database': database,
    'partnerId': partnerId,
  };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
    name: json['name'],
    url: json['url'],
    database: json['database'],
    partnerId: json['partnerId'],
  );

  ServerConfig copyWith({
    String? name,
    String? url,
    String? database,
    String? apiKey,
    int? partnerId,
    String? imStatusAccessToken,
  }) {
    return ServerConfig(
      name: name ?? this.name,
      url: url ?? this.url,
      database: database ?? this.database,
      apiKey: apiKey ?? this.apiKey,
      partnerId: partnerId ?? this.partnerId,
      imStatusAccessToken: imStatusAccessToken ?? this.imStatusAccessToken,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is ServerConfig &&
        other.name == name &&
        other.url == url &&
        other.database == database &&
        other.apiKey == apiKey &&
        other.partnerId == partnerId &&
        other.imStatusAccessToken == imStatusAccessToken;
  }

  @override
  int get hashCode =>
      name.hashCode ^
      url.hashCode ^
      database.hashCode ^
      apiKey.hashCode ^
      partnerId.hashCode ^
      imStatusAccessToken.hashCode;
}

/// Stored credential for offline login
class StoredCredential {
  static const maxOfflineAge = Duration(days: 30);

  final String serverUrl;
  final String database;
  final String apiKey;
  final int userId;
  final DateTime lastLoginAt;

  StoredCredential({
    required this.serverUrl,
    required this.database,
    required this.apiKey,
    required this.userId,
    required this.lastLoginAt,
  });

  bool isValidAt(DateTime now) {
    final normalizedNow = now.toUtc();
    final normalizedLogin = lastLoginAt.toUtc();
    if (normalizedLogin.isAfter(normalizedNow)) return false;
    return normalizedNow.difference(normalizedLogin) < maxOfflineAge;
  }
}

final class _StoredCredentialSnapshot {
  const _StoredCredentialSnapshot({
    required this.credentials,
    required this.metadata,
    required this.secretKey,
    required this.secretValue,
  });

  final List<StoredCredential> credentials;
  final String? metadata;
  final String secretKey;
  final String? secretValue;
}

@Riverpod(keepAlive: true)
class ServerService extends _$ServerService {
  static const _key = 'saved_servers';
  static const _currentSessionKey = 'current_session';
  static const _storedCredentialsKey = 'stored_credentials';

  ServerConfig? _currentSession;
  ServerConfig? get currentSession => _currentSession;
  late final Future<void> _serversLoaded;
  late final Future<void> _sessionLoaded;
  late final Future<void> _credentialsLoaded;

  String _sessionCredentialScope(String url, String database) =>
      'session:${url.replaceAll(RegExp(r'[^A-Za-z0-9]'), '_')}:$database';

  /// Stored credentials for offline login (API key -> user ID mapping)
  List<StoredCredential> _storedCredentials = [];

  Future<SharedPreferences> get _preferences =>
      ref.read(serverPreferencesProvider);

  DateTime get _now => ref.read(serverClockProvider)();

  @override
  List<ServerConfig> build() {
    _serversLoaded = _loadServers();
    _sessionLoaded = _loadCurrentSession();
    _credentialsLoaded = _loadStoredCredentials();
    return [];
  }

  Future<void> _loadServers() async {
    final prefs = await _preferences;
    final String? serversJson = prefs.getString(_key);

    if (serversJson != null) {
      final List<dynamic> decoded = jsonDecode(serversJson);
      final servers = decoded.map((e) => ServerConfig.fromJson(e)).map((
        server,
      ) {
        if (server.url == 'https://erp2.tecnosmart.com.ec' &&
            server.apiKey == null &&
            developmentErp2ApiKey.isNotEmpty) {
          return server.copyWith(apiKey: developmentErp2ApiKey);
        }
        return server;
      }).toList();
      if (!servers.any(
        (server) => server.url == 'https://erp2.tecnosmart.com.ec',
      )) {
        servers.add(_defaultErp2Server());
        await _setPreference(
          prefs,
          _key,
          jsonEncode(servers.map((e) => e.toJson()).toList()),
        );
      }
      state = servers;
    } else {
      state = [_defaultErp2Server()];
      await _saveServers();
    }
  }

  ServerConfig _defaultErp2Server() => ServerConfig(
    name: 'Tecnosmart ERP2 (Pruebas)',
    url: 'https://erp2.tecnosmart.com.ec',
    database: 'erp2_tecnosmart_com_ec',
    apiKey: developmentErp2ApiKey.isEmpty ? null : developmentErp2ApiKey,
  );

  Future<void> addServer(ServerConfig server) async {
    // Check if server with same name exists, if so update it
    final index = state.indexWhere((s) => s.name == server.name);
    if (index != -1) {
      final newState = [...state];
      newState[index] = server;
      state = newState;
    } else {
      state = [...state, server];
    }
    await _saveServers();
  }

  Future<void> updateServer(
    ServerConfig oldServer,
    ServerConfig newServer,
  ) async {
    final index = state.indexOf(oldServer);
    if (index != -1) {
      final newState = List<ServerConfig>.from(state);
      newState[index] = newServer;
      state = newState;
      await _saveServers();
    }
  }

  Future<void> saveLastServer(ServerConfig server) async {
    final prefs = await _preferences;
    final previousUrl = prefs.getString('last_server_url');
    final previousDatabase = prefs.getString('last_server_db');
    try {
      await _setPreference(prefs, 'last_server_url', server.url);
      await _setPreference(prefs, 'last_server_db', server.database);
    } catch (error, stackTrace) {
      final rollbackCauses = <Object>[];
      await _restorePreference(
        prefs,
        'last_server_url',
        previousUrl,
        rollbackCauses,
      );
      await _restorePreference(
        prefs,
        'last_server_db',
        previousDatabase,
        rollbackCauses,
      );
      _throwPersistenceFailure(
        operation: 'save last server',
        cause: error,
        stackTrace: stackTrace,
        rollbackCauses: rollbackCauses,
      );
    }
  }

  Future<ServerConfig?> loadLastServer() async {
    // Session metadata and the saved-server catalog are loaded independently.
    // Both must finish before the fallback can safely inspect [state].
    await Future.wait([_sessionLoaded, _serversLoaded]);

    // First, try to use the current session which has the correct API key
    // This is important when the user logs in with a different API key
    // on the same server (same URL and database)
    if (_currentSession != null && _currentSession!.apiKey != null) {
      logger.d(
        '[ServerService] Using current session: ${_currentSession!.url}',
      );
      return _currentSession;
    }

    // Fallback: look for server by URL and database in the saved servers list
    final prefs = await _preferences;
    final url = prefs.getString('last_server_url');
    final db = prefs.getString('last_server_db');

    if (url != null && db != null) {
      try {
        return state.firstWhere((s) => s.url == url && s.database == db);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Load current session from storage
  Future<void> _loadCurrentSession() async {
    final prefs = await _preferences;
    final String? sessionJson = prefs.getString(_currentSessionKey);
    if (sessionJson != null) {
      final metadata = Map<String, dynamic>.from(jsonDecode(sessionJson));
      final config = ServerConfig.fromJson(metadata);
      final secureStore = ref.read(secureCredentialStoreProvider);
      final credentialRef = metadata['credentialRef'] as String?;
      // Session metadata is never sufficient to authenticate. A fresh
      // installation only restores a secret when it carries an explicit
      // reference into the platform credential vault.
      if (credentialRef == null || credentialRef.isEmpty) {
        await _removePreference(prefs, _currentSessionKey);
        return;
      }
      final scope = credentialRef;
      final apiKey = await secureStore.retrieve(
        CredentialKeys.scoped(scope, CredentialKeys.apiKey),
      );
      if (apiKey == null || apiKey.isEmpty) {
        await _removePreference(prefs, _currentSessionKey);
        return;
      }
      final imToken = await secureStore.retrieve(
        CredentialKeys.scoped(scope, CredentialKeys.sessionToken),
      );
      _currentSession = config.copyWith(
        apiKey: apiKey,
        imStatusAccessToken: imToken,
      );
    }
  }

  /// Sets the current Bearer session and its non-cookie metadata.
  Future<void> setCurrentSession(
    ServerConfig config, {
    int? partnerId,
    String? imStatusAccessToken,
  }) async {
    await _sessionLoaded;
    final apiKey = config.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw ArgumentError('An authenticated session requires a credential');
    }

    final nextSession = config.copyWith(
      partnerId: partnerId,
      imStatusAccessToken: imStatusAccessToken,
    );
    final secureStore = ref.read(secureCredentialStoreProvider);
    final scope = _sessionCredentialScope(config.url, config.database);
    final apiKeyStorageKey = CredentialKeys.scoped(
      scope,
      CredentialKeys.apiKey,
    );
    final tokenStorageKey = CredentialKeys.scoped(
      scope,
      CredentialKeys.sessionToken,
    );
    final previousApiKey = await secureStore.retrieve(apiKeyStorageKey);
    final previousToken = await secureStore.retrieve(tokenStorageKey);
    final prefs = await _preferences;
    final previousMetadata = prefs.getString(_currentSessionKey);

    try {
      await secureStore.store(apiKeyStorageKey, apiKey);
      if (imStatusAccessToken != null && imStatusAccessToken.isNotEmpty) {
        await secureStore.store(tokenStorageKey, imStatusAccessToken);
      } else {
        await secureStore.delete(tokenStorageKey);
      }
      await _setPreference(
        prefs,
        _currentSessionKey,
        jsonEncode({...nextSession.toJson(), 'credentialRef': scope}),
      );
      _currentSession = nextSession;
    } catch (error, stackTrace) {
      final rollbackCauses = <Object>[];
      await _restoreSecret(
        secureStore,
        apiKeyStorageKey,
        previousApiKey,
        rollbackCauses,
      );
      await _restoreSecret(
        secureStore,
        tokenStorageKey,
        previousToken,
        rollbackCauses,
      );
      await _restorePreference(
        prefs,
        _currentSessionKey,
        previousMetadata,
        rollbackCauses,
      );
      _throwPersistenceFailure(
        operation: 'commit current session',
        cause: error,
        stackTrace: stackTrace,
        rollbackCauses: rollbackCauses,
      );
    }
  }

  /// Clear current session
  Future<void> clearSession() async {
    await _sessionLoaded;
    final session = _currentSession;
    final prefs = await _preferences;
    final errors = <Object>[];
    for (final key in <String>[
      _currentSessionKey,
      'last_server_url',
      'last_server_db',
    ]) {
      try {
        await _removePreference(prefs, key);
      } catch (error) {
        errors.add(error);
      }
    }
    final secureStore = ref.read(secureCredentialStoreProvider);
    // Remove session secrets for the last known server without ever storing
    // them in preferences.
    if (session != null) {
      final scope = _sessionCredentialScope(session.url, session.database);
      for (final key in CredentialKeys.values) {
        try {
          await secureStore.delete(CredentialKeys.scoped(scope, key));
        } catch (error) {
          errors.add(error);
        }
      }
    }
    _currentSession = null;
    if (errors.isNotEmpty) {
      throw SessionPersistenceException(
        operation: 'clear current session',
        cause: errors.first,
        rollbackCauses: List<Object>.unmodifiable(errors.skip(1)),
      );
    }
  }

  Future<void> removeServer(ServerConfig server) async {
    state = state.where((s) => s != server).toList();
    await _saveServers();
  }

  Future<void> _saveServers() async {
    final prefs = await _preferences;
    final String encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await _setPreference(prefs, _key, encoded);
  }

  // ============================================================================
  // STORED CREDENTIALS FOR OFFLINE LOGIN
  // ============================================================================

  /// Load stored credentials from SharedPreferences
  Future<void> _loadStoredCredentials() async {
    final prefs = await _preferences;
    final String? credentialsJson = prefs.getString(_storedCredentialsKey);
    if (credentialsJson != null) {
      final List<dynamic> decoded = jsonDecode(credentialsJson);
      final secureStore = ref.read(secureCredentialStoreProvider);
      final loaded = <StoredCredential>[];
      var metadataNeedsPruning = false;
      for (final raw in decoded) {
        final metadata = Map<String, dynamic>.from(raw as Map);
        final reference = metadata['credentialRef'] as String?;
        final lastLoginAt = DateTime.parse(metadata['lastLoginAt'] as String);
        final candidate = StoredCredential(
          serverUrl: metadata['serverUrl'] as String,
          database: metadata['database'] as String,
          apiKey: '',
          userId: metadata['userId'] as int,
          lastLoginAt: lastLoginAt,
        );
        if (reference == null ||
            reference.isEmpty ||
            !candidate.isValidAt(_now)) {
          metadataNeedsPruning = true;
          if (reference != null && reference.isNotEmpty) {
            for (final key in CredentialKeys.values) {
              await secureStore.delete(CredentialKeys.scoped(reference, key));
            }
          }
          continue;
        }

        // Session metadata is non-secret. Only an explicit scoped reference
        // into the OS vault can restore its API key.
        final apiKey = await secureStore.retrieve(
          CredentialKeys.scoped(reference, CredentialKeys.apiKey),
        );
        if (apiKey == null || apiKey.isEmpty) {
          metadataNeedsPruning = true;
          continue;
        }
        loaded.add(
          StoredCredential(
            serverUrl: candidate.serverUrl,
            database: candidate.database,
            apiKey: apiKey,
            userId: candidate.userId,
            lastLoginAt: candidate.lastLoginAt,
          ),
        );
      }
      _storedCredentials = loaded;
      if (metadataNeedsPruning) {
        await _saveStoredCredentials(prefs: prefs);
      }
      logger.d(
        '[ServerService] Loaded ${_storedCredentials.length} stored credentials',
      );
    }
  }

  /// Save stored credentials to SharedPreferences
  Future<void> _saveStoredCredentials({SharedPreferences? prefs}) async {
    final storage = prefs ?? await _preferences;
    final String encoded = _encodeStoredCredentials(_storedCredentials);
    await _setPreference(storage, _storedCredentialsKey, encoded);
  }

  /// Store credential for offline login
  /// Called when a user successfully logs in online
  Future<void> storeCredential({
    required String serverUrl,
    required String database,
    required String apiKey,
    required int userId,
  }) async {
    await _credentialsLoaded;
    // Normalize URL
    final normalizedUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;

    final scope = SessionScope(
      serverUrl: normalizedUrl,
      database: database,
      userId: userId,
    );
    final snapshot = await _captureStoredCredentialSnapshot(scope);

    // Check if credential already exists
    final existingIndex = _storedCredentials.indexWhere(
      (c) =>
          c.serverUrl == normalizedUrl &&
          c.database == database &&
          c.userId == userId,
    );

    final newCredential = StoredCredential(
      serverUrl: normalizedUrl,
      database: database,
      apiKey: apiKey,
      userId: userId,
      lastLoginAt: _now,
    );

    final secureStore = ref.read(secureCredentialStoreProvider);
    try {
      await secureStore.store(snapshot.secretKey, apiKey);

      if (existingIndex != -1) {
        // Update existing credential
        _storedCredentials[existingIndex] = newCredential;
      } else {
        // Add new credential
        _storedCredentials.add(newCredential);
      }

      await _saveStoredCredentials();
    } catch (error, stackTrace) {
      final rollbackCauses = await _restoreStoredCredentialSnapshot(snapshot);
      _throwPersistenceFailure(
        operation: 'store offline credential',
        cause: error,
        stackTrace: stackTrace,
        rollbackCauses: rollbackCauses,
      );
    }
    logger.d(
      '[ServerService] Stored credential for user $userId on $normalizedUrl',
    );
  }

  /// Atomically commits the offline credential and the resumable session.
  ///
  /// If the current-session commit fails after the offline credential was
  /// written, the exact previous credential state is restored.
  Future<void> commitAuthenticatedSession({
    required ServerConfig config,
    required int userId,
    int? partnerId,
    String? imStatusAccessToken,
  }) async {
    final apiKey = config.apiKey;
    if (apiKey == null || apiKey.isEmpty) {
      throw ArgumentError('An authenticated session requires a credential');
    }
    await Future.wait([_credentialsLoaded, _sessionLoaded]);
    final scope = SessionScope(
      serverUrl: config.url,
      database: config.database,
      userId: userId,
    );
    final credentialSnapshot = await _captureStoredCredentialSnapshot(scope);
    var offlineCredentialCommitted = false;
    try {
      await storeCredential(
        serverUrl: config.url,
        database: config.database,
        apiKey: apiKey,
        userId: userId,
      );
      offlineCredentialCommitted = true;
      await setCurrentSession(
        config,
        partnerId: partnerId,
        imStatusAccessToken: imStatusAccessToken,
      );
    } catch (error, stackTrace) {
      final rollbackCauses = offlineCredentialCommitted
          ? await _restoreStoredCredentialSnapshot(credentialSnapshot)
          : const <Object>[];
      _throwPersistenceFailure(
        operation: 'commit authenticated session',
        cause: error,
        stackTrace: stackTrace,
        rollbackCauses: rollbackCauses,
      );
    }
  }

  /// Find stored credential by server, database, and API key
  /// Returns the user ID if found, null otherwise
  StoredCredential? findCredential({
    required String serverUrl,
    required String database,
    required String apiKey,
  }) {
    // Normalize URL
    final normalizedUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;

    try {
      return _storedCredentials.firstWhere(
        (c) =>
            c.serverUrl == normalizedUrl &&
            c.database == database &&
            c.apiKey == apiKey &&
            c.isValidAt(_now),
      );
    } catch (_) {
      return null;
    }
  }

  /// Secure-store aware lookup. New authentication flows must await this API
  /// so metadata and the OS credential vault are fully loaded first.
  Future<StoredCredential?> findCredentialAsync({
    required String serverUrl,
    required String database,
    required String apiKey,
  }) async {
    await _credentialsLoaded;
    return findCredential(
      serverUrl: serverUrl,
      database: database,
      apiKey: apiKey,
    );
  }

  /// Removes the remembered offline credential for exactly one user scope.
  ///
  /// This is intentionally narrower than [clearAllCredentials]: logging out or
  /// expiring one profile must not erase unrelated servers/users on the device.
  Future<void> removeStoredCredential({
    required String serverUrl,
    required String database,
    required int userId,
  }) async {
    await _credentialsLoaded;
    final normalizedUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;
    final scope = SessionScope(
      serverUrl: normalizedUrl,
      database: database,
      userId: userId,
    );
    final secureStore = ref.read(secureCredentialStoreProvider);
    for (final key in CredentialKeys.values) {
      await secureStore.delete(
        CredentialKeys.scoped(scope.storageIdentifier, key),
      );
    }
    _storedCredentials.removeWhere(
      (credential) =>
          credential.serverUrl == normalizedUrl &&
          credential.database == database &&
          credential.userId == userId,
    );
    await _saveStoredCredentials();
  }

  /// Get all stored credentials for a server
  List<StoredCredential> getCredentialsForServer(
    String serverUrl,
    String database,
  ) {
    final normalizedUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;

    return _storedCredentials
        .where(
          (c) =>
              c.serverUrl == normalizedUrl &&
              c.database == database &&
              c.isValidAt(_now),
        )
        .toList();
  }

  /// Clear all stored credentials (used during complete logout or data reset)
  Future<void> clearAllCredentials() async {
    await ref.read(secureCredentialStoreProvider).deleteAll();
    _storedCredentials = [];
    await _saveStoredCredentials();
    logger.d('[ServerService] Cleared all stored credentials');
  }

  Future<_StoredCredentialSnapshot> _captureStoredCredentialSnapshot(
    SessionScope scope,
  ) async {
    final prefs = await _preferences;
    final secureStore = ref.read(secureCredentialStoreProvider);
    final secretKey = CredentialKeys.scoped(
      scope.storageIdentifier,
      CredentialKeys.apiKey,
    );
    return _StoredCredentialSnapshot(
      credentials: List<StoredCredential>.of(_storedCredentials),
      metadata: prefs.getString(_storedCredentialsKey),
      secretKey: secretKey,
      secretValue: await secureStore.retrieve(secretKey),
    );
  }

  Future<List<Object>> _restoreStoredCredentialSnapshot(
    _StoredCredentialSnapshot snapshot,
  ) async {
    final rollbackCauses = <Object>[];
    _storedCredentials = List<StoredCredential>.of(snapshot.credentials);
    await _restoreSecret(
      ref.read(secureCredentialStoreProvider),
      snapshot.secretKey,
      snapshot.secretValue,
      rollbackCauses,
    );
    await _restorePreference(
      await _preferences,
      _storedCredentialsKey,
      snapshot.metadata,
      rollbackCauses,
    );
    return List<Object>.unmodifiable(rollbackCauses);
  }

  String _encodeStoredCredentials(List<StoredCredential> credentials) {
    return jsonEncode(
      credentials.map((credential) {
        final scope = SessionScope(
          serverUrl: credential.serverUrl,
          database: credential.database,
          userId: credential.userId,
        );
        return {
          'serverUrl': scope.serverUrl,
          'database': scope.database,
          'userId': credential.userId,
          'lastLoginAt': credential.lastLoginAt.toIso8601String(),
          'credentialRef': scope.storageIdentifier,
        };
      }).toList(),
    );
  }

  Future<void> _setPreference(
    SharedPreferences prefs,
    String key,
    String value,
  ) async {
    if (!await prefs.setString(key, value)) {
      throw StateError('Could not persist $key');
    }
  }

  Future<void> _removePreference(SharedPreferences prefs, String key) async {
    if (!await prefs.remove(key)) {
      throw StateError('Could not remove $key');
    }
  }

  Future<void> _restorePreference(
    SharedPreferences prefs,
    String key,
    String? previousValue,
    List<Object> rollbackCauses,
  ) async {
    try {
      if (previousValue == null) {
        await _removePreference(prefs, key);
      } else {
        await _setPreference(prefs, key, previousValue);
      }
    } catch (error) {
      rollbackCauses.add(error);
    }
  }

  Future<void> _restoreSecret(
    SecureCredentialStore secureStore,
    String key,
    String? previousValue,
    List<Object> rollbackCauses,
  ) async {
    try {
      if (previousValue == null) {
        await secureStore.delete(key);
      } else {
        await secureStore.store(key, previousValue);
      }
    } catch (error) {
      rollbackCauses.add(error);
    }
  }

  Never _throwPersistenceFailure({
    required String operation,
    required Object cause,
    required StackTrace stackTrace,
    required List<Object> rollbackCauses,
  }) {
    Error.throwWithStackTrace(
      SessionPersistenceException(
        operation: operation,
        cause: cause,
        rollbackCauses: List<Object>.unmodifiable(rollbackCauses),
      ),
      stackTrace,
    );
  }
}
