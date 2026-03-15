// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'fast_sale_providers.dart';

/// Extension on [FastSaleNotifier] for customer management operations.
///
/// Includes: setting customer, toggling customer panel, updating order fields,
/// partner phone/email, end customer fields (consumidor final), and referrer.
extension FastSaleNotifierCustomer on FastSaleNotifier {
  // ============================================================
  // CUSTOMER MANAGEMENT
  // ============================================================

  /// Set customer for active order
  ///
  /// Also handles:
  /// - Payment term IDs filtering (authorized terms for this customer)
  /// - Default payment term from customer's property_payment_term_id
  ///
  /// Returns early if order is not editable.
  Future<void> setCustomer({
    required int partnerId,
    required String partnerName,
    String? partnerVat,
    String? partnerStreet,
    String? partnerPhone,
    String? partnerEmail,
    String? partnerAvatar,
    List<int>? paymentTermIds,
    int? propertyPaymentTermId,
    String? propertyPaymentTermName,
  }) async {
    logger.i(
      '[FastSale]',
      '>>> setCustomer CALLED: partnerId=$partnerId, partnerName=$partnerName, vat=$partnerVat',
    );

    // Block if order is not editable
    if (!_ensureCanModify('setCustomer')) {
      logger.w('[FastSale]', '>>> setCustomer: Order is not editable, returning');
      return;
    }

    final activeTab = state.activeTab;
    if (activeTab == null) {
      logger.w('[FastSale]', '>>> setCustomer: No active tab, returning');
      return;
    }

    logger.d(
      '[FastSale]',
      '>>> setCustomer: Current partner in tab: ${activeTab.order?.partnerId}/${activeTab.order?.partnerName}',
    );

    // Load authorized payment term IDs from Odoo if not provided
    List<int> authorizedPaymentTermIds = paymentTermIds ?? [];
    if (authorizedPaymentTermIds.isEmpty) {
      authorizedPaymentTermIds = await _loadPartnerPaymentTermIds(partnerId);
    }

    // Determine new payment term
    int? newPaymentTermId = activeTab.order?.paymentTermId;
    String? newPaymentTermName = activeTab.order?.paymentTermName;

    // If partner has a default payment term, use it
    if (propertyPaymentTermId != null) {
      newPaymentTermId = propertyPaymentTermId;
      newPaymentTermName = propertyPaymentTermName;
      newPaymentTermName ??= await _lookupName(
        'account_payment_term',
        propertyPaymentTermId,
      );
    } else if (authorizedPaymentTermIds.isNotEmpty &&
        newPaymentTermId != null &&
        !authorizedPaymentTermIds.contains(newPaymentTermId)) {
      // If current payment term is not in the authorized list, clear it
      newPaymentTermId = null;
      newPaymentTermName = null;
    }

    // Determine if this is a Final Consumer based on VAT
    final isFinalConsumer = partnerVat == '9999999999999';

    final updatedOrder =
        (activeTab.order ??
                SaleOrder(
                  id: activeTab.orderId,
                  name: activeTab.orderName,
                  state: SaleOrderState.draft,
                ))
            .copyWith(
              partnerId: partnerId,
              partnerName: partnerName,
              partnerVat: partnerVat,
              partnerStreet: partnerStreet,
              partnerPhone: partnerPhone,
              partnerEmail: partnerEmail,
              partnerAvatar: partnerAvatar,
              isFinalConsumer: isFinalConsumer,
              // Clear endCustomerName when switching to non-final consumer
              endCustomerName: isFinalConsumer
                  ? activeTab.order?.endCustomerName
                  : null,
              paymentTermId: newPaymentTermId,
              paymentTermName: newPaymentTermName,
            );

    final updatedTab = activeTab.copyWith(
      order: updatedOrder,
      hasChanges: true,
      partnerPaymentTermIds: authorizedPaymentTermIds,
    );

    logger.i(
      '[FastSale]',
      '>>> setCustomer: About to call _updateActiveTab with partner ${updatedOrder.partnerId}/${updatedOrder.partnerName}',
    );

    _updateActiveTab(updatedTab);

    logger.i(
      '[FastSale]',
      '>>> setCustomer: _updateActiveTab DONE. Verifying state...',
    );

    // Verify state after update
    final verifyTab = state.activeTab;
    logger.d(
      '[FastSale]',
      '>>> setCustomer: After _updateActiveTab, state.activeTab.order.partner = '
      '${verifyTab?.order?.partnerId}/${verifyTab?.order?.partnerName}',
    );

    logger.d(
      '[FastSale]',
      'Customer set: $partnerName (ID: $partnerId), '
          'paymentTermIds: $authorizedPaymentTermIds, defaultTerm: $newPaymentTermId',
    );

    // Auto-save to local database
    logger.d('[FastSale]', '>>> setCustomer: About to call saveActiveOrder...');
    await saveActiveOrder();
    logger.d('[FastSale]', '>>> setCustomer: saveActiveOrder DONE');

    // Final verification
    final finalTab = state.activeTab;
    logger.i(
      '[FastSale]',
      '>>> setCustomer COMPLETE. Final partner: ${finalTab?.order?.partnerId}/${finalTab?.order?.partnerName}',
    );
  }

  /// Toggle customer panel expansion
  void toggleCustomerPanel() {
    state = state.copyWith(
      isCustomerPanelExpanded: !state.isCustomerPanelExpanded,
    );
  }

  /// Update a field in the active order
  ///
  /// Supports fields: date_order, pricelist_id, payment_term_id, warehouse_id, user_id
  /// Auto-saves to local database after update.
  /// Returns early if order is not editable.
  Future<void> updateOrderField(String field, dynamic value) async {
    // Block if order is not editable
    if (!_ensureCanModify('updateOrderField')) return;

    final activeTab = state.activeTab;
    if (activeTab == null) return;

    final currentOrder =
        activeTab.order ??
        SaleOrder(
          id: activeTab.orderId,
          name: activeTab.orderName,
          state: SaleOrderState.draft,
        );

    SaleOrder updatedOrder;
    switch (field) {
      case 'date_order':
        updatedOrder = currentOrder.copyWith(dateOrder: value as DateTime?);
        break;
      case 'pricelist_id':
        final pricelistId = value as int?;
        String? pricelistName;
        if (pricelistId != null) {
          pricelistName = await _lookupName('product_pricelist', pricelistId);
        }
        updatedOrder = currentOrder.copyWith(
          pricelistId: pricelistId,
          pricelistName: pricelistName,
        );
        break;
      case 'payment_term_id':
        final paymentTermId = value as int?;
        String? paymentTermName;
        if (paymentTermId != null) {
          paymentTermName = await _lookupName(
            'account_payment_term',
            paymentTermId,
          );
        }
        updatedOrder = currentOrder.copyWith(
          paymentTermId: paymentTermId,
          paymentTermName: paymentTermName,
        );
        break;
      case 'warehouse_id':
        final warehouseId = value as int?;
        String? warehouseName;
        if (warehouseId != null) {
          warehouseName = await _lookupName('stock_warehouse', warehouseId);
        }
        updatedOrder = currentOrder.copyWith(
          warehouseId: warehouseId,
          warehouseName: warehouseName,
        );
        break;
      case 'user_id':
        final userId = value as int?;
        String? userName;
        if (userId != null) {
          userName = await _lookupName('res_users', userId);
        }
        updatedOrder = currentOrder.copyWith(
          userId: userId,
          userName: userName,
        );
        break;
      default:
        logger.w('[FastSale]', 'Unknown field: $field');
        return;
    }

    final updatedTab = activeTab.copyWith(
      order: updatedOrder,
      hasChanges: true,
    );

    _updateActiveTab(updatedTab);

    // Auto-save to local database
    await saveActiveOrder();
  }

  /// Update partner phone and sync to Odoo
  ///
  /// Updates local state immediately and sends change to Odoo.
  /// Returns early if order is not editable.
  Future<void> updatePartnerPhone(String phone) async {
    // Block if order is not editable
    if (!_ensureCanModify('updatePartnerPhone')) return;

    final activeTab = state.activeTab;
    final order = activeTab?.order;
    final partnerId = order?.partnerId;
    if (activeTab == null || order == null || partnerId == null) return;

    final oldPhone = order.partnerPhone;

    // Update local state immediately
    final updatedOrder = order.copyWith(partnerPhone: phone);
    final updatedTab = activeTab.copyWith(
      order: updatedOrder,
      hasChanges: true,
    );
    _updateActiveTab(updatedTab);

    final partnerRepo = ref.read(partnerRepositoryProvider);
    if (partnerRepo == null) return;

    await partner_utils.updatePartnerField(
      partnerId: partnerId,
      fieldName: 'phone',
      newValue: phone,
      partnerRepo: partnerRepo,
      logTag: '[FastSale]',
      onFailure: (error) {
        // Revert state on failure
        final revertedOrder = order.copyWith(partnerPhone: oldPhone);
        final revertedTab = activeTab.copyWith(order: revertedOrder);
        _updateActiveTab(revertedTab);
        state = state.copyWith(error: error);
      },
    );
  }

  /// Update partner email and sync to Odoo
  ///
  /// Updates local state immediately and sends change to Odoo.
  /// Returns early if order is not editable.
  Future<void> updatePartnerEmail(String email) async {
    // Block if order is not editable
    if (!_ensureCanModify('updatePartnerEmail')) return;

    final activeTab = state.activeTab;
    final order = activeTab?.order;
    final partnerId = order?.partnerId;
    if (activeTab == null || order == null || partnerId == null) return;

    final oldEmail = order.partnerEmail;

    // Update local state immediately
    final updatedOrder = order.copyWith(partnerEmail: email);
    final updatedTab = activeTab.copyWith(
      order: updatedOrder,
      hasChanges: true,
    );
    _updateActiveTab(updatedTab);

    final partnerRepo = ref.read(partnerRepositoryProvider);
    if (partnerRepo == null) return;

    await partner_utils.updatePartnerField(
      partnerId: partnerId,
      fieldName: 'email',
      newValue: email,
      partnerRepo: partnerRepo,
      logTag: '[FastSale]',
      onFailure: (error) {
        // Revert state on failure
        final revertedOrder = order.copyWith(partnerEmail: oldEmail);
        final revertedTab = activeTab.copyWith(order: revertedOrder);
        _updateActiveTab(revertedTab);
        state = state.copyWith(error: error);
      },
    );
  }

  // ============================================================
  // END CUSTOMER FIELDS (Consumidor Final)
  // ============================================================

  /// Update end customer name for final consumer orders.
  ///
  /// Updates in-memory state immediately for UI responsiveness,
  /// but debounces the DB persist to avoid excessive writes on every keystroke.
  void updateEndCustomerName(String name) {
    final activeTab = state.activeTab;
    final order = activeTab?.order;
    if (activeTab == null || order == null) return;

    final updatedOrder = order.copyWith(endCustomerName: name);
    final updatedTab = activeTab.copyWith(
      order: updatedOrder,
      hasChanges: true,
    );
    _updateActiveTab(updatedTab);

    logger.d('[FastSale]', 'Updated end customer name (in-memory): $name');

    // Debounce: persist to DB only after user stops typing
    _debounceSaveEndCustomer();
  }

  /// Update end customer phone for final consumer orders.
  ///
  /// Updates in-memory state immediately for UI responsiveness,
  /// but debounces the DB persist to avoid excessive writes on every keystroke.
  void updateEndCustomerPhone(String phone) {
    final activeTab = state.activeTab;
    final order = activeTab?.order;
    if (activeTab == null || order == null) return;

    final updatedOrder = order.copyWith(endCustomerPhone: phone);
    final updatedTab = activeTab.copyWith(
      order: updatedOrder,
      hasChanges: true,
    );
    _updateActiveTab(updatedTab);

    logger.d('[FastSale]', 'Updated end customer phone (in-memory): $phone');

    // Debounce: persist to DB only after user stops typing
    _debounceSaveEndCustomer();
  }

  /// Update end customer email for final consumer orders.
  ///
  /// Updates in-memory state immediately for UI responsiveness,
  /// but debounces the DB persist to avoid excessive writes on every keystroke.
  void updateEndCustomerEmail(String email) {
    final activeTab = state.activeTab;
    final order = activeTab?.order;
    if (activeTab == null || order == null) return;

    final updatedOrder = order.copyWith(endCustomerEmail: email);
    final updatedTab = activeTab.copyWith(
      order: updatedOrder,
      hasChanges: true,
    );
    _updateActiveTab(updatedTab);

    logger.d('[FastSale]', 'Updated end customer email (in-memory): $email');

    // Debounce: persist to DB only after user stops typing
    _debounceSaveEndCustomer();
  }

  /// Debounce helper: resets the timer on each call, only saves after 500ms idle.
  void _debounceSaveEndCustomer() {
    _endCustomerDebounceTimer?.cancel();
    _endCustomerDebounceTimer = Timer(
      const Duration(milliseconds: 500),
      () async {
        logger.d('[FastSale]', 'Debounce fired: saving end customer fields');
        await saveActiveOrder();
      },
    );
  }

  /// Set the referrer for the active order
  Future<void> setReferrer({required int referrerId, required String referrerName}) async {
    final activeTab = state.activeTab;
    final order = activeTab?.order;
    if (activeTab == null || order == null) return;

    final updatedOrder = order.copyWith(
      referrerId: referrerId,
      referrerName: referrerName,
    );
    final updatedTab = activeTab.copyWith(
      order: updatedOrder,
      hasChanges: true,
    );
    _updateActiveTab(updatedTab);

    logger.d('[FastSale]', 'Set referrer: $referrerName (ID: $referrerId)');

    // Persist to local DB + fire-and-forget sync to Odoo
    await saveActiveOrder();
  }
}
