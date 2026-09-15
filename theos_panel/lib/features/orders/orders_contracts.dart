import 'dart:async';

import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OrderLoadStatus { initial, loading, data, empty, error }

enum OrderFilter { mine, all, cashierPending }

/// Los tres estados con contador propio en la barra de filtros rápidos
/// («Cotizaciones (820) / Confirmadas (384) / Por aprobar (0)», tal como ya
/// se ve en theos_pos). El menú «Filtros» ofrece los demás
/// [SaleOrderState.values] además de éstos — los tres no son una lista
/// aparte, son sólo los que se adelantan como accesos directos.
const orderQuickStates = [
  SaleOrderState.draft,
  SaleOrderState.sale,
  SaleOrderState.waitingApproval,
];

final class OrderListItem {
  const OrderListItem({
    required this.localId,
    required this.title,
    required this.companyId,
    required this.authorId,
    required this.businessState,
    required this.syncState,
    this.clientOrderRef,
    this.pickingIds = const [],
    this.fiscalState,
    this.pendingCollection = false,
    this.pendingInvoicing = false,
    this.partnerName,
    this.dateOrder,
    this.amountTotal,
    this.currencySymbol,
    this.sellerName,
    this.amountUntaxed,
    this.amountTax,
  });

  final String localId;
  final String title;
  final int companyId;
  final int authorId;
  final SaleOrderState businessState;
  final OperationSyncState syncState;
  final String? clientOrderRef;
  final List<int> pickingIds;
  final FiscalState? fiscalState;
  final bool pendingCollection;
  final bool pendingInvoicing;

  /// Nulo cuando la fila todavía no trae ese dato de la base local — por
  /// ejemplo, una orden creada sin conexión y nunca refrescada desde el
  /// servidor. La pantalla decide entonces cómo mostrarlo, no aquí.
  final String? partnerName;
  final DateTime? dateOrder;
  final double? amountTotal;
  final String? currencySymbol;

  /// El nombre lo trajo Odoo junto con `user_id` (par `[id, nombre]`), no se
  /// resuelve aparte. Nulo en una orden creada sin conexión y nunca
  /// refrescada — ahí sólo hay [authorId].
  final String? sellerName;

  /// Subtotal e impuestos ya calculados por Odoo: se muestran, no se
  /// recalculan aquí. Nulos cuando la fila todavía no los trae de la base
  /// local (por ejemplo, una orden sincronizada antes de este cambio).
  final double? amountUntaxed;
  final double? amountTax;

  /// Todavía no ha llegado al servidor: es lo mismo que activa el icono de
  /// pendiente de subir en la lista.
  bool get pendingUpload => syncState != OperationSyncState.synced;
}

final class OrderSnapshot {
  OrderSnapshot({
    this.status = OrderLoadStatus.initial,
    List<OrderListItem> items = const [],
    this.totalCount = 0,
    this.query,
    this.error,
    this.refreshError,
  }) : items = List.unmodifiable(items);

  final OrderLoadStatus status;
  final List<OrderListItem> items;
  final int totalCount;
  final OrderQuery? query;
  final Object? error;

  /// No fatal: el refresco EN LÍNEA falló (red, permiso, modelo ausente)
  /// pero la copia local sí se pudo leer, y [items] la sigue mostrando.
  /// Distinto de [error], que es un fallo DURO de la lectura LOCAL misma
  /// (`ScopeOrderRepository._load`) y por eso apaga la lista entera. `null`
  /// cuando el refresco en línea salió bien, o no se intentó (sin conexión:
  /// no hay nada nuevo que reportar como fallo).
  final Object? refreshError;
}

/// Local, already-authorized order query. The implementation owns storage and
/// applies the exact same query to page and count before publishing a snapshot.
abstract interface class OrderRepository {
  Stream<OrderSnapshot> watch(OrderQuery query);
  Future<void> refresh(OrderQuery query);
}

final class OrderFilterPolicy {
  const OrderFilterPolicy({required this.userId, required this.capabilities});

  final int userId;
  final CapabilitySnapshot capabilities;

  bool get canViewAll => capabilities.permissions.contains('orders.view_all');
  bool get isCashier => capabilities.permissions.contains('cashier');
  bool get isSeller => capabilities.permissions.contains('seller');
  bool get isWarehouse => capabilities.permissions.contains('warehouse');

  OrderFilter get initialFilter => isCashier
      ? OrderFilter.cashierPending
      : isWarehouse
      ? OrderFilter.all
      : OrderFilter.mine;

  bool canSelect(OrderFilter filter) => switch (filter) {
    OrderFilter.mine => isSeller || !isCashier,
    OrderFilter.all => canViewAll || isWarehouse,
    OrderFilter.cashierPending => isCashier,
  };

  OrderQuery queryFor(OrderFilter filter, {String? text}) {
    final states = filter == OrderFilter.cashierPending
        ? const [SaleOrderState.sale]
        : const <SaleOrderState>[];
    return OrderQuery(
      companyId: capabilities.companyId,
      authorFilter: filter == OrderFilter.mine ? userId : null,
      text: text,
      states: states,
      workQueue: filter == OrderFilter.cashierPending
          ? OrderWorkQueue.cashierPending
          : OrderWorkQueue.all,
    );
  }
}

abstract interface class OrderFilterStore {
  String? read(String scopeKey);
  Future<void> write(String scopeKey, OrderFilter filter);
}

final class SharedPreferencesOrderFilterStore implements OrderFilterStore {
  const SharedPreferencesOrderFilterStore(this.preferences);
  final SharedPreferences preferences;
  String _key(String scope) => 'orbi.orders.filter.$scope';
  @override
  String? read(String scopeKey) => preferences.getString(_key(scopeKey));
  @override
  Future<void> write(String scopeKey, OrderFilter filter) =>
      preferences.setString(_key(scopeKey), filter.name);
}

final class OrderController {
  OrderController({
    required this.repository,
    required this.policy,
    this.filterStore,
    this.scopeKey = 'unscoped',
  }) : _filter = _restoredFilter(policy, filterStore?.read(scopeKey)) {
    _subscribe();
  }

  final OrderRepository repository;
  final OrderFilterPolicy policy;
  final OrderFilterStore? filterStore;
  final String scopeKey;
  OrderFilter _filter;
  SaleOrderState? _selectedState;
  String _text = '';
  StreamSubscription<OrderSnapshot>? _subscription;
  OrderSnapshot _snapshot = OrderSnapshot();
  final _changes = StreamController<OrderSnapshot>.broadcast();
  int _epoch = 0;

  /// Contador real por estado (sólo [orderQuickStates], que son los que se
  /// muestran como chip). Aparte de [_snapshot] porque cambia con su propia
  /// consulta — una por estado — y no debe pisar los datos de la página
  /// actual.
  final _statusCounts = <SaleOrderState, int>{};
  final _statusSubscriptions =
      <SaleOrderState, StreamSubscription<OrderSnapshot>>{};
  int _countsEpoch = 0;

  OrderFilter get filter => _filter;
  SaleOrderState? get selectedState => _selectedState;
  String get text => _text;
  OrderSnapshot get snapshot => _snapshot;
  Stream<OrderSnapshot> get changes => _changes.stream;

  /// Cuántas filas hay realmente en cada estado de [orderQuickStates], con el
  /// mismo ámbito (dueño, texto) que la consulta activa. Vacío mientras el
  /// filtro sea de caja: ahí el estado ya lo fija
  /// `OrderWorkQueue.cashierPending`, y estos contadores no aplican.
  Map<SaleOrderState, int> get statusCounts => Map.unmodifiable(_statusCounts);

  OrderQuery get query {
    final base = policy.queryFor(_filter, text: _text.isEmpty ? null : _text);
    final state = _selectedState;
    if (state == null || _filter == OrderFilter.cashierPending) return base;
    return OrderQuery(
      companyId: base.companyId,
      authorFilter: base.authorFilter,
      text: base.text,
      states: [state],
      workQueue: base.workQueue,
    );
  }

  void setText(String value) {
    if (_text == value) return;
    _text = value;
    _subscribe();
  }

  void setFilter(OrderFilter value) {
    if (value == _filter || !policy.canSelect(value)) return;
    _filter = value;
    unawaited(filterStore?.write(scopeKey, value));
    _subscribe();
  }

  /// Vuelve a tocar el mismo estado para quitar el filtro (mostrar todos los
  /// estados de nuevo), igual que un `ToggleButton` que se puede desmarcar.
  /// Sirve tanto para los tres chips rápidos como para el menú «Filtros» con
  /// el resto de [SaleOrderState.values].
  void setSelectedState(SaleOrderState? value) {
    final next = value == _selectedState ? null : value;
    if (next == _selectedState) return;
    _selectedState = next;
    _subscribe();
  }

  static OrderFilter _restoredFilter(OrderFilterPolicy policy, String? raw) {
    final parsed = OrderFilter.values.where((value) => value.name == raw);
    if (parsed.isNotEmpty && policy.canSelect(parsed.first)) {
      return parsed.first;
    }
    return policy.initialFilter;
  }

  Future<void> refresh() => repository.refresh(query);

  void _subscribe() {
    final epoch = ++_epoch;
    final old = _subscription;
    _subscription = null;
    old?.cancel();
    final nextQuery = query;
    _snapshot = OrderSnapshot(
      status: OrderLoadStatus.loading,
      query: nextQuery,
    );
    _publish();
    _subscription = repository.watch(nextQuery).listen((value) {
      if (epoch != _epoch) return;
      _snapshot = value;
      _publish();
    });
    _subscribeCounts();
  }

  void _subscribeCounts() {
    final epoch = ++_countsEpoch;
    for (final subscription in _statusSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _statusSubscriptions.clear();
    if (_filter == OrderFilter.cashierPending) {
      if (_statusCounts.isNotEmpty) {
        _statusCounts.clear();
        _publish();
      }
      return;
    }
    final authorFilter = _filter == OrderFilter.mine ? policy.userId : null;
    final text = _text.isEmpty ? null : _text;
    for (final state in orderQuickStates) {
      final countQuery = OrderQuery(
        companyId: policy.capabilities.companyId,
        authorFilter: authorFilter,
        text: text,
        states: [state],
      );
      _statusSubscriptions[state] = repository.watch(countQuery).listen((
        value,
      ) {
        if (epoch != _countsEpoch) return;
        _statusCounts[state] = value.totalCount;
        _publish();
      });
    }
  }

  void _publish() {
    if (!_changes.isClosed) _changes.add(_snapshot);
  }

  Future<void> dispose() async {
    _epoch++;
    _countsEpoch++;
    await _subscription?.cancel();
    for (final subscription in _statusSubscriptions.values) {
      await subscription.cancel();
    }
    await _changes.close();
  }
}
