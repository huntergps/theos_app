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
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase, AccountPaymentManager, SaleOrderLine, SaleOrderLineManager, SaleOrderLineManagerBusiness, saleOrderLineManager, SaleOrderManager, SaleOrderManagerBusiness, saleOrderManager, ClientManagerBusiness, clientManager, CollectionSessionManager, CollectionSessionManagerBusiness, SaleOrderPaymentLineCompanion;
import '../../../core/database/database_helper.dart';
import '../../../core/database/datasources/datasources.dart';

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
      removeOnSkipped: false,
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

  /// Process a CREATE operation
  ///
  /// Creates the record in Odoo, then updates the local database
  /// with the real Odoo ID.
  ///
  /// For sale.order, reads current local order values to ensure
  /// any updates made after the operation was queued are included.
  Future<void> _processCreate(OfflineOperation op) async {
    // Extract local_id and uuid from values (support both 'uuid' and '_uuid' keys)
    // For sale.order, the local_id might be stored in recordId (negative number)
    int? localId = op.values['local_id'] as int?;
    if (localId == null && op.recordId != null && op.recordId! < 0) {
      // Use recordId as localId for orders created offline
      localId = op.recordId;
    }
    final uuid = (op.values['uuid'] ?? op.values['_uuid']) as String?;

    // Prepare values for Odoo (remove local-only fields)
    Map<String, dynamic> odooValues = Map<String, dynamic>.from(op.values)
      ..remove('local_id')
      ..remove('uuid')
      ..remove('_uuid');

    // For sale.order, read current local values to get any updates made after queue
    if (op.model == 'sale.order' && localId != null) {
      final localOrder = await _orderManager.getSaleOrder(localId);
      if (localOrder != null) {
        // Validate order before syncing
        final validationError = await _validateOrderForSync(localOrder);
        if (validationError != null) {
          throw Exception(validationError);
        }

        // Use current local values (override stale queued values)
        odooValues = {
          'partner_id': localOrder.partnerId,
          if (localOrder.warehouseId != null)
            'warehouse_id': localOrder.warehouseId,
          if (localOrder.pricelistId != null)
            'pricelist_id': localOrder.pricelistId,
          if (localOrder.paymentTermId != null)
            'payment_term_id': localOrder.paymentTermId,
          if (localOrder.userId != null) 'user_id': localOrder.userId,
          // Final consumer fields
          if (localOrder.isFinalConsumer) 'is_final_consumer': true,
          if (localOrder.endCustomerName != null &&
              localOrder.endCustomerName!.isNotEmpty)
            'end_customer_name': localOrder.endCustomerName,
          if (localOrder.endCustomerPhone != null &&
              localOrder.endCustomerPhone!.isNotEmpty)
            'end_customer_phone': localOrder.endCustomerPhone,
          if (localOrder.endCustomerEmail != null &&
              localOrder.endCustomerEmail!.isNotEmpty)
            'end_customer_email': localOrder.endCustomerEmail,
          // Referrer
          if (localOrder.referrerId != null)
            'referrer_id': localOrder.referrerId,
          // Note / commitment date
          if (localOrder.note != null && localOrder.note!.isNotEmpty)
            'note': localOrder.note,
          if (localOrder.commitmentDate != null)
            'commitment_date': localOrder.commitmentDate!.toIso8601String(),
        };

        logger.d(
          '[OfflineSyncService]',
          'Using current local values for order $localId: isFinalConsumer=${localOrder.isFinalConsumer}, '
              'endCustomerName=${localOrder.endCustomerName}, referrerId=${localOrder.referrerId}',
        );
      }
    }

    // Add x_uuid for tracking
    if (uuid != null) {
      odooValues['x_uuid'] = uuid;
    }

    logger.d(
      '[OfflineSyncService]',
      'Creating ${op.model} with uuid=$uuid, localId=$localId',
    );

    final remoteId = await _odooClient!.create(
      model: op.model,
      values: odooValues,
    );

    if (remoteId != null && localId != null) {
      // Update local record with remote ID based on model type
      if (op.model == 'sale.order') {
        await _orderManager.updateSaleOrderRemoteId(localId, remoteId);
        logger.d(
          '[OfflineSyncService]',
          'Updated local order $localId -> remote $remoteId',
        );

        // Also update order_id in pending line operations in the queue
        await _offlineQueue.updateOrderIdInPendingOperations(localId, remoteId);

        // Remove any pending write operations for this order since we already included all values
        await _offlineQueue.removePendingWritesForOrder(localId);
      } else if (op.model == 'sale.order.line') {
        await _updateLineRemoteIdByUuid(uuid!, remoteId);
        logger.d(
          '[OfflineSyncService]',
          'Updated local line $uuid -> remote $remoteId',
        );
      }
    }
  }

  /// Process a WRITE operation
  ///
  /// If we have a recordId, use it directly. Otherwise, look up by UUID.
  /// Returns ConflictInfo if there's a conflict, null otherwise.
  Future<ConflictInfo?> _processWrite(OfflineOperation op) async {
    final uuid = op.values['uuid'] as String?;

    // Prepare values for Odoo (remove uuid)
    final odooValues = Map<String, dynamic>.from(op.values)..remove('uuid');

    int? targetId = op.recordId;

    // If no recordId but we have UUID, look it up
    if (targetId == null && uuid != null && op.model == 'sale.order.line') {
      final line = await _findLineByUuid(uuid);
      if (line != null && line.id > 0) {
        targetId = line.id;
      }
    }

    if (targetId == null || targetId <= 0) {
      throw Exception(
        'Cannot write to ${op.model}: no valid remote ID (uuid=$uuid)',
      );
    }

    // Check for conflicts if we have baseWriteDate
    if (op.baseWriteDate != null) {
      final conflict = await _checkWriteConflict(op, targetId);
      if (conflict != null) {
        return conflict;
      }
    }

    logger.d(
      '[OfflineSyncService]',
      'Writing to ${op.model}[$targetId]: $odooValues',
    );

    final success = await _odooClient!.write(
      model: op.model,
      ids: [targetId],
      values: odooValues,
    );

    if (!success) {
      throw Exception('Write to ${op.model}[$targetId] returned false');
    }

    return null;
  }

  /// Check if server has newer version than our queued operation
  Future<ConflictInfo?> _checkWriteConflict(
    OfflineOperation op,
    int targetId,
  ) async {
    try {
      // Read current write_date from server
      final serverData = await _odooClient!.searchRead(
        model: op.model,
        domain: [
          ['id', '=', targetId],
        ],
        fields: ['write_date'],
        limit: 1,
      );

      if (serverData.isEmpty) {
        // Record doesn't exist on server anymore
        logger.w(
          '[OfflineSyncService]',
          '${op.model}[$targetId] not found on server',
        );
        return null;
      }

      final serverWriteDateStr = serverData[0]['write_date'] as String?;
      if (serverWriteDateStr == null) {
        return null;
      }

      final serverWriteDate = DateTime.parse(serverWriteDateStr);
      final localWriteDate = op.baseWriteDate!;

      // Server has been modified after our local change was queued
      if (serverWriteDate.isAfter(localWriteDate)) {
        logger.w(
          '[OfflineSyncService]',
          '⚠️ CONFLICT: ${op.model}[$targetId] - server: $serverWriteDate > local: $localWriteDate',
        );

        return ConflictInfo(
          operationId: op.id,
          model: op.model,
          recordId: targetId,
          localWriteDate: localWriteDate,
          serverWriteDate: serverWriteDate,
          localValues: op.values,
        );
      }

      return null;
    } catch (e) {
      logger.e(
        '[OfflineSyncService]',
        'Error checking conflict for ${op.model}[$targetId]: $e',
      );
      // If we can't check, proceed without conflict detection
      return null;
    }
  }

  /// Process an UNLINK operation
  ///
  /// Throws [OperationSkippedException] if the record doesn't exist
  Future<void> _processUnlink(OfflineOperation op) async {
    if (op.recordId == null || op.recordId! <= 0) {
      // Record was never synced, nothing to delete on server
      throw OperationSkippedException(
        '${op.model}: sin ID remoto (registro local no sincronizado)',
      );
    }

    logger.d('[OfflineSyncService]', 'Unlinking ${op.model}[${op.recordId}]');

    try {
      final success = await _odooClient!.unlink(
        model: op.model,
        ids: [op.recordId!],
      );

      if (!success) {
        throw Exception('Unlink ${op.model}[${op.recordId}] returned false');
      }
    } catch (e) {
      // If record doesn't exist, throw skipped exception
      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('does not exist') ||
          errorStr.contains('has been deleted') ||
          errorStr.contains('missing record')) {
        throw OperationSkippedException(
          '${op.model}[${op.recordId}] ya no existe en Odoo',
        );
      }
      rethrow; // Other errors should still fail
    }
  }

  /// Process only operations for a specific sale order (order + its lines)
  ///
  /// Syncs in FIFO order only operations belonging to this order.
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
    int success = 0;
    int failed = 0;
    int skipped = 0;
    final errors = <String>[];
    final conflicts = <ConflictInfo>[];

    try {
      final operations = await _offlineQueue.getOperationsForSaleOrder(orderId);

      if (operations.isEmpty) {
        logger.d(
          '[OfflineSyncService]',
          'No pending operations for order $orderId - checking if order needs sync',
        );

        // Check if order exists locally and needs sync
        final localOrder = await _orderManager.getSaleOrder(orderId);
        if (localOrder != null && !localOrder.isSynced && orderId < 0) {
          // Validate order before syncing
          final validationError = await _validateOrderForSync(localOrder);
          if (validationError != null) {
            logger.w(
              '[OfflineSyncService]',
              'Order $orderId validation failed: $validationError',
            );
            return SyncResult(
              model: 'sale.order',
              status: SyncStatus.error,
              synced: 0,
              failed: 1,
              error: validationError,
              timestamp: DateTime.now(),
            );
          }

          // Order exists locally but has no queue operations - create one on-the-fly
          logger.i(
            '[OfflineSyncService]',
            'Creating sync operation on-the-fly for order $orderId',
          );

          await _offlineQueue.queueOperation(
            model: 'sale.order',
            method: 'create',
            recordId: orderId,
            values: {
              'partner_id': localOrder.partnerId,
              if (localOrder.warehouseId != null)
                'warehouse_id': localOrder.warehouseId,
              if (localOrder.pricelistId != null)
                'pricelist_id': localOrder.pricelistId,
              if (localOrder.paymentTermId != null)
                'payment_term_id': localOrder.paymentTermId,
              // Campos de consumidor final
              if (localOrder.isFinalConsumer) 'is_final_consumer': true,
              if (localOrder.endCustomerName != null)
                'end_customer_name': localOrder.endCustomerName,
              if (localOrder.endCustomerPhone != null)
                'end_customer_phone': localOrder.endCustomerPhone,
              if (localOrder.endCustomerEmail != null)
                'end_customer_email': localOrder.endCustomerEmail,
              '_uuid': localOrder.orderUuid ?? '',
            },
          );

          // Also queue any unsynced lines for this order
          final lines = await _lineManager.getSaleOrderLines(orderId);
          for (final line in lines) {
            if (!line.isSynced) {
              await _offlineQueue.queueOperation(
                model: 'sale.order.line',
                method: 'create',
                values: {
                  'uuid': line.lineUuid ?? '',
                  'local_id': line.id,
                  'order_id': orderId,
                  'product_id': line.productId,
                  'name': line.name,
                  'product_uom_qty': line.productUomQty,
                  'price_unit': line.priceUnit,
                  'discount': line.discount,
                  if (line.productUomId != null)
                    'product_uom_id': line.productUomId,
                },
                parentOrderId: orderId,
              );
            }
          }

          // Recursively process now that operations are queued
          _isSyncing = false;
          return await processSaleOrderQueue(orderId);
        }

        return SyncResult.empty;
      }

      logger.i(
        '[OfflineSyncService]',
        'Processing ${operations.length} operations for order $orderId',
      );

      // Log all operation models for debugging
      final modelCounts = <String, int>{};
      for (final op in operations) {
        modelCounts[op.model] = (modelCounts[op.model] ?? 0) + 1;
      }
      logger.d('[OfflineSyncService]', 'Operation models: $modelCounts');

      // Separate operations by type:
      // 1. sale.order operations first
      // 2. sale.order.line operations second
      // 3. All other operations (payments, withholds, etc.) last
      var orderOps = operations
          .where((op) => op.model == 'sale.order')
          .toList();
      var lineOps = operations
          .where((op) => op.model == 'sale.order.line')
          .toList();
      final otherOps = operations
          .where(
            (op) => op.model != 'sale.order' && op.model != 'sale.order.line',
          )
          .toList();

      // If there are no order create operations but we have other operations
      // that reference this order (payments, etc.), check if order needs to be created first
      if (orderOps.isEmpty && otherOps.isNotEmpty && orderId < 0) {
        final localOrder = await _orderManager.getSaleOrder(orderId);
        if (localOrder != null && !localOrder.isSynced) {
          logger.i(
            '[OfflineSyncService]',
            'Order $orderId has pending operations but no create operation. '
                'Creating order sync operation first.',
          );

          // Queue order create operation
          final opId = await _offlineQueue.queueOperation(
            model: 'sale.order',
            method: 'create',
            recordId: orderId,
            values: {
              'partner_id': localOrder.partnerId,
              if (localOrder.warehouseId != null)
                'warehouse_id': localOrder.warehouseId,
              if (localOrder.pricelistId != null)
                'pricelist_id': localOrder.pricelistId,
              if (localOrder.paymentTermId != null)
                'payment_term_id': localOrder.paymentTermId,
              if (localOrder.isFinalConsumer) 'is_final_consumer': true,
              if (localOrder.endCustomerName != null)
                'end_customer_name': localOrder.endCustomerName,
              if (localOrder.endCustomerPhone != null)
                'end_customer_phone': localOrder.endCustomerPhone,
              if (localOrder.endCustomerEmail != null)
                'end_customer_email': localOrder.endCustomerEmail,
              '_uuid': localOrder.orderUuid ?? '',
              'local_id': orderId,
            },
          );

          // Reload orderOps with the new operation
          final newOp = await _offlineQueue.getOperationById(opId);
          if (newOp != null) {
            orderOps = [newOp];
            logger.d(
              '[OfflineSyncService]',
              'Added order create operation (id=$opId) to sync queue',
            );
          }

          // Also queue lines if they're not synced
          final lines = await _lineManager.getSaleOrderLines(orderId);
          for (final line in lines) {
            if (!line.isSynced) {
              await _offlineQueue.queueOperation(
                model: 'sale.order.line',
                method: 'create',
                values: {
                  'uuid': line.lineUuid ?? '',
                  'local_id': line.id,
                  'order_id': orderId,
                  'product_id': line.productId,
                  'name': line.name,
                  'product_uom_qty': line.productUomQty,
                  'price_unit': line.priceUnit,
                  'discount': line.discount,
                  if (line.productUomId != null)
                    'product_uom_id': line.productUomId,
                },
                parentOrderId: orderId,
              );
            }
          }

          // Reload line operations
          lineOps = await _offlineQueue.getOperationsForModel('sale.order.line');
          lineOps = lineOps
              .where((op) => op.parentOrderId == orderId)
              .toList();
        }
      }

      // Track if order was synced successfully and the new ID
      int? newOrderId;
      bool orderSyncFailed = false;

      // Process order operations first
      for (final op in orderOps) {
        try {
          final conflict = await _processOperation(op);
          if (conflict != null) {
            conflicts.add(conflict);
            await _completeOperationWithAudit(op, result: 'conflict');
            logger.w(
              '[OfflineSyncService]',
              'Conflict for operation ${op.id}: ${op.model}.${op.method}',
            );
            orderSyncFailed = true;
          } else {
            await _completeOperationWithAudit(op, result: 'success');
            success++;
            logger.d(
              '[OfflineSyncService]',
              'Synced operation ${op.id}: ${op.model}.${op.method}',
            );
            // Get the new order ID from the database
            final syncedOrder = await _orderManager.getSaleOrderByUuid(
              op.values['_uuid'] as String? ?? '',
            );
            if (syncedOrder != null && syncedOrder.id > 0) {
              newOrderId = syncedOrder.id;
              logger.d(
                '[OfflineSyncService]',
                'Order synced with new ID: $newOrderId',
              );
            }
          }
        } catch (e) {
          failed++;
          final errorMsg = 'Op ${op.id} (${op.model}.${op.method}): $e';
          errors.add(errorMsg);
          await _completeOperationWithAudit(
            op,
            result: 'error',
            errorMessage: e.toString(),
          );
          logger.e('[OfflineSyncService]', 'Failed to sync: $errorMsg');
          orderSyncFailed = true;
        }
      }

      // If order sync failed, don't process lines
      if (orderSyncFailed) {
        logger.w(
          '[OfflineSyncService]',
          'Order sync failed, skipping ${lineOps.length} line operations',
        );
        // Mark line operations as skipped (will retry when order succeeds)
        for (final op in lineOps) {
          await _offlineQueue.markOperationFailed(
            op.id,
            'Order sync failed, line operation pending',
          );
        }
      } else {
        // Reload line operations from DB to get updated order_id
        if (newOrderId != null) {
          lineOps = await _offlineQueue.getOperationsForModel(
            'sale.order.line',
          );
          lineOps = lineOps
              .where(
                (op) =>
                    op.parentOrderId == newOrderId ||
                    op.parentOrderId == orderId,
              )
              .toList();
          logger.d(
            '[OfflineSyncService]',
            'Reloaded ${lineOps.length} line operations with updated order_id',
          );
        }

        // Process line operations
        for (final op in lineOps) {
          try {
            final conflict = await _processOperation(op);
            if (conflict != null) {
              conflicts.add(conflict);
              await _completeOperationWithAudit(op, result: 'conflict');
              logger.w(
                '[OfflineSyncService]',
                'Conflict for operation ${op.id}: ${op.model}.${op.method}',
              );
            } else {
              await _completeOperationWithAudit(op, result: 'success');
              success++;
              logger.d(
                '[OfflineSyncService]',
                'Synced operation ${op.id}: ${op.model}.${op.method}',
              );
            }
          } catch (e) {
            failed++;
            final errorMsg = 'Op ${op.id} (${op.model}.${op.method}): $e';
            errors.add(errorMsg);
            await _completeOperationWithAudit(
              op,
              result: 'error',
              errorMessage: e.toString(),
            );
            logger.e('[OfflineSyncService]', 'Failed to sync: $errorMsg');
          }
        }

        // Process other operations (payments, withholds, wizards, etc.)
        if (otherOps.isNotEmpty) {
          logger.i(
            '[OfflineSyncService]',
            'Processing ${otherOps.length} other operations (payments, withholds, etc.)',
          );

          for (final op in otherOps) {
            try {
              // Process based on model type
              await _processOtherModelOperation(op);
              await _completeOperationWithAudit(op, result: 'success');
              success++;
              logger.d(
                '[OfflineSyncService]',
                'Synced operation ${op.id}: ${op.model}.${op.method}',
              );
            } on OperationSkippedException catch (e) {
              // Operation was skipped (e.g., record doesn't exist)
              skipped++;
              await _completeOperationWithAudit(op, result: 'skipped');
              logger.w(
                '[OfflineSyncService]',
                'Skipped operation ${op.id}: $e',
              );
            } catch (e) {
              failed++;
              final errorMsg = 'Op ${op.id} (${op.model}.${op.method}): $e';
              errors.add(errorMsg);
              await _completeOperationWithAudit(
                op,
                result: 'error',
                errorMessage: e.toString(),
              );
              logger.e('[OfflineSyncService]', 'Failed to sync: $errorMsg');
            }
          }
        }
      }

      logger.i(
        '[OfflineSyncService]',
        'Order $orderId sync complete: $success success, $failed failed, $skipped skipped, ${conflicts.length} conflicts',
      );
    } finally {
      _isSyncing = false;
    }

    // Determine status based on results
    SyncStatus resultStatus;
    if (failed > 0) {
      resultStatus = success > 0 ? SyncStatus.partial : SyncStatus.error;
    } else {
      resultStatus = SyncStatus.success;
    }

    return SyncResult(
      model: 'sale.order',
      status: resultStatus,
      synced: success,
      failed: failed,
      error: errors.isNotEmpty ? errors.join('; ') : null,
      timestamp: DateTime.now(),
      conflicts: conflicts,
      extra: _lastInvoiceCreated != null
          ? {'invoiceCreated': _lastInvoiceCreated}
          : const {},
    );
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

  // =========================================================================
  // COLLECTION SESSION SYNC HANDLERS
  // =========================================================================

  /// Process session_create_and_open: Create session + call action_session_open
  ///
  /// Values expected:
  /// - config_id: int
  /// - user_id: int
  /// - cash_register_balance_start: double
  /// - session_uuid: String
  /// - local_id: int (negative ID)
  Future<void> _processSessionCreateAndOpen(OfflineOperation op) async {
    final localId = op.values['local_id'] as int?;
    final sessionUuid = op.values['session_uuid'] as String?;

    final odooValues = <String, dynamic>{
      'config_id': op.values['config_id'],
      'user_id': op.values['user_id'],
      'cash_register_balance_start': op.values['cash_register_balance_start'],
    };

    if (sessionUuid != null) {
      odooValues['session_uuid'] = sessionUuid;
    }

    logger.d(
      '[OfflineSyncService]',
      'Creating collection.session: uuid=$sessionUuid, localId=$localId',
    );

    // 1. Create session
    final remoteId = await _odooClient!.create(
      model: 'collection.session',
      values: odooValues,
    );

    if (remoteId == null) {
      throw Exception('Failed to create collection.session - returned null');
    }

    logger.d('[OfflineSyncService]', 'Session created: $remoteId, opening...');

    // 2. Open session
    await _odooClient.call(
      model: 'collection.session',
      method: 'action_session_open',
      ids: [remoteId],
    );

    logger.d('[OfflineSyncService]', 'Session $remoteId opened successfully');

    // 3. Update local session with remote ID
    if (localId != null && sessionUuid != null) {
      await _sessionManager.updateSessionIdByUuid(sessionUuid, remoteId);
      logger.d(
        '[OfflineSyncService]',
        'Updated local session $localId -> $remoteId',
      );
    }
  }

  /// Process session_open: Write cash + call action_session_open
  ///
  /// Values expected:
  /// - session_id: int
  /// - cash_register_balance_start: double
  Future<void> _processSessionOpen(OfflineOperation op) async {
    final sessionId = op.values['session_id'] as int;
    final cashAmount = op.values['cash_register_balance_start'] as double;

    logger.d(
      '[OfflineSyncService]',
      'Opening session $sessionId with cash=$cashAmount',
    );

    // 1. Write cash balance
    final writeResult = await _odooClient!.write(
      model: 'collection.session',
      ids: [sessionId],
      values: {'cash_register_balance_start': cashAmount},
    );

    if (!writeResult) {
      throw Exception('Failed to write cash_register_balance_start');
    }

    // 2. Open session
    await _odooClient.call(
      model: 'collection.session',
      method: 'action_session_open',
      ids: [sessionId],
    );

    logger.d('[OfflineSyncService]', 'Session $sessionId opened successfully');
  }

  /// Process session_closing_control: Write closing cash + start closing control
  ///
  /// Values expected:
  /// - session_id: int
  /// - cash_register_balance_end_real: double
  Future<void> _processSessionClosingControl(OfflineOperation op) async {
    final sessionId = op.values['session_id'] as int;
    final cashAmount = op.values['cash_register_balance_end_real'] as double;

    logger.d(
      '[OfflineSyncService]',
      'Starting closing control for session $sessionId, cash=$cashAmount',
    );

    // 1. Write closing cash
    final writeResult = await _odooClient!.write(
      model: 'collection.session',
      ids: [sessionId],
      values: {'cash_register_balance_end_real': cashAmount},
    );

    if (!writeResult) {
      throw Exception('Failed to write cash_register_balance_end_real');
    }

    // 2. Start closing control
    await _odooClient.call(
      model: 'collection.session',
      method: 'action_session_closing_control',
      ids: [sessionId],
    );

    logger.d(
      '[OfflineSyncService]',
      'Closing control started for session $sessionId',
    );
  }

  /// Process session_close: Close the session
  ///
  /// Values expected:
  /// - session_id: int
  Future<void> _processSessionClose(OfflineOperation op) async {
    final sessionId = op.values['session_id'] as int;

    logger.d('[OfflineSyncService]', 'Closing session $sessionId');

    await _odooClient!.call(
      model: 'collection.session',
      method: 'action_session_close',
      ids: [sessionId],
    );

    logger.d('[OfflineSyncService]', 'Session $sessionId closed successfully');
  }

  // =========================================================================
  // ACCOUNT PAYMENT SYNC HANDLERS
  // =========================================================================

  /// Process account.payment CREATE operation
  ///
  /// Values expected:
  /// - local_id: int (negative ID)
  /// - payment_uuid: String
  /// - collection_session_id: int
  /// - partner_id: int
  /// - journal_id: int
  /// - payment_method_line_id: int
  /// - amount: double
  /// - payment_type: String
  /// - payment_origin_type: String
  /// - date: String (ISO format)
  /// - ref: String?
  Future<void> _processPaymentCreate(OfflineOperation op) async {
    final localId = op.values['local_id'] as int?;
    final paymentUuid = op.values['payment_uuid'] as String?;

    // Build Odoo values
    final odooValues = <String, dynamic>{
      'collection_session_id': op.values['collection_session_id'],
      'partner_id': op.values['partner_id'],
      'journal_id': op.values['journal_id'],
      'payment_method_line_id': op.values['payment_method_line_id'],
      'amount': op.values['amount'],
      'payment_type': op.values['payment_type'] ?? 'inbound',
      'payment_origin_type': op.values['payment_origin_type'],
      'date': op.values['date'],
    };

    if (op.values['ref'] != null) {
      odooValues['ref'] = op.values['ref'];
    }

    if (paymentUuid != null) {
      odooValues['payment_uuid'] = paymentUuid;
    }

    logger.d(
      '[OfflineSyncService]',
      'Creating account.payment: uuid=$paymentUuid, localId=$localId',
    );

    final remoteId = await _odooClient!.create(
      model: 'account.payment',
      values: odooValues,
    );

    if (remoteId == null) {
      throw Exception('Failed to create account.payment - returned null');
    }

    logger.d('[OfflineSyncService]', 'Payment created: $remoteId');

    // Update local payment with remote ID
    if (localId != null && paymentUuid != null) {
      await _updatePaymentIdByUuid(paymentUuid, remoteId);
      logger.d(
        '[OfflineSyncService]',
        'Updated local payment $localId -> $remoteId',
      );
    }
  }

  /// Process invoice creation with payments (offline-first)
  ///
  /// Creates a payment wizard and executes action_apply_and_create_invoice.
  /// This is used when the user saves and creates invoice while offline.
  ///
  /// Values expected:
  /// - sale_id: int (sale order ID)
  /// - collection_session_id: int? (optional)
  /// - payment_lines: List<Map> with payment line data
  ///
  /// Returns the created invoice ID if successful.
  Future<int?> _processInvoiceWithPayments(OfflineOperation op) async {
    final saleId = op.values['sale_id'] as int?;
    final collectionSessionId = op.values['collection_session_id'] as int?;
    final paymentLines = op.values['payment_lines'] as List?;

    if (saleId == null) {
      throw Exception('sale_id is required for invoice_create_with_payments');
    }

    logger.d(
      '[OfflineSyncService]',
      'Creating invoice with payments for sale $saleId',
    );

    // Prepare line values for wizard
    final lineVals = (paymentLines ?? []).map((line) {
      final lineMap = line as Map<String, dynamic>;
      return [0, 0, lineMap];
    }).toList();

    // Create the payment wizard
    final wizardId = await _odooClient!.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'sale_id': saleId,
            if (collectionSessionId != null)
              'collection_session_id': collectionSessionId,
            'line_ids': lineVals,
          },
        ],
      },
    );

    if (wizardId == null) {
      throw Exception('Failed to create payment wizard');
    }

    // Execute action_apply_and_create_invoice
    final actualId = wizardId is List ? wizardId[0] : wizardId;
    final result = await _odooClient.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'action_apply_and_create_invoice',
      kwargs: {
        'ids': [actualId],
      },
    );

    logger.i(
      '[OfflineSyncService]',
      'Invoice created for sale $saleId: $result',
    );

    // Update local order state if needed
    int? invoiceId;
    if (result is Map && result.containsKey('res_id')) {
      invoiceId = result['res_id'] as int?;
      if (invoiceId != null) {
        // Mark local payments as synced
        await _markOrderPaymentsAsSynced(saleId);
        // Store for result feedback
        _lastInvoiceCreated = invoiceId;
        logger.d(
          '[OfflineSyncService]',
          'Marked payments as synced for sale $saleId, invoice $invoiceId',
        );
      }
    }
    return invoiceId;
  }

  /// Process SRI Offline Invoice Sync
  ///
  /// Sends the pre-generated offline invoice data (Access Key, Name, etc.) to Odoo.
  /// Requires the order to be already synced (to have a remote ID).
  ///
  /// Values expected:
  /// - order_local_id: int
  /// - order_uuid: String
  /// - access_key: String
  /// - invoice_name: String
  /// - invoice_date: String
  /// - amount_total: double
  Future<void> _processSyncOfflineInvoice(OfflineOperation op) async {
    final orderLocalId = op.values['order_local_id'] as int?;
    final orderUuid = op.values['order_uuid'] as String?;
    final accessKey = op.values['access_key'] as String?;
    final invoiceName = op.values['invoice_name'] as String?;

    if (orderLocalId == null || accessKey == null) {
      throw Exception('Missing required fields for offline invoice sync');
    }

    logger.d(
      '[OfflineSyncService]',
      'Syncing offline invoice $invoiceName (Key: $accessKey) for order $orderLocalId',
    );

    // 1. Resolve Remote Order ID
    int? remoteOrderId;
    // Check if local order has been updated with remote ID
    final order = await _orderManager.getSaleOrder(orderLocalId);
    if (order != null && order.isSynced) {
      remoteOrderId = order.id;
    } else if (orderUuid != null) {
      // Try to find by UUID in case ID link is missing
      final syncedOrder = await _orderManager.getSaleOrderByUuid(orderUuid);
      if (syncedOrder != null && syncedOrder.id > 0) {
        remoteOrderId = syncedOrder.id;
      }
    }

    if (remoteOrderId == null || remoteOrderId <= 0) {
      // Order not synced yet. Throw exception to retry later.
      // Since FIFO applies, this should happen rarely if queued after order sync.
      throw Exception(
        'Order $orderLocalId not yet synced to Odoo. Cannot sync invoice.',
      );
    }

    // 2. Call Odoo Method
    // We assume 'account.move' has a method 'action_sync_offline_invoice'
    // Payload:
    // - order_id: Remote Order ID
    // - access_key: SRI Access Key
    // - invoice_number: '001-001-000000001'
    // - invoice_date: '2023-10-25'
    // - amount_total: 100.0 (optional validation)
    final result = await _odooClient!.call(
      model: 'account.move',
      method: 'action_sync_offline_invoice',
      kwargs: {
        'vals': {
          'order_id': remoteOrderId,
          'access_key': accessKey,
          'invoice_number': invoiceName,
          'invoice_date': op.values['invoice_date'],
          'amount_total': op.values['amount_total'],
        },
      },
    );

    if (result == null || result == false) {
      throw Exception(
        'Failed to sync offline invoice (Odoo returned false/null)',
      );
    }

    logger.i(
      '[OfflineSyncService]',
      'Successfully synced offline invoice $invoiceName. Result: $result',
    );

    // Optional: Update OfflineInvoice table status to 'synced' here if needed.
    // For now, removing from queue is sufficient.
  }

  // =========================================================================
  // RES.PARTNER SYNC HANDLERS
  // =========================================================================

  /// Process res.partner CREATE operation
  ///
  /// Values expected:
  /// - local_id: int (negative ID)
  /// - partner_uuid: String
  /// - name: String
  /// - vat: String?
  /// - email: String?
  /// - phone: String?
  /// - mobile: String?
  /// - street: String?
  /// - city: String?
  /// - country_id: int?
  ///
  /// VAT Uniqueness Check:
  /// Before creating in Odoo, checks if a partner with the same VAT already exists.
  /// If found, links to existing partner instead of creating a duplicate.
  /// This replicates l10n_ec_base._check_vat_uniqueness behavior.
  Future<void> _processPartnerCreate(OfflineOperation op) async {
    final localId = op.values['local_id'] as int?;
    final partnerUuid = op.values['partner_uuid'] as String?;
    final vat = op.values['vat'] as String?;

    logger.d(
      '[OfflineSyncService]',
      'Processing partner create: uuid=$partnerUuid, localId=$localId, vat=$vat',
    );

    // Check if partner with same VAT already exists in Odoo
    // This handles the case where:
    // - Partner was created offline with VAT "1234567890001"
    // - While offline, someone else created the same partner in Odoo
    // - When syncing, we should link to existing instead of failing with duplicate VAT error
    if (vat != null && vat.isNotEmpty) {
      try {
        final existingInOdoo = await _odooClient!.searchRead(
          model: 'res.partner',
          domain: [
            ['vat', '=', vat],
          ],
          fields: ['id', 'name'],
          limit: 1,
        );

        if (existingInOdoo.isNotEmpty) {
          final existingId = existingInOdoo[0]['id'] as int;
          final existingName = existingInOdoo[0]['name'] as String?;

          logger.d(
            '[OfflineSyncService]',
            'Partner with VAT $vat already exists in Odoo: id=$existingId, name=$existingName. '
                'Linking to existing instead of creating.',
          );

          // Update local partner with existing Odoo ID
          if (partnerUuid != null) {
            await clientManager.updatePartnerIdByUuid(partnerUuid, existingId);
            logger.d(
              '[OfflineSyncService]',
              'Linked local partner (uuid=$partnerUuid) to existing Odoo partner: $existingId',
            );
          }

          // Success - no need to create, partner already exists
          return;
        }
      } catch (e) {
        logger.w(
          '[OfflineSyncService]',
          'Could not check VAT existence in Odoo, proceeding with create: $e',
        );
        // Continue with create attempt - Odoo will validate
      }
    }

    // Build Odoo values
    final odooValues = <String, dynamic>{'name': op.values['name']};

    if (vat != null) {
      odooValues['vat'] = vat;
    }
    if (op.values['email'] != null) {
      odooValues['email'] = op.values['email'];
    }
    if (op.values['phone'] != null) {
      odooValues['phone'] = op.values['phone'];
    }
    if (op.values['mobile'] != null) {
      odooValues['mobile'] = op.values['mobile'];
    }
    if (op.values['street'] != null) {
      odooValues['street'] = op.values['street'];
    }
    if (op.values['city'] != null) {
      odooValues['city'] = op.values['city'];
    }
    if (op.values['country_id'] != null) {
      odooValues['country_id'] = op.values['country_id'];
    }

    logger.d(
      '[OfflineSyncService]',
      'Creating res.partner: uuid=$partnerUuid, localId=$localId',
    );

    final remoteId = await _odooClient!.create(
      model: 'res.partner',
      values: odooValues,
    );

    if (remoteId == null) {
      throw Exception('Failed to create res.partner - returned null');
    }

    logger.d('[OfflineSyncService]', 'Partner created: $remoteId');

    // Update local partner with remote ID
    if (localId != null && partnerUuid != null) {
      await clientManager.updatePartnerIdByUuid(partnerUuid, remoteId);
      logger.d(
        '[OfflineSyncService]',
        'Updated local partner $localId -> $remoteId',
      );
    }
  }

  /// Process offline order confirmation
  ///
  /// Calls action_confirm on the order in Odoo and clears pendingConfirm flag
  ///
  /// Expected op.values:
  /// - order_uuid: String? (for orders created offline)
  /// - local_id: int (local order ID)
  Future<void> _processOrderConfirm(OfflineOperation op) async {
    final localId = op.values['local_id'] as int?;
    final orderUuid = op.values['order_uuid'] as String?;
    final odooId = op.recordId;

    logger.d(
      '[OfflineSyncService]',
      'Confirming sale.order: odooId=$odooId, uuid=$orderUuid, localId=$localId',
    );

    // Determine the actual Odoo ID to use
    int? actualOdooId = odooId;

    // If the order was created offline, we need to resolve UUID to Odoo ID
    if (actualOdooId == null && orderUuid != null) {
      final order = await _orderManager.getSaleOrderByUuid(orderUuid);
      if (order != null && order.id > 0) {
        actualOdooId = order.id;
        logger.d(
          '[OfflineSyncService]',
          'Resolved order UUID $orderUuid to Odoo ID $actualOdooId',
        );
      }
    }

    if (actualOdooId == null) {
      throw Exception(
        'Cannot confirm order - no Odoo ID available (uuid=$orderUuid, localId=$localId)',
      );
    }

    // Before confirming, sync any unsynced lines to Odoo
    // This handles the case where lines exist locally but were never synced
    final lookupOrderId = localId ?? actualOdooId;
    final localLines = await _lineManager.getSaleOrderLines(lookupOrderId);
    final unsyncedLines = localLines.where((l) => !l.isSynced).toList();

    if (unsyncedLines.isNotEmpty) {
      logger.i(
        '[OfflineSyncService]',
        'Found ${unsyncedLines.length} unsynced lines for order $actualOdooId - syncing before confirm',
      );

      for (final line in unsyncedLines) {
        try {
          final lineResult = await _odooClient!.call(
            model: 'sale.order.line',
            method: 'create',
            kwargs: {
              'vals_list': [
                {
                  'order_id': actualOdooId,
                  'product_id': line.productId,
                  'name': line.name,
                  'product_uom_qty': line.productUomQty,
                  'price_unit': line.priceUnit,
                  'discount': line.discount,
                  if (line.productUomId != null) 'product_uom': line.productUomId,
                },
              ],
            },
          );

          // Update local line as synced
          final newLineId = (lineResult is List && lineResult.isNotEmpty)
              ? lineResult[0] as int
              : lineResult as int?;

          if (newLineId != null && line.lineUuid != null) {
            await _updateLineRemoteIdByUuid(line.lineUuid!, newLineId);
            logger.d(
              '[OfflineSyncService]',
              'Synced line ${line.lineUuid} -> Odoo ID $newLineId',
            );
          }
        } catch (e) {
          logger.e(
            '[OfflineSyncService]',
            'Failed to sync line ${line.id} for order $actualOdooId: $e',
          );
          // Re-throw to fail the confirm operation
          rethrow;
        }
      }

      logger.i(
        '[OfflineSyncService]',
        'All ${unsyncedLines.length} lines synced for order $actualOdooId',
      );
    }

    // Call action_pos_confirm on Odoo (handles credit validation on server)
    await _odooClient!.call(
      model: 'sale.order',
      method: 'action_pos_confirm',
      ids: [actualOdooId],
    );

    logger.d('[OfflineSyncService]', 'Order $actualOdooId confirmed in Odoo');

    // Clear pendingConfirm flag on local order
    // Use localId if available (offline order), otherwise use the Odoo ID
    final orderIdToClear = localId ?? actualOdooId;
    await _orderManager.clearSaleOrderPendingConfirm(orderIdToClear);
  }

  /// Process offline order state actions (lock/unlock/confirm/cancel/draft)
  ///
  /// Calls the specified action method on the order in Odoo.
  /// Used for offline-first state changes that were queued for later sync.
  ///
  /// Returns [ConflictInfo] if the order was modified on the server after
  /// the operation was queued (based on write_date comparison).
  ///
  /// Expected op.values:
  /// - order_id: int (Odoo order ID)
  /// Process a generic action method on any model.
  ///
  /// This handles action_* methods (action_confirm, action_cancel, action_post,
  /// action_return, etc.) for models other than sale.order by calling the method
  /// directly on the correct model via the Odoo API.
  Future<ConflictInfo?> _processGenericAction(OfflineOperation op) async {
    final recordId = op.recordId ?? op.values['id'] as int?;

    if (recordId == null) {
      throw Exception(
        'Cannot process ${op.model}.${op.method} - no record ID available',
      );
    }

    logger.d(
      '[OfflineSyncService]',
      'Processing generic action ${op.model}.${op.method} for record $recordId',
    );

    await _odooClient!.call(
      model: op.model,
      method: op.method,
      ids: [recordId],
    );

    logger.d(
      '[OfflineSyncService]',
      '${op.model} $recordId ${op.method} synced to Odoo',
    );

    return null;
  }

  Future<ConflictInfo?> _processOrderStateAction(OfflineOperation op) async {
    final orderId = op.recordId ?? op.values['order_id'] as int?;

    if (orderId == null) {
      throw Exception('Cannot process ${op.method} - no order_id available');
    }

    logger.d(
      '[OfflineSyncService]',
      'Processing ${op.method} for sale.order $orderId (baseWriteDate: ${op.baseWriteDate})',
    );

    // Check for conflicts if we have baseWriteDate
    if (op.baseWriteDate != null) {
      final conflict = await _checkWriteConflict(op, orderId);
      if (conflict != null) {
        logger.w(
          '[OfflineSyncService]',
          '⚠️ CONFLICT detected for ${op.method} on order $orderId - '
              'server was modified after operation was queued',
        );
        return conflict;
      }
    }

    // No conflict - proceed with the action
    await _odooClient!.call(
      model: 'sale.order',
      method: op.method,
      ids: [orderId],
    );

    logger.d(
      '[OfflineSyncService]',
      'Order $orderId ${op.method} synced to Odoo',
    );

    // For lock/unlock, update isSynced flag
    if (op.method == 'action_lock' || op.method == 'action_unlock') {
      final locked = op.method == 'action_lock';
      await _orderManager.updateSaleOrderLocked(orderId, locked: locked, isSynced: true);
    }

    // For state changes, clear pendingConfirm if it was a confirm action
    if (op.method == 'action_confirm' || op.method == 'action_pos_confirm') {
      await _orderManager.clearSaleOrderPendingConfirm(orderId);
    }

    return null; // No conflict
  }

  /// Process operations for models other than sale.order and sale.order.line
  ///
  /// This handles payment wizards, withhold lines, advances, etc.
  Future<void> _processOtherModelOperation(OfflineOperation op) async {
    logger.d(
      '[OfflineSyncService]',
      'Processing ${op.model}.${op.method} (op ${op.id})',
    );

    switch (op.model) {
      // Payment wizard operations
      case 'l10n_ec_collection_box.sale.order.payment.wizard':
        await _processPaymentWizard(op);
        break;

      // Payment lines (individual payments)
      case 'l10n_ec_collection_box.sale.order.payment':
        await _processPaymentLine(op);
        break;

      // Withhold lines
      case 'sale.order.withhold.line':
        await _processWithholdLine(op);
        break;

      // Advance payments
      case 'sale.order.advance.line':
        await _processAdvanceLine(op);
        break;

      // Generic fallback - try standard CRUD operations
      default:
        logger.w(
          '[OfflineSyncService]',
          'Unknown model ${op.model}, attempting generic ${op.method}',
        );
        await _processGenericOperation(op);
    }
  }

  /// Process payment wizard operation (l10n_ec_collection_box.sale.order.payment.wizard)
  Future<void> _processPaymentWizard(OfflineOperation op) async {
    final saleId = op.values['sale_id'] as int?;
    final collectionSessionId = op.values['collection_session_id'] as int?;
    final paymentLines = op.values['line_ids'] ?? op.values['payment_lines'];

    if (saleId == null) {
      throw Exception('sale_id is required for payment wizard');
    }

    // Resolve local sale_id to remote if needed
    int actualSaleId = saleId;
    if (saleId < 0) {
      // Look up by parent order ID or UUID
      final order = await _orderManager.getSaleOrder(saleId);
      if (order != null && order.id > 0) {
        actualSaleId = order.id;
      } else {
        throw Exception('Cannot resolve local sale_id $saleId to remote ID');
      }
    }

    logger.d(
      '[OfflineSyncService]',
      'Processing payment wizard for sale $actualSaleId (original: $saleId)',
    );

    // Prepare line values for wizard
    List<dynamic> lineVals = [];
    if (paymentLines is List) {
      lineVals = paymentLines.map((line) {
        if (line is Map<String, dynamic>) {
          return [0, 0, line];
        }
        return line;
      }).toList();
    }

    // Create the payment wizard
    final wizardId = await _odooClient!.call(
      model: 'l10n_ec_collection_box.sale.order.payment.wizard',
      method: 'create',
      kwargs: {
        'vals_list': [
          {
            'sale_id': actualSaleId,
            if (collectionSessionId != null)
              'collection_session_id': collectionSessionId,
            if (lineVals.isNotEmpty) 'line_ids': lineVals,
          },
        ],
      },
    );

    if (wizardId == null) {
      throw Exception('Failed to create payment wizard');
    }

    // Execute the action based on method
    final actualId = wizardId is List ? wizardId[0] : wizardId;

    if (op.method == 'action_apply_and_create_invoice') {
      final result = await _odooClient.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'action_apply_and_create_invoice',
        kwargs: {
          'ids': [actualId],
        },
      );
      // Capture invoice ID from result
      if (result is Map && result.containsKey('res_id')) {
        _lastInvoiceCreated = result['res_id'] as int?;
        // Mark local payments as synced
        await _markOrderPaymentsAsSynced(actualSaleId);
      }
      logger.i(
        '[OfflineSyncService]',
        'Payment wizard: invoice created for sale $actualSaleId (invoice: $_lastInvoiceCreated)',
      );
    } else if (op.method == 'action_apply') {
      await _odooClient.call(
        model: 'l10n_ec_collection_box.sale.order.payment.wizard',
        method: 'action_apply',
        kwargs: {
          'ids': [actualId],
        },
      );
      logger.i(
        '[OfflineSyncService]',
        'Payment wizard: payments applied for sale $actualSaleId',
      );
    } else {
      // Just create was enough
      logger.i(
        '[OfflineSyncService]',
        'Payment wizard created for sale $actualSaleId (id=$actualId)',
      );
    }
  }

  /// Process individual payment line
  Future<void> _processPaymentLine(OfflineOperation op) async {
    final values = Map<String, dynamic>.from(op.values);

    // Remove local-only fields
    values.remove('local_id');
    values.remove('uuid');
    values.remove('_uuid');

    // Resolve local IDs to remote IDs if needed
    if (values['sale_id'] != null && (values['sale_id'] as int) < 0) {
      final localSaleId = values['sale_id'] as int;
      final order = await _orderManager.getSaleOrder(localSaleId);
      if (order != null && order.id > 0) {
        values['sale_id'] = order.id;
      }
    }

    if (op.method == 'create') {
      final remoteId = await _odooClient!.create(
        model: op.model,
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Payment line created: $remoteId');
    } else if (op.method == 'write' && op.recordId != null) {
      await _odooClient!.write(
        model: op.model,
        ids: [op.recordId!],
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Payment line updated: ${op.recordId}');
    } else if (op.method == 'unlink' && op.recordId != null) {
      try {
        await _odooClient!.unlink(model: op.model, ids: [op.recordId!]);
        logger.d(
          '[OfflineSyncService]',
          'Payment line deleted: ${op.recordId}',
        );
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('does not exist') ||
            errorStr.contains('has been deleted') ||
            errorStr.contains('missing record')) {
          throw OperationSkippedException(
            'Payment line ${op.recordId} ya no existe en Odoo',
          );
        }
        rethrow;
      }
    }
  }

  /// Process withhold line
  Future<void> _processWithholdLine(OfflineOperation op) async {
    final values = Map<String, dynamic>.from(op.values);

    // Remove local-only fields
    values.remove('local_id');
    values.remove('uuid');
    values.remove('_uuid');

    // Resolve local sale_id to remote if needed
    if (values['sale_id'] != null && (values['sale_id'] as int) < 0) {
      final localSaleId = values['sale_id'] as int;
      final order = await _orderManager.getSaleOrder(localSaleId);
      if (order != null && order.id > 0) {
        values['sale_id'] = order.id;
      }
    }

    if (op.method == 'create') {
      final remoteId = await _odooClient!.create(
        model: op.model,
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Withhold line created: $remoteId');
    } else if (op.method == 'write' && op.recordId != null) {
      await _odooClient!.write(
        model: op.model,
        ids: [op.recordId!],
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Withhold line updated: ${op.recordId}');
    } else if (op.method == 'unlink' && op.recordId != null) {
      try {
        await _odooClient!.unlink(model: op.model, ids: [op.recordId!]);
        logger.d(
          '[OfflineSyncService]',
          'Withhold line deleted: ${op.recordId}',
        );
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('does not exist') ||
            errorStr.contains('has been deleted') ||
            errorStr.contains('missing record')) {
          throw OperationSkippedException(
            'Withhold line ${op.recordId} ya no existe en Odoo',
          );
        }
        rethrow;
      }
    }
  }

  /// Process advance line
  Future<void> _processAdvanceLine(OfflineOperation op) async {
    final values = Map<String, dynamic>.from(op.values);

    // Remove local-only fields
    values.remove('local_id');
    values.remove('uuid');
    values.remove('_uuid');

    // Resolve local sale_id to remote if needed
    if (values['sale_id'] != null && (values['sale_id'] as int) < 0) {
      final localSaleId = values['sale_id'] as int;
      final order = await _orderManager.getSaleOrder(localSaleId);
      if (order != null && order.id > 0) {
        values['sale_id'] = order.id;
      }
    }

    if (op.method == 'create') {
      final remoteId = await _odooClient!.create(
        model: op.model,
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Advance line created: $remoteId');
    } else if (op.method == 'write' && op.recordId != null) {
      await _odooClient!.write(
        model: op.model,
        ids: [op.recordId!],
        values: values,
      );
      logger.d('[OfflineSyncService]', 'Advance line updated: ${op.recordId}');
    } else if (op.method == 'unlink' && op.recordId != null) {
      try {
        await _odooClient!.unlink(model: op.model, ids: [op.recordId!]);
        logger.d(
          '[OfflineSyncService]',
          'Advance line deleted: ${op.recordId}',
        );
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        if (errorStr.contains('does not exist') ||
            errorStr.contains('has been deleted') ||
            errorStr.contains('missing record')) {
          throw OperationSkippedException(
            'Advance line ${op.recordId} ya no existe en Odoo',
          );
        }
        rethrow;
      }
    }
  }

  /// Process generic operation for unknown models
  Future<void> _processGenericOperation(OfflineOperation op) async {
    final values = Map<String, dynamic>.from(op.values);

    // Remove local-only fields
    values.remove('local_id');
    values.remove('uuid');
    values.remove('_uuid');

    switch (op.method) {
      case 'create':
        final remoteId = await _odooClient!.create(
          model: op.model,
          values: values,
        );
        logger.d('[OfflineSyncService]', '${op.model} created: $remoteId');
        break;

      case 'write':
        if (op.recordId == null || op.recordId! <= 0) {
          throw Exception('Cannot write ${op.model}: no valid record ID');
        }
        await _odooClient!.write(
          model: op.model,
          ids: [op.recordId!],
          values: values,
        );
        logger.d('[OfflineSyncService]', '${op.model} updated: ${op.recordId}');
        break;

      case 'unlink':
        if (op.recordId == null || op.recordId! <= 0) {
          throw OperationSkippedException('${op.model}: sin ID remoto');
        }
        try {
          await _odooClient!.unlink(model: op.model, ids: [op.recordId!]);
          logger.d(
            '[OfflineSyncService]',
            '${op.model} deleted: ${op.recordId}',
          );
        } catch (e) {
          final errorStr = e.toString().toLowerCase();
          if (errorStr.contains('does not exist') ||
              errorStr.contains('has been deleted') ||
              errorStr.contains('missing record')) {
            throw OperationSkippedException(
              '${op.model}[${op.recordId}] ya no existe en Odoo',
            );
          }
          rethrow;
        }
        break;

      default:
        // Try to call the method directly on the model
        if (op.recordId != null && op.recordId! > 0) {
          await _odooClient!.call(
            model: op.model,
            method: op.method,
            ids: [op.recordId!],
          );
          logger.d(
            '[OfflineSyncService]',
            '${op.model}.${op.method}(${op.recordId}) called',
          );
        } else {
          throw Exception(
            'Cannot call ${op.model}.${op.method}: no valid record ID',
          );
        }
    }
  }

  /// Validate order before syncing to Odoo
  ///
  /// Returns error message if validation fails, null if valid.
  Future<String?> _validateOrderForSync(dynamic order) async {
    // Check if order is a SaleOrder model
    if (order == null) {
      return 'Orden no encontrada';
    }

    // Partner is required
    final partnerId = order.partnerId;
    if (partnerId == null) {
      return 'Cliente es obligatorio';
    }

    // Check final consumer validation
    // If isFinalConsumer is true, endCustomerName is required
    final isFinalConsumer = order.isFinalConsumer ?? false;
    final endCustomerName = order.endCustomerName;

    if (isFinalConsumer &&
        (endCustomerName == null || endCustomerName.isEmpty)) {
      return 'El nombre del consumidor final es obligatorio cuando el cliente es Consumidor Final. '
          'Por favor ingrese el nombre en el campo "Nombre Consumidor Final".';
    }

    // Validate productos temporales (product_id < 0 means not synced yet)
    final orderId = order.id as int?;
    if (orderId != null) {
      final lines = await _lineManager.getSaleOrderLines(orderId);
      final tempProductLines = lines.where(
        (line) => line.productId != null && line.productId! < 0,
      );
      if (tempProductLines.isNotEmpty) {
        return 'La orden tiene productos temporales que aún no se han '
            'sincronizado con el servidor.';
      }
    }

    // Validate facturación postfechada
    final emitirPostfechada = order.emitirFacturaFechaPosterior ?? false;
    if (emitirPostfechada) {
      final DateTime? fechaFacturar = order.fechaFacturar;
      if (fechaFacturar == null) {
        return 'La fecha de facturación es obligatoria cuando se habilita '
            'facturación postfechada.';
      }
      final today = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      );
      final fechaNormalized = DateTime(
        fechaFacturar.year,
        fechaFacturar.month,
        fechaFacturar.day,
      );
      if (fechaNormalized.isBefore(today)) {
        return 'La fecha de facturación postfechada no puede ser una fecha '
            'pasada.';
      }
    }

    return null; // Valid
  }

  // ═══════════════════════════════════════════════════════════════════════════
  // Private helpers (migrated from CollectionPaymentDataSource)
  // ═══════════════════════════════════════════════════════════════════════════

  /// Update local payment with Odoo ID after sync (by UUID)
  Future<void> _updatePaymentIdByUuid(String paymentUuid, int newOdooId) async {
    final existing = (await _paymentManager.searchLocal(
      domain: [['payment_uuid', '=', paymentUuid]],
      limit: 1,
    )).firstOrNull;
    if (existing == null) {
      logger.w('[OfflineSyncService]', 'No payment found with UUID=$paymentUuid');
      return;
    }
    final updated = existing.copyWith(
      id: newOdooId,
      isSynced: true,
      lastSyncDate: DateTime.now(),
    );
    await _paymentManager.upsertLocal(updated);
  }

  /// Mark all SaleOrderPaymentLine records for an order as synced.
  ///
  /// This operates on the SaleOrderPaymentLine table (not AccountPayment),
  /// so it uses direct Drift access rather than a manager.
  Future<void> _markOrderPaymentsAsSynced(int orderId) async {
    final db = _appDb;
    await (db.update(db.saleOrderPaymentLine)
          ..where((tbl) => tbl.orderId.equals(orderId)))
        .write(
      const SaleOrderPaymentLineCompanion(
        isSynced: drift.Value(true),
      ),
    );
    logger.d(
      '[OfflineSyncService]',
      'Payments marked as synced for order $orderId',
    );
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
