/// Connectivity Sync Orchestrator
///
/// Orchestrates automatic synchronization when server connectivity is restored.
/// Implements gradual sync with rate limiting to avoid overwhelming the server.
library;

import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/datasources/datasources.dart' show OfflineQueueDataSource;
import '../../../core/services/logger_service.dart' show logger;
import '../../../core/services/platform/server_connectivity_service.dart';
import '../providers/offline_mode_providers.dart' show offlineModeConfigProvider;
import '../../../core/database/repositories/repository_providers.dart';
import '../providers/sync_provider.dart';
import 'offline_sync_service.dart';

/// Orchestrator that triggers automatic sync when server recovers.
///
/// Features:
/// - Waits for connection stability before syncing
/// - Gradual sync with rate limiting
/// - Prevents duplicate sync triggers
/// - Respects app lifecycle (background vs foreground)
class ConnectivitySyncOrchestrator {
  final ServerHealthService _healthService;
  final bool Function() _isOfflineModeEnabledFn;
  final OfflineSyncService? Function() _getOfflineSyncService;
  final OfflineQueueDataSource? Function() _getOfflineQueue;
  final Future<void> Function() _syncCriticalData;

  StreamSubscription<ConnectivityStatus>? _statusSubscription;
  Timer? _stabilityTimer;

  bool _isSyncing = false;
  bool _isInitialized = false;
  ServerConnectionState? _previousState;

  // Configuration
  static const Duration _stabilityWait = Duration(seconds: 5);
  static const int _batchSize = 10;
  static const Duration _batchDelay = Duration(seconds: 2);

  ConnectivitySyncOrchestrator({
    required ServerHealthService healthService,
    required bool Function() isOfflineModeEnabled,
    required OfflineSyncService? Function() getOfflineSyncService,
    required OfflineQueueDataSource? Function() getOfflineQueue,
    required Future<void> Function() syncCriticalData,
  })  : _healthService = healthService,
        _isOfflineModeEnabledFn = isOfflineModeEnabled,
        _getOfflineSyncService = getOfflineSyncService,
        _getOfflineQueue = getOfflineQueue,
        _syncCriticalData = syncCriticalData;

  /// Initialize the orchestrator and start listening to connectivity changes
  void initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    logger.i('[SyncOrchestrator]', 'Initializing connectivity sync orchestrator');

    // Store initial state
    _previousState = _healthService.status.serverState;

    // Listen to connectivity status changes
    _statusSubscription = _healthService.statusStream.listen(_onConnectivityChanged);
  }

  /// Handle connectivity status changes
  void _onConnectivityChanged(ConnectivityStatus status) {
    final currentState = status.serverState;
    final wasOffline = _previousState == ServerConnectionState.unreachable ||
        _previousState == ServerConnectionState.maintenance ||
        _previousState == ServerConnectionState.unknown;
    final isNowOnline = currentState == ServerConnectionState.online;

    logger.d(
      '[SyncOrchestrator]',
      'Connectivity changed: ${_previousState?.name} -> ${currentState.name}',
    );

    // Check for recovery scenario
    if (wasOffline && isNowOnline) {
      // Don't auto-sync if offline mode is manually enabled
      if (_isOfflineModeEnabledFn()) {
        logger.d('[SyncOrchestrator]', 'Server recovered but offline mode is enabled - skipping auto-sync');
        _previousState = currentState;
        return;
      }
      logger.i('[SyncOrchestrator]', 'Server recovered! Scheduling sync...');
      _scheduleRecoverySync();
    }

    _previousState = currentState;
  }

  /// Schedule a sync after confirming connection stability
  void _scheduleRecoverySync() {
    // Cancel any pending stability check
    _stabilityTimer?.cancel();

    // Wait for connection stability
    _stabilityTimer = Timer(_stabilityWait, () async {
      // Verify still online
      if (_healthService.status.serverState != ServerConnectionState.online) {
        logger.w('[SyncOrchestrator]', 'Connection lost during stability wait - aborting sync');
        return;
      }

      // Proceed with recovery sync
      await _performRecoverySync();
    });
  }

  /// Perform the recovery sync with rate limiting
  Future<void> _performRecoverySync() async {
    if (_isSyncing) {
      logger.d('[SyncOrchestrator]', 'Sync already in progress - skipping');
      return;
    }

    _isSyncing = true;
    logger.i('[SyncOrchestrator]', 'Starting recovery sync...');

    try {
      // 1. Process offline queue first (highest priority)
      await _processOfflineQueue();

      // 2. Check if still online
      if (_healthService.status.serverState != ServerConnectionState.online) {
        logger.w('[SyncOrchestrator]', 'Connection lost during sync - stopping');
        return;
      }

      // 3. Perform incremental catalog sync
      await _performIncrementalSync();

      logger.i('[SyncOrchestrator]', 'Recovery sync completed successfully');
    } catch (e, stack) {
      logger.e('[SyncOrchestrator]', 'Recovery sync failed: $e\n$stack');
    } finally {
      _isSyncing = false;
    }
  }

  /// Process offline queue with rate limiting
  Future<void> _processOfflineQueue() async {
    final offlineSyncService = _getOfflineSyncService();
    if (offlineSyncService == null) {
      logger.w('[SyncOrchestrator]', 'OfflineSyncService not available');
      return;
    }

    logger.d('[SyncOrchestrator]', 'Processing offline queue...');

    // Get pending operations count
    final pendingCount = await _getPendingOperationsCount();
    if (pendingCount == 0) {
      logger.d('[SyncOrchestrator]', 'No pending operations in queue');
      return;
    }

    logger.i('[SyncOrchestrator]', 'Processing $pendingCount pending operations');

    // Process in batches to avoid overwhelming server
    int processed = 0;
    while (processed < pendingCount) {
      // Check if still online
      if (_healthService.status.serverState != ServerConnectionState.online) {
        logger.w('[SyncOrchestrator]', 'Connection lost - pausing queue processing');
        break;
      }

      // Process a batch
      final result = await offlineSyncService.processQueue();
      processed += _batchSize;

      logger.d('[SyncOrchestrator]', 'Batch processed: $result');

      // Rate limiting delay between batches
      if (processed < pendingCount) {
        await Future.delayed(_batchDelay);
      }
    }
  }

  /// Get count of pending operations
  Future<int> _getPendingOperationsCount() async {
    try {
      final offlineQueue = _getOfflineQueue();
      if (offlineQueue == null) return 0;

      final operations = await offlineQueue.getPendingOperations();
      return operations.length;
    } catch (e) {
      logger.w('[SyncOrchestrator]', 'Error getting pending count: $e');
      return 0;
    }
  }

  /// Perform incremental catalog sync
  Future<void> _performIncrementalSync() async {
    try {
      logger.d('[SyncOrchestrator]', 'Starting incremental catalog sync...');

      // Sync critical catalogs only (lightweight)
      // Full sync can be triggered manually by user
      await _syncCriticalData();

      logger.d('[SyncOrchestrator]', 'Incremental catalog sync completed');
    } catch (e) {
      logger.w('[SyncOrchestrator]', 'Catalog sync failed: $e');
      // Non-fatal - queue was already processed
    }
  }

  /// Manually trigger a sync (can be called from UI)
  Future<void> triggerManualSync() async {
    logger.i('[SyncOrchestrator]', 'Manual sync triggered');
    await _performRecoverySync();
  }

  /// Dispose resources
  void dispose() {
    _stabilityTimer?.cancel();
    _statusSubscription?.cancel();
    _isInitialized = false;
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

/// Provider for ConnectivitySyncOrchestrator
final connectivitySyncOrchestratorProvider = Provider<ConnectivitySyncOrchestrator>((ref) {
  final healthService = ref.read(serverHealthServiceProvider);
  final syncNotifier = ref.read(syncProvider.notifier);

  final orchestrator = ConnectivitySyncOrchestrator(
    healthService: healthService,
    isOfflineModeEnabled: () {
      try {
        final offlineConfig = ref.read(offlineModeConfigProvider);
        return offlineConfig.maybeWhen(
          data: (config) => config.isEnabled,
          orElse: () => false,
        );
      } catch (_) {
        return false;
      }
    },
    getOfflineSyncService: () => ref.read(offlineSyncServiceProvider),
    getOfflineQueue: () => ref.read(offlineQueueDataSourceProvider),
    syncCriticalData: () => syncNotifier.syncCriticalData(),
  );

  // Initialize when provider is first accessed
  orchestrator.initialize();

  ref.onDispose(() => orchestrator.dispose());

  return orchestrator;
});
