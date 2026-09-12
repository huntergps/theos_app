import 'package:fluent_ui/fluent_ui.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'package:orbi_runtime/orbi_runtime.dart';

import '../../app/theme/orbi_theme.dart';
import '../../ui/components/orbi_components.dart';
import '../../ui/fluent/orbi_page.dart';
import 'warehouse_existences_contracts.dart';

/// BOD-01 — inventario de existencias.
///
/// Reads exclusively through [WarehouseExistencesRepository.watch], the
/// reactive local copy `StockQuantCache` exposes: once a sync completes and
/// commits a new snapshot to SQLite, this screen updates on its own — it
/// never re-queries Odoo just because it is on screen.
///
/// Deliberately absent: `costo_promedio` (`stock.quant`, gated behind
/// `groups='stock.group_stock_manager'` in
/// `l10n_ec_stock_base/models/stock_quant.py`). The app's own capability
/// model — `CapabilityProvisioner` in
/// `theos_pos_core/lib/src/services/operations/capability_provisioner.dart`
/// — folds `stock.group_stock_user` AND `stock.group_stock_manager` into the
/// single `'warehouse'` permission; there is no signal today that tells a
/// screen "this specific user is a stock MANAGER, not just stock staff".
/// Gating the column on `'warehouse'` would show it to every warehouse
/// worker, not only the manager Odoo restricts it to — and a placeholder or
/// a zero would be read as a real (and wrong) cost. So this screen shows the
/// column to **nobody**, for every viewer, until that capability is split.
/// `StockQuantReader` already never requests the field, so there is no data
/// to leak by mistake.
class WarehouseExistencesScreen extends StatefulWidget {
  const WarehouseExistencesScreen({super.key, required this.repository});

  final WarehouseExistencesRepository repository;

  @override
  State<WarehouseExistencesScreen> createState() =>
      _WarehouseExistencesScreenState();
}

String _qty(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

class _WarehouseExistencesScreenState
    extends State<WarehouseExistencesScreen> {
  WarehouseExistencesFilter _filter = const WarehouseExistencesFilter();
  bool _refreshing = false;
  Object? _refreshError;

  // Captured once: `watch()` must stay the same subscription across
  // rebuilds (typing in the search field rebuilds this widget on every
  // keystroke). Calling `widget.repository.watch()` again from `build()`
  // would resubscribe on every rebuild instead of reusing one live stream.
  late final Stream<StockQuantSnapshot?> _snapshots = widget.repository.watch();

  @override
  void initState() {
    super.initState();
    _refresh();
  }

  Future<void> _refresh() async {
    setState(() {
      _refreshing = true;
      _refreshError = null;
    });
    try {
      await widget.repository.refresh();
    } catch (error) {
      if (mounted) setState(() => _refreshError = error);
    } finally {
      if (mounted) setState(() => _refreshing = false);
    }
  }

  @override
  Widget build(BuildContext context) => OrbiPage(
    title: 'Inventario de existencias',
    commands: [
      CommandBarButton(
        key: const Key('existences-refresh-button'),
        icon: _refreshing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: ProgressRing(strokeWidth: 2),
              )
            : const Icon(FluentIcons.refresh),
        label: const Text('Actualizar'),
        tooltip: 'Actualizar inventario',
        onPressed: _refreshing ? null : _refresh,
      ),
    ],
    child: StreamBuilder<StockQuantSnapshot?>(
      // This subscription is what makes the screen react to a completed
      // sync on its own: `StockQuantCache.watch()` re-emits whenever the
      // local table changes, with no request from this widget.
      stream: _snapshots,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return OrbiErrorState(
            message: 'No se pudo leer el inventario local.',
            onRetry: _refresh,
          );
        }
        final data = snapshot.data;
        if (data == null) {
          if (_refreshError != null) {
            return OrbiErrorState(
              message: 'No se pudo actualizar el inventario.',
              onRetry: _refresh,
            );
          }
          return const Center(
            child: ProgressRing(key: Key('existences-loading')),
          );
        }
        return _body(context, data);
      },
    ),
  );

  Widget _body(BuildContext context, StockQuantSnapshot data) {
    final warehouses = WarehouseExistencesFilter.warehousesIn(data.rows);
    final filtered = _filter.apply(data.rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _filters(context, warehouses),
        const SizedBox(height: OrbiTheme.space8),
        Text(
          key: const Key('existences-updated-at'),
          'Copia local actualizada: ${_formatCachedAt(data.cachedAt)}',
          style: FluentTheme.of(context).typography.caption,
        ),
        const SizedBox(height: OrbiTheme.space12),
        Expanded(
          child: filtered.isEmpty
              ? OrbiEmptyState(
                  title: 'Sin existencias',
                  message: data.rows.isEmpty
                      ? 'No hay existencias registradas para esta compañía.'
                      : 'Ningún producto coincide con el filtro aplicado.',
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    // Real available space decides the layout — same rule
                    // as CollectionSessionHubScreen and OperationalShell:
                    // wide (desktop/tablet-landscape) gets the table, the
                    // rest (tablet-portrait/phone) gets the card list. No
                    // hardcoded height threshold.
                    final wide =
                        constraints.maxWidth >= OrbiTheme.compactBreakpoint &&
                        constraints.maxWidth >= constraints.maxHeight;
                    return wide
                        ? _table(context, filtered)
                        : _list(context, filtered);
                  },
                ),
        ),
      ],
    );
  }

  Widget _filters(BuildContext context, List<(int, String)> warehouses) => Wrap(
    spacing: OrbiTheme.space12,
    runSpacing: OrbiTheme.space8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 220,
        child: InfoLabel(
          label: 'Almacén',
          child: ComboBox<int?>(
            key: const Key('existences-warehouse-filter'),
            value: _filter.warehouseId,
            isExpanded: true,
            items: [
              const ComboBoxItem(value: null, child: Text('Todos')),
              for (final warehouse in warehouses)
                ComboBoxItem(value: warehouse.$1, child: Text(warehouse.$2)),
            ],
            onChanged: (value) => setState(
              () => _filter = _filter.copyWith(warehouseId: () => value),
            ),
          ),
        ),
      ),
      SizedBox(
        width: 260,
        child: OrbiField(
          key: const Key('existences-search-field'),
          label: 'Buscar producto o ubicación',
          onChanged: (value) => setState(
            () => _filter = _filter.copyWith(text: value),
          ),
        ),
      ),
    ],
  );

  Widget _table(BuildContext context, List<StockQuantRow> rows) => SfDataGrid(
    key: const Key('existences-table'),
    source: _ExistencesDataSource(rows),
    columnWidthMode: ColumnWidthMode.fill,
    columns: [
      _column('product', 'Producto'),
      _column('location', 'Ubicación'),
      _column('warehouse', 'Almacén'),
      _column('quantity', 'A mano', numeric: true),
      _column('reserved', 'Reservado', numeric: true),
      _column('available', 'Disponible', numeric: true),
      _column('detail', 'Detalle'),
    ],
  );

  GridColumn _column(String name, String label, {bool numeric = false}) =>
      GridColumn(
        columnName: name,
        label: Container(
          alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            label,
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
        ),
      );

  Widget _list(BuildContext context, List<StockQuantRow> rows) =>
      ListView.separated(
        key: const Key('existences-list'),
        itemCount: rows.length,
        separatorBuilder: (_, _) => const SizedBox(height: OrbiTheme.space8),
        itemBuilder: (context, index) => _card(context, rows[index]),
      );

  Widget _card(BuildContext context, StockQuantRow row) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          row.productName,
          style: FluentTheme.of(context).typography.bodyStrong,
        ),
        const SizedBox(height: OrbiTheme.space4),
        Text('${row.locationName} · ${row.warehouseName ?? 'Sin almacén'}'),
        const SizedBox(height: OrbiTheme.space8),
        Wrap(
          spacing: OrbiTheme.space8,
          runSpacing: OrbiTheme.space4,
          children: [
            OrbiStatusChip(label: 'A mano: ${_qty(row.quantity)}'),
            OrbiStatusChip(
              label: 'Reservado: ${_qty(row.reservedQuantity)}',
              icon: FluentIcons.lock,
            ),
            OrbiStatusChip(
              label: 'Disponible: ${_qty(row.availableQuantity)}',
              icon: FluentIcons.package,
            ),
          ],
        ),
        if (row.reservedBy != null) ...[
          const SizedBox(height: OrbiTheme.space8),
          Text(
            'Reservado por: ${row.reservedBy}',
            style: TextStyle(
              color: FluentTheme.of(context).resources.textFillColorSecondary,
            ),
          ),
        ],
      ],
    ),
  );

  static String _formatCachedAt(DateTime utc) {
    final local = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}

/// A one-shot, read-only grid source: the screen rebuilds a fresh one on
/// every `build()` (the underlying rows already come from a `watch()`
/// stream, so there is no local selection or edit state to preserve across
/// rebuilds here).
class _ExistencesDataSource extends DataGridSource {
  _ExistencesDataSource(List<StockQuantRow> rows)
    : _rows = [
        for (final row in rows)
          DataGridRow(
            cells: [
              DataGridCell<String>(columnName: 'product', value: row.productName),
              DataGridCell<String>(
                columnName: 'location',
                value: row.locationName,
              ),
              DataGridCell<String>(
                columnName: 'warehouse',
                value: row.warehouseName ?? '—',
              ),
              DataGridCell<String>(
                columnName: 'quantity',
                value: _qty(row.quantity),
              ),
              DataGridCell<String>(
                columnName: 'reserved',
                value: _qty(row.reservedQuantity),
              ),
              DataGridCell<String>(
                columnName: 'available',
                value: _qty(row.availableQuantity),
              ),
              DataGridCell<String>(
                columnName: 'detail',
                value: row.reservedBy ?? '',
              ),
            ],
          ),
      ];

  final List<DataGridRow> _rows;

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) => DataGridRowAdapter(
    cells: row.getCells().map((cell) {
      final numeric = const {
        'quantity',
        'reserved',
        'available',
      }.contains(cell.columnName);
      return Container(
        alignment: numeric ? Alignment.centerRight : Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        child: Text('${cell.value}'),
      );
    }).toList(),
  );
}
