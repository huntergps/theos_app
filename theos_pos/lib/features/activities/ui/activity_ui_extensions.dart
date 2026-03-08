import 'package:fluent_ui/fluent_ui.dart';

import 'package:theos_pos_core/theos_pos_core.dart' show ActivityPriority;

/// UI extensions for ActivityPriority (colors, icons)
/// These are presentation-layer concerns and should not be in the domain layer.
extension ActivityPriorityUI on ActivityPriority {
  Color get color {
    switch (this) {
      case ActivityPriority.overdue:
        return Colors.red;
      case ActivityPriority.today:
        return Colors.orange;
      case ActivityPriority.planned:
        return Colors.blue;
      case ActivityPriority.done:
        return Colors.green;
    }
  }

  Color get backgroundColor {
    switch (this) {
      case ActivityPriority.overdue:
        return Colors.red.withValues(alpha: 0.1);
      case ActivityPriority.today:
        return Colors.orange.withValues(alpha: 0.1);
      case ActivityPriority.planned:
        return Colors.blue.withValues(alpha: 0.1);
      case ActivityPriority.done:
        return Colors.green.withValues(alpha: 0.1);
    }
  }

  IconData get icon {
    switch (this) {
      case ActivityPriority.overdue:
        return FluentIcons.warning;
      case ActivityPriority.today:
        return FluentIcons.clock;
      case ActivityPriority.planned:
        return FluentIcons.calendar;
      case ActivityPriority.done:
        return FluentIcons.check_mark;
    }
  }

  String get label {
    switch (this) {
      case ActivityPriority.overdue:
        return 'Atrasada';
      case ActivityPriority.today:
        return 'Hoy';
      case ActivityPriority.planned:
        return 'Planificada';
      case ActivityPriority.done:
        return 'Completada';
    }
  }
}
