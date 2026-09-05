import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

import '../../../../core/constants/app_colors.dart';

/// Badge that displays credit status with appropriate styling
///
/// Shows a compact badge with icon and text indicating the client's
/// credit status (OK, warning, exceeded, overdue, no limit).
///
/// Usage:
/// ```dart
/// CreditStatusBadge(status: client.creditStatus)
/// CreditStatusBadge.fromClient(client)
/// ```
class CreditStatusBadge extends StatelessWidget {
  final CreditStatus status;
  final bool showLabel;
  final bool compact;

  const CreditStatusBadge({
    super.key,
    required this.status,
    this.showLabel = true,
    this.compact = false,
  });

  /// Create badge from Client model
  factory CreditStatusBadge.fromClient(
    Client client, {
    bool showLabel = true,
    bool compact = false,
  }) {
    return CreditStatusBadge(
      status: client.creditStatus,
      showLabel: showLabel,
      compact: compact,
    );
  }

  @override
  Widget build(BuildContext context) {
    final config = _getStatusConfig(status);

    if (compact) {
      return Tooltip(
        message: config.label,
        child: Icon(config.icon, color: config.color, size: 16),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: config.backgroundColor,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: config.color.withAlpha(128)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(config.icon, color: config.color, size: 14),
          if (showLabel) ...[
            const SizedBox(width: 4),
            Text(
              config.label,
              style: TextStyle(
                color: config.color,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }

  _StatusConfig _getStatusConfig(CreditStatus status) {
    switch (status) {
      case CreditStatus.ok:
        return _StatusConfig(
          icon: FluentIcons.check_mark,
          color: AppColors.success,
          backgroundColor: AppColors.success.withAlpha(25),
          label: 'OK',
        );
      case CreditStatus.warning:
        return _StatusConfig(
          icon: FluentIcons.warning,
          color: AppColors.warning,
          backgroundColor: AppColors.warning.withAlpha(25),
          label: 'Advertencia',
        );
      case CreditStatus.exceeded:
        return _StatusConfig(
          icon: FluentIcons.error_badge,
          color: AppColors.danger,
          backgroundColor: AppColors.danger.withAlpha(25),
          label: 'Excedido',
        );
      case CreditStatus.overdueDebt:
        return _StatusConfig(
          icon: FluentIcons.clock,
          color: AppColors.danger,
          backgroundColor: AppColors.danger.withAlpha(25),
          label: 'Mora',
        );
      case CreditStatus.noLimit:
        return _StatusConfig(
          icon: FluentIcons.remove,
          color: Colors.grey,
          backgroundColor: Colors.grey.withAlpha(25),
          label: 'Sin límite',
        );
    }
  }
}

class _StatusConfig {
  final IconData icon;
  final Color color;
  final Color backgroundColor;
  final String label;

  const _StatusConfig({
    required this.icon,
    required this.color,
    required this.backgroundColor,
    required this.label,
  });
}
