import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show CollectionSession;

// =============================================================================
// SESSION INFO CARD
// =============================================================================
class SessionInfoCard extends StatelessWidget {
  final CollectionSession session;
  final DateFormat dateFormat;

  const SessionInfoCard({
    super.key,
    required this.session,
    required this.dateFormat,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // First card: User information
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CompactInfoItem(
                    icon: FluentIcons.contact,
                    label: 'Usuario',
                    value: session.userName ?? '-',
                  ),
                  const SizedBox(height: 8),
                  _CompactInfoItem(
                    icon: FluentIcons.user_followed,
                    label: 'Supervisor',
                    value: session.supervisorName ?? '-',
                  ),
                  // const SizedBox(height: 8),
                  // _CompactInfoItem(
                  //   icon: FluentIcons.completed_solid,
                  //   label: 'Validacion Supervisor',
                  //   value: session.supervisorValidationDate != null
                  //       ? dateFormat.format(session.supervisorValidationDate!)
                  //       : '-',
                  // ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Second card: Date information
        Expanded(
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _CompactInfoItem(
                    icon: FluentIcons.calendar_agenda,
                    label: 'Inicio',
                    value: session.startAt != null
                        ? dateFormat.format(session.startAt!)
                        : '-',
                  ),
                  const SizedBox(height: 8),
                  _CompactInfoItem(
                    icon: FluentIcons.calendar_mirrored,
                    label: 'Cierre',
                    value: session.stopAt != null
                        ? dateFormat.format(session.stopAt!)
                        : '-',
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Compact info item widget for single-line display with icon
class _CompactInfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _CompactInfoItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: theme.accentColor.withValues(alpha: 0.7)),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: theme.typography.caption?.copyWith(
            color: theme.resources.textFillColorSecondary,
            fontWeight: FontWeight.normal,
          ),
        ),
        Text(
          value,
          style: theme.typography.body?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
