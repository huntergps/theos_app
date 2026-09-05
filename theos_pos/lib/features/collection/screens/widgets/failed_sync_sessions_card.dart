import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/providers.dart';
import '../../../../core/database/repositories/repository_providers.dart';
import '../../../../shared/utils/error_utils.dart';
import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

/// Busca la última operación en dead-letter (agotó reintentos) de la cola
/// offline para una sesión específica, para mostrarle al supervisor el
/// motivo real del fallo en vez de solo el nombre/UUID de la sesión.
Future<OfflineOperation?> _lastFailureFor(WidgetRef ref, int sessionId) async {
  final queue = ref.read(offlineQueueDataSourceProvider);
  if (queue == null) return null;
  try {
    final deadLetter = await queue.getDeadLetterOperations();
    final matches = deadLetter.where(
      (op) => op.model == 'collection.session' && op.recordId == sessionId,
    );
    return matches.isEmpty ? null : matches.first;
  } catch (_) {
    return null;
  }
}

// ---------------------------------------------------------------------------
// Provider reactivo: se invalida después de cada reintento para refrescar
// automáticamente la lista sin necesidad de navegar fuera y volver.
// ---------------------------------------------------------------------------
final _failedSessionsProvider =
    FutureProvider.autoDispose<List<CollectionSession>>((ref) async {
      final repo = ref.watch(collectionRepositoryProvider);
      final maxRetries = ref.watch(maxSyncRetriesProvider);
      if (repo == null) return [];
      return repo.getFailedSyncSessions(maxRetries: maxRetries);
    });

/// Widget que muestra las sesiones que no se pudieron sincronizar y ofrece
/// un botón para reintentar.
///
/// Se actualiza automáticamente después de cada reintento gracias a
/// [_failedSessionsProvider] — ya no depende de [FutureBuilder]
/// sin mecanismo de refresco.
class FailedSyncSessionsCard extends ConsumerWidget {
  const FailedSyncSessionsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final sessionsAsync = ref.watch(_failedSessionsProvider);

    return sessionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (err, st) => const SizedBox.shrink(),
      data: (failedSessions) {
        if (failedSessions.isEmpty) return const SizedBox.shrink();

        final maxRetries = ref.watch(maxSyncRetriesProvider);

        return InfoBar(
          title: const Text('Sesiones no sincronizadas'),
          content: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${failedSessions.length} sesión(es) no se pudieron sincronizar '
                'con el servidor después de $maxRetries intentos.',
              ),
              const SizedBox(height: 8),
              for (final session in failedSessions) ...[
                _FailedSessionTile(session: session, theme: theme),
              ],
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => _retrySync(context, ref),
                child: const Text('Reintentar sincronización'),
              ),
            ],
          ),
          severity: InfoBarSeverity.warning,
        );
      },
    );
  }

  Future<void> _retrySync(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(collectionRepositoryProvider);
    if (repo == null) return;

    try {
      CopyableInfoBar.showInfo(
        context,
        title: 'Sincronizando...',
        message: 'Reintentando sincronizar sesiones pendientes',
        durationSeconds: 2,
      );

      final syncedCount = await repo.retryUnsyncedSessions(force: true);

      if (context.mounted) {
        // Invalidar para refrescar la lista inmediatamente
        ref.invalidate(_failedSessionsProvider);
        ref.invalidate(collectionConfigsProvider);

        if (syncedCount > 0) {
          CopyableInfoBar.showSuccess(
            context,
            title: 'Sincronización completada',
            message: 'Se sincronizaron $syncedCount sesión(es) exitosamente',
          );
        } else {
          CopyableInfoBar.showError(
            context,
            title: 'Sin cambios',
            message:
                'No se pudieron sincronizar las sesiones. '
                'Verifica la conexión con el servidor.',
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        final errorDuration = ref.read(errorNotificationDurationProvider);
        CopyableInfoBar.showError(
          context,
          title: 'Error de sincronización',
          message: 'No se pudo sincronizar la sesión. Intenta nuevamente.',
          durationSeconds: errorDuration,
        );
      }
    }
  }
}

/// Fila con el nombre de la sesión fallida, el motivo del último error
/// (resuelto desde la cola offline / dead-letter) y un botón para copiar
/// el detalle técnico completo. El UUID ya no se muestra en línea — pasa a
/// un tooltip para no saturar la vista del supervisor.
class _FailedSessionTile extends ConsumerWidget {
  final CollectionSession session;
  final FluentThemeData theme;

  const _FailedSessionTile({required this.session, required this.theme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: FutureBuilder<OfflineOperation?>(
        future: _lastFailureFor(ref, session.id),
        builder: (context, snapshot) {
          final failure = snapshot.data;
          final reason = failure?.lastError != null
              ? friendlyErrorMessage(failure!.lastError!)
              : 'No se encontró el detalle del error (agotó los reintentos).';

          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Tooltip(
                  message: session.sessionUuid != null
                      ? 'UUID: ${session.sessionUuid}'
                      : 'Sin UUID local asignado',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• ${session.name}',
                        style: theme.typography.caption,
                      ),
                      Text(
                        reason,
                        style: theme.typography.caption?.copyWith(
                          color: theme.resources.textFillColorSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Tooltip(
                message: 'Copiar detalle técnico',
                child: IconButton(
                  icon: const Icon(FluentIcons.copy, size: 12),
                  onPressed: () => _copyTechnicalDetail(context, failure),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  void _copyTechnicalDetail(BuildContext context, OfflineOperation? failure) {
    final detail = StringBuffer()
      ..writeln('Sesión: ${session.name}')
      ..writeln('UUID local: ${session.sessionUuid ?? "N/D"}')
      ..writeln('Reintentos de sesión: ${session.syncRetryCount}');

    if (failure != null) {
      detail
        ..writeln(
          'Operación en cola: ${failure.model} (record ${failure.recordId})',
        )
        ..writeln('Reintentos de la operación: ${failure.retryCount}')
        ..writeln('Último error técnico: ${failure.lastError ?? "N/D"}');
    } else {
      detail.writeln(
        'No se encontró una operación asociada en la cola offline.',
      );
    }

    Clipboard.setData(ClipboardData(text: detail.toString()));
    CopyableInfoBar.showInfo(
      context,
      title: 'Copiado',
      message: 'Detalle técnico copiado al portapapeles',
      durationSeconds: 2,
    );
  }
}
