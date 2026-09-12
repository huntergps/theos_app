import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show NotificationSeverity;

import '../../app/theme/orbi_theme.dart';

/// How serious a transient message is, and therefore how long it stays and
/// what it looks like.
///
/// Four levels, matching what `theos_pos` settled on
/// (`global_notification_service.dart`) rather than the three of
/// [NotificationSeverity]: the durable notification centre has no use for
/// "success", because a success never needs to be kept, but a transient
/// message very much does need to distinguish it from "info".
enum OrbiMessageSeverity { error, warning, success, info }

/// Bridges the durable notification vocabulary into the presentation one.
OrbiMessageSeverity orbiSeverityFor(NotificationSeverity severity) =>
    switch (severity) {
      NotificationSeverity.error => OrbiMessageSeverity.error,
      NotificationSeverity.attention => OrbiMessageSeverity.warning,
      NotificationSeverity.info => OrbiMessageSeverity.info,
    };

/// How long each severity stays on screen, in seconds, with **0 meaning "until
/// someone closes it"**.
///
/// 🔴 The default for [error] is 0, and that is a deliberate departure from
/// `theos_pos`, which gives errors ten seconds. Ten seconds is not enough time
/// to read a two-line explanation, decide it matters, find the copy button and
/// press it — and an error the owner is expected to copy and send is exactly
/// the message that must not evaporate while he is reaching for it. The other
/// three still expire on their own: a success that needed dismissing would be
/// a chore, not care.
///
/// It remains a choice, not a policy: the durations screen lets anyone set the
/// error back to a countdown if they prefer one.
final class MessageDurations {
  const MessageDurations({
    this.errorSeconds = 0,
    this.warningSeconds = 8,
    this.successSeconds = 3,
    this.infoSeconds = 4,
  });

  final int errorSeconds;
  final int warningSeconds;
  final int successSeconds;
  final int infoSeconds;

  /// The upper bound offered by the picker. Anything longer is indistinguish-
  /// able from "does not expire", which is what 0 is for.
  static const int maxSeconds = 60;

  int secondsFor(OrbiMessageSeverity severity) => switch (severity) {
    OrbiMessageSeverity.error => errorSeconds,
    OrbiMessageSeverity.warning => warningSeconds,
    OrbiMessageSeverity.success => successSeconds,
    OrbiMessageSeverity.info => infoSeconds,
  };

  /// `null` means "stays until dismissed".
  Duration? durationFor(OrbiMessageSeverity severity) {
    final seconds = secondsFor(severity);
    return seconds <= 0 ? null : Duration(seconds: seconds);
  }

  MessageDurations copyWithSeverity(OrbiMessageSeverity severity, int seconds) {
    final value = seconds.clamp(0, maxSeconds);
    return MessageDurations(
      errorSeconds: severity == OrbiMessageSeverity.error
          ? value
          : errorSeconds,
      warningSeconds: severity == OrbiMessageSeverity.warning
          ? value
          : warningSeconds,
      successSeconds: severity == OrbiMessageSeverity.success
          ? value
          : successSeconds,
      infoSeconds: severity == OrbiMessageSeverity.info ? value : infoSeconds,
    );
  }

  Map<String, dynamic> toJson() => {
    'error': errorSeconds,
    'warning': warningSeconds,
    'success': successSeconds,
    'info': infoSeconds,
  };

  /// Tolerant on purpose: a payload written before these existed, or one with
  /// a junk entry, falls back to the default for that entry rather than
  /// throwing away the whole preferences file.
  factory MessageDurations.fromJson(Object? json) {
    if (json is! Map) return const MessageDurations();
    int read(String key, int fallback) {
      final value = json[key];
      return value is int ? value.clamp(0, maxSeconds) : fallback;
    }

    const defaults = MessageDurations();
    return MessageDurations(
      errorSeconds: read('error', defaults.errorSeconds),
      warningSeconds: read('warning', defaults.warningSeconds),
      successSeconds: read('success', defaults.successSeconds),
      infoSeconds: read('info', defaults.infoSeconds),
    );
  }

  @override
  bool operator ==(Object other) =>
      other is MessageDurations &&
      other.errorSeconds == errorSeconds &&
      other.warningSeconds == warningSeconds &&
      other.successSeconds == successSeconds &&
      other.infoSeconds == infoSeconds;

  @override
  int get hashCode =>
      Object.hash(errorSeconds, warningSeconds, successSeconds, infoSeconds);
}

/// A message the person can read AND take away.
///
/// [clipboardText] is the whole thing — headline, explanation and the moment
/// it happened — because the point of the copy button is that what gets pasted
/// into a chat is enough for somebody else to act on. A summary would defeat
/// it.
final class CopyableMessage {
  const CopyableMessage({
    required this.title,
    required this.body,
    required this.severity,
    this.occurredAt,
  });

  final String title;
  final String body;
  final OrbiMessageSeverity severity;

  /// Injectable so tests are not at the mercy of the wall clock.
  final DateTime? occurredAt;

  /// Everything, in the order a person would write it themselves.
  ///
  /// The timestamp is not decoration: several of the failure messages end by
  /// asking the person to tell their administrator *when* it happened, and a
  /// copy button that dropped the one fact the message just asked for would be
  /// a small betrayal. It is a local wall-clock time, never an internal id.
  String get clipboardText {
    final when = occurredAt ?? DateTime.now();
    return '$title\n\n$body\n\nOrbi · ${_stamp(when)}';
  }

  static String _stamp(DateTime value) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(value.day)}/${two(value.month)}/${value.year} '
        '${two(value.hour)}:${two(value.minute)}';
  }
}

/// The palette for one severity, resolved against the active scheme.
({Color background, Color foreground, Color border, IconData icon})
orbiMessageTones(ColorScheme colors, OrbiMessageSeverity severity) =>
    switch (severity) {
      OrbiMessageSeverity.error => (
        background: colors.errorContainer,
        foreground: colors.onErrorContainer,
        border: colors.error,
        icon: Icons.error_outline,
      ),
      OrbiMessageSeverity.warning => (
        background: colors.secondaryContainer,
        foreground: colors.onSecondaryContainer,
        border: colors.secondary,
        icon: Icons.warning_amber_rounded,
      ),
      OrbiMessageSeverity.success => (
        background: colors.tertiaryContainer,
        foreground: colors.onTertiaryContainer,
        border: colors.tertiary,
        icon: Icons.check_circle_outline,
      ),
      OrbiMessageSeverity.info => (
        background: colors.surfaceContainerHighest,
        foreground: colors.onSurface,
        border: colors.outline,
        icon: Icons.info_outline,
      ),
    };

/// Puts [message] on the clipboard and confirms it, briefly.
///
/// Returns whether it made it, so a caller can react if the platform refuses.
/// The confirmation is deliberately its own short-lived message rather than a
/// silent success: copying is invisible, and an owner who is not sure it
/// worked will press the button again and paste twice.
Future<bool> copyOrbiMessage(
  BuildContext context,
  CopyableMessage message,
) async {
  try {
    await Clipboard.setData(ClipboardData(text: message.clipboardText));
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        const SnackBar(
          key: Key('copy-failed-confirmation'),
          content: Text('No se pudo copiar. Selecciona el texto y cópialo.'),
        ),
      );
    }
    return false;
  }
  if (context.mounted) {
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        key: Key('copy-confirmation'),
        duration: Duration(seconds: 1),
        content: Text('Mensaje copiado'),
      ),
    );
  }
  return true;
}

/// An inline message block: tinted, bordered, with the headline, the
/// explanation, and a button that takes the whole thing away.
///
/// 🔴 The copy button sits BELOW the text, not beside the headline.
/// `theos_pos` puts it in the title row next to the close button
/// (`copyable_info_bar.dart`), and at phone width that leaves a long headline
/// fighting two icon buttons for the same line — the title wraps to three
/// lines while a third of the row sits empty. Actions under the content is
/// also just what Material does.
class CopyableMessagePanel extends StatelessWidget {
  const CopyableMessagePanel({
    super.key,
    required this.message,
    this.onDismiss,
  });

  final CopyableMessage message;

  /// When non-null, an explicit close affordance is offered. Required for a
  /// message that never expires on its own.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tones = orbiMessageTones(theme.colorScheme, message.severity);
    return Semantics(
      liveRegion: true,
      container: true,
      label: '${message.title}. ${message.body}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tones.background,
          borderRadius: const BorderRadius.all(Radius.circular(8)),
          border: Border.all(color: tones.border.withValues(alpha: .48)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(OrbiTheme.space12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    child: Icon(tones.icon, size: 20, color: tones.foreground),
                  ),
                  const SizedBox(width: OrbiTheme.space12),
                  Expanded(
                    child: ExcludeSemantics(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            message.title,
                            style: theme.textTheme.titleSmall?.copyWith(
                              color: tones.foreground,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: OrbiTheme.space4),
                          // Selectable as well as copyable: someone who wants
                          // only one sentence should not have to take all of
                          // it.
                          SelectableText(
                            message.body,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: tones.foreground,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: OrbiTheme.space4),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    key: const Key('copy-message-button'),
                    onPressed: () => copyOrbiMessage(context, message),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Copiar'),
                    style: TextButton.styleFrom(
                      foregroundColor: tones.foreground,
                    ),
                  ),
                  if (onDismiss != null)
                    TextButton(
                      key: const Key('dismiss-message-button'),
                      onPressed: onDismiss,
                      style: TextButton.styleFrom(
                        foregroundColor: tones.foreground,
                      ),
                      child: const Text('Cerrar'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The floating counterpart, for messages that are not anchored to a form.
///
/// One entry point, four severities, the duration injected from settings and
/// overridable per call — the shape `theos_pos`'s
/// `global_notification_service.dart` arrived at, rebuilt on Material.
///
/// A severity configured as 0 seconds gets a snack bar with no timeout and an
/// explicit "Cerrar": it stays until someone deals with it.
void showCopyableMessage(
  BuildContext context,
  CopyableMessage message, {
  required MessageDurations durations,
  Duration? overrideDuration,
}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final theme = Theme.of(context);
  final tones = orbiMessageTones(theme.colorScheme, message.severity);
  final duration = overrideDuration ?? durations.durationFor(message.severity);
  messenger.showSnackBar(
    SnackBar(
      key: const Key('copyable-message-bar'),
      backgroundColor: tones.background,
      // Material requires *some* duration; a message that must not expire gets
      // one long enough that only the explicit "Cerrar" ends it.
      duration: duration ?? const Duration(days: 365),
      behavior: SnackBarBehavior.floating,
      content: Semantics(
        liveRegion: true,
        container: true,
        label: '${message.title}. ${message.body}',
        child: ExcludeSemantics(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(tones.icon, size: 20, color: tones.foreground),
                  const SizedBox(width: OrbiTheme.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          message.title,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: tones.foreground,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: OrbiTheme.space4),
                        Text(
                          message.body,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: tones.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton.icon(
                    key: const Key('copy-message-button'),
                    onPressed: () => copyOrbiMessage(context, message),
                    icon: const Icon(Icons.copy_all_outlined, size: 18),
                    label: const Text('Copiar'),
                    style: TextButton.styleFrom(
                      foregroundColor: tones.foreground,
                    ),
                  ),
                  TextButton(
                    key: const Key('dismiss-message-button'),
                    onPressed: messenger.hideCurrentSnackBar,
                    style: TextButton.styleFrom(
                      foregroundColor: tones.foreground,
                    ),
                    child: const Text('Cerrar'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
