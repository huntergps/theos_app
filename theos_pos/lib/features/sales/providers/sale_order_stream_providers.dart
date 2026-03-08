import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/database/repositories/repository_providers.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        SaleOrder,
        SaleOrderLine,
        SaleOrderState,
        saleOrderManager,
        saleOrderLineManager;

part 'sale_order_stream_providers.g.dart';

/// Stream provider for watching all sale orders
@Riverpod(keepAlive: true)
Stream<List<SaleOrder>> saleOrdersStream(Ref ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value([]);

  return saleOrderManager.watchLocalSearch(
    orderBy: 'date_order desc',
  );
}

/// Stream provider for watching sale orders filtered by state
@Riverpod(keepAlive: true)
Stream<List<SaleOrder>> saleOrdersByStateStream(Ref ref, String state) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value([]);

  return saleOrderManager.watchLocalSearch(
    domain: [
      ['state', '=', state],
    ],
    orderBy: 'date_order desc',
  );
}

/// Stream provider for watching a single sale order by ID
@Riverpod(keepAlive: true)
Stream<SaleOrder?> saleOrderStream(Ref ref, int orderId) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value(null);

  return saleOrderManager.watch(orderId);
}

/// Stream provider for watching a single sale order line by ID
@Riverpod(keepAlive: true)
Stream<SaleOrderLine?> saleOrderLineStream(Ref ref, int lineId) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value(null);

  return saleOrderLineManager.watch(lineId);
}

/// Stream provider for watching all lines of a specific order
@Riverpod(keepAlive: true)
Stream<List<SaleOrderLine>> saleOrderLinesStream(Ref ref, int orderId) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value([]);

  return saleOrderLineManager.watchLocalSearch(
    domain: [
      ['order_id', '=', orderId],
    ],
    orderBy: 'sequence asc',
  );
}

/// Stream provider for watching only line IDs of an order
@Riverpod(keepAlive: true)
Stream<List<int>> saleOrderLineIdsStream(Ref ref, int orderId) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value([]);

  return saleOrderLineManager
      .watchLocalSearch(
        domain: [
          ['order_id', '=', orderId],
        ],
        orderBy: 'sequence asc',
      )
      .map((lines) => lines.map((l) => l.id).where((id) => id != 0).toList());
}

/// Stream provider for orders pending sync (offline)
@Riverpod(keepAlive: true)
Stream<List<SaleOrder>> unsyncedSaleOrdersStream(Ref ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value([]);

  return saleOrderManager.watchLocalSearch(
    domain: [
      ['is_synced', '=', false],
    ],
    orderBy: 'date_order desc',
  );
}

/// Stream provider for counting orders by state
@Riverpod(keepAlive: true)
Stream<int> saleOrderCountByStateStream(Ref ref, String state) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value(0);

  return saleOrderManager
      .watchLocalSearch(
        domain: [
          ['state', '=', state],
        ],
      )
      .map((orders) => orders.length);
}

// ============================================================================
// DERIVED PROVIDERS: Field-level selectors for granular reactivity
// ============================================================================

/// Provider for watching only the partner name of an order
@Riverpod(keepAlive: true)
String? saleOrderPartnerName(Ref ref, int orderId) {
  final asyncValue = ref.watch(saleOrderStreamProvider(orderId));
  return asyncValue.whenData((order) => order?.partnerName).value;
}

/// Provider for watching only the state of an order
@Riverpod(keepAlive: true)
SaleOrderState? saleOrderState(Ref ref, int orderId) {
  final asyncValue = ref.watch(saleOrderStreamProvider(orderId));
  return asyncValue.whenData((order) => order?.state).value;
}

/// Provider for watching only the total of an order
@Riverpod(keepAlive: true)
double? saleOrderTotal(Ref ref, int orderId) {
  final asyncValue = ref.watch(saleOrderStreamProvider(orderId));
  return asyncValue.whenData((order) => order?.amountTotal).value;
}

/// Provider for watching if an order is synced
@Riverpod(keepAlive: true)
bool saleOrderIsSynced(Ref ref, int orderId) {
  final asyncValue = ref.watch(saleOrderStreamProvider(orderId));
  return asyncValue.whenData((order) => order?.isSynced ?? false).value ?? false;
}

/// Provider for watching only the quantity of a line
@Riverpod(keepAlive: true)
double? saleOrderLineQty(Ref ref, int lineId) {
  final asyncValue = ref.watch(saleOrderLineStreamProvider(lineId));
  return asyncValue.whenData((line) => line?.productUomQty).value;
}

/// Provider for watching only the price of a line
@Riverpod(keepAlive: true)
double? saleOrderLinePrice(Ref ref, int lineId) {
  final asyncValue = ref.watch(saleOrderLineStreamProvider(lineId));
  return asyncValue.whenData((line) => line?.priceUnit).value;
}

/// Provider for watching only the subtotal of a line
@Riverpod(keepAlive: true)
double? saleOrderLineSubtotal(Ref ref, int lineId) {
  final asyncValue = ref.watch(saleOrderLineStreamProvider(lineId));
  return asyncValue.whenData((line) => line?.priceSubtotal).value;
}
