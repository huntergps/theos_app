/// SupervisorDashboard — Vista de metricas del dia para supervisores
///
/// Solo visible para usuarios con permisos de coleccion o ventas manager.
/// Lee exclusivamente de Drift local (offline-first), sin llamadas a Odoo.
library;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show CollectionSession, SessionState, SessionStateExtension;

import '../../../core/database/providers.dart' show activeSessionsProvider;
import '../../../core/navigation/app_router.dart';
import '../../../core/theme/spacing.dart';
import '../../../features/sync/providers/sync_provider.dart';
import '../providers/dashboard_providers.dart';
import '../../../shared/utils/formatting_utils.dart';

// ============================================================================
// CONSTANTES DE COLOR — estado de sesion de caja
// ============================================================================

/// Colores para cada estado de sesion. Definidos aqui para evitar
/// duplicacion entre _stateColor() y _StateDot.
const _colorSessionOpened = Color(0xFF107C10); // verde — abierta
const _colorSessionOpening = Color(0xFFCA5010); // naranja — apertura/cierre
const _colorSessionClosing = Color(0xFF0078D4); // azul — cierre en proceso
const _colorSessionClosed = Color(0xFF767676); // gris — cerrada

class SupervisorDashboard extends ConsumerWidget {
  const SupervisorDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final spacing = ref.watch(themedSpacingProvider);
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompact = screenWidth < 700;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Resumen del dia',
          style: theme.typography.subtitle,
        ),
        SizedBox(height: spacing.md),

        // --- Metricas de ventas ---
        _SalesMetricsSection(isCompact: isCompact, spacing: spacing),
        SizedBox(height: spacing.md),

        // --- Sesiones activas + Ultimo sync ---
        _LastSyncCard(spacing: spacing),
        SizedBox(height: spacing.md),

        // --- Lista de todas las sesiones activas ---
        _AllSessionsSection(spacing: spacing),

        SizedBox(height: spacing.lg),

        // --- Accesos rapidos ---
        Text(
          'Accesos rapidos',
          style: theme.typography.bodyStrong,
        ),
        SizedBox(height: spacing.sm),
        _QuickActionsRow(spacing: spacing),
      ],
    );
  }
}

// ============================================================================
// SECCION: Metricas de ventas del dia
// ============================================================================

class _SalesMetricsSection extends ConsumerWidget {
  final bool isCompact;
  final ThemedSpacing spacing;

  const _SalesMetricsSection({
    required this.isCompact,
    required this.spacing,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metrics = ref.watch(dailySaleMetricsProvider);

        if (isCompact) {
          return Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Total ventas',
                      value: metrics.totalAmount.toCurrency(),
                      subtitle: '${metrics.totalOrders} ordenes',
                      icon: FluentIcons.money,
                      accentColor: Colors.green,
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: _MetricCard(
                      label: 'Confirmadas',
                      value: '${metrics.confirmedCount}',
                      subtitle: 'ordenes sale',
                      icon: FluentIcons.check_mark,
                      accentColor: Colors.blue,
                    ),
                  ),
                ],
              ),
              SizedBox(height: spacing.sm),
              Row(
                children: [
                  Expanded(
                    child: _MetricCard(
                      label: 'Borradores',
                      value: '${metrics.draftCount}',
                      subtitle: 'pendientes',
                      icon: FluentIcons.edit,
                      accentColor: Colors.orange,
                    ),
                  ),
                  SizedBox(width: spacing.sm),
                  Expanded(
                    child: _MetricCard(
                      label: 'Completadas',
                      value: '${metrics.doneCount}',
                      subtitle: 'facturadas',
                      icon: FluentIcons.receipt_processing,
                      accentColor: Colors.teal,
                    ),
                  ),
                ],
              ),
            ],
          );
        }

        return Row(
          children: [
            Expanded(
              flex: 2,
              child: _MetricCard(
                label: 'Total ventas del dia',
                value: metrics.totalAmount.toCurrency(),
                subtitle: '${metrics.totalOrders} ordenes en total',
                icon: FluentIcons.money,
                accentColor: Colors.green,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: _MetricCard(
                label: 'Borradores',
                value: '${metrics.draftCount}',
                subtitle: 'pendientes',
                icon: FluentIcons.edit,
                accentColor: Colors.orange,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: _MetricCard(
                label: 'Confirmadas',
                value: '${metrics.confirmedCount}',
                subtitle: 'ordenes sale',
                icon: FluentIcons.check_mark,
                accentColor: Colors.blue,
              ),
            ),
            SizedBox(width: spacing.sm),
            Expanded(
              child: _MetricCard(
                label: 'Completadas',
                value: '${metrics.doneCount}',
                subtitle: 'facturadas',
                icon: FluentIcons.receipt_processing,
                accentColor: Colors.teal,
              ),
            ),
          ],
        );
  }
}

// ============================================================================
// TARJETA METRICA INDIVIDUAL
// ============================================================================

class _MetricCard extends StatelessWidget {
  final String label;
  final String value;
  final String subtitle;
  final IconData icon;
  final Color accentColor;

  const _MetricCard({
    required this.label,
    required this.value,
    required this.subtitle,
    required this.icon,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 20, color: accentColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: theme.typography.bodyStrong?.copyWith(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SECCION: Todas las sesiones de caja activas
// ============================================================================

/// Muestra TODAS las sesiones de caja activas (no cerradas) del dia.
///
/// Disenada para el dashboard del supervisor. Cada sesion se muestra como
/// una fila compacta con: punto de estado, nombre de sesion, config/sucursal,
/// cajero, hora de apertura, total cobrado, chip de estado y flecha.
/// Al hacer clic navega a [AppRouter.collectionSessionPath].
class _AllSessionsSection extends ConsumerWidget {
  final ThemedSpacing spacing;
  const _AllSessionsSection({required this.spacing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final sessionsAsync = ref.watch(activeSessionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(FluentIcons.people, size: 16, color: theme.accentColor),
            const SizedBox(width: 8),
            Text('Sesiones de caja activas', style: theme.typography.bodyStrong),
            const Spacer(),
            sessionsAsync.maybeWhen(
              data: (s) => Text(
                '${s.length} ${s.length == 1 ? "sesion" : "sesiones"}',
                style: theme.typography.caption?.copyWith(
                  color: theme.inactiveColor,
                ),
              ),
              orElse: () => const SizedBox.shrink(),
            ),
          ],
        ),
        SizedBox(height: spacing.sm),
        sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return const InfoBar(
                title: Text('Sin sesiones activas'),
                content: Text(
                  'No hay cajeros con sesiones abiertas en este momento.',
                ),
                severity: InfoBarSeverity.info,
              );
            }
            return Column(
              children: sessions
                  .map((s) => _SessionRowCard(session: s, spacing: spacing))
                  .toList(),
            );
          },
          loading: () => const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: ProgressRing(),
            ),
          ),
          error: (err, _) => InfoBar(
            title: const Text('Error al cargar sesiones'),
            content: Text(err.toString()),
            severity: InfoBarSeverity.error,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// FILA: Una sesion individual en el dashboard
// ============================================================================

class _SessionRowCard extends StatelessWidget {
  final CollectionSession session;
  final ThemedSpacing spacing;

  const _SessionRowCard({required this.session, required this.spacing});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final startTime = session.startAt;
    final timeLabel = startTime != null
        ? DateFormat('dd/MM HH:mm', 'es_ES').format(startTime.toLocal())
        : '--:--';

    final totalLabel = session.totalGeneral > 0
        ? '\$${session.totalGeneral.toStringAsFixed(2)}'
        : session.totalPaymentsAmount > 0
            ? '\$${session.totalPaymentsAmount.toStringAsFixed(2)}'
            : null;

    final stateColor = _stateColor(session.state);
    final stateLabel = session.state.label;

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: HoverButton(
        onPressed: () =>
            context.go(AppRouter.collectionSessionPath(session.id)),
        builder: (ctx, states) {
          final hovered = states.isHovered;
          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: hovered
                  ? theme.resources.subtleFillColorSecondary
                  : theme.resources.cardBackgroundFillColorDefault,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hovered
                    ? theme.accentColor.defaultBrushFor(theme.brightness)
                    : theme.resources.cardStrokeColorDefault,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  // Indicador de estado (punto de color)
                  _StateDot(state: session.state),
                  const SizedBox(width: 10),

                  // Nombre de sesion + config/sucursal
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          session.name,
                          style: theme.typography.bodyStrong,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                        if (session.configName != null)
                          Text(
                            session.configName!,
                            style: theme.typography.caption?.copyWith(
                              color: theme.resources.textFillColorSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                      ],
                    ),
                  ),

                  // Cajero
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Icon(
                          FluentIcons.contact,
                          size: 13,
                          color: theme.resources.textFillColorSecondary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            session.userName ?? 'Sin asignar',
                            style: theme.typography.body,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Hora de apertura
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Icon(
                          FluentIcons.clock,
                          size: 13,
                          color: theme.resources.textFillColorSecondary,
                        ),
                        const SizedBox(width: 5),
                        Expanded(
                          child: Text(
                            timeLabel,
                            style: theme.typography.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Total acumulado (si disponible)
                  if (totalLabel != null) ...[
                    Expanded(
                      flex: 2,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Icon(
                            FluentIcons.money,
                            size: 13,
                            color: theme.resources.textFillColorSecondary,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            totalLabel,
                            style: theme.typography.bodyStrong?.copyWith(
                              fontSize: 13,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ] else
                    const Expanded(flex: 2, child: SizedBox.shrink()),

                  const SizedBox(width: 10),

                  // Chip de estado
                  _StateChip(state: session.state, color: stateColor, label: stateLabel),

                  const SizedBox(width: 8),

                  // Flecha de navegacion
                  Icon(
                    FluentIcons.chevron_right,
                    size: 13,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Color _stateColor(SessionState state) => switch (state) {
        SessionState.opened => _colorSessionOpened,
        SessionState.openingControl => _colorSessionOpening,
        SessionState.closingControl => _colorSessionClosing,
        SessionState.closed => _colorSessionClosed,
      };
}

// ============================================================================
// COMPONENTES AUXILIARES LOCALES
// ============================================================================

/// Punto de color que indica el estado de la sesion.
class _StateDot extends StatelessWidget {
  final SessionState state;
  const _StateDot({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      SessionState.opened => _colorSessionOpened,
      SessionState.openingControl => _colorSessionOpening,
      SessionState.closingControl => _colorSessionClosing,
      SessionState.closed => _colorSessionClosed,
    };
    return Container(
      width: 9,
      height: 9,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}

/// Chip compacto de estado (no usa StateChip de collection para evitar
/// dependencia cruzada de features).
class _StateChip extends StatelessWidget {
  final SessionState state;
  final Color color;
  final String label;

  const _StateChip({
    required this.state,
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================================
// TARJETA: Ultimo sync exitoso
// ============================================================================

class _LastSyncCard extends ConsumerWidget {
  final ThemedSpacing spacing;
  const _LastSyncCard({required this.spacing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final lastSync = ref.watch(lastSuccessfulSyncProvider);
    final syncState = ref.watch(syncProvider);
    final isSyncing = syncState.isAnySyncing;

    return Card(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Icon(
            isSyncing ? FluentIcons.sync : FluentIcons.cloud_download,
            size: 18,
            color: isSyncing ? Colors.orange : theme.accentColor,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Ultimo sync',
                  style: theme.typography.bodyStrong,
                ),
                const SizedBox(height: 2),
                if (isSyncing)
                  Text(
                    'Sincronizando...',
                    style: theme.typography.caption?.copyWith(
                      color: Colors.orange,
                    ),
                  )
                else if (lastSync != null)
                  Text(
                    _formatSyncDate(lastSync),
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  )
                else
                  Text(
                    'Sin sincronizaciones',
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSyncDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'Hace un momento';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) {
      return 'Hoy ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
    }
    return 'Ayer ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  }
}

// ============================================================================
// ACCESOS RAPIDOS
// ============================================================================

class _QuickActionsRow extends ConsumerWidget {
  final ThemedSpacing spacing;
  const _QuickActionsRow({required this.spacing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      children: [
        _QuickActionButton(
          icon: FluentIcons.shopping_cart,
          label: 'Nueva Venta',
          onPressed: () => context.go('/fast-sale'),
        ),
        _QuickActionButton(
          icon: FluentIcons.bill,
          label: 'Ver Ordenes',
          onPressed: () => context.go('/sales'),
        ),
        _QuickActionButton(
          icon: FluentIcons.money,
          label: 'Punto de Cobro',
          onPressed: () => context.go('/collection'),
        ),
        _QuickActionButton(
          icon: FluentIcons.sync,
          label: 'Sincronizar',
          onPressed: () => context.go('/sync'),
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Button(
      onPressed: onPressed,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

// ============================================================================
// PLACEHOLDER DE CARGA
// ============================================================================


