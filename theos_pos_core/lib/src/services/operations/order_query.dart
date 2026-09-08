import '../../models/sales/sale_order_enums.dart';

/// Additional authorized work queue applied by both the page and its count.
enum OrderWorkQueue { all, cashierPending }

/// Immutable, stable query for local order streams and their counters.
class OrderQuery {
  final int companyId;
  final int? authorFilter;
  final String? text;
  final Set<SaleOrderState> states;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final int limit;
  final int? afterId;
  final OrderWorkQueue workQueue;

  OrderQuery({
    required int companyId,
    this.authorFilter,
    this.text,
    Iterable<SaleOrderState> states = const [],
    this.dateFrom,
    this.dateTo,
    this.limit = 50,
    this.afterId,
    this.workQueue = OrderWorkQueue.all,
  }) : companyId = _positive(companyId, 'companyId'),
       states = Set.unmodifiable(states) {
    if (authorFilter != null) _positive(authorFilter!, 'authorFilter');
    if (afterId != null) _positive(afterId!, 'afterId');
    if (limit <= 0)
      throw ArgumentError.value(limit, 'limit', 'Must be positive');
    if (dateFrom != null && dateTo != null && dateFrom!.isAfter(dateTo!)) {
      throw ArgumentError.value(
        dateFrom,
        'dateFrom',
        'Must not be after dateTo',
      );
    }
  }

  OrderQuery withoutAuthorFilter() => OrderQuery(
    companyId: companyId,
    text: text,
    states: states,
    dateFrom: dateFrom,
    dateTo: dateTo,
    limit: limit,
    afterId: afterId,
    workQueue: workQueue,
  );

  /// Stable keyset ordering: newest order first, then ID as a tie-breaker.
  String get stableOrder => 'date_order:desc,id:desc';
}

int _positive(int value, String name) {
  if (value <= 0) throw ArgumentError.value(value, name, 'Must be positive');
  return value;
}
