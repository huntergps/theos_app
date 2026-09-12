import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:odoo_widgets/odoo_widgets.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/export/export_listing.dart';
import '../../ui/fluent/orbi_page.dart';
import '../../ui/state_labels.dart';
import 'orders_contracts.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.repository,
    required this.policy,
    this.filterStore,
    this.scopeKey = 'unscoped',
    this.onExport,
  });

  final OrderRepository repository;
  final OrderFilterPolicy policy;
  final OrderFilterStore? filterStore;
  final String scopeKey;

  /// Cómo guardar el Excel. Lo pone la ruta, que sí tiene con qué leer
  /// la preferencia de duración del aviso. Nulo esconde el botón.
  final ListingExporter? onExport;

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

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrbiPage(
      title: 'Órdenes',
      subtitle: 'Ventas y cotizaciones visibles para tu ámbito',
      commands: [
        CommandBarButton(
          key: const Key('new-sale-button'),
          icon: const Icon(FluentIcons.add),
          label: const Text('Nueva venta'),
          onPressed: () => context.go('/sales/counter'),
        ),
        CommandBarButton(
          key: const Key('orders-refresh-button'),
          icon: const Icon(FluentIcons.refresh),
          label: const Text('Actualizar'),
          tooltip: 'Actualizar órdenes',
          onPressed: _controller.refresh,
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
              // El lector local siempre trae hasta 50 filas por consulta (sin
              // desplazamiento: `RuntimeLocalOrderReader.read`, límite fijo).
              // Cuando el total real es mayor, decirlo en vez de paginar en
              // silencio hacia páginas vacías es lo honesto.
              if (state.totalCount > state.items.length)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: InfoBar(
                    title: const Text('Hay más órdenes de las que se muestran'),
                    content: Text(
                      'Mostrando ${state.items.length} de ${state.totalCount}. '
                      'Filtra o busca para acotar el resultado.',
                    ),
                    severity: InfoBarSeverity.info,
                  ),
                ),
              Expanded(child: _body(context, state)),
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
        if (widget.policy.canSelect(OrderFilter.mine))
          ToggleButton(
            checked: _controller.filter == OrderFilter.mine,
            onChanged: (_) => _controller.setFilter(OrderFilter.mine),
            child: const Text('Mis ventas'),
          ),
        if (canAll)
          ToggleButton(
            checked: _controller.filter == OrderFilter.all,
            onChanged: (_) => _controller.setFilter(OrderFilter.all),
            child: const Text('Todas'),
          ),
        if (widget.policy.canSelect(OrderFilter.cashierPending))
          ToggleButton(
            checked: _controller.filter == OrderFilter.cashierPending,
            onChanged: (_) => _controller.setFilter(OrderFilter.cashierPending),
            child: const Text('Pendientes de caja'),
          ),
      ],
    );
  }

  Widget _body(BuildContext context, OrderSnapshot state) {
    return switch (state.status) {
      OrderLoadStatus.initial ||
      OrderLoadStatus.loading => const Center(child: ProgressRing()),
      OrderLoadStatus.error => OrbiErrorState(
        message: 'No se pudieron cargar las órdenes.',
        onRetry: _controller.refresh,
      ),
      OrderLoadStatus.empty || OrderLoadStatus.data => _listing(context, state),
    };
  }

  Widget _listing(BuildContext context, OrderSnapshot state) {
    return OrbiListing<OrderListItem>(
      rows: state.items,
      columns: _columns(),
      storageKey: 'orders-screen',
      exportFileName: 'pedidos',
      onExport: widget.onExport == null
          ? null
          : (bytes, name) => widget.onExport!(context, bytes, name),
      filterText: _controller.text,
      onFilterChanged: _controller.setText,
      filterPlaceholder: 'Buscar órdenes',
      // Sin desplazamiento en el lector local (ver el aviso de arriba), el
      // paginador sólo puede reflejar honestamente lo que ya está cargado.
      totalCount: state.items.length,
      onRowTap: (item) => _showOrderDetail(context, item),
      emptyMessage: 'Sin órdenes: no hay órdenes visibles con este filtro.',
    );
  }

  List<OrbiColumn<OrderListItem>> _columns() => [
    OrbiColumn(
      key: 'order',
      label: 'Orden',
      value: (item) => item.title,
      alwaysVisible: true,
    ),
    OrbiColumn(
      key: 'business',
      label: 'Estado comercial',
      value: (item) => item.businessState.code,
    ),
    OrbiColumn(
      key: 'sync',
      label: 'Sincronización',
      value: (item) => syncStateLabel(item.syncState),
    ),
    OrbiColumn(
      key: 'fiscal',
      label: 'Estado fiscal',
      value: (item) => fiscalStateLabelOrNone(item.fiscalState),
    ),
    OrbiColumn(
      key: 'pending',
      label: 'Pendiente',
      value: (item) => item.pendingCollection
          ? 'Cobro'
          : item.pendingInvoicing
          ? 'Facturación'
          : '—',
    ),
  ];

  Future<void> _showOrderDetail(BuildContext context, OrderListItem item) {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: Text(item.title),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
          Button(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }
}
