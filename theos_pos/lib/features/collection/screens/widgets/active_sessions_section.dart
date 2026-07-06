import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show CollectionSession, SessionState;

import '../../../../core/constants/app_colors.dart';
import '../../../../core/database/providers.dart';
import '../../../../shared/providers/menu_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/utils/error_utils.dart';
import '../../../../shared/utils/formatting_utils.dart';
import '../../../../shared/widgets/common/theos_info_bars.dart';
import '../state_chip.dart';

/// Section shown in the supervisor dashboard listing all non-closed sessions.
///
/// Only renders when the current user has the
/// `l10n_ec_collection_box.group_collection_manager` group (or admin).
/// Visibility is decided via the same [MenuItemDefinition.hasAccess] logic
/// used by the navigation menu.
class ActiveSessionsSection extends ConsumerWidget {
  const ActiveSessionsSection({super.key});

  static const _managerGroup = 'l10n_ec_collection_box.group_collection_manager';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(userProvider);
    final permissions = user?.permissions ?? [];

    // Only visible to managers / admins
    final isManager =
        permissions.contains(_managerGroup) ||
        adminGroups.any(permissions.contains);

    if (!isManager) return const SizedBox.shrink();

    final sessionsAsync = ref.watch(activeSessionsProvider);
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(FluentIcons.people, size: 16, color: theme.accentColor),
            const SizedBox(width: 8),
            Text('Sesiones Activas', style: theme.typography.subtitle),
          ],
        ),
        const SizedBox(height: 12),
        sessionsAsync.when(
          data: (sessions) {
            if (sessions.isEmpty) {
              return TheosInfoBars.info(
                title: 'Sin sesiones activas',
                message: 'No hay cajeros con sesiones abiertas en este momento.',
              );
            }

            return Column(
              children: sessions
                  .map((s) => _ActiveSessionCard(session: s))
                  .toList(),
            );
          },
          loading: () => const Center(child: ProgressRing()),
          error: (err, _) => TheosInfoBars.error(
            title: 'Error al cargar sesiones',
            message: friendlyErrorMessage(err),
          ),
        ),
      ],
    );
  }
}

/// Card showing a single active session.
class _ActiveSessionCard extends ConsumerWidget {
  final CollectionSession session;

  const _ActiveSessionCard({required this.session});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final startTime = session.startAt;
    final timeLabel = startTime != null
        ? DateFormat('dd/MM/yyyy HH:mm', 'es').format(startTime.toLocal())
        : 'Desconocida';

    final stateCode = _stateCode(session.state);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: HoverButton(
        onPressed: () => context.go('/collection/session/${session.id}'),
        builder: (ctx, states) {
          final hovered = states.isHovered;
          final hasMismatch = session.hasCashDifference;

          return AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            decoration: BoxDecoration(
              color: hovered
                  ? theme.resources.subtleFillColorSecondary
                  : theme.resources.cardBackgroundFillColorDefault,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: hasMismatch
                    ? AppColors.danger.withValues(alpha: 0.6)
                    : hovered
                        ? theme.accentColor.defaultBrushFor(theme.brightness)
                        : theme.resources.cardStrokeColorDefault,
                width: hasMismatch ? 1.5 : 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  // State indicator dot
                  _StateDot(state: session.state),
                  const SizedBox(width: 12),

                  // Session name + config
                  Expanded(
                    flex: 3,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          session.name,
                          style: theme.typography.bodyStrong,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (session.configName != null)
                          Text(
                            session.configName!,
                            style: theme.typography.caption?.copyWith(
                              color: theme.resources.textFillColorSecondary,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),

                  // Cajero name
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Icon(
                          FluentIcons.contact,
                          size: 14,
                          color: theme.resources.textFillColorSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            session.userName ?? 'Sin asignar',
                            style: theme.typography.body,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Open time
                  Expanded(
                    flex: 3,
                    child: Row(
                      children: [
                        Icon(
                          FluentIcons.calendar,
                          size: 14,
                          color: theme.resources.textFillColorSecondary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            timeLabel,
                            style: theme.typography.caption,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Descuadre de caja (si aplica)
                  if (hasMismatch) ...[
                    _CashMismatchBadge(difference: session.cashRegisterDifference),
                    const SizedBox(width: 8),
                  ],

                  // State chip
                  StateChip(state: stateCode),
                  const SizedBox(width: 8),

                  // Chevron hint
                  Icon(
                    FluentIcons.chevron_right,
                    size: 14,
                    color: theme.resources.textFillColorSecondary,
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  String _stateCode(SessionState state) {
    switch (state) {
      case SessionState.openingControl:
        return 'opening_control';
      case SessionState.opened:
        return 'opened';
      case SessionState.closingControl:
        return 'closing_control';
      case SessionState.closed:
        return 'closed';
    }
  }
}

/// Small coloured dot that visually indicates the session state.
class _StateDot extends StatelessWidget {
  final SessionState state;

  const _StateDot({required this.state});

  @override
  Widget build(BuildContext context) {
    final color = switch (state) {
      SessionState.opened => const Color(0xFF107C10),          // green
      SessionState.openingControl => const Color(0xFFCA5010),  // orange
      SessionState.closingControl => const Color(0xFF0078D4),  // blue
      SessionState.closed => const Color(0xFF767676),           // grey
    };

    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
    );
  }
}

/// Badge de alerta mostrado cuando la sesión tiene descuadre de caja
/// (diferencia entre el efectivo contado y el esperado).
class _CashMismatchBadge extends StatelessWidget {
  final double difference;

  const _CashMismatchBadge({required this.difference});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: 'Descuadre de caja: ${difference.toCurrency()}',
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.4)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(FluentIcons.warning, size: 10, color: AppColors.danger),
            const SizedBox(width: 4),
            Text(
              'Descuadre',
              style: TextStyle(
                fontSize: 10,
                color: AppColors.danger,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
