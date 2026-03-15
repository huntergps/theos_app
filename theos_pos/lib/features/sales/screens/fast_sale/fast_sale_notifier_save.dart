// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'fast_sale_providers.dart';

/// Save operations for FastSaleNotifier.
/// Contains the saveActiveOrder method for persisting order data.
extension FastSaleNotifierSave on FastSaleNotifier {
  Future<bool> saveActiveOrder() async {
    final activeTab = state.activeTab;
    if (activeTab == null) return false;

    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo == null) return false;

    final order = activeTab.order;
    if (order == null) return false;

    // Validate partner
    if (order.partnerId == null) {
      state = state.copyWith(error: 'Debe seleccionar un cliente');
      return false;
    }

    // Validate final consumer (replica _check_final_consumer_name de Odoo)
    // Si el partner es consumidor final, end_customer_name es obligatorio
    if (order.isFinalConsumer &&
        (order.endCustomerName == null ||
            order.endCustomerName!.trim().isEmpty)) {
      state = state.copyWith(
        error:
            'El nombre del consumidor final es obligatorio cuando el cliente es Consumidor Final.',
      );
      return false;
    }

    try {
      final updatedTab = activeTab.copyWith(isLoading: true, error: null);
      _updateActiveTab(updatedTab);

      int orderId = activeTab.orderId;

      // Save/update order header to local database
      await saleOrderManager.upsertLocal(
        order.copyWith(isSynced: false, writeDate: DateTime.now()),
      );
      logger.d('[FastSale]', 'Order header saved: $orderId');

      // Fire-and-forget: sync header fields to Odoo for existing orders
      if (orderId > 0) {
        final headerVals = <String, dynamic>{
          if (order.partnerId != null) 'partner_id': order.partnerId,
          if (order.pricelistId != null) 'pricelist_id': order.pricelistId,
          if (order.paymentTermId != null)
            'payment_term_id': order.paymentTermId,
          if (order.warehouseId != null) 'warehouse_id': order.warehouseId,
          if (order.userId != null) 'user_id': order.userId,
          if (order.teamId != null) 'team_id': order.teamId,
          if (order.fiscalPositionId != null)
            'fiscal_position_id': order.fiscalPositionId,
          if (order.dateOrder != null)
            'date_order': order.dateOrder!.toIso8601String(),
          if (order.note != null) 'note': order.note,
          if (order.clientOrderRef != null)
            'client_order_ref': order.clientOrderRef,
          'is_final_consumer': order.isFinalConsumer,
          if (order.endCustomerName != null &&
              order.endCustomerName!.isNotEmpty)
            'end_customer_name': order.endCustomerName,
          if (order.endCustomerPhone != null &&
              order.endCustomerPhone!.isNotEmpty)
            'end_customer_phone': order.endCustomerPhone,
          if (order.endCustomerEmail != null &&
              order.endCustomerEmail!.isNotEmpty)
            'end_customer_email': order.endCustomerEmail,
          if (order.referrerId != null) 'referrer_id': order.referrerId,
        };

        if (headerVals.isNotEmpty) {
          salesRepo.update(orderId, headerVals).then((_) {
            logger.d('[FastSale]', 'Header synced to Odoo for order $orderId');
          }).catchError((e) {
            logger.w('[FastSale]',
                'Background header sync failed (will retry later): $e');
          });
        }
      }

      // Queue order for sync if it's a new order (negative ID)
      // This ensures offline-first: the queue will sync the order to Odoo
      // when connectivity is available. The confirmation service checks
      // if the queue already synced (positive ID) to avoid duplication.
      if (orderId < 0) {
        final offlineQueue = ref.read(offlineQueueDataSourceProvider);
        if (offlineQueue != null) {
          // Check if there's already a pending create for this order
          final existingOps = await offlineQueue.getOperationsForRecord(
            'sale.order',
            orderId,
          );
          final hasCreate = existingOps.any((op) => op.method == 'create');
          if (!hasCreate) {
            await offlineQueue.queueOperation(
              model: 'sale.order',
              method: 'create',
              recordId: orderId,
              values: {
                'partner_id': order.partnerId,
                if (order.warehouseId != null) 'warehouse_id': order.warehouseId,
                if (order.pricelistId != null) 'pricelist_id': order.pricelistId,
                if (order.paymentTermId != null)
                  'payment_term_id': order.paymentTermId,
                // Campos de consumidor final
                if (order.isFinalConsumer) 'is_final_consumer': true,
                if (order.endCustomerName != null &&
                    order.endCustomerName!.isNotEmpty)
                  'end_customer_name': order.endCustomerName,
                if (order.endCustomerPhone != null &&
                    order.endCustomerPhone!.isNotEmpty)
                  'end_customer_phone': order.endCustomerPhone,
                if (order.endCustomerEmail != null &&
                    order.endCustomerEmail!.isNotEmpty)
                  'end_customer_email': order.endCustomerEmail,
                // Referidor
                if (order.referrerId != null) 'referrer_id': order.referrerId,
                '_uuid': order.orderUuid ?? '',
              },
            );
            logger.i('[FastSale]', 'Order $orderId queued for sync');
          } else {
            // Update existing create operation with latest values
            await offlineQueue.updatePendingCreateValues(orderId, {
              'partner_id': order.partnerId,
              if (order.warehouseId != null) 'warehouse_id': order.warehouseId,
              if (order.pricelistId != null) 'pricelist_id': order.pricelistId,
              if (order.paymentTermId != null)
                'payment_term_id': order.paymentTermId,
              if (order.isFinalConsumer) 'is_final_consumer': true,
              if (order.endCustomerName != null &&
                  order.endCustomerName!.isNotEmpty)
                'end_customer_name': order.endCustomerName,
              if (order.endCustomerPhone != null &&
                  order.endCustomerPhone!.isNotEmpty)
                'end_customer_phone': order.endCustomerPhone,
              if (order.endCustomerEmail != null &&
                  order.endCustomerEmail!.isNotEmpty)
                'end_customer_email': order.endCustomerEmail,
              if (order.referrerId != null) 'referrer_id': order.referrerId,
              '_uuid': order.orderUuid ?? '',
            });
            logger.d('[FastSale]', 'Updated pending create for order $orderId');
          }
        }
      }

      // Save lines using upsert to avoid duplicates
      // NOTE: Lines with id < 0 are already saved to DB by _saveLineToDatabase when
      // the product was added. Using addLine here would create duplicates because
      // addLine generates new IDs and UUIDs. Instead, we use upsertSaleOrderLine
      // which updates if exists or creates if not.
      logger.d('[FastSale]', '=== SAVE: Saving ${activeTab.lines.length} lines for orderId=$orderId ===');
      for (final line in activeTab.lines) {
        logger.d('[FastSale]', '  Processing line: id=${line.id}, orderId=${line.orderId}, product=${line.productName}');
        final lineWithOrderId = line.copyWith(orderId: orderId);
        // Use upsert to avoid creating duplicate lines
        // This handles both new lines (id < 0) and existing lines (id >= 0)
        await saleOrderLineManager.upsertLocal(lineWithOrderId);
        logger.d('[FastSale]', '    -> Upserted line ${line.id}');
      }

      // Handle deleted lines (lines that were in DB but not in current state)
      logger.d('[FastSale]', '=== SAVE: Checking for deleted lines ===');
      final dbLines = await saleOrderLineManager.getSaleOrderLines(orderId);
      logger.d('[FastSale]', '  DB has ${dbLines.length} lines for orderId=$orderId');
      for (final dbLine in dbLines) {
        logger.d('[FastSale]', '    DB Line: id=${dbLine.id}, orderId=${dbLine.orderId}');
      }
      final currentLineIds = activeTab.lines.map((l) => l.id).toSet();
      logger.d('[FastSale]', '  State has line IDs: $currentLineIds');
      for (final dbLine in dbLines) {
        if (!currentLineIds.contains(dbLine.id)) {
          logger.d('[FastSale]', '  Deleting line ${dbLine.id} (not in current state)');
          await salesRepo.deleteLine(dbLine.id);
        }
      }

      // Reload lines from database (order header is already updated in memory)
      // NOTE: We do NOT reload the order header to avoid race conditions with
      // WebSocket notifications that may contain stale partner data.
      // The order header we just saved is the source of truth.
      logger.d('[FastSale]', '=== SAVE: Reloading lines from database for orderId=$orderId ===');
      final (_, savedLines) = await salesRepo.getWithLines(
        orderId,
        forceRefresh: false,
      );
      logger.d('[FastSale]', '=== SAVE: Loaded ${savedLines.length} lines from DB ===');
      for (final line in savedLines) {
        logger.d('[FastSale]', '  DB Line: id=${line.id}, orderId=${line.orderId}, displayType=${line.displayType}, product=${line.productName}');
      }

      // Preserve the order header we just saved (including the partner we just set)
      // Only update the lines from the database
      final savedTab = FastSaleTabState(
        orderId: orderId,
        orderName: order.name,
        order: order.copyWith(
          isSynced: false,
          writeDate: DateTime.now(),
        ),
        lines: savedLines,
        hasChanges: false,
        // Preserve the authorized payment term IDs
        partnerPaymentTermIds: activeTab.partnerPaymentTermIds,
      );

      _updateActiveTab(savedTab);

      // Invalidate providers so other screens reload from database
      // This ensures changes from POS are visible everywhere in the app
      ref.invalidate(saleOrderFormProvider);
      ref.invalidate(saleOrderWithLinesProvider(orderId));

      logger.i('[FastSale]', 'Order saved: $orderId with ${savedLines.length} lines');
      return true;
    } catch (e, stack) {
      logger.e('[FastSale]', 'Error saving order', e, stack);
      _updateActiveTab(activeTab.copyWith(isLoading: false, error: null));
      state = state.copyWith(error: 'Error al guardar: $e');
      return false;
    }
  }
}
