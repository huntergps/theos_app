import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import '../grid/theos_data_grid.dart';
import '../grid/theos_data_grid_source.dart';
import '../../../core/theme/spacing.dart';

/// Configuration for a DataGrid column
///
/// This is a simplified column definition that can be used to
/// generate GridColumn instances.
class DataGridColumnConfig {
  /// Column identifier (must be unique)
  final String name;

  /// Header label text
  final String label;

  /// Fixed width (null for auto/fill)
  final double? width;

  /// Width mode for the column
  final ColumnWidthMode widthMode;

  /// Whether sorting is allowed
  final bool allowSorting;

  /// Header alignment
  final AlignmentGeometry headerAlignment;

  const DataGridColumnConfig({
    required this.name,
    required this.label,
    this.width,
    this.widthMode = ColumnWidthMode.none,
    this.allowSorting = true,
    this.headerAlignment = Alignment.centerLeft,
  });

  /// Create a GridColumn from this config
  GridColumn toGridColumn(BuildContext context) {
    return GridColumn(
      columnName: name,
      width: width ?? double.nan,
      columnWidthMode: widthMode,
      allowSorting: allowSorting,
      label: TheosDataGrid.buildHeaderLabel(
        label,
        context,
        alignment: headerAlignment,
      ),
    );
  }
}

/// A reactive DataGrid widget that automatically updates when data changes
///
/// This widget watches a provider and automatically rebuilds when the data
/// changes. It handles loading, error, and empty states internally.
///
/// Usage:
/// ```dart
/// ReactiveDataGrid<SaleOrder>(
///   dataProvider: filteredSaleOrdersProvider,
///   columns: [
///     DataGridColumnConfig(name: 'name', label: 'Referencia', width: 120),
///     DataGridColumnConfig(name: 'customer', label: 'Cliente', widthMode: ColumnWidthMode.fill),
///   ],
///   rowBuilder: (order) => [
///     DataGridCell(columnName: 'name', value: order.name),
///     DataGridCell(columnName: 'customer', value: order.partnerName),
///   ],
///   cellBuilders: {
///     'state': (context, cell) => TheosStateChip(label: cell.value.label),
///   },
///   onRowTap: (order) => openOrder(order),
///   emptyMessage: 'No hay órdenes',
///   storageKey: 'sale_orders',
/// )
/// ```
class ReactiveDataGrid<T> extends ConsumerStatefulWidget {
  /// Provider that supplies the list data (e.g., `Provider.autoDispose<AsyncValue<List<T>>>`)
  final dynamic dataProvider;

  /// Column configurations
  final List<DataGridColumnConfig> columns;

  /// Function to build DataGridCells from a data item
  final List<DataGridCell> Function(T item) rowBuilder;

  /// Custom cell builders for specific columns
  final Map<String, Widget Function(BuildContext context, DataGridCell cell)>?
      cellBuilders;

  /// Callback when a row is tapped
  final void Function(T item)? onRowTap;

  /// Callback when export button is pressed
  final VoidCallback? onExport;

  /// Storage key for persisting column widths
  final String? storageKey;

  /// Message to show when data is empty
  final String emptyMessage;

  /// Secondary message for empty state
  final String? emptySubMessage;

  /// Icon for empty state
  final IconData emptyIcon;

  /// Whether to show pagination
  final bool showPager;

  /// Rows per page for pagination
  final int rowsPerPage;

  /// Whether to allow sorting
  final bool allowSorting;

  /// Callback for refresh action
  final Future<void> Function()? onRefresh;

  const ReactiveDataGrid({
    super.key,
    required this.dataProvider,
    required this.columns,
    required this.rowBuilder,
    this.cellBuilders,
    this.onRowTap,
    this.onExport,
    this.storageKey,
    this.emptyMessage = 'No hay datos',
    this.emptySubMessage,
    this.emptyIcon = FluentIcons.info,
    this.showPager = true,
    this.rowsPerPage = 80,
    this.allowSorting = true,
    this.onRefresh,
  });

  @override
  ConsumerState<ReactiveDataGrid<T>> createState() =>
      _ReactiveDataGridState<T>();
}

class _ReactiveDataGridState<T> extends ConsumerState<ReactiveDataGrid<T>> {
  final GlobalKey<SfDataGridState> _gridKey = GlobalKey<SfDataGridState>();
  late TheosDataGridSource<T> _dataSource;

  @override
  void initState() {
    super.initState();
    _initializeDataSource([]);
  }

  void _initializeDataSource(List<T> data) {
    _dataSource = TheosDataGridSource<T>(
      data: data,
      rowBuilder: widget.rowBuilder,
      cellBuilders: widget.cellBuilders,
    );
    // Configure pagination settings
    _dataSource.setRowsPerPage(widget.rowsPerPage);
  }

  @override
  Widget build(BuildContext context) {
    final watchedValue = ref.watch(widget.dataProvider);
    final spacing = ref.watch(themedSpacingProvider);

    // Handle both StreamProvider (returns AsyncValue) and
    // Provider<AsyncValue<...>> (returns AsyncValue directly)
    final AsyncValue<List<T>> asyncData;
    if (watchedValue is AsyncValue<List<T>>) {
      asyncData = watchedValue;
    } else {
      // Assume it's a provider that returns AsyncValue when watched
      asyncData = watchedValue as AsyncValue<List<T>>;
    }

    return asyncData.when(
      data: (items) {
        // Update data source when data changes
        _dataSource.updateData(items);
        // Ensure pagination settings are current
        _dataSource.setRowsPerPage(widget.rowsPerPage);

        if (items.isEmpty) {
          return _EmptyState(
            icon: widget.emptyIcon,
            message: widget.emptyMessage,
            subMessage: widget.emptySubMessage,
            onRefresh: widget.onRefresh,
            spacing: spacing,
          );
        }

        return TheosDataGrid(
          gridKey: _gridKey,
          source: _dataSource,
          columns: widget.columns.map((c) => c.toGridColumn(context)).toList(),
          showPager: widget.showPager,
          rowsPerPage: widget.rowsPerPage,
          allowSorting: widget.allowSorting,
          storageKey: widget.storageKey,
          onExport: widget.onExport,
          onCellTap: widget.onRowTap != null
              ? (details) {
                  if (details.rowColumnIndex.rowIndex > 0) {
                    final rowIndex = details.rowColumnIndex.rowIndex - 1;
                    // Use getItem to get the correct item based on current sort order
                    final item = _dataSource.getItem(rowIndex);
                    if (item != null) {
                      widget.onRowTap!(item);
                    }
                  }
                }
              : null,
        );
      },
      loading: () => const Center(child: ProgressRing()),
      error: (error, stack) => _ErrorState(
        error: error,
        onRetry: widget.onRefresh,
        spacing: spacing,
      ),
    );
  }

  /// Export grid to Excel
  Future<void> exportToExcel(String fileName) async {
    final grid = TheosDataGrid(
      gridKey: _gridKey,
      source: _dataSource,
      columns: widget.columns.map((c) => c.toGridColumn(context)).toList(),
    );
    await grid.exportToExcel(fileName);
  }
}

/// Empty state widget
class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String message;
  final String? subMessage;
  final Future<void> Function()? onRefresh;
  final ThemedSpacing spacing;

  const _EmptyState({
    required this.icon,
    required this.message,
    this.subMessage,
    this.onRefresh,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.grey[100]),
          spacing.vertical.md,
          Text(message, style: theme.typography.subtitle),
          if (subMessage != null) ...[
            spacing.vertical.sm,
            Text(subMessage!, style: theme.typography.caption),
          ],
          if (onRefresh != null) ...[
            spacing.vertical.md,
            FilledButton(
              onPressed: onRefresh,
              child: const Text('Actualizar'),
            ),
          ],
        ],
      ),
    );
  }
}

/// Error state widget
class _ErrorState extends StatelessWidget {
  final Object error;
  final Future<void> Function()? onRetry;
  final ThemedSpacing spacing;

  const _ErrorState({
    required this.error,
    this.onRetry,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.error_badge, size: 48, color: Colors.red),
          spacing.vertical.md,
          const Text('Error al cargar datos'),
          spacing.vertical.sm,
          Text(
            error.toString(),
            style: theme.typography.caption,
            textAlign: TextAlign.center,
          ),
          if (onRetry != null) ...[
            spacing.vertical.md,
            FilledButton(
              onPressed: onRetry,
              child: const Text('Reintentar'),
            ),
          ],
        ],
      ),
    );
  }
}
