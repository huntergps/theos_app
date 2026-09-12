import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';

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
/// Por orden del dueño (11-sep-2026) — *«todos los listados deben tener el
/// mismo aspecto»* — la tabla se pinta con el `OrbiListing` estándar en vez
/// de una rejilla Syncfusion propia con una lista de tarjetas aparte: el
/// filtro de almacén sigue siendo un `ComboBox` (no es texto libre, así que
/// no encaja en el filtro de `OrbiListing`), pero el filtro de texto libre
/// ahora escribe directamente en el `TextBox` que trae `OrbiListing`, en vez
/// de duplicar un segundo campo de búsqueda.
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
  int _pageIndex = 0;

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

  void _updateFilter(WarehouseExistencesFilter Function() next) {
    setState(() {
      _filter = next();
      _pageIndex = 0;
    });
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
          child: OrbiListing<StockQuantRow>(
            rows: filtered,
            columns: _columns(),
            storageKey: 'warehouse-existences',
            filterText: _filter.text,
            onFilterChanged: (value) =>
                _updateFilter(() => _filter.copyWith(text: value)),
            filterPlaceholder: 'Buscar producto o ubicación',
            pageIndex: _pageIndex,
            totalCount: filtered.length,
            onPageChanged: (index) => setState(() => _pageIndex = index),
            emptyMessage: data.rows.isEmpty
                ? 'No hay existencias registradas para esta compañía.'
                : 'Ningún producto coincide con el filtro aplicado.',
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
            onChanged: (value) =>
                _updateFilter(() => _filter.copyWith(warehouseId: () => value)),
          ),
        ),
      ),
    ],
  );

  List<OrbiColumn<StockQuantRow>> _columns() => [
    OrbiColumn(
      key: 'product',
      label: 'Producto',
      value: (row) => row.productName,
      alwaysVisible: true,
    ),
    OrbiColumn(key: 'location', label: 'Ubicación', value: (row) => row.locationName),
    OrbiColumn(
      key: 'warehouse',
      label: 'Almacén',
      value: (row) => row.warehouseName ?? '—',
    ),
    OrbiColumn(
      key: 'quantity',
      label: 'A mano',
      numeric: true,
      value: (row) => _qty(row.quantity),
    ),
    OrbiColumn(
      key: 'reserved',
      label: 'Reservado',
      numeric: true,
      value: (row) => _qty(row.reservedQuantity),
    ),
    OrbiColumn(
      key: 'available',
      label: 'Disponible',
      numeric: true,
      value: (row) => _qty(row.availableQuantity),
    ),
    OrbiColumn(
      key: 'reserved_by',
      label: 'Reservado por',
      value: (row) => row.reservedBy ?? '—',
    ),
  ];

  static String _formatCachedAt(DateTime utc) {
    final local = utc.toLocal();
    String two(int v) => v.toString().padLeft(2, '0');
    return '${local.year}-${two(local.month)}-${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }
}
