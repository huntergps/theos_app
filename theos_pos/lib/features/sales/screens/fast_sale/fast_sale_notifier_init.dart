// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'fast_sale_providers.dart';

/// Initialization and validation helpers for FastSaleNotifier.
///
/// Contains cache sync logic, order editability checks, and the main
/// [initialize] method that loads the seller's orders into tabs.
extension FastSaleNotifierInit on FastSaleNotifier {
  /// Sync open orders from the cache when it updates
  ///
  /// Called by the cache listener when version changes.
  /// Only updates orders that are open in tabs.
  void _syncFromCache(OrderCacheState cache) {
    logger.d(
      '[FastSale]',
      '>>> _syncFromCache CALLED, tabs=${state.tabs.length}, cache.orders=${cache.orders.length}',
    );

    if (state.tabs.isEmpty) {
      logger.d('[FastSale]', '>>> _syncFromCache: No tabs, skipping');
      return;
    }

    bool hasChanges = false;
    final newTabs = <FastSaleTabState>[];

    for (final tab in state.tabs) {
      // Skip new orders (negative IDs) - they're not in the cache yet
      if (tab.isNewOrder) {
        logger.d('[FastSale]', '>>> _syncFromCache: Skipping new order ${tab.orderId}');
        newTabs.add(tab);
        continue;
      }

      final cachedOrder = cache.orders[tab.orderId];
      if (cachedOrder == null) {
        logger.d('[FastSale]', '>>> _syncFromCache: No cached order for ${tab.orderId}');
        newTabs.add(tab);
        continue;
      }

      // Check if the cached order differs from tab's order
      if (tab.order != null && _orderNeedsSync(tab.order!, cachedOrder)) {
        logger.w(
          '[FastSale]',
          '>>> _syncFromCache: SYNCING order ${tab.orderId}! '
          'Tab partner: ${tab.order?.partnerId}/${tab.order?.partnerName}, '
          'Cache partner: ${cachedOrder.partnerId}/${cachedOrder.partnerName}',
        );

        // Sync partner and other fields from cache
        final updatedOrder = tab.order!.copyWith(
          partnerId: cachedOrder.partnerId,
          partnerName: cachedOrder.partnerName,
          partnerVat: cachedOrder.partnerVat,
          partnerStreet: cachedOrder.partnerStreet,
          partnerPhone: cachedOrder.partnerPhone,
          partnerEmail: cachedOrder.partnerEmail,
          state: cachedOrder.state,
          locked: cachedOrder.locked,
          amountUntaxed: cachedOrder.amountUntaxed,
          amountTax: cachedOrder.amountTax,
          amountTotal: cachedOrder.amountTotal,
        );

        newTabs.add(tab.copyWith(order: updatedOrder));
        hasChanges = true;

        logger.d(
          '[FastSale]',
          'Synced order ${tab.orderId} from cache: partner=${cachedOrder.partnerName}',
        );
      } else {
        logger.d('[FastSale]', '>>> _syncFromCache: Order ${tab.orderId} is up-to-date');
        newTabs.add(tab);
      }
    }

    if (hasChanges) {
      logger.d('[FastSale]', '>>> _syncFromCache: Applying ${newTabs.length} updated tabs');
      state = state.copyWith(tabs: newTabs);
    } else {
      logger.d('[FastSale]', '>>> _syncFromCache: No changes needed');
    }
  }

  /// Check if order needs syncing from cache
  bool _orderNeedsSync(SaleOrder local, SaleOrder cached) {
    return local.partnerId != cached.partnerId ||
        local.partnerName != cached.partnerName ||
        local.partnerVat != cached.partnerVat ||
        local.state != cached.state ||
        local.locked != cached.locked;
  }

  /// Check if the active order can be modified (lines, prices, partner, etc.)
  ///
  /// Returns true only for draft and sent states.
  /// States like waiting, approved, sale, done, cancel are NOT editable.
  bool get _canModifyActiveOrder {
    final order = state.activeTab?.order;
    // New orders (no order yet) are always editable
    if (order == null) return true;
    return order.isEditable;
  }

  /// Check if active order is editable, log warning if not
  ///
  /// Use this at the start of any method that modifies order data.
  bool _ensureCanModify(String methodName) {
    if (!_canModifyActiveOrder) {
      final order = state.activeTab?.order;
      logger.w(
        '[FastSale]',
        '$methodName blocked: order ${order?.name} is in state ${order?.state.name} (not editable)',
      );
      return false;
    }
    return true;
  }

  /// Initialize the POS with seller's orders
  ///
  /// Loads orders for the current user that:
  /// - Are not invoiced (invoice_status != 'invoiced')
  /// - Are in editable states (draft, sent, waiting_approval, approved, sale)
  /// - Limited to maxTabs (default 10), most recent first
  ///
  /// If no orders found, creates a new draft order with defaults from Odoo.
  Future<void> initialize({bool force = false}) async {
    // Skip if already initialized (unless forced)
    if (state.isInitialized && !force) {
      logger.d('[FastSale]', 'Already initialized, skipping');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      final userRepo = ref.read(userRepositoryProvider);

      logger.d('[FastSale]', '=== INITIALIZE START ===');
      logger.d('[FastSale]', 'salesRepo: ${salesRepo != null ? "OK" : "NULL"}');
      logger.d('[FastSale]', 'userRepo: ${userRepo != null ? "OK" : "NULL"}');

      if (salesRepo == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Repositorio de ventas no disponible',
        );
        return;
      }

      if (userRepo == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Repositorio de usuarios no disponible',
        );
        return;
      }

      // Get user directly from repository (database)
      final currentUser = await userRepo.getCurrentUser();
      logger.d(
        '[FastSale]',
        'currentUser from DB: ${currentUser?.name ?? "NULL"} (id=${currentUser?.id})',
      );

      if (currentUser == null) {
        state = state.copyWith(
          isLoading: false,
          error: 'Usuario no autenticado',
        );
        return;
      }

      final userId = currentUser.id;

      // Get total count of available orders
      final totalCount = await saleOrderManager.countSaleOrdersForPOS(userId: userId);

      // Load orders (limited to maxTabs)
      final orders = await saleOrderManager.getSaleOrdersForPOS(
        userId: userId,
        limit: state.maxTabs,
      );

      logger.i(
        '[FastSale]',
        'Found $totalCount orders for user $userId, loading ${orders.length}',
      );

      final tabs = <FastSaleTabState>[];

      if (orders.isEmpty) {
        // No orders found - show empty state, user must create manually with + button
        logger.i(
          '[FastSale]',
          'No orders found, showing empty state (user must create manually)',
        );
        // tabs stays empty, UI will show empty state with "Nueva Orden" button
      } else {
        // Load each order with its lines and partner payment terms
        for (final order in orders) {
          final lines = await saleOrderLineManager.getSaleOrderLines(order.id);

          // Load authorized payment term IDs for this order's partner
          List<int> partnerPaymentTermIds = [];
          if (order.partnerId != null) {
            partnerPaymentTermIds = await _loadPartnerPaymentTermIds(
              order.partnerId!,
            );
          }

          tabs.add(
            FastSaleTabState(
              orderId: order.id,
              orderName: order.name,
              order: order,
              lines: lines,
              partnerPaymentTermIds: partnerPaymentTermIds,
            ),
          );
        }
        logger.i('[FastSale]', 'Loaded ${tabs.length} order tabs');
      }

      // Select last line in first tab (like normal edit screen)
      if (tabs.isNotEmpty && tabs.first.lines.isNotEmpty) {
        tabs[0] = tabs[0].copyWith(selectedLineIndex: tabs[0].lines.length - 1);
      }

      state = state.copyWith(
        isLoading: false,
        isInitialized: true,
        tabs: tabs,
        activeTabIndex: 0,
        totalOrdersCount: totalCount,
      );

      // Sync and load withhold, payment lines, and invoices for all initial orders
      // This syncs from Odoo if online, then loads from local DB (offline-first pattern)
      for (final tab in tabs) {
        ref.read(posWithholdLinesByOrderProvider.notifier).syncAndLoad(tab.orderId);
        ref.read(posPaymentLinesByOrderProvider.notifier).syncAndLoad(tab.orderId);
        // Sync invoices for this order (similar to payment lines)
        final salesRepo = ref.read(salesRepositoryProvider);
        if (salesRepo != null && salesRepo.isOnline) {
          salesRepo.syncInvoicesForOrder(tab.orderId).catchError((e) {
            logger.w('[FastSale]', 'Failed to sync invoices for order ${tab.orderId}: $e');
          });
        }
      }
    } catch (e, stack) {
      logger.e('[FastSale]', 'Error initializing', e, stack);
      state = state.copyWith(
        isLoading: false,
        error: 'Error al inicializar: $e',
      );
    }
  }
}
