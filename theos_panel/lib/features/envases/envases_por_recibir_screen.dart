import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/export/export_listing.dart';
import '../../ui/fluent/orbi_page.dart';
import 'envases_traslado_detalle.dart';
import 'widgets/lista_actualizado_en.dart';
import 'widgets/lista_estado_chip.dart';

/// Envases pendientes de recibir (BODEGA-ENVASES «En tránsito», ENV-03
/// pestaña Tránsitos): lo que ya salió de una sede y todavía no confirma
/// llegada la sede destino.
///
/// Sólo lectura y sólo estado local — la pantalla nunca decide qué llegó,
/// eso lo hace el formulario de recepción a través de `EnvasesOperations`.
///
/// Por debajo del corte ancho (el mismo 840 de `OrbiListing`) las filas se
/// agrupan por sentido (origen → destino) en tarjetas — `OrbiListing` no
/// agrupa, así que esta pantalla arma su propia lista angosta en vez de
/// reusar su modo tarjeta automático.
///
/// En escritorio (ENV-03 «Tránsitos», BODEGA-ENVASES «En tránsito»), elegir
/// una fila abre su detalle AL LADO, sin navegar — mismo traslado que la
/// ficha completa (`EnvasesTrasladoDetalle`), reutilizando su cuerpo
/// (`EnvasesTrasladoDetalleBody`) para no duplicar el estado de "dar por
/// perdido". Sólo puede hacerlo cuando [operations] no es nulo: sin permiso
/// de escritura la pantalla sigue navegando a la página completa, igual que
/// antes de este cambio.
class EnvasesPorRecibirScreen extends StatefulWidget {
  const EnvasesPorRecibirScreen({
    super.key,
    required this.snapshots,
    required this.operaciones,
    required this.onOpenDetail,
    this.onRefresh,
    this.isConnected,
    this.operations,
    this.canManage = false,
    this.onRegistrarRecepcion,
    this.onExport,
  });

  final Stream<EnvasesPorRecibirSnapshot?> snapshots;
  final Stream<List<EnvasesOperacionLocal>> operaciones;
  final ValueChanged<EnvasesPorRecibirRow> onOpenDetail;
  final VoidCallback? onRefresh;
  final bool? isConnected;

  /// Presente sólo cuando quien compone la pantalla ya resolvió permiso de
  /// escritura (`envasesOperationsProvider`). Habilita el panel de detalle al
  /// lado en escritorio; nulo conserva el comportamiento anterior (navegar a
  /// una página aparte al tocar una fila).
  final EnvasesOperations? operations;
  final bool canManage;

  /// A dónde ir para registrar la recepción desde el panel al lado. Nulo cae
  /// en [onOpenDetail] (abre la página de detalle completa, que a su vez
  /// ofrece "Registrar recepción").
  final ValueChanged<EnvasesPorRecibirRow>? onRegistrarRecepcion;

  final ListingExporter? onExport;

  @override
  State<EnvasesPorRecibirScreen> createState() => _EnvasesPorRecibirScreenState();
}

class _EnvasesPorRecibirScreenState extends State<EnvasesPorRecibirScreen> {
  StreamSubscription<EnvasesPorRecibirSnapshot?>? _subscription;
  StreamSubscription<List<EnvasesOperacionLocal>>? _operacionesSubscription;
  EnvasesPorRecibirSnapshot? _snapshot;
  List<EnvasesOperacionLocal> _operaciones = const [];
  Object? _error;
  bool _waiting = true;
  String _query = '';
  int? _selectedId;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant EnvasesPorRecibirScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshots != widget.snapshots || oldWidget.operaciones != widget.operaciones) {
      _subscription?.cancel();
      _operacionesSubscription?.cancel();
      _snapshot = null;
      _error = null;
      _waiting = true;
      _listen();
    }
  }

  void _listen() {
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
    _operacionesSubscription = widget.operaciones.listen((value) {
      if (!mounted) return;
      setState(() => _operaciones = value);
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _operacionesSubscription?.cancel();
    super.dispose();
  }

  EnvasesOperacionLocal? _operacionDe(int pickingId) {
    for (final operacion in _operaciones) {
      if (operacion.pickingId == pickingId) return operacion;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return OrbiPage(
      title: 'Envases por recibir',
      subtitle: 'Traslados en tránsito hacia tus sedes',
      commands: [
        CommandBarButton(
          key: const Key('envases-por-recibir-refresh'),
          icon: const Icon(FluentIcons.refresh),
          label: const Text('Actualizar'),
          tooltip: 'Actualizar por recibir',
          onPressed: widget.onRefresh,
        ),
      ],
      child: _waiting && _snapshot == null && _error == null
          ? const Center(child: ProgressRing(key: Key('envases-por-recibir-loading')))
          : _content(context),
    );
  }

  Widget _content(BuildContext context) {
    final snapshot = _snapshot;
    if (snapshot == null) {
      if (_error != null) {
        return OrbiErrorState(message: 'No se pudo cargar los envases por recibir.', onRetry: widget.onRefresh);
      }
      return const OrbiEmptyState(
        title: 'Sin datos descargados',
        message: 'Aún no hay una copia local de los envases por recibir.',
      );
    }
    final rows = _filtered(snapshot.rows);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_error != null) _ErrorBanner(onRetry: widget.onRefresh),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: ListaActualizadoEn(cachedAt: snapshot.cachedAt),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 12),
          child: TextBox(
            key: const Key('envases-por-recibir-filter'),
            placeholder: 'Filtrar por sede o documento',
            prefix: const Padding(padding: EdgeInsets.only(left: 8), child: Icon(FluentIcons.search)),
            onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? const OrbiEmptyState(title: 'Nada pendiente', message: 'No hay envases por recibir.')
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final window = MediaQuery.sizeOf(context);
                    final portrait = window.height > window.width && constraints.maxWidth < 1200;
                    final narrow = constraints.maxWidth < OrbiListing.cardBreakpoint || portrait;
                    if (narrow) return _groupedCards(context, rows);
                    if (widget.operations != null) return _tableWithDetail(context, rows);
                    return _table(context, rows, onRowTap: widget.onOpenDetail);
                  },
                ),
        ),
      ],
    );
  }

  List<EnvasesPorRecibirRow> _filtered(List<EnvasesPorRecibirRow> rows) {
    if (_query.isEmpty) return rows;
    return rows
        .where(
          (row) =>
              row.name.toLowerCase().contains(_query) ||
              (row.origenName ?? '').toLowerCase().contains(_query) ||
              (row.destinoName ?? '').toLowerCase().contains(_query),
        )
        .toList(growable: false);
  }

  EnvasesPorRecibirRow? _selectedRow(List<EnvasesPorRecibirRow> rows) {
    final id = _selectedId;
    if (id == null) return null;
    for (final row in rows) {
      if (row.id == id) return row;
    }
    return null;
  }

  /// ENV-03 «Tránsitos» / BODEGA-ENVASES «En tránsito»: la tabla a la
  /// izquierda, el detalle del traslado elegido a la derecha — sin navegar,
  /// para poder mirar varios traslados seguidos sin perder el filtro ni la
  /// posición de la tabla.
  Widget _tableWithDetail(BuildContext context, List<EnvasesPorRecibirRow> rows) {
    final selected = _selectedRow(rows);
    final table = _table(context, rows, onRowTap: (row) => setState(() => _selectedId = row.id));
    if (selected == null) return table;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 3, child: table),
        const SizedBox(width: 16),
        SizedBox(
          width: 380,
          child: Card(
            key: const Key('envases-por-recibir-detalle-panel'),
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              child: EnvasesTrasladoDetalleBody(
                key: ValueKey('envases-detalle-al-lado-${selected.id}'),
                row: selected,
                operaciones: widget.operations!.watchOperaciones(),
                operations: widget.operations!,
                canManage: widget.canManage,
                onRegistrarRecepcion: () =>
                    (widget.onRegistrarRecepcion ?? widget.onOpenDetail)(selected),
                // El panel se queda abierto: la insignia de estado se
                // actualiza sola por `watchOperaciones()`, no hace falta
                // cerrar nada.
                onDarPorPerdido: () {},
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _table(
    BuildContext context,
    List<EnvasesPorRecibirRow> rows, {
    required ValueChanged<EnvasesPorRecibirRow> onRowTap,
  }) {
    final theme = FluentTheme.of(context);
    return Card(
      key: const Key('envases-por-recibir-tabla'),
      backgroundColor: theme.scaffoldBackgroundColor,
      borderColor: theme.resources.surfaceStrokeColorDefault,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(8),
      child: OrbiListing<EnvasesPorRecibirRow>(
        rows: rows,
        storageKey: 'envases-por-recibir',
        onRowTap: onRowTap,
        onExport: widget.onExport == null
            ? null
            : (bytes, name) => widget.onExport!(context, bytes, name),
        exportFileName: 'envases-por-recibir',
        emptyMessage: 'No hay envases por recibir que coincidan con el filtro.',
        columns: [
          OrbiColumn(key: 'name', label: 'Documento', value: (row) => row.name, alwaysVisible: true),
          OrbiColumn(key: 'origen', label: 'Origen', value: (row) => row.origenName ?? 'Origen desconocido'),
          OrbiColumn(key: 'destino', label: 'Destino', value: (row) => row.destinoName ?? 'Destino desconocido'),
          OrbiColumn(
            key: 'fecha',
            label: 'Fecha de salida',
            value: (row) => _formatDate(row.fechaSalida),
          ),
          OrbiColumn(
            key: 'pendientes',
            label: 'Unidades pendientes',
            numeric: true,
            emphasis: true,
            value: (row) => _formatQuantity(row.unidadesPendientes),
          ),
          OrbiColumn(
            key: 'estado',
            label: 'Estado local',
            value: (row) {
              final operacion = _operacionDe(row.id);
              return operacion == null ? '' : envasesEstadoLabel(operacion.estado, mensajeOdoo: operacion.mensajeOdoo);
            },
            // `OrbiColumn.badgeColor` pinta SIEMPRE una insignia cuando la
            // columna la declara — no hay forma de decir "esta fila no
            // tiene insignia" sin dibujar un recuadro vacío. La mayoría de
            // filas no tiene operación local todavía (recién sincronizadas o
            // nunca tocadas desde este equipo), así que aquí se deja texto
            // plano; la insignia de color sí aparece en la tarjeta angosta y
            // en el panel de detalle, donde sólo se pinta cuando SÍ hay
            // operación (`if (operacion != null) ...`).
          ),
        ],
      ),
    );
  }

  Widget _groupedCards(BuildContext context, List<EnvasesPorRecibirRow> rows) {
    final grouped = <String, List<EnvasesPorRecibirRow>>{};
    for (final row in rows) {
      grouped.putIfAbsent(row.sentido, () => []).add(row);
    }
    final sentidos = grouped.keys.toList()..sort();
    final theme = FluentTheme.of(context);
    return ListView(
      key: const Key('envases-por-recibir-grouped'),
      children: [
        for (final sentido in sentidos) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 6),
            child: Text(sentido, style: theme.typography.bodyStrong, key: Key('envases-grupo-$sentido')),
          ),
          for (final row in grouped[sentido]!) _card(context, row),
        ],
      ],
    );
  }

  Widget _card(BuildContext context, EnvasesPorRecibirRow row) {
    final theme = FluentTheme.of(context);
    final operacion = _operacionDe(row.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: () => widget.onOpenDetail(row),
        child: Card(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(row.name, style: theme.typography.bodyStrong),
              const SizedBox(height: 4),
              Text('Salida: ${_formatDate(row.fechaSalida)}', style: theme.typography.caption),
              const SizedBox(height: 4),
              Text('Pendientes: ${_formatQuantity(row.unidadesPendientes)}'),
              if (operacion != null) ...[
                const SizedBox(height: 8),
                ListaEstadoChip.operacion(operacion),
              ],
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
            const Expanded(child: Text('No se pudo actualizar. Se conserva la última copia disponible.')),
            if (onRetry != null) Button(onPressed: onRetry, child: const Text('Reintentar')),
          ],
        ),
      ),
    );
  }
}

String _formatQuantity(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

String _formatDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
