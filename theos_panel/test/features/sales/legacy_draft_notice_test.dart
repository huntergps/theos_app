import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:theos_panel/features/sales/legacy_draft_inspector.dart';
import 'package:theos_panel/features/sales/legacy_draft_notice.dart';

LegacyDraftInspection _inspection({bool rawPresent = true}) =>
    LegacyDraftInspection(
      status: LegacyDraftStatus.partial,
      issueLabels: const ['La empresa de origen no está identificada'],
      recoverableFields: const ['clientName', 'lines'],
      missingFields: const ['note'],
      unknownFields: const ['oldField'],
      rawPresent: rawPresent,
    );

Future<void> _pumpNotice(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    FluentApp(
      home: ScaffoldPage(
        content: LegacyDraftNotice(inspection: _inspection()),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('is visible and reviewable at compact and expanded widths', (
    tester,
  ) async {
    for (final size in [
      const Size(320, 640),
      const Size(480, 800),
      const Size(800, 900),
      const Size(1280, 900),
    ]) {
      await _pumpNotice(tester, size);
      expect(
        find.text('Hay un borrador local anterior para revisar'),
        findsOneWidget,
      );
      expect(find.text('Revisar'), findsOneWidget);
      await tester.tap(find.text('Revisar'));
      await tester.pumpAndSettle();
      expect(find.text('Revisión del borrador anterior'), findsOneWidget);
      expect(find.textContaining('No se asignará una empresa'), findsOneWidget);
      await tester.tap(
        find.descendant(
          of: find.byType(ContentDialog),
          matching: find.text('Cerrar'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Revisión del borrador anterior'), findsNothing);
    }
  });

  testWidgets('dismisses notice without opening an import flow', (
    tester,
  ) async {
    var dismissed = false;
    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: LegacyDraftNotice(
            inspection: _inspection(),
            onDismiss: () => dismissed = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Cerrar'));
    // Fluent's `Button` schedules a short internal timer for its press
    // feedback; letting it settle before the test ends avoids a spurious
    // "Timer still pending" teardown failure unrelated to this behavior.
    await tester.pump(const Duration(milliseconds: 200));
    expect(dismissed, isTrue);
    expect(find.text('importó'), findsNothing);
  });

  testWidgets('missing legacy draft renders no notice', (tester) async {
    await tester.pumpWidget(
      FluentApp(
        home: ScaffoldPage(
          content: LegacyDraftNotice(inspection: _inspection(rawPresent: false)),
        ),
      ),
    );
    expect(find.text('Revisar'), findsNothing);
    expect(find.byType(Card), findsNothing);
  });
}
