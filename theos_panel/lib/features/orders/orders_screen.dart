import 'package:fluent_ui/fluent_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
// Sólo por `SaleOrderStateExtension.label`: `orbi_runtime` re-exporta el tipo
// `SaleOrderState` con un `show`, y eso no arrastra la extensión que le pone
// nombre en español — hay que traerla de su paquete de origen.
import 'package:theos_pos_core/theos_pos_core.dart'
    show SaleOrderStateExtension;

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
    // La cola de caja ya fija su propio estado (`OrderWorkQueue.cashierPending`
    // sólo trae `sale`); los filtros por estado no aplican ahí.
    final showStateFilters = _controller.filter != OrderFilter.cashierPending;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
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
                onChanged: (_) =>
                    _controller.setFilter(OrderFilter.cashierPending),
                child: const Text('Pendientes de caja'),
              ),
          ],
        ),
        if (showStateFilters) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Contador real de la base local, uno por estado: no es un
              // adorno, es la cuenta de las filas que la consulta local trae
              // para ese estado y ese mismo ámbito (dueño, texto).
              for (final state in orderQuickStates) _stateChip(state),
              _stateMenu(context),
            ],
          ),
        ],
      ],
    );
  }

  Widget _stateChip(SaleOrderState state) {
    final count = _controller.statusCounts[state];
    return ToggleButton(
      key: Key('orders-state-chip-${state.code}'),
      checked: _controller.selectedState == state,
      onChanged: (_) => _controller.setSelectedState(state),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_stateIcon(state), size: 14),
          const SizedBox(width: 6),
          Text(count == null ? state.label : '${state.label} ($count)'),
        ],
      ),
    );
  }

  /// El resto de [SaleOrderState.values] (menos `done`, que ni theos_pos
  /// muestra aquí) — para filtrar por uno que no tiene su propio chip, sin
  /// llenar la barra de botones.
  Widget _stateMenu(BuildContext context) => DropDownButton(
    key: const Key('orders-state-menu'),
    title: const Row(
      mainAxisSize: MainAxisSize.min,
      children: [Icon(FluentIcons.filter), SizedBox(width: 6), Text('Filtros')],
    ),
    items: [
      for (final state in SaleOrderState.values)
        if (state != SaleOrderState.done)
          MenuFlyoutItem(
            text: Text(state.label),
            leading: Icon(_stateIcon(state)),
            selected: _controller.selectedState == state,
            onPressed: () => _controller.setSelectedState(state),
          ),
    ],
  );

  IconData _stateIcon(SaleOrderState state) => switch (state) {
    SaleOrderState.draft => FluentIcons.page,
    SaleOrderState.sent => FluentIcons.send,
    SaleOrderState.waitingApproval => FluentIcons.clock,
    SaleOrderState.approved => FluentIcons.accept,
    SaleOrderState.rejected => FluentIcons.blocked2,
    SaleOrderState.sale => FluentIcons.shopping_cart,
    SaleOrderState.done => FluentIcons.completed_solid,
    SaleOrderState.cancel => FluentIcons.circle_stop,
  };

  Color _stateColor(BuildContext context, SaleOrderState state) {
    final theme = FluentTheme.of(context);
    final resources = theme.resources;
    return switch (state) {
      SaleOrderState.draft => resources.textFillColorSecondary,
      SaleOrderState.sent => theme.accentColor.normal,
      SaleOrderState.waitingApproval => resources.systemFillColorCaution,
      SaleOrderState.approved => theme.accentColor.dark,
      SaleOrderState.rejected => resources.systemFillColorCritical,
      SaleOrderState.sale => resources.systemFillColorSuccess,
      SaleOrderState.done => resources.systemFillColorSuccess,
      SaleOrderState.cancel => resources.systemFillColorCritical,
    };
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
      label: 'Referencia',
      value: (item) => item.title,
      alwaysVisible: true,
      // El mismo aviso que ya usa theos_pos: una nube con flecha antes de la
      // referencia cuando la orden todavía no llegó al servidor. No es un
      // adorno — es `syncState`, el mismo dato que antes sólo se leía en la
      // columna de texto «Sincronización».
      leadingIcon: (item) => item.pendingUpload
          ? (icon: FluentIcons.cloud_upload, color: Colors.orange)
          : null,
    ),
    OrbiColumn(
      key: 'client',
      label: 'Cliente',
      value: (item) => item.partnerName ?? '—',
    ),
    OrbiColumn(
      key: 'date',
      label: 'Fecha de la orden',
      value: (item) => _formatDate(item.dateOrder),
    ),
    OrbiColumn(
      key: 'business',
      label: 'Estado',
      value: (item) => item.businessState.label,
      badgeColor: (item) => _stateColor(context, item.businessState),
    ),
    OrbiColumn(
      key: 'seller',
      label: 'Vendedor',
      value: (item) => item.sellerName ?? '—',
    ),
    OrbiColumn(
      key: 'subtotal',
      label: 'Subtotal',
      value: (item) => _formatAmount(item.amountUntaxed, null),
      numeric: true,
    ),
    OrbiColumn(
      key: 'tax',
      label: 'Impuestos',
      value: (item) => _formatAmount(item.amountTax, null),
      numeric: true,
    ),
    OrbiColumn(
      key: 'total',
      label: 'Total',
      value: (item) => _formatAmount(item.amountTotal, item.currencySymbol),
      numeric: true,
      emphasis: true,
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

  /// `dd/mm/aaaa`, igual que ya lo muestra theos_pos. Sin `intl`: theos_panel
  /// no lo declara como dependencia directa y añadirlo sólo por un formato de
  /// fecha es más de lo que este cambio necesita.
  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    final local = date.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.day)}/${two(local.month)}/${local.year}';
  }

  /// Miles con coma y dos decimales («3,511.99»), con el símbolo de moneda
  /// delante sólo cuando la fila lo trae — la base local de Orbi hoy no
  /// siempre lo guarda, y poner un símbolo fijo sería inventar un dato.
  String _formatAmount(double? amount, String? symbol) {
    if (amount == null) return '—';
    final fixed = amount.toStringAsFixed(2);
    final parts = fixed.split('.');
    final negative = parts[0].startsWith('-');
    final digits = negative ? parts[0].substring(1) : parts[0];
    final grouped = StringBuffer();
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
      grouped.write(digits[i]);
    }
    final formatted = '${negative ? '-' : ''}$grouped.${parts[1]}';
    return symbol == null || symbol.isEmpty ? formatted : '$symbol $formatted';
  }

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
