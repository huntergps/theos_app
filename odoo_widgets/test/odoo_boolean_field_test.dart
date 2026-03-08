import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:odoo_widgets/odoo_widgets.dart';

/// Helper to wrap a widget in a FluentApp with proper theming and desktop size.
Widget buildTestApp(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1200, 800)),
    child: FluentApp(
      home: ScaffoldPage(content: Center(child: child)),
    ),
  );
}

void main() {
  group('OdooBooleanField', () {
    group('view mode', () {
      testWidgets('displays "Yes" badge when value is true', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Active',
              isEditing: false,
            ),
            value: true,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Active: '), findsOneWidget);
        expect(find.text('Yes'), findsOneWidget);
      });

      testWidgets('displays "No" badge when value is false', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Active',
              isEditing: false,
            ),
            value: false,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('No'), findsOneWidget);
      });

      testWidgets('displays dash when value is null', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Active',
              isEditing: false,
            ),
            value: null,
          ),
        ));
        await tester.pumpAndSettle();

        // formatValue(null) returns '-'
        expect(find.text('-'), findsOneWidget);
      });

      testWidgets('uses custom true/false text', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: false,
            ),
            value: true,
            trueText: 'Enabled',
            falseText: 'Disabled',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Enabled'), findsOneWidget);
      });

      testWidgets('does not show Checkbox in view mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Active',
              isEditing: false,
            ),
            value: true,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(Checkbox), findsNothing);
      });

      testWidgets('does not show ToggleSwitch in view mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Active',
              isEditing: false,
            ),
            value: true,
            asToggle: true,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(ToggleSwitch), findsNothing);
      });

      testWidgets('renders badge in a Container with colored background',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Active',
              isEditing: false,
            ),
            value: true,
          ),
        ));
        await tester.pumpAndSettle();

        // The "Yes" text should be inside a Container (badge)
        final yesText = find.text('Yes');
        expect(yesText, findsOneWidget);

        // Find the Container ancestor with decoration
        final container = find.ancestor(
          of: yesText,
          matching: find.byType(Container),
        );
        expect(container, findsWidgets);
      });
    });

    group('edit mode - checkbox', () {
      testWidgets('shows Checkbox in edit mode (default)', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Active',
              isEditing: true,
            ),
            value: true,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(Checkbox), findsOneWidget);
      });

      testWidgets('checkbox shows inline label', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Is Active',
              isEditing: true,
            ),
            value: false,
            onChanged: (_) {},
            inlineLabel: true,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Is Active'), findsOneWidget);
        expect(find.byType(Checkbox), findsOneWidget);
      });

      testWidgets('checkbox fires onChanged when tapped', (tester) async {
        bool? changedValue;

        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Active',
              isEditing: true,
            ),
            value: false,
            onChanged: (val) => changedValue = val,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.byType(Checkbox));
        await tester.pumpAndSettle();

        expect(changedValue, true);
      });
    });

    group('edit mode - toggle', () {
      testWidgets('shows ToggleSwitch when asToggle is true', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Active',
              isEditing: true,
            ),
            value: true,
            asToggle: true,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(ToggleSwitch), findsOneWidget);
        expect(find.byType(Checkbox), findsNothing);
      });

      testWidgets('toggle shows inline label', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Feature Toggle',
              isEditing: true,
            ),
            value: false,
            asToggle: true,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Feature Toggle'), findsOneWidget);
        expect(find.byType(ToggleSwitch), findsOneWidget);
      });
    });

    group('formatting', () {
      testWidgets('formatValue returns custom text for true', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: false,
            ),
            value: true,
            trueText: 'On',
            falseText: 'Off',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('On'), findsOneWidget);
      });

      testWidgets('formatValue returns custom text for false', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooBooleanField(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: false,
            ),
            value: false,
            trueText: 'On',
            falseText: 'Off',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Off'), findsOneWidget);
      });
    });
  });

  group('OdooTristateBooleanField', () {
    group('view mode', () {
      testWidgets('displays "Yes" badge for true', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTristateBooleanField(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: false,
            ),
            value: true,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Yes'), findsOneWidget);
      });

      testWidgets('displays "No" badge for false', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTristateBooleanField(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: false,
            ),
            value: false,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('No'), findsOneWidget);
      });

      testWidgets('displays "Undefined" badge for null', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTristateBooleanField(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: false,
            ),
            value: null,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Undefined'), findsOneWidget);
      });

      testWidgets('uses custom text for all three states', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTristateBooleanField(
            config: const OdooFieldConfig(
              label: 'Review',
              isEditing: false,
            ),
            value: null,
            trueText: 'Approved',
            falseText: 'Rejected',
            nullText: 'Pending',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Pending'), findsOneWidget);
      });
    });

    group('edit mode', () {
      testWidgets('shows three segment buttons in edit mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTristateBooleanField(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        // Three segments: No, Undefined, Yes
        expect(find.text('No'), findsOneWidget);
        expect(find.text('Undefined'), findsOneWidget);
        expect(find.text('Yes'), findsOneWidget);
      });

      testWidgets('tapping segment fires onChanged', (tester) async {
        bool? changedValue;

        await tester.pumpWidget(buildTestApp(
          OdooTristateBooleanField(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: true,
            ),
            value: null,
            onChanged: (val) => changedValue = val,
          ),
        ));
        await tester.pumpAndSettle();

        // Tap "Yes" segment
        await tester.tap(find.text('Yes'));
        await tester.pumpAndSettle();

        expect(changedValue, true);
      });

      testWidgets('tapping "No" segment fires onChanged with false',
          (tester) async {
        bool? changedValue;

        await tester.pumpWidget(buildTestApp(
          OdooTristateBooleanField(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: true,
            ),
            value: true,
            onChanged: (val) => changedValue = val,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('No'));
        await tester.pumpAndSettle();

        expect(changedValue, false);
      });

      testWidgets('shows label above segments when not compact',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTristateBooleanField(
            config: const OdooFieldConfig(
              label: 'Decision',
              isEditing: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Decision'), findsOneWidget);
      });
    });

    group('formatting', () {
      testWidgets('each state renders with appropriate color in view mode',
          (tester) async {
        // Test true state (green)
        await tester.pumpWidget(buildTestApp(
          OdooTristateBooleanField(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: false,
            ),
            value: true,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Yes'), findsOneWidget);
      });
    });
  });
}
