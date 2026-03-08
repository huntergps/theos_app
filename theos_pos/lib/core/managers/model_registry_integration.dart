/// ModelRegistry Integration for theos_pos
///
/// Bridges the ModelRegistry from odoo_model_manager with the existing
/// theos_pos services (WebSocket, OfflineSync, etc.)
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart' as mm;
import 'package:odoo_sdk/odoo_sdk.dart' as core;

import '../services/websocket/odoo_websocket_service.dart';
import 'manager_providers.dart';

// Re-export commonly used types
export 'package:odoo_sdk/odoo_sdk.dart'
    show ModelRegistry, SyncReport, SyncProgress, CancellationToken, ModelSyncStatus;

// ═══════════════════════════════════════════════════════════════════════════
// WebSocket Event Adapter
// ═══════════════════════════════════════════════════════════════════════════

/// Converts OdooRecordEvent (WebSocket) to ModelRecordEvent (ModelManager) format.
mm.ModelRecordEvent _adaptEvent(core.OdooRecordEvent coreEvent) {
  return mm.ModelRecordEvent(
    model: coreEvent.model,
    recordId: coreEvent.recordId,
    operation: _mapAction(coreEvent.action),
    data: coreEvent.values.isNotEmpty ? coreEvent.values : null,
    timestamp: coreEvent.writeDate ?? DateTime.now(),
  );
}

mm.RecordOperation _mapAction(core.OdooRecordAction action) {
  return switch (action) {
    core.OdooRecordAction.created => mm.RecordOperation.create,
    core.OdooRecordAction.updated => mm.RecordOperation.write,
    core.OdooRecordAction.deleted => mm.RecordOperation.unlink,
  };
}

// ═══════════════════════════════════════════════════════════════════════════
// Integration Service
// ═══════════════════════════════════════════════════════════════════════════

/// Service that connects ModelRegistry with theos_pos WebSocket events.
///
/// Listens to OdooRecordEvent from WebSocket and routes them to the
/// appropriate ModelManager via ModelRegistry.
class ModelRegistryIntegration {
  final AppOdooWebSocketService _wsService;
  StreamSubscription<core.OdooWebSocketEvent>? _subscription;
  bool _isConnected = false;

  ModelRegistryIntegration(this._wsService);

  /// Start listening to WebSocket events and routing to ModelRegistry.
  void connect() {
    if (_isConnected) return;

    _subscription = _wsService.eventStream.listen((event) {
      if (event is core.OdooRecordEvent) {
        final adapted = _adaptEvent(event);
        final manager =
            mm.ModelRegistry.get<mm.OdooModelManager>(adapted.model);
        manager?.handleWebSocketEvent(adapted);
      }
    });

    _isConnected = true;
  }

  /// Stop listening to WebSocket events.
  void disconnect() {
    _subscription?.cancel();
    _subscription = null;
    _isConnected = false;
  }

  /// Dispose resources.
  void dispose() {
    disconnect();
  }

  bool get isConnected => _isConnected;
}

// ═══════════════════════════════════════════════════════════════════════════
// Riverpod Providers
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for ModelRegistryIntegration.
///
/// Auto-connects when WebSocket service is available.
final modelRegistryIntegrationProvider =
    Provider.autoDispose<ModelRegistryIntegration>((ref) {
  final wsService = ref.watch(odooWebSocketServiceProvider);

  final integration = ModelRegistryIntegration(wsService);

  // Auto-connect
  integration.connect();

  // Cleanup on dispose
  ref.onDispose(() {
    integration.dispose();
  });

  return integration;
});

/// Provider that initializes ModelRegistry with all managers.
///
/// Call this early in app startup, after database is ready.
final modelRegistryInitializerProvider = Provider<bool>((ref) {
  // Initialize managers via their providers
  initializeModelManagers();
  return true;
});

// ═══════════════════════════════════════════════════════════════════════════
// Convenience Extension for SyncAll
// ═══════════════════════════════════════════════════════════════════════════

/// Extension to add ModelRegistry sync capabilities to Ref.
extension ModelRegistrySyncExtension on Ref {
  /// Sync all registered models from Odoo.
  ///
  /// Delegates to ModelRegistry.syncAll().
  Future<mm.SyncReport> syncAllModels({
    DateTime? since,
    mm.MultiModelSyncCallback? onProgress,
    mm.CancellationToken? cancellation,
  }) {
    return mm.ModelRegistry.syncAll(
      since: since,
      onProgress: onProgress,
      cancellation: cancellation,
    );
  }

  /// Get sync status for all registered models.
  Future<Map<String, mm.ModelSyncStatus>> getModelSyncStatus() {
    return mm.ModelRegistry().getSyncStatus();
  }

  /// Check if any model has unsynced changes.
  Future<bool> hasUnsyncedChanges() {
    return mm.ModelRegistry().hasUnsyncedChanges();
  }
}
