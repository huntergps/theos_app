import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/logger_service.dart';

part 'server_service.g.dart';

class ServerConfig {
  final String name;
  final String url;
  final String database;
  final String? apiKey;
  final String? sessionId;
  final int? partnerId;
  final String? imStatusAccessToken;

  ServerConfig({
    required this.name,
    required this.url,
    required this.database,
    this.apiKey,
    this.sessionId,
    this.partnerId,
    this.imStatusAccessToken,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'url': url,
    'database': database,
    'apiKey': apiKey,
    'sessionId': sessionId,
    'partnerId': partnerId,
    'imStatusAccessToken': imStatusAccessToken,
  };

  factory ServerConfig.fromJson(Map<String, dynamic> json) => ServerConfig(
    name: json['name'],
    url: json['url'],
    database: json['database'],
    apiKey: json['apiKey'],
    sessionId: json['sessionId'],
    partnerId: json['partnerId'],
    imStatusAccessToken: json['imStatusAccessToken'],
  );

  ServerConfig copyWith({
    String? name,
    String? url,
    String? database,
    String? apiKey,
    String? sessionId,
    int? partnerId,
    String? imStatusAccessToken,
  }) {
    return ServerConfig(
      name: name ?? this.name,
      url: url ?? this.url,
      database: database ?? this.database,
      apiKey: apiKey ?? this.apiKey,
      sessionId: sessionId ?? this.sessionId,
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
        other.sessionId == sessionId &&
        other.partnerId == partnerId &&
        other.imStatusAccessToken == imStatusAccessToken;
  }

  @override
  int get hashCode =>
      name.hashCode ^
      url.hashCode ^
      database.hashCode ^
      apiKey.hashCode ^
      sessionId.hashCode ^
      partnerId.hashCode ^
      imStatusAccessToken.hashCode;
}

/// Stored credential for offline login
class StoredCredential {
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

  Map<String, dynamic> toJson() => {
    'serverUrl': serverUrl,
    'database': database,
    'apiKey': apiKey,
    'userId': userId,
    'lastLoginAt': lastLoginAt.toIso8601String(),
  };

  factory StoredCredential.fromJson(Map<String, dynamic> json) => StoredCredential(
    serverUrl: json['serverUrl'],
    database: json['database'],
    apiKey: json['apiKey'],
    userId: json['userId'],
    lastLoginAt: DateTime.parse(json['lastLoginAt']),
  );

  /// Generate unique key for this credential
  String get key => '${serverUrl}_${database}_$apiKey';
}

@Riverpod(keepAlive: true)
class ServerService extends _$ServerService {
  static const _key = 'saved_servers';
  static const _currentSessionKey = 'current_session';
  static const _storedCredentialsKey = 'stored_credentials';

  ServerConfig? _currentSession;
  ServerConfig? get currentSession => _currentSession;
  late final Future<void> _sessionLoaded;

  /// Stored credentials for offline login (API key -> user ID mapping)
  List<StoredCredential> _storedCredentials = [];

  @override
  List<ServerConfig> build() {
    _loadServers();
    _sessionLoaded = _loadCurrentSession();
    _loadStoredCredentials();
    return [];
  }

  Future<void> _loadServers() async {
    final prefs = await SharedPreferences.getInstance();
    final String? serversJson = prefs.getString(_key);

    if (serversJson != null) {
      final List<dynamic> decoded = jsonDecode(serversJson);
      state = decoded.map((e) => ServerConfig.fromJson(e)).toList();
    } else {
      // Default servers
      state = [
        ServerConfig(
          name: 'Localhost',
          url: 'http://localhost:8069',
          database: 'erp1_tecnosmart_com_ec',
        ),
        ServerConfig(
          name: 'Tecnosmart',
          url: 'https://erp1.tecnosmart.com.ec',
          database: 'erp1_tecnosmart_com_ec',
        ),
      ];
      _saveServers();
    }
  }

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
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_server_url', server.url);
    await prefs.setString('last_server_db', server.database);
  }

  Future<ServerConfig?> loadLastServer() async {
    // Wait for session to be loaded from storage
    await _sessionLoaded;

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
    final prefs = await SharedPreferences.getInstance();
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
    final prefs = await SharedPreferences.getInstance();
    final String? sessionJson = prefs.getString(_currentSessionKey);
    if (sessionJson != null) {
      try {
        _currentSession = ServerConfig.fromJson(jsonDecode(sessionJson));
      } catch (e) {
        logger.d('[ServerService] Error loading current session: $e');
      }
    }
  }

  /// Set current session with sessionId, partnerId, and imStatusAccessToken
  Future<void> setCurrentSession(
    ServerConfig config,
    String sessionId, {
    int? partnerId,
    String? imStatusAccessToken,
  }) async {
    _currentSession = config.copyWith(
      sessionId: sessionId,
      partnerId: partnerId,
      imStatusAccessToken: imStatusAccessToken,
    );
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      _currentSessionKey,
      jsonEncode(_currentSession!.toJson()),
    );
  }

  /// Clear current session
  Future<void> clearSession() async {
    _currentSession = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_currentSessionKey);
    await prefs.remove('last_server_url');
    await prefs.remove('last_server_db');
  }

  Future<void> removeServer(ServerConfig server) async {
    state = state.where((s) => s != server).toList();
    await _saveServers();
  }

  Future<void> _saveServers() async {
    final prefs = await SharedPreferences.getInstance();
    final String encoded = jsonEncode(state.map((e) => e.toJson()).toList());
    await prefs.setString(_key, encoded);
  }

  // ============================================================================
  // STORED CREDENTIALS FOR OFFLINE LOGIN
  // ============================================================================

  /// Load stored credentials from SharedPreferences
  Future<void> _loadStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? credentialsJson = prefs.getString(_storedCredentialsKey);
      if (credentialsJson != null) {
        final List<dynamic> decoded = jsonDecode(credentialsJson);
        _storedCredentials = decoded
            .map((e) => StoredCredential.fromJson(e as Map<String, dynamic>))
            .toList();
        logger.d('[ServerService] Loaded ${_storedCredentials.length} stored credentials');
      }
    } catch (e) {
      logger.e('[ServerService] Error loading stored credentials: $e');
      _storedCredentials = [];
    }
  }

  /// Save stored credentials to SharedPreferences
  Future<void> _saveStoredCredentials() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String encoded = jsonEncode(
        _storedCredentials.map((e) => e.toJson()).toList(),
      );
      await prefs.setString(_storedCredentialsKey, encoded);
    } catch (e) {
      logger.e('[ServerService] Error saving stored credentials: $e');
    }
  }

  /// Store credential for offline login
  /// Called when a user successfully logs in online
  Future<void> storeCredential({
    required String serverUrl,
    required String database,
    required String apiKey,
    required int userId,
  }) async {
    // Normalize URL
    final normalizedUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;

    // Check if credential already exists
    final existingIndex = _storedCredentials.indexWhere(
      (c) => c.serverUrl == normalizedUrl &&
             c.database == database &&
             c.apiKey == apiKey,
    );

    final newCredential = StoredCredential(
      serverUrl: normalizedUrl,
      database: database,
      apiKey: apiKey,
      userId: userId,
      lastLoginAt: DateTime.now(),
    );

    if (existingIndex != -1) {
      // Update existing credential
      _storedCredentials[existingIndex] = newCredential;
    } else {
      // Add new credential
      _storedCredentials.add(newCredential);
    }

    await _saveStoredCredentials();
    logger.d('[ServerService] Stored credential for user $userId on $normalizedUrl');
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
        (c) => c.serverUrl == normalizedUrl &&
               c.database == database &&
               c.apiKey == apiKey,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get all stored credentials for a server
  List<StoredCredential> getCredentialsForServer(String serverUrl, String database) {
    final normalizedUrl = serverUrl.endsWith('/')
        ? serverUrl.substring(0, serverUrl.length - 1)
        : serverUrl;

    return _storedCredentials
        .where((c) => c.serverUrl == normalizedUrl && c.database == database)
        .toList();
  }

  /// Clear all stored credentials (used during complete logout or data reset)
  Future<void> clearAllCredentials() async {
    _storedCredentials = [];
    await _saveStoredCredentials();
    logger.d('[ServerService] Cleared all stored credentials');
  }
}
