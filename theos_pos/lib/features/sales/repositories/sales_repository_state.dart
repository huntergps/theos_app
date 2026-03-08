part of 'sales_repository.dart';

/// State management operations for sale orders: approve, confirm, cancel,
/// draft, lock/unlock, and offline state queueing.
extension SalesRepositoryState on SalesRepository {
  Future<void> approve(int orderId) async {
    // 1. Update local DB first (source of truth)
    await _orderManager.updateSaleOrderState(
      orderId,
      state: 'approved',
      pendingConfirm: true,
    );
    logger.d('[SalesRepo]', 'Order $orderId approved locally');

    // 2. Try to sync to Odoo if online
    if (_odooClient != null) {
      try {
        await _odooClient.call(
          model: 'sale.order',
          method: 'action_approve',
          ids: [orderId],
        );
        await _orderManager.clearSaleOrderPendingConfirm(orderId);
        logger.d('[SalesRepo]', 'Order $orderId approve synced to Odoo');
        // Refresh order from Odoo
        await getById(orderId, forceRefresh: true);
      } catch (e) {
        // Some Odoo installations don't have action_approve
        // Queue for later sync
        logger.w('[SalesRepo]', 'Approve sync failed, queuing: $e');
        await _queueStateOperation(orderId, 'action_approve', 'approved');
      }
    } else {
      // Offline - queue for later sync
      await _queueStateOperation(orderId, 'action_approve', 'approved');
    }
  }

  Future<void> confirm(int orderId) async {
    // 1. Update local DB first (source of truth)
    await _orderManager.updateSaleOrderState(
      orderId,
      state: 'sale',
      pendingConfirm: true,
    );
    logger.d('[SalesRepo]', 'Order $orderId confirmed locally');

    // 2. Try to sync to Odoo if online
    if (_odooClient != null) {
      try {
        await _odooClient.call(
          model: 'sale.order',
          method: 'action_pos_confirm',
          ids: [orderId],
        );
        await _orderManager.clearSaleOrderPendingConfirm(orderId);
        logger.d('[SalesRepo]', 'Order $orderId confirm synced to Odoo');
      } catch (e) {
        logger.w('[SalesRepo]', 'Confirm sync failed, queuing: $e');
        await _queueStateOperation(orderId, 'action_pos_confirm', 'sale');
      }
    } else {
      await _queueStateOperation(orderId, 'action_pos_confirm', 'sale');
    }
  }

  Future<PosConfirmResult> posConfirm(
    int orderId, {
    bool skipCreditCheck = false,
  }) async {
    logger.d('[SalesRepository]', 'posConfirm: orderId=$orderId, skipCreditCheck=$skipCreditCheck');

    // OFFLINE-FIRST: If no connection, use offline confirmation
    if (_odooClient == null) {
      logger.d('[SalesRepository]', 'posConfirm: offline mode, using confirmOffline');
      final success = await confirmOffline(orderId);
      if (success) {
        final order = await _orderManager.getSaleOrder(orderId);
        return PosConfirmResult(
          success: true,
          orderId: orderId,
          orderName: order?.name,
          orderState: 'sale',
          confirmedOffline: true,
        );
      } else {
        return PosConfirmResult(
          success: false,
          error: 'Error al confirmar offline',
        );
      }
    }

    // ONLINE: Try to confirm with Odoo
    try {
      final result = await _odooClient.call(
        model: 'sale.order',
        method: 'action_pos_confirm',
        ids: [orderId],
        kwargs: {'skip_credit_check': skipCreditCheck},
      );

      logger.d('[SalesRepository]', 'posConfirm result: $result');

      if (result is Map<String, dynamic>) {
        final success = result['success'] as bool? ?? false;

        if (success) {
          // Refresh order to get new state
          await getById(orderId, forceRefresh: true);
          return PosConfirmResult(
            success: true,
            orderId: result['order_id'] as int?,
            orderName: result['order_name'] as String?,
            orderState: result['state'] as String?,
          );
        } else {
          // Check for credit issue
          final creditIssue = result['credit_issue'] as Map<String, dynamic>?;
          if (creditIssue != null) {
            return PosConfirmResult(
              success: false,
              error: result['error'] as String?,
              creditIssue: CreditIssue.fromMap(creditIssue),
            );
          }
          return PosConfirmResult(
            success: false,
            error: result['error'] as String? ?? 'Error desconocido',
          );
        }
      }

      // Unexpected result format
      return PosConfirmResult(
        success: false,
        error: 'Respuesta inesperada del servidor',
      );
    } catch (e, stack) {
      logger.e('[SalesRepository]', 'Error in posConfirm, trying offline', e, stack);
      // On network error, try offline confirmation
      final success = await confirmOffline(orderId);
      if (success) {
        final order = await _orderManager.getSaleOrder(orderId);
        return PosConfirmResult(
          success: true,
          orderId: orderId,
          orderName: order?.name,
          orderState: 'sale',
          confirmedOffline: true,
        );
      }
      return PosConfirmResult(success: false, error: 'Error al confirmar: $e');
    }
  }

  Future<bool> confirmOffline(int orderId) async {
    try {
      logger.d('[SalesRepository]', 'confirmOffline START for orderId=$orderId');
      // 1. Get current order to get UUID
      final order = await _orderManager.getSaleOrder(orderId);
      logger.d('[SalesRepository]', 'getSaleOrder returned: ${order == null ? "NULL" : "order ${order.id}"}');
      if (order == null) {
        logger.e('[SalesRepository]', 'Order $orderId not found locally');
        return false;
      }
      logger.d('[SalesRepository]', 'confirmOffline: order found, orderUuid=${order.orderUuid}');

      // 2a. OFFLINE INVOICE GENERATION (SRI Ecuador)
      // Use unified method to create invoice with AccountMove and lines
      logger.d('[SalesRepository]', 'confirmOffline: creating offline invoice...');
      try {
        final offlineInvoice = await _createOfflineInvoiceWithAccountMove(
          orderId: orderId,
          order: order,
        );

        if (offlineInvoice != null) {
          logger.d('[SalesRepository]', 'confirmOffline: invoice created = ${offlineInvoice.invoiceName}');

          // Queue invoice sync
          if (_offlineQueue != null) {
            await _offlineQueue.queueOperation(
              model: 'account.move',
              method: 'invoice_create_offline',
              recordId: orderId,
              values: {
                'order_local_id': orderId,
                'order_uuid': order.orderUuid,
                'access_key': offlineInvoice.accessKey,
                'invoice_name': offlineInvoice.invoiceName,
                'invoice_date': offlineInvoice.invoiceDate?.toIso8601String(),
                'amount_total': order.amountTotal,
              },
              priority: OfflinePriority.high,
              parentOrderId: orderId,
            );
          }
        }
      } catch (e) {
        logger.w('[SalesRepository]', 'SRI invoice generation error (non-fatal): $e');
        // Continue with confirmation - SRI invoice generation is optional
      }

      // 2. Update local state to 'sale' and mark pendingConfirm
      logger.d('[SalesRepository]', 'confirmOffline: updating local state to sale...');
      await _orderManager.updateSaleOrderState(
        orderId,
        state: 'sale',
        pendingConfirm: true,
      );
      logger.d('[SalesRepository]', 'confirmOffline: local state updated');

      // 3. Queue action_confirm for sync
      logger.d('[SalesRepository]', 'confirmOffline: _offlineQueue is ${_offlineQueue == null ? "NULL" : "available"}');
      if (_offlineQueue != null) {
        logger.d('[SalesRepository]', 'confirmOffline: queueing operation...');
        await _offlineQueue.queueOperation(
          model: 'sale.order',
          method: 'order_confirm',
          recordId: order.id,
          values: {'order_uuid': order.orderUuid, 'local_id': orderId},
          priority: OfflinePriority.high,
        );
        logger.d(
          '[SalesRepository]',
          'Order $orderId confirmed offline, queued for sync',
        );
      }

      logger.d('[SalesRepository]', 'confirmOffline: returning TRUE');
      return true;
    } catch (e, stack) {
      logger.e('[SalesRepository]', 'Error confirming order offline: $e', e, stack);
      return false;
    }
  }

  Future<void> cancel(int orderId) async {
    // 1. Update local DB first (source of truth)
    await _orderManager.updateSaleOrderState(orderId, state: 'cancel');
    logger.d('[SalesRepo]', 'Order $orderId cancelled locally');

    // 2. Try to sync to Odoo if online
    if (_odooClient != null) {
      try {
        await _odooClient.call(
          model: 'sale.order',
          method: 'action_cancel',
          ids: [orderId],
        );
        logger.d('[SalesRepo]', 'Order $orderId cancel synced to Odoo');
      } catch (e) {
        logger.w('[SalesRepo]', 'Cancel sync failed, queuing: $e');
        await _queueStateOperation(orderId, 'action_cancel', 'cancel');
      }
    } else {
      await _queueStateOperation(orderId, 'action_cancel', 'cancel');
    }
  }

  Future<void> setToDraft(int orderId) async {
    // 1. Update local DB first (source of truth)
    await _orderManager.updateSaleOrderState(orderId, state: 'draft');
    logger.d('[SalesRepo]', 'Order $orderId set to draft locally');

    // 2. Try to sync to Odoo if online
    if (_odooClient != null) {
      try {
        await _odooClient.call(
          model: 'sale.order',
          method: 'action_draft',
          ids: [orderId],
        );
        logger.d('[SalesRepo]', 'Order $orderId setToDraft synced to Odoo');
      } catch (e) {
        logger.w('[SalesRepo]', 'SetToDraft sync failed, queuing: $e');
        await _queueStateOperation(orderId, 'action_draft', 'draft');
      }
    } else {
      await _queueStateOperation(orderId, 'action_draft', 'draft');
    }
  }

  Future<void> lockOrder(int orderId) async {
    // 1. Update local DB first (source of truth)
    await _orderManager.updateSaleOrderLocked(orderId, locked: true, isSynced: false);
    logger.d('[SalesRepo]', 'Order $orderId locked locally');

    // 2. Try to sync to Odoo if online
    if (_odooClient != null) {
      try {
        await _odooClient.call(
          model: 'sale.order',
          method: 'action_lock',
          ids: [orderId],
        );
        // Mark as synced
        await _orderManager.updateSaleOrderLocked(orderId, locked: true, isSynced: true);
        logger.d('[SalesRepo]', 'Order $orderId lock synced to Odoo');
      } catch (e) {
        // Queue for later sync
        logger.w('[SalesRepo]', 'Lock sync failed, queuing: $e');
        await _queueLockOperation(orderId, true);
      }
    } else {
      // Offline - queue for later
      await _queueLockOperation(orderId, true);
    }
  }

  Future<void> unlockOrder(int orderId) async {
    // 1. Update local DB first (source of truth)
    await _orderManager.updateSaleOrderLocked(orderId, locked: false, isSynced: false);
    logger.d('[SalesRepo]', 'Order $orderId unlocked locally');

    // 2. Try to sync to Odoo if online
    if (_odooClient != null) {
      try {
        await _odooClient.call(
          model: 'sale.order',
          method: 'action_unlock',
          ids: [orderId],
        );
        // Mark as synced
        await _orderManager.updateSaleOrderLocked(orderId, locked: false, isSynced: true);
        logger.d('[SalesRepo]', 'Order $orderId unlock synced to Odoo');
      } catch (e) {
        // Queue for later sync
        logger.w('[SalesRepo]', 'Unlock sync failed, queuing: $e');
        await _queueLockOperation(orderId, false);
      }
    } else {
      // Offline - queue for later
      await _queueLockOperation(orderId, false);
    }
  }

  Future<void> _queueLockOperation(int orderId, bool lock) async {
    if (_offlineQueue == null) return;

    // Get current write_date for conflict detection
    final order = await _orderManager.getSaleOrder(orderId);
    final baseWriteDate = order?.writeDate;

    await _offlineQueue.queueOperation(
      model: 'sale.order',
      method: lock ? 'action_lock' : 'action_unlock',
      recordId: orderId,
      values: {'order_id': orderId, 'lock': lock},
      baseWriteDate: baseWriteDate,
    );
    logger.d(
      '[SalesRepo]',
      'Queued ${lock ? "lock" : "unlock"} for order $orderId (baseWriteDate: $baseWriteDate)',
    );
  }

  Future<void> _queueStateOperation(
    int orderId,
    String method,
    String newState,
  ) async {
    if (_offlineQueue == null) return;

    // Get current write_date for conflict detection
    final order = await _orderManager.getSaleOrder(orderId);
    final baseWriteDate = order?.writeDate;

    await _offlineQueue.queueOperation(
      model: 'sale.order',
      method: method,
      recordId: orderId,
      values: {'order_id': orderId, 'new_state': newState},
      baseWriteDate: baseWriteDate,
    );
    logger.d(
      '[SalesRepo]',
      'Queued $method for order $orderId (baseWriteDate: $baseWriteDate)',
    );
  }
}
