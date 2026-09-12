import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/fluent/orbi_page.dart';

/// Read-only Envases dashboard surface.
///
/// The runtime owns the query, cache and synchronization. This widget only
/// renders snapshots supplied by [snapshots] and delegates refresh intent to
/// [onRefresh].
///
/// Por orden del dueño (11-sep-2026) — *«todos los listados deben tener el
/// mismo aspecto»* — la ficha en estrecho la pinta el `OrbiListing` estándar,
/// no un `cardBuilder` propio: `OrbiColumn.subtitle` pone la unidad de medida
/// bajo el nombre del producto, `OrbiColumn.metric` dibuja las cinco cifras en
/// su cuadrícula de recuadros, y `OrbiListing.cardBadge` pinta «N propios» en
/// la esquina del título. El total propio sigue siendo, además, una columna
/// normal de la rejilla ancha, igual que antes.
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
      _listen();
    }
  }

  void _listen() {
    final generation = _streamGeneration;
    _subscription = widget.snapshots.listen(
      (value) {
        if (!mounted || generation != _streamGeneration) return;
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
            child: OrbiListing<EnvasesDashboardRow>(
              rows: _filteredRows(snapshot.rows),
              columns: _columns,
              storageKey: 'envases-dashboard',
              filterText: _productQuery,
              onFilterChanged: (value) =>
                  setState(() => _productQuery = value.trim().toLowerCase()),
              filterPlaceholder: 'Filtrar por producto o unidad',
              onRowTap: widget.onProductTap == null
                  ? null
                  : (row) => widget.onProductTap!(row.productId),
              cardBadge: (row) => '${_formatQuantity(row.totalPropio)} propios',
              emptyMessage: 'No hay productos que coincidan con el filtro.',
            ),
          ),
        ),
      ],
    );
  }

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

  List<OrbiColumn<EnvasesDashboardRow>> get _columns => [
    OrbiColumn(
      key: 'product',
      label: 'Producto',
      value: (row) => row.productName,
      alwaysVisible: true,
    ),
    OrbiColumn(
      key: 'packaging',
      label: 'Envase / unidad',
      value: (row) => row.uomName,
      subtitle: true,
    ),
    OrbiColumn(
      key: 'total_propio',
      label: 'Total propio',
      numeric: true,
      value: (row) => '${_formatQuantity(row.totalPropio)} ${row.uomName}',
    ),
    _metricColumn('en_sede', 'En sede', (row) => row.enSede),
    _metricColumn(
      'en_custodia_cliente',
      'Custodia cliente',
      (row) => row.enCustodiaCliente,
    ),
    _metricColumn(
      'en_custodia_proveedor',
      'Custodia proveedor',
      (row) => row.enCustodiaProveedor,
    ),
    _metricColumn('en_transito', 'En tránsito', (row) => row.enTransito),
    _metricColumn(
      'danados',
      'Dañados (incluidos en total)',
      (row) => row.danados,
    ),
  ];

  OrbiColumn<EnvasesDashboardRow> _metricColumn(
    String key,
    String label,
    double Function(EnvasesDashboardRow) value,
  ) => OrbiColumn(
    key: key,
    label: label,
    numeric: true,
    metric: true,
    value: (row) => '${_formatQuantity(value(row))} ${row.uomName}',
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
