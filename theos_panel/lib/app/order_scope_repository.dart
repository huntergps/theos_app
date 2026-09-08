import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/orders/orders_contracts.dart';
import 'notification_scope_adapter.dart';

final scopeOrderRepositoryProvider = Provider<OrderRepository?>((ref) {
  final sessions = ref.watch(runtimeSessionProvider);
  if (sessions == null) return null;
  return ScopeOrderRepository(sessions);
});

final class ScopeOrderRepository implements OrderRepository {
  ScopeOrderRepository(this.sessions);
  final SessionRuntime sessions;
  final _streams = <String, StreamController<OrderSnapshot>>{};

  @override
  Stream<OrderSnapshot> watch(OrderQuery query) {
    final key = query.toString();
    final controller = _streams.putIfAbsent(
      key,
      () => StreamController<OrderSnapshot>.broadcast(),
    );
    unawaited(refresh(query));
    return controller.stream;
  }

  @override
  Future<void> refresh(OrderQuery query) async {
    final active = sessions.active;
    if (active?.client != null) {
      try {
        await RuntimeLocalOrderReader(sessions).refreshOnline(query);
      } catch (_) {
        // Offline refresh continues from the durable local table.
      }
    }
    final key = query.toString();
    final controller = _streams[key];
    if (controller != null) await _load(query, controller);
  }

  Future<void> _load(
    OrderQuery query,
    StreamController<OrderSnapshot> controller,
  ) async {
    try {
      final result = await RuntimeLocalOrderReader(sessions).read(query);
      final items = result.rows.map(_map).toList(growable: false);
      controller.add(
        OrderSnapshot(
          status: items.isEmpty ? OrderLoadStatus.empty : OrderLoadStatus.data,
          items: items,
          totalCount: result.count,
          query: query,
        ),
      );
    } catch (error) {
      if (!controller.isClosed) {
        controller.add(
          OrderSnapshot(
            status: OrderLoadStatus.error,
            query: query,
            error: error,
          ),
        );
      }
    }
  }

  OrderListItem _map(Map<String, dynamic> row) {
    final stateCode = row['state'] as String? ?? 'draft';
    final state = SaleOrderState.values.firstWhere(
      (value) => value.code == stateCode,
      orElse: () => SaleOrderState.draft,
    );
    return OrderListItem(
      localId: '${row['id']}',
      title: row['name'] as String? ?? '${row['id']}',
      companyId: row['company_id'] as int? ?? 0,
      authorId: row['user_id'] as int? ?? 0,
      businessState: state,
      syncState: row['is_synced'] == true
          ? OperationSyncState.synced
          : OperationSyncState.localOnly,
          pendingCollection: _pendingCollection(row),
          pendingInvoicing: _pendingInvoicing(row),
        );
  }

  static bool _pendingCollection(Map<String, dynamic> row) {
    final unpaid = (row['amount_unpaid'] as num?)?.toDouble() ?? 0;
    final paymentState = row['payment_state'] as String?;
    return unpaid > 0 ||
        const {'not_paid', 'partial', 'in_payment'}.contains(paymentState);
  }

  static bool _pendingInvoicing(Map<String, dynamic> row) {
    final toInvoice = (row['amount_to_invoice'] as num?)?.toDouble() ?? 0;
    final invoiceStatus = row['invoice_status'] as String?;
    return toInvoice > 0 ||
        const {'to invoice', 'upselling'}.contains(invoiceStatus) ||
        row['has_queued_invoice'] == true;
  }
}
