import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/providers.dart';
import '../../../../core/database/repositories/repository_providers.dart';
import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Widget to display failed sync sessions with retry button
///
/// Shows an InfoBar warning when there are sessions that couldn't
/// be synced after max retries, with a button to retry sync.
class FailedSyncSessionsCard extends ConsumerWidget {
  const FailedSyncSessionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final repo = ref.watch(collectionRepositoryProvider);
    final maxRetries = ref.watch(maxSyncRetriesProvider);

    if (repo == null) return const SizedBox.shrink();

    return FutureBuilder<List<CollectionSession>>(
      future: repo.getFailedSyncSessions(maxRetries: maxRetries),
      builder: (context, snapshot) {
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const SizedBox.shrink();
        }

        final failedSessions = snapshot.data!;

        return InfoBar(
          title: const Text('Sesiones no sincronizadas'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${failedSessions.length} sesion(es) no se pudieron sincronizar con el servidor después de $maxRetries intentos.',
              ),
              const SizedBox(height: 8),
              for (final session in failedSessions) ...[
                Text(
                  '• ${session.name} (UUID: ${session.sessionUuid?.substring(0, 8)}...)',
                  style: theme.typography.caption,
                ),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _retrySync(context, ref, repo),
                child: const Text('Reintentar sincronización'),
              ),
            ],
          ),
          severity: InfoBarSeverity.warning,
        );
      },
    );
  }

  Future<void> _retrySync(
    BuildContext context,
    WidgetRef ref,
    dynamic repo,
  ) async {
    try {
      CopyableInfoBar.showInfo(
        context,
        title: 'Sincronizando...',
        message: 'Reintentando sincronizar sesiones pendientes',
        durationSeconds: 2,
      );

      final syncedCount = await repo.retryUnsyncedSessions(force: true);

      if (context.mounted) {
        ref.invalidate(collectionConfigsProvider);

        if (syncedCount > 0) {
          CopyableInfoBar.showSuccess(
            context,
            title: 'Sincronización completada',
            message: 'Se sincronizaron $syncedCount sesion(es) exitosamente',
          );
        } else {
          CopyableInfoBar.showError(
            context,
            title: 'Sincronización completada',
            message: 'No se pudieron sincronizar las sesiones. Verifica la conexión con el servidor.',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        final errorDuration = ref.read(errorNotificationDurationProvider);
        CopyableInfoBar.showError(
          context,
          title: 'Error de sincronización',
          message: 'No se pudo sincronizar la sesion. Intente nuevamente.',
          durationSeconds: errorDuration,
        );
      }
    }
  }
}
