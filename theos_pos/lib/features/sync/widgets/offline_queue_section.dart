import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/database/datasources/datasources.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../../../shared/providers/offline_queue_provider.dart';

/// Section showing offline queue status and operations
class OfflineQueueSection extends ConsumerWidget {
  const OfflineQueueSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queueState = ref.watch(offlineQueueProvider);
    final theme = FluentTheme.of(context);
    final isOnline = ref.watch(catalogSyncRepositoryProvider)?.isOnline ?? false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with count and actions
        _QueueHeader(
          totalCount: queueState.totalCount,
          isProcessing: queueState.isProcessing,
          isOnline: isOnline,
          onRefresh: () => ref.read(offlineQueueProvider.notifier).refresh(),
          onProcess: isOnline
              ? () => ref.read(offlineQueueProvider.notifier).processQueue()
              : null,
          onClearAll: queueState.totalCount > 0
              ? () => _confirmClearAll(context, ref)
              : null,
        ),
        const SizedBox(height: 12),

        // Priority summary cards
        if (queueState.totalCount > 0) ...[
          _PrioritySummary(
            criticalCount: queueState.criticalCount,
            highCount: queueState.highCount,
            normalCount: queueState.normalCount,
            lowCount: queueState.lowCount,
          ),
          const SizedBox(height: 16),
        ],

        // Operations list or empty state
        if (queueState.isLoading)
          const Center(child: ProgressRing())
        else if (queueState.error != null)
          InfoBar(
            title: const Text('Error'),
            content: Text(queueState.error!),
            severity: InfoBarSeverity.error,
          )
        else if (queueState.totalCount == 0)
          _EmptyQueueState(theme: theme)
        else
          _OperationsList(
            operations: queueState.operations,
            onRemove: (id) => _confirmRemoveOperation(context, ref, id),
          ),
      ],
    );
  }

  Future<void> _confirmClearAll(BuildContext context, WidgetRef ref) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Vaciar Cola Offline'),
        content: const Text(
          'Se eliminaran todas las operaciones pendientes. '
          'Esta accion no se puede deshacer.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Vaciar'),
          ),
        ],
      ),
    );

    if (result == true) {
      await ref.read(offlineQueueProvider.notifier).clearAll();
    }
  }

  Future<void> _confirmRemoveOperation(
    BuildContext context,
    WidgetRef ref,
    int operationId,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Eliminar Operacion'),
        content: const Text(
          'Esta operacion no sera sincronizada. Continuar?',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (result == true) {
      await ref.read(offlineQueueProvider.notifier).removeOperation(operationId);
    }
  }
}

/// Header with queue info and actions
class _QueueHeader extends StatelessWidget {
  final int totalCount;
  final bool isProcessing;
  final bool isOnline;
  final VoidCallback onRefresh;
  final VoidCallback? onProcess;
  final VoidCallback? onClearAll;

  const _QueueHeader({
    required this.totalCount,
    required this.isProcessing,
    required this.isOnline,
    required this.onRefresh,
    this.onProcess,
    this.onClearAll,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        Icon(
          FluentIcons.cloud_upload,
          size: 20,
          color: totalCount > 0
              ? Colors.orange
              : theme.resources.textFillColorSecondary,
        ),
        const SizedBox(width: 8),
        Text(
          'Cola Offline',
          style: theme.typography.subtitle,
        ),
        const SizedBox(width: 8),
        if (totalCount > 0)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$totalCount pendiente${totalCount != 1 ? 's' : ''}',
              style: theme.typography.caption?.copyWith(
                color: Colors.orange,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const Spacer(),
        // Action buttons
        if (isProcessing)
          const Row(
            children: [
              ProgressRing(strokeWidth: 2),
              SizedBox(width: 8),
              Text('Procesando...'),
            ],
          )
        else ...[
          IconButton(
            icon: const Icon(FluentIcons.refresh, size: 16),
            onPressed: onRefresh,
          ),
          if (onClearAll != null)
            IconButton(
              icon: Icon(FluentIcons.delete, size: 16, color: Colors.red),
              onPressed: onClearAll,
            ),
          const SizedBox(width: 8),
          if (totalCount > 0)
            FilledButton(
              onPressed: onProcess,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(FluentIcons.cloud_upload, size: 14),
                  const SizedBox(width: 6),
                  Text(isOnline ? 'Procesar Cola' : 'Sin Conexion'),
                ],
              ),
            ),
        ],
      ],
    );
  }
}

/// Priority summary cards
class _PrioritySummary extends StatelessWidget {
  final int criticalCount;
  final int highCount;
  final int normalCount;
  final int lowCount;

  const _PrioritySummary({
    required this.criticalCount,
    required this.highCount,
    required this.normalCount,
    required this.lowCount,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (criticalCount > 0)
          _PriorityChip(
            label: 'Critico',
            count: criticalCount,
            color: Colors.red,
          ),
        if (highCount > 0)
          _PriorityChip(
            label: 'Alto',
            count: highCount,
            color: Colors.orange,
          ),
        if (normalCount > 0)
          _PriorityChip(
            label: 'Normal',
            count: normalCount,
            color: Colors.blue,
          ),
        if (lowCount > 0)
          _PriorityChip(
            label: 'Bajo',
            count: lowCount,
            color: Colors.grey,
          ),
      ],
    );
  }
}

/// Individual priority chip
class _PriorityChip extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _PriorityChip({
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$label: $count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Empty queue state
class _EmptyQueueState extends StatelessWidget {
  final FluentThemeData theme;

  const _EmptyQueueState({required this.theme});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.completed,
              size: 48,
              color: Colors.green,
            ),
            const SizedBox(height: 12),
            Text(
              'Cola vacia',
              style: theme.typography.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Todas las operaciones han sido sincronizadas',
              style: theme.typography.caption?.copyWith(
                color: theme.resources.textFillColorSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// List of operations grouped by model
class _OperationsList extends StatelessWidget {
  final List<OfflineOperation> operations;
  final void Function(int) onRemove;

  const _OperationsList({
    required this.operations,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    // Group by model
    final grouped = <String, List<OfflineOperation>>{};
    for (final op in operations) {
      grouped.putIfAbsent(op.model, () => []).add(op);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: grouped.entries.map((entry) {
        return _ModelOperationsGroup(
          model: entry.key,
          operations: entry.value,
          onRemove: onRemove,
        );
      }).toList(),
    );
  }
}

/// Group of operations for a specific model
class _ModelOperationsGroup extends StatelessWidget {
  final String model;
  final List<OfflineOperation> operations;
  final void Function(int) onRemove;

  const _ModelOperationsGroup({
    required this.model,
    required this.operations,
    required this.onRemove,
  });

  String get _modelDisplayName {
    switch (model) {
      case 'collection.session':
        return 'Sesiones de Caja';
      case 'account.payment':
        return 'Pagos';
      case 'res.partner':
        return 'Clientes';
      case 'sale.order':
        return 'Ordenes de Venta';
      case 'sale.order.line':
        return 'Lineas de Orden';
      default:
        return model;
    }
  }

  IconData get _modelIcon {
    switch (model) {
      case 'collection.session':
        return FluentIcons.money;
      case 'account.payment':
        return FluentIcons.payment_card;
      case 'res.partner':
        return FluentIcons.people;
      case 'sale.order':
        return FluentIcons.shopping_cart;
      case 'sale.order.line':
        return FluentIcons.list;
      default:
        return FluentIcons.sync;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Expander(
      header: Row(
        children: [
          Icon(_modelIcon, size: 16),
          const SizedBox(width: 8),
          Text(_modelDisplayName),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: theme.accentColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${operations.length}',
              style: theme.typography.caption?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      content: Column(
        children: operations.map((op) {
          return _OperationTile(
            operation: op,
            onRemove: () => onRemove(op.id),
          );
        }).toList(),
      ),
    );
  }
}

/// Individual operation tile
class _OperationTile extends StatelessWidget {
  final OfflineOperation operation;
  final VoidCallback onRemove;

  const _OperationTile({
    required this.operation,
    required this.onRemove,
  });

  Color _getPriorityColor() {
    switch (operation.priority) {
      case OfflinePriority.critical:
        return Colors.red;
      case OfflinePriority.high:
        return Colors.orange;
      case OfflinePriority.normal:
        return Colors.blue;
      case OfflinePriority.low:
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  String _getMethodDisplay() {
    switch (operation.method) {
      case 'session_create_and_open':
        return 'Crear y Abrir';
      case 'session_open':
        return 'Abrir';
      case 'session_closing_control':
        return 'Control de Cierre';
      case 'session_close':
        return 'Cerrar';
      case 'payment_create':
        return 'Crear';
      case 'partner_create':
        return 'Crear';
      case 'create':
        return 'Crear';
      case 'write':
        return 'Actualizar';
      case 'unlink':
        return 'Eliminar';
      default:
        return operation.method;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final dateFormat = DateFormat('dd/MM HH:mm');

    return ListTile(
      leading: Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: _getPriorityColor(),
          shape: BoxShape.circle,
        ),
      ),
      title: Text(
        _getMethodDisplay(),
        style: theme.typography.body,
      ),
      subtitle: Text(
        'Creado: ${dateFormat.format(operation.createdAt.toLocal())}',
        style: theme.typography.caption,
      ),
      trailing: IconButton(
        icon: Icon(FluentIcons.delete, size: 14, color: Colors.red),
        onPressed: onRemove,
      ),
    );
  }
}
