import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../database/providers.dart';
import '../logger_service.dart';

/// Global notification service that provides copyable InfoBars throughout the app.
/// All error messages can be copied to clipboard for easier debugging.
///
/// Usage:
/// ```dart
/// // In a ConsumerWidget or ConsumerState:
/// ref.read(globalNotificationProvider).showError(
///   context,
///   title: 'Error',
///   message: 'Something went wrong',
/// );
/// ```
class GlobalNotificationService {
  final int _errorDuration;
  final int _warningDuration;
  final int _successDuration;
  final int _infoDuration;

  GlobalNotificationService({
    required int errorDuration,
    required int warningDuration,
    required int successDuration,
    required int infoDuration,
  })  : _errorDuration = errorDuration,
        _warningDuration = warningDuration,
        _successDuration = successDuration,
        _infoDuration = infoDuration;

  /// Show an error notification with copy-to-clipboard functionality
  void showError(
    BuildContext context, {
    required String title,
    required String message,
    int? durationSeconds,
  }) {
    final int duration =
        durationSeconds ?? _errorDuration;
    _showCopyable(
      context,
      title: title,
      message: message,
      severity: InfoBarSeverity.error,
      durationSeconds: duration,
    );
    logger.e('[Notification] Error: $title - $message');
  }

  /// Show a warning notification with copy-to-clipboard functionality
  void showWarning(
    BuildContext context, {
    required String title,
    required String message,
    int? durationSeconds,
  }) {
    final int duration =
        durationSeconds ?? _warningDuration;
    _showCopyable(
      context,
      title: title,
      message: message,
      severity: InfoBarSeverity.warning,
      durationSeconds: duration,
    );
    logger.w('[Notification] Warning: $title - $message');
  }

  /// Show a success notification with copy-to-clipboard functionality
  void showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    int? durationSeconds,
  }) {
    final int duration =
        durationSeconds ?? _successDuration;
    _showCopyable(
      context,
      title: title,
      message: message,
      severity: InfoBarSeverity.success,
      durationSeconds: duration,
    );
    logger.d('[Notification] Success: $title - $message');
  }

  /// Show an info notification with copy-to-clipboard functionality
  void showInfo(
    BuildContext context, {
    required String title,
    required String message,
    int? durationSeconds,
  }) {
    final int duration =
        durationSeconds ?? _infoDuration;
    _showCopyable(
      context,
      title: title,
      message: message,
      severity: InfoBarSeverity.info,
      durationSeconds: duration,
    );
    logger.i('[Notification] Info: $title - $message');
  }

  /// Show an exception notification with full stack trace (copyable)
  void showException(
    BuildContext context, {
    required String title,
    required Object error,
    StackTrace? stackTrace,
    int? durationSeconds,
  }) {
    final message = stackTrace != null
        ? '$error\n\nStack trace:\n$stackTrace'
        : '$error';

    final int duration =
        durationSeconds ?? _errorDuration;
    _showCopyable(
      context,
      title: title,
      message: message,
      severity: InfoBarSeverity.error,
      durationSeconds: duration,
    );
    logger.e('[Notification] Exception: $title', '$error');
  }

  /// Internal method to show a copyable InfoBar
  void _showCopyable(
    BuildContext context, {
    required String title,
    required String message,
    required InfoBarSeverity severity,
    required int durationSeconds,
  }) {
    switch (severity) {
      case InfoBarSeverity.error:
        CopyableInfoBar.showError(
          context,
          title: title,
          message: message,
          durationSeconds: durationSeconds,
        );
        break;
      case InfoBarSeverity.warning:
        CopyableInfoBar.showWarning(
          context,
          title: title,
          message: message,
          durationSeconds: durationSeconds,
        );
        break;
      case InfoBarSeverity.success:
        CopyableInfoBar.showSuccess(
          context,
          title: title,
          message: message,
          durationSeconds: durationSeconds,
        );
        break;
      case InfoBarSeverity.info:
        CopyableInfoBar.showInfo(
          context,
          title: title,
          message: message,
          durationSeconds: durationSeconds,
        );
        break;
    }
  }
}

/// Provider for the global notification service
final globalNotificationProvider = Provider<GlobalNotificationService>((ref) {
  return GlobalNotificationService(
    errorDuration: ref.read(errorNotificationDurationProvider),
    warningDuration: ref.read(warningNotificationDurationProvider),
    successDuration: ref.read(successNotificationDurationProvider),
    infoDuration: ref.read(infoNotificationDurationProvider),
  );
});

/// Extension methods for WidgetRef to simplify notification calls
extension NotificationRefExtension on WidgetRef {
  /// Show an error notification with copyable message
  void showErrorNotification(
    BuildContext context, {
    required String title,
    required String message,
    int? durationSeconds,
  }) {
    read(globalNotificationProvider).showError(
      context,
      title: title,
      message: message,
      durationSeconds: durationSeconds,
    );
  }

  /// Show a warning notification with copyable message
  void showWarningNotification(
    BuildContext context, {
    required String title,
    required String message,
    int? durationSeconds,
  }) {
    read(globalNotificationProvider).showWarning(
      context,
      title: title,
      message: message,
      durationSeconds: durationSeconds,
    );
  }

  /// Show a success notification with copyable message
  void showSuccessNotification(
    BuildContext context, {
    required String title,
    required String message,
    int? durationSeconds,
  }) {
    read(globalNotificationProvider).showSuccess(
      context,
      title: title,
      message: message,
      durationSeconds: durationSeconds,
    );
  }

  /// Show an info notification with copyable message
  void showInfoNotification(
    BuildContext context, {
    required String title,
    required String message,
    int? durationSeconds,
  }) {
    read(globalNotificationProvider).showInfo(
      context,
      title: title,
      message: message,
      durationSeconds: durationSeconds,
    );
  }

  /// Show an exception notification with full error details (copyable)
  void showExceptionNotification(
    BuildContext context, {
    required String title,
    required Object error,
    StackTrace? stackTrace,
    int? durationSeconds,
  }) {
    read(globalNotificationProvider).showException(
      context,
      title: title,
      error: error,
      stackTrace: stackTrace,
      durationSeconds: durationSeconds,
    );
  }
}
