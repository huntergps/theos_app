import 'dart:async';

import 'package:odoo_sdk/odoo_sdk.dart'
    show
        OdooClient,
        logger,
        SyncProgressEvent,
        SyncResult,
        SyncStatus,
        ConflictInfo,
        OperationSkippedException,
        OfflineQueueProcessor,
        OfflineQueueAuditLogger;
import 'package:drift/drift.dart' as drift;
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase, AccountPaymentManager, SaleOrder, SaleOrderLine, SaleOrderLineManager, SaleOrderLineManagerBusiness, saleOrderLineManager, SaleOrderManager, SaleOrderManagerBusiness, saleOrderManager, ClientManagerBusiness, clientManager, CollectionSessionManager, CollectionSessionManagerBusiness, SaleOrderPaymentLineCompanion;
import '../../../core/database/database_helper.dart';
import '../../../core/database/datasources/datasources.dart';
import '../../../shared/utils/error_utils.dart';

// Re-export sync types from package for backward compatibility
export 'package:odoo_sdk/odoo_sdk.dart'
    show
        SyncProgressEvent,
        SyncOperationStatus,
        SyncResult,
        SyncStatus,
        ConflictInfo,
        OperationSkippedException,
        SyncConflictException,
        SyncFieldResult,
        FieldChange,
        ConflictResolutionStrategy,
        SyncModelHandler;

part 'offline_sync_session.dart';
part 'offline_sync_generic_ops.dart';
part 'offline_sync_partner.dart';
part 'offline_sync_sale_order.dart';
part 'offline_sync_payment.dart';

/// App-specific extension for SyncResult
///
/// Provides convenience getters for invoice-related data stored in [extra].
extension SyncResultAppExtension on SyncResult {
  /// Invoice ID created during sync (if any)
  int? get invoiceCreated => extra['invoiceCreated'] as int?;

  /// Whether an invoice was created during sync
  bool get hasInvoice => invoiceCreated != null;
}

/// Service for processing offline queue operations
///
/// Handles syncing locally-queued operations to Odoo when connection
/// is restored. Processes create, write, and unlink operations in FIFO order.
///
/// Usage:
/// ```dart
/// final syncService = OfflineSyncService(
///   db: databaseHelper,
///   odooClient: odooClient,
///   offlineQueue: offlineQueueDataSource,
/// );
///
/// // Process all pending operations
/// final result = await syncService.processQueue();
/// ```
class OfflineSyncService {
  final DatabaseHelper _db;
  final AppDatabase _appDb;
  final OdooClient? _odooClient;
  final OfflineQueueDataSource _offlineQueue;
  final CollectionSessionManager _sessionManager;
  final AccountPaymentManager _paymentManager;
  late final OfflineQueueProcessor _processor;

  bool _isSyncing = false;

  /// Last invoice ID created during sync (used for result feedback)
  int? _lastInvoiceCreated;

  /// Convenience accessor for the global SaleOrderManager
  SaleOrderManager get _orderManager => saleOrderManager;

  /// Convenience accessor for the global SaleOrderLineManager
  SaleOrderLineManager get _lineManager => saleOrderLineManager;

  OfflineSyncService({
    required DatabaseHelper db,
    required AppDatabase appDb,
    OdooClient? odooClient,
    required OfflineQueueDataSource offlineQueue,
    required CollectionSessionManager sessionManager,
    required AccountPaymentManager paymentManager,
  })  : _db = db,
        _appDb = appDb,
        _odooClient = odooClient,
        _offlineQueue = offlineQueue,
        _sessionManager = sessionManager,
        _paymentManager = paymentManager {
    _processor = OfflineQueueProcessor(
      queue: _offlineQueue,
      handler: _processOperation,
      auditLogger: _AppAuditLogger(_db),
      removeOnSuccess: true,
      removeOnConflict: false,
      // FIX 3: remove skipped operations immediately — they are already logged
      // in the audit log (_AppAuditLogger) so removing them prevents unnecessary
      // retries up to maxRetries and keeps the dead-letter queue clean.
      removeOnSkipped: true,
    );
  }

  /// Find a sale order line by UUID using searchLocal domain filter
  Future<SaleOrderLine?> _findLineByUuid(String uuid) async {
    final results = await _lineManager.searchLocal(
      domain: [['line_uuid', '=', uuid]],
      limit: 1,
    );
    return results.isNotEmpty ? results.first : null;
  }

  /// Update local UUID-based line with its remote Odoo ID after sync
  Future<void> _updateLineRemoteIdByUuid(String uuid, int remoteId) async {
    final existingLine = await _findLineByUuid(uuid);
    if (existingLine == null) {
      logger.w(
        '[OfflineSyncService]',
        'Cannot update remote ID: line UUID $uuid not found',
      );
      return;
    }

    await _lineManager.deleteLocal(existingLine.id);
    final updatedLine = existingLine.copyWith(
      id: remoteId,
      isSynced: true,
      lastSyncDate: DateTime.now().toUtc(),
    );
    await _lineManager.upsertLocal(updatedLine);
    logger.d(
      '[OfflineSyncService]',
      'Updated line UUID $uuid with Odoo ID: $remoteId',
    );
  }

  /// Dispose resources
  void dispose() {
    _processor.dispose();
  }

  /// Stream of sync progress events
  Stream<SyncProgressEvent> get progressStream => _processor.progressStream;

  /// Check if currently syncing
  bool get isSyncing => _isSyncing;

  /// Check if we have connection to sync
  bool get canSync => _odooClient != null;

  /// Get pending operation count
  Future<int> getPendingCount() => _offlineQueue.getPendingCount();

  Future<void> _logOperation(
    OfflineOperation op, {
    required String result,
    int? odooId,
    String? errorMessage,
  }) async {
    await _db.logSyncOperation(
      model: op.model,
      method: op.method,
      odooId: odooId ?? op.recordId,
      localId: op.values['local_id'] as int?,
      recordUuid:
          (op.values['uuid'] ?? op.values['_uuid'] ?? op.values['order_uuid'])
              as String?,
      deviceId: op.deviceId,
      createdOfflineAt: op.createdAt,
      result: result,
      errorMessage: errorMessage,
      metadata: {'op_id': op.id, 'priority': op.priority},
    );
  }

  /// Complete an operation with audit logging
  Future<void> _completeOperationWithAudit(
    OfflineOperation op, {
    required String result,
    int? odooId,
    String? errorMessage,
  }) async {
    await _logOperation(
      op,
      result: result,
      odooId: odooId,
      errorMessage: errorMessage,
    );

    // Remove from queue only on success
    if (result == 'success') {
      await _offlineQueue.removeOperation(op.id);
    }
  }

  /// Process all pending operations in the queue
  ///
  /// Returns [SyncResult] with count of successful and failed operations.
  /// Operations are processed in FIFO order (oldest first).
  Future<SyncResult> processQueue() async {
    if (_odooClient == null) {
      logger.w('[OfflineSyncService]', 'Cannot sync: no Odoo connection');
      return SyncResult.noConnection;
    }

    if (_isSyncing) {
      logger.d('[OfflineSyncService]', 'Sync already in progress');
      return SyncResult.empty;
    }

    _isSyncing = true;
    try {
      final queueResult = await _processor.processQueue();
      if (queueResult.isEmpty) {
        logger.d('[OfflineSyncService]', 'No pending operations to sync');
      } else {
        logger.i(
          '[OfflineSyncService]',
          'Sync complete: ${queueResult.synced} success, ${queueResult.failed} failed, ${queueResult.conflicts.length} conflicts, ${queueResult.skipped} skipped',
        );
      }
      return SyncResult.fromQueueResult(queueResult);
    } finally {
      _isSyncing = false;
    }
  }

  /// Process only operations for a specific sale order (order + its lines)
  ///
  /// Syncs in FIFO order only operations belonging to this order.
  /// This method owns the [_isSyncing] guard; the actual work is delegated
  /// to `_processSaleOrderQueueInternal` (offline_sync_sale_order.dart) so
  /// that on-the-fly enqueue + retry never manipulates the flag directly
  /// (FIX 2).
  ///
  /// NOTA: este método (y [processModelQueue]) se quedan acá, en la clase
  /// concreta, en vez de en `offline_sync_sale_order.dart` como el resto del
  /// dominio de sale.order — son API pública consumida desde otros
  /// archivos/librerías que NO importan `offline_sync_service.dart`
  /// directamente (solo obtienen la instancia vía
  /// `offlineSyncServiceProvider`). Una `extension` (aunque sea pública) NO
  /// resuelve en esos call-sites; un método de instancia normal sí. Ver el
  /// comentario completo en `offline_sync_sale_order.dart`.
  Future<SyncResult> processSaleOrderQueue(int orderId) async {
    if (_odooClient == null) {
      logger.w('[OfflineSyncService]', 'Cannot sync: no Odoo connection');
      return SyncResult.noConnection;
    }

    if (_isSyncing) {
      logger.d('[OfflineSyncService]', 'Sync already in progress');
      return SyncResult.empty;
    }

    _isSyncing = true;
    _lastInvoiceCreated = null; // Reset for new sync session
    try {
      // Fase B, tarea 4: este path despacha operaciones directamente (su
      // propio loop, sin pasar por OfflineQueueProcessor) — comparte el
      // MISMO lock global de proceso que usa `processQueue()`/
      // `processModelQueue()` (vía OfflineQueueProcessor.runExclusive) para
      // que una segunda instancia de OfflineSyncService (ej. tras invalidar
      // offlineSyncServiceProvider mientras esta sync sigue en curso) no
      // pueda tomar las MISMAS operaciones de sale.order/sale.order.line y
      // reenviarlas en paralelo a Odoo. El guard `_isSyncing` de arriba solo
      // protege esta instancia; el lock global protege contra CUALQUIER
      // instancia del proceso.
      return await OfflineQueueProcessor.runExclusive(
        () => _processSaleOrderQueueInternal(orderId),
      );
    } finally {
      _isSyncing = false;
    }
  }

  /// Process only operations for a specific model
  Future<SyncResult> processModelQueue(String model) async {
    if (_odooClient == null) {
      return SyncResult.noConnection;
    }

    if (_isSyncing) {
      return SyncResult.empty;
    }

    _isSyncing = true;
    try {
      final operations = await _offlineQueue.getOperationsForModel(model);

      if (operations.isEmpty) {
        return SyncResult.empty;
      }

      logger.i(
        '[OfflineSyncService]',
        'Processing ${operations.length} $model operations',
      );
      final queueResult = await _processor.processQueue(operations: operations);
      return SyncResult.fromQueueResult(queueResult, model: model);
    } finally {
      _isSyncing = false;
    }
  }

  /// Get retry statistics from the queue
  Future<Map<String, dynamic>> getRetryStats() => _offlineQueue.getRetryStats();

  /// Get dead letter operations (exceeded max retries)
  Future<List<OfflineOperation>> getDeadLetterOperations() =>
      _offlineQueue.getDeadLetterOperations();

  /// Reset retry count for an operation (for manual retry)
  Future<void> resetOperationRetry(int operationId) =>
      _offlineQueue.resetOperationRetry(operationId);

  /// Remove operation from dead letter queue (give up)
  Future<void> removeDeadLetterOperation(int operationId) =>
      _offlineQueue.removeOperation(operationId);

  /// Process a single operation based on its method type
  /// Returns ConflictInfo if there's a conflict (only for write operations)
  Future<ConflictInfo?> _processOperation(OfflineOperation op) async {
    switch (op.method) {
      case 'create':
        await _processCreate(op);
        return null;
      case 'write':
        return await _processWrite(op);
      case 'unlink':
        await _processUnlink(op);
        return null;
      // Collection session specific actions
      case 'session_create_and_open':
        await _processSessionCreateAndOpen(op);
        return null;
      case 'session_open':
        await _processSessionOpen(op);
        return null;
      case 'session_closing_control':
        await _processSessionClosingControl(op);
        return null;
      case 'session_close':
        await _processSessionClose(op);
        return null;
      // Payment operations
      case 'payment_create':
        await _processPaymentCreate(op);
        return null;
      // Partner operations
      case 'partner_create':
        await _processPartnerCreate(op);
        return null;
      // Sale order operations
      case 'order_confirm':
        await _processOrderConfirm(op);
        return null;
      // Sale order state actions (offline-first) - with conflict detection
      // Only route to order-specific handler for sale.order model
      case 'action_lock':
      case 'action_unlock':
      case 'action_confirm':
      case 'action_pos_confirm':
      case 'action_cancel':
      case 'action_draft':
        if (op.model == 'sale.order') {
          return await _processOrderStateAction(op);
        }
        // For other models (account.advance, l10n_ec.cash.out, etc.)
        // use the generic action handler
        return await _processGenericAction(op);
      // Generic action methods that work on any model
      case 'action_post':
      case 'action_return':
        return await _processGenericAction(op);
      // Invoice creation with payments (offline-first)
      case 'invoice_create_with_payments':
        await _processInvoiceWithPayments(op);
        return null;
      // SRI Offline Invoice Sync
      case 'invoice_create_offline':
        await _processSyncOfflineInvoice(op);
        return null;
      default:
        // For unknown action_* methods, use generic handler instead of dropping
        if (op.method.startsWith('action_')) {
          logger.i(
            '[OfflineSyncService]',
            'Using generic action handler for ${op.model}.${op.method} (op ${op.id})',
          );
          return await _processGenericAction(op);
        }
        logger.w(
          '[OfflineSyncService]',
          'Unknown method: ${op.method} for model ${op.model} (op ${op.id}) - operation will be retried',
        );
        throw Exception(
          'Unknown offline sync method: ${op.model}.${op.method} (op ${op.id})',
        );
    }
  }

}

class _AppAuditLogger implements OfflineQueueAuditLogger {
  final DatabaseHelper _db;

  _AppAuditLogger(this._db);

  @override
  Future<void> logOperation(
    OfflineOperation op, {
    required String result,
    int? odooId,
    String? errorMessage,
  }) async {
    await _db.logSyncOperation(
      model: op.model,
      method: op.method,
      odooId: odooId ?? op.recordId,
      localId: op.values['local_id'] as int?,
      recordUuid:
          (op.values['uuid'] ?? op.values['_uuid'] ?? op.values['order_uuid'])
              as String?,
      deviceId: op.deviceId,
      createdOfflineAt: op.createdAt,
      result: result,
      errorMessage: errorMessage,
      metadata: {'op_id': op.id, 'priority': op.priority},
    );
  }
}
