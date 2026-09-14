import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:odoo_widgets/odoo_widgets.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/fluent/orbi_page.dart';

/// Envases pendientes de recibir (BODEGA-ENVASES «En tránsito», ENV-03
/// pestaña Tránsitos): lo que ya salió de una sede y todavía no confirma
/// llegada la sede destino.
///
/// Sólo lectura y sólo estado local — la pantalla nunca decide qué llegó,
/// eso lo hace el formulario de recepción a través de `EnvasesOperations`
/// (`onOpenDetail` navega al detalle, que a su vez ofrece recibir/perder).
///
/// Por debajo del corte ancho (el mismo 840 de `OrbiListing`) las filas se
/// agrupan por sentido (origen → destino) en tarjetas — `OrbiListing` no
/// agrupa, así que esta pantalla arma su propia lista angosta en vez de
/// reusar su modo tarjeta automático.
class EnvasesPorRecibirScreen extends StatefulWidget {
  const EnvasesPorRecibirScreen({
    super.key,
    required this.snapshots,
    required this.operaciones,
    required this.onOpenDetail,
    this.onRefresh,
    this.isConnected,
  });

  final Stream<EnvasesPorRecibirSnapshot?> snapshots;
  final Stream<List<EnvasesOperacionLocal>> operaciones;
  final ValueChanged<EnvasesPorRecibirRow> onOpenDetail;
  final VoidCallback? onRefresh;
  final bool? isConnected;

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
          padding: const EdgeInsets.only(bottom: 12),
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
                    return narrow ? _groupedCards(context, rows) : _table(context, rows);
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

  Widget _table(BuildContext context, List<EnvasesPorRecibirRow> rows) {
    final theme = FluentTheme.of(context);
    return Card(
      backgroundColor: theme.scaffoldBackgroundColor,
      borderColor: theme.resources.surfaceStrokeColorDefault,
      borderRadius: BorderRadius.circular(12),
      padding: const EdgeInsets.all(8),
      child: OrbiListing<EnvasesPorRecibirRow>(
        rows: rows,
        storageKey: 'envases-por-recibir',
        onRowTap: widget.onOpenDetail,
        emptyMessage: 'No hay envases por recibir que coincidan con el filtro.',
        columns: [
          OrbiColumn(key: 'name', label: 'Documento', value: (row) => row.name, alwaysVisible: true),
          OrbiColumn(key: 'sentido', label: 'Origen → Destino', value: (row) => row.sentido),
          OrbiColumn(
            key: 'fecha',
            label: 'Fecha de salida',
            value: (row) => _formatDate(row.fechaSalida),
          ),
          OrbiColumn(
            key: 'pendientes',
            label: 'Unidades pendientes',
            numeric: true,
            value: (row) => _formatQuantity(row.unidadesPendientes),
          ),
          OrbiColumn(key: 'estado', label: 'Estado local', value: (row) => _estadoLabel(_operacionDe(row.id))),
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
                OrbiStatusChip(label: _estadoLabel(operacion), icon: FluentIcons.sync_status_solid),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

String _estadoLabel(EnvasesOperacionLocal? operacion) {
  if (operacion == null) return '';
  return switch (operacion.estado) {
    EnvasesOperacionEstado.pendienteDeEnviar => 'Pendiente de enviar',
    EnvasesOperacionEstado.enviada => 'Enviada',
    EnvasesOperacionEstado.rechazada => operacion.mensajeOdoo ?? 'Rechazada por Odoo',
    EnvasesOperacionEstado.revisarAMano => 'Revisar a mano',
  };
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
