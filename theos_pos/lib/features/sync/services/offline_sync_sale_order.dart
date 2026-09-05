part of 'offline_sync_service.dart';

/// Sync de sale.order: despacho interno de la cola específica de una orden,
/// confirmación offline-first, y validación pre-sync.
///
/// `processSaleOrderQueue` y `processModelQueue` (la API PÚBLICA que este
/// dominio expone) se quedan en `offline_sync_service.dart` (el archivo
/// principal) — NO acá. Razón: son consumidos desde otros archivos/librerías
/// (`pos_actions_panel.dart`, `pos_order_tabs.dart`,
/// `pos_sync_order_button_inline.dart`, `form_header.dart`) que solo
/// obtienen la instancia vía `offlineSyncServiceProvider` (definido en
/// `repository_providers.dart`, que hace `import` normal — no `export` — de
/// este archivo). Una `extension` (aunque sea pública) solo resuelve en el
/// call-site si el archivo que la declara está en la cadena de imports del
/// caller — si viviera acá, esos 4 archivos externos romperían con
/// `undefined_method` (se detectó así en la corrida de `flutter analyze`
/// posterior al split). Los métodos de instancia normales, en cambio, se
/// resuelven por despacho de tipo sin importar quién importó qué — por eso
/// se quedan en la clase concreta.
///
/// Todo lo demás acá es privado (`_processSaleOrderQueueInternal`,
/// `_processOrderConfirm`, `_processOrderStateAction`,
/// `_validateOrderForSync`) — sin consumidores externos, mismo patrón que
/// `_OfflineSyncSession`/`_OfflineSyncGenericOps`/`_OfflineSyncPartner`/
/// `_OfflineSyncPayment`.
extension _OfflineSyncSaleOrder on OfflineSyncService {
  /// Internal implementation of `processSaleOrderQueue` (declarado en
  /// offline_sync_service.dart).
  ///
  /// Does NOT touch [_isSyncing]. Can be called from within the guard
  /// (e.g. after on-the-fly operation enqueue) without flag inconsistency.
  /// Se asume ejecutado bajo [OfflineQueueProcessor.runExclusive] (ver
  /// `processSaleOrderQueue`) — la recursión interna (rama on-the-fly) NO
  /// vuelve a adquirir el lock, ya corre dentro de él.
  Future<SyncResult> _processSaleOrderQueueInternal(int orderId) async {
    int success = 0;
    int failed = 0;
    int skipped = 0;
    final errors = <String>[];
    final conflicts = <ConflictInfo>[];

    {
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

          // Process the newly-queued operations directly without going through
          // the public entry point (which re-checks _isSyncing).
          // This avoids the race condition where _isSyncing is set to false,
          // a concurrent call acquires the guard, and then this path also
          // re-enters — and if an exception is thrown between the flag reset
          // and the recursive call, the guard stays permanently unlocked.
          return await _processSaleOrderQueueInternal(orderId);
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
      final confirmationOps = operations
          .where((op) => op.model == 'sale.order' && _isOrderConfirmation(op))
          .toList();
      var orderOps = operations
          .where((op) => op.model == 'sale.order' && !_isOrderConfirmation(op))
          .toList();
      var lineOps = operations
          .where((op) => op.model == 'sale.order.line')
          .toList();
      final otherOps =
          <OfflineOperation>[
            ...confirmationOps,
            ...operations.where(
              (op) => op.model != 'sale.order' && op.model != 'sale.order.line',
            ),
          ]..sort(
            (a, b) =>
                _postLineDependencyRank(a)
                    .compareTo(_postLineDependencyRank(b)),
          );

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
          lineOps = await _offlineQueue.getOperationsForModel(
            'sale.order.line',
          );
          lineOps = lineOps.where((op) => op.parentOrderId == orderId).toList();
        }
      }

      // Track if order was synced successfully and the new ID
      int? newOrderId;
      bool orderSyncFailed = false;

      // Process order operations first
      for (final op in orderOps) {
        if (!await _claimForDispatch(op)) {
          if (op.status == OfflineOperationStatus.recoveryPending &&
              op.replayPolicy == OfflineReplayPolicy.manualAfterAmbiguous) {
            failed++;
            errors.add('Op ${op.id} requiere reconciliación manual');
            orderSyncFailed = true;
          }
          continue;
        }
        final currentOp = await _offlineQueue.getOperationById(op.id) ?? op;
        try {
          final conflict = await _processOperation(currentOp);
          if (conflict != null) {
            conflicts.add(conflict);
            await _completeOperationWithAudit(
              currentOp,
              result: 'conflict',
              conflict: conflict,
            );
            logger.w(
              '[OfflineSyncService]',
              'Conflict for operation ${op.id}: ${op.model}.${op.method}',
            );
            orderSyncFailed = true;
          } else {
            await _completeOperationWithAudit(currentOp, result: 'success');
            success++;
            logger.d(
              '[OfflineSyncService]',
              'Synced operation ${op.id}: ${op.model}.${op.method}',
            );
            // Get the new order ID from the database
            final syncedOrder = await _orderManager.getSaleOrderByUuid(
              currentOp.values['_uuid'] as String? ?? '',
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
          final errorMsg =
              'Op ${currentOp.id} (${currentOp.model}.${currentOp.method}): $e';
          errors.add(errorMsg);
          await _completeOperationWithAudit(
            currentOp,
            result: 'error',
            errorMessage: friendlyErrorMessage(e),
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
        // Las líneas nunca fueron reclamadas: permanecen pending sin consumir
        // reintentos y se despacharán cuando la orden padre se reconcilie.
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
        var lineSyncFailed = false;
        for (final op in lineOps) {
          if (!await _claimForDispatch(op)) {
            if (op.status == OfflineOperationStatus.recoveryPending &&
                op.replayPolicy == OfflineReplayPolicy.manualAfterAmbiguous) {
              failed++;
              errors.add('Op ${op.id} requiere reconciliación manual');
              lineSyncFailed = true;
            }
            continue;
          }
          final currentOp = await _offlineQueue.getOperationById(op.id) ?? op;
          try {
            final conflict = await _processOperation(currentOp);
            if (conflict != null) {
              conflicts.add(conflict);
              await _completeOperationWithAudit(
                currentOp,
                result: 'conflict',
                conflict: conflict,
              );
              logger.w(
                '[OfflineSyncService]',
                'Conflict for operation ${op.id}: ${op.model}.${op.method}',
              );
              lineSyncFailed = true;
            } else {
              await _completeOperationWithAudit(currentOp, result: 'success');
              success++;
              logger.d(
                '[OfflineSyncService]',
                'Synced operation ${op.id}: ${op.model}.${op.method}',
              );
            }
          } catch (e) {
            failed++;
            final errorMsg =
                'Op ${currentOp.id} (${currentOp.model}.${currentOp.method}): $e';
            errors.add(errorMsg);
            await _completeOperationWithAudit(
              currentOp,
              result: 'error',
              errorMessage: friendlyErrorMessage(e),
            );
            logger.e('[OfflineSyncService]', 'Failed to sync: $errorMsg');
            lineSyncFailed = true;
          }
        }

        // Process other operations (payments, withholds, wizards, etc.)
        if (lineSyncFailed) {
          logger.w(
            '[OfflineSyncService]',
            'Line sync failed, leaving ${otherOps.length} dependent '
                'operation(s) pending',
          );
        } else if (otherOps.isNotEmpty) {
          logger.i(
            '[OfflineSyncService]',
            'Processing ${otherOps.length} other operations (payments, withholds, etc.)',
          );

          for (final op in otherOps) {
            if (!await _claimForDispatch(op)) {
              if (op.status == OfflineOperationStatus.recoveryPending &&
                  op.replayPolicy == OfflineReplayPolicy.manualAfterAmbiguous) {
                failed++;
                errors.add('Op ${op.id} requiere reconciliación manual');
              }
              continue;
            }
            final currentOp = await _offlineQueue.getOperationById(op.id) ?? op;
            try {
              final conflict = currentOp.model == 'sale.order'
                  ? await _processOperation(currentOp)
                  : await _processOtherModelOperation(currentOp);
              if (conflict != null) {
                conflicts.add(conflict);
                await _completeOperationWithAudit(
                  currentOp,
                  result: 'conflict',
                  conflict: conflict,
                );
              } else {
                await _completeOperationWithAudit(currentOp, result: 'success');
                success++;
              }
              logger.d(
                '[OfflineSyncService]',
                'Synced operation ${op.id}: ${op.model}.${op.method}',
              );
            } on OperationSkippedException catch (e) {
              // Operation was skipped (e.g., record doesn't exist)
              skipped++;
              await _completeOperationWithAudit(currentOp, result: 'skipped');
              logger.w(
                '[OfflineSyncService]',
                'Skipped operation ${op.id}: $e',
              );
            } catch (e) {
              failed++;
              final errorMsg =
                  'Op ${currentOp.id} (${currentOp.model}.${currentOp.method}): $e';
              errors.add(errorMsg);
              await _completeOperationWithAudit(
                currentOp,
                result: 'error',
                errorMessage: friendlyErrorMessage(e),
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
    }

    // Determine status based on results
    final SyncStatus resultStatus;
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
    int? actualOdooId = odooId != null && odooId > 0 ? odooId : null;

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

    final serverOrder = await _odooClient!.searchRead(
      model: 'sale.order',
      domain: [
        ['id', '=', actualOdooId],
      ],
      fields: const ['state'],
      limit: 1,
    );
    final serverState = serverOrder.isEmpty
        ? null
        : serverOrder.first['state'] as String?;
    if (serverState == 'sale' || serverState == 'done') {
      await _orderManager.clearSaleOrderPendingConfirm(localId ?? actualOdooId);
      logger.d(
        '[OfflineSyncService]',
        'Order $actualOdooId was already confirmed; replay reconciled',
      );
      return;
    }

    // Lines must already have passed through their durable queue handlers.
    // Creating them inline here has no preflight marker and can duplicate a
    // line when a response is lost between server commit and local binding.
    final lookupOrderId = localId ?? actualOdooId;
    final localLines = await _lineManager.getSaleOrderLines(lookupOrderId);
    final unsyncedLines = localLines.where((l) => !l.isSynced).toList();

    if (unsyncedLines.isNotEmpty) {
      throw StateError(
        'Cannot confirm order $actualOdooId: ${unsyncedLines.length} '
        'line(s) are still pending durable synchronization',
      );
    }

    // Call action_pos_confirm on Odoo (handles credit validation on server)
    final confirmation = await _odooClient.call(
      model: 'sale.order',
      method: 'action_pos_confirm',
      ids: [actualOdooId],
    );
    requireConfirmedSaleResponse(confirmation, orderId: actualOdooId);

    logger.d('[OfflineSyncService]', 'Order $actualOdooId confirmed in Odoo');

    // Clear pendingConfirm flag on local order
    // Use localId if available (offline order), otherwise use the Odoo ID
    final orderIdToClear = localId ?? actualOdooId;
    await _orderManager.clearSaleOrderPendingConfirm(orderIdToClear);
  }

  bool _isOrderConfirmation(OfflineOperation op) {
    return op.method == OfflineLocalCommand.orderConfirm.storageName ||
        op.method == 'action_confirm' ||
        op.method == 'action_pos_confirm';
  }

  int _postLineDependencyRank(OfflineOperation op) {
    if (_isOrderConfirmation(op)) return 0;
    if (op.model == 'l10n_ec_collection_box.sale.order.payment.wizard' ||
        op.method == OfflineLocalCommand.paymentWizardApply.storageName) {
      return 10;
    }
    if (op.method ==
            OfflineLocalCommand.invoiceCreateWithPayments.storageName ||
        op.method == OfflineLocalCommand.paymentCreate.storageName ||
        op.model == 'account.move' ||
        op.model == 'account.payment' ||
        op.method.contains('invoice') ||
        op.method.contains('payment')) {
      return 20;
    }
    if (op.method == OfflineLocalCommand.sessionClose.storageName ||
        op.method == OfflineLocalCommand.sessionClosingControl.storageName) {
      return 30;
    }
    return 15;
  }

  Future<ConflictInfo?> _processOrderStateAction(OfflineOperation op) async {
    var orderId = op.recordId ?? op.values['order_id'] as int?;

    if (orderId != null && orderId <= 0) {
      final orderUuid =
          (op.values['order_uuid'] ?? op.values['_uuid']) as String?;
      if (orderUuid != null && orderUuid.isNotEmpty) {
        final localOrder = await _orderManager.getSaleOrderByUuid(orderUuid);
        if (localOrder != null && localOrder.id > 0) {
          orderId = localOrder.id;
        }
      }
    }

    if (orderId == null || orderId <= 0) {
      throw Exception('Cannot process ${op.method} - no order_id available');
    }

    logger.d(
      '[OfflineSyncService]',
      'Processing ${op.method} for sale.order $orderId (baseWriteDate: ${op.baseWriteDate})',
    );

    final serverOrder = await _odooClient!.searchRead(
      model: 'sale.order',
      domain: [
        ['id', '=', orderId],
      ],
      fields: const ['state', 'locked'],
      limit: 1,
    );
    if (serverOrder.isNotEmpty &&
        _isOrderActionAlreadyApplied(op, serverOrder.first)) {
      await _reconcileAppliedOrderAction(op, orderId);
      logger.d(
        '[OfflineSyncService]',
        'Order $orderId already satisfies ${op.method}; replay reconciled',
      );
      return null;
    }

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
    await _odooClient.call(
      model: 'sale.order',
      // Recover commands queued by older clients under the non-existent name.
      method: op.method == 'action_approve' ? 'set_approved' : op.method,
      ids: [orderId],
    );

    logger.d(
      '[OfflineSyncService]',
      'Order $orderId ${op.method} synced to Odoo',
    );

    // For lock/unlock, update isSynced flag
    if (op.method == 'action_lock' || op.method == 'action_unlock') {
      final locked = op.method == 'action_lock';
      await _orderManager.updateSaleOrderLocked(
        orderId,
        locked: locked,
        isSynced: true,
      );
    }

    // For state changes, clear pendingConfirm if it was a confirm action
    if (op.method == 'action_confirm' || op.method == 'action_pos_confirm') {
      await _orderManager.clearSaleOrderPendingConfirm(orderId);
    }

    return null; // No conflict
  }

  bool _isOrderActionAlreadyApplied(
    OfflineOperation op,
    Map<String, dynamic> serverOrder,
  ) {
    final state = serverOrder['state'] as String?;
    final locked = serverOrder['locked'] as bool?;
    return switch (op.method) {
      'action_lock' => locked == true,
      'action_unlock' => locked == false,
      'action_confirm' ||
      'action_pos_confirm' => state == 'sale' || state == 'done',
      'action_cancel' => state == 'cancel',
      'action_draft' => state == 'draft',
      'action_approve' || 'set_approved' => state == 'approved',
      _ => false,
    };
  }

  Future<void> _reconcileAppliedOrderAction(
    OfflineOperation op,
    int orderId,
  ) async {
    if (op.method == 'action_lock' || op.method == 'action_unlock') {
      await _orderManager.updateSaleOrderLocked(
        orderId,
        locked: op.method == 'action_lock',
        isSynced: true,
      );
    }
    if (op.method == 'action_confirm' || op.method == 'action_pos_confirm') {
      await _orderManager.clearSaleOrderPendingConfirm(orderId);
    }
  }

  /// Validate order before syncing to Odoo
  ///
  /// Returns error message if validation fails, null if valid.
  Future<String?> _validateOrderForSync(SaleOrder order) async {
    // Partner is required
    final partnerId = order.partnerId;
    if (partnerId == null) {
      return 'Cliente es obligatorio';
    }

    // Check final consumer validation
    // If isFinalConsumer is true, endCustomerName is required
    final isFinalConsumer = order.isFinalConsumer;
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
    final emitirPostfechada = order.emitirFacturaFechaPosterior;
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
}
