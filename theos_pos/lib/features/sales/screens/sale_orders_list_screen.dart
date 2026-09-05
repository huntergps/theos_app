import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show SaleOrder, SaleOrderState, SaleOrderStateExtension;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/repositories/repository_providers.dart';

import 'package:odoo_sdk/odoo_sdk.dart' show logger;

import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../../shared/widgets/common_grid_widgets.dart';
import '../../../../shared/widgets/reactive/reactive_search_bar.dart';
import '../../../../shared/widgets/reactive/reactive_data_grid.dart';
import '../providers/sale_order_tabs_provider.dart';
import '../providers/sale_orders_list_providers.dart';
import '../ui/sale_order_ui_extensions.dart';
import 'sale_order_list/sale_orders_list_mobile.dart';

/// Pantalla de lista de órdenes de venta - Versión reactiva
///
/// Características:
/// - Búsqueda con facets/chips al estilo Odoo
/// - Filtros como chips removibles dentro del campo de búsqueda
/// - Actualización reactiva cuando cambian los datos
/// - Soporte para desktop (DataGrid) y mobile (Cards)
class SaleOrdersScreen extends ConsumerStatefulWidget {
  const SaleOrdersScreen({super.key});

  @override
  ConsumerState<SaleOrdersScreen> createState() => _SaleOrdersScreenState();
}

class _SaleOrdersScreenState extends ConsumerState<SaleOrdersScreen> {
  bool _isLoading = false;
  final GlobalKey<SfDataGridState> _gridKey = GlobalKey<SfDataGridState>();

  Future<void> _syncOrders() async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    try {
      logger.d('[SaleOrdersScreen] 🔄 Syncing sale orders...');
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      if (catalogRepo != null) {
        // Navigation is local-first. Network work happens only when the user
        // explicitly requests refresh, so reopening the screen is instant and
        // fully usable offline.
        await catalogRepo.syncSaleOrders(batchSize: 200);
        logger.d('[SaleOrdersScreen] ✅ Sale orders refreshed');
      }
    } catch (e) {
      logger.d('[SaleOrdersScreen] ❌ Error syncing orders: $e');
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error de sincronización',
          message:
              'No se pudieron sincronizar las ordenes. Intente nuevamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDetail(SaleOrder order) {
    ref.read(saleOrderTabsProvider.notifier).openOrder(order.id, order.name);
  }

  void _createNewOrder() {
    ref.read(saleOrderTabsProvider.notifier).openNewOrder();
  }

  void _onFilterChanged(List<SearchFacet> facets) {
    logger.d('[SaleOrdersScreen] Filters changed: ${facets.map((f) => f.id)}');
  }

  void _onFilterSelected(String filterId, String value) {
    logger.d('[SaleOrdersScreen] Filter selected: $filterId = $value');
  }

  void _onSearch(String query) {
    final normalized = query.trim();
    if (normalized.length < 2) return;
    final catalogRepo = ref.read(catalogSyncRepositoryProvider);
    if (catalogRepo == null) return;

    // The list paints immediately from Drift. Search remote in the background
    // so records outside the initial page are upserted into the same stream.
    unawaited(catalogRepo.searchSaleOrdersWithLines(normalized, limit: 50));
  }

  Future<void> _exportToExcel() async {
    final grid = TheosDataGrid(
      gridKey: _gridKey,
      source: TheosDataGridSource<SaleOrder>(data: [], rowBuilder: _buildRow),
      columns: [],
    );
    await grid.exportToExcel(
      'ordenes_venta_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}',
    );
  }

  @override
  Widget build(BuildContext context) {
    final ordersCountAsync = ref.watch(saleOrdersCountProvider);
    final unsyncedCountAsync = ref.watch(unsyncedOrdersCountProvider);
    final countsError = ordersCountAsync.when<Object?>(
      data: (_) => null,
      loading: () => null,
      error: (error, _) => error,
    );

    return ScaffoldPage(
      header: PageHeader(
        title: Row(
          children: [
            const Text('Órdenes de Venta'),
            ...unsyncedCountAsync.when(
              data: (count) => count > 0
                  ? [const SizedBox(width: 8), _SyncBadge(count: count)]
                  : const <Widget>[],
              loading: () => const <Widget>[],
              error: (error, _) => [
                const SizedBox(width: 8),
                _SyncBadge(error: error),
              ],
            ),
          ],
        ),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: _isLoading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : const Icon(FluentIcons.refresh),
              label: const Text('Actualizar'),
              onPressed: _isLoading ? null : _syncOrders,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.add),
              label: const Text('Nueva Orden'),
              onPressed: _createNewOrder,
            ),
          ],
        ),
      ),
      content: Column(
        children: [
          // Search bar with Odoo-style facets
          ReactiveSearchBar<String, SalesSearchBarNotifier>(
            provider: salesSearchBarProvider,
            placeholder: 'Buscar órdenes...',
            filterSections: [
              FilterMenuSection<String>(
                title: 'Filtros',
                icon: FluentIcons.filter,
                options: [
                  FilterOption(
                    id: 'my_orders',
                    label: 'Mis cotizaciones',
                    value: 'my_orders',
                    icon: FluentIcons.contact,
                    facetLabel: 'Vendedor',
                  ),
                ],
              ),
              FilterMenuSection<String>(
                title: 'Estado',
                icon: FluentIcons.status_circle_checkmark,
                options: [
                  FilterOption(
                    id: 'draft',
                    label: 'Cotización',
                    value: 'draft',
                    icon: FluentIcons.document,
                    facetLabel: 'Estado',
                  ),
                  FilterOption(
                    id: 'sent',
                    label: 'Enviado',
                    value: 'sent',
                    icon: FluentIcons.send,
                    facetLabel: 'Estado',
                  ),
                  FilterOption(
                    id: 'waiting',
                    label: 'Esperando aprobación',
                    value: 'waiting',
                    icon: FluentIcons.clock,
                    facetLabel: 'Estado',
                  ),
                  FilterOption(
                    id: 'approved',
                    label: 'Aprobado',
                    value: 'approved',
                    icon: FluentIcons.completed,
                    facetLabel: 'Estado',
                  ),
                  FilterOption(
                    id: 'rejected',
                    label: 'Rechazado',
                    value: 'rejected',
                    icon: FluentIcons.status_error_full,
                    facetLabel: 'Estado',
                  ),
                  FilterOption(
                    id: 'sale',
                    label: 'Orden de venta',
                    value: 'sale',
                    icon: FluentIcons.accept,
                    facetLabel: 'Estado',
                  ),
                  FilterOption(
                    id: 'cancel',
                    label: 'Cancelado',
                    value: 'cancel',
                    icon: FluentIcons.cancel,
                    facetLabel: 'Estado',
                  ),
                ],
              ),
            ],
            quickFilters: [
              QuickFilter(
                id: 'my_orders',
                label: 'Mis cotizaciones',
                icon: FluentIcons.contact,
              ),
              QuickFilter(
                id: 'draft',
                label:
                    'Cotizaciones (${_formatOrderCount(ordersCountAsync, 'draft')})',
                icon: FluentIcons.document,
              ),
              QuickFilter(
                id: 'sale',
                label:
                    'Confirmadas (${_formatOrderCount(ordersCountAsync, 'sale')})',
                icon: FluentIcons.accept,
                color: Colors.green,
              ),
              QuickFilter(
                id: 'waiting',
                label:
                    'Por aprobar (${_formatOrderCount(ordersCountAsync, 'waiting')})',
                icon: FluentIcons.clock,
                color: Colors.orange,
              ),
            ],
            onFilterChanged: _onFilterChanged,
            onFilterSelected: _onFilterSelected,
            onSearch: _onSearch,
          ),

          if (countsError != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: InfoBar(
                title: const Text('No se pudieron calcular los contadores'),
                content: Text(countsError.toString()),
                severity: InfoBarSeverity.error,
              ),
            ),

          // Responsive content: DataGrid or Cards
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isLargeScreen = constraints.maxWidth > 800;

                if (isLargeScreen) {
                  return _DesktopDataGrid(
                    gridKey: _gridKey,
                    onOrderTap: _navigateToDetail,
                    onExport: _exportToExcel,
                    onRefresh: _syncOrders,
                  );
                } else {
                  return _MobileList(onOrderTap: _navigateToDetail);
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// Desktop DataGrid view using ReactiveDataGrid
class _DesktopDataGrid extends ConsumerWidget {
  final GlobalKey<SfDataGridState> gridKey;
  final void Function(SaleOrder) onOrderTap;
  final VoidCallback onExport;
  final Future<void> Function() onRefresh;

  const _DesktopDataGrid({
    required this.gridKey,
    required this.onOrderTap,
    required this.onExport,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshot = ref.watch(saleOrdersListSnapshotProvider).value;
    return ReactiveDataGrid<SaleOrder>(
      gridKey: gridKey,
      dataProvider: filteredSaleOrdersProvider,
      storageKey: 'sale_orders',
      showPager: true,
      rowsPerPage: salesListPageSize,
      totalRowCount: snapshot?.totalCount,
      currentPageIndex: snapshot?.pageIndex ?? 0,
      onPageChanged: (pageIndex) async {
        ref.read(salesListPageIndexProvider.notifier).setPage(pageIndex);
        return true;
      },
      // Database paging is ordered by date. Sorting only the visible page
      // would be misleading, so column sorting remains disabled until a sort
      // key is explicitly part of the SQL query.
      allowSorting: false,
      emptyMessage: 'No hay órdenes',
      emptySubMessage: 'Crea una nueva orden para comenzar',
      emptyIcon: FluentIcons.receipt_processing,
      onRowTap: onOrderTap,
      onExport: onExport,
      onRefresh: onRefresh,
      columns: const [
        DataGridColumnConfig(
          name: 'reference',
          label: 'Referencia',
          width: 120,
        ),
        DataGridColumnConfig(
          name: 'customer',
          label: 'Cliente',
          widthMode: ColumnWidthMode.fill,
        ),
        DataGridColumnConfig(
          name: 'date',
          label: 'Fecha de la orden',
          width: 160,
        ),
        DataGridColumnConfig(
          name: 'subtotal',
          label: 'Subtotal',
          width: 110,
          headerAlignment: Alignment.centerRight,
        ),
        DataGridColumnConfig(
          name: 'taxes',
          label: 'Impuestos',
          width: 100,
          headerAlignment: Alignment.centerRight,
        ),
        DataGridColumnConfig(
          name: 'total',
          label: 'Total',
          width: 110,
          headerAlignment: Alignment.centerRight,
        ),
        DataGridColumnConfig(
          name: 'state',
          label: 'Estado',
          width: 130,
          allowSorting: true,
          headerAlignment: Alignment.center,
        ),
        DataGridColumnConfig(
          name: 'salesperson',
          label: 'Vendedor',
          width: 140,
        ),
      ],
      rowBuilder: _buildRow,
      cellBuilders: _cellBuilders,
    );
  }
}

/// Mobile card list view
class _MobileList extends ConsumerWidget {
  final void Function(SaleOrder) onOrderTap;

  const _MobileList({required this.onOrderTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ordersAsync = ref.watch(filteredSaleOrdersProvider);

    return ordersAsync.when(
      data: (orders) {
        if (orders.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  FluentIcons.receipt_processing,
                  size: 64,
                  color: Colors.grey[100],
                ),
                const SizedBox(height: 16),
                Text(
                  'No hay órdenes',
                  style: FluentTheme.of(context).typography.subtitle,
                ),
              ],
            ),
          );
        }
        final snapshot = ref.watch(saleOrdersListSnapshotProvider).value;
        final pageIndex = snapshot?.pageIndex ?? 0;
        final totalCount = snapshot?.totalCount ?? orders.length;
        final hasPrevious = pageIndex > 0;
        final hasNext = (pageIndex + 1) * salesListPageSize < totalCount;
        return Column(
          children: [
            Expanded(
              child: SaleOrdersMobile(orders: orders, onOrderTap: onOrderTap),
            ),
            if (hasPrevious || hasNext)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Button(
                      onPressed: hasPrevious
                          ? () => ref
                                .read(salesListPageIndexProvider.notifier)
                                .setPage(pageIndex - 1)
                          : null,
                      child: const Text('Anterior'),
                    ),
                    Text(
                      '${pageIndex + 1} / '
                      '${(totalCount / salesListPageSize).ceil()}',
                    ),
                    Button(
                      onPressed: hasNext
                          ? () => ref
                                .read(salesListPageIndexProvider.notifier)
                                .setPage(pageIndex + 1)
                          : null,
                      child: const Text('Siguiente'),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
      loading: () => const Center(child: ProgressRing()),
      error: (error, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(FluentIcons.error_badge, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
          ],
        ),
      ),
    );
  }
}

/// Badge showing unsynced orders count
class _SyncBadge extends StatelessWidget {
  final int? count;
  final Object? error;

  const _SyncBadge({this.count, this.error})
    : assert(count != null || error != null);

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: error == null
          ? '$count órdenes pendientes de sincronizar'
          : 'No se pudo leer el estado de sincronización: $error',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: (error == null ? Colors.orange : Colors.red).withValues(
            alpha: 0.2,
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: error == null ? Colors.orange : Colors.red),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              error == null
                  ? FluentIcons.cloud_upload
                  : FluentIcons.error_badge,
              size: 12,
              color: error == null ? Colors.orange : Colors.red,
            ),
            const SizedBox(width: 4),
            Text(
              error == null ? '$count' : '!',
              style: TextStyle(
                color: error == null ? Colors.orange : Colors.red,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _formatOrderCount(AsyncValue<Map<String, int>> counts, String state) {
  return counts.when(
    data: (value) => '${value[state] ?? 0}',
    loading: () => '…',
    error: (_, _) => '!',
  );
}

// ============================================================================
// Data Grid Row Builder and Cell Builders
// ============================================================================

/// Build DataGrid cells for a sale order
List<DataGridCell> _buildRow(SaleOrder order) {
  return [
    DataGridCell<Map<String, dynamic>>(
      columnName: 'reference',
      value: {'name': order.name, 'isSynced': order.isSynced},
    ),
    DataGridCell<String>(columnName: 'customer', value: order.partnerName),
    DataGridCell<DateTime?>(columnName: 'date', value: order.dateOrder),
    DataGridCell<double>(columnName: 'subtotal', value: order.amountUntaxed),
    DataGridCell<double>(columnName: 'taxes', value: order.amountTax),
    DataGridCell<double>(columnName: 'total', value: order.amountTotal),
    DataGridCell<SaleOrderState>(columnName: 'state', value: order.state),
    DataGridCell<String>(
      columnName: 'salesperson',
      value: order.userName ?? '',
    ),
  ];
}

/// Custom cell builders for specific columns
final _cellBuilders = <String, Widget Function(BuildContext, DataGridCell)>{
  'reference': (context, cell) {
    final data = cell.value as Map<String, dynamic>;
    final name = data['name'] as String;
    final isSynced = data['isSynced'] as bool;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.centerLeft,
      child: Row(
        children: [
          if (!isSynced) ...[
            Tooltip(
              message: 'Pendiente de sincronizar',
              child: Icon(
                FluentIcons.cloud_upload,
                size: 14,
                color: Colors.orange,
              ),
            ),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: Text(
              name,
              style: const TextStyle(
                color: AppColors.referenceText,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  },
  'customer': (context, cell) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12),
    alignment: Alignment.centerLeft,
    child: Text(cell.value?.toString() ?? '', overflow: TextOverflow.ellipsis),
  ),
  'date': (context, cell) => TheosDateCell(value: cell.value as DateTime?),
  'subtotal': (context, cell) => TheosNumberCell(value: cell.value as double),
  'taxes': (context, cell) => TheosNumberCell(value: cell.value as double),
  'total': (context, cell) =>
      TheosNumberCell(value: cell.value as double, isBold: true),
  'state': (context, cell) {
    final state = cell.value as SaleOrderState;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      alignment: Alignment.center,
      child: TheosStateChip(label: state.label, color: state.color),
    );
  },
};
