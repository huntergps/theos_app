part of 'offline_sync_service.dart';

/// Procesamiento genérico de operaciones de la cola offline: create/write/
/// unlink estándar, detección de conflictos por write_date, y el fallback
/// genérico para modelos/acciones sin handler específico.
extension _OfflineSyncGenericOps on OfflineSyncService {
  /// Busca en Odoo un sale.order existente por `x_uuid`.
  ///
  /// Usado para recuperar de un `create` cuya respuesta se perdió pero que
  /// sí se persistió en el servidor (ver [_processCreate]). Retorna `null`
  /// si no existe o si la búsqueda falla (en ese caso el llamador debe
  /// tratar el create original como un fallo real y reintentar).
  Future<int?> _findExistingSaleOrderIdByUuid(String uuid) async {
    try {
      final results = await _odooClient!.searchRead(
        model: 'sale.order',
        domain: [
          ['x_uuid', '=', uuid],
        ],
        fields: ['id'],
        limit: 1,
      );
      if (results.isEmpty) return null;
      return results.first['id'] as int?;
    } catch (e) {
      logger.w(
        '[OfflineSyncService]',
        'No se pudo verificar x_uuid=$uuid en Odoo: $e',
      );
      return null;
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

    int? remoteId;
    try {
      remoteId = await _odooClient!.create(
        model: op.model,
        values: odooValues,
      );
    } catch (e) {
      // Recuperación de idempotencia: el create puede haber llegado a Odoo
      // y persistido, pero la respuesta HTTP se perdió (timeout, red
      // inestable) — el cliente lo interpreta como fallo y reintenta. El
      // reintento choca con el constraint único `x_uuid_unique` en
      // sale.order y sigue fallando indefinidamente, dejando la orden
      // huérfana: sincronizada en Odoo pero atascada en dead-letter local.
      // Antes de reintentar, verificamos si ya existe por x_uuid y, si es
      // así, vinculamos el ID real en vez de volver a intentar el create.
      if (op.model == 'sale.order' && uuid != null && uuid.isNotEmpty) {
        final existingId = await _findExistingSaleOrderIdByUuid(uuid);
        if (existingId != null) {
          logger.w(
            '[OfflineSyncService]',
            'Create de sale.order (uuid=$uuid) falló ("$e") pero YA existe '
                'en Odoo con id=$existingId — vinculando en vez de reintentar.',
          );
          remoteId = existingId;
        } else {
          rethrow;
        }
      } else {
        rethrow;
      }
    }

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
}
