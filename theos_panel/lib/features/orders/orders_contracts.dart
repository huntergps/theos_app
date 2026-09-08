import 'dart:async';

import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum OrderLoadStatus { initial, loading, data, empty, error }

enum OrderFilter { mine, all, cashierPending }

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
}

final class OrderSnapshot {
  OrderSnapshot({
    this.status = OrderLoadStatus.initial,
    List<OrderListItem> items = const [],
    this.totalCount = 0,
    this.query,
    this.error,
  }) : items = List.unmodifiable(items);

  final OrderLoadStatus status;
  final List<OrderListItem> items;
  final int totalCount;
  final OrderQuery? query;
  final Object? error;
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
  String _text = '';
  StreamSubscription<OrderSnapshot>? _subscription;
  OrderSnapshot _snapshot = OrderSnapshot();
  final _changes = StreamController<OrderSnapshot>.broadcast();
  int _epoch = 0;

  OrderFilter get filter => _filter;
  String get text => _text;
  OrderSnapshot get snapshot => _snapshot;
  Stream<OrderSnapshot> get changes => _changes.stream;
  OrderQuery get query =>
      policy.queryFor(_filter, text: _text.isEmpty ? null : _text);

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
  }

  void _publish() {
    if (!_changes.isClosed) _changes.add(_snapshot);
  }

  Future<void> dispose() async {
    _epoch++;
    await _subscription?.cancel();
    await _changes.close();
  }
}
