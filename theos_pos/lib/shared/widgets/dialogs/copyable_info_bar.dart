import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

/// InfoBar wrapper with copy-to-clipboard button and configurable duration
class CopyableInfoBar {
  /// Show an error InfoBar with copy button
  static void showError(
    BuildContext context, {
    required String title,
    required String message,
    int durationSeconds = 10,
  }) {
    _show(
      context,
      title: title,
      message: message,
      severity: InfoBarSeverity.error,
      durationSeconds: durationSeconds,
    );
  }

  /// Show a warning InfoBar with copy button
  static void showWarning(
    BuildContext context, {
    required String title,
    required String message,
    int durationSeconds = 5,
    Duration? duration,
    Widget? action,
  }) {
    _show(
      context,
      title: title,
      message: message,
      severity: InfoBarSeverity.warning,
      durationSeconds: duration != null ? duration.inSeconds : durationSeconds,
      action: action,
    );
  }

  /// Show a success InfoBar with copy button
  static void showSuccess(
    BuildContext context, {
    required String title,
    required String message,
    int durationSeconds = 3,
  }) {
    _show(
      context,
      title: title,
      message: message,
      severity: InfoBarSeverity.success,
      durationSeconds: durationSeconds,
    );
  }

  /// Show an info InfoBar with copy button
  static void showInfo(
    BuildContext context, {
    required String title,
    required String message,
    int durationSeconds = 3,
  }) {
    _show(
      context,
      title: title,
      message: message,
      severity: InfoBarSeverity.info,
      durationSeconds: durationSeconds,
    );
  }

  static void _show(
    BuildContext context, {
    required String title,
    required String message,
    required InfoBarSeverity severity,
    required int durationSeconds,
    Widget? action,
  }) {
    displayInfoBar(
      context,
      duration: Duration(seconds: durationSeconds),
      builder: (context, close) {
        return InfoBar(
          title: Row(
            children: [
              Expanded(child: Text(title)),
              // Copy button
              Tooltip(
                message: 'Copiar mensaje al portapapeles',
                child: IconButton(
                  icon: const Icon(FluentIcons.copy, size: 14),
                  onPressed: () {
                    final fullMessage = '$title\n$message';
                    Clipboard.setData(ClipboardData(text: fullMessage));

                    // Show confirmation
                    displayInfoBar(
                      context,
                      duration: const Duration(seconds: 1),
                      builder: (ctx, closeConfirm) {
                        return const InfoBar(
                          title: Text('Copiado'),
                          content: Text('Mensaje copiado al portapapeles'),
                          severity: InfoBarSeverity.success,
                        );
                      },
                    );
                  },
                ),
              ),
              // Close button
              IconButton(
                icon: const Icon(FluentIcons.chrome_close, size: 12),
                onPressed: close,
              ),
            ],
          ),
          content: SelectableText(
            message,
            style: const TextStyle(fontSize: 13),
          ),
          action: action,
          severity: severity,
          isLong: message.length > 100,
        );
      },
    );
  }
}
