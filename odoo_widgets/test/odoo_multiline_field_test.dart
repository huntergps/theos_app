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
  group('OdooMultilineField', () {
    group('view mode', () {
      testWidgets('displays value inside a bordered Container',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: false,
            ),
            value: 'These are internal notes for the order.',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Notes'), findsOneWidget);
        expect(
          find.text('These are internal notes for the order.'),
          findsOneWidget,
        );
      });

      testWidgets('displays dash when value is null', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: false,
            ),
            value: null,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('-'), findsOneWidget);
      });

      testWidgets('displays dash when value is empty string', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: false,
            ),
            value: '',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('-'), findsOneWidget);
      });

      testWidgets('does not show TextBox in view mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: false,
            ),
            value: 'Some text',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(TextBox), findsNothing);
      });

      testWidgets('shows prefix icon when configured', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Description',
              isEditing: false,
              prefixIcon: FluentIcons.edit_note,
            ),
            value: 'Description text',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(FluentIcons.edit_note), findsOneWidget);
      });

      testWidgets('hides label in compact mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: false,
              isCompact: true,
            ),
            value: 'Compact content',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Notes'), findsNothing);
        expect(find.text('Compact content'), findsOneWidget);
      });
    });

    group('edit mode', () {
      testWidgets('shows TextBox (textarea) in edit mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: true,
            ),
            value: 'Editable notes',
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(TextBox), findsOneWidget);
      });

      testWidgets('shows label above textarea', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Internal Notes',
              isEditing: true,
            ),
            value: '',
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Internal Notes'), findsOneWidget);
        expect(find.byType(TextBox), findsOneWidget);
      });

      testWidgets('fires onChanged when text is entered', (tester) async {
        String? changedValue;

        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: true,
            ),
            value: '',
            onChanged: (val) => changedValue = val,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextBox), 'New note');
        await tester.pumpAndSettle();

        expect(changedValue, 'New note');
      });

      testWidgets('shows character count when enabled', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: true,
            ),
            value: 'Hello',
            showCharCount: true,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('5 characters'), findsOneWidget);
      });

      testWidgets('shows character count with max length', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: true,
            ),
            value: 'Hi',
            showCharCount: true,
            maxLength: 100,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('2/100'), findsOneWidget);
      });

      testWidgets('shows error message when provided', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: true,
              errorMessage: 'Notes are required',
            ),
            value: '',
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Notes are required'), findsOneWidget);
      });

      testWidgets('shows required asterisk', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Description',
              isEditing: true,
              isRequired: true,
            ),
            value: '',
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text(' *'), findsOneWidget);
      });
    });

    group('formatting', () {
      testWidgets('formatValue returns empty string for null', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMultilineField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: false,
            ),
            value: null,
          ),
        ));
        await tester.pumpAndSettle();

        // Null formats to '' which shows as '-'
        expect(find.text('-'), findsOneWidget);
      });
    });
  });

  group('OdooCollapsibleTextField', () {
    group('view mode', () {
      testWidgets('displays text in a bordered Container', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooCollapsibleTextField(
            config: const OdooFieldConfig(
              label: 'Long Text',
              isEditing: false,
            ),
            value: 'Short text.',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Long Text'), findsOneWidget);
        expect(find.text('Short text.'), findsOneWidget);
      });

      testWidgets('shows "Show more" link for long text', (tester) async {
        // Generate text long enough to trigger the expand behavior (>100 chars)
        final longText = 'A' * 150;

        await tester.pumpWidget(buildTestApp(
          OdooCollapsibleTextField(
            config: const OdooFieldConfig(
              label: 'Details',
              isEditing: false,
            ),
            value: longText,
            collapsedMaxLines: 2,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Show more'), findsOneWidget);
      });

      testWidgets('toggles to "Show less" when expanded', (tester) async {
        final longText = 'A' * 150;

        await tester.pumpWidget(buildTestApp(
          OdooCollapsibleTextField(
            config: const OdooFieldConfig(
              label: 'Details',
              isEditing: false,
            ),
            value: longText,
            collapsedMaxLines: 2,
          ),
        ));
        await tester.pumpAndSettle();

        // Tap to expand
        await tester.tap(find.text('Show more'));
        await tester.pumpAndSettle();

        expect(find.text('Show less'), findsOneWidget);
      });

      testWidgets('uses custom show more/less labels', (tester) async {
        final longText = 'A' * 150;

        await tester.pumpWidget(buildTestApp(
          OdooCollapsibleTextField(
            config: const OdooFieldConfig(
              label: 'Info',
              isEditing: false,
            ),
            value: longText,
            collapsedMaxLines: 2,
            showMoreLabel: 'Expand',
            showLessLabel: 'Collapse',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Expand'), findsOneWidget);

        // Tap to expand
        await tester.tap(find.text('Expand'));
        await tester.pumpAndSettle();

        expect(find.text('Collapse'), findsOneWidget);
      });

      testWidgets('does not show expand link for short text', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooCollapsibleTextField(
            config: const OdooFieldConfig(
              label: 'Short',
              isEditing: false,
            ),
            value: 'Brief.',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Show more'), findsNothing);
        expect(find.text('Brief.'), findsOneWidget);
      });

      testWidgets('shows dash when value is empty', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooCollapsibleTextField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: false,
            ),
            value: '',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('-'), findsOneWidget);
      });
    });

    group('edit mode', () {
      testWidgets('shows OdooMultilineField in edit mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooCollapsibleTextField(
            config: const OdooFieldConfig(
              label: 'Notes',
              isEditing: true,
            ),
            value: 'Editable long text',
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        // In edit mode, it delegates to OdooMultilineField which renders a TextBox
        expect(find.byType(TextBox), findsOneWidget);
      });
    });

    group('formatting', () {
      testWidgets('shows multiline text correctly in collapsed view',
          (tester) async {
        final multilineText = 'Line 1\nLine 2\nLine 3\nLine 4\nLine 5';

        await tester.pumpWidget(buildTestApp(
          OdooCollapsibleTextField(
            config: const OdooFieldConfig(
              label: 'Multiline',
              isEditing: false,
            ),
            value: multilineText,
            collapsedMaxLines: 2,
          ),
        ));
        await tester.pumpAndSettle();

        // Should show "Show more" since there are 5 lines but collapsed to 2
        expect(find.text('Show more'), findsOneWidget);
      });
    });
  });
}
