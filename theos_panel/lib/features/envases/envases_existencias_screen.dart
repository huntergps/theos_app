import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/export/export_listing.dart';
import '../../ui/fluent/orbi_page.dart';
import 'envases_existencias_contracts.dart';

/// ENV-01 — Existencias de envases.
///
/// Lee exclusivamente por [EnvasesExistenciasRepository.watch]: la copia
/// local reactiva que expone `EnvasesExistenciasCache`. Una vez que un ciclo
/// de sincronización deja una copia nueva en SQLite, esta pantalla se
/// actualiza sola — nunca vuelve a preguntarle a Odoo sólo porque está en
/// pantalla.
///
/// Ni una sede ni un sentido de tránsito están escritos aquí: cada columna
/// de la rejilla sale, en el orden que entregue el servidor, de
/// `l10n_ec.envases.existencias.datos()` (`EnvasesExistenciasReader`).
///
/// Por orden del dueño (11-sep-2026) — *«todos los listados deben tener el
/// mismo aspecto»* — la ficha en estrecho la pinta el `OrbiListing`
/// estándar: `OrbiColumn.subtitle` pone la unidad de medida bajo el nombre
/// del producto, `OrbiColumn.metric` dibuja cada columna dinámica en su
/// propio recuadro, y `OrbiListing.cardBadge` pinta el total del producto en
/// la esquina del título.
class EnvasesExistenciasScreen extends StatefulWidget {
  const EnvasesExistenciasScreen({super.key, required this.repository, this.onExport});

  final EnvasesExistenciasRepository repository;
  final ListingExporter? onExport;

  @override
  State<EnvasesExistenciasScreen> createState() =>
      _EnvasesExistenciasScreenState();
}

class _EnvasesExistenciasScreenState extends State<EnvasesExistenciasScreen> {
  bool _refreshing = false;
  Object? _refreshError;
  String _productQuery = '';

  // Capturado una sola vez: `watch()` debe seguir siendo la misma
  // suscripción entre reconstrucciones (escribir en el filtro reconstruye
  // este widget en cada tecla). Volver a llamar a `widget.repository.watch()`
  // desde `build()` resuscribiría en cada reconstrucción en vez de reusar un
  // único flujo vivo.
  late final Stream<EnvasesExistenciasSnapshot?> _snapshots =
      widget.repository.watch();

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
    title: 'Existencias de envases',
    commands: [
      CommandBarButton(
        key: const Key('envases-existencias-refresh-button'),
        icon: _refreshing
            ? const SizedBox(
                width: 16,
                height: 16,
                child: ProgressRing(strokeWidth: 2),
              )
            : const Icon(FluentIcons.refresh),
        label: const Text('Actualizar'),
        tooltip: 'Actualizar existencias de envases',
        onPressed: _refreshing ? null : _refresh,
      ),
    ],
    child: StreamBuilder<EnvasesExistenciasSnapshot?>(
      // Esta suscripción es lo que hace que la pantalla reaccione sola a una
      // sincronización terminada: `EnvasesExistenciasCache.watch()` vuelve a
      // emitir cuando la tabla local cambia, sin que este widget lo pida.
      stream: _snapshots,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return OrbiErrorState(
            message: 'No se pudo leer la copia local de existencias.',
            onRetry: _refresh,
          );
        }
        final value = snapshot.data;
        if (value == null) {
          if (_refreshError != null) {
            return OrbiErrorState(
              message: 'No se pudo actualizar las existencias de envases.',
              onRetry: _refresh,
            );
          }
          return const Center(
            child: ProgressRing(key: Key('envases-existencias-loading')),
          );
        }
        return _body(context, value);
      },
    ),
  );

  Widget _body(BuildContext context, EnvasesExistenciasSnapshot snapshot) {
    final data = snapshot.data;
    final rows = _filteredRows(data.filas);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _header(context, snapshot),
        if (_refreshError != null) ...[
          const SizedBox(height: 8),
          _ErrorBanner(onRetry: _refresh),
        ],
        const SizedBox(height: 12),
        Expanded(
          child: data.filas.isEmpty
              ? const OrbiEmptyState(
                  title: 'Sin existencias',
                  message: 'No hay productos con existencia de envases.',
                )
              : Card(
                  backgroundColor: FluentTheme.of(
                    context,
                  ).scaffoldBackgroundColor,
                  borderColor: FluentTheme.of(
                    context,
                  ).resources.surfaceStrokeColorDefault,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.all(8),
                  child: OrbiListing<EnvasesExistenciasRow>(
                    rows: rows,
                    columns: _columns(data.columnas),
                    storageKey: 'envases-existencias',
                    filterText: _productQuery,
                    onFilterChanged: (value) => setState(
                      () => _productQuery = value.trim().toLowerCase(),
                    ),
                    filterPlaceholder: 'Filtrar por producto o unidad',
                    onExport: widget.onExport == null
                        ? null
                        : (bytes, name) => widget.onExport!(context, bytes, name),
                    exportFileName: 'envases-existencias',
                    cardBadge: (row) => '${_formatQuantity(row.total)} propios',
                    emptyMessage: 'No hay productos que coincidan con el filtro.',
                  ),
                ),
        ),
      ],
    );
  }

  List<EnvasesExistenciasRow> _filteredRows(List<EnvasesExistenciasRow> rows) =>
      _productQuery.isEmpty
      ? rows
      : rows
            .where(
              (row) =>
                  row.nombre.toLowerCase().contains(_productQuery) ||
                  row.uom.toLowerCase().contains(_productQuery),
            )
            .toList(growable: false);

  /// Columnas de la rejilla: producto, unidad, una por cada `columna` que
  /// entregó `datos()` (en su mismo orden) y, al final, el total — nunca un
  /// nombre de sede o de sentido cableado aquí.
  List<OrbiColumn<EnvasesExistenciasRow>> _columns(
    List<EnvasesExistenciasColumn> columnas,
  ) => [
    OrbiColumn(
      key: 'product',
      label: 'Producto',
      value: (row) => row.nombre,
      alwaysVisible: true,
    ),
    OrbiColumn(
      key: 'uom',
      label: 'Unidad',
      value: (row) => row.uom,
      subtitle: true,
    ),
    for (final columna in columnas)
      OrbiColumn<EnvasesExistenciasRow>(
        key: 'col-${columna.id}',
        label: columna.nombre,
        numeric: true,
        metric: true,
        value: (row) => _formatQuantity(row.celdas[columna.id] ?? 0),
      ),
    OrbiColumn(
      key: 'total',
      label: 'Total',
      numeric: true,
      emphasis: true,
      value: (row) => _formatQuantity(row.total),
    ),
  ];

  Widget _header(BuildContext context, EnvasesExistenciasSnapshot snapshot) {
    final typography = FluentTheme.of(context).typography;
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Existencias de envases', style: typography.subtitle),
          const SizedBox(height: 4),
          Text(
            'Última actualización en este equipo: ${_formatDate(snapshot.cachedAt)}',
            style: typography.body,
          ),
          const SizedBox(height: 12),
          _PendingWork(pendientes: snapshot.data.pendientes),
        ],
      ),
    );
  }
}

/// «Trabajo de hoy», acotado en este encargo a la cifra `pendientes` de
/// `datos()`: sólo el número, sin abrir la lista de traslados por recibir —
/// esa lista es otro encargo.
class _PendingWork extends StatelessWidget {
  const _PendingWork({required this.pendientes});

  final int pendientes;

  @override
  Widget build(BuildContext context) {
    final resources = FluentTheme.of(context).resources;
    final theme = FluentTheme.of(context);
    return Container(
      key: const Key('envases-existencias-pendientes'),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: resources.subtleFillColorSecondary,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.delivery_truck, size: 16),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'Trabajo de hoy · Traslados por recibir:',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 6),
          Text('$pendientes', style: theme.typography.bodyStrong),
        ],
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
    return Card(
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
                Text('No se pudo actualizar las existencias.'),
                Text('Se conserva la última copia disponible.'),
              ],
            ),
          ),
          if (onRetry != null)
            Button(onPressed: onRetry, child: const Text('Reintentar')),
        ],
      ),
    );
  }
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
