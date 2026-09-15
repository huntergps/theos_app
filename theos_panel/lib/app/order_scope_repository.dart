import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/auth/auth_controller.dart';
import '../features/orders/orders_contracts.dart';
import 'notification_scope_adapter.dart';

final scopeOrderRepositoryProvider = Provider<OrderRepository?>((ref) {
  final sessions = ref.watch(runtimeSessionProvider);
  if (sessions == null) return null;
  // `l10n_ec_collection_box.sale.order.payment` is only readable by the
  // Cajero/Supervisor de Caja groups in Odoo. A plain seller must never have
  // this model requested on their behalf — Odoo answers with a 403 today.
  final capabilities = ref.watch(capabilitySnapshotProvider);
  final canReadCollectionPayments =
      capabilities?.permissions.contains('cashier') ?? false;
  return ScopeOrderRepository(
    sessions,
    canReadCollectionPayments: canReadCollectionPayments,
  );
});

final class ScopeOrderRepository implements OrderRepository {
  ScopeOrderRepository(this.sessions, {this.canReadCollectionPayments = false});
  final SessionRuntime sessions;
  final bool canReadCollectionPayments;
  final _streams = <String, StreamController<OrderSnapshot>>{};

  // 🔴 Causa raíz de que dos filtros distintos (por ejemplo, el conteo de
  // «Cotizaciones» y el de «Confirmadas») se pisaran entre sí: `OrderQuery`
  // no redefine `toString()`, así que `query.toString()` daba SIEMPRE el
  // mismo texto («Instance of 'OrderQuery'»), sin importar el contenido de la
  // consulta. Con esa clave, `_streams.putIfAbsent` devolvía el MISMO
  // controlador para consultas con distinto autor/estado/texto, y cada
  // `_load` sobreescribía en ese controlador compartido lo que había
  // publicado la consulta anterior. Con una sola consulta viva a la vez
  // (el uso original) no se notaba; en cuanto hay varias en paralelo
  // (contadores por estado), sí.
  String _key(OrderQuery query) =>
      '${query.companyId}|${query.authorFilter}|${query.text}|'
      '${(query.states.map((s) => s.code).toList()..sort()).join(',')}|'
      '${query.workQueue}';

  @override
  Stream<OrderSnapshot> watch(OrderQuery query) {
    final key = _key(query);
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
    // 🔴 Causa raíz de que Bodega quedara vacía SIN explicación en un
    // servidor que sí tiene datos locales (Mepriga, evidencia del 14-sep):
    // antes este `catch (_) {}` se tragaba el fallo del refresco en línea
    // por completo — red caída, permiso insuficiente, o `sale.order`
    // directamente ausente del servidor — y seguía a `_load` como si nada
    // hubiera pasado. Ahora el error se guarda y viaja en el snapshot
    // (`OrderSnapshot.refreshError`) para que la pantalla lo cuente en vez
    // de quedarse muda.
    Object? refreshError;
    if (active?.client != null) {
      try {
        await RuntimeLocalOrderReader(sessions).refreshOnline(
          query,
          canReadCollectionPayments: canReadCollectionPayments,
        );
      } catch (error) {
        refreshError = error;
      }
    }
    final key = _key(query);
    final controller = _streams[key];
    if (controller != null) {
      await _load(query, controller, refreshError: refreshError);
    }
  }

  Future<void> _load(
    OrderQuery query,
    StreamController<OrderSnapshot> controller, {
    Object? refreshError,
  }) async {
    try {
      final result = await RuntimeLocalOrderReader(sessions).read(query);
      final items = result.rows.map(_map).toList(growable: false);
      controller.add(
        OrderSnapshot(
          status: items.isEmpty ? OrderLoadStatus.empty : OrderLoadStatus.data,
          items: items,
          totalCount: result.count,
          query: query,
          refreshError: refreshError,
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
      clientOrderRef: row['client_order_ref'] as String?,
      companyId: row['company_id'] as int? ?? 0,
      authorId: row['user_id'] as int? ?? 0,
      businessState: state,
      syncState: row['is_synced'] == true
          ? OperationSyncState.synced
          : OperationSyncState.localOnly,
      pickingIds: _pickingIds(row['picking_ids']),
      pendingCollection: _pendingCollection(row),
      pendingInvoicing: _pendingInvoicing(row),
      partnerName: row['partner_name'] as String?,
      dateOrder: _dateOrder(row['date_order']),
      amountTotal: (row['amount_total'] as num?)?.toDouble(),
      currencySymbol: row['currency_symbol'] as String?,
      sellerName: row['user_name'] as String?,
      amountUntaxed: (row['amount_untaxed'] as num?)?.toDouble(),
      amountTax: (row['amount_tax'] as num?)?.toDouble(),
    );
  }

  static DateTime? _dateOrder(Object? raw) => switch (raw) {
    String value => DateTime.tryParse(value),
    int millis => DateTime.fromMillisecondsSinceEpoch(millis),
    _ => null,
  };

  static List<int> _pickingIds(Object? raw) {
    if (raw is! String || raw.trim().isEmpty) return const [];
    try {
      final value = jsonDecode(raw);
      return value is List
          ? value.whereType<num>().map((id) => id.toInt()).toList()
          : const [];
    } catch (_) {
      return const [];
    }
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
