/// Server Connectivity Service - App Integration
///
/// This file provides Riverpod providers that wrap the generic ServerHealthService
/// from odoo_offline_core with app-specific dependencies.
library;

import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../websocket/odoo_websocket_service.dart';
import '../../database/repositories/repository_providers.dart';

// Re-export types from package for backward compatibility
export 'package:odoo_sdk/odoo_sdk.dart'
    show
        ServerConnectionState,
        ConnectivityStatus,
        ServerHealthService,
        ServerHealthConfig,
        HealthCheckCallback,
        WebSocketStateCallback,
        WebSocketEventSubscriber,
        HealthStatePersistence,
        NetworkConnectivityMonitor;

// ============================================================================
// APP-SPECIFIC IMPLEMENTATIONS
// ============================================================================

/// SharedPreferences-based persistence for health state
class _SharedPrefsHealthPersistence implements HealthStatePersistence {
  static const _keyState = 'server_health_state';
  static const _keyTimestamp = 'server_health_timestamp';
  static const _keyLastOnline = 'server_health_last_online';

  @override
  Future<void> saveState(
    ServerConnectionState state,
    DateTime timestamp,
    DateTime? lastOnline,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyState, state.name);
    await prefs.setInt(_keyTimestamp, timestamp.millisecondsSinceEpoch);
    if (lastOnline != null) {
      await prefs.setInt(_keyLastOnline, lastOnline.millisecondsSinceEpoch);
    }
  }

  @override
  Future<({ServerConnectionState? state, DateTime? timestamp, DateTime? lastOnline})>
      loadState() async {
    final prefs = await SharedPreferences.getInstance();
    final stateStr = prefs.getString(_keyState);
    final timestamp = prefs.getInt(_keyTimestamp);
    final lastOnline = prefs.getInt(_keyLastOnline);

    return (
      state: stateStr != null
          ? ServerConnectionState.values.firstWhere(
              (s) => s.name == stateStr,
              orElse: () => ServerConnectionState.unknown,
            )
          : null,
      timestamp: timestamp != null
          ? DateTime.fromMillisecondsSinceEpoch(timestamp)
          : null,
      lastOnline: lastOnline != null
          ? DateTime.fromMillisecondsSinceEpoch(lastOnline)
          : null,
    );
  }
}

/// connectivity_plus based network monitor
class _ConnectivityPlusMonitor implements NetworkConnectivityMonitor {
  final _connectivity = Connectivity();

  @override
  Future<bool> checkConnectivity() async {
    final results = await _connectivity.checkConnectivity();
    return _hasNetworkFromResults(results);
  }

  @override
  Stream<bool> get connectivityStream {
    return _connectivity.onConnectivityChanged.map(_hasNetworkFromResults);
  }

  bool _hasNetworkFromResults(List<ConnectivityResult> results) {
    if (results.isEmpty) return false;
    return !results.every((r) => r == ConnectivityResult.none);
  }
}

// ============================================================================
// MONITORED ODOO CLIENT EXTENSION
// ============================================================================

/// Extension to wrap OdooClient calls and report health to ServerHealthService.
///
/// This is a non-invasive wrapper that doesn't modify odoo_offline_core.
extension MonitoredOdooClientExtension on OdooClient {
  /// Execute a call and report result to health service
  Future<T> callWithHealthMonitoring<T>(
    ServerHealthService healthService, {
    required String model,
    required String method,
    List<dynamic> args = const [],
    Map<String, dynamic> kwargs = const {},
  }) async {
    final stopwatch = Stopwatch()..start();
    try {
      final result = await call(
        model: model,
        method: method,
        args: args,
        kwargs: kwargs,
      );
      stopwatch.stop();
      healthService.recordSuccess(latencyMs: stopwatch.elapsedMilliseconds);
      return result as T;
    } catch (e) {
      stopwatch.stop();
      // Extract status code if available
      int? statusCode;
      if (e is OdooException) {
        statusCode = e.statusCode;
      }
      healthService.recordFailure(e, statusCode: statusCode);
      rethrow;
    }
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for ServerHealthService with all app dependencies wired up
final serverHealthServiceProvider = Provider<ServerHealthService>((ref) {
  final odooClient = ref.watch(odooClientProvider);
  final wsService = ref.watch(odooWebSocketServiceProvider);

  final service = ServerHealthService(
    config: const ServerHealthConfig(),

    // Health check using OdooClient
    healthCheck: odooClient != null
        ? () async {
            await odooClient.call(
              model: 'res.users',
              method: 'search_count',
              kwargs: {'domain': []},
            );
          }
        : null,

    // WebSocket state
    getWebSocketState: () => wsService.isConnected,

    // WebSocket event subscription
    subscribeToWebSocket: (callback) => wsService.eventStream.listen(callback),

    // Persistence
    persistence: _SharedPrefsHealthPersistence(),

    // Network monitoring: use polling on web (connectivity_plus has known
    // issues in web release builds), connectivity_plus on native.
    networkMonitor: kIsWeb
        ? PollingConnectivityMonitor()
        : _ConnectivityPlusMonitor(),
  );

  // Initialize asynchronously
  Future.microtask(() => service.initialize());

  ref.onDispose(() => service.dispose());

  return service;
});

/// Provider for current connectivity status
final connectivityStatusProvider = StreamProvider<ConnectivityStatus>((ref) {
  final healthService = ref.watch(serverHealthServiceProvider);
  return healthService.statusStream;
});

/// Provider for simple online/offline check (convenience)
final isServerOnlineProvider = Provider<bool>((ref) {
  final healthService = ref.watch(serverHealthServiceProvider);
  return healthService.status.canAttemptRemote;
});

/// Provider that returns OdooClient only if server is reachable
/// Use this instead of effectiveOdooClientProvider for health-aware operations
final healthAwareOdooClientProvider = Provider<OdooClient?>((ref) {
  final effectiveClient = ref.watch(effectiveOdooClientProvider);
  if (effectiveClient == null) return null;

  final healthService = ref.watch(serverHealthServiceProvider);
  if (healthService.status.shouldSkipRemote) {
    return null; // Server unreachable - don't even try
  }

  return effectiveClient;
});
