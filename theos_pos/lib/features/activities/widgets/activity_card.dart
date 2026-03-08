import 'package:fluent_ui/fluent_ui.dart';

import 'package:theos_pos_core/theos_pos_core.dart' show MailActivity;
import '../ui/activity_ui_extensions.dart';
import '../../../shared/utils/formatting_utils.dart';
import 'reschedule_button.dart';

/// Card para mostrar actividades en la vista mobile
class ActivityCard extends StatelessWidget {
  final MailActivity activity;
  final VoidCallback onRescheduleToday;
  final VoidCallback onRescheduleTomorrow;
  final VoidCallback onRescheduleNextWeek;
  final VoidCallback onMarkAsDone;
  final VoidCallback onCancel;

  const ActivityCard({
    super.key,
    required this.activity,
    required this.onRescheduleToday,
    required this.onRescheduleTomorrow,
    required this.onRescheduleNextWeek,
    required this.onMarkAsDone,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final stateColor = activity.priority.color;
    final stateIcon = activity.priority.icon;

    return Card(
      margin: const EdgeInsets.only(bottom: 12.0),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(theme, stateColor, stateIcon),
          if (activity.note != null && activity.note!.isNotEmpty)
            _buildNote(theme),
          const SizedBox(height: 12),
          _buildDetails(theme, stateColor),
          const SizedBox(height: 16),
          _buildActions(),
        ],
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme, Color stateColor, IconData stateIcon) {
    return Row(
      children: [
        Container(
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: activity.priority.backgroundColor,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(stateIcon, size: 16, color: stateColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                activity.displayTitle,
                style: theme.typography.bodyStrong,
              ),
              if (activity.resName != null) ...[
                const SizedBox(height: 4),
                Text(
                  activity.resName!,
                  style: theme.typography.caption,
                ),
              ],
            ],
          ),
        ),
        _buildStateBadge(theme, stateColor),
      ],
    );
  }

  Widget _buildStateBadge(FluentThemeData theme, Color stateColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: activity.priority.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: stateColor.withValues(alpha: 0.3)),
      ),
      child: Text(
        activity.priority.label,
        style: TextStyle(
          color: stateColor,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildNote(FluentThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 12),
        Text(
          activity.note!.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
          style: theme.typography.body,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildDetails(FluentThemeData theme, Color stateColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(FluentIcons.calendar, size: 14),
            const SizedBox(width: 6),
            Text(
              FormattingUtils.formatRelativeDate(activity.dateDeadline),
              style: TextStyle(
                fontSize: 12,
                color: stateColor,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.grey[20],
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                activity.resModel.split('.').last,
                style: TextStyle(fontSize: 11, color: Colors.grey[100]),
              ),
            ),
          ],
        ),
        if (activity.userName != null) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(FluentIcons.contact, size: 14, color: Colors.grey[100]),
              const SizedBox(width: 6),
              Text(activity.userName!, style: theme.typography.caption),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        RescheduleButton(
          onRescheduleToday: onRescheduleToday,
          onRescheduleTomorrow: onRescheduleTomorrow,
          onRescheduleNextWeek: onRescheduleNextWeek,
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: FluentIcons.check_mark,
          tooltip: 'Marcar como listo',
          color: Colors.green,
          onPressed: onMarkAsDone,
        ),
        const SizedBox(width: 8),
        _buildActionButton(
          icon: FluentIcons.clear,
          tooltip: 'Cancelar actividad',
          color: Colors.red,
          onPressed: onCancel,
        ),
      ],
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String tooltip,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        icon: Icon(icon, size: 16),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.isHovered) {
              return color.withValues(alpha: 0.1);
            }
            return Colors.transparent;
          }),
          foregroundColor: WidgetStateProperty.all(color),
        ),
        onPressed: onPressed,
      ),
    );
  }
}
