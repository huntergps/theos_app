import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/fluent/orbi_page.dart';
import 'envases_uuid.dart';
import 'widgets/lista_estado_chip.dart';

/// Detalle de un traslado "por recibir" (ENV-03 pestaña Tránsitos, detalle):
/// origen, destino, fecha de salida y lo pendiente, con las dos acciones que
/// caben aquí — registrar la recepción y, sólo con permiso de gerencia, dar
/// por perdido lo que sigue en tránsito.
///
/// Nunca escribe directo a Odoo: las dos acciones pasan por
/// [EnvasesOperations], igual que el formulario de recepción.
///
/// Página completa (con `OrbiPage`), para la navegación en pantalla angosta.
/// En escritorio, el mismo contenido se embebe sin la cabecera de página a
/// través de [EnvasesTrasladoDetalleBody] — el panel «al lado» de ENV-03 y de
/// «Detalle de traslado» en BODEGA-ENVASES.
class EnvasesTrasladoDetalle extends StatelessWidget {
  const EnvasesTrasladoDetalle({
    super.key,
    required this.row,
    required this.operaciones,
    required this.operations,
    required this.canManage,
    required this.onRegistrarRecepcion,
    this.onDarPorPerdido,
  });

  final EnvasesPorRecibirRow row;
  final Stream<List<EnvasesOperacionLocal>> operaciones;
  final EnvasesOperations operations;

  /// Decidido por quien compone la pantalla, nunca aquí: viene ya resuelto
  /// contra `envases_manage`.
  final bool canManage;

  final VoidCallback onRegistrarRecepcion;

  /// Se llama después de que Odoo confirma (o encola) el "dar por perdido".
  /// Nulo cuando el detalle no necesita reaccionar (por ejemplo, ya se
  /// muestra a sí mismo mientras la lista de por-recibir refleja el cambio).
  final VoidCallback? onDarPorPerdido;

  @override
  Widget build(BuildContext context) => OrbiPage(
    title: row.name,
    subtitle: row.sentido,
    // `OrbiPage` ya pinta el documento como título de la página — el cuerpo
    // no repite un segundo encabezado aquí. El panel «al lado» de escritorio
    // (`EnvasesPorRecibirScreen._tableWithDetail`) no tiene ese título de
    // página, así que ahí sí lo pide (`showHeader` por omisión).
    child: EnvasesTrasladoDetalleBody(
      row: row,
      operaciones: operaciones,
      operations: operations,
      canManage: canManage,
      onRegistrarRecepcion: onRegistrarRecepcion,
      onDarPorPerdido: onDarPorPerdido,
      showHeader: false,
    ),
  );
}

/// El contenido del detalle, sin la cabecera de página — lo reutiliza el
/// panel lateral de escritorio de `EnvasesPorRecibirScreen` (ENV-03: «detalle
/// al lado»), que no puede anidar un segundo `OrbiPage` dentro de la lista.
class EnvasesTrasladoDetalleBody extends StatefulWidget {
  const EnvasesTrasladoDetalleBody({
    super.key,
    required this.row,
    required this.operaciones,
    required this.operations,
    required this.canManage,
    required this.onRegistrarRecepcion,
    this.onDarPorPerdido,
    this.showHeader = true,
  });

  final EnvasesPorRecibirRow row;
  final Stream<List<EnvasesOperacionLocal>> operaciones;
  final EnvasesOperations operations;
  final bool canManage;
  final VoidCallback onRegistrarRecepcion;
  final VoidCallback? onDarPorPerdido;

  /// El documento en negrita y la etiqueta de estado arriba del panel, como
  /// en ENV-03 y en «Detalle de traslado» de BODEGA-ENVASES — 🔴 el panel
  /// «al lado» de escritorio (`EnvasesPorRecibirScreen._tableWithDetail`) no
  /// tenía ningún encabezado (queja del dueño, 14-sep-2026): sin `OrbiPage`
  /// alrededor, no había ni un solo lugar que dijera de qué traslado se
  /// trata. Falso sólo cuando quien nos usa YA puso ese título encima
  /// (`EnvasesTrasladoDetalle`, que lo hace vía `OrbiPage`).
  final bool showHeader;

  @override
  State<EnvasesTrasladoDetalleBody> createState() => _EnvasesTrasladoDetalleBodyState();
}

class _EnvasesTrasladoDetalleBodyState extends State<EnvasesTrasladoDetalleBody> {
  StreamSubscription<List<EnvasesOperacionLocal>>? _subscription;
  EnvasesOperacionLocal? _operacion;
  bool _perdiendo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _listen();
  }

  @override
  void didUpdateWidget(covariant EnvasesTrasladoDetalleBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    // El panel lateral reutiliza este mismo `State` al cambiar de fila
    // seleccionada (misma posición en el árbol) — sin esto seguiría
    // mostrando la operación del traslado anterior.
    if (oldWidget.row.id != widget.row.id || oldWidget.operaciones != widget.operaciones) {
      _subscription?.cancel();
      _operacion = null;
      _error = null;
      _perdiendo = false;
      _listen();
    }
  }

  void _listen() {
    _subscription = widget.operaciones.listen((operaciones) {
      if (!mounted) return;
      setState(() {
        _operacion = operaciones.where((o) => o.pickingId == widget.row.id).firstOrNull;
      });
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _confirmarDarPorPerdido() async {
    final confirmado = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('¿Dar por perdido?'),
        content: Text(
          'Se dará de baja lo que sigue en tránsito de "${widget.row.name}". Esta acción no se deshace.',
        ),
        actions: [
          Button(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
          FilledButton(
            key: const Key('envases-detalle-confirmar-perdido'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Dar por perdido'),
          ),
        ],
      ),
    );
    if (confirmado != true || !mounted) return;
    setState(() {
      _perdiendo = true;
      _error = null;
    });
    try {
      await widget.operations.darPorPerdido(
        operacionUuid: generateEnvasesOperacionUuid(),
        pickingId: widget.row.id,
      );
      widget.onDarPorPerdido?.call();
    } catch (error) {
      if (mounted) setState(() => _error = 'No se pudo registrar la baja: $error');
    } finally {
      if (mounted) setState(() => _perdiendo = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final row = widget.row;
    final theme = FluentTheme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.showHeader)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    row.name,
                    key: const Key('envases-detalle-titulo'),
                    style: theme.typography.subtitle,
                  ),
                ),
                const SizedBox(width: 12),
                const OrbiStatusChip(label: 'En tránsito', icon: FluentIcons.sync_status_solid),
              ],
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InfoBar(title: const Text('No se pudo completar'), content: Text(_error!), severity: InfoBarSeverity.error),
          ),
        Card(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _line(theme, 'Origen', row.origenName ?? 'Origen desconocido'),
              _line(theme, 'Destino', row.destinoName ?? 'Destino desconocido'),
              _line(theme, 'Fecha de salida', _formatDate(row.fechaSalida)),
              _line(theme, 'Unidades pendientes', _formatQuantity(row.unidadesPendientes)),
              if (_operacion != null) ...[
                const SizedBox(height: 8),
                ListaEstadoChip.operacion(_operacion!),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            FilledButton(
              key: const Key('envases-detalle-recibir'),
              onPressed: widget.onRegistrarRecepcion,
              child: const Text('Registrar recepción'),
            ),
            if (widget.canManage)
              Button(
                key: const Key('envases-detalle-dar-por-perdido'),
                onPressed: _perdiendo ? null : _confirmarDarPorPerdido,
                child: _perdiendo
                    ? const SizedBox(width: 16, height: 16, child: ProgressRing(strokeWidth: 2))
                    : const Text('Dar por perdido'),
              ),
          ],
        ),
      ],
    );
  }

  Widget _line(FluentThemeData theme, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Row(
      children: [
        SizedBox(width: 160, child: Text(label, style: theme.typography.caption)),
        Expanded(child: Text(value, style: theme.typography.body)),
      ],
    ),
  );
}

extension<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

String _formatQuantity(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

String _formatDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
