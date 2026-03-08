import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/datasources/datasources.dart';
import '../../core/database/repositories/repository_providers.dart';
import '../../core/services/logger_service.dart';
import '../../features/sync/services/offline_sync_service.dart'
    show SyncOperationStatus, SyncProgressEvent, SyncResult, SyncStatus;

/// Progress info for a single operation being synced
class OperationSyncProgress {
  final int operationId;
  final int current;
  final int total;
  final SyncOperationStatus status;
  final String? error;

  const OperationSyncProgress({
    required this.operationId,
    required this.current,
    required this.total,
    required this.status,
    this.error,
  });

  double get progressPercent => total > 0 ? (current / total) * 100 : 0;
}

/// State for offline queue UI
class OfflineQueueState {
  final List<OfflineOperation> operations;
  final bool isLoading;
  final bool isProcessing;
  final String? error;

  /// Map of operation ID to its sync progress (only during sync)
  final Map<int, OperationSyncProgress> syncProgress;

  /// Current sync progress (overall)
  final int currentSyncIndex;
  final int totalSyncCount;

  const OfflineQueueState({
    this.operations = const [],
    this.isLoading = false,
    this.isProcessing = false,
    this.error,
    this.syncProgress = const {},
    this.currentSyncIndex = 0,
    this.totalSyncCount = 0,
  });

  OfflineQueueState copyWith({
    List<OfflineOperation>? operations,
    bool? isLoading,
    bool? isProcessing,
    String? error,
    Map<int, OperationSyncProgress>? syncProgress,
    int? currentSyncIndex,
    int? totalSyncCount,
  }) {
    return OfflineQueueState(
      operations: operations ?? this.operations,
      isLoading: isLoading ?? this.isLoading,
      isProcessing: isProcessing ?? this.isProcessing,
      error: error,
      syncProgress: syncProgress ?? this.syncProgress,
      currentSyncIndex: currentSyncIndex ?? this.currentSyncIndex,
      totalSyncCount: totalSyncCount ?? this.totalSyncCount,
    );
  }

  /// Get sync status for an operation
  OperationSyncProgress? getSyncProgress(int operationId) =>
      syncProgress[operationId];

  /// Get count of operations by priority
  int get criticalCount => operations.where((op) => op.priority == OfflinePriority.critical).length;
  int get highCount => operations.where((op) => op.priority == OfflinePriority.high).length;
  int get normalCount => operations.where((op) => op.priority == OfflinePriority.normal).length;
  int get lowCount => operations.where((op) => op.priority == OfflinePriority.low).length;

  /// Total pending count
  int get totalCount => operations.length;

  /// Group operations by model
  Map<String, List<OfflineOperation>> get operationsByModel {
    final grouped = <String, List<OfflineOperation>>{};
    for (final op in operations) {
      grouped.putIfAbsent(op.model, () => []).add(op);
    }
    return grouped;
  }
}

/// Notifier for offline queue state
class OfflineQueueNotifier extends Notifier<OfflineQueueState> {
  @override
  OfflineQueueState build() {
    // Load initial state
    _loadOperations();
    return const OfflineQueueState(isLoading: true);
  }

  OfflineQueueDataSource? get _offlineQueue =>
      ref.read(offlineQueueDataSourceProvider);

  /// Load pending operations from database
  Future<void> _loadOperations() async {
    try {
      final offlineQueue = _offlineQueue;
      if (offlineQueue == null) {
        state = const OfflineQueueState();
        return;
      }

      // Include ALL operations (including those waiting for retry)
      // so users can see the full queue status
      final operations = await offlineQueue.getPendingOperations(includeNotReady: true);
      state = OfflineQueueState(operations: operations);
      logger.d('[OfflineQueue] Loaded ${operations.length} pending operations');
    } catch (e) {
      logger.e('[OfflineQueue] Error loading operations: $e');
      state = OfflineQueueState(error: e.toString());
    }
  }

  /// Refresh operations list
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    await _loadOperations();
  }

  /// Process all pending operations
  ///
  /// Returns [SyncResult] with count of successful and failed operations.
  Future<SyncResult> processQueue() async {
    final offlineSyncService = ref.read(offlineSyncServiceProvider);
    if (offlineSyncService == null) {
      logger.e('[OfflineQueue] OfflineSyncService not available');
      return SyncResult.noConnection;
    }

    state = state.copyWith(
      isProcessing: true,
      syncProgress: {},
      currentSyncIndex: 0,
      totalSyncCount: state.totalCount,
    );

    // Subscribe to progress events
    final subscription = offlineSyncService.progressStream.listen((SyncProgressEvent event) {
      final progress = OperationSyncProgress(
        operationId: event.operationId,
        current: event.current,
        total: event.total,
        status: event.status,
        error: event.error,
      );

      // Update the sync progress map
      final newProgress = Map<int, OperationSyncProgress>.from(state.syncProgress);
      newProgress[event.operationId] = progress;

      state = state.copyWith(
        syncProgress: newProgress,
        currentSyncIndex: event.current,
        totalSyncCount: event.total,
      );

      logger.d(
        '[OfflineQueue] Progress: op ${event.operationId} - ${event.current}/${event.total} (${event.status})',
      );
    });

    try {
      final result = await offlineSyncService.processQueue();
      await _loadOperations();
      logger.i('[OfflineQueue] Queue processing completed: $result');
      return result;
    } catch (e) {
      logger.e('[OfflineQueue] Error processing queue: $e');
      state = state.copyWith(error: e.toString(), isProcessing: false);
      return SyncResult(
        model: 'queue',
        status: SyncStatus.error,
        synced: 0,
        failed: 1,
        error: e.toString(),
        timestamp: DateTime.now(),
      );
    } finally {
      await subscription.cancel();
      state = state.copyWith(
        isProcessing: false,
        syncProgress: {},
        currentSyncIndex: 0,
        totalSyncCount: 0,
      );
    }
  }

  /// Remove a specific operation
  Future<void> removeOperation(int operationId) async {
    final offlineQueue = _offlineQueue;
    if (offlineQueue == null) return;

    try {
      await offlineQueue.removeOperation(operationId);
      await _loadOperations();
      logger.d('[OfflineQueue] Removed operation $operationId');
    } catch (e) {
      logger.e('[OfflineQueue] Error removing operation: $e');
    }
  }

  /// Clear all pending operations
  Future<void> clearAll() async {
    final offlineQueue = _offlineQueue;
    if (offlineQueue == null) return;

    try {
      await offlineQueue.clearAll();
      state = const OfflineQueueState();
      logger.i('[OfflineQueue] Cleared all operations');
    } catch (e) {
      logger.e('[OfflineQueue] Error clearing operations: $e');
      state = state.copyWith(error: e.toString());
    }
  }
}

/// Provider for offline queue state
final offlineQueueProvider = NotifierProvider<OfflineQueueNotifier, OfflineQueueState>(
  OfflineQueueNotifier.new,
);

/// Helper extensions for OfflineOperation display
extension OfflineOperationDisplay on OfflineOperation {
  /// Get human-readable model name
  String get modelDisplayName {
    switch (model) {
      case 'collection.session':
        return 'Sesión de Caja';
      case 'account.payment':
        return 'Pago';
      case 'res.partner':
        return 'Cliente';
      case 'sale.order':
        return 'Orden de Venta';
      case 'sale.order.line':
        return 'Línea de Orden';
      default:
        return model;
    }
  }

  /// Get human-readable method name
  String get methodDisplayName {
    switch (method) {
      case 'session_create_and_open':
        return 'Crear y Abrir';
      case 'session_open':
        return 'Abrir';
      case 'session_closing_control':
        return 'Control de Cierre';
      case 'session_close':
        return 'Cerrar';
      case 'payment_create':
        return 'Crear Pago';
      case 'partner_create':
        return 'Crear Cliente';
      case 'create':
        return 'Crear';
      case 'write':
        return 'Actualizar';
      case 'unlink':
        return 'Eliminar';
      default:
        return method;
    }
  }

  /// Get priority display name
  String get priorityDisplayName {
    switch (priority) {
      case OfflinePriority.critical:
        return 'Crítico';
      case OfflinePriority.high:
        return 'Alto';
      case OfflinePriority.normal:
        return 'Normal';
      case OfflinePriority.low:
        return 'Bajo';
      default:
        return 'Normal';
    }
  }

  /// Get summary description
  String get summary {
    final buffer = StringBuffer();
    buffer.write(methodDisplayName);
    buffer.write(' - ');
    buffer.write(modelDisplayName);

    // Add record ID if available
    if (recordId != null && recordId! > 0) {
      buffer.write(' #$recordId');
    }

    return buffer.toString();
  }
}
