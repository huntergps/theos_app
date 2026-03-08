import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

import '../repositories/sync_models.dart' show SyncProgress;
import '../providers/sync_provider.dart';

/// Tarjeta para mostrar el estado de sincronización de un item individual
class SyncItemCard extends StatelessWidget {
  final String name;
  final String description;
  final IconData icon;
  final SyncItemState state;
  final bool isOnline;
  final bool isSyncingAll;
  final VoidCallback onSync;
  final VoidCallback onForceSync;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  const SyncItemCard({
    super.key,
    required this.name,
    required this.description,
    required this.icon,
    required this.state,
    required this.isOnline,
    required this.isSyncingAll,
    required this.onSync,
    required this.onForceSync,
    required this.onClear,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isSyncing = state.status == SyncStatus.syncing;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header con icono, título y estado
            _SyncItemHeader(
              icon: icon,
              description: description,
              state: state,
            ),
            const SizedBox(height: 12),

            // Info de conteo local y última sincronización
            _SyncInfoPanel(state: state),
            const SizedBox(height: 8),

            // Estado actual (éxito, error, sincronizando, idle)
            _SyncStatusDisplay(state: state),
            const SizedBox(height: 12),

            // Botones de acción
            _SyncActionButtons(
              isSyncing: isSyncing,
              isOnline: isOnline,
              isSyncingAll: isSyncingAll,
              onSync: onSync,
              onForceSync: onForceSync,
              onClear: onClear,
              onCancel: onCancel,
            ),
          ],
        ),
      ),
    );
  }
}

/// Header de la tarjeta con icono, descripción y estado
class _SyncItemHeader extends StatelessWidget {
  final IconData icon;
  final String description;
  final SyncItemState state;

  const _SyncItemHeader({
    required this.icon,
    required this.description,
    required this.state,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        Icon(icon, size: 24),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            description,
            style: theme.typography.bodyStrong,
          ),
        ),
        _SyncStatusIcon(state: state),
      ],
    );
  }
}

/// Icono de estado de sincronización
class _SyncStatusIcon extends StatelessWidget {
  final SyncItemState state;

  const _SyncStatusIcon({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    switch (state.status) {
      case SyncStatus.syncing:
        return const SizedBox(
          width: 16,
          height: 16,
          child: ProgressRing(strokeWidth: 2),
        );
      case SyncStatus.success:
        return Icon(FluentIcons.check_mark, size: 16, color: Colors.green);
      case SyncStatus.error:
        return Icon(FluentIcons.error_badge, size: 16, color: Colors.red);
      case SyncStatus.idle:
        if (state.lastSyncDate != null) {
          return Icon(
            FluentIcons.status_circle_checkmark,
            size: 16,
            color: theme.accentColor,
          );
        }
        return Icon(
          FluentIcons.status_circle_ring,
          size: 16,
          color: theme.resources.textFillColorSecondary,
        );
    }
  }
}

/// Panel de información con conteo local y fecha de última sincronización
class _SyncInfoPanel extends StatelessWidget {
  final SyncItemState state;

  const _SyncInfoPanel({required this.state});

  String _formatDate(DateTime? date) {
    if (date == null) return 'Nunca';
    final formatter = DateFormat('dd/MM/yyyy HH:mm');
    return formatter.format(date.toLocal());
  }

  String _formatRelativeTime(DateTime? date) {
    if (date == null) return '';
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) return 'hace un momento';
    if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'hace ${diff.inHours} horas';
    if (diff.inDays < 7) return 'hace ${diff.inDays} dias';
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.resources.cardBackgroundFillColorSecondary,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Conteo local
          _InfoRow(
            icon: FluentIcons.database,
            label: 'Local: ',
            value: state.status == SyncStatus.syncing && state.progress != null
                ? '${state.progress!.synced} sincronizados'
                : '${state.localCount} registros',
            isValueBold: true,
          ),
          const SizedBox(height: 4),

          // Última sincronización
          _InfoRow(
            icon: FluentIcons.clock,
            label: 'Ultima sync: ',
            value: _formatDate(state.lastSyncDate),
          ),

          // Tiempo relativo
          if (state.lastSyncDate != null) ...[
            const SizedBox(height: 2),
            Padding(
              padding: const EdgeInsets.only(left: 18),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _formatRelativeTime(state.lastSyncDate),
                  style: theme.typography.caption?.copyWith(
                    color: theme.accentColor,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Fila de información con icono, etiqueta y valor
class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool isValueBold;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.isValueBold = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 12,
          color: theme.resources.textFillColorSecondary,
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.typography.caption?.copyWith(
              fontWeight: isValueBold ? FontWeight.w600 : null,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

/// Display del estado actual de sincronización
class _SyncStatusDisplay extends StatelessWidget {
  final SyncItemState state;

  const _SyncStatusDisplay({required this.state});

  @override
  Widget build(BuildContext context) {
    switch (state.status) {
      case SyncStatus.success:
        if (state.count != null) {
          return _SuccessStatus(count: state.count!, wasIncremental: state.wasIncremental);
        }
        return _IdleStatus(lastSyncDate: state.lastSyncDate);
      case SyncStatus.error:
        return _ErrorStatus(error: state.error);
      case SyncStatus.syncing:
        return _SyncingProgress(progress: state.progress);
      case SyncStatus.idle:
        return _IdleStatus(lastSyncDate: state.lastSyncDate);
    }
  }
}

/// Estado de éxito
class _SuccessStatus extends StatelessWidget {
  final int count;
  final bool wasIncremental;

  const _SuccessStatus({
    required this.count,
    required this.wasIncremental,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        Icon(FluentIcons.check_mark, size: 12, color: Colors.green),
        const SizedBox(width: 4),
        Text(
          '$count registros sincronizados',
          style: theme.typography.caption?.copyWith(
            color: Colors.green,
          ),
        ),
        if (wasIncremental) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Text(
              'incremental',
              style: theme.typography.caption?.copyWith(
                color: Colors.blue,
                fontSize: 9,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// Estado de error
class _ErrorStatus extends StatelessWidget {
  final String? error;

  const _ErrorStatus({this.error});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(FluentIcons.error_badge, size: 12, color: Colors.red),
            const SizedBox(width: 4),
            Text(
              'Error en sincronizacion',
              style: theme.typography.caption?.copyWith(
                color: Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          error ?? 'Error desconocido',
          style: theme.typography.caption?.copyWith(
            color: Colors.red.withValues(alpha: 0.8),
          ),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Estado idle
class _IdleStatus extends StatelessWidget {
  final DateTime? lastSyncDate;

  const _IdleStatus({this.lastSyncDate});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (lastSyncDate != null) {
      return Text(
        'Listo para sincronizacion incremental',
        style: theme.typography.caption?.copyWith(
          color: theme.resources.textFillColorSecondary,
        ),
      );
    }

    return Text(
      'Nunca sincronizado - se requiere sync completo',
      style: theme.typography.caption?.copyWith(
        color: Colors.orange,
      ),
    );
  }
}

/// Progreso de sincronización
class _SyncingProgress extends StatelessWidget {
  final SyncProgress? progress;

  const _SyncingProgress({this.progress});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (progress == null) {
      return Row(
        children: [
          const SizedBox(
            width: 12,
            height: 12,
            child: ProgressRing(strokeWidth: 2),
          ),
          const SizedBox(width: 8),
          Text('Iniciando...', style: theme.typography.caption),
        ],
      );
    }

    // Mostrar error parcial si existe
    if (progress!.error != null) {
      return _PartialErrorDisplay(error: progress!.error!);
    }

    final percentage = progress!.percentage;
    final progressValue = progress!.total > 0 ? progress!.synced / progress!.total : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ProgressBar(value: progressValue * 100),
        const SizedBox(height: 8),

        // Stats row
        Row(
          children: [
            Expanded(
              child: Text(
                '${progress!.synced}/${progress!.total} registros',
                style: theme.typography.caption?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${(percentage ?? 0).toStringAsFixed(1)}%',
                style: theme.typography.caption?.copyWith(
                  color: theme.accentColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),

        // Item actual siendo sincronizado
        if (progress!.currentItem != null) ...[
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(
                width: 10,
                height: 10,
                child: ProgressRing(strokeWidth: 1.5),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  progress!.currentItem!,
                  style: theme.typography.caption?.copyWith(
                    color: theme.resources.textFillColorSecondary,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        // Registros restantes
        if (progress!.remaining > 0) ...[
          const SizedBox(height: 2),
          Text(
            'Faltan ${progress!.remaining} registros',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
              fontSize: 10,
            ),
          ),
        ],
      ],
    );
  }
}

/// Display de error parcial durante sincronización
class _PartialErrorDisplay extends StatelessWidget {
  final String error;

  const _PartialErrorDisplay({required this.error});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(FluentIcons.warning, size: 12, color: Colors.orange),
            const SizedBox(width: 4),
            Text(
              'Error parcial',
              style: theme.typography.caption?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          error,
          style: theme.typography.caption?.copyWith(
            color: Colors.orange.withValues(alpha: 0.8),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Botones de acción de la tarjeta
class _SyncActionButtons extends StatelessWidget {
  final bool isSyncing;
  final bool isOnline;
  final bool isSyncingAll;
  final VoidCallback onSync;
  final VoidCallback onForceSync;
  final VoidCallback onClear;
  final VoidCallback onCancel;

  const _SyncActionButtons({
    required this.isSyncing,
    required this.isOnline,
    required this.isSyncingAll,
    required this.onSync,
    required this.onForceSync,
    required this.onClear,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Botón principal (Sincronizar/Cancelar)
        Expanded(
          child: isSyncing
              ? FilledButton(
                  style: ButtonStyle(
                    backgroundColor: WidgetStateProperty.all(Colors.orange),
                  ),
                  onPressed: onCancel,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(FluentIcons.cancel, size: 14),
                      SizedBox(width: 8),
                      Text('Cancelar'),
                    ],
                  ),
                )
              : Button(
                  onPressed: isOnline && !isSyncingAll ? onSync : null,
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Padding(
                        padding: EdgeInsets.only(right: 8),
                        child: Icon(FluentIcons.sync, size: 14),
                      ),
                      Text('Sincronizar'),
                    ],
                  ),
                ),
        ),
        const SizedBox(width: 8),

        // Botón forzar sincronización completa
        Tooltip(
          message: 'Forzar sincronizacion completa',
          child: IconButton(
            icon: const Icon(FluentIcons.refresh, size: 16),
            onPressed: isOnline && !isSyncing && !isSyncingAll ? onForceSync : null,
          ),
        ),
        const SizedBox(width: 4),

        // Botón vaciar tabla
        Tooltip(
          message: 'Vaciar tabla local',
          child: IconButton(
            icon: Icon(
              FluentIcons.delete,
              size: 16,
              color: !isSyncing && !isSyncingAll ? Colors.red : null,
            ),
            onPressed: !isSyncing && !isSyncingAll ? onClear : null,
          ),
        ),
      ],
    );
  }
}
