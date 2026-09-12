import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/components/records/orbi_record_grid.dart';
import '../../ui/bindings/record_view_controller.dart';
import '../../ui/fluent/orbi_page.dart';

/// Read-only Envases dashboard surface.
///
/// The runtime owns the query, cache and synchronization. This widget only
/// renders snapshots supplied by [snapshots] and delegates refresh intent to
/// [onRefresh].
class EnvasesDashboardScreen extends StatefulWidget {
  const EnvasesDashboardScreen({
    super.key,
    required this.snapshots,
    this.workspaceEnvases = 'Envases',
    this.isConnected,
    this.onRefresh,
    this.onProductTap,
  });

  final Stream<EnvasesDashboardSnapshot?> snapshots;
  final String workspaceEnvases;
  final bool? isConnected;
  final VoidCallback? onRefresh;
  final ValueChanged<int>? onProductTap;

  @override
  State<EnvasesDashboardScreen> createState() => _EnvasesDashboardScreenState();
}

class _EnvasesDashboardScreenState extends State<EnvasesDashboardScreen> {
  StreamSubscription<EnvasesDashboardSnapshot?>? _subscription;
  int _streamGeneration = 0;
  late final OrbiRecordViewController<EnvasesDashboardRow> _controller =
      OrbiRecordViewController<EnvasesDashboardRow>();
  late final TextEditingController _productFilter = TextEditingController();
  EnvasesDashboardSnapshot? _snapshot;
  Object? _error;
  bool _waiting = true;
  String _productQuery = '';

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant EnvasesDashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshots != widget.snapshots) {
      _streamGeneration++;
      _subscription?.cancel();
      _snapshot = null;
      _error = null;
      _waiting = true;
      _controller.clearSelection();
      _controller.replaceRecords(const <OrbiRecord<EnvasesDashboardRow>>[]);
      _listen();
    }
  }

  void _listen() {
    final generation = _streamGeneration;
    _subscription = widget.snapshots.listen(
      (value) {
        if (!mounted || generation != _streamGeneration) return;
        _controller.replaceRecords(_recordsFor(value));
        setState(() {
          _snapshot = value;
          _error = null;
          _waiting = false;
        });
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted || generation != _streamGeneration) return;
        setState(() {
          _error = error;
          _waiting = false;
        });
      },
      onDone: () {
        if (!mounted || generation != _streamGeneration) return;
        setState(() => _waiting = false);
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _productFilter.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return OrbiPage(
      title: widget.workspaceEnvases,
      commands: [
        _WidgetCommandBarItem(_ConnectionStatus(connected: widget.isConnected)),
        CommandBarButton(
          key: const Key('envases-refresh-button'),
          icon: const Icon(FluentIcons.refresh),
          label: const Text('Actualizar'),
          tooltip: 'Actualizar envases',
          onPressed: widget.onRefresh,
        ),
      ],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _DashboardHeader(title: widget.workspaceEnvases, snapshot: _snapshot),
          if (_snapshot?.rows.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Card(
                backgroundColor: FluentTheme.of(
                  context,
                ).resources.cardBackgroundFillColorSecondary,
                borderColor: FluentTheme.of(
                  context,
                ).resources.surfaceStrokeColorDefault,
                borderRadius: BorderRadius.circular(12),
                child: InfoLabel(
                  label: 'Filtrar por producto o unidad',
                  child: TextBox(
                    key: const Key('envases-product-filter'),
                    controller: _productFilter,
                    prefix: const Padding(
                      padding: EdgeInsets.only(left: 8),
                      child: Icon(FluentIcons.search),
                    ),
                    onChanged: (value) {
                      setState(
                        () => _productQuery = value.trim().toLowerCase(),
                      );
                      _controller.replaceRecords(_recordsFor(_snapshot));
                    },
                  ),
                ),
              ),
            ),
          if (_error != null) _ErrorBanner(onRetry: widget.onRefresh),
          if (_snapshot?.rows.isNotEmpty ?? false)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                'Mostrando ${_filteredRows(_snapshot!.rows).length} de '
                '${_snapshot!.rows.length} registros',
                key: const Key('envases-filtered-count'),
              ),
            ),
          if (_waiting && _snapshot == null && _error == null)
            const Expanded(child: Center(child: ProgressRing()))
          else
            Expanded(
              child: _error != null && _snapshot == null
                  ? OrbiErrorState(
                      message: 'No se pudo cargar el dashboard de envases.',
                      onRetry: widget.onRefresh,
                    )
                  : _content(context),
            ),
        ],
      ),
    );
  }

  Widget _content(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      return const OrbiEmptyState(
        title: 'Sin datos descargados',
        message: 'Aún no hay una copia local del dashboard de envases.',
      );
    }
    if (snapshot.rows.isEmpty) {
      return const OrbiEmptyState(
        title: 'Sin registros',
        message: 'No hay productos de envases en la copia local.',
      );
    }
    final filtered = _filteredRows(snapshot.rows);
    if (filtered.isEmpty) {
      return const OrbiEmptyState(
        title: 'Sin coincidencias',
        message: 'No hay productos que coincidan con el filtro.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (widget.onProductTap == null)
          const Padding(
            padding: EdgeInsets.only(bottom: 8),
            child: Text(
              'Vista agregada; detalle por ubicación no disponible en esta conexión',
            ),
          ),
        Expanded(
          child: Card(
            backgroundColor: FluentTheme.of(context).scaffoldBackgroundColor,
            borderColor: FluentTheme.of(
              context,
            ).resources.surfaceStrokeColorDefault,
            borderRadius: BorderRadius.circular(12),
            padding: const EdgeInsets.all(8),
            child: OrbiRecordGrid<EnvasesDashboardRow>(
              controller: _controller,
              columns: _columns,
              cardBuilder: _envasesCard,
              onRecordTap: widget.onProductTap == null
                  ? null
                  : (record) => widget.onProductTap!(record.value.productId),
            ),
          ),
        ),
      ],
    );
  }

  List<OrbiRecord<EnvasesDashboardRow>> _recordsFor(
    EnvasesDashboardSnapshot? snapshot,
  ) => [
    for (final row in _filteredRows(snapshot?.rows ?? const []))
      OrbiRecord<EnvasesDashboardRow>(
        id: '${row.companyId}:${row.productId}',
        value: row,
      ),
  ];

  List<EnvasesDashboardRow> _filteredRows(List<EnvasesDashboardRow> rows) =>
      _productQuery.isEmpty
      ? rows
      : rows
            .where(
              (row) =>
                  row.productName.toLowerCase().contains(_productQuery) ||
                  row.uomName.toLowerCase().contains(_productQuery),
            )
            .toList(growable: false);

  List<OrbiRecordColumn<EnvasesDashboardRow>> get _columns => [
    OrbiRecordColumn(
      id: 'product',
      label: 'Producto',
      value: (row) => row.productName,
    ),
    OrbiRecordColumn(
      id: 'packaging',
      label: 'Envase / unidad',
      value: (row) => row.uomName,
    ),
    _quantityColumn('total_propio', 'Total propio', (row) => row.totalPropio),
    _quantityColumn('en_sede', 'En sede', (row) => row.enSede),
    _quantityColumn(
      'en_custodia_cliente',
      'Custodia cliente',
      (row) => row.enCustodiaCliente,
    ),
    _quantityColumn(
      'en_custodia_proveedor',
      'Custodia proveedor',
      (row) => row.enCustodiaProveedor,
    ),
    _quantityColumn('en_transito', 'En tránsito', (row) => row.enTransito),
    _quantityColumn(
      'danados',
      'Dañados (incluidos en total)',
      (row) => row.danados,
    ),
  ];

  OrbiRecordColumn<EnvasesDashboardRow> _quantityColumn(
    String id,
    String label,
    double Function(EnvasesDashboardRow) value,
  ) => OrbiRecordColumn(
    id: id,
    label: label,
    textAlign: TextAlign.end,
    value: (row) => '${_formatQuantity(value(row))} ${row.uomName}',
  );

  Widget _envasesCard(
    BuildContext context,
    OrbiRecord<EnvasesDashboardRow> record,
  ) {
    final row = record.value;
    final metrics = <String, double>{
      'En sede': row.enSede,
      'Custodia cliente': row.enCustodiaCliente,
      'Custodia proveedor': row.enCustodiaProveedor,
      'En tránsito': row.enTransito,
      'Dañados': row.danados,
    };
    return Card(
      margin: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columns = constraints.maxWidth >= 600 ? 2 : 1;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          row.productName,
                          style: FluentTheme.of(context).typography.bodyStrong,
                        ),
                        Text(row.uomName),
                      ],
                    ),
                  ),
                  OrbiStatusChip(
                    label: '${_formatQuantity(row.totalPropio)} propios',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              for (var index = 0; index < metrics.length; index += columns)
                Padding(
                  padding: EdgeInsets.only(
                    bottom: index + columns < metrics.length ? 8 : 0,
                  ),
                  child: Row(
                    children: [
                      for (final entry
                          in metrics.entries.skip(index).take(columns))
                        Expanded(
                          child: Padding(
                            padding: EdgeInsetsDirectional.only(
                              end:
                                  entry.key ==
                                      metrics.entries
                                          .skip(index)
                                          .take(columns)
                                          .last
                                          .key
                                  ? 0
                                  : 8,
                            ),
                            child: _metric(
                              context,
                              entry.key,
                              entry.value,
                              row.uomName,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _metric(
    BuildContext context,
    String label,
    double value,
    String unit,
  ) => DecoratedBox(
    decoration: BoxDecoration(
      color: FluentTheme.of(context).resources.cardBackgroundFillColorSecondary,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: FluentTheme.of(context).typography.caption),
          Text('${_formatQuantity(value)} $unit'),
        ],
      ),
    ),
  );
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader({required this.title, required this.snapshot});

  final String title;
  final EnvasesDashboardSnapshot? snapshot;

  @override
  Widget build(BuildContext context) {
    final typography = FluentTheme.of(context).typography;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Estado de envases', style: typography.subtitle),
          const SizedBox(height: 4),
          const Text('Consulta la propiedad de envases por producto y unidad.'),
          if (snapshot != null) ...[
            const SizedBox(height: 4),
            Text(
              'Última descarga en este equipo: ${_formatDate(snapshot!.cachedAt)}',
              style: typography.body,
            ),
          ],
        ],
      ),
    );
  }
}

/// Insignia de estado de conexión. El color sigue el significado, no la
/// forma: verde cuando hay conexión confirmada, rojo cuando se sabe que no
/// la hay, gris cuando todavía no se ha verificado — nunca al revés.
class _ConnectionStatus extends StatelessWidget {
  const _ConnectionStatus({required this.connected});

  final bool? connected;

  @override
  Widget build(BuildContext context) {
    final resources = FluentTheme.of(context).resources;
    final (icon, color, label) = switch (connected) {
      null => (FluentIcons.cloud, resources.textFillColorSecondary, 'Red sin verificar'),
      true => (FluentIcons.cloud, resources.systemFillColorSuccess, 'Conectado'),
      false => (
        FluentIcons.cloud_not_synced,
        resources.systemFillColorCritical,
        'Sin conexión',
      ),
    };
    return Semantics(
      label: label,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: resources.subtleFillColorSecondary,
          borderRadius: const BorderRadius.all(Radius.circular(4)),
          border: Border.all(color: color),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ExcludeSemantics(child: Icon(icon, size: 16, color: color)),
              const SizedBox(width: 6),
              ExcludeSemantics(
                child: Text(
                  label,
                  style: FluentTheme.of(context).typography.caption,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.onRetry});

  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final resources = FluentTheme.of(context).resources;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        backgroundColor: resources.systemFillColorCriticalBackground,
        borderColor: resources.systemFillColorCritical,
        borderRadius: BorderRadius.circular(12),
        child: Row(
          children: [
            Icon(FluentIcons.error_badge, color: resources.systemFillColorCritical),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('No se pudo actualizar el dashboard.'),
                  Text('Se conserva la última copia disponible.'),
                ],
              ),
            ),
            if (onRetry != null)
              Button(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

/// Adapta un widget cualquiera (no un botón) para la barra de acciones de
/// [OrbiPage], que sólo entiende [CommandBarItem]. Existe porque el estado de
/// conexión no es una acción: es una insignia informativa.
class _WidgetCommandBarItem extends CommandBarItem {
  const _WidgetCommandBarItem(this.child) : super(key: null);

  final Widget child;

  @override
  Widget build(BuildContext context, CommandBarItemDisplayMode displayMode) =>
      Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
        child: child,
      );
}

String _formatQuantity(double value) => value == value.roundToDouble()
    ? value.toInt().toString()
    : value.toString();

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} '
      '${two(local.hour)}:${two(local.minute)}';
}
