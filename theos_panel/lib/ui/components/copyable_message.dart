import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
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

/// The palette for one severity, resolved against the active Fluent theme.
///
/// Foreground is deliberately the SAME default text color for every
/// severity — the same choice Fluent's own `InfoBar` makes
/// (`InfoBarThemeData.standard`): only the background tint, the border and
/// the icon carry the severity's color.
///
/// 🔴 Both halves of that pair are translucent scrims in `theme.resources`,
/// not opaque colors — `systemFillColorAttentionBackground` in particular is
/// a faint ~5%-alpha white in dark mode, and `textFillColorPrimary` itself
/// carries alpha too. Fluent expects them composited over Mica, the way
/// `InfoBar` does; handed out as-is, this panel's actual on-screen color
/// would depend on whatever happens to sit behind it, which this function
/// cannot see, and contrast is meaningless to compute against a color that
/// is not fully painted yet (comparing raw RGB, as [Color.computeLuminance]
/// does, ignores alpha entirely). [Color.alphaBlend] flattens the background
/// tint against [FluentThemeData.micaBackgroundColor] — the one resource
/// that actually is opaque — and then flattens the text color against THAT,
/// so both halves returned here are fully opaque, paint the same regardless
/// of what is behind the panel, and are the colors contrast is measured
/// against.
({Color background, Color foreground, Color border, IconData icon})
orbiMessageTones(FluentThemeData theme, OrbiMessageSeverity severity) {
  final resources = theme.resources;
  Color opaqueBackground(Color tint) =>
      Color.alphaBlend(tint, theme.micaBackgroundColor);
  Color opaqueForeground(Color background) =>
      Color.alphaBlend(resources.textFillColorPrimary, background);

  final tint = switch (severity) {
    OrbiMessageSeverity.error => resources.systemFillColorCriticalBackground,
    OrbiMessageSeverity.warning => resources.systemFillColorCautionBackground,
    OrbiMessageSeverity.success => resources.systemFillColorSuccessBackground,
    OrbiMessageSeverity.info => resources.systemFillColorAttentionBackground,
  };
  final background = opaqueBackground(tint);
  return (
    background: background,
    foreground: opaqueForeground(background),
    border: switch (severity) {
      OrbiMessageSeverity.error => resources.systemFillColorCritical,
      OrbiMessageSeverity.warning => resources.systemFillColorCaution,
      OrbiMessageSeverity.success => resources.systemFillColorSuccess,
      OrbiMessageSeverity.info => theme.accentColor.normal,
    },
    icon: switch (severity) {
      OrbiMessageSeverity.error => FluentIcons.status_error_full,
      OrbiMessageSeverity.warning => FluentIcons.warning,
      OrbiMessageSeverity.success => FluentIcons.completed_solid,
      OrbiMessageSeverity.info => FluentIcons.info_solid,
    },
  );
}

InfoBarSeverity _infoBarSeverityFor(OrbiMessageSeverity severity) =>
    switch (severity) {
      OrbiMessageSeverity.error => InfoBarSeverity.error,
      OrbiMessageSeverity.warning => InfoBarSeverity.warning,
      OrbiMessageSeverity.success => InfoBarSeverity.success,
      OrbiMessageSeverity.info => InfoBarSeverity.info,
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
      _showTransientBar(
        context,
        duration: const Duration(seconds: 4),
        builder: (context, close) => InfoBar(
          key: const Key('copy-failed-confirmation'),
          title: const Text(
            'No se pudo copiar. Selecciona el texto y cópialo.',
          ),
          severity: InfoBarSeverity.warning,
          onClose: close,
        ),
      );
    }
    return false;
  }
  if (context.mounted) {
    _showTransientBar(
      context,
      duration: const Duration(seconds: 1),
      builder: (context, close) => const InfoBar(
        key: Key('copy-confirmation'),
        title: Text('Mensaje copiado'),
        severity: InfoBarSeverity.success,
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
/// also just what Material does — kept the same way on Fluent, since it is a
/// layout decision, not one this port owes to either design system.
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
    final theme = FluentTheme.of(context);
    final tones = orbiMessageTones(theme, message.severity);
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
                            style: theme.typography.bodyStrong?.copyWith(
                              color: tones.foreground,
                            ),
                          ),
                          const SizedBox(height: OrbiTheme.space4),
                          // Selectable as well as copyable: someone who wants
                          // only one sentence should not have to take all of
                          // it.
                          SelectableText(
                            message.body,
                            style: theme.typography.caption?.copyWith(
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
                  Button(
                    key: const Key('copy-message-button'),
                    onPressed: () => copyOrbiMessage(context, message),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.copy, size: 16),
                        SizedBox(width: 6),
                        Text('Copiar'),
                      ],
                    ),
                  ),
                  if (onDismiss != null) ...[
                    const SizedBox(width: 8),
                    Button(
                      key: const Key('dismiss-message-button'),
                      onPressed: onDismiss,
                      child: const Text('Cerrar'),
                    ),
                  ],
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
/// `global_notification_service.dart` arrived at, originally built on
/// Material's `SnackBar`/`ScaffoldMessenger` and rebuilt here on Fluent's
/// `InfoBar`.
///
/// A severity configured as 0 seconds gets a bar with no timeout and an
/// explicit "Cerrar": it stays until someone deals with it.
void showCopyableMessage(
  BuildContext context,
  CopyableMessage message, {
  required MessageDurations durations,
  Duration? overrideDuration,
}) {
  final duration = overrideDuration ?? durations.durationFor(message.severity);
  late final _TransientBarHandle handle;
  handle = _showTransientBar(
    context,
    // A message that must not expire gets a handle whose Timer is simply
    // never scheduled (see _showTransientBar), instead of a duration long
    // enough to outlast the test suite — the same intent the previous
    // Material implementation expressed with `Duration(days: 365)`, done
    // properly this time.
    duration: duration,
    builder: (context, _) => Semantics(
      liveRegion: true,
      container: true,
      label: '${message.title}. ${message.body}',
      child: ExcludeSemantics(
        child: InfoBar(
          key: const Key('copyable-message-bar'),
          title: Text(message.title),
          content: Text(message.body),
          severity: _infoBarSeverityFor(message.severity),
          isLong: true,
          action: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Button(
                key: const Key('copy-message-button'),
                onPressed: () => copyOrbiMessage(context, message),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(FluentIcons.copy, size: 16),
                    SizedBox(width: 6),
                    Text('Copiar'),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Button(
                key: const Key('dismiss-message-button'),
                onPressed: () => handle.close(),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

/// A single, minimal overlay slot for a transient Fluent-styled message.
///
/// Deliberately NOT `displayInfoBar` (the helper `package:fluent_ui` ships):
/// that helper hides its content behind a themed fade-in for the whole first
/// animation frame, so a caller cannot rely on the bar being visible the
/// instant it is shown — and the copy confirmation, in particular, is
/// expected to appear immediately. This inserts the widget synchronously and
/// manages its own removal, either after [duration] or via the returned
/// handle's `close`.
_TransientBarHandle _showTransientBar(
  BuildContext context, {
  required Widget Function(BuildContext context, VoidCallback close) builder,
  Duration? duration,
}) {
  final overlay = Overlay.of(context, rootOverlay: true);
  late final OverlayEntry entry;
  void close() {
    if (entry.mounted) entry.remove();
  }

  entry = OverlayEntry(
    builder: (context) => _TransientBarSlot(
      duration: duration,
      onExpire: close,
      builder: (context) => builder(context, close),
    ),
  );
  overlay.insert(entry);
  return _TransientBarHandle(close);
}

final class _TransientBarHandle {
  const _TransientBarHandle(this.close);
  final VoidCallback close;
}

/// Owns the auto-dismiss [Timer], so it dies with the widget instead of
/// outliving it — a bare top-level `Timer` has nothing to cancel it when the
/// overlay is torn down (e.g. at the end of a widget test), and Flutter
/// treats that as a leak.
class _TransientBarSlot extends StatefulWidget {
  const _TransientBarSlot({
    required this.duration,
    required this.onExpire,
    required this.builder,
  });

  final Duration? duration;
  final VoidCallback onExpire;
  final WidgetBuilder builder;

  @override
  State<_TransientBarSlot> createState() => _TransientBarSlotState();
}

class _TransientBarSlotState extends State<_TransientBarSlot> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    final duration = widget.duration;
    if (duration != null) {
      _timer = Timer(duration, widget.onExpire);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: widget.builder(context),
      ),
    ),
  );
}
