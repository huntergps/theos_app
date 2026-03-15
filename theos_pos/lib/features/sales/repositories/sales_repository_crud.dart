part of 'sales_repository.dart';

/// CRUD operations for sale orders: create, update, delete, and sync.
extension SalesRepositoryCrud on SalesRepository {
  Future<int?> create({
    required int partnerId,
    int? warehouseId,
    int? userId,
    String? userName,
    int? pricelistId,
    int? paymentTermId,
    bool isFinalConsumer = false,
    String? endCustomerName,
  }) async {
    // 1. ALWAYS save locally first so the UI has something to show immediately
    final tempId = await _createOffline(
      partnerId: partnerId,
      warehouseId: warehouseId,
      userId: userId,
      userName: userName,
      pricelistId: pricelistId,
      paymentTermId: paymentTermId,
      isFinalConsumer: isFinalConsumer,
      endCustomerName: endCustomerName,
    );

    if (tempId == null) return null;

    // 2. If online, try to sync to Odoo in the background
    if (_odooClient != null) {
      try {
        // Build values map with required fields
        final values = <String, dynamic>{
          'partner_id': partnerId,
        };

        if (warehouseId != null) values['warehouse_id'] = warehouseId;
        if (pricelistId != null) values['pricelist_id'] = pricelistId;
        if (paymentTermId != null) values['payment_term_id'] = paymentTermId;

        // Add Final Consumer fields if applicable
        // This is required for Ecuador when partner VAT is 9999999999999
        if (isFinalConsumer) {
          values['is_final_consumer'] = true;
          if (endCustomerName != null && endCustomerName.isNotEmpty) {
            values['end_customer_name'] = endCustomerName;
          }
        }

        final remoteId = await _odooClient.create(
          model: 'sale.order',
          values: values,
        );

        if (remoteId != null) {
          // Remove the offline queue entry since Odoo succeeded
          if (_offlineQueue != null) {
            await _offlineQueue.removeOperationsForRecord('sale.order', tempId);
          }

          // Update local record: replace temp ID with remote ID
          await _orderManager.updateSaleOrderRemoteId(tempId, remoteId);

          // Fetch full order from Odoo to get all computed fields
          await getById(remoteId, forceRefresh: true);

          logger.i(
            '[SalesRepository]',
            'Order created and synced: local $tempId -> remote $remoteId',
          );
          return remoteId;
        }
      } catch (e) {
        logger.w(
          '[SalesRepository]',
          'Online sync after local create failed, order $tempId queued for later: $e',
        );
        // Local record + offline queue entry already exist from _createOffline,
        // so no additional action needed — sync will retry later.
      }
    }

    // Return the local temp ID — offline queue will sync it later
    return tempId;
  }

  Future<int?> _createOffline({
    required int partnerId,
    int? warehouseId,
    int? userId,
    String? userName,
    int? pricelistId,
    int? paymentTermId,
    bool isFinalConsumer = false,
    String? endCustomerName,
  }) async {
    try {
      // Generate negative ID and UUID
      final tempId = await _getNextTempOrderId();
      final orderUuid = _uuid.v4();
      final now = DateTime.now();

      // Get partner data from local database
      String? partnerName;
      String? partnerVat;
      String? partnerStreet;
      String? partnerPhone;
      String? partnerEmail;

      final partner = await clientManager.getPartner(partnerId);
      if (partner != null) {
        partnerName = partner.name;
        partnerVat = partner.vat;
        partnerStreet = partner.street;
        partnerPhone = partner.phone;
        partnerEmail = partner.email;
      }

      // Get warehouse name if available
      String? warehouseName;
      if (warehouseId != null) {
        final warehouse = await warehouseManager.readLocal(warehouseId);
        warehouseName = warehouse?.name;
      }

      // Get pricelist name if available
      String? pricelistName;
      if (pricelistId != null) {
        final pricelist = await pricelistManager.readLocal(pricelistId);
        pricelistName = pricelist?.name;
      }

      // Get payment term name if available
      String? paymentTermName;
      if (paymentTermId != null) {
        final paymentTerm = await paymentTermManager.readLocal(paymentTermId);
        paymentTermName = paymentTerm?.name;
      }

      // Create order model with full partner info
      final order = SaleOrder(
        id: tempId,
        orderUuid: orderUuid,
        name: 'NUEVO$tempId', // Temporary name, will be replaced on sync
        state: SaleOrderState.draft,
        dateOrder: now,
        validityDate: now.add(const Duration(days: 30)),
        partnerId: partnerId,
        partnerName: partnerName,
        partnerVat: partnerVat,
        partnerStreet: partnerStreet,
        partnerPhone: partnerPhone,
        partnerEmail: partnerEmail,
        userId: userId,
        userName: userName,
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        pricelistId: pricelistId,
        pricelistName: pricelistName,
        paymentTermId: paymentTermId,
        paymentTermName: paymentTermName,
        isFinalConsumer: isFinalConsumer,
        endCustomerName: endCustomerName,
        isSynced: false,
        lastSyncDate: null,
        writeDate: now,
      );

      // Save to local database
      await _orderManager.upsertLocal(order);
      logger.i(
        '[SalesRepository]',
        'Created offline order: $tempId (UUID: $orderUuid)',
      );

      // Queue for sync when online
      if (_offlineQueue != null) {
        await _offlineQueue.queueOperation(
          model: 'sale.order',
          method: 'create',
          recordId: tempId,
          values: {
            'partner_id': partnerId,
            if (warehouseId != null) 'warehouse_id': warehouseId,
            if (pricelistId != null) 'pricelist_id': pricelistId,
            if (paymentTermId != null) 'payment_term_id': paymentTermId,
            if (isFinalConsumer) 'is_final_consumer': true,
            if (endCustomerName != null && endCustomerName.isNotEmpty)
              'end_customer_name': endCustomerName,
            '_uuid': orderUuid, // To map back after sync
          },
        );
      }

      return tempId;
    } catch (e) {
      logger.e('[SalesRepository]', 'Error creating offline order: $e');
      return null;
    }
  }

  Future<int> _getNextTempOrderId() async {
    // Use manager to find the minimum existing ID
    // Orders with negative IDs are offline-created; we need the next one below them
    try {
      final orders = await saleOrderManager.searchLocal(
        orderBy: 'id asc',
        limit: 1,
      );
      final minId = orders.isNotEmpty ? orders.first.id : 0;
      return minId < 0 ? minId - 1 : -1;
    } catch (e) {
      logger.w('[SalesRepository]', 'Error getting min order ID via manager, using fallback: $e');
      // Fallback: use timestamp-based negative ID to avoid collisions
      return -(DateTime.now().millisecondsSinceEpoch % 1000000000);
    }
  }

  Future<bool> update(int orderId, Map<String, dynamic> values) async {
    logger.d('[SalesRepository]', 'Updating order $orderId: $values');

    // 1. Get existing order
    final existingOrder = await _orderManager.getSaleOrder(orderId);
    if (existingOrder == null) {
      logger.w('[SalesRepository]', 'Order $orderId not found locally');
      return false;
    }

    // 2. Update local order with new values
    var updatedOrder = _applyValuesToOrder(existingOrder, values);

    // 3. Enrich with partner details from local DB if partner changed
    if (values.containsKey('partner_id')) {
      updatedOrder = await _enrichOrderWithLocalDataOnly(updatedOrder);
    }

    await _orderManager.upsertLocal(
      updatedOrder.copyWith(isSynced: false, lastSyncAttempt: DateTime.now()),
    );
    logger.d('[SalesRepository]', 'Order $orderId updated locally');

    // 4. If online, sync to Odoo
    if (_odooClient != null) {
      try {
        final success = await _odooClient.write(
          model: 'sale.order',
          ids: [orderId],
          values: values,
        );

        if (success) {
          // Mark as synced and refresh from server
          await getById(orderId, forceRefresh: true);
          logger.d('[SalesRepository]', 'Order $orderId synced to Odoo');
          return true;
        }
        // Odoo returned false - queue for retry
      } catch (e) {
        logger.w('[SalesRepository]', 'Error syncing order to Odoo: $e');
        // Fall through to queue operation
      }
    }

    // 5. Queue operation for later sync (offline or sync failed)
    if (_offlineQueue != null) {
      // For offline orders (negative ID), update the pending create operation
      // instead of queueing a separate write operation
      if (orderId < 0) {
        final updated = await _offlineQueue.updatePendingCreateValues(
          orderId,
          values,
        );
        if (updated) {
          logger.d(
            '[SalesRepository]',
            'Order $orderId: updated pending create operation with new values',
          );
          return true;
        }
        // If no pending create operation found, fall through to queue write
        logger.w(
          '[SalesRepository]',
          'Order $orderId: no pending create found, queueing write operation',
        );
      }

      await _offlineQueue.queueOperation(
        model: 'sale.order',
        method: 'write',
        recordId: orderId,
        values: values,
        // Store write_date for conflict detection when syncing
        baseWriteDate: existingOrder.writeDate,
      );
      logger.d(
        '[SalesRepository]',
        'Order $orderId queued for sync (baseWriteDate: ${existingOrder.writeDate})',
      );
    }

    return true;
  }

  SaleOrder _applyValuesToOrder(SaleOrder order, Map<String, dynamic> values) {
    var updated = order;

    if (values.containsKey('partner_id')) {
      final newPartnerId = values['partner_id'] as int?;
      // When partner changes, clear old partner details (will be enriched later)
      updated = updated.copyWith(
        partnerId: newPartnerId,
        partnerName: null,
        partnerVat: null,
        partnerStreet: null,
        partnerPhone: null,
        partnerEmail: null,
      );
    }
    if (values.containsKey('payment_term_id')) {
      final val = values['payment_term_id'];
      updated = updated.copyWith(
        paymentTermId: val == false ? null : val as int?,
      );
    }
    if (values.containsKey('pricelist_id')) {
      final val = values['pricelist_id'];
      updated = updated.copyWith(
        pricelistId: val == false ? null : val as int?,
      );
    }
    if (values.containsKey('warehouse_id')) {
      final val = values['warehouse_id'];
      updated = updated.copyWith(
        warehouseId: val == false ? null : val as int?,
      );
    }
    if (values.containsKey('user_id')) {
      final val = values['user_id'];
      updated = updated.copyWith(userId: val == false ? null : val as int?);
    }
    if (values.containsKey('note')) {
      updated = updated.copyWith(note: values['note'] as String?);
    }
    if (values.containsKey('client_order_ref')) {
      updated = updated.copyWith(
        clientOrderRef: values['client_order_ref'] as String?,
      );
    }

    // Final consumer fields (Consumidor Final)
    if (values.containsKey('is_final_consumer')) {
      updated = updated.copyWith(
        isFinalConsumer: values['is_final_consumer'] == true,
      );
    }
    if (values.containsKey('end_customer_name')) {
      final val = values['end_customer_name'];
      updated = updated.copyWith(
        endCustomerName: val == false ? null : val as String?,
      );
    }
    if (values.containsKey('end_customer_phone')) {
      final val = values['end_customer_phone'];
      updated = updated.copyWith(
        endCustomerPhone: val == false ? null : val as String?,
      );
    }
    if (values.containsKey('end_customer_email')) {
      final val = values['end_customer_email'];
      updated = updated.copyWith(
        endCustomerEmail: val == false ? null : val as String?,
      );
    }

    return updated;
  }

  Future<void> deleteLocal(int orderId) async {
    await _orderManager.deleteSaleOrderWithLines(orderId);
  }

  Future<void> _deleteOrderAndChildren(int orderId) async {
    try {
      // 1. Delete withhold lines
      await deleteAllWithholdLinesForOrder(orderId);

      // 2. Delete invoices related to this order (via managers)
      final invoices = await accountMoveManager.searchLocal(
        domain: [['sale_order_id', '=', orderId]],
      );
      for (final invoice in invoices) {
        // Delete lines first, then invoice header
        final db = _db;
        await (db.delete(db.accountMoveLine)
              ..where((tbl) => tbl.moveId.equals(invoice.id)))
            .go();
        await accountMoveManager.deleteLocal(invoice.id);
      }

      // 3. Delete order (this also deletes sale_order_line via _db.deleteSaleOrder)
      await _orderManager.deleteSaleOrderWithLines(orderId);

      logger.i(
        '[SalesRepository]',
        '🗑️ Deleted order $orderId and all child records '
        '(${invoices.length} invoices)',
      );
    } catch (e) {
      logger.e('[SalesRepository]', 'Error deleting order and children: $e');
    }
  }

  Future<bool> syncOrder(int orderId) async {
    if (_odooClient == null) {
      logger.w('[SalesRepository]', 'Cannot sync order $orderId - offline');
      return false;
    }

    final localOrder = await _orderManager.getSaleOrder(orderId);
    if (localOrder == null) {
      logger.w('[SalesRepository]', 'Order $orderId not found locally');
      return false;
    }

    if (localOrder.isSynced) {
      logger.d('[SalesRepository]', 'Order $orderId already synced');
      return true;
    }

    logger.d('[SalesRepository]', 'Syncing order $orderId to Odoo...');

    try {
      // Build values map from local order for sync
      final values = <String, dynamic>{'partner_id': localOrder.partnerId};
      if (localOrder.paymentTermId != null) {
        values['payment_term_id'] = localOrder.paymentTermId;
      }
      if (localOrder.pricelistId != null) {
        values['pricelist_id'] = localOrder.pricelistId;
      }
      if (localOrder.warehouseId != null) {
        values['warehouse_id'] = localOrder.warehouseId;
      }
      if (localOrder.userId != null) {
        values['user_id'] = localOrder.userId;
      }
      if (localOrder.note != null) {
        values['note'] = localOrder.note;
      }
      if (localOrder.clientOrderRef != null) {
        values['client_order_ref'] = localOrder.clientOrderRef;
      }
      // Final consumer fields (Consumidor Final)
      if (localOrder.isFinalConsumer) {
        values['is_final_consumer'] = true;
        if (localOrder.endCustomerName != null) {
          values['end_customer_name'] = localOrder.endCustomerName;
        }
        if (localOrder.endCustomerPhone != null) {
          values['end_customer_phone'] = localOrder.endCustomerPhone;
        }
        if (localOrder.endCustomerEmail != null) {
          values['end_customer_email'] = localOrder.endCustomerEmail;
        }
      }

      // Write changes to Odoo
      final success = await _odooClient.write(
        model: 'sale.order',
        ids: [orderId],
        values: values,
      );

      if (success) {
        // Mark as synced and refresh from server
        await getById(orderId, forceRefresh: true);
        logger.i('[SalesRepository]', 'Order $orderId synced successfully');
        return true;
      } else {
        logger.w(
          '[SalesRepository]',
          'Odoo write returned false for order $orderId',
        );
        return false;
      }
    } catch (e) {
      logger.e('[SalesRepository]', 'Error syncing order $orderId: $e');
      return false;
    }
  }
}
