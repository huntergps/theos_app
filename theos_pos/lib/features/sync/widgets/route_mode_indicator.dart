/// Widget indicador de Modo Ruta
///
/// Muestra un badge azul en la barra superior cuando el modo ruta esta activo.
/// Permite activar/desactivar con un toggle.
library;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/websocket/odoo_websocket_service.dart';
import '../providers/route_mode_provider.dart';
import '../providers/sync_provider.dart';

// ============================================================================
// BADGE COMPACTO — para la barra superior
// ============================================================================

/// Badge compacto que aparece en la barra de titulos cuando Modo Ruta esta activo.
///
/// Muestra el icono de ruta + texto "Modo Ruta".
/// Al presionar abre el dialogo de confirmacion para desactivar.
class RouteModeIndicatorBadge extends ConsumerWidget {
  const RouteModeIndicatorBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(isRouteModeActiveProvider);

    if (!isActive) return const SizedBox.shrink();

    final routeState = ref.watch(routeModeStateProvider);
    final durationText = routeState.activeDurationText;
    // Usar accentColor del tema en lugar de color hardcodeado
    final accentColor = FluentTheme.of(context).accentColor;

    return Tooltip(
      message: 'Modo Ruta activo${durationText != null ? " ($durationText)" : ""}.\n'
          'El WebSocket y la cola offline estan suspendidos.\n'
          'Pulsa para desactivar y sincronizar.',
      child: GestureDetector(
        onTap: () => _showDeactivateDialog(context, ref),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: accentColor,
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  FluentIcons.car,
                  size: 14,
                  color: accentColor,
                ),
                const SizedBox(width: 4),
                Text(
                  durationText != null
                      ? 'Modo Ruta ($durationText)'
                      : 'Modo Ruta',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: accentColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showDeactivateDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => const _RouteModeDeactivateDialog(),
    );
  }
}

// ============================================================================
// TOGGLE BUTTON — para Settings y otros paneles
// ============================================================================

/// Toggle que activa/desactiva el Modo Ruta.
///
/// Al activar: muestra confirmacion y explica las consecuencias.
/// Al desactivar: reconecta WebSocket y dispara sync incremental.
class RouteModeToggle extends ConsumerWidget {
  /// Si true, muestra texto descriptivo ademas del toggle
  final bool showDescription;

  const RouteModeToggle({
    super.key,
    this.showDescription = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isActive = ref.watch(isRouteModeActiveProvider);
    final routeState = ref.watch(routeModeStateProvider);
    final durationText = routeState.activeDurationText;
    // Usar accentColor del tema en lugar de color hardcodeado
    final accentColor = FluentTheme.of(context).accentColor;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            // Icono de estado
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: isActive
                    ? accentColor.withValues(alpha: 0.15)
                    : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                FluentIcons.car,
                size: 20,
                color: isActive ? accentColor : Colors.grey,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Modo Ruta',
                    style: FluentTheme.of(context).typography.body?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (isActive && durationText != null)
                    Text(
                      'Activo hace $durationText',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                            color: accentColor,
                          ),
                    )
                  else if (!isActive)
                    Text(
                      'Inactivo',
                      style: FluentTheme.of(context).typography.caption?.copyWith(
                            color: FluentTheme.of(context).inactiveColor,
                          ),
                    ),
                ],
              ),
            ),
            ToggleSwitch(
              checked: isActive,
              onChanged: (value) {
                if (value) {
                  _showActivateDialog(context, ref);
                } else {
                  _showDeactivateDialog(context, ref);
                }
              },
            ),
          ],
        ),
        if (showDescription) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(left: 48),
            child: Text(
              isActive
                  ? 'WebSocket y cola offline suspendidos. '
                    'Al desactivar se sincronizara automaticamente.'
                  : 'Activa para trabajar sin internet. '
                    'Suspende reconexion WiFi y ahorra bateria.',
              style: FluentTheme.of(context).typography.caption?.copyWith(
                    color: FluentTheme.of(context).inactiveColor,
                  ),
            ),
          ),
        ],
      ],
    );
  }

  void _showActivateDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => const _RouteModeActivateDialog(),
    );
  }

  void _showDeactivateDialog(BuildContext context, WidgetRef ref) {
    showDialog<void>(
      context: context,
      builder: (_) => const _RouteModeDeactivateDialog(),
    );
  }
}

// ============================================================================
// DIALOGO — Activar
// ============================================================================

/// Dialogo de confirmacion para activar el Modo Ruta.
///
/// No recibe WidgetRef por constructor: es ConsumerWidget y usa su propio ref.
class _RouteModeActivateDialog extends ConsumerWidget {
  const _RouteModeActivateDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usar accentColor del tema en lugar de color hardcodeado
    final accentColor = FluentTheme.of(context).accentColor;

    return ContentDialog(
      title: Row(
        children: [
          Icon(FluentIcons.car, size: 20, color: accentColor),
          const SizedBox(width: 8),
          const Text('Activar Modo Ruta'),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'El Modo Ruta esta disenado para trabajar horas sin internet.',
          ),
          const SizedBox(height: 12),
          _BulletItem(
            icon: FluentIcons.plug_disconnected,
            text: 'Suspende los intentos de reconexion al WebSocket',
            accentColor: accentColor,
          ),
          const SizedBox(height: 6),
          _BulletItem(
            icon: FluentIcons.pause,
            text: 'Pausa el envio de operaciones en cola offline',
            accentColor: accentColor,
          ),
          const SizedBox(height: 6),
          _BulletItem(
            icon: FluentIcons.lightning_bolt,
            text: 'Ahorra bateria al eliminar reconexiones repetidas',
            accentColor: accentColor,
          ),
          const SizedBox(height: 12),
          const Text(
            'Tus ventas se guardaran localmente y se enviaran automaticamente cuando desactives el modo ruta.',
            style: TextStyle(fontStyle: FontStyle.italic),
          ),
        ],
      ),
      actions: [
        Button(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
        FilledButton(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.car, size: 16),
              SizedBox(width: 6),
              Text('Activar Modo Ruta'),
            ],
          ),
          onPressed: () async {
            Navigator.pop(context);
            await ref.read(routeModeProvider.notifier).activate();
            // Suspender WebSocket auto-reconnect
            final wsService = ref.read(odooWebSocketServiceProvider);
            wsService.autoReconnectEnabled = false;
          },
        ),
      ],
    );
  }
}

// ============================================================================
// DIALOGO — Desactivar
// ============================================================================

/// Dialogo de confirmacion para desactivar el Modo Ruta.
///
/// Al confirmar: desactiva modo ruta, rehabilita WebSocket y dispara sync.
/// No recibe WidgetRef por constructor: es ConsumerWidget y usa su propio ref.
class _RouteModeDeactivateDialog extends ConsumerWidget {
  const _RouteModeDeactivateDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Usar accentColor del tema en lugar de color hardcodeado
    final accentColor = FluentTheme.of(context).accentColor;

    return ContentDialog(
      title: Row(
        children: [
          Icon(FluentIcons.sync, size: 20, color: accentColor),
          const SizedBox(width: 8),
          const Text('Desactivar Modo Ruta'),
        ],
      ),
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Al desactivar el Modo Ruta, la aplicacion:'),
          const SizedBox(height: 12),
          _BulletItem(
            icon: FluentIcons.plug_connected,
            text: 'Reconectara al WebSocket de Odoo',
            accentColor: accentColor,
          ),
          const SizedBox(height: 6),
          _BulletItem(
            icon: FluentIcons.cloud_upload,
            text: 'Enviara todas las ventas guardadas en cola',
            accentColor: accentColor,
          ),
          const SizedBox(height: 6),
          _BulletItem(
            icon: FluentIcons.refresh,
            text: 'Sincronizara catalogos (productos, precios, clientes)',
            accentColor: accentColor,
          ),
        ],
      ),
      actions: [
        Button(
          child: const Text('Cancelar'),
          onPressed: () => Navigator.pop(context),
        ),
        FilledButton(
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.cloud_download, size: 16),
              SizedBox(width: 6),
              Text('Desactivar y Sincronizar'),
            ],
          ),
          onPressed: () async {
            Navigator.pop(context);
            await _deactivateAndSync(ref);
          },
        ),
      ],
    );
  }

  Future<void> _deactivateAndSync(WidgetRef ref) async {
    // 1. Desactivar modo ruta
    await ref.read(routeModeProvider.notifier).deactivate();

    // 2. Rehabilitar WebSocket auto-reconnect y reconectar
    final wsService = ref.read(odooWebSocketServiceProvider);
    wsService.autoReconnectEnabled = true;
    await wsService.manualReconnect();

    // 3. Disparar sync incremental de catalogos criticos
    try {
      await ref.read(syncProvider.notifier).syncCriticalData();
    } catch (e) {
      // Non-fatal — la cola offline sera procesada cuando llegue conexion
    }
  }
}

// ============================================================================
// HELPER WIDGET
// ============================================================================

class _BulletItem extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color accentColor;

  const _BulletItem({
    required this.icon,
    required this.text,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: accentColor),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text),
        ),
      ],
    );
  }
}
