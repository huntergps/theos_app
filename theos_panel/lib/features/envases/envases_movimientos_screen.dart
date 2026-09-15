import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/export/export_listing.dart';
import '../../ui/fluent/orbi_page.dart';
import 'widgets/lista_actualizado_en.dart';

/// Movimientos de envases (ENV-02): traza cada línea de `stock.move.line`
/// que tocó una ubicación de envases, del más reciente al más antiguo.
///
/// El filtro de fechas narrows sobre la copia local ya descargada — la
/// misma disciplina "sin conexión se ve lo último" que el resto de Envases;
/// [onRefresh] es la única vez que esta pantalla vuelve a pedirle a Odoo.
///
/// `stock.move.line.envases_movimientos()` no entrega ni "tipo" (transferencia
/// / entrega / devolución) ni "estado" del documento — sólo fecha, producto,
/// cantidad, sentido, sede y responsable (`EnvasesMovimientoRow`). ENV-02
/// pide esas dos columnas de más; no se fabrican aquí porque el servidor no
/// las da todavía (ver `docs/orbi_panel/reports/` para el contrato vigente).
class EnvasesMovimientosScreen extends StatefulWidget {
  const EnvasesMovimientosScreen({
    super.key,
    required this.snapshots,
    this.onRefresh,
    this.isConnected,
    this.onExport,
  });

  final Stream<EnvasesMovimientosSnapshot?> snapshots;
  final VoidCallback? onRefresh;
  final bool? isConnected;
  final ListingExporter? onExport;

  @override
  State<EnvasesMovimientosScreen> createState() => _EnvasesMovimientosScreenState();
}

class _EnvasesMovimientosScreenState extends State<EnvasesMovimientosScreen> {
  StreamSubscription<EnvasesMovimientosSnapshot?>? _subscription;
  EnvasesMovimientosSnapshot? _snapshot;
  Object? _error;
  bool _waiting = true;
  DateTime? _desde;
  DateTime? _hasta;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _subscription = widget.snapshots.listen(
      (value) {
        if (!mounted) return;
        setState(() {
          _snapshot = value;
          _error = null;
          _waiting = false;
        });
      },
      onError: (Object error, StackTrace stack) {
        if (!mounted) return;
        setState(() {
          _error = error;
          _waiting = false;
        });
      },
    );
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  List<EnvasesMovimientoRow> _filtrados(List<EnvasesMovimientoRow> rows) {
    return rows.where((row) {
      if (_desde != null && row.date.isBefore(_desde!)) return false;
      if (_hasta != null && row.date.isAfter(_hasta!)) return false;
      if (_query.isNotEmpty) {
        final haystack = [
          row.productName,
          row.pickingName ?? '',
          row.desde ?? '',
          row.hacia ?? '',
          row.warehouseName ?? '',
          row.responsableName ?? '',
        ].join(' ').toLowerCase();
        if (!haystack.contains(_query)) return false;
      }
      return true;
    }).toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return OrbiPage(
      title: 'Movimientos de envases',
      subtitle: 'Trazabilidad de envases retornables en toda la cadena',
      commands: [
        CommandBarButton(
          key: const Key('envases-movimientos-refresh'),
          icon: const Icon(FluentIcons.refresh),
          label: const Text('Actualizar'),
          tooltip: 'Actualizar movimientos',
          onPressed: widget.onRefresh,
        ),
      ],
      child: _waiting && _snapshot == null && _error == null
          ? const Center(child: ProgressRing(key: Key('envases-movimientos-loading')))
          : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      if (_error != null) {
        return OrbiErrorState(message: 'No se pudo cargar los movimientos.', onRetry: widget.onRefresh);
      }
      return const OrbiEmptyState(
        title: 'Sin datos descargados',
        message: 'Aún no hay una copia local de los movimientos de envases.',
      );
    }
    final rows = _filtrados(snapshot.rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ListaActualizadoEn(cachedAt: snapshot.cachedAt),
        ),
        const SizedBox(height: 8),
        _filtroFechas(context),
        const SizedBox(height: 12),
        Expanded(
          child: rows.isEmpty
              ? const OrbiEmptyState(title: 'Sin movimientos', message: 'No hay movimientos en el rango elegido.')
              : Card(
                  padding: const EdgeInsets.all(8),
                  child: OrbiListing<EnvasesMovimientoRow>(
                    rows: rows,
                    storageKey: 'envases-movimientos',
                    filterText: _query,
                    onFilterChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                    filterPlaceholder: 'Buscar por documento, producto o cliente',
                    onRowTap: (row) => _abrirDetalle(context, row),
                    onExport: widget.onExport == null
                        ? null
                        : (bytes, name) => widget.onExport!(context, bytes, name),
                    exportFileName: 'envases-movimientos',
                    emptyMessage: 'No hay movimientos que coincidan con el filtro.',
                    columns: [
                      OrbiColumn(key: 'date', label: 'Fecha', value: (row) => _formatDate(row.date), alwaysVisible: true),
                      OrbiColumn(key: 'picking', label: 'Documento', value: (row) => row.pickingName ?? '—'),
                      OrbiColumn(key: 'producto', label: 'Producto', value: (row) => row.productName),
                      OrbiColumn(
                        key: 'cantidad',
                        label: 'Unidades',
                        numeric: true,
                        emphasis: true,
                        value: (row) => _formatQuantity(row.quantity),
                      ),
                      OrbiColumn(key: 'origen', label: 'Origen', value: (row) => row.desde ?? '—'),
                      OrbiColumn(key: 'destino', label: 'Destino', value: (row) => row.hacia ?? '—'),
                      OrbiColumn(key: 'sede', label: 'Sede', value: (row) => row.warehouseName ?? '—'),
                      OrbiColumn(key: 'responsable', label: 'Responsable', value: (row) => row.responsableName ?? '—'),
                    ],
                  ),
                ),
        ),
      ],
    );
  }

  Widget _filtroFechas(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        InfoLabel(
          label: 'Desde',
          child: DatePicker(
            key: const Key('envases-movimientos-desde'),
            selected: _desde,
            onChanged: (value) => setState(() => _desde = value),
          ),
        ),
        InfoLabel(
          label: 'Hasta',
          child: DatePicker(
            key: const Key('envases-movimientos-hasta'),
            selected: _hasta,
            onChanged: (value) => setState(() => _hasta = DateTime(value.year, value.month, value.day, 23, 59, 59)),
          ),
        ),
        if (_desde != null || _hasta != null)
          Button(
            key: const Key('envases-movimientos-limpiar-filtro'),
            onPressed: () => setState(() {
              _desde = null;
              _hasta = null;
            }),
            child: const Text('Limpiar'),
          ),
      ],
    );
  }

  void _abrirDetalle(BuildContext context, EnvasesMovimientoRow row) {
    showDialog<void>(
      context: context,
      builder: (context) => ContentDialog(
        title: Text(row.productName),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fecha: ${_formatDate(row.date)}'),
            Text('Cantidad: ${_formatQuantity(row.quantity)}'),
            Text('Desde: ${row.desde ?? '—'}'),
            Text('Hacia: ${row.hacia ?? '—'}'),
            Text('Sede: ${row.warehouseName ?? '—'}'),
            Text('Responsable: ${row.responsableName ?? '—'}'),
            Text('Documento: ${row.pickingName ?? '—'}'),
          ],
        ),
        actions: [Button(onPressed: () => Navigator.pop(context), child: const Text('Cerrar'))],
      ),
    );
  }
}

String _formatQuantity(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

String _formatDate(DateTime value) {
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
