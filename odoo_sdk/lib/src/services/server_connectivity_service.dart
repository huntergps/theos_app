/// Server Connectivity Service (Generic)
///
/// Monitors server health through passive observation and active probing.
/// This is a generic implementation without framework-specific dependencies.
///
/// For app integration, use the callbacks/interfaces to connect with your
/// specific framework (Riverpod, Provider, GetX, etc.)
library;

import 'dart:async';
import '../websocket/odoo_websocket_events.dart';
import 'logger_service.dart';

// ============================================================================
// ENUMS AND MODELS
// ============================================================================

/// Server connection states with detailed granularity
enum ServerConnectionState {
  /// Server responding correctly to requests
  online,

  /// Server responding but slow or with intermittent errors
  degraded,

  /// Cannot reach server (timeout, connection refused, DNS failure)
  unreachable,

  /// Server responding with 502, 503, 504 (maintenance mode)
  maintenance,

  /// Session expired, needs re-authentication (401, 403)
  sessionExpired,

  /// Initial state before any check
  unknown,
}

/// Comprehensive connectivity status combining all layers
class ConnectivityStatus {
  /// Whether device has network connectivity (WiFi/Mobile)
  final bool hasNetwork;

  /// HTTP API health state
  final ServerConnectionState serverState;

  /// WebSocket connection state
  final bool webSocketConnected;

  /// Whether current session is valid
  final bool sessionValid;

  /// Last time server was confirmed online
  final DateTime? lastOnlineAt;

  /// Last time a health check was performed
  final DateTime? lastCheckedAt;

  /// Number of consecutive failures
  final int consecutiveFailures;

  /// Last error message (if any)
  final String? lastError;

  /// HTTP response time in milliseconds (null if unknown)
  final int? latencyMs;

  /// Whether offline mode was manually set by the user
  final bool isManualOffline;

  const ConnectivityStatus({
    this.hasNetwork = true,
    this.serverState = ServerConnectionState.unknown,
    this.webSocketConnected = false,
    this.sessionValid = true,
    this.lastOnlineAt,
    this.lastCheckedAt,
    this.consecutiveFailures = 0,
    this.lastError,
    this.latencyMs,
    this.isManualOffline = false,
  });

  /// Can we attempt remote operations?
  /// True only if we believe the server is reachable and manual offline is not set
  bool get canAttemptRemote =>
      !isManualOffline &&
      hasNetwork &&
      (serverState == ServerConnectionState.online ||
          serverState == ServerConnectionState.degraded ||
          serverState == ServerConnectionState.unknown);

  /// Should we skip remote operations entirely?
  /// True when we know the server is down or manual offline is active
  bool get shouldSkipRemote =>
      isManualOffline ||
      !hasNetwork ||
      serverState == ServerConnectionState.unreachable ||
      serverState == ServerConnectionState.maintenance;

  /// Is the server fully operational?
  bool get isFullyOnline =>
      hasNetwork &&
      serverState == ServerConnectionState.online &&
      sessionValid;

  /// Requires re-authentication?
  bool get needsReauth => serverState == ServerConnectionState.sessionExpired;

  /// Copy with modifications
  ConnectivityStatus copyWith({
    bool? hasNetwork,
    ServerConnectionState? serverState,
    bool? webSocketConnected,
    bool? sessionValid,
    DateTime? lastOnlineAt,
    DateTime? lastCheckedAt,
    int? consecutiveFailures,
    String? lastError,
    int? latencyMs,
    bool? isManualOffline,
  }) {
    return ConnectivityStatus(
      hasNetwork: hasNetwork ?? this.hasNetwork,
      serverState: serverState ?? this.serverState,
      webSocketConnected: webSocketConnected ?? this.webSocketConnected,
      sessionValid: sessionValid ?? this.sessionValid,
      lastOnlineAt: lastOnlineAt ?? this.lastOnlineAt,
      lastCheckedAt: lastCheckedAt ?? this.lastCheckedAt,
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      lastError: lastError,
      latencyMs: latencyMs ?? this.latencyMs,
      isManualOffline: isManualOffline ?? this.isManualOffline,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConnectivityStatus &&
        other.hasNetwork == hasNetwork &&
        other.serverState == serverState &&
        other.webSocketConnected == webSocketConnected &&
        other.sessionValid == sessionValid &&
        other.consecutiveFailures == consecutiveFailures &&
        other.isManualOffline == isManualOffline;
  }

  @override
  int get hashCode => Object.hash(
        hasNetwork,
        serverState,
        webSocketConnected,
        sessionValid,
        consecutiveFailures,
        isManualOffline,
      );

  @override
  String toString() {
    return 'ConnectivityStatus('
        'network: $hasNetwork, '
        'server: ${serverState.name}, '
        'ws: $webSocketConnected, '
        'session: $sessionValid, '
        'failures: $consecutiveFailures, '
        'manualOffline: $isManualOffline'
        ')';
  }
}

// ============================================================================
// DEPENDENCY INTERFACES
// ============================================================================

/// Callback to perform HTTP health check
/// Returns true if server is healthy, throws on error
typedef HealthCheckCallback = Future<void> Function();

/// Callback to get current WebSocket connection state
typedef WebSocketStateCallback = bool Function();

/// Callback to subscribe to WebSocket events
typedef WebSocketEventSubscriber = StreamSubscription<OdooWebSocketEvent>
    Function(void Function(OdooWebSocketEvent));

/// Interface for persisting health state
abstract class HealthStatePersistence {
  Future<void> saveState(ServerConnectionState state, DateTime timestamp,
      DateTime? lastOnline);
  Future<({ServerConnectionState? state, DateTime? timestamp, DateTime? lastOnline})>
      loadState();
}

/// Interface for network connectivity monitoring
abstract class NetworkConnectivityMonitor {
  /// Check current connectivity
  Future<bool> checkConnectivity();

  /// Stream of connectivity changes
  Stream<bool> get connectivityStream;
}

// ============================================================================
// SERVER HEALTH SERVICE (Generic)
// ============================================================================

/// Configuration for ServerHealthService
class ServerHealthConfig {
  /// Interval between normal health checks
  final Duration normalCheckInterval;

  /// Interval between recovery checks (after failures)
  final Duration recoveryCheckInterval;

  /// How long after activity to skip active checks
  final Duration activityThreshold;

  /// Number of failures before switching to recovery mode
  final int failureThreshold;

  /// How old cached state can be before ignoring it
  final Duration maxCacheAge;

  const ServerHealthConfig({
    this.normalCheckInterval = const Duration(seconds: 120),
    this.recoveryCheckInterval = const Duration(seconds: 30),
    this.activityThreshold = const Duration(seconds: 30),
    this.failureThreshold = 3,
    this.maxCacheAge = const Duration(minutes: 5),
  });
}

/// Service that monitors server health through passive observation and active probing.
///
/// This is a framework-agnostic implementation. To use with your app:
///
/// ```dart
/// final service = ServerHealthService(
///   config: ServerHealthConfig(),
///   healthCheck: () => odooClient.call(model: 'res.users', method: 'search_count', kwargs: {'domain': []}),
///   getWebSocketState: () => wsService.isConnected,
///   subscribeToWebSocket: (callback) => wsService.eventStream.listen(callback),
///   persistence: MyHealthStatePersistence(),
///   networkMonitor: MyNetworkMonitor(),
/// );
/// await service.initialize();
/// ```
class ServerHealthService {
  final ServerHealthConfig config;

  /// Callback to perform health check - should throw on failure
  final HealthCheckCallback? _healthCheck;

  /// Callback to get current WebSocket state
  final WebSocketStateCallback? _getWebSocketState;

  /// Callback to subscribe to WebSocket events
  final WebSocketEventSubscriber? _subscribeToWebSocket;

  /// Optional persistence for state
  final HealthStatePersistence? _persistence;

  /// Optional network monitor
  final NetworkConnectivityMonitor? _networkMonitor;

  Timer? _healthCheckTimer;
  Timer? _recoveryCheckTimer;
  DateTime? _lastActivity;
  StreamSubscription<bool>? _connectivitySubscription;
  StreamSubscription<OdooWebSocketEvent>? _wsEventSubscription;

  // Current state
  ConnectivityStatus _status = const ConnectivityStatus();

  // Stream controller for status updates
  final _statusController = StreamController<ConnectivityStatus>.broadcast();

  ServerHealthService({
    this.config = const ServerHealthConfig(),
    HealthCheckCallback? healthCheck,
    WebSocketStateCallback? getWebSocketState,
    WebSocketEventSubscriber? subscribeToWebSocket,
    HealthStatePersistence? persistence,
    NetworkConnectivityMonitor? networkMonitor,
  })  : _healthCheck = healthCheck,
        _getWebSocketState = getWebSocketState,
        _subscribeToWebSocket = subscribeToWebSocket,
        _persistence = persistence,
        _networkMonitor = networkMonitor;

  /// Current connectivity status
  ConnectivityStatus get status => _status;

  /// Stream of status updates
  Stream<ConnectivityStatus> get statusStream => _statusController.stream;

  /// Whether the service is in manual offline mode
  bool get isManualOffline => _status.isManualOffline;

  /// Toggle manual offline mode.
  ///
  /// When enabled, all operations are treated as offline regardless of actual
  /// connectivity. Health check timers are stopped. When disabled, health
  /// checking resumes and an immediate check is triggered.
  void setManualOfflineMode(bool enabled) {
    if (_status.isManualOffline == enabled) return;

    if (enabled) {
      _updateStatus(_status.copyWith(
        serverState: ServerConnectionState.unreachable,
        isManualOffline: true,
      ));
      _healthCheckTimer?.cancel();
      _healthCheckTimer = null;
      _recoveryCheckTimer?.cancel();
      _recoveryCheckTimer = null;
      logger.i('[ServerHealth]', 'Manual offline mode enabled');
    } else {
      _updateStatus(_status.copyWith(isManualOffline: false));
      _startHealthCheckTimer();
      checkHealth();
      logger.i('[ServerHealth]', 'Manual offline mode disabled');
    }
  }

  /// Initialize the service and start monitoring
  Future<void> initialize() async {
    logger.d('[ServerHealth]', 'Initializing server health monitoring');

    // Load persisted state
    await _loadPersistedState();

    // Check initial network state
    await _checkInitialNetworkState();

    // Listen to network connectivity changes
    _listenToNetworkChanges();

    // Listen to WebSocket state changes
    _listenToWebSocket();

    // Start periodic health check
    _startHealthCheckTimer();

    logger.i('[ServerHealth]',
        'Initialized with state: ${_status.serverState.name}');
  }

  /// Check initial network connectivity state
  Future<void> _checkInitialNetworkState() async {
    if (_networkMonitor == null) return;

    try {
      final hasNetwork = await _networkMonitor.checkConnectivity();
      _updateStatus(_status.copyWith(hasNetwork: hasNetwork));
      logger.d('[ServerHealth]',
          'Initial network state: ${hasNetwork ? "connected" : "disconnected"}');
    } catch (e) {
      logger.w('[ServerHealth]', 'Failed to check initial network state: $e');
    }
  }

  /// Listen to network connectivity changes
  void _listenToNetworkChanges() {
    if (_networkMonitor == null) return;

    _connectivitySubscription = _networkMonitor.connectivityStream.listen(
      (hasNetwork) {
        updateNetworkState(hasNetwork);
      },
      onError: (e) {
        logger.w('[ServerHealth]', 'Connectivity stream error: $e');
      },
    );
  }

  /// Record a successful API call (passive detection)
  void recordSuccess({int? latencyMs}) {
    _lastActivity = DateTime.now();

    if (_status.serverState != ServerConnectionState.online) {
      logger.i('[ServerHealth]', 'Server recovered - marking online');
    }

    _updateStatus(_status.copyWith(
      serverState: ServerConnectionState.online,
      lastOnlineAt: DateTime.now(),
      lastCheckedAt: DateTime.now(),
      consecutiveFailures: 0,
      lastError: null,
      latencyMs: latencyMs,
    ));

    // Switch back to normal check interval if we were in recovery mode
    if (_recoveryCheckTimer != null) {
      _recoveryCheckTimer?.cancel();
      _recoveryCheckTimer = null;
      _startHealthCheckTimer();
    }
  }

  /// Record a failed API call (passive detection)
  void recordFailure(Object error, {int? statusCode}) {
    final newState = classifyError(error, statusCode);
    final newFailures = _status.consecutiveFailures + 1;

    final errorStr = error.toString();
    logger.w(
      '[ServerHealth]',
      'API failure #$newFailures: ${errorStr.substring(0, errorStr.length > 100 ? 100 : errorStr.length)}',
    );

    _updateStatus(_status.copyWith(
      serverState: newState,
      lastCheckedAt: DateTime.now(),
      consecutiveFailures: newFailures,
      lastError: errorStr,
    ));

    // Switch to recovery mode (faster checking)
    if (newFailures >= config.failureThreshold && _recoveryCheckTimer == null) {
      _startRecoveryCheckTimer();
    }
  }

  /// Record session expiration
  void recordSessionExpired() {
    logger.w('[ServerHealth]', 'Session expired - needs re-authentication');
    _updateStatus(_status.copyWith(
      serverState: ServerConnectionState.sessionExpired,
      sessionValid: false,
      lastCheckedAt: DateTime.now(),
    ));
  }

  /// Record session restoration
  void recordSessionRestored() {
    logger.i('[ServerHealth]', 'Session restored');
    _updateStatus(_status.copyWith(
      sessionValid: true,
    ));
  }

  /// Update network connectivity state
  void updateNetworkState(bool hasNetwork) {
    if (_status.hasNetwork != hasNetwork) {
      logger.i('[ServerHealth]', 'Network state changed: $hasNetwork');
      _updateStatus(_status.copyWith(hasNetwork: hasNetwork));

      if (hasNetwork &&
          _status.serverState == ServerConnectionState.unreachable) {
        // Network restored - start recovery checks
        _startRecoveryCheckTimer();
      }
    }
  }

  /// Perform an active health check
  Future<bool> checkHealth() async {
    if (_healthCheck == null) {
      logger.d('[ServerHealth]', 'No health check callback - skipping');
      return false;
    }

    // Skip if recent activity AND server is online (passive detection is enough)
    if (_status.serverState == ServerConnectionState.online &&
        _lastActivity != null &&
        DateTime.now().difference(_lastActivity!) < config.activityThreshold) {
      logger.d(
          '[ServerHealth]', 'Recent activity & online - skipping active check');
      return true;
    }

    return _performHealthCheck();
  }

  /// Actually perform the HTTP health check
  Future<bool> _performHealthCheck() async {
    if (_healthCheck == null) return false;

    logger.d('[ServerHealth]', 'Performing HTTP health check...');
    final stopwatch = Stopwatch()..start();

    try {
      await _healthCheck();
      stopwatch.stop();

      recordSuccess(latencyMs: stopwatch.elapsedMilliseconds);
      logger.d('[ServerHealth]',
          'Health check OK (${stopwatch.elapsedMilliseconds}ms)');
      return true;
    } catch (e) {
      stopwatch.stop();
      recordFailure(e);
      logger.w('[ServerHealth]', 'Health check FAILED: $e');
      return false;
    }
  }

  /// Force a health check and wait for result
  Future<ConnectivityStatus> forceCheck() async {
    await _performHealthCheck();
    return _status;
  }

  /// Classify an error into a server state
  static ServerConnectionState classifyError(Object error, int? statusCode) {
    // Check status code first
    if (statusCode != null) {
      if (statusCode == 401 || statusCode == 403) {
        return ServerConnectionState.sessionExpired;
      }
      if (statusCode == 502 || statusCode == 503 || statusCode == 504) {
        return ServerConnectionState.maintenance;
      }
      if (statusCode == 429) {
        return ServerConnectionState.degraded; // Rate limited
      }
    }

    // Check error type
    final errorStr = error.toString().toLowerCase();

    if (errorStr.contains('timeout') ||
        errorStr.contains('timed out') ||
        errorStr.contains('connection refused') ||
        errorStr.contains('socket') ||
        errorStr.contains('host lookup') ||
        errorStr.contains('network is unreachable') ||
        errorStr.contains('no route to host')) {
      return ServerConnectionState.unreachable;
    }

    if (errorStr.contains('401') ||
        errorStr.contains('403') ||
        errorStr.contains('unauthorized') ||
        errorStr.contains('forbidden') ||
        errorStr.contains('session expired') ||
        errorStr.contains('sessionexpired')) {
      return ServerConnectionState.sessionExpired;
    }

    if (errorStr.contains('502') ||
        errorStr.contains('503') ||
        errorStr.contains('504') ||
        errorStr.contains('bad gateway') ||
        errorStr.contains('service unavailable')) {
      return ServerConnectionState.maintenance;
    }

    // Default to degraded for other errors (not fully unreachable)
    return ServerConnectionState.degraded;
  }

  /// Listen to WebSocket connection state using typed event stream
  void _listenToWebSocket() {
    if (_getWebSocketState == null || _subscribeToWebSocket == null) return;

    try {
      // Update initial state
      _updateStatus(_status.copyWith(
        webSocketConnected: _getWebSocketState(),
      ));

      // Subscribe to typed event stream for all WebSocket events
      _wsEventSubscription = _subscribeToWebSocket((event) {
        switch (event) {
          case OdooConnectionEvent():
            logger.d('[ServerHealth]',
                'WebSocket state changed: connected=${event.isConnected}');
            _updateStatus(
                _status.copyWith(webSocketConnected: event.isConnected));

            if (event.isConnected &&
                _status.serverState != ServerConnectionState.online) {
              // WebSocket connected implies server is reachable
              logger.i(
                  '[ServerHealth]', 'WebSocket connected - server likely online');
              checkHealth();
            } else if (!event.isConnected &&
                _status.serverState == ServerConnectionState.online) {
              // WebSocket disconnected while we thought server was online
              logger.w('[ServerHealth]',
                  'WebSocket disconnected - marking as degraded, verifying HTTP');
              _updateStatus(_status.copyWith(
                serverState: ServerConnectionState.degraded,
                consecutiveFailures: _status.consecutiveFailures + 1,
              ));
              _performHealthCheck();
            }

          case OdooErrorEvent():
            logger.w('[ServerHealth]', 'WebSocket error: ${event.error}');
            recordFailure(event.error);

          default:
            // Ignore other event types
            break;
        }
      });
    } catch (e) {
      logger.w('[ServerHealth]', 'WebSocket service not available: $e');
    }
  }

  /// Start the normal health check timer
  void _startHealthCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(config.normalCheckInterval, (_) {
      checkHealth();
    });
  }

  /// Start the recovery check timer (faster interval)
  void _startRecoveryCheckTimer() {
    _healthCheckTimer?.cancel();
    _healthCheckTimer = null;

    _recoveryCheckTimer?.cancel();
    _recoveryCheckTimer = Timer.periodic(config.recoveryCheckInterval, (_) {
      checkHealth();
    });

    logger.i('[ServerHealth]',
        'Switched to recovery mode (${config.recoveryCheckInterval.inSeconds}s interval)');
  }

  /// Update status and notify listeners
  void _updateStatus(ConnectivityStatus newStatus) {
    if (_status != newStatus) {
      _status = newStatus;
      _statusController.add(newStatus);
      _persistState();
    }
  }

  /// Persist state for faster startup
  Future<void> _persistState() async {
    if (_persistence == null) return;

    try {
      await _persistence.saveState(
        _status.serverState,
        DateTime.now(),
        _status.lastOnlineAt,
      );
    } catch (e) {
      logger.w('[ServerHealth]', 'Failed to persist state: $e');
    }
  }

  /// Load persisted state
  Future<void> _loadPersistedState() async {
    if (_persistence == null) return;

    try {
      final cached = await _persistence.loadState();

      if (cached.state != null && cached.timestamp != null) {
        final age = DateTime.now().difference(cached.timestamp!);
        // Only use cached state if less than maxCacheAge
        if (age < config.maxCacheAge) {
          _status = ConnectivityStatus(
            serverState: cached.state!,
            lastCheckedAt: cached.timestamp,
            lastOnlineAt: cached.lastOnline,
          );
          logger.d('[ServerHealth]', 'Loaded cached state: ${cached.state!.name}');
        }
      }
    } catch (e) {
      logger.w('[ServerHealth]', 'Failed to load persisted state: $e');
    }
  }

  /// Dispose resources
  void dispose() {
    _healthCheckTimer?.cancel();
    _recoveryCheckTimer?.cancel();
    _connectivitySubscription?.cancel();
    _wsEventSubscription?.cancel();
    _statusController.close();
  }
}
