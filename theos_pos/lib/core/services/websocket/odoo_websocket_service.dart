/// Odoo WebSocket Service - App Integration
///
/// This file provides Riverpod providers that wrap the generic OdooWebSocketService
/// from odoo_offline_core with app-specific session management.
///
/// Features:
/// - Auto-reconnect with exponential backoff
/// - Session-based connection management
/// - Default channel subscriptions
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

import 'package:odoo_sdk/odoo_sdk.dart' hide ServerConfig;

import '../../../features/authentication/services/server_service.dart';

// Re-export types from package for backward compatibility
export 'package:odoo_sdk/odoo_sdk.dart'
    show
        OdooWebSocketService,
        OdooWebSocketConnectionInfo,
        OdooWebSocketEvent,
        OdooConnectionEvent,
        OdooErrorEvent,
        OdooPresenceEvent,
        OdooCompanyConfigEvent,
        OdooRecordEvent,
        OdooRecordAction,
        OdooOrderLineEvent,
        OdooCatalogEvent,
        OdooRawNotificationEvent,
        parseRecordAction,
        BrowserSessionEstablisher;

// ============================================================================
// RECONNECT STATE
// ============================================================================

/// State class for tracking WebSocket reconnection attempts.
///
/// Used to notify UI of reconnect progress and status.
class ReconnectState {
  /// Whether a reconnection is currently in progress
  final bool isReconnecting;

  /// Current reconnect attempt number (0 = not reconnecting)
  final int attempt;

  /// Time until next retry attempt
  final Duration? nextRetryIn;

  /// Whether max attempts has been reached
  final bool maxAttemptsReached;

  /// Whether successfully connected
  final bool connected;

  const ReconnectState({
    this.isReconnecting = false,
    this.attempt = 0,
    this.nextRetryIn,
    this.maxAttemptsReached = false,
    this.connected = false,
  });

  /// Initial state (not reconnecting)
  static const initial = ReconnectState();

  /// Check if we're waiting for next retry
  bool get isWaitingForRetry => isReconnecting && nextRetryIn != null;

  /// Human-readable status message
  String get statusMessage {
    if (connected) return 'Conectado';
    if (maxAttemptsReached) return 'Reconexión fallida';
    if (isReconnecting) {
      if (nextRetryIn != null) {
        return 'Reintentando en ${nextRetryIn!.inSeconds}s (intento $attempt)';
      }
      return 'Reconectando... (intento $attempt)';
    }
    return 'Desconectado';
  }

  @override
  String toString() =>
      'ReconnectState(isReconnecting: $isReconnecting, attempt: $attempt, '
      'nextRetryIn: $nextRetryIn, maxAttemptsReached: $maxAttemptsReached, '
      'connected: $connected)';
}

// ============================================================================
// APP-SPECIFIC WEBSOCKET WRAPPER
// ============================================================================

/// App-specific wrapper for OdooWebSocketService that integrates with Riverpod.
///
/// This wrapper:
/// - Reads session info from serverServiceProvider
/// - Configures browser session establishment for Web platform
/// - Manages default channel subscriptions
/// - Auto-reconnect with exponential backoff on disconnect
class AppOdooWebSocketService {
  final ServerConfig? Function() _getCurrentSession;
  late final OdooWebSocketService _service;

  /// Auto-reconnect configuration
  late final ExponentialBackoff _backoff;

  /// Whether auto-reconnect is enabled
  bool _autoReconnectEnabled = true;

  /// Whether we're currently attempting to reconnect
  bool _isReconnecting = false;

  /// Timer for scheduled reconnect
  Timer? _reconnectTimer;

  /// Subscription for connection events
  StreamSubscription<OdooWebSocketEvent>? _connectionEventSub;

  /// Controller for reconnect state changes
  final _reconnectStateController = StreamController<ReconnectState>.broadcast();

  AppOdooWebSocketService({
    required ServerConfig? Function() getCurrentSession,
  }) : _getCurrentSession = getCurrentSession {
    _service = OdooWebSocketService();

    // Configure browser session establishment callback for Web platform
    _service.browserSessionEstablisher = _establishBrowserSession;

    // Initialize backoff with WebSocket preset
    _backoff = BackoffPresets.websocket(
      onRetry: (attempt, delay) {
        logger.d('[OdooWebSocket] Reconnect attempt $attempt in ${delay.inSeconds}s');
        _reconnectStateController.add(ReconnectState(
          isReconnecting: true,
          attempt: attempt,
          nextRetryIn: delay,
        ));
      },
      onMaxAttemptsReached: () {
        logger.w('[OdooWebSocket] Max reconnect attempts reached');
        _isReconnecting = false;
        _reconnectStateController.add(ReconnectState(
          isReconnecting: false,
          attempt: _backoff.attempts,
          maxAttemptsReached: true,
        ));
      },
    );

    // Listen for disconnect events to trigger auto-reconnect
    _connectionEventSub = _service.eventsOfType<OdooConnectionEvent>().listen(
      _handleConnectionEvent,
    );
  }

  // ============================================================================
  // DELEGATED GETTERS
  // ============================================================================

  bool get isConnected => _service.isConnected;
  String? get connectionUrl => _service.connectionUrl;
  String? get lastError => _service.lastError;
  DateTime? get lastHeartbeat => _service.lastHeartbeat;
  Map<String, dynamic>? get lastNotification => _service.lastNotification;
  int get reconnectAttempts => _service.reconnectAttempts;
  List<String> get subscribedChannels => _service.subscribedChannels;

  // ============================================================================
  // AUTO-RECONNECT
  // ============================================================================

  /// Whether auto-reconnect is enabled
  bool get autoReconnectEnabled => _autoReconnectEnabled;

  /// Whether currently attempting to reconnect
  bool get isReconnecting => _isReconnecting;

  /// Current reconnect attempt number
  int get currentReconnectAttempt => _backoff.attempts;

  /// Stream of reconnect state changes
  Stream<ReconnectState> get reconnectStateStream => _reconnectStateController.stream;

  /// Enable or disable auto-reconnect
  set autoReconnectEnabled(bool value) {
    _autoReconnectEnabled = value;
    if (!value) {
      _cancelReconnect();
    }
  }

  /// Handle connection events for auto-reconnect
  void _handleConnectionEvent(OdooConnectionEvent event) {
    if (event.isConnected) {
      // Successfully connected - reset backoff
      _backoff.reset();
      _isReconnecting = false;
      _reconnectStateController.add(ReconnectState(
        isReconnecting: false,
        attempt: 0,
        connected: true,
      ));
    } else if (_autoReconnectEnabled && !_isReconnecting) {
      // Disconnected - start auto-reconnect
      _startAutoReconnect();
    }
  }

  /// Start auto-reconnect process
  void _startAutoReconnect() async {
    if (_isReconnecting || !_autoReconnectEnabled) return;

    _isReconnecting = true;
    _backoff.reset();

    logger.d('[OdooWebSocket] Starting auto-reconnect...');

    while (_backoff.shouldRetry && _autoReconnectEnabled && _isReconnecting) {
      // Wait for backoff delay
      if (!await _backoff.wait()) {
        break;
      }

      try {
        await connect();
        if (isConnected) {
          logger.d('[OdooWebSocket] Reconnected successfully');
          _isReconnecting = false;
          return;
        }
      } catch (e) {
        logger.w('[OdooWebSocket] Reconnect failed: $e');
      }
    }

    _isReconnecting = false;
  }

  /// Cancel ongoing reconnect attempts
  void _cancelReconnect() {
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _backoff.reset();
  }

  /// Manually trigger a reconnect attempt
  Future<void> manualReconnect() async {
    _cancelReconnect();
    _backoff.reset();
    try {
      await connect();
    } catch (e) {
      logger.e('[OdooWebSocket] Manual reconnect failed: $e');
      if (_autoReconnectEnabled) {
        _startAutoReconnect();
      }
    }
  }

  // ============================================================================
  // EVENT STREAMS
  // ============================================================================

  /// Stream of typed WebSocket events.
  Stream<OdooWebSocketEvent> get eventStream => _service.eventStream;

  /// Subscribe to typed events with automatic cleanup.
  StreamSubscription<OdooWebSocketEvent> addEventListener(
    void Function(OdooWebSocketEvent) callback,
  ) {
    return _service.addEventListener(callback);
  }

  /// Get a filtered stream of specific event types.
  Stream<T> eventsOfType<T extends OdooWebSocketEvent>() {
    return _service.eventsOfType<T>();
  }

  // ============================================================================
  // CONNECTION MANAGEMENT
  // ============================================================================

  /// Connect to Odoo WebSocket using session from serverServiceProvider.
  Future<void> connect() async {
    final sessionInfo = _getCurrentSession();

    if (sessionInfo == null) {
      logger.e('[OdooWebSocket]', 'No session info available');
      return;
    }

    // Build default channels for this database
    final channels = _buildDefaultChannels(
      sessionInfo.database,
      sessionInfo.partnerId,
    );

    // Add channels before connecting
    _service.addChannels(channels);

    // Connect with session info
    // Allow insecure (ws://) for local development (http:// URLs)
    final isInsecureUrl = sessionInfo.url.startsWith('http://');
    await _service.connect(OdooWebSocketConnectionInfo(
      baseUrl: sessionInfo.url,
      database: sessionInfo.database,
      apiKey: sessionInfo.apiKey,
      sessionId: sessionInfo.sessionId,
      partnerId: sessionInfo.partnerId,
      isWeb: kIsWeb,
      allowInsecure: isInsecureUrl,
    ));
  }

  /// Disconnect from WebSocket
  void disconnect() {
    _cancelReconnect();
    _service.disconnect();
  }

  /// Dispose and cleanup
  void dispose() {
    _cancelReconnect();
    _connectionEventSub?.cancel();
    _reconnectStateController.close();
    _service.dispose();
  }

  // ============================================================================
  // PRIVATE METHODS
  // ============================================================================

  /// Establish browser session for Web platform
  Future<void> _establishBrowserSession({
    required String baseUrl,
    required String apiKey,
    required String database,
    required String sessionId,
  }) async {
    if (kIsWeb) {
      await BrowserSessionHelper.establishBrowserSession(
        baseUrl: baseUrl,
        apiKey: apiKey,
        database: database,
        sessionId: sessionId,
      );
    }
  }

  /// Build default channels to subscribe to.
  ///
  /// These are the standard Odoo bus channels for the POS app.
  List<String> _buildDefaultChannels(String database, int? partnerId) {
    final channels = <String>[
      '$database.collection_config',
      '$database.collection_session',
      '$database.res.partner',
      '$database.mail.channel',
      '$database.sale.order',
      '$database.sale.order.line',
      '$database.res_company',
      // Product/catalog channels
      '$database.product_price_updated',
      '$database.pricelist_item_updated',
      '$database.product_uom_updated',
      '$database.uom_uom_updated',
      // WebSocket sync channels
      '$database.sale_order_updated',
      '$database.sale_order_withhold_updated',
      '$database.sale_order_payment_updated',
      '$database.partner_updated',
      '$database.company_updated',
      '$database.user_updated',
      '$database.product_updated',
      // Card payment channels
      '$database.card_brand_updated',
      '$database.card_deadline_updated',
      '$database.card_lote_updated',
      '$database.journal_updated',
      // Payment channels
      '$database.payment_method_line_updated',
      '$database.advance_updated',
      '$database.credit_note_updated',
    ];

    // Subscribe to presence/activity channels if partnerId available
    if (partnerId != null) {
      channels.add('$database.odoo-presence-res.partner_$partnerId');
      channels.add('$database.odoo-activity-res.partner_$partnerId');
    }

    return channels;
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for WebSocket service (app-specific wrapper).
///
/// This provides an `AppOdooWebSocketService` which wraps the generic
/// `OdooWebSocketService` from odoo_offline_core with Riverpod integration.
final odooWebSocketServiceProvider = Provider<AppOdooWebSocketService>((ref) {
  final service = AppOdooWebSocketService(
    getCurrentSession: () => ref.read(serverServiceProvider.notifier).currentSession,
  );
  ref.onDispose(() => service.dispose());
  return service;
});

/// Convenience provider for checking WebSocket connection status.
final isWebSocketConnectedProvider = Provider<bool>((ref) {
  return ref.watch(odooWebSocketServiceProvider).isConnected;
});

/// Provider for WebSocket reconnect state stream.
///
/// Use this to display reconnect status in the UI.
final webSocketReconnectStateProvider = StreamProvider<ReconnectState>((ref) {
  return ref.watch(odooWebSocketServiceProvider).reconnectStateStream;
});

/// Provider for checking if WebSocket is currently reconnecting.
final isWebSocketReconnectingProvider = Provider<bool>((ref) {
  return ref.watch(odooWebSocketServiceProvider).isReconnecting;
});
