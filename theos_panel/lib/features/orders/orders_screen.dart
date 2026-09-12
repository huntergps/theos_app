import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../ui/bindings/record_view_controller.dart';
import '../../ui/components/orbi_components.dart';
import '../../ui/components/records/orbi_record_grid.dart';
import 'orders_contracts.dart';
import '../../ui/state_labels.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.repository,
    required this.policy,
    this.filterStore,
    this.scopeKey = 'unscoped',
  });

  final OrderRepository repository;
  final OrderFilterPolicy policy;
  final OrderFilterStore? filterStore;
  final String scopeKey;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late final OrderController _controller = OrderController(
    repository: widget.repository,
    policy: widget.policy,
    filterStore: widget.filterStore,
    scopeKey: widget.scopeKey,
  );
  late final OrbiRecordViewController<OrderListItem> _records =
      OrbiRecordViewController();
  late final TextEditingController _search = TextEditingController();
  late final StreamSubscription<OrderSnapshot> _recordSubscription;

  @override
  void initState() {
    super.initState();
    _recordSubscription = _controller.changes.listen(_syncRecords);
  }

  void _syncRecords(OrderSnapshot snapshot) {
    _records.replaceRecords(
      snapshot.items.map(
        (item) => OrbiRecord<OrderListItem>(id: item.localId, value: item),
      ),
    );
  }

  @override
  void dispose() {
    _search.dispose();
    _recordSubscription.cancel();
    _records.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrbiPageShell(
      title: 'Órdenes',
      actions: [
        FilledButton.icon(
          key: const Key('new-sale-button'),
          onPressed: () => context.go('/sales/counter'),
          icon: const Icon(Icons.add),
          label: const Text('Nueva venta'),
        ),
        IconButton(
          tooltip: 'Actualizar órdenes',
          onPressed: _controller.refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: StreamBuilder<OrderSnapshot>(
        stream: _controller.changes,
        initialData: _controller.snapshot,
        builder: (context, snapshot) {
          final state = snapshot.data ?? _controller.snapshot;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _filters(context),
              const SizedBox(height: 12),
              Semantics(
                liveRegion: true,
                label: '${state.totalCount} órdenes',
                child: Text(
                  '${state.totalCount} órdenes',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      _body(context, constraints.maxWidth, state),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _filters(BuildContext context) {
    final canAll = widget.policy.canSelect(OrderFilter.all);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 320,
          child: TextField(
            controller: _search,
            onChanged: _controller.setText,
            decoration: const InputDecoration(
              labelText: 'Buscar órdenes',
              prefixIcon: Icon(Icons.search),
            ),
          ),
        ),
        if (widget.policy.canSelect(OrderFilter.mine))
          FilterChip(
            label: const Text('Mis ventas'),
            selected: _controller.filter == OrderFilter.mine,
            onSelected: (_) => _controller.setFilter(OrderFilter.mine),
          ),
        if (canAll)
          FilterChip(
            label: const Text('Todas'),
            selected: _controller.filter == OrderFilter.all,
            onSelected: (_) => _controller.setFilter(OrderFilter.all),
          ),
        if (widget.policy.canSelect(OrderFilter.cashierPending))
          FilterChip(
            label: const Text('Pendientes de caja'),
            selected: _controller.filter == OrderFilter.cashierPending,
            onSelected: (_) =>
                _controller.setFilter(OrderFilter.cashierPending),
          ),
      ],
    );
  }

  Widget _body(BuildContext context, double width, OrderSnapshot state) {
    return switch (state.status) {
      OrderLoadStatus.initial || OrderLoadStatus.loading => const Center(
        child: CircularProgressIndicator(),
      ),
      OrderLoadStatus.empty => const OrbiEmptyState(
        title: 'Sin órdenes',
        message: 'No hay órdenes visibles con este filtro.',
      ),
      OrderLoadStatus.error => OrbiErrorState(
        message: 'No se pudieron cargar las órdenes.',
        onRetry: _controller.refresh,
      ),
      OrderLoadStatus.data => _orderList(context, width, state),
    };
  }

  Widget _orderList(BuildContext context, double width, OrderSnapshot state) {
    return OrbiRecordGrid<OrderListItem>(
      controller: _records,
      columns: [
        OrbiRecordColumn(
          id: 'order',
          label: 'Orden',
          value: (item) => item.title,
        ),
        OrbiRecordColumn(
          id: 'business',
          label: 'Estado comercial',
          value: (item) => item.businessState.code,
        ),
        OrbiRecordColumn(
          id: 'sync',
          label: 'Sincronización',
          value: (item) => item.syncState.name,
        ),
        OrbiRecordColumn(
          id: 'pending',
          label: 'Pendiente',
          value: (item) => item.pendingCollection
              ? 'Cobro'
              : item.pendingInvoicing
              ? 'Facturación'
              : '—',
        ),
      ],
      cardBuilder: (context, record) => _orderCard(context, record.value),
      onRecordTap: (record) => _showOrderDetail(context, record.value),
    );
  }

  Widget _orderCard(BuildContext context, OrderListItem item) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(item.title, style: Theme.of(context).textTheme.titleMedium),
            if (item.clientOrderRef case final reference?
                when reference.trim().isNotEmpty)
              Text(reference),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                OrbiStatusChip(label: 'Negocio: ${item.businessState.code}'),
                OrbiStatusChip(label: syncStateLabel(item.syncState)),
                OrbiStatusChip(
                  label: fiscalStateLabelOrNone(item.fiscalState),
                ),
              ],
            ),
            if (item.pendingCollection || item.pendingInvoicing) ...[
              const SizedBox(height: 8),
              Text(
                [
                  if (item.pendingCollection) 'Pendiente por cobrar',
                  if (item.pendingInvoicing) 'Pendiente por facturar',
                ].join(' · '),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showOrderDetail(BuildContext context, OrderListItem item) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(item.title),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text('Estado comercial: ${item.businessState.code}'),
              Text('Estado local: ${syncStateLabel(item.syncState)}'),
              Text(
                'Estado fiscal: ${fiscalStateLabelOrNone(item.fiscalState)}',
              ),
              if (item.pendingCollection) const Text('Pendiente por cobrar'),
              if (item.pendingInvoicing) const Text('Pendiente por facturar'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
