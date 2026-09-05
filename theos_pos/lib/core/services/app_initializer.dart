import 'dart:async';

import 'package:odoo_sdk/odoo_sdk.dart' hide ServerConfig;

import '../database/database_helper.dart';
import '../security/transport_security.dart';
import 'auth_event_service.dart';
import '../session/app_session_scope_driver.dart';
import '../session/session_scope_activation_coordinator.dart';
import '../session/session_scope.dart';
import '../session/session_teardown_coordinator.dart';

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
  static AppInitializationResult? _lastResult;
  static final AppSessionScopeDriver _scopeDriver = AppSessionScopeDriver();
  static final SessionScopeActivationCoordinator _scopeCoordinator =
      SessionScopeActivationCoordinator(driver: _scopeDriver);
  static final SessionTeardownCoordinator _teardownCoordinator =
      SessionTeardownCoordinator();

  static SessionScopeActivationCoordinator get sessionScopeCoordinator =>
      _scopeCoordinator;

  /// Serializes logout, expiry and server-switch cleanup. Callers can safely
  /// invoke this more than once; concurrent callers await the same teardown.
  static Future<void> deactivateSessionScope() =>
      _teardownCoordinator.run(() async {
        _cancelVersionRetry();
        await _scopeCoordinator.deactivate();
        _lastResult = null;
      });

  static Future<bool> hasCommittedSessionScope({
    required String baseUrl,
    required String database,
    required int userId,
  }) => _scopeDriver.isCommitted(
    SessionScope(serverUrl: baseUrl, database: database, userId: userId),
  );

  /// Activates the authenticated scope after the caller has resolved its UID.
  /// This is deliberately separate from [initialize], preserving the public
  /// initializer API for splash/offline callers that may not have a UID yet.
  static Future<SessionScopeActivationResult> activateSessionScope({
    required String baseUrl,
    required String database,
    required int userId,
    bool offline = false,
  }) async {
    _scopeDriver.setOnlineUserId(userId);
    return offline
        ? _scopeCoordinator.activateOffline(
            serverUrl: baseUrl,
            database: database,
          )
        : _scopeCoordinator.activateOnline(
            serverUrl: baseUrl,
            database: database,
          );
  }

  // Reintento en segundo plano de la detección de versión Odoo (19.1 vs
  // 19.2). Si fetchVersion() falla en el arranque (p.ej. app offline), no
  // basta con solo loguear una advertencia: mientras version==unknown, el
  // SDK asume Odoo 19.1 por defecto (ver OdooVersion.unknown), lo que puede
  // enviar campos inválidos si el servidor real es 19.2. Reintentamos
  // periódicamente hasta detectarla o agotar los intentos.
  static Timer? _versionRetryTimer;
  static Future<void>? _versionRetryInFlight;
  static int _versionRetryGeneration = 0;
  static int _versionRetryAttempts = 0;
  static const _versionRetryInterval = Duration(seconds: 30);
  static const _maxVersionRetryAttempts = 10;

  /// Initialize core app dependencies
  ///
  /// Creates OdooClient and DatabaseHelper for the given server configuration.
  /// Handles API key change detection to clear stale data.
  static Future<AppInitializationResult> initialize({
    required String baseUrl,
    required String apiKey,
    String? database,
    AuthEventService? authEventService,
    int? userId,
    bool waitForServerVersion = true,
  }) async {
    logger.i(
      '[AppInitializer]',
      '🏁 START initialize() - baseUrl: $baseUrl, db: $database',
    );

    // This project has never been deployed: every initialization is a clean
    // installation. Credentials are resolved from the platform vault by
    // ServerService; no API key is persisted in preferences and no
    // key-comparison/reset path is needed.
    logger.d('[AppInitializer] 🔐 Clean-install credential policy active');

    // Create OdooClient
    logger.d('[AppInitializer] 🌐 Step 2: Creating OdooClient...');
    final allowInsecure = allowsInsecureLoopbackTransport(baseUrl);
    final odooClient = OdooClient(
      config: OdooClientConfig(
        baseUrl: baseUrl,
        apiKey: apiKey,
        database: database,
        allowInsecure: allowInsecure,
        tokenRefreshHandler: authEventService != null
            ? SessionExpiredHandler(authEventService)
            : null,
      ),
    );
    logger.d('[AppInitializer] ✅ OdooClient created');

    if (waitForServerVersion) {
      await _detectServerVersion(odooClient);
    } else {
      unawaited(_detectServerVersion(odooClient));
    }

    // Resolve identity before opening Drift. Every local database is scoped to
    // the authenticated UID; no server-only database may be opened.
    var scopedUserId = userId;
    if (scopedUserId == null) {
      final context = await odooClient.call(
        model: 'res.users',
        method: 'context_get',
      );
      if (context is Map && context['uid'] is num) {
        scopedUserId = (context['uid'] as num).toInt();
      }
    }
    if (scopedUserId == null || scopedUserId <= 0) {
      throw StateError('Cannot initialize Drift without a positive user UID');
    }
    final scope = SessionScope(
      serverUrl: baseUrl,
      database: database ?? 'default',
      userId: scopedUserId,
    );
    final dbName = scope.driftDatabaseName;
    logger.d('[AppInitializer] ✅ Database name generated: $dbName');

    // Initialize DatabaseHelper
    logger.i('[AppInitializer]', '🗄️  Step 4: Initializing DatabaseHelper...');
    logger.d(
      '[AppInitializer] Database: $dbName (server: $baseUrl, db: $database)',
    );
    final databaseHelper = await DatabaseHelper.initializeForServer(dbName);
    logger.d('[AppInitializer] ✅ DatabaseHelper initialized: $dbName');

    // JSON-2 is bearer-authenticated and does not require a browser cookie
    // session. Never call /web/session/* on Web: those routes belong to
    // Odoo's webclient and are not CORS-enabled.
    logger.d('[AppInitializer] 🔐 JSON-2 bearer session active');

    _lastResult = AppInitializationResult(
      odooClient: odooClient,
      databaseHelper: databaseHelper,
    );

    logger.i('[AppInitializer]', '✅ App initialization complete');
    return _lastResult!;
  }

  static Future<void> _detectServerVersion(OdooClient odooClient) async {
    logger.d('[AppInitializer] 🔍 Detecting Odoo server version...');
    try {
      final version = await odooClient.fetchVersion();
      if (version.isUnknown) {
        logger.w(
          '[AppInitializer]',
          '⚠️ No se pudo detectar la version de Odoo (sin conexion?). '
              'La versión permanece sin confirmar. '
              'Reintentando en segundo plano cada ${_versionRetryInterval.inSeconds}s...',
        );
        _scheduleVersionRetry(odooClient);
      } else {
        logger.i('[AppInitializer]', '✅ Odoo version detected: $version');
      }
    } catch (e) {
      logger.w(
        '[AppInitializer]',
        '⚠️ Could not detect Odoo version: $e. '
            'La versión permanece sin confirmar hasta reintentar.',
      );
      _scheduleVersionRetry(odooClient);
    }
  }

  /// Clear all local data (for logout/server switch)
  static Future<void> clearAllData() async {
    if (_lastResult != null) {
      logger.d('[AppInitializer] Clearing all local data...');
      await _lastResult!.databaseHelper.clearAll();
    }
  }

  /// Programa reintentos periódicos de `fetchVersion()` cuando el arranque
  /// no pudo detectar la version de Odoo (p.ej. app offline). Se cancela
  /// automáticamente al detectar la version o al agotar los intentos.
  static void _scheduleVersionRetry(OdooClient odooClient) {
    _versionRetryTimer?.cancel();
    final generation = ++_versionRetryGeneration;
    _versionRetryAttempts = 0;
    _versionRetryTimer = Timer.periodic(_versionRetryInterval, (timer) {
      if (_versionRetryInFlight != null) {
        logger.d(
          '[AppInitializer]',
          'Omitiendo reintento de version: ya hay una consulta en curso.',
        );
        return;
      }

      late final Future<void> operation;
      operation = _runVersionRetry(odooClient, timer, generation).whenComplete(
        () {
          if (identical(_versionRetryInFlight, operation)) {
            _versionRetryInFlight = null;
          }
        },
      );
      _versionRetryInFlight = operation;
    });
  }

  static Future<void> _runVersionRetry(
    OdooClient odooClient,
    Timer timer,
    int generation,
  ) async {
    if (generation != _versionRetryGeneration) return;

    _versionRetryAttempts++;
    logger.d(
      '[AppInitializer]',
      'Reintentando deteccion de version Odoo (intento $_versionRetryAttempts/$_maxVersionRetryAttempts)...',
    );
    try {
      final version = await odooClient.fetchVersion();
      if (generation != _versionRetryGeneration) return;
      if (!version.isUnknown) {
        logger.i(
          '[AppInitializer]',
          '✅ Odoo version detectada en reintento: $version',
        );
        timer.cancel();
        if (identical(_versionRetryTimer, timer)) {
          _versionRetryTimer = null;
        }
        return;
      }
    } catch (e) {
      if (generation != _versionRetryGeneration) return;
      logger.d(
        '[AppInitializer]',
        'Reintento de deteccion de version fallo: $e',
      );
    }

    if (_versionRetryAttempts >= _maxVersionRetryAttempts) {
      logger.w(
        '[AppInitializer]',
        '⚠️ No se pudo detectar la version de Odoo tras $_maxVersionRetryAttempts '
            'intentos. La versión permanece sin confirmar; '
            'verificar conectividad con el servidor.',
      );
      timer.cancel();
      if (identical(_versionRetryTimer, timer)) {
        _versionRetryTimer = null;
      }
    }
  }

  /// Reset initialization state
  static void reset() {
    _cancelVersionRetry();
    _lastResult = null;
    DatabaseHelper.resetInstance();
    logger.d('[AppInitializer] Reset complete');
  }

  static void _cancelVersionRetry() {
    _versionRetryTimer?.cancel();
    _versionRetryTimer = null;
    _versionRetryGeneration++;
    _versionRetryAttempts = 0;
    _versionRetryInFlight = null;
  }
}
