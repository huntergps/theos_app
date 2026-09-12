import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show NotificationSeverity;
import 'package:theos_panel/app/theme/orbi_theme.dart';
import 'package:theos_panel/ui/components/copyable_message.dart';

/// Captures what the app actually hands to the platform clipboard.
///
/// `Clipboard.setData` is a platform channel, so a widget test sees nothing
/// unless the channel is intercepted. Everything asserted about copying below
/// goes through this, never through an internal getter — the question is what
/// LANDS in the clipboard, not what we intended to put there.
final class _ClipboardSpy {
  String? text;
  int calls = 0;

  void install(WidgetTester tester) {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          calls++;
          text = (call.arguments as Map)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
  }
}

const _longFailure = CopyableMessage(
  title: 'No se pudo crear la clave de acceso de este dispositivo',
  body:
      'Esto no es una contraseña equivocada. El servidor no entregó la clave '
      'que la aplicación necesita para quedarse conectada. Vuelve a '
      'intentarlo; si sigue igual, pide a tu administrador que revise si tu '
      'usuario puede crear claves de API.',
  severity: OrbiMessageSeverity.error,
);

Widget _host(Widget child, {Size? size}) => MaterialApp(
  theme: OrbiTheme.light,
  home: Scaffold(
    body: Center(
      child: SizedBox(width: size?.width ?? 420, child: child),
    ),
  ),
);

void main() {
  group('copying a message takes the WHOLE thing', () {
    testWidgets('title, guidance and when it happened all land on the clipboard', (
      tester,
    ) async {
      final spy = _ClipboardSpy()..install(tester);
      final message = CopyableMessage(
        title: _longFailure.title,
        body: _longFailure.body,
        severity: OrbiMessageSeverity.error,
        occurredAt: DateTime(2026, 9, 11, 23, 52),
      );
      await tester.pumpWidget(_host(CopyableMessagePanel(message: message)));
      await tester.tap(find.byKey(const Key('copy-message-button')));
      await tester.pump();

      expect(spy.calls, 1);
      // The full guidance, not a summary — the point of the button is that
      // what gets pasted into a chat is enough for somebody else to act on.
      expect(spy.text, contains(message.title));
      expect(spy.text, contains(message.body));
      expect(
        spy.text!.length,
        greaterThanOrEqualTo(message.title.length + message.body.length),
      );
      // Several failure messages end by asking the person to tell their
      // administrator WHEN it happened. A copy button that dropped the one
      // fact the message just asked for would be a small betrayal.
      expect(spy.text, contains('11/09/2026 23:52'));
    });

    testWidgets('and nothing internal rides along', (tester) async {
      final spy = _ClipboardSpy()..install(tester);
      await tester.pumpWidget(
        _host(const CopyableMessagePanel(message: _longFailure)),
      );
      await tester.tap(find.byKey(const Key('copy-message-button')));
      await tester.pump();
      for (final leak in [
        'Exception',
        'StackTrace',
        'statusCode',
        'OdooClient',
        '#0',
      ]) {
        expect(spy.text, isNot(contains(leak)));
      }
    });

    testWidgets('the person is told it worked', (tester) async {
      _ClipboardSpy().install(tester);
      await tester.pumpWidget(
        _host(const CopyableMessagePanel(message: _longFailure)),
      );
      await tester.tap(find.byKey(const Key('copy-message-button')));
      await tester.pump();
      // Copying is invisible; without confirmation an unsure owner presses
      // again and pastes twice.
      expect(find.byKey(const Key('copy-confirmation')), findsOneWidget);
      expect(find.text('Mensaje copiado'), findsOneWidget);
    });

    testWidgets('a clipboard that refuses says so instead of lying', (
      tester,
    ) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            throw PlatformException(code: 'unavailable');
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        _host(const CopyableMessagePanel(message: _longFailure)),
      );
      await tester.tap(find.byKey(const Key('copy-message-button')));
      await tester.pump();
      expect(find.byKey(const Key('copy-failed-confirmation')), findsOneWidget);
      expect(find.byKey(const Key('copy-confirmation')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('the body can also be selected by hand', (tester) async {
      // Someone who wants one sentence should not have to take all of it.
      await tester.pumpWidget(
        _host(const CopyableMessagePanel(message: _longFailure)),
      );
      expect(find.byType(SelectableText), findsOneWidget);
    });
  });

  group('the copy button does not crowd the headline on a narrow screen', () {
    testWidgets('at phone width the title still gets the full row', (
      tester,
    ) async {
      // theos_pos puts the copy button IN the title row, beside the close
      // button (copyable_info_bar.dart). At this width that leaves a long
      // headline fighting two icon buttons for the same line. Orbi puts the
      // actions underneath, so the headline keeps the width.
      await tester.pumpWidget(
        _host(
          const CopyableMessagePanel(message: _longFailure),
          size: const Size(320, 600),
        ),
      );
      final titleWidth = tester.getSize(find.text(_longFailure.title)).width;
      final copyButton = find.byKey(const Key('copy-message-button'));
      final titleBottom = tester.getBottomLeft(
        find.text(_longFailure.title),
      ).dy;

      // The button is BELOW the headline, not level with it.
      expect(
        tester.getTopLeft(copyButton).dy,
        greaterThanOrEqualTo(titleBottom),
        reason:
            'The copy button is on the headline\'s row — the exact squeeze '
            'inherited from theos_pos.',
      );
      // And the headline gets essentially everything left after the icon.
      expect(
        titleWidth,
        greaterThan(320 - OrbiTheme.space12 * 2 - 20 - OrbiTheme.space12 - 8),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('the action row is the height the layout budget assumes', (
      tester,
    ) async {
      // login_screen.dart's compact-vs-normal budget reserves
      // _kFailurePanelActionRowHeight for this row. If Material ever changes
      // a TextButton's minimum height, that budget silently drifts and the
      // form starts picking the spacious styling in a window it no longer
      // fits — so it fails loudly here instead.
      await tester.pumpWidget(
        _host(const CopyableMessagePanel(message: _longFailure)),
      );
      expect(
        tester.getSize(find.byKey(const Key('copy-message-button'))).height,
        kMinInteractiveDimension,
        reason:
            'The copy button moved away from the minimum touch target — '
            'update _kFailurePanelActionRowHeight in login_screen.dart.',
      );
    });

    testWidgets('nothing overflows at phone width', (tester) async {
      await tester.pumpWidget(
        _host(
          const CopyableMessagePanel(message: _longFailure),
          size: const Size(320, 600),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('how long a message stays is chosen, not hard-coded', () {
    test('an error does not expire by default; the others do', () {
      const durations = MessageDurations();
      // The owner has to be able to reach for the copy button. Ten seconds —
      // what theos_pos gives an error — is not enough to read two lines,
      // decide it matters and press it.
      expect(durations.durationFor(OrbiMessageSeverity.error), isNull);
      expect(durations.durationFor(OrbiMessageSeverity.warning), isNotNull);
      expect(durations.durationFor(OrbiMessageSeverity.success), isNotNull);
      expect(durations.durationFor(OrbiMessageSeverity.info), isNotNull);
    });

    test('but it remains a choice: an error can be given a countdown', () {
      const durations = MessageDurations();
      final chosen = durations.copyWithSeverity(OrbiMessageSeverity.error, 10);
      expect(
        chosen.durationFor(OrbiMessageSeverity.error),
        const Duration(seconds: 10),
      );
      // And changing one severity leaves the rest alone.
      expect(chosen.warningSeconds, durations.warningSeconds);
      expect(chosen.successSeconds, durations.successSeconds);
      expect(chosen.infoSeconds, durations.infoSeconds);
    });

    test('values are clamped to what the picker can actually offer', () {
      const durations = MessageDurations();
      expect(
        durations.copyWithSeverity(OrbiMessageSeverity.info, -5).infoSeconds,
        0,
      );
      expect(
        durations.copyWithSeverity(OrbiMessageSeverity.info, 9999).infoSeconds,
        MessageDurations.maxSeconds,
      );
    });

    test('a payload written before durations existed still loads', () {
      // AppPreferencesSnapshot.fromJson must never throw over a key that did
      // not exist when the file was written — that would lose the person's
      // theme and text scale on the next start.
      expect(MessageDurations.fromJson(null), const MessageDurations());
      expect(MessageDurations.fromJson('junk'), const MessageDurations());
      expect(
        MessageDurations.fromJson({'error': 12, 'warning': 'nonsense'}),
        const MessageDurations(errorSeconds: 12),
      );
    });

    test('it survives a round trip through JSON', () {
      const original = MessageDurations(
        errorSeconds: 0,
        warningSeconds: 12,
        successSeconds: 2,
        infoSeconds: 7,
      );
      expect(MessageDurations.fromJson(original.toJson()), original);
    });

    testWidgets('0 seconds really means the bar waits for you', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OrbiTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCopyableMessage(
                  context,
                  _longFailure,
                  durations: const MessageDurations(),
                ),
                child: const Text('mostrar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mostrar'));
      // Settle the entrance first: a SnackBar only starts its own expiry
      // timer once that animation completes.
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('copyable-message-bar')), findsOneWidget);
      // Far longer than theos_pos's ten seconds, and longer than any value
      // the picker offers.
      await tester.pump(const Duration(minutes: 5));
      // pumpAndSettle, NOT a bare pump: a SnackBar that HAS expired is still
      // in the tree for the length of its exit animation, so asserting right
      // after the clock jump would pass even when the bar was on its way out.
      // That is not hypothetical — this test did exactly that, and stayed
      // green with the error set back to theos_pos's ten seconds.
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('copyable-message-bar')),
        findsOneWidget,
        reason: 'The error vanished while the person was reading it.',
      );
      // It is not a trap: there is an explicit way out.
      await tester.tap(find.byKey(const Key('dismiss-message-button')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('copyable-message-bar')), findsNothing);
    });

    testWidgets('a severity with a countdown does go away on its own', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OrbiTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCopyableMessage(
                  context,
                  const CopyableMessage(
                    title: 'Guardado',
                    body: 'Se guardó el cambio.',
                    severity: OrbiMessageSeverity.success,
                  ),
                  durations: const MessageDurations(successSeconds: 3),
                ),
                child: const Text('mostrar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mostrar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('copyable-message-bar')), findsOneWidget);
      await tester.pump(const Duration(seconds: 4));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('copyable-message-bar')), findsNothing);
    });

    testWidgets('a single call can override the configured duration', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: OrbiTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCopyableMessage(
                  context,
                  _longFailure,
                  durations: const MessageDurations(),
                  overrideDuration: const Duration(seconds: 2),
                ),
                child: const Text('mostrar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mostrar'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('copyable-message-bar')), findsOneWidget);
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('copyable-message-bar')), findsNothing);
    });

    testWidgets('a floating message is copyable too', (tester) async {
      final spy = _ClipboardSpy()..install(tester);
      await tester.pumpWidget(
        MaterialApp(
          theme: OrbiTheme.light,
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showCopyableMessage(
                  context,
                  _longFailure,
                  durations: const MessageDurations(),
                ),
                child: const Text('mostrar'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('mostrar'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('copy-message-button')));
      await tester.pump();
      expect(spy.text, contains(_longFailure.title));
      expect(spy.text, contains(_longFailure.body));
    });
  });

  group('severities keep their own voice', () {
    test('the durable three map onto the presentation four', () {
      expect(
        orbiSeverityFor(NotificationSeverity.error),
        OrbiMessageSeverity.error,
      );
      expect(
        orbiSeverityFor(NotificationSeverity.attention),
        OrbiMessageSeverity.warning,
      );
      expect(
        orbiSeverityFor(NotificationSeverity.info),
        OrbiMessageSeverity.info,
      );
    });

    test('every severity is readable and distinct in both schemes', () {
      for (final theme in [OrbiTheme.light, OrbiTheme.dark]) {
        final backgrounds = <Color>{};
        for (final severity in OrbiMessageSeverity.values) {
          final tones = orbiMessageTones(theme.colorScheme, severity);
          expect(
            _contrast(tones.foreground, tones.background),
            greaterThanOrEqualTo(4.5),
            reason:
                '${severity.name} is unreadable in ${theme.brightness}.',
          );
          expect(
            backgrounds.add(tones.background),
            isTrue,
            reason:
                '${severity.name} paints the same background as another '
                'severity in ${theme.brightness}.',
          );
        }
      }
    });
  });
}

double _contrast(Color foreground, Color background) {
  final a = foreground.computeLuminance();
  final b = background.computeLuminance();
  final lighter = a > b ? a : b;
  final darker = a > b ? b : a;
  return (lighter + 0.05) / (darker + 0.05);
}
