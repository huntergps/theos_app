// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'fast_sale_providers.dart';

/// Shared local state operations used by the focused Fast Sale extensions.
extension FastSaleNotifierState on FastSaleNotifier {
  void _updateActiveTab(FastSaleTabState updatedTab) {
    final activeIndex = state.activeTabIndex;
    if (activeIndex < 0 || activeIndex >= state.tabs.length) {
      logger.w('[FastSale]', 'Invalid active tab index: $activeIndex');
      return;
    }

    final tabs = List<FastSaleTabState>.from(state.tabs);
    tabs[activeIndex] = updatedTab;
    state = state.copyWith(tabs: tabs);

    final order = updatedTab.order;
    if (order != null && !updatedTab.isNewOrder) {
      ref
          .read(orderCacheProvider.notifier)
          .cacheOrder(order, lines: updatedTab.lines);
    }
  }

  /// Update the active order lock without reloading its complete snapshot.
  void updateActiveOrderLocked(bool locked) {
    final activeTab = state.activeTab;
    final order = activeTab?.order;
    if (activeTab == null || order == null) return;

    ref.read(orderCacheProvider.notifier).updateOrderLocked(order.id, locked);
    _updateActiveTab(activeTab.copyWith(order: order.copyWith(locked: locked)));
  }

  /// Update a cached/open order lock by ID for cross-screen consistency.
  void updateOrderLockedById(int orderId, bool locked) {
    ref.read(orderCacheProvider.notifier).updateOrderLocked(orderId, locked);

    var changed = false;
    final tabs = state.tabs
        .map((tab) {
          final order = tab.order;
          if (tab.orderId != orderId || order == null) return tab;
          changed = true;
          return tab.copyWith(order: order.copyWith(locked: locked));
        })
        .toList(growable: false);
    if (changed) state = state.copyWith(tabs: tabs);
  }

  /// Clear errors after their UI notification has been dismissed.
  void clearError() {
    state = state.copyWith(error: null, lastCreditIssue: null);
    final activeTab = state.activeTab;
    if (activeTab?.error != null) {
      _updateActiveTab(activeTab!.copyWith(error: null));
    }
  }

  /// Clear only the credit warning handled by its confirmation dialog.
  void clearCreditIssue() {
    state = state.copyWith(lastCreditIssue: null);
  }
}
