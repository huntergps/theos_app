import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:odoo_sdk/odoo_sdk.dart' hide ServerConfig;
import '../database/database_helper.dart';
import 'platform/device_service.dart';
import 'platform/server_database_service.dart' show AppServerDatabaseService;
import '../../features/authentication/services/server_service.dart';
import 'auth_event_service.dart';

bool _isLocalAddress(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  final host = uri.host.toLowerCase();
  return host == 'localhost' || host == '127.0.0.1' || host == '::1';
}

/// Result of app initialization
class AppInitializationResult {
  final OdooClient odooClient;
  final DatabaseHelper databaseHelper;

  const AppInitializationResult({
    required this.odooClient,
    required this.databaseHelper,
  });
}

/// Service responsible for initializing core app dependencies
///
/// This replaces the deprecated OdooRepository.initialize() method.
/// Creates and configures:
/// - OdooClient for API communication
/// - DatabaseHelper for local storage (server-specific)
class AppInitializer {
  static const _lastApiKeyKey = 'last_used_api_key';
  static AppInitializationResult? _lastResult;

  /// Initialize core app dependencies
  ///
  /// Creates OdooClient and DatabaseHelper for the given server configuration.
  /// Handles API key change detection to clear stale data.
  static Future<AppInitializationResult> initialize({
    required String baseUrl,
    required String apiKey,
    String? database,
    bool forceReinitialize = false,
    AuthEventService? authEventService,
  }) async {
    logger.i('[AppInitializer]', '🏁 START initialize() - baseUrl: $baseUrl, db: $database');

    // Check if API key changed and we need to clear old data
    logger.d('[AppInitializer] 🔑 Step 1: Checking API key changes...');
    await _handleApiKeyChange(
      baseUrl: baseUrl,
      apiKey: apiKey,
      database: database,
      forceReinitialize: forceReinitialize,
    );
    logger.d('[AppInitializer] ✅ API key check complete');

    // Create OdooClient
    logger.d('[AppInitializer] 🌐 Step 2: Creating OdooClient...');
    final allowInsecure = kDebugMode ||
        _isLocalAddress(baseUrl);
    final odooClient = OdooClient(
      config: OdooClientConfig(
        baseUrl: baseUrl,
        apiKey: apiKey,
        database: database,
        allowInsecure: allowInsecure,
        isWeb: kIsWeb,
        tokenRefreshHandler: authEventService != null
            ? SessionExpiredHandler(authEventService)
            : null,
      ),
    );
    logger.d('[AppInitializer] ✅ OdooClient created');

    // Generate server-specific database name for multi-server support
    logger.d('[AppInitializer] 📝 Step 3: Generating database name...');
    final serverConfig = ServerConfig(
      name: 'Current Server',
      url: baseUrl,
      database: database ?? 'default',
    );
    final deviceService = createDeviceService();
    final serverDbService = AppServerDatabaseService(deviceService);
    final dbName = serverDbService.generateDatabaseName(serverConfig);
    logger.d('[AppInitializer] ✅ Database name generated: $dbName');

    // Initialize DatabaseHelper
    logger.i('[AppInitializer]', '🗄️  Step 4: Initializing DatabaseHelper...');
    logger.d('[AppInitializer] Database: $dbName (server: $baseUrl, db: $database)');
    final databaseHelper = await DatabaseHelper.initializeForServer(dbName);
    logger.d('[AppInitializer] ✅ DatabaseHelper initialized: $dbName');

    // For web platform: Establish session cookies for WebSocket authentication
    if (kIsWeb) {
      logger.d(
        '[AppInitializer] 🌐 Web platform, establishing session cookies...',
      );
      await odooClient.createWebSession();
    } else {
      logger.d(
        '[AppInitializer] 📱 Desktop/Mobile platform, skipping web session',
      );
    }

    _lastResult = AppInitializationResult(
      odooClient: odooClient,
      databaseHelper: databaseHelper,
    );

    logger.i('[AppInitializer]', '✅ App initialization complete');
    return _lastResult!;
  }

  /// Handle API key change detection and clear stale data if needed
  static Future<void> _handleApiKeyChange({
    required String baseUrl,
    required String apiKey,
    String? database,
    required bool forceReinitialize,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final lastApiKey = prefs.getString(_lastApiKeyKey);

    // If we have a previous result and API key changed, clear data
    if (_lastResult != null && !forceReinitialize) {
      final currentApiKey = _lastResult!.odooClient.apiKey;
      if (currentApiKey != apiKey) {
        logger.d('[AppInitializer] API key changed, clearing old data...');
        await _lastResult!.databaseHelper.clearAll();
        _lastResult = null;
      }
    }

    // Check if API key changed since last app startup (handles cold restart)
    if (_lastResult == null && !forceReinitialize) {
      if (lastApiKey != null && lastApiKey != apiKey) {
        logger.d(
          '[AppInitializer] 🔄 API key changed since last startup, clearing old data...',
        );
        // Generate server-specific database name
        final serverConfig = ServerConfig(
          name: 'Temp Server',
          url: baseUrl,
          database: database ?? 'default',
        );
        final deviceService = createDeviceService();
        final serverDbService = AppServerDatabaseService(deviceService);
        final dbName = serverDbService.generateDatabaseName(serverConfig);

        // Initialize db temporarily just to clear it
        final tempDb = await DatabaseHelper.initializeForServer(dbName);
        await tempDb.clearAll();
        await tempDb.close();

        // Reset DatabaseHelper for fresh initialization
        DatabaseHelper.resetInstance();
      }
    }

    // Save current API key
    await prefs.setString(_lastApiKeyKey, apiKey);
  }

  /// Clear all local data (for logout/server switch)
  static Future<void> clearAllData() async {
    if (_lastResult != null) {
      logger.d('[AppInitializer] Clearing all local data...');
      await _lastResult!.databaseHelper.clearAll();
    }
  }

  /// Reset initialization state
  static void reset() {
    _lastResult = null;
    DatabaseHelper.resetInstance();
    logger.d('[AppInitializer] Reset complete');
  }
}
