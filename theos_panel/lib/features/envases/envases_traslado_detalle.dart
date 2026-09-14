import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../ui/components/orbi_components.dart';
import '../../ui/fluent/orbi_page.dart';
import 'envases_uuid.dart';

/// Detalle de un traslado "por recibir" (ENV-03 pestaña Tránsitos, detalle):
/// origen, destino, fecha de salida y lo pendiente, con las dos acciones que
/// caben aquí — registrar la recepción y, sólo con permiso de gerencia, dar
/// por perdido lo que sigue en tránsito.
///
/// Nunca escribe directo a Odoo: las dos acciones pasan por
/// [EnvasesOperations], igual que el formulario de recepción.
class EnvasesTrasladoDetalle extends StatefulWidget {
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
  State<EnvasesTrasladoDetalle> createState() => _EnvasesTrasladoDetalleState();
}

class _EnvasesTrasladoDetalleState extends State<EnvasesTrasladoDetalle> {
  StreamSubscription<List<EnvasesOperacionLocal>>? _subscription;
  EnvasesOperacionLocal? _operacion;
  bool _perdiendo = false;
  String? _error;

  @override
  void initState() {
    super.initState();
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
    return OrbiPage(
      title: row.name,
      subtitle: row.sentido,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
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
                  OrbiStatusChip(label: _estadoLabel(_operacion!), icon: FluentIcons.sync_status_solid),
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
      ),
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

String _estadoLabel(EnvasesOperacionLocal operacion) => switch (operacion.estado) {
  EnvasesOperacionEstado.pendienteDeEnviar => 'Pendiente de enviar',
  EnvasesOperacionEstado.enviada => 'Enviada',
  EnvasesOperacionEstado.rechazada => operacion.mensajeOdoo ?? 'Rechazada por Odoo',
  EnvasesOperacionEstado.revisarAMano => 'Revisar a mano',
};

String _formatQuantity(double value) =>
    value == value.roundToDouble() ? value.toInt().toString() : value.toString();

String _formatDate(DateTime? value) {
  if (value == null) return '—';
  final local = value.toLocal();
  String two(int number) => number.toString().padLeft(2, '0');
  return '${two(local.day)}/${two(local.month)}/${local.year} ${two(local.hour)}:${two(local.minute)}';
}
