import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/providers/offline_queue_provider.dart';
import '../providers/sync_provider.dart';

/// Badge animado que muestra el estado de sincronización y operaciones offline
///
/// Muestra:
/// - Spinner cuando hay sincronización en progreso
/// - Badge rojo con contador cuando hay operaciones offline pendientes
/// - Icono verde cuando todo está sincronizado
class SyncStatusBadge extends ConsumerWidget {
  /// Tamaño del badge
  final double size;

  /// Si se debe mostrar el tooltip
  final bool showTooltip;

  /// Callback cuando se presiona el badge
  final VoidCallback? onTap;

  const SyncStatusBadge({
    super.key,
    this.size = 24,
    this.showTooltip = true,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final offlineState = ref.watch(offlineQueueProvider);

    final isSyncing = syncState.isAnySyncing || offlineState.isProcessing;
    final pendingCount = offlineState.totalCount;
    final hasErrors = syncState.itemStates.values.any(
      (s) => s.status == SyncStatus.error,
    );

    Widget badge;

    if (isSyncing) {
      // Syncing animation
      badge = _buildSyncingBadge(context, syncState, offlineState);
    } else if (pendingCount > 0) {
      // Pending offline operations
      badge = _buildPendingBadge(context, pendingCount);
    } else if (hasErrors) {
      // Has sync errors
      badge = _buildErrorBadge(context);
    } else {
      // All synced
      badge = _buildSyncedBadge(context);
    }

    if (showTooltip) {
      badge = Tooltip(
        message: _getTooltipMessage(isSyncing, pendingCount, hasErrors),
        child: badge,
      );
    }

    if (onTap != null) {
      badge = GestureDetector(
        onTap: onTap,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: badge,
        ),
      );
    }

    return badge;
  }

  Widget _buildSyncingBadge(
    BuildContext context,
    SyncScreenState syncState,
    OfflineQueueState offlineState,
  ) {
    final theme = FluentTheme.of(context);

    // Calculate progress percentage
    double progress = 0;
    String progressText = '';

    if (offlineState.isProcessing && offlineState.totalSyncCount > 0) {
      progress = offlineState.currentSyncIndex / offlineState.totalSyncCount;
      progressText =
          '${offlineState.currentSyncIndex}/${offlineState.totalSyncCount}';
    } else if (syncState.currentSyncingItem != null) {
      final itemState = syncState.getItemState(syncState.currentSyncingItem!);
      if (itemState.progress != null) {
        progress = itemState.progress!.synced / itemState.progress!.total;
        progressText =
            '${itemState.progress!.synced}/${itemState.progress!.total}';
      }
    }

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Progress ring
          SizedBox(
            width: size,
            height: size,
            child: ProgressRing(
              value: progress > 0 ? progress * 100 : null,
              strokeWidth: 3,
            ),
          ),
          // Progress text (only for larger sizes)
          if (size >= 32 && progressText.isNotEmpty)
            Text(
              progressText,
              style: theme.typography.caption?.copyWith(
                fontSize: 8,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildPendingBadge(BuildContext context, int count) {
    final theme = FluentTheme.of(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.orange,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withValues(alpha: 0.4),
            blurRadius: 4,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: count > 99
            ? Icon(
                FluentIcons.more,
                size: size * 0.6,
                color: Colors.white,
              )
            : Text(
                count.toString(),
                style: theme.typography.caption?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: size * 0.45,
                ),
              ),
      ),
    );
  }

  Widget _buildErrorBadge(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.red,
        shape: BoxShape.circle,
      ),
      child: Icon(
        FluentIcons.error_badge,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }

  Widget _buildSyncedBadge(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.green,
        shape: BoxShape.circle,
      ),
      child: Icon(
        FluentIcons.check_mark,
        size: size * 0.6,
        color: Colors.white,
      ),
    );
  }

  String _getTooltipMessage(bool isSyncing, int pendingCount, bool hasErrors) {
    if (isSyncing) {
      return 'Sincronizando...';
    } else if (pendingCount > 0) {
      return '$pendingCount operaciones pendientes de sincronizar';
    } else if (hasErrors) {
      return 'Hay errores de sincronización';
    } else {
      return 'Todo sincronizado';
    }
  }
}

/// Widget compacto para mostrar en la barra de estado
class SyncStatusIndicator extends ConsumerWidget {
  const SyncStatusIndicator({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final offlineState = ref.watch(offlineQueueProvider);

    final isSyncing = syncState.isAnySyncing || offlineState.isProcessing;
    final pendingCount = offlineState.totalCount;

    if (!isSyncing && pendingCount == 0) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isSyncing
            ? Colors.blue.withValues(alpha: 0.2)
            : Colors.orange.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isSyncing
              ? Colors.blue.withValues(alpha: 0.5)
              : Colors.orange.withValues(alpha: 0.5),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (isSyncing)
            const SizedBox(
              width: 14,
              height: 14,
              child: ProgressRing(strokeWidth: 2),
            )
          else
            Icon(
              FluentIcons.cloud_upload,
              size: 14,
              color: Colors.orange,
            ),
          const SizedBox(width: 6),
          Text(
            isSyncing
                ? 'Sincronizando...'
                : '$pendingCount pendiente${pendingCount > 1 ? 's' : ''}',
            style: FluentTheme.of(context).typography.caption,
          ),
        ],
      ),
    );
  }
}

/// Widget de progreso detallado para pantalla de sincronización
class SyncProgressDetail extends ConsumerWidget {
  final String itemName;
  final bool showLocalCount;

  const SyncProgressDetail({
    super.key,
    required this.itemName,
    this.showLocalCount = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final syncState = ref.watch(syncProvider);
    final itemState = syncState.getItemState(itemName);
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Progress bar
        if (itemState.status == SyncStatus.syncing &&
            itemState.progress != null) ...[
          Row(
            children: [
              Expanded(
                child: ProgressBar(
                  value: (itemState.progress!.synced /
                          itemState.progress!.total) *
                      100,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${itemState.progress!.synced}/${itemState.progress!.total}',
                style: theme.typography.caption,
              ),
            ],
          ),
          const SizedBox(height: 4),
        ],

        // Status row
        Row(
          children: [
            _buildStatusIcon(itemState.status),
            const SizedBox(width: 8),
            Text(
              _getStatusText(itemState),
              style: theme.typography.caption?.copyWith(
                color: _getStatusColor(itemState.status),
              ),
            ),
            const Spacer(),
            if (showLocalCount && itemState.localCount > 0)
              Text(
                '${itemState.localCount} registros',
                style: theme.typography.caption?.copyWith(
                  color: theme.inactiveColor,
                ),
              ),
          ],
        ),

        // Last sync date
        if (itemState.lastSyncDate != null) ...[
          const SizedBox(height: 2),
          Text(
            'Última sync: ${_formatDate(itemState.lastSyncDate!)}${itemState.wasIncremental ? ' (incremental)' : ''}',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
              fontSize: 10,
            ),
          ),
        ],

        // Error message
        if (itemState.error != null) ...[
          const SizedBox(height: 4),
          Text(
            itemState.error!,
            style: theme.typography.caption?.copyWith(
              color: Colors.red,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ],
    );
  }

  Widget _buildStatusIcon(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Icon(FluentIcons.clock, size: 12, color: Colors.grey);
      case SyncStatus.syncing:
        return const SizedBox(
          width: 12,
          height: 12,
          child: ProgressRing(strokeWidth: 2),
        );
      case SyncStatus.success:
        return Icon(FluentIcons.check_mark, size: 12, color: Colors.green);
      case SyncStatus.error:
        return Icon(FluentIcons.error_badge, size: 12, color: Colors.red);
    }
  }

  String _getStatusText(SyncItemState state) {
    switch (state.status) {
      case SyncStatus.idle:
        return 'Pendiente';
      case SyncStatus.syncing:
        if (state.progress != null) {
          final percent =
              (state.progress!.synced / state.progress!.total * 100).toInt();
          return 'Sincronizando... $percent%';
        }
        return 'Sincronizando...';
      case SyncStatus.success:
        return 'Sincronizado (${state.count ?? 0} registros)';
      case SyncStatus.error:
        return 'Error';
    }
  }

  Color _getStatusColor(SyncStatus status) {
    switch (status) {
      case SyncStatus.idle:
        return Colors.grey;
      case SyncStatus.syncing:
        return Colors.blue;
      case SyncStatus.success:
        return Colors.green;
      case SyncStatus.error:
        return Colors.red;
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);

    if (diff.inMinutes < 1) {
      return 'hace un momento';
    } else if (diff.inMinutes < 60) {
      return 'hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'hace ${diff.inHours} h';
    } else {
      return '${date.day}/${date.month} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
    }
  }
}
