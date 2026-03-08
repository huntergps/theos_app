// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'fast_sale_providers.dart';

/// Confirmation and deletion operations for FastSaleNotifier.
/// Contains credit validation, order confirmation, approval requests, and deletion.
extension FastSaleNotifierConfirm on FastSaleNotifier {
  Future<UnifiedCreditResult> validateCreditForConfirmation() async {
    logger.d('[FastSale]', 'validateCreditForConfirmation: START');
    final activeTab = state.activeTab;
    if (activeTab == null) {
      return UnifiedCreditResult.error('No hay orden activa');
    }

    final order = activeTab.order;
    if (order == null) {
      return UnifiedCreditResult.error('Orden no encontrada');
    }

    final partnerId = order.partnerId;
    if (partnerId == null) {
      return UnifiedCreditResult.error('Debe seleccionar un cliente');
    }

    try {
      // Get client from ClientRepository
      final clientRepo = ref.read(clientRepositoryProvider);
      if (clientRepo == null) {
        logger.w('[FastSale]', 'ClientRepository not available');
        return UnifiedCreditResult.proceed();
      }

      Client? client = await clientRepo.getById(partnerId);

      if (client == null) {
        logger.w('[FastSale]', 'Client $partnerId not found');
        return UnifiedCreditResult.proceed();
      }

      // Check if credit limit is configured
      if (!client.hasCreditLimit) {
        logger.d('[FastSale]', 'Client has no credit limit');
        return UnifiedCreditResult.proceed();
      }

      // Check online status
      final isOnline = clientRepo.isOnline;

      // If online and data is stale, refresh credit data
      if (isOnline && client.isCreditDataStale(1)) {
        try {
          client = await clientRepo.refreshCreditData(partnerId);
        } catch (e) {
          logger.w('[FastSale]', 'Failed to refresh credit data: $e');
        }
      }

      if (client == null) {
        return UnifiedCreditResult.proceed();
      }

      // Calculate order amount
      final orderAmount = activeTab.total;

      // Validate credit using ClientCreditService
      final creditService = ref.read(clientCreditServiceProvider);
      if (creditService == null) {
        logger.w('[FastSale]', 'ClientCreditService not available');
        return UnifiedCreditResult.proceed();
      }

      final result = await creditService.validateOrderCreditForClient(
        client: client,
        orderAmount: orderAmount,
        isOnline: isOnline,
        bypassCheck: false,
      );

      if (!result.isValid) {
        return UnifiedCreditResult.showDialog(
          client: client,
          validationResult: result,
          orderAmount: orderAmount,
          isOnline: isOnline,
        );
      }

      logger.d('[FastSale]', 'validateCreditForConfirmation: DONE - proceed');
      return UnifiedCreditResult.proceed();
    } catch (e, stack) {
      logger.e('[FastSale]', 'Error validating credit', e, stack);
      return UnifiedCreditResult.error('Error al validar crédito: $e');
    }
  }

  /// Confirm the active order (change state to 'sale')
  ///
  /// Flow:
  /// 1. Save order if has changes
  /// 2. Validate credit (caller should show dialog if needed)
  /// 3. Call action_confirm on Odoo (via OrderConfirmationService)
  /// 4. Reload order with new state
  ///
  /// [skipCreditCheck] - Skip credit validation (used after dialog approval)
  Future<bool> confirmActiveOrder({bool skipCreditCheck = false}) async {
    logger.d(
      '[FastSale]',
      'confirmActiveOrder: START (skipCreditCheck=$skipCreditCheck)',
    );
    final activeTab = state.activeTab;
    if (activeTab == null) {
      state = state.copyWith(error: 'No hay orden activa');
      return false;
    }

    final order = activeTab.order;
    if (order == null) {
      state = state.copyWith(error: 'Orden no encontrada');
      return false;
    }

    try {
      _updateActiveTab(activeTab.copyWith(isLoading: true, error: null));

      // DEBUG: Log lines before save
      logger.d('[FastSale]', '=== CONFIRM: Lines BEFORE save ===');
      logger.d('[FastSale]', 'activeTab.orderId: ${activeTab.orderId}');
      logger.d('[FastSale]', 'order.id: ${order.id}');
      logger.d('[FastSale]', 'hasChanges: ${activeTab.hasChanges}, lines count: ${activeTab.lines.length}');
      for (final line in activeTab.lines) {
        logger.d('[FastSale]', '  Line: id=${line.id}, orderId=${line.orderId}, displayType=${line.displayType}, product=${line.productName}');
      }

      // 1. Save if has unsaved changes (UI-specific pre-step)
      if (activeTab.hasChanges) {
        final saved = await saveActiveOrder();
        if (!saved) {
          _updateActiveTab(activeTab.copyWith(isLoading: false));
          return false;
        }
      }

      // Get current order state after save
      final currentTab = state.activeTab;
      if (currentTab == null) {
        state = state.copyWith(error: 'No hay pestaña activa después de guardar');
        return false;
      }
      final currentOrder = currentTab.order ?? order;

      // DEBUG: Log lines after save
      logger.d('[FastSale]', '=== CONFIRM: Lines AFTER save ===');
      logger.d('[FastSale]', 'lines count: ${currentTab.lines.length}');
      for (final line in currentTab.lines) {
        logger.d('[FastSale]', '  Line: id=${line.id}, orderId=${line.orderId}, displayType=${line.displayType}, product=${line.productName}');
      }
      final productLines = currentTab.lines.where((l) => l.isProductLine).toList();
      logger.d('[FastSale]', 'Product lines count: ${productLines.length}');

      // 2. Use OrderConfirmationService for unified confirmation logic
      logger.d('[FastSale]', '=== Calling confirmationService.confirmOrder ===');
      logger.d('[FastSale]', 'Order ID: ${currentOrder.id}, Name: ${currentOrder.name}');
      final confirmationService = ref.read(orderConfirmationServiceProvider);
      final result = await confirmationService.confirmOrder(
        order: currentOrder,
        lines: currentTab.lines,
        skipCreditCheck: skipCreditCheck,
        usePosConfirm: true, // Use POS-specific confirmation
        creditBypassed: skipCreditCheck,
      );
      logger.d('[FastSale]', '=== confirmOrder returned ===');
      logger.d('[FastSale]', 'success=${result.success}, error=${result.error}, hasCreditIssue=${result.hasCreditIssue}');

      // 3. Handle result
      if (!result.success) {
        _updateActiveTab(currentTab.copyWith(isLoading: false));

        // Handle credit issue - convert to legacy format for UI compatibility
        if (result.hasCreditIssue && result.creditResult != null) {
          final creditResult = result.creditResult!;
          final validation = creditResult.validationResult;
          // Convert UnifiedCreditResult to CreditIssue for UI dialog
          final creditIssue = CreditIssue(
            type: validation?.type == CreditCheckType.creditLimitExceeded
                ? 'credit_limit_exceeded'
                : validation?.type == CreditCheckType.overdueDebt
                ? 'overdue_debt'
                : 'credit_blocked',
            message: validation?.message ?? 'Problema de crédito',
            partnerId: currentOrder.partnerId ?? 0,
            partnerName: currentOrder.partnerName ?? '',
            creditLimit: creditResult.client?.creditLimit,
            creditUsed: creditResult.client?.credit,
            creditAvailable: validation?.creditAvailable,
            excessAmount: validation?.creditExceededAmount,
            orderAmount: creditResult.orderAmount,
          );
          state = state.copyWith(
            error: creditIssue.message,
            lastCreditIssue: creditIssue,
          );
          logger.w('[FastSale]', 'Credit issue: ${creditIssue.type}');
          return false;
        }

        state = state.copyWith(error: result.error ?? 'Error al confirmar');
        return false;
      }

      logger.i(
        '[FastSale]',
        'Order confirmed successfully via OrderConfirmationService',
      );

      // 4. Update tab with confirmed order
      final confirmedTab = FastSaleTabState(
        orderId: result.confirmedOrder?.id ?? currentTab.orderId,
        orderName: result.confirmedOrder?.name ?? currentTab.orderName,
        order: result.confirmedOrder,
        lines: result.confirmedLines ?? [],
        hasChanges: false,
        partnerPaymentTermIds: currentTab.partnerPaymentTermIds,
      );

      _updateActiveTab(confirmedTab);

      // Invalidate providers for reactivity
      ref.invalidate(saleOrderFormProvider);
      final confirmedOrder = result.confirmedOrder;
      if (confirmedOrder != null) {
        ref.invalidate(saleOrderWithLinesProvider(confirmedOrder.id));
      }

      logger.i(
        '[FastSale]',
        'Order ${result.confirmedOrder?.id} confirmed successfully',
      );
      return true;
    } catch (e, stack) {
      logger.e('[FastSale]', 'Error confirming order', e, stack);
      _updateActiveTab(activeTab.copyWith(isLoading: false, error: null));
      state = state.copyWith(error: 'Error al confirmar: $e');
      return false;
    }
  }

  /// Create credit approval request for active order
  Future<int?> createCreditApprovalRequest({
    required String reason,
    required String checkType,
  }) async {
    final activeTab = state.activeTab;
    if (activeTab == null) return null;

    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo == null) return null;

    final order = activeTab.order;
    final partnerId = order?.partnerId;
    if (order == null || partnerId == null) return null;

    try {
      final approvalId = await salesRepo.createCreditApprovalRequest(
        orderId: activeTab.orderId,
        partnerId: partnerId,
        amount: activeTab.total,
        reason: reason,
        checkType: checkType,
        paymentTermId: order.paymentTermId,
      );

      if (approvalId != null) {
        // Reload order to get 'waiting' state
        final (updatedOrder, updatedLines) = await salesRepo.getWithLines(
          activeTab.orderId,
          forceRefresh: true,
        );

        final updatedTab = activeTab.copyWith(
          order: updatedOrder,
          lines: updatedLines,
          hasChanges: false,
        );
        _updateActiveTab(updatedTab);
      }

      return approvalId;
    } catch (e, stack) {
      logger.e('[FastSale]', 'Error creating approval request', e, stack);
      state = state.copyWith(error: 'Error al crear solicitud: $e');
      return null;
    }
  }

  /// Delete the active order from local database
  ///
  /// Only allows deleting unsynced (local) orders.
  Future<bool> deleteActiveOrder() async {
    final activeTab = state.activeTab;
    if (activeTab == null) return false;

    final order = activeTab.order;
    if (order == null) return false;

    // Only allow deleting unsynced orders
    if (order.isSynced) {
      state = state.copyWith(
        error: 'No se puede eliminar una orden ya sincronizada con el servidor',
      );
      return false;
    }

    try {
      await saleOrderManager.deleteSaleOrderWithLines(activeTab.orderId);

      logger.i('[FastSale]', 'Order deleted: ${activeTab.orderId}');

      // Invalidate providers so other screens reload from database
      ref.invalidate(saleOrderFormProvider);
      ref.invalidate(saleOrderWithLinesProvider(activeTab.orderId));

      // Remove tab from state
      final newTabs = List<FastSaleTabState>.from(state.tabs);
      newTabs.removeAt(state.activeTabIndex);

      // If no tabs left, show empty state
      if (newTabs.isEmpty) {
        state = state.copyWith(tabs: [], activeTabIndex: -1, isLoading: false);
      } else {
        // Switch to previous tab or first tab
        final newIndex = state.activeTabIndex > 0
            ? state.activeTabIndex - 1
            : 0;
        state = state.copyWith(tabs: newTabs, activeTabIndex: newIndex);
      }

      return true;
    } catch (e) {
      logger.e('[FastSale]', 'Error deleting order: $e');
      state = state.copyWith(error: 'Error al eliminar: $e');
      return false;
    }
  }
}
