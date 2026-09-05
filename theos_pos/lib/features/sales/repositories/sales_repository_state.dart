part of 'sales_repository.dart';

/// State management operations for sale orders: approve, confirm, cancel,
/// draft, lock/unlock, and offline state queueing.
extension SalesRepositoryState on SalesRepository {
  Future<void> approve(int orderId) async {
    await _changeOrderState(
      orderId,
      method: 'set_approved',
      state: 'approved',
      pendingConfirm: true,
    );
  }

  Future<void> confirm(int orderId) async {
    await _changeOrderState(
      orderId,
      method: 'action_pos_confirm',
      state: 'sale',
      pendingConfirm: true,
    );
  }

  Future<PosConfirmResult> posConfirm(
    int orderId, {
    bool skipCreditCheck = false,
  }) async {
    logger.d(
      '[SalesRepository]',
      'posConfirm: orderId=$orderId, skipCreditCheck=$skipCreditCheck',
    );

    // OFFLINE-FIRST: If no connection, use offline confirmation
    if (!_orderManager.isOnline) {
      logger.d(
        '[SalesRepository]',
        'posConfirm: offline mode, using confirmOffline',
      );
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
      final result = await _orderManager.callCustomMethod<dynamic>(
        'action_pos_confirm',
        ids: [orderId],
        kwargs: {'skip_credit_check': skipCreditCheck},
      );

      logger.d('[SalesRepository]', 'posConfirm result: $result');

      if (result is Map<String, dynamic>) {
        final approvalAction = readPendingSaleApprovalAction(
          result,
          orderId: orderId,
        );
        if (approvalAction != null) {
          final context = approvalAction['context'];
          final checkType = context is Map
              ? context['default_check_type']
              : null;
          final message =
              result['error'] as String? ??
              'La venta necesita aprobación antes de confirmarse.';
          final creditIssue =
              approvalAction['res_model'] == 'credit.limit.exceeded.wizard' &&
                  checkType is String
              ? CreditIssue(
                  approvalAction: approvalAction,
                  type: checkType,
                  message: message,
                  partnerId: context['default_partner_id'] as int? ?? 0,
                  partnerName: '',
                  orderAmount: (context['default_transaction_amount'] as num?)
                      ?.toDouble(),
                  creditLimit: (context['default_current_credit_limit'] as num?)
                      ?.toDouble(),
                )
              : null;
          return PosConfirmResult(
            success: false,
            error: message,
            orderId: orderId,
            orderState: result['state'] as String,
            approvalAction: approvalAction,
            creditIssue: creditIssue,
          );
        }
        final success = result['success'] as bool? ?? false;

        if (success) {
          requireConfirmedSaleResponse(result, orderId: orderId);
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
      if (_isSalesTransportFailure(e)) {
        logger.e(
          '[SalesRepository]',
          'Transport failed in posConfirm, trying offline',
          e,
          stack,
        );
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
      } else {
        logger.e('[SalesRepository]', 'Server rejected posConfirm', e, stack);
      }
      return PosConfirmResult(success: false, error: 'Error al confirmar: $e');
    }
  }

  Future<bool> confirmOffline(int orderId) async {
    try {
      logger.d(
        '[SalesRepository]',
        'confirmOffline START for orderId=$orderId',
      );
      // 1. Get current order to get UUID
      final order = await _orderManager.getSaleOrder(orderId);
      logger.d(
        '[SalesRepository]',
        'getSaleOrder returned: ${order == null ? "NULL" : "order ${order.id}"}',
      );
      if (order == null) {
        logger.e('[SalesRepository]', 'Order $orderId not found locally');
        return false;
      }
      logger.d(
        '[SalesRepository]',
        'confirmOffline: order found, orderUuid=${order.orderUuid}',
      );

      await _persistStateSnapshotAndIntent(
        order,
        method: OfflineLocalCommand.orderConfirm.storageName,
        state: 'sale',
        pendingConfirm: true,
        command: OfflineLocalCommand.orderConfirm,
      );

      logger.d('[SalesRepository]', 'confirmOffline: returning TRUE');
      return true;
    } catch (e, stack) {
      logger.e(
        '[SalesRepository]',
        'Error confirming order offline: $e',
        e,
        stack,
      );
      return false;
    }
  }

  Future<void> cancel(int orderId) async {
    await _changeOrderState(orderId, method: 'action_cancel', state: 'cancel');
  }

  Future<void> setToDraft(int orderId) async {
    await _changeOrderState(orderId, method: 'action_draft', state: 'draft');
  }

  Future<void> lockOrder(int orderId) async {
    await _changeOrderLock(orderId, locked: true);
  }

  Future<void> unlockOrder(int orderId) async {
    await _changeOrderLock(orderId, locked: false);
  }

  Future<void> _changeOrderState(
    int orderId, {
    required String method,
    required String state,
    bool pendingConfirm = false,
  }) async {
    final order = await _orderManager.getSaleOrder(orderId);
    if (order == null) throw StateError('Order $orderId not found locally');
    final operationId = await _persistStateSnapshotAndIntent(
      order,
      method: method,
      state: state,
      pendingConfirm: pendingConfirm,
    );
    if (!_orderManager.isOnline || orderId <= 0) return;

    try {
      final response = await _orderManager.callCustomMethod<dynamic>(
        method,
        ids: [orderId],
      );
      if (method == 'action_pos_confirm') {
        requireConfirmedSaleResponse(response, orderId: orderId);
      }
      await _db.transaction(() async {
        if (pendingConfirm) {
          await _orderManager.clearSaleOrderPendingConfirm(orderId);
        }
        if (operationId != null) {
          await _offlineQueue?.removeOperation(operationId);
        }
      });
    } catch (error) {
      if (_isSalesTransportFailure(error)) {
        logger.w('[SalesRepo]', '$method transport failed; intent retained');
        return;
      }
      await _db.transaction(() async {
        await _orderManager.updateSaleOrderState(
          orderId,
          state: order.state.code,
          pendingConfirm: false,
        );
        if (operationId != null) {
          await _offlineQueue?.removeOperation(operationId);
        }
      });
      rethrow;
    }
  }

  Future<int?> _persistStateSnapshotAndIntent(
    SaleOrder order, {
    required String method,
    required String state,
    required bool pendingConfirm,
    OfflineLocalCommand? command,
  }) async {
    Future<int?> persist() async {
      await _orderManager.updateSaleOrderState(
        order.id,
        state: state,
        pendingConfirm: pendingConfirm,
      );
      final queue = _offlineQueue;
      if (queue == null) return null;
      final values = <String, dynamic>{
        'order_id': order.id,
        'local_id': order.id,
        'order_uuid': order.orderUuid,
        'new_state': state,
      };
      if (command != null) {
        return queue.queueCommand(
          model: 'sale.order',
          command: command,
          recordId: order.id,
          values: values,
          baseWriteDate: order.writeDate,
          parentOrderId: order.id,
          priority: OfflinePriority.high,
          replayPolicy: OfflineReplayPolicy.retrySafe,
        );
      }
      return queue.queueOperation(
        model: 'sale.order',
        method: method,
        recordId: order.id,
        values: values,
        baseWriteDate: order.writeDate,
        parentOrderId: order.id,
        operationKey: 'sale-state:${order.orderUuid ?? order.id}:${_uuid.v4()}',
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
    }

    return _offlineQueue == null ? persist() : _db.transaction(persist);
  }

  Future<void> _changeOrderLock(int orderId, {required bool locked}) async {
    final order = await _orderManager.getSaleOrder(orderId);
    if (order == null) throw StateError('Order $orderId not found locally');
    final method = locked ? 'action_lock' : 'action_unlock';
    Future<int?> persist() async {
      await _orderManager.updateSaleOrderLocked(
        orderId,
        locked: locked,
        isSynced: false,
      );
      return _offlineQueue?.queueOperation(
        model: 'sale.order',
        method: method,
        recordId: orderId,
        values: {
          'order_id': orderId,
          'order_uuid': order.orderUuid,
          'lock': locked,
        },
        baseWriteDate: order.writeDate,
        parentOrderId: orderId,
        operationKey: 'sale-lock:${order.orderUuid ?? orderId}:${_uuid.v4()}',
        replayPolicy: OfflineReplayPolicy.retrySafe,
      );
    }

    final operationId = _offlineQueue == null
        ? await persist()
        : await _db.transaction(persist);
    if (!_orderManager.isOnline || orderId <= 0) return;

    try {
      await _orderManager.callCustomMethod<dynamic>(method, ids: [orderId]);
      await _db.transaction(() async {
        await _orderManager.updateSaleOrderLocked(
          orderId,
          locked: locked,
          isSynced: true,
        );
        if (operationId != null) {
          await _offlineQueue?.removeOperation(operationId);
        }
      });
    } catch (error) {
      if (_isSalesTransportFailure(error)) {
        logger.w('[SalesRepo]', '$method transport failed; intent retained');
        return;
      }
      await _db.transaction(() async {
        await _orderManager.updateSaleOrderLocked(
          orderId,
          locked: order.locked,
          isSynced: order.isSynced,
        );
        if (operationId != null) {
          await _offlineQueue?.removeOperation(operationId);
        }
      });
      rethrow;
    }
  }
}

bool _isSalesTransportFailure(Object error) {
  return error is OdooConnectionException ||
      error is OdooTimeoutException ||
      error is OdooOfflineException;
}
