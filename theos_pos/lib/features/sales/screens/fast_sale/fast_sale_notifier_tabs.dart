// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'fast_sale_providers.dart';

/// Tab management for FastSaleNotifier.
///
/// Handles creating, switching, closing, and loading order tabs,
/// as well as background sync of Odoo defaults and partner data lookup.
extension FastSaleNotifierTabs on FastSaleNotifier {
  /// Add a new order tab
  ///
  /// Uses TRUE OFFLINE-FIRST approach:
  /// 1. Uses OrderService to create order with local defaults (instant)
  /// 2. Shows UI immediately with local defaults
  /// 3. Optionally syncs with Odoo in background (if online)
  ///
  /// Does not set global loading state to avoid UI flicker.
  Future<void> addNewTab() async {
    try {
      logger.d(
        '[FastSale]',
        'addNewTab: Creating new order tab (offline-first)...',
      );

      // Step 1: Use OrderService to create order with local defaults
      final orderService = ref.read(orderServiceProvider);
      final baseOrder = await orderService.createOrder();

      if (baseOrder.userId == null) {
        logger.w('[FastSale]', 'No current user for addNewTab');
        state = state.copyWith(error: 'Usuario no autenticado');
        return;
      }

      // Step 2: Load complete partner data from local database
      String? partnerVat;
      String? partnerPhone;
      String? partnerEmail;
      String? partnerStreet;
      String? partnerAvatar;

      if (baseOrder.partnerId != null) {
        final partnerData = await _loadPartnerData(baseOrder.partnerId!);
        if (partnerData != null) {
          partnerVat = partnerData.vat;
          partnerPhone = partnerData.phone;
          partnerEmail = partnerData.email;
          partnerStreet = partnerData.street;
          partnerAvatar = partnerData.avatar;
        }
      }

      // Step 3: Create final order with partner extra data
      final tempId = baseOrder.id;
      final nextNumber = state.newOrderCounter + 1;
      final orderName = 'Nueva $nextNumber';

      // Determine if this is a Final Consumer based on VAT
      final isFinalConsumer = partnerVat == '9999999999999';

      final localOrder = baseOrder.copyWith(
        name: orderName,
        validityDate: DateTime.now().add(const Duration(days: 30)),
        partnerVat: partnerVat,
        partnerPhone: partnerPhone,
        partnerEmail: partnerEmail,
        partnerStreet: partnerStreet,
        partnerAvatar: partnerAvatar,
        isFinalConsumer: isFinalConsumer,
        isSynced: false,
      );

      // Step 4: Create tab and update state immediately
      final newTab = FastSaleTabState(
        orderId: tempId,
        orderName: orderName,
        order: localOrder,
        hasChanges: true,
      );

      state = state.copyWith(
        tabs: [...state.tabs, newTab],
        activeTabIndex: state.tabs.length,
        newOrderCounter: nextNumber,
      );

      logger.i(
        '[FastSale]',
        'Added new tab "$orderName" (offline-first): partner=${localOrder.partnerName}, '
            'warehouse=${localOrder.warehouseName}, pricelist=${localOrder.pricelistName}',
      );

      // Step 5: (Optional) Sync with Odoo in background using OrderService
      _syncDefaultsFromOdooInBackground(tempId);
    } catch (e, stack) {
      logger.e('[FastSale]', 'Error adding new tab: $e', e, stack);
      state = state.copyWith(error: 'Error al crear nueva orden: $e');
    }
  }

  /// Background sync of defaults from Odoo (non-blocking)
  ///
  /// Updates the order with fresh Odoo defaults if local values were null.
  /// This is called after the UI is already responsive with local defaults.
  void _syncDefaultsFromOdooInBackground(int orderId) async {
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) return;

      final odooDefaults = await salesRepo.getDefaultValues();
      if (odooDefaults.isEmpty) return;

      logger.d(
        '[FastSale]',
        'Background Odoo defaults received: $odooDefaults',
      );

      // Find the tab for this order
      final tabIndex = state.tabs.indexWhere((t) => t.orderId == orderId);
      if (tabIndex < 0) return;

      final tab = state.tabs[tabIndex];
      final order = tab.order;
      if (order == null) return;

      // Check if we need to update missing values from Odoo
      bool needsUpdate = false;
      SaleOrder updatedOrder = order;

      // Apply pricelist if local was null
      if (order.pricelistId == null && odooDefaults['pricelist_id'] != null) {
        int? pricelistId;
        String? pricelistName;
        if (odooDefaults['pricelist_id'] is List &&
            (odooDefaults['pricelist_id'] as List).isNotEmpty) {
          pricelistId = (odooDefaults['pricelist_id'] as List)[0] as int?;
          if ((odooDefaults['pricelist_id'] as List).length > 1) {
            pricelistName =
                (odooDefaults['pricelist_id'] as List)[1] as String?;
          }
        } else if (odooDefaults['pricelist_id'] is int) {
          pricelistId = odooDefaults['pricelist_id'] as int;
          // Lookup name from local DB
          pricelistName = await _lookupName('product_pricelist', pricelistId);
        }
        if (pricelistId != null) {
          updatedOrder = updatedOrder.copyWith(
            pricelistId: pricelistId,
            pricelistName: pricelistName,
          );
          needsUpdate = true;
          logger.d(
            '[FastSale]',
            'Applying Odoo pricelist: $pricelistId ($pricelistName)',
          );
        }
      }

      // Apply payment term if local was null
      if (order.paymentTermId == null &&
          odooDefaults['payment_term_id'] != null) {
        int? paymentTermId;
        String? paymentTermName;
        if (odooDefaults['payment_term_id'] is List &&
            (odooDefaults['payment_term_id'] as List).isNotEmpty) {
          paymentTermId = (odooDefaults['payment_term_id'] as List)[0] as int?;
          if ((odooDefaults['payment_term_id'] as List).length > 1) {
            paymentTermName =
                (odooDefaults['payment_term_id'] as List)[1] as String?;
          }
        } else if (odooDefaults['payment_term_id'] is int) {
          paymentTermId = odooDefaults['payment_term_id'] as int;
          // Lookup name from local DB
          paymentTermName = await _lookupName(
            'account_payment_term',
            paymentTermId,
          );
        }
        if (paymentTermId != null) {
          updatedOrder = updatedOrder.copyWith(
            paymentTermId: paymentTermId,
            paymentTermName: paymentTermName,
          );
          needsUpdate = true;
          logger.d(
            '[FastSale]',
            'Applying Odoo paymentTerm: $paymentTermId ($paymentTermName)',
          );
        }
      }

      // Update state if we applied any Odoo defaults
      if (needsUpdate) {
        final updatedTab = tab.copyWith(order: updatedOrder);
        final newTabs = List<FastSaleTabState>.from(state.tabs);
        newTabs[tabIndex] = updatedTab;
        state = state.copyWith(tabs: newTabs);
        logger.i(
          '[FastSale]',
          'Order updated with Odoo defaults for missing fields',
        );
      }
    } catch (e) {
      // Silent failure - background sync shouldn't affect user experience
      logger.d('[FastSale]', 'Background Odoo sync skipped: $e');
    }
  }

  /// Lookup name from local DB by manager type and ID
  Future<String?> _lookupName(String table, int odooId) async {
    try {
      switch (table) {
        case 'product_pricelist':
          final record = await pricelistManager.readLocal(odooId);
          return record?.name;
        case 'account_payment_term':
          final record = await paymentTermManager.readLocal(odooId);
          return record?.name;
        default:
          logger.w('[FastSale]', 'Unknown table for name lookup: $table');
          return null;
      }
    } catch (e) {
      logger.w(
        '[FastSale]',
        'Could not lookup name from $table for id $odooId: $e',
      );
      return null;
    }
  }

  /// Load complete partner data from database
  ///
  /// Returns a record with all partner fields needed for the order.
  /// Uses shared utility from partner_utils for consistency with SaleOrderFormNotifier.
  Future<
    ({
      int id,
      String name,
      String? vat,
      String? phone,
      String? email,
      String? street,
      String? avatar,
    })?
  >
  _loadPartnerData(int partnerId) async {
    return partner_utils.loadPartnerDataFromLocal(
      appDb: ref.read(appDatabaseProvider),
      partnerId: partnerId,
      logTag: '[FastSale]',
    );
  }

  /// Load authorized payment term IDs from Odoo for a partner
  ///
  /// Returns an empty list if offline or if partner has no restrictions.
  Future<List<int>> _loadPartnerPaymentTermIds(int partnerId) async {
    return partner_utils.loadPartnerPaymentTermIds(
      partnerId: partnerId,
      odooClient: ref.read(odooClientProvider),
      logTag: '[FastSale]',
    );
  }

  /// Switch to a specific tab
  void switchToTab(int index) {
    if (index >= 0 && index < state.tabs.length) {
      state = state.copyWith(activeTabIndex: index);
    }
  }

  /// Close a tab
  void closeTab(int index) {
    final newTabs = List<FastSaleTabState>.from(state.tabs)..removeAt(index);

    // If closing the last tab, show empty state
    if (newTabs.isEmpty) {
      state = state.copyWith(tabs: [], activeTabIndex: -1);
      return;
    }

    int newActiveIndex = state.activeTabIndex;

    if (newActiveIndex >= newTabs.length) {
      newActiveIndex = newTabs.length - 1;
    }

    state = state.copyWith(tabs: newTabs, activeTabIndex: newActiveIndex);
  }

  /// Load an existing order into a new tab
  Future<void> loadOrderInNewTab(int orderId) async {
    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo == null) return;

    // Check if order is already open
    final existingIndex = state.tabs.indexWhere((t) => t.orderId == orderId);
    if (existingIndex >= 0) {
      state = state.copyWith(activeTabIndex: existingIndex);
      return;
    }

    try {
      // Always refresh from Odoo to get latest state
      final (order, lines) = await salesRepo.getWithLines(
        orderId,
        forceRefresh: true,
      );

      if (order == null) return;

      // Load authorized payment term IDs for this order's partner
      List<int> partnerPaymentTermIds = [];
      if (order.partnerId != null) {
        partnerPaymentTermIds = await _loadPartnerPaymentTermIds(
          order.partnerId!,
        );
      }

      final newTab = FastSaleTabState(
        orderId: order.id,
        orderName: order.name,
        order: order,
        lines: lines,
        partnerPaymentTermIds: partnerPaymentTermIds,
      );

      state = state.copyWith(
        tabs: [...state.tabs, newTab],
        activeTabIndex: state.tabs.length,
      );

      // Sync and load withhold, payment lines, and invoices for this order (syncs from Odoo if online)
      ref.read(posWithholdLinesByOrderProvider.notifier).syncAndLoad(order.id);
      ref.read(posPaymentLinesByOrderProvider.notifier).syncAndLoad(order.id);
      // Sync invoices for this order (similar to payment lines)
      if (salesRepo.isOnline) {
        salesRepo.syncInvoicesForOrder(order.id).catchError((e) {
          logger.w('[FastSale]', 'Failed to sync invoices for order ${order.id}: $e');
        });
      }
    } catch (e) {
      logger.e('[FastSale]', 'Error loading order $orderId', e);
    }
  }

  /// Reload the active order from Odoo
  ///
  /// Used after operations that change order state (like creating invoice)
  Future<void> reloadActiveOrder() async {
    final activeTab = state.activeTab;
    if (activeTab == null) return;

    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo == null) return;

    try {
      final (order, lines) = await salesRepo.getWithLines(
        activeTab.orderId,
        forceRefresh: true,
      );

      if (order == null) return;

      // Cache order in unified cache (single source of truth)
      ref.read(orderCacheProvider.notifier).cacheOrder(order, lines: lines);

      final updatedTab = FastSaleTabState(
        orderId: order.id,
        orderName: order.name,
        order: order,
        lines: lines,
        hasChanges: false,
        partnerPaymentTermIds: activeTab.partnerPaymentTermIds,
      );

      _updateActiveTab(updatedTab);

      // Reload withhold and payment lines from DB (sync already happened in getWithLines)
      ref.read(posWithholdLinesByOrderProvider.notifier).loadFromDb(order.id);
      ref.read(posPaymentLinesByOrderProvider.notifier).loadFromDb(order.id);

      logger.i(
        '[FastSale]',
        'Reloaded order ${order.id}, state: ${order.state}',
      );
    } catch (e) {
      logger.e('[FastSale]', 'Error reloading active order', e);
    }
  }
}
