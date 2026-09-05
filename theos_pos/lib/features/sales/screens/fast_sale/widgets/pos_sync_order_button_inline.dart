part of 'pos_order_lines_panel.dart';

/// Inline sync button for pending offline operations
class _SyncOrderButtonInline extends ConsumerStatefulWidget {
  final int orderId;
  final bool fullWidth;

  const _SyncOrderButtonInline({required this.orderId, this.fullWidth = false});

  @override
  ConsumerState<_SyncOrderButtonInline> createState() =>
      _SyncOrderButtonInlineState();
}

class _SyncOrderButtonInlineState
    extends ConsumerState<_SyncOrderButtonInline> {
  bool _isSyncing = false;

  Future<void> _syncOrder() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final offlineSyncService = ref.read(offlineSyncServiceProvider);
      if (offlineSyncService == null) {
        logger.w('[SyncOrderButton]', 'Cannot sync: no sync service available');
        return;
      }

      final result = await offlineSyncService.processSaleOrderQueue(
        widget.orderId,
      );

      if (mounted) {
        // El contador de pendientes se actualiza automáticamente via Drift watch
        // Show result message
        if (result.synced > 0 || result.failed > 0) {
          String message;
          String title;

          if (result.hasInvoice) {
            // Invoice was created
            title = 'Factura creada';
            message = 'Factura #${result.invoiceCreated} creada exitosamente';
          } else if (result.failed == 0) {
            title = 'Sincronizado';
            message = 'Sincronizado: ${result.synced} operaciones';
          } else {
            title = 'Sync parcial';
            message = 'Sync: ${result.synced} ok, ${result.failed} fallidas';
          }

          if (result.failed == 0) {
            CopyableInfoBar.showSuccess(
              context,
              title: title,
              message: message,
            );
          } else {
            CopyableInfoBar.showWarning(
              context,
              title: title,
              message: message,
            );
          }
        } else if (result.isEmpty) {
          // No operations were processed (might have been filtered or already synced)
          CopyableInfoBar.showInfo(
            context,
            title: 'Sin cambios',
            message: 'No hay operaciones pendientes para sincronizar',
          );
        } else if (result.hasConflicts) {
          // Conflicts detected
          CopyableInfoBar.showWarning(
            context,
            title: 'Conflictos detectados',
            message:
                '${result.conflicts.length} operaciones tienen conflictos con el servidor',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error de sincronización',
          message: 'No se pudieron sincronizar los datos. Intente nuevamente.',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch pending sync count for this order
    final pendingSyncAsync = ref.watch(
      orderPendingSyncProvider(widget.orderId),
    );
    if (pendingSyncAsync.hasError) {
      return Tooltip(
        message: 'No se pudo consultar la cola de sincronización',
        child: IconButton(
          icon: Icon(FluentIcons.warning, color: Colors.orange),
          onPressed: () =>
              ref.invalidate(orderPendingSyncProvider(widget.orderId)),
        ),
      );
    }
    final pendingCount = pendingSyncAsync.value ?? 0;

    // Don't show if no pending operations
    if (pendingCount == 0) return const SizedBox.shrink();

    // Check if we're online using OdooClient (HTTP connectivity)
    // Remote synchronization uses authenticated HTTP.
    final odooClient = ref.watch(odooClientProvider);
    final isOnline = odooClient?.isConfigured ?? false;

    final button = Tooltip(
      message: isOnline
          ? 'Sincronizar $pendingCount operaciones pendientes con Odoo'
          : 'Sin conexión a Odoo - $pendingCount operaciones pendientes',
      child: FilledButton(
        onPressed: isOnline && !_isSyncing ? _syncOrder : null,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.danger.withValues(alpha: 0.7);
            }
            return AppColors.success;
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(
              horizontal: Spacing.md,
              vertical: Spacing.sm,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: ProgressRing(strokeWidth: 2, activeColor: Colors.white),
              )
            else
              Icon(
                isOnline ? FluentIcons.sync : FluentIcons.cloud_not_synced,
                size: 14,
                color: Colors.white,
              ),
            const SizedBox(width: 6),
            Text(
              _isSyncing
                  ? 'Sincronizando...'
                  : isOnline
                  ? 'Sincronizar ($pendingCount)'
                  : 'Offline ($pendingCount)',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return Padding(
      padding: const EdgeInsets.only(left: Spacing.xs),
      child: button,
    );
  }
}
