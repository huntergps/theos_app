import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/preferences/app_preferences.dart';
import 'package:theos_panel/features/settings/message_durations_section.dart';
import 'package:theos_panel/ui/components/copyable_message.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// The owner did not ask for the durations to merely EXIST in the code — he
/// said "se debe escoger el tiempo a mostrar". So these tests are about the
/// two halves of choosing: that there is somewhere to choose, and that the
/// choice is still there after the app is restarted.
const _scope = PreferencesScope(appId: 'theos_panel', scopeKey: 'anonymous');

Future<AppPreferencesController> _controller() async {
  final preferences = await SharedPreferences.getInstance();
  final controller = AppPreferencesController(
    AppPreferencesStore(preferences: preferences, scope: _scope),
  );
  await controller.load();
  return controller;
}

Widget _host(AppPreferencesController controller) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: ScaffoldPage(
    content: SingleChildScrollView(
      child: MessageDurationsSection(controller: controller),
    ),
  ),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('there is somewhere to choose, one control per severity', (
    tester,
  ) async {
    final controller = await _controller();
    await tester.pumpWidget(_host(controller));
    for (final severity in OrbiMessageSeverity.values) {
      expect(
        find.byKey(Key('message-duration-${severity.name}')),
        findsOneWidget,
        reason: '${severity.name} cannot be chosen.',
      );
    }
    expect(find.text('Errores'), findsOneWidget);
    expect(find.text('Avisos'), findsOneWidget);
    expect(find.text('Confirmaciones'), findsOneWidget);
    expect(find.text('Información'), findsOneWidget);
  });

  testWidgets('the error default reads as words, not as a bare zero', (
    tester,
  ) async {
    // "0 s" next to "Errores" reads as "disabled", which is the opposite of
    // what it does.
    final controller = await _controller();
    await tester.pumpWidget(_host(controller));
    expect(find.text('Hasta que la cierres'), findsOneWidget);
    expect(MessageDurationsSection.describeSeconds(0), 'Hasta que la cierres');
    expect(MessageDurationsSection.describeSeconds(7), '7 s');
  });

  testWidgets('choosing a duration changes it right away', (tester) async {
    final controller = await _controller();
    await tester.pumpWidget(_host(controller));
    final slider = find.descendant(
      of: find.byKey(const Key('message-duration-info')),
      matching: find.byType(Slider),
    );
    await tester.drag(slider, const Offset(400, 0));
    await tester.pumpAndSettle();
    expect(
      controller.snapshot.messageDurations.infoSeconds,
      greaterThan(const MessageDurations().infoSeconds),
    );
  });

  testWidgets('and the choice is still there after a restart', (tester) async {
    // The real question behind "se debe escoger": a setting that forgets
    // itself was never chosen, it was just nudged.
    final controller = await _controller();
    await tester.pumpWidget(_host(controller));
    await tester.runAsync(
      () => controller.setMessageDuration(OrbiMessageSeverity.error, 25),
    );
    await tester.pumpAndSettle();
    expect(controller.snapshot.messageDurations.errorSeconds, 25);

    // A brand-new store over the same storage — what a cold start does.
    final restarted = await tester.runAsync(_controller);
    expect(restarted!.snapshot.messageDurations.errorSeconds, 25);
    expect(
      restarted.snapshot.messageDurations.durationFor(
        OrbiMessageSeverity.error,
      ),
      const Duration(seconds: 25),
    );
  });

  testWidgets('an error can be put back to never expiring', (tester) async {
    final controller = await _controller();
    await tester.pumpWidget(_host(controller));
    await tester.runAsync(
      () => controller.setMessageDuration(OrbiMessageSeverity.error, 25),
    );
    await tester.runAsync(
      () => controller.setMessageDuration(OrbiMessageSeverity.error, 0),
    );
    await tester.pumpAndSettle();
    final restarted = await tester.runAsync(_controller);
    expect(restarted!.snapshot.messageDurations.errorSeconds, 0);
    expect(
      restarted.snapshot.messageDurations.durationFor(
        OrbiMessageSeverity.error,
      ),
      isNull,
    );
  });

  testWidgets('preferences saved before durations existed still load', (
    tester,
  ) async {
    // The upgrade path: a payload written by the previous version carries no
    // messageDurations key. It must keep its theme and text scale, not be
    // thrown away as corrupt.
    SharedPreferences.setMockInitialValues({
      'orbi/preferences/["theos_panel","anonymous"]':
          '{"version":1,"theme":"dark","accentSeed":123,"density":"compact",'
          '"textScale":1.5,"routeMode":true,"syncRetries":7,'
          '"notificationCategories":{}}',
    });
    final controller = await _controller();
    expect(controller.snapshot.themeMode, PreferenceThemeMode.dark);
    expect(controller.snapshot.textScale, 1.5);
    expect(controller.snapshot.syncRetries, 7);
    expect(
      controller.snapshot.messageDurations,
      const MessageDurations(),
      reason: 'An old payload must fall back to the defaults, not blow up.',
    );
    await tester.pumpWidget(_host(controller));
    expect(tester.takeException(), isNull);
  });
}
