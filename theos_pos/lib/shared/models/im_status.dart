import 'package:fluent_ui/fluent_ui.dart';
import '../../core/constants/app_colors.dart';

/// User presence/IM status matching Odoo 19.0 implementation
/// Based on mail/static/src/core/common/im_status_dropdown.js
enum ImStatus {
  online,
  away,
  busy,
  offline;

  /// Get human-readable label matching Odoo 19.0
  String get label {
    switch (this) {
      case ImStatus.online:
        return 'En línea';
      case ImStatus.away:
        return 'Ausente';
      case ImStatus.busy:
        return 'No molestar';
      case ImStatus.offline:
        return 'Desconectado';
    }
  }

  /// Get icon matching Odoo 19.0
  /// Using FluentIcons instead of Material Icons
  IconData get icon {
    switch (this) {
      case ImStatus.online:
        return FluentIcons.status_circle_outer; // Green circle for online
      case ImStatus.away:
        return FluentIcons.status_circle_outer; // Yellow circle for away
      case ImStatus.busy:
        return FluentIcons
            .status_circle_outer; // Red circle with minus for busy
      case ImStatus.offline:
        return FluentIcons
            .status_circle_outer; // Gray circle outline for offline
    }
  }

  /// Get color matching Odoo 19.0 exactly
  /// Based on mail/static/src/core/common/im_status.xml
  Color get color {
    switch (this) {
      case ImStatus.online:
        return AppColors.success; // text-success green
      case ImStatus.away:
        return AppColors.warning; // o-yellow
      case ImStatus.busy:
        return AppColors.danger; // text-danger red
      case ImStatus.offline:
        return const Color(
          0xFF6C757D,
        ).withValues(alpha: 0.75); // text-700 opacity-75 gray
    }
  }

  /// Get subtitle/description for "Do Not Disturb"
  String? get description {
    if (this == ImStatus.busy) {
      return 'No recibirás notificaciones';
    }
    return null;
  }

  /// Parse from Odoo API string value
  static ImStatus fromString(String? value) {
    switch (value?.toLowerCase()) {
      case 'online':
        return ImStatus.online;
      case 'away':
        return ImStatus.away;
      case 'busy':
        return ImStatus.busy;
      case 'offline':
      default:
        return ImStatus.offline;
    }
  }

  /// Convert to Odoo API string value
  String toOdooString() {
    return name; // 'online', 'away', 'busy', 'offline'
  }
}
