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
///
/// `keepAlive:false` (autoDispose, default): es `.family` por `state` — sin
/// esto, cada valor de `state` visto durante la sesión dejaría un stream de
/// Drift `.watch()` vivo para siempre, aunque nadie lo esté observando
/// (memory leak corregido). Riverpod libera automáticamente la instancia
/// cuando el último watcher se va y la recrea si vuelve a observarse.
@Riverpod(keepAlive: false)
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
///
/// `keepAlive:false`: `.family` por `orderId` transitorio — ver nota en
/// [saleOrdersByStateStream] sobre por qué autoDispose es el default correcto
/// para providers "por ID de entidad" (evita cientos de streams de Drift
/// activos indefinidamente en un turno largo de POS).
@Riverpod(keepAlive: false)
Stream<SaleOrder?> saleOrderStream(Ref ref, int orderId) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value(null);

  return saleOrderManager.watch(orderId);
}

/// Stream provider for watching a single sale order line by ID
///
/// `keepAlive:false`: `.family` por `lineId` transitorio (ver nota en
/// [saleOrdersByStateStream]).
@Riverpod(keepAlive: false)
Stream<SaleOrderLine?> saleOrderLineStream(Ref ref, int lineId) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value(null);

  return saleOrderLineManager.watch(lineId);
}

/// Stream provider for watching all lines of a specific order
///
/// `keepAlive:false`: `.family` por `orderId` transitorio (ver nota en
/// [saleOrdersByStateStream]).
@Riverpod(keepAlive: false)
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
///
/// `keepAlive:false`: `.family` por `orderId` transitorio (ver nota en
/// [saleOrdersByStateStream]).
@Riverpod(keepAlive: false)
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
///
/// `keepAlive:false`: `.family` por `state` (ver nota en
/// [saleOrdersByStateStream]).
@Riverpod(keepAlive: false)
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
///
/// `keepAlive:false`: `.family` por `orderId` transitorio (ver nota en
/// [saleOrdersByStateStream]).
@Riverpod(keepAlive: false)
String? saleOrderPartnerName(Ref ref, int orderId) {
  final asyncValue = ref.watch(saleOrderStreamProvider(orderId));
  return asyncValue.whenData((order) => order?.partnerName).value;
}

/// Provider for watching only the state of an order
///
/// `keepAlive:false`: `.family` por `orderId` transitorio (ver nota en
/// [saleOrdersByStateStream]).
@Riverpod(keepAlive: false)
SaleOrderState? saleOrderState(Ref ref, int orderId) {
  final asyncValue = ref.watch(saleOrderStreamProvider(orderId));
  return asyncValue.whenData((order) => order?.state).value;
}

/// Provider for watching only the total of an order
///
/// `keepAlive:false`: `.family` por `orderId` transitorio (ver nota en
/// [saleOrdersByStateStream]).
@Riverpod(keepAlive: false)
double? saleOrderTotal(Ref ref, int orderId) {
  final asyncValue = ref.watch(saleOrderStreamProvider(orderId));
  return asyncValue.whenData((order) => order?.amountTotal).value;
}

/// Provider for watching if an order is synced
///
/// `keepAlive:false`: `.family` por `orderId` transitorio (ver nota en
/// [saleOrdersByStateStream]).
@Riverpod(keepAlive: false)
bool saleOrderIsSynced(Ref ref, int orderId) {
  final asyncValue = ref.watch(saleOrderStreamProvider(orderId));
  return asyncValue.whenData((order) => order?.isSynced ?? false).value ?? false;
}

/// Provider for watching only the quantity of a line
///
/// `keepAlive:false`: `.family` por `lineId` transitorio (ver nota en
/// [saleOrdersByStateStream]).
@Riverpod(keepAlive: false)
double? saleOrderLineQty(Ref ref, int lineId) {
  final asyncValue = ref.watch(saleOrderLineStreamProvider(lineId));
  return asyncValue.whenData((line) => line?.productUomQty).value;
}

/// Provider for watching only the price of a line
///
/// `keepAlive:false`: `.family` por `lineId` transitorio (ver nota en
/// [saleOrdersByStateStream]).
@Riverpod(keepAlive: false)
double? saleOrderLinePrice(Ref ref, int lineId) {
  final asyncValue = ref.watch(saleOrderLineStreamProvider(lineId));
  return asyncValue.whenData((line) => line?.priceUnit).value;
}

/// Provider for watching only the subtotal of a line
///
/// `keepAlive:false`: `.family` por `lineId` transitorio (ver nota en
/// [saleOrdersByStateStream]).
@Riverpod(keepAlive: false)
double? saleOrderLineSubtotal(Ref ref, int lineId) {
  final asyncValue = ref.watch(saleOrderLineStreamProvider(lineId));
  return asyncValue.whenData((line) => line?.priceSubtotal).value;
}
