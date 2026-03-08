import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/services/config_service.dart';
import '../../../../shared/widgets/common/chip_is_local.dart';

import '../../../../shared/utils/formatting_utils.dart';
import '../state_chip.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Card widget displaying a collection point configuration
///
/// Shows:
/// - Config name and code
/// - Active session info (if any)
/// - Local sync status indicator
/// - Action buttons (Open/Continue session)
class CollectionConfigCard extends ConsumerWidget {
  final CollectionConfig config;
  final VoidCallback onOpenSession;
  final VoidCallback onContinueSession;
  final bool isLocalOnly;
  final CollectionSession? localSession;
  final Future<bool> Function()? onSyncSession;

  const CollectionConfigCard({
    super.key,
    required this.config,
    required this.onOpenSession,
    required this.onContinueSession,
    this.isLocalOnly = false,
    this.localSession,
    this.onSyncSession,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final appConfig = ref.watch(configServiceProvider);

    final hasActiveSession =
        config.currentSessionId != null || localSession != null;
    final hasRescueSessions = config.numberOfRescueSession > 0;
    final dateTimeFormat = _buildDateTimeFormat(appConfig.dateFormat);
    final dateFormat = DateFormat(dateTimeFormat, 'es');

    final sessionName =
        localSession?.name ?? config.currentSessionName ?? 'Sin nombre';
    final sessionState =
        localSession?.state.toString().split('.').last ??
        config.currentSessionState;
    final sessionStateDisplay = localSession != null
        ? getStateDisplay(localSession!.state)
        : (config.currentSessionStateDisplay ??
              config.currentSessionState ??
              'Desconocido');
    final sessionUserName =
        localSession?.userName ??
        config.currentSessionUserName ??
        'Desconocido';

    return SizedBox(
      width: 360,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with name and state badge
              Row(
                children: [
                  Icon(
                    FluentIcons.money,
                    color: hasActiveSession
                        ? Colors.green
                        : theme.resources.textFillColorSecondary,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(config.name, style: theme.typography.subtitle),
                        Text(
                          config.code,
                          style: theme.typography.caption?.copyWith(
                            color: theme.resources.textFillColorSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (hasActiveSession)
                    StateChip(state: sessionState ?? 'opened'),
                ],
              ),

              // Active Session Info
              if (hasActiveSession) ...[
                const SizedBox(height: 16),

                // Local-only indicator
                if (isLocalOnly && onSyncSession != null) ...[
                  SyncPendingChip(
                    onSync: onSyncSession!,
                    label: 'Pendiente de sincronizar',
                    syncingLabel: 'Sincronizando sesión...',
                  ),
                ],

                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.accentColor
                        .defaultBrushFor(theme.brightness)
                        .withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: theme.accentColor
                          .defaultBrushFor(theme.brightness)
                          .withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SessionInfoRow(
                        label: 'Sesión',
                        value: sessionName,
                        icon: FluentIcons.clipboard_list,
                        isHighlighted: true,
                      ),
                      const SizedBox(height: 8),
                      SessionInfoRow(
                        label: 'Estado',
                        value: sessionStateDisplay,
                        icon: FluentIcons.status_circle_checkmark,
                      ),
                      const SizedBox(height: 8),
                      SessionInfoRow(
                        label: 'Abierto por',
                        value: sessionUserName,
                        icon: FluentIcons.contact,
                      ),
                    ],
                  ),
                ),
              ],

              // Rescue Sessions Alert
              if (hasRescueSessions) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Colors.orange.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(FluentIcons.warning, size: 16, color: Colors.orange),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          config.numberOfRescueSession == 1
                              ? '1 sesion de rescate pendiente'
                              : '${config.numberOfRescueSession} sesiones de rescate pendientes',
                          style: theme.typography.body?.copyWith(
                            color: Colors.orange,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // Last session info (only when no active session)
              if (!hasActiveSession) ...[
                const SizedBox(height: 12),
                if (config.lastSessionClosingDate != null)
                  Row(
                    children: [
                      const Icon(FluentIcons.calendar, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'Ultimo cierre: ${dateFormat.format(config.lastSessionClosingDate!)}',
                        style: theme.typography.caption,
                      ),
                    ],
                  ),
                if (config.lastSessionClosingCash > 0) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(FluentIcons.money, size: 14),
                      const SizedBox(width: 8),
                      Text(
                        'Ultimo saldo: ${config.lastSessionClosingCash.toCurrency()}',
                        style: theme.typography.caption,
                      ),
                    ],
                  ),
                ],
              ],

              const SizedBox(height: 16),

              // Action Button
              SizedBox(
                width: double.infinity,
                child: hasActiveSession
                    ? FilledButton(
                        onPressed: onContinueSession,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(FluentIcons.play, size: 14),
                            const SizedBox(width: 8),
                            const Text('Continuar Sesion'),
                          ],
                        ),
                      )
                    : Button(
                        onPressed: onOpenSession,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(FluentIcons.add, size: 14),
                            const SizedBox(width: 8),
                            const Text('Nueva Sesion'),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildDateTimeFormat(String baseFormat) {
    if (baseFormat.contains('H') ||
        baseFormat.contains('h') ||
        (baseFormat.contains('m') && baseFormat.contains('a'))) {
      return baseFormat;
    }

    if (baseFormat == 'dd/MM/yyyy') {
      return 'dd/MM/yyyy HH:mm';
    } else if (baseFormat == 'MM/dd/yyyy') {
      return 'MM/dd/yyyy h:mm a';
    } else if (baseFormat == 'yyyy-MM-dd') {
      return 'yyyy-MM-dd HH:mm';
    } else if (baseFormat == 'd MMM, yyyy') {
      return 'd MMM, yyyy h:mm a';
    }

    return '$baseFormat HH:mm';
  }
}

/// Row widget displaying a session info label and value
class SessionInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final bool isHighlighted;

  const SessionInfoRow({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.isHighlighted = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: isHighlighted ? theme.accentColor : null),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.typography.body?.copyWith(
            color: theme.resources.textFillColorSecondary,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: isHighlighted
                ? theme.typography.bodyStrong?.copyWith(
                    color: theme.accentColor,
                  )
                : theme.typography.body,
          ),
        ),
      ],
    );
  }
}

/// Convert SessionState enum to display string
String getStateDisplay(SessionState state) {
  switch (state) {
    case SessionState.openingControl:
      return 'Control de Apertura';
    case SessionState.opened:
      return 'Abierta';
    case SessionState.closingControl:
      return 'Control de Cierre';
    case SessionState.closed:
      return 'Cerrada';
  }
}
