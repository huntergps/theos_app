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
  group('OdooTextField', () {
    group('view mode', () {
      testWidgets('displays the label and value in view mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Customer Name',
              isEditing: false,
            ),
            value: 'Acme Corp',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Customer Name'), findsOneWidget);
        expect(find.text('Acme Corp'), findsOneWidget);
      });

      testWidgets('displays dash when value is null', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Customer Name',
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
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Name',
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
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Name',
              isEditing: false,
            ),
            value: 'Test',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(TextBox), findsNothing);
      });

      testWidgets('hides label in compact mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Name',
              isEditing: false,
              isCompact: true,
            ),
            value: 'Compact Value',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Name'), findsNothing);
        expect(find.text('Compact Value'), findsOneWidget);
      });
    });

    group('edit mode', () {
      testWidgets('shows TextBox in edit mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Name',
              isEditing: true,
            ),
            value: 'Editable',
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(TextBox), findsOneWidget);
      });

      testWidgets('shows label above TextBox in edit mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Full Name',
              isEditing: true,
            ),
            value: '',
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Full Name'), findsOneWidget);
        expect(find.byType(TextBox), findsOneWidget);
      });

      testWidgets('shows required asterisk when isRequired is true',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Email',
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

      testWidgets('fires onChanged callback when text changes',
          (tester) async {
        String? changedValue;

        await tester.pumpWidget(buildTestApp(
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Name',
              isEditing: true,
            ),
            value: '',
            onChanged: (val) => changedValue = val,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.enterText(find.byType(TextBox), 'Hello');
        await tester.pumpAndSettle();

        expect(changedValue, 'Hello');
      });

      testWidgets('displays error message when provided', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Name',
              isEditing: true,
              errorMessage: 'This field is required',
            ),
            value: '',
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('This field is required'), findsOneWidget);
      });

      testWidgets('displays help text when no error', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Name',
              isEditing: true,
              helpText: 'Enter your full name',
            ),
            value: '',
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Enter your full name'), findsOneWidget);
      });

      testWidgets('falls back to view mode when disabled', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Name',
              isEditing: true,
              isEnabled: false,
            ),
            value: 'Read Only',
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        // When isEnabled is false, even in edit mode, buildViewMode is used
        expect(find.byType(TextBox), findsNothing);
        expect(find.text('Read Only'), findsOneWidget);
      });
    });

    group('formatting', () {
      testWidgets('formats null value as empty string', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooTextField(
            config: const OdooFieldConfig(
              label: 'Field',
              isEditing: false,
            ),
            value: null,
          ),
        ));
        await tester.pumpAndSettle();

        // Null formatted as '' which then shows as '-'
        expect(find.text('-'), findsOneWidget);
      });
    });
  });

  group('OdooInlineTextField', () {
    testWidgets('shows value in view mode (not editing config)',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooInlineTextField(
          config: const OdooFieldConfig(
            label: 'Name',
            isEditing: false,
          ),
          value: 'Inline Value',
          onSave: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Inline Value'), findsOneWidget);
      // No TextBox in non-editing mode
      expect(find.byType(TextBox), findsNothing);
    });

    testWidgets(
        'shows value with edit hint icon when config isEditing but not active editing',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooInlineTextField(
          config: const OdooFieldConfig(
            label: 'Name',
            isEditing: true,
          ),
          value: 'Click to Edit',
          onSave: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Click to Edit'), findsOneWidget);
      // Edit hint icon should be visible when isEditing but not actively editing
      expect(find.byIcon(FluentIcons.edit), findsOneWidget);
    });

    testWidgets('enters edit mode on tap and shows save/cancel buttons',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooInlineTextField(
          config: const OdooFieldConfig(
            label: 'Name',
            isEditing: true,
          ),
          value: 'Tap Me',
          onSave: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      // Tap to enter editing
      await tester.tap(find.text('Tap Me'));
      await tester.pumpAndSettle();

      // Now should show TextBox and save/cancel buttons
      expect(find.byType(TextBox), findsOneWidget);
      expect(find.byIcon(FluentIcons.check_mark), findsOneWidget);
      expect(find.byIcon(FluentIcons.cancel), findsOneWidget);
    });

    testWidgets('cancel button restores original value', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooInlineTextField(
          config: const OdooFieldConfig(
            label: 'Name',
            isEditing: true,
          ),
          value: 'Original',
          onSave: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      // Enter editing
      await tester.tap(find.text('Original'));
      await tester.pumpAndSettle();

      // Type new value
      await tester.enterText(find.byType(TextBox), 'Modified');
      await tester.pumpAndSettle();

      // Press cancel
      await tester.tap(find.byIcon(FluentIcons.cancel));
      await tester.pumpAndSettle();

      // Should return to view mode showing original value
      expect(find.byType(TextBox), findsNothing);
      expect(find.text('Original'), findsOneWidget);
    });

    testWidgets('shows hint when value is null or empty', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooInlineTextField(
          config: const OdooFieldConfig(
            label: 'Notes',
            isEditing: false,
            hint: 'Enter notes...',
          ),
          value: null,
          onSave: (_) async {},
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Enter notes...'), findsOneWidget);
    });
  });
}
