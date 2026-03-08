import 'package:drift/drift.dart' as drift;
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;
import '../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../../core/database/repositories/repository_providers.dart';
import '../../core/services/platform/global_notification_service.dart';

/// Provider for pending sync conflicts (reactive stream).
///
/// Uses Drift `.watch()` so the UI auto-updates when conflicts are
/// resolved or new ones are detected — no manual `invalidate()` needed.
final pendingConflictsProvider = StreamProvider<List<SyncConflictData>>((
  ref,
) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return Stream.value([]);

  final db = ref.watch(appDatabaseProvider);
  return (db.select(db.syncConflict)
        ..where((t) => t.isResolved.equals(false))
        ..orderBy([(t) => drift.OrderingTerm.desc(t.detectedAt)]))
      .watch();
});

/// Provider for conflict count (for badge/notification).
///
/// Derives from [pendingConflictsProvider] stream — auto-updates reactively.
final conflictCountProvider = Provider<AsyncValue<int>>((ref) {
  return ref.watch(pendingConflictsProvider).whenData((conflicts) => conflicts.length);
});

/// Screen for resolving sync conflicts between local and server data.
///
/// Shows a list of pending conflicts with options to:
/// - Keep local changes
/// - Accept server values
/// - View detailed comparison of local vs server data
class ConflictResolutionScreen extends ConsumerStatefulWidget {
  const ConflictResolutionScreen({super.key});

  @override
  ConsumerState<ConflictResolutionScreen> createState() =>
      _ConflictResolutionScreenState();
}

class _ConflictResolutionScreenState
    extends ConsumerState<ConflictResolutionScreen> {
  int? _selectedConflictId;
  bool _isProcessing = false;

  @override
  Widget build(BuildContext context) {
    final conflictsAsync = ref.watch(pendingConflictsProvider);
    final theme = FluentTheme.of(context);

    return ScaffoldPage(
      header: PageHeader(
        title: const Text('Resolución de Conflictos'),
        commandBar: CommandBar(
          mainAxisAlignment: MainAxisAlignment.end,
          primaryItems: [
            CommandBarButton(
              icon: const Icon(FluentIcons.refresh),
              label: const Text('Actualizar'),
              onPressed: () => ref.invalidate(pendingConflictsProvider),
            ),
          ],
        ),
      ),
      content: conflictsAsync.when(
        data: (conflicts) {
          if (conflicts.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(FluentIcons.check_mark, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  Text(
                    'No hay conflictos pendientes',
                    style: theme.typography.subtitle,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Todos los datos están sincronizados correctamente',
                    style: theme.typography.body?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ],
              ),
            );
          }

          return Row(
            children: [
              // Conflict list
              SizedBox(
                width: 400,
                child: Card(
                  padding: EdgeInsets.zero,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Icon(
                              FluentIcons.warning,
                              color: Colors.orange,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${conflicts.length} conflicto(s) pendiente(s)',
                              style: theme.typography.bodyStrong,
                            ),
                          ],
                        ),
                      ),
                      const Divider(),
                      Expanded(
                        child: ListView.builder(
                          itemCount: conflicts.length,
                          itemBuilder: (context, index) {
                            final conflict = conflicts[index];
                            final isSelected =
                                _selectedConflictId == conflict.id;

                            return ListTile.selectable(
                              selected: isSelected,
                              onPressed: () {
                                setState(() {
                                  _selectedConflictId = conflict.id;
                                });
                              },
                              leading: _getModelIcon(conflict.model),
                              title: Text(
                                _getConflictTitle(conflict),
                                style: theme.typography.body,
                              ),
                              subtitle: Text(
                                _formatDate(conflict.detectedAt),
                                style: theme.typography.caption,
                              ),
                              trailing: _getStatusBadge(conflict.resolution ?? 'pending'),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Conflict details
              Expanded(
                child: _selectedConflictId != null
                    ? _buildConflictDetails(
                        conflicts.firstWhere(
                          (c) => c.id == _selectedConflictId,
                        ),
                      )
                    : Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              FluentIcons.info,
                              size: 48,
                              color: theme.resources.textFillColorSecondary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Selecciona un conflicto para ver los detalles',
                              style: theme.typography.body?.copyWith(
                                color: theme.resources.textFillColorSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          );
        },
        loading: () => const Center(child: ProgressRing()),
        error: (error, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.error, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text('Error: $error'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildConflictDetails(SyncConflictData conflict) {
    final theme = FluentTheme.of(context);

    // Note: SyncConflict stores full objects in localData/remoteData as JSON
    // Not individual field conflicts like DirtyFields
    // final fieldName = conflict.fieldName; // Not available in SyncConflict
    // final localValue = conflict.localValue; // Not available in SyncConflict
    // final serverValue = conflict.serverValue; // Not available in SyncConflict

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              _getModelIcon(conflict.model),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getConflictTitle(conflict),
                      style: theme.typography.subtitle,
                    ),
                    Text(
                      'Modelo: ${conflict.model} | ID: ${conflict.localId}',
                      style: theme.typography.caption?.copyWith(
                        color: theme.resources.textFillColorSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Conflict type info
          Text(
            'Tipo de conflicto: ${conflict.conflictType}',
            style: theme.typography.bodyStrong,
          ),
          const SizedBox(height: 16),

          // Comparison cards
          Row(
            children: [
              // Local value
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.blue.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FluentIcons.cell_phone,
                            size: 16,
                            color: Colors.blue,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Datos Locales',
                            style: theme.typography.bodyStrong?.copyWith(
                              color: Colors.blue,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        conflict.localData,
                        style: theme.typography.body,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 16),

              // Server value
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: Colors.green.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            FluentIcons.cloud,
                            size: 16,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Datos del Servidor',
                            style: theme.typography.bodyStrong?.copyWith(
                              color: Colors.green,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        conflict.remoteData,
                        style: theme.typography.body,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const Spacer(),

          // Timestamps
          Text(
            'Detectado: ${_formatDate(conflict.detectedAt)}',
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),

          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 16),

          // Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Button(
                onPressed: _isProcessing
                    ? null
                    : () => _resolveConflict(conflict.id, 'local'),
                child: Row(
                  children: [
                    const Icon(FluentIcons.cell_phone, size: 16),
                    const SizedBox(width: 8),
                    const Text('Mantener Local'),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              FilledButton(
                onPressed: _isProcessing
                    ? null
                    : () => _resolveConflict(conflict.id, 'server'),
                child: Row(
                  children: [
                    Icon(FluentIcons.cloud, size: 16, color: Colors.white),
                    const SizedBox(width: 8),
                    const Text('Usar Servidor'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _resolveConflict(int conflictId, String resolution) async {
    setState(() {
      _isProcessing = true;
    });

    try {
      final db = ref.read(appDatabaseProvider);

      // Update conflict status directly in database
      if (resolution == 'local') {
        await (db.update(
          db.syncConflict,
        )..where((t) => t.id.equals(conflictId))).write(
          SyncConflictCompanion(
            resolution: const drift.Value('local_wins'),
            isResolved: const drift.Value(true),
            resolvedAt: drift.Value(DateTime.now()),
          ),
        );
      } else {
        await (db.update(
          db.syncConflict,
        )..where((t) => t.id.equals(conflictId))).write(
          SyncConflictCompanion(
            resolution: const drift.Value('remote_wins'),
            isResolved: const drift.Value(true),
            resolvedAt: drift.Value(DateTime.now()),
          ),
        );
      }

      // Refresh the list
      ref.invalidate(pendingConflictsProvider);

      // Clear selection if resolved conflict was selected
      if (_selectedConflictId == conflictId) {
        setState(() {
          _selectedConflictId = null;
        });
      }

      if (mounted) {
        ref.showSuccessNotification(
          context,
          title: 'Conflicto resuelto',
          message: resolution == 'local'
              ? 'Se mantuvieron los valores locales'
              : 'Se aplicaron los valores del servidor',
        );
      }
    } catch (e) {
      if (mounted) {
        ref.showErrorNotification(
          context,
          title: 'Error',
          message: 'No se pudo resolver el conflicto: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }

  Icon _getModelIcon(String model) {
    switch (model) {
      case 'sale.order':
        return Icon(FluentIcons.shopping_cart, color: Colors.blue);
      case 'sale.order.line':
        return Icon(FluentIcons.product, color: Colors.teal);
      case 'res.partner':
        return Icon(FluentIcons.contact, color: Colors.purple);
      case 'product.product':
        return Icon(FluentIcons.product_catalog, color: Colors.orange);
      default:
        return Icon(FluentIcons.database, color: Colors.grey);
    }
  }

  Widget _getStatusBadge(String status) {
    Color color;
    String label;

    switch (status) {
      case 'pending':
        color = Colors.orange;
        label = 'Pendiente';
        break;
      case 'local_wins':
        color = Colors.blue;
        label = 'Local';
        break;
      case 'server_wins':
        color = Colors.green;
        label = 'Servidor';
        break;
      default:
        color = Colors.grey;
        label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  String _getConflictTitle(SyncConflictData conflict) {
    switch (conflict.model) {
      case 'sale.order':
        return 'Orden de Venta #${conflict.localId}';
      case 'sale.order.line':
        return 'Línea de Orden #${conflict.localId}';
      case 'res.partner':
        return 'Cliente #${conflict.localId}';
      case 'product.product':
        return 'Producto #${conflict.localId}';
      default:
        return '${conflict.model} #${conflict.localId}';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }

}

/// Small widget showing conflict count badge
class ConflictCountBadge extends ConsumerWidget {
  const ConflictCountBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(conflictCountProvider);

    return countAsync.when(
      data: (count) {
        if (count == 0) return const SizedBox.shrink();

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.orange,
            borderRadius: BorderRadius.circular(10),
          ),
          child: Text(
            count > 99 ? '99+' : count.toString(),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
    );
  }
}

/// Icon button with conflict count badge overlay
class ConflictResolutionButton extends ConsumerWidget {
  final VoidCallback onPressed;

  const ConflictResolutionButton({super.key, required this.onPressed});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final countAsync = ref.watch(conflictCountProvider);

    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(icon: const Icon(FluentIcons.sync), onPressed: onPressed),
        Positioned(
          right: -4,
          top: -4,
          child: countAsync.when(
            data: (count) {
              if (count == 0) return const SizedBox.shrink();

              return Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: Colors.orange,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(minWidth: 16, minHeight: 16),
                child: Text(
                  count > 9 ? '9+' : count.toString(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}
