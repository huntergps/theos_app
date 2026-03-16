/// SupervisorDashboard — Vista de metricas del dia para supervisores
///
/// Solo visible para usuarios con permisos de coleccion o ventas manager.
/// Lee exclusivamente de Drift local (offline-first), sin llamadas a Odoo.
library;

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show SessionState;

import '../../../core/theme/spacing.dart';
import '../../../features/sync/providers/sync_provider.dart';
import '../providers/dashboard_providers.dart';
import '../../../shared/utils/formatting_utils.dart';

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

        // --- Sesion de caja + Ultimo sync ---
        if (isCompact)
          Column(
            children: [
              _SessionCard(spacing: spacing),
              SizedBox(height: spacing.sm),
              _LastSyncCard(spacing: spacing),
            ],
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: _SessionCard(spacing: spacing)),
                SizedBox(width: spacing.sm),
                Expanded(child: _LastSyncCard(spacing: spacing)),
              ],
            ),
          ),

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
// TARJETA: Sesion de caja activa
// ============================================================================

class _SessionCard extends ConsumerWidget {
  final ThemedSpacing spacing;
  const _SessionCard({required this.spacing});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final summary = ref.watch(activeSessionSummaryProvider);

    return Card(
      padding: const EdgeInsets.all(16),
      child: Builder(builder: (_) {
          if (!summary.hasActiveSession) {
            return _SessionEmptyState(theme: theme);
          }

          final stateColor = _sessionStateColor(summary.sessionState);
          final stateLabel = _sessionStateLabel(summary.sessionState);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Icon(FluentIcons.money, size: 18, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Text(
                    'Sesion de caja',
                    style: theme.typography.bodyStrong,
                  ),
                  const Spacer(),
                  // Chip de estado
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: stateColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: stateColor.withValues(alpha: 0.5),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      stateLabel,
                      style: TextStyle(
                        fontSize: 11,
                        color: stateColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              if (summary.configName != null)
                Row(
                  children: [
                    Icon(
                      FluentIcons.settings,
                      size: 13,
                      color: theme.inactiveColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        summary.configName!,
                        style: theme.typography.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              if (summary.userName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      FluentIcons.contact,
                      size: 13,
                      color: theme.inactiveColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        summary.userName!,
                        style: theme.typography.caption?.copyWith(
                          color: theme.inactiveColor,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          );
        }),
    );
  }

  Color _sessionStateColor(SessionState? state) {
    switch (state) {
      case SessionState.opened:
        return Colors.green;
      case SessionState.openingControl:
        return Colors.orange;
      case SessionState.closingControl:
        return Colors.orange;
      case SessionState.closed:
      case null:
        return Colors.grey;
    }
  }

  String _sessionStateLabel(SessionState? state) {
    switch (state) {
      case SessionState.opened:
        return 'Abierta';
      case SessionState.openingControl:
        return 'Apertura';
      case SessionState.closingControl:
        return 'Cierre';
      case SessionState.closed:
        return 'Cerrada';
      case null:
        return 'Desconocido';
    }
  }
}

class _SessionEmptyState extends StatelessWidget {
  final FluentThemeData theme;
  const _SessionEmptyState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          FluentIcons.money,
          size: 18,
          color: theme.inactiveColor,
        ),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Sesion de caja',
              style: theme.typography.bodyStrong,
            ),
            Text(
              'Sin sesion activa',
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ),
      ],
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


