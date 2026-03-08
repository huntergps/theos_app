import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/datasources/datasources.dart';
import '../../core/database/repositories/repository_providers.dart';
import '../../core/services/logger_service.dart';
import '../../core/theme/spacing.dart';
import '../widgets/dialogs/copyable_info_bar.dart';

/// Screen to view and manage failed sync operations (Dead Letter Queue)
///
/// Allows users to:
/// - View operations that exceeded max retries
/// - Retry individual operations
/// - Remove operations from the queue
/// - Clear all failed operations
class DeadLetterQueueScreen extends ConsumerStatefulWidget {
  const DeadLetterQueueScreen({super.key});

  @override
  ConsumerState<DeadLetterQueueScreen> createState() =>
      _DeadLetterQueueScreenState();
}

class _DeadLetterQueueScreenState extends ConsumerState<DeadLetterQueueScreen> {
  List<OfflineOperation> _deadLetterOps = [];
  bool _isLoading = true;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _loadDeadLetterOperations();
  }

  Future<void> _loadDeadLetterOperations() async {
    setState(() => _isLoading = true);

    try {
      final syncService = ref.read(offlineSyncServiceProvider);
      if (syncService != null) {
        final ops = await syncService.getDeadLetterOperations();
        setState(() {
          _deadLetterOps = ops;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      logger.e('[DeadLetterQueue]', 'Error loading operations', e);
      setState(() => _isLoading = false);
    }
  }

  Future<void> _retryOperation(OfflineOperation op) async {
    setState(() => _isProcessing = true);

    try {
      final syncService = ref.read(offlineSyncServiceProvider);
      if (syncService != null) {
        // Reset retry count so it can be processed again
        await syncService.resetOperationRetry(op.id);

        // Show success message
        if (mounted) {
          CopyableInfoBar.showSuccess(
            context,
            title: 'Operación reintentada',
            message: '${op.model} - ${op.method}',
          );
        }

        // Reload list
        await _loadDeadLetterOperations();
      }
    } catch (e) {
      logger.e('[DeadLetterQueue]', 'Error retrying operation', e);
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error',
          message: 'No se pudo reintentar: $e',
        );
      }
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _removeOperation(OfflineOperation op) async {
    // Confirm deletion
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Eliminar operación'),
        content: Text(
          '¿Está seguro de eliminar esta operación?\n\n'
          'Modelo: ${op.model}\n'
          'Método: ${op.method}\n'
          'Reintentos: ${op.retryCount}\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          Button(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Eliminar'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final syncService = ref.read(offlineSyncServiceProvider);
      if (syncService != null) {
        await syncService.removeDeadLetterOperation(op.id);

        if (mounted) {
          CopyableInfoBar.showWarning(
            context,
            title: 'Operación eliminada',
            message: 'La operación ha sido eliminada de la cola',
          );
        }

        await _loadDeadLetterOperations();
      }
    } catch (e) {
      logger.e('[DeadLetterQueue]', 'Error removing operation', e);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _retryAllOperations() async {
    if (_deadLetterOps.isEmpty) return;

    setState(() => _isProcessing = true);

    try {
      final syncService = ref.read(offlineSyncServiceProvider);
      if (syncService != null) {
        int retried = 0;
        for (final op in _deadLetterOps) {
          await syncService.resetOperationRetry(op.id);
          retried++;
        }

        if (mounted) {
          CopyableInfoBar.showSuccess(
            context,
            title: 'Operaciones reintentadas',
            message: '$retried operaciones movidas a la cola',
          );
        }

        await _loadDeadLetterOperations();
      }
    } catch (e) {
      logger.e('[DeadLetterQueue]', 'Error retrying all', e);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _clearAllOperations() async {
    if (_deadLetterOps.isEmpty) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Limpiar todas las operaciones'),
        content: Text(
          '¿Está seguro de eliminar ${_deadLetterOps.length} operaciones fallidas?\n\n'
          'Esta acción no se puede deshacer y los datos se perderán.',
        ),
        actions: [
          Button(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(context).pop(false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Limpiar todo'),
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);

    try {
      final syncService = ref.read(offlineSyncServiceProvider);
      if (syncService != null) {
        int removed = 0;
        for (final op in _deadLetterOps) {
          await syncService.removeDeadLetterOperation(op.id);
          removed++;
        }

        if (mounted) {
          CopyableInfoBar.showWarning(
            context,
            title: 'Cola limpiada',
            message: '$removed operaciones eliminadas',
          );
        }

        await _loadDeadLetterOperations();
      }
    } catch (e) {
      logger.e('[DeadLetterQueue]', 'Error clearing all', e);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Cola de Operaciones Fallidas'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Actualizar'),
              onPressed: _isProcessing ? null : _loadDeadLetterOperations,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.play),
              label: const Text('Reintentar todo'),
              onPressed: _isProcessing || _deadLetterOps.isEmpty
                  ? null
                  : _retryAllOperations,
            ),
            CommandBarButton(
              icon: const Icon(FluentIcons.delete),
              label: const Text('Limpiar todo'),
              onPressed: _isProcessing || _deadLetterOps.isEmpty
                  ? null
                  : _clearAllOperations,
            ),
          ],
        ),
      ),
      content: _buildContent(theme),
    );
  }

  Widget _buildContent(FluentThemeData theme) {
    if (_isLoading) {
      return const Center(child: ProgressRing());
    }

    if (_deadLetterOps.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              FluentIcons.completed,
              size: 64,
              color: Colors.green,
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Sin operaciones fallidas',
              style: theme.typography.subtitle,
            ),
            const SizedBox(height: Spacing.sm),
            Text(
              'Todas las operaciones se sincronizaron correctamente',
              style: theme.typography.body?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.all(Spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Summary card
              Card(
                padding: const EdgeInsets.all(Spacing.md),
                child: Row(
                  children: [
                    Icon(
                      FluentIcons.warning,
                      color: Colors.orange,
                      size: 32,
                    ),
                    const SizedBox(width: Spacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${_deadLetterOps.length} operaciones fallidas',
                            style: theme.typography.subtitle,
                          ),
                          Text(
                            'Estas operaciones excedieron el número máximo de reintentos',
                            style: theme.typography.caption,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Spacing.md),

              // Operations list
              Expanded(
                child: ListView.separated(
                  itemCount: _deadLetterOps.length,
                  separatorBuilder: (_, _) =>
                      const SizedBox(height: Spacing.sm),
                  itemBuilder: (context, index) {
                    final op = _deadLetterOps[index];
                    return _buildOperationCard(op, theme);
                  },
                ),
              ),
            ],
          ),
        ),

        // Processing overlay
        if (_isProcessing)
          Container(
            color: Colors.black.withAlpha(77),
            child: const Center(child: ProgressRing()),
          ),
      ],
    );
  }

  Widget _buildOperationCard(OfflineOperation op, FluentThemeData theme) {
    return Card(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                _getIconForModel(op.model),
                color: theme.accentColor,
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getModelDisplayName(op.model),
                      style: theme.typography.bodyStrong,
                    ),
                    Text(
                      'Método: ${op.method}',
                      style: theme.typography.caption,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withAlpha(51),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${op.retryCount} reintentos',
                  style: theme.typography.caption?.copyWith(
                    color: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),

          // Record ID and UUID
          if (op.recordId != null || op.values['uuid'] != null)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Text(
                'ID: ${op.recordId ?? "N/A"} | UUID: ${_formatUuid(op.values['uuid'])}',
                style: theme.typography.caption,
              ),
            ),

          // Error message
          if (op.lastError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: Colors.red.withAlpha(25),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                op.lastError!,
                style: theme.typography.caption?.copyWith(
                  color: Colors.red,
                ),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),

          const SizedBox(height: Spacing.sm),

          // Timestamps
          Row(
            children: [
              Text(
                'Creado: ${_formatDateTime(op.createdAt)}',
                style: theme.typography.caption,
              ),
              const Spacer(),
              Text(
                'Último intento: ${_formatDateTime(op.lastRetryAt)}',
                style: theme.typography.caption,
              ),
            ],
          ),

          const SizedBox(height: Spacing.md),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Button(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.delete, size: 14),
                    SizedBox(width: 4),
                    Text('Eliminar'),
                  ],
                ),
                onPressed: () => _removeOperation(op),
              ),
              const SizedBox(width: Spacing.sm),
              FilledButton(
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.play, size: 14),
                    SizedBox(width: 4),
                    Text('Reintentar'),
                  ],
                ),
                onPressed: () => _retryOperation(op),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getIconForModel(String model) {
    switch (model) {
      case 'sale.order':
        return FluentIcons.shopping_cart;
      case 'collection.session':
        return FluentIcons.money;
      case 'account.payment':
        return FluentIcons.payment_card;
      case 'account.move':
        return FluentIcons.document;
      default:
        return FluentIcons.database;
    }
  }

  String _getModelDisplayName(String model) {
    switch (model) {
      case 'sale.order':
        return 'Orden de Venta';
      case 'collection.session':
        return 'Sesión de Cobranza';
      case 'account.payment':
        return 'Pago';
      case 'account.move':
        return 'Factura';
      default:
        return model;
    }
  }

  String _formatDateTime(DateTime? dt) {
    if (dt == null) return '-';
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatUuid(dynamic uuid) {
    if (uuid == null) return 'N/A';
    final uuidStr = uuid.toString();
    if (uuidStr.length >= 8) {
      return '${uuidStr.substring(0, 8)}...';
    }
    return uuidStr;
  }
}
