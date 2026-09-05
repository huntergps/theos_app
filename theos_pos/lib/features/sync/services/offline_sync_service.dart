import 'dart:async';
import 'dart:convert';

import 'package:odoo_sdk/odoo_sdk.dart'
    show
        OdooClient,
        logger,
        SyncProgressEvent,
        SyncResult,
        SyncStatus,
        ConflictInfo,
        OperationSkippedException,
        OfflineOperationStatus,
        OfflineReplayPolicy,
        OfflineLocalCommand,
        OfflineQueueProcessor,
        OfflineQueueAuditLogger;
import 'package:drift/drift.dart' as drift;
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        AppDatabase,
        AccountPaymentManager,
        SaleOrder,
        SaleOrderLine,
        SaleOrderLineManager,
        SaleOrderLineManagerBusiness,
        saleOrderLineManager,
        SaleOrderManager,
        SaleOrderManagerBusiness,
        saleOrderManager,
        ClientManagerBusiness,
        clientManager,
        CollectionSessionManager,
        CollectionSessionManagerBusiness,
        CollectionSessionCashCompanion,
        CollectionSessionDepositCompanion,
        CashOutCompanion,
        AccountPaymentCompanion,
        AccountAdvanceCompanion,
        AdvanceLinesTableCompanion,
        ResPartnerBankCompanion,
        SaleOrderCompanion,
        SaleOrderLineCompanion,
        SaleOrderPaymentLineCompanion,
        SaleOrderWithholdLineCompanion,
        SyncConflictCompanion;

import '../../../core/database/database_helper.dart';
import '../../../core/database/datasources/datasources.dart';
import '../../sales/services/credit_approval_service.dart';
import '../../sales/services/sale_confirmation_contract.dart';
import '../../sales/services/payment_wizard_contract.dart';
import '../../../shared/utils/error_utils.dart';

part 'offline_sync_session.dart';
part 'offline_sync_generic_ops.dart';
part 'offline_sync_partner.dart';
part 'offline_sync_sale_order.dart';
part 'offline_sync_payment.dart';
part 'offline_sync_credit_approval.dart';

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
  late final OfflineQueueAuditLogger _auditLogger;
  late final OfflineQueueProcessor _processor;

  bool _isSyncing = false;

  /// Last invoice ID created during sync (used for result feedback)
  int? _lastInvoiceCreated;

  /// Convenience accessor for the global SaleOrderManager
  SaleOrderManager get _orderManager => saleOrderManager;

  /// Convenience accessor for the global SaleOrderLineManager
  SaleOrderLineManager get _lineManager => saleOrderLineManager;

  OfflineSyncService({
    required this._db,
    required this._appDb,
    this._odooClient,
    required this._offlineQueue,
    required this._sessionManager,
    required this._paymentManager,
    OfflineQueueAuditLogger? auditLogger,
  }) {
    _auditLogger = auditLogger ?? _AppAuditLogger(_db, _appDb);
    _processor = OfflineQueueProcessor(
      queue: _offlineQueue,
      handler: _processOperation,
      auditLogger: _auditLogger,
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
      domain: [
        ['line_uuid', '=', uuid],
      ],
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

  /// Stops new dispatches and waits for the active queue writer to finish.
  /// Callers closing/switching the database must await this first.
  Future<void> shutdown() => _processor.shutdown();

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
    await _auditLogger.logOperation(
      op,
      result: result,
      odooId: odooId,
      errorMessage: errorMessage,
    );
  }

  /// Complete an operation with audit logging
  Future<void> _completeOperationWithAudit(
    OfflineOperation op, {
    required String result,
    int? odooId,
    String? errorMessage,
    ConflictInfo? conflict,
  }) async {
    if (conflict != null) {
      await _auditLogger.logConflict(op, conflict);
    } else {
      await _logOperation(
        op,
        result: result,
        odooId: odooId,
        errorMessage: errorMessage,
      );
    }

    switch (result) {
      case 'success':
      case 'skipped':
        await _offlineQueue.removeOperation(op.id);
        return;
      case 'conflict':
        await _offlineQueue.markOperationConflict(op.id);
        return;
      case 'error':
        if (op.replayPolicy == OfflineReplayPolicy.retrySafe) {
          await _offlineQueue.markOperationFailed(
            op.id,
            errorMessage ?? 'Offline dispatch failed',
          );
        } else {
          await _offlineQueue.markOperationDeadLetter(
            op.id,
            errorMessage ?? 'Ambiguous offline dispatch requires review',
          );
        }
        return;
      default:
        return;
    }
  }

  /// Claims one row for the direct sale-order dispatcher.
  ///
  /// Rows recovered from an interrupted unsafe create are held for manual
  /// reconciliation instead of being sent again blindly.
  Future<bool> _claimForDispatch(OfflineOperation op) async {
    if (!op.isReadyForRetry) return false;
    if (op.status == OfflineOperationStatus.recoveryPending &&
        op.replayPolicy == OfflineReplayPolicy.manualAfterAmbiguous) {
      const message =
          'Operación recuperada tras un cierre durante el envío; requiere '
          'revisión manual antes de repetirla.';
      await _offlineQueue.markOperationDeadLetter(op.id, message);
      await _logOperation(op, result: 'dead_letter', errorMessage: message);
      return false;
    }
    await _offlineQueue.markOperationProcessing(op.id);
    return true;
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
    final command = OfflineLocalCommand.tryParse(op.method);
    if (command != null && op.commandVersion != command.version) {
      throw StateError(
        'Unsupported ${command.storageName} payload version '
        '${op.commandVersion}; expected ${command.version}',
      );
    }
    if (command != null) {
      switch (command) {
        case OfflineLocalCommand.sessionCreateAndOpen:
          await _processSessionCreateAndOpen(op);
        case OfflineLocalCommand.sessionOpen:
          await _processSessionOpen(op);
        case OfflineLocalCommand.sessionClosingControl:
          await _processSessionClosingControl(op);
        case OfflineLocalCommand.sessionClose:
          await _processSessionClose(op);
        case OfflineLocalCommand.paymentCreate:
          await _processPaymentCreate(op);
        case OfflineLocalCommand.paymentWizardApply:
          return await _processPaymentWizard(op);
        case OfflineLocalCommand.partnerCreate:
          await _processPartnerCreate(op);
        case OfflineLocalCommand.orderConfirm:
          await _processOrderConfirm(op);
        case OfflineLocalCommand.invoiceCreateWithPayments:
          return await _processInvoiceWithPayments(op);
        case OfflineLocalCommand.invoiceCollectExisting:
          return await _processExistingInvoiceCollection(op);
      }
      return null;
    }
    if (op.method == CreditApprovalOfflineContract.method) {
      return await _processCreditApproval(op);
    }
    switch (op.method) {
      case 'create':
        await _processCreate(op);
        return null;
      case 'write':
        return await _processWrite(op);
      case 'unlink':
        await _processUnlink(op);
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
  final AppDatabase _appDb;

  _AppAuditLogger(this._db, this._appDb);

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

  @override
  Future<void> logConflict(OfflineOperation op, ConflictInfo conflict) async {
    await logOperation(op, result: 'conflict');

    final existing =
        await (_appDb.select(_appDb.syncConflict)..where(
              (table) =>
                  table.operationId.equals(op.id) &
                  table.isResolved.equals(false),
            ))
            .getSingleOrNull();
    if (existing != null) return;

    final localPayload = jsonEncode({
      'field': '__record__',
      'value': jsonEncode(conflict.localValues),
      'write_date': conflict.localWriteDate.toUtc().toIso8601String(),
    });
    final remotePayload = jsonEncode({
      'field': '__record__',
      'value': jsonEncode(conflict.serverValues ?? const {}),
      'write_date': conflict.serverWriteDate.toUtc().toIso8601String(),
    });

    await _appDb
        .into(_appDb.syncConflict)
        .insert(
          SyncConflictCompanion.insert(
            operationId: op.id,
            model: conflict.model,
            localId:
                op.values['local_id'] as int? ??
                op.recordId ??
                conflict.recordId ??
                0,
            remoteId: conflict.recordId ?? op.recordId ?? 0,
            conflictType: 'both_modified',
            localData: localPayload,
            remoteData: remotePayload,
            detectedAt: DateTime.now().toUtc(),
          ),
        );
  }
}
