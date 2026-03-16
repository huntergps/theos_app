import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/repository_providers.dart';
import '../services/offline_mode_service.dart';
import '../providers/offline_mode_providers.dart';
import '../../../core/services/platform/global_notification_service.dart';

/// Simple toggle widget for on-demand offline mode (FASE 4)
///
/// Features:
/// - Toggle button to activate/deactivate offline mode
/// - Status indicator (active/inactive)
/// - Progress indicator during preload
/// - Shows pending operations count when active
class OfflineModeSection extends ConsumerStatefulWidget {
  const OfflineModeSection({super.key});

  @override
  ConsumerState<OfflineModeSection> createState() => _OfflineModeSectionState();
}

class _OfflineModeSectionState extends ConsumerState<OfflineModeSection> {
  bool _isLoading = false;
  double _progress = 0;
  String _progressMessage = '';

  @override
  Widget build(BuildContext context) {
    final configAsync = ref.watch(offlineModeConfigProvider);
    final pendingOpsAsync = ref.watch(pendingOperationsCountProvider);
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header row with toggle
        Row(
          children: [
            // Status icon
            configAsync.when(
              data: (config) => Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: config.isEnabled
                      ? Colors.blue.withValues(alpha: 0.1)
                      : theme.resources.cardBackgroundFillColorDefault,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  config.isEnabled
                      ? FluentIcons.airplane_solid
                      : FluentIcons.airplane,
                  color: config.isEnabled
                      ? Colors.blue
                      : theme.resources.textFillColorSecondary,
                  size: 20,
                ),
              ),
              loading: () => const ProgressRing(strokeWidth: 2),
              error: (_, _) =>
                  Icon(FluentIcons.error, color: Colors.red, size: 20),
            ),
            const SizedBox(width: 12),
            // Title and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Modo Offline', style: theme.typography.bodyStrong),
                  configAsync.when(
                    data: (config) => Text(
                      config.isEnabled
                          ? 'Activo - trabajando sin conexion'
                          : 'Inactivo',
                      style: theme.typography.caption?.copyWith(
                        color: config.isEnabled
                            ? Colors.blue
                            : theme.resources.textFillColorSecondary,
                      ),
                    ),
                    loading: () =>
                        Text('Cargando...', style: theme.typography.caption),
                    error: (_, _) => Text(
                      'Error',
                      style: theme.typography.caption?.copyWith(
                        color: Colors.red,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Toggle switch
            configAsync.when(
              data: (config) => ToggleSwitch(
                checked: config.isEnabled,
                onChanged: _isLoading ? null : (_) => _toggleOfflineMode(),
              ),
              loading: () =>
                  const ToggleSwitch(checked: false, onChanged: null),
              error: (_, _) =>
                  const ToggleSwitch(checked: false, onChanged: null),
            ),
          ],
        ),

        // Progress indicator during preload
        if (_isLoading) ...[
          const SizedBox(height: 16),
          ProgressBar(value: _progress * 100),
          const SizedBox(height: 8),
          Text(
            _progressMessage,
            style: theme.typography.caption?.copyWith(
              color: theme.resources.textFillColorSecondary,
            ),
          ),
        ],

        // Info when active
        ...configAsync.when(
          data: (config) => config.isEnabled
              ? [
                  const SizedBox(height: 16),
                  // Pending operations
                  Row(
                    children: [
                      Icon(FluentIcons.clock, size: 14, color: Colors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Operaciones pendientes: ',
                        style: theme.typography.caption,
                      ),
                      pendingOpsAsync.when(
                        data: (count) => Text(
                          '$count',
                          style: theme.typography.caption?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: count > 0 ? Colors.orange : Colors.green,
                          ),
                        ),
                        loading: () => const SizedBox(
                          width: 12,
                          height: 12,
                          child: ProgressRing(strokeWidth: 2),
                        ),
                        error: (_, _) => const Text('-'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Active duration
                  if (config.activeDuration != null)
                    Row(
                      children: [
                        Icon(
                          FluentIcons.timer,
                          size: 14,
                          color: theme.resources.textFillColorSecondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Activo hace: ${_formatDuration(config.activeDuration!)}',
                          style: theme.typography.caption,
                        ),
                      ],
                    ),
                  const SizedBox(height: 8),
                  // Last preload info
                  if (config.lastPreloadAt != null)
                    Row(
                      children: [
                        Icon(
                          config.preloadStatus == PreloadStatus.completed
                              ? FluentIcons.completed_solid
                              : FluentIcons.warning,
                          size: 14,
                          color: config.preloadStatus == PreloadStatus.completed
                              ? Colors.green
                              : Colors.orange,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Datos cargados: ${_formatDateTime(config.lastPreloadAt!)}',
                          style: theme.typography.caption,
                        ),
                      ],
                    ),
                ]
              : <Widget>[],
          loading: () => <Widget>[],
          error: (_, _) => <Widget>[],
        ),
      ],
    );
  }

  Future<void> _toggleOfflineMode() async {
    final configAsync = ref.read(offlineModeConfigProvider);
    final config = configAsync.maybeWhen(
      data: (c) => c,
      orElse: () => const OfflineModeConfig(),
    );

    if (config.isEnabled) {
      // Deactivate
      final confirm = await _showDeactivateDialog();
      if (confirm == true) {
        try {
          final service = ref.read(offlineModeServiceImplProvider);
          await service.deactivateOfflineMode();
          ref.invalidate(offlineModeConfigProvider);

          if (mounted) {
            ref.showInfoNotification(
              context,
              title: 'Modo offline desactivado',
              message: 'Volviendo al modo normal de operación',
            );
          }
        } catch (e) {
          if (mounted) {
            ref.showErrorNotification(context, title: 'Error de modo offline', message: '$e');
          }
        }
      }
    } else {
      // Activate with preload
      setState(() {
        _isLoading = true;
        _progress = 0;
        _progressMessage = 'Activando modo offline...';
      });

      try {
        final service = ref.read(offlineModeServiceImplProvider);
        final result = await service.activateOfflineMode(
          onProgress: (message, progress) {
            if (mounted) {
              setState(() {
                _progressMessage = message;
                _progress = progress;
              });
            }
          },
        );

        ref.invalidate(offlineModeConfigProvider);

        if (mounted) {
          if (result.success) {
            ref.showSuccessNotification(
              context,
              title: 'Modo offline activado',
              message:
                  '${result.productsLoaded} productos, ${result.partnersLoaded} clientes cargados',
            );
          } else {
            ref.showWarningNotification(
              context,
              title: 'Modo offline activado con errores',
              message:
                  '${result.productsLoaded} productos, ${result.partnersLoaded} clientes cargados',
            );
          }
        }
      } catch (e) {
        if (mounted) {
          ref.showErrorNotification(context, title: 'Error de modo offline', message: '$e');
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    }
  }

  Future<bool?> _showDeactivateDialog() {
    final pendingOpsAsync = ref.read(pendingOperationsCountProvider);

    return showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Desactivar modo offline'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Las operaciones pendientes se sincronizaran cuando haya conexion.',
            ),
            const SizedBox(height: 12),
            pendingOpsAsync.when(
              data: (count) => count > 0
                  ? InfoBar(
                      title: Text('$count operaciones pendientes'),
                      severity: InfoBarSeverity.warning,
                    )
                  : const SizedBox.shrink(),
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
  }

  String _formatDuration(Duration duration) {
    if (duration.inMinutes < 60) {
      return '${duration.inMinutes} min';
    } else if (duration.inHours < 24) {
      return '${duration.inHours}h ${duration.inMinutes % 60}min';
    } else {
      return '${duration.inDays}d ${duration.inHours % 24}h';
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 1) {
      return 'ahora';
    } else if (diff.inMinutes < 60) {
      return 'hace ${diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'hace ${diff.inHours}h';
    } else {
      return '${dateTime.day}/${dateTime.month} ${dateTime.hour}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
