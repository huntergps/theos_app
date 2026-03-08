/// Unified Order Cache Provider
///
/// Single source of truth for all loaded sale orders.
/// Both [saleOrderFormProvider] and [fastSaleProvider] read from here.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

part 'order_cache_provider.freezed.dart';
part 'order_cache_provider.g.dart';

// ============================================================================
// STATE
// ============================================================================

/// State for the unified order cache
@freezed
abstract class OrderCacheState with _$OrderCacheState {
  const OrderCacheState._();

  const factory OrderCacheState({
    /// Cached orders by ID
    @Default({}) Map<int, SaleOrder> orders,

    /// Cached lines by order ID
    @Default({}) Map<int, List<SaleOrderLine>> orderLines,

    /// Track which orders are currently loading
    @Default({}) Set<int> loadingOrderIds,

    /// Version counter - incremented on every change to force UI rebuilds
    @Default(0) int version,
  }) = _OrderCacheState;

  /// Check if an order is cached
  bool hasOrder(int orderId) => orders.containsKey(orderId);

  /// Check if an order is loading
  bool isLoading(int orderId) => loadingOrderIds.contains(orderId);

  /// Get order count
  int get orderCount => orders.length;
}

// ============================================================================
// NOTIFIER
// ============================================================================

/// Notifier for the unified order cache
@Riverpod(keepAlive: true)
class OrderCache extends _$OrderCache {
  @override
  OrderCacheState build() => const OrderCacheState();

  // ==========================================================================
  // CACHE OPERATIONS
  // ==========================================================================

  /// Cache an order and optionally its lines
  void cacheOrder(SaleOrder order, {List<SaleOrderLine>? lines}) {
    final newOrders = Map<int, SaleOrder>.from(state.orders);
    newOrders[order.id] = order;

    var newOrderLines = state.orderLines;
    if (lines != null) {
      newOrderLines = Map<int, List<SaleOrderLine>>.from(state.orderLines);
      newOrderLines[order.id] = List.unmodifiable(lines);
    }

    state = state.copyWith(
      orders: newOrders,
      orderLines: newOrderLines,
      version: state.version + 1,
    );

    logger.d(
      '[OrderCache]',
      'Cached order ${order.id} (${order.name}), '
          'lines: ${lines?.length ?? "unchanged"}',
    );
  }

  /// Cache multiple orders at once
  void cacheOrders(List<SaleOrder> orders) {
    if (orders.isEmpty) return;

    final newOrders = Map<int, SaleOrder>.from(state.orders);
    for (final order in orders) {
      newOrders[order.id] = order;
    }

    state = state.copyWith(
      orders: newOrders,
      version: state.version + 1,
    );

    logger.d('[OrderCache]', 'Cached ${orders.length} orders');
  }

  /// Cache lines for an order
  void cacheLines(int orderId, List<SaleOrderLine> lines) {
    final newOrderLines = Map<int, List<SaleOrderLine>>.from(state.orderLines);
    newOrderLines[orderId] = List.unmodifiable(lines);

    state = state.copyWith(
      orderLines: newOrderLines,
      version: state.version + 1,
    );

    logger.d('[OrderCache]', 'Cached ${lines.length} lines for order $orderId');
  }

  /// Remove an order from the cache
  void removeOrder(int orderId) {
    final newOrders = Map<int, SaleOrder>.from(state.orders);
    final newOrderLines = Map<int, List<SaleOrderLine>>.from(state.orderLines);

    newOrders.remove(orderId);
    newOrderLines.remove(orderId);

    state = state.copyWith(
      orders: newOrders,
      orderLines: newOrderLines,
      version: state.version + 1,
    );

    logger.d('[OrderCache]', 'Removed order $orderId from cache');
  }

  /// Clear the entire cache
  void clearCache() {
    state = const OrderCacheState();
    logger.d('[OrderCache]', 'Cache cleared');
  }

  /// Mark an order as loading
  void setLoading(int orderId, bool isLoading) {
    final newLoadingIds = Set<int>.from(state.loadingOrderIds);
    if (isLoading) {
      newLoadingIds.add(orderId);
    } else {
      newLoadingIds.remove(orderId);
    }
    state = state.copyWith(loadingOrderIds: newLoadingIds);
  }

  // ==========================================================================
  // REACTIVE FIELD UPDATES
  // ==========================================================================

  /// Update a specific order using a transformation function
  bool updateOrder(int orderId, SaleOrder Function(SaleOrder) updater) {
    final order = state.orders[orderId];
    if (order == null) {
      logger.w('[OrderCache]', 'updateOrder: Order $orderId not in cache');
      return false;
    }

    final updatedOrder = updater(order);
    final newOrders = Map<int, SaleOrder>.from(state.orders);
    newOrders[orderId] = updatedOrder;

    state = state.copyWith(
      orders: newOrders,
      version: state.version + 1,
    );

    return true;
  }

  /// Update the locked status of an order
  void updateOrderLocked(int orderId, bool locked) {
    final updated = updateOrder(orderId, (o) => o.copyWith(locked: locked));
    if (updated) {
      logger.d('[OrderCache]', 'Order $orderId locked=$locked');
    }
  }

  /// Update the state of an order
  void updateOrderState(int orderId, SaleOrderState newState) {
    final updated = updateOrder(orderId, (o) => o.copyWith(state: newState));
    if (updated) {
      logger.d('[OrderCache]', 'Order $orderId state=${newState.name}');
    }
  }

  /// Update partner info on an order
  void updateOrderPartner(
    int orderId, {
    int? partnerId,
    String? partnerName,
    String? partnerVat,
    String? partnerStreet,
    String? partnerPhone,
    String? partnerEmail,
  }) {
    updateOrder(orderId, (o) {
      return o.copyWith(
        partnerId: partnerId ?? o.partnerId,
        partnerName: partnerName ?? o.partnerName,
        partnerVat: partnerVat ?? o.partnerVat,
        partnerStreet: partnerStreet ?? o.partnerStreet,
        partnerPhone: partnerPhone ?? o.partnerPhone,
        partnerEmail: partnerEmail ?? o.partnerEmail,
      );
    });
  }

  /// Update order totals
  void updateOrderTotals(
    int orderId, {
    double? amountUntaxed,
    double? amountTax,
    double? amountTotal,
  }) {
    updateOrder(orderId, (o) {
      return o.copyWith(
        amountUntaxed: amountUntaxed ?? o.amountUntaxed,
        amountTax: amountTax ?? o.amountTax,
        amountTotal: amountTotal ?? o.amountTotal,
      );
    });
  }

  /// Mark order as synced/unsynced
  void updateOrderSyncStatus(int orderId, bool isSynced) {
    updateOrder(orderId, (o) => o.copyWith(isSynced: isSynced));
  }

  // ==========================================================================
  // LINE OPERATIONS
  // ==========================================================================

  /// Add a line to an order
  void addLine(int orderId, SaleOrderLine line) {
    final currentLines = state.orderLines[orderId] ?? [];
    final newLines = [...currentLines, line];
    cacheLines(orderId, newLines);
  }

  /// Update a specific line
  void updateLine(int orderId, int lineId, SaleOrderLine updatedLine) {
    final currentLines = state.orderLines[orderId];
    if (currentLines == null) return;

    final newLines = currentLines.map((l) {
      return l.id == lineId ? updatedLine : l;
    }).toList();

    cacheLines(orderId, newLines);
  }

  /// Remove a line from an order
  void removeLine(int orderId, int lineId) {
    final currentLines = state.orderLines[orderId];
    if (currentLines == null) return;

    final newLines = currentLines.where((l) => l.id != lineId).toList();
    cacheLines(orderId, newLines);
  }

  /// Update line by transformation function
  void updateLineWhere(
    int orderId,
    bool Function(SaleOrderLine) test,
    SaleOrderLine Function(SaleOrderLine) updater,
  ) {
    final currentLines = state.orderLines[orderId];
    if (currentLines == null) return;

    final newLines = currentLines.map((l) {
      return test(l) ? updater(l) : l;
    }).toList();

    cacheLines(orderId, newLines);
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Get a specific order from cache (reactive)
@Riverpod(keepAlive: true)
SaleOrder? cachedOrder(Ref ref, int orderId) {
  // Watch version to ensure rebuilds on any change
  ref.watch(orderCacheProvider.select((s) => s.version));
  return ref.watch(orderCacheProvider.select((s) => s.orders[orderId]));
}

/// Get lines for a specific order from cache (reactive)
@Riverpod(keepAlive: true)
List<SaleOrderLine> cachedOrderLines(Ref ref, int orderId) {
  // Watch version to ensure rebuilds on any change
  ref.watch(orderCacheProvider.select((s) => s.version));
  return ref.watch(
        orderCacheProvider.select((s) => s.orderLines[orderId]),
      ) ??
      const [];
}

/// Check if an order is in the cache
@Riverpod(keepAlive: true)
bool isOrderCached(Ref ref, int orderId) {
  return ref.watch(orderCacheProvider.select((s) => s.hasOrder(orderId)));
}

/// Check if an order is loading
@Riverpod(keepAlive: true)
bool isOrderLoading(Ref ref, int orderId) {
  return ref.watch(orderCacheProvider.select((s) => s.isLoading(orderId)));
}

/// Get order locked status directly
@Riverpod(keepAlive: true)
bool orderLocked(Ref ref, int orderId) {
  final order = ref.watch(cachedOrderProvider(orderId));
  return order?.locked ?? false;
}

/// Get order state directly
@Riverpod(keepAlive: true)
SaleOrderState? orderState(Ref ref, int orderId) {
  final order = ref.watch(cachedOrderProvider(orderId));
  return order?.state;
}

/// Get order with its lines as a tuple
@Riverpod(keepAlive: true)
(SaleOrder?, List<SaleOrderLine>) cachedOrderWithLines(Ref ref, int orderId) {
  final order = ref.watch(cachedOrderProvider(orderId));
  final lines = ref.watch(cachedOrderLinesProvider(orderId));
  return (order, lines);
}
