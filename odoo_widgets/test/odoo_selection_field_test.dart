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

final testOptions = [
  SelectionOption(value: 'draft', label: 'Draft'),
  SelectionOption(value: 'confirmed', label: 'Confirmed', color: Colors.blue),
  SelectionOption(value: 'done', label: 'Done', color: Colors.green),
  SelectionOption(value: 'cancel', label: 'Cancelled', color: Colors.red),
];

void main() {
  group('OdooSelectionField', () {
    group('view mode', () {
      testWidgets('displays selected option label with colored badge',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: false,
            ),
            value: 'confirmed',
            options: testOptions,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Status:'), findsOneWidget);
        expect(find.text('Confirmed'), findsOneWidget);
      });

      testWidgets('displays dash when value is null', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: false,
            ),
            value: null,
            options: testOptions,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('-'), findsOneWidget);
      });

      testWidgets('shows option with color in a decorated Container',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'State',
              isEditing: false,
            ),
            value: 'done',
            options: testOptions,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Done'), findsOneWidget);
        // The colored option text should be in a Container with decoration
        final doneText = find.text('Done');
        final container = find.ancestor(
          of: doneText,
          matching: find.byType(Container),
        );
        expect(container, findsWidgets);
      });

      testWidgets('shows option without color styling for colorless options',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'Type',
              isEditing: false,
            ),
            value: 'draft',
            options: testOptions,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Draft'), findsOneWidget);
      });

      testWidgets('shows prefix icon when configured', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: false,
              prefixIcon: FluentIcons.info,
            ),
            value: 'draft',
            options: testOptions,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(FluentIcons.info), findsOneWidget);
      });
    });

    group('edit mode - combobox (default)', () {
      testWidgets('shows inline selection button in edit mode',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: true,
            ),
            value: 'draft',
            options: testOptions,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        // Should show the current value label and label
        expect(find.text('Status:'), findsOneWidget);
        expect(find.text('Draft'), findsOneWidget);
      });

      testWidgets('shows placeholder when no value selected', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'Status',
              isEditing: true,
            ),
            value: null,
            options: testOptions,
            onChanged: (_) {},
            placeholder: 'Choose one...',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Choose one...'), findsOneWidget);
      });
    });

    group('edit mode - radio', () {
      testWidgets('shows RadioButton widgets for each option', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'Priority',
              isEditing: true,
            ),
            value: 'draft',
            options: testOptions,
            asRadio: true,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(RadioButton), findsNWidgets(testOptions.length));
        expect(find.text('Draft'), findsOneWidget);
        expect(find.text('Confirmed'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Cancelled'), findsOneWidget);
      });

      testWidgets('fires onChanged when radio button is tapped',
          (tester) async {
        String? changedValue;

        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'Priority',
              isEditing: true,
            ),
            value: 'draft',
            options: testOptions,
            asRadio: true,
            onChanged: (val) => changedValue = val,
          ),
        ));
        await tester.pumpAndSettle();

        // Tap the "Confirmed" radio button
        await tester.tap(find.text('Confirmed'));
        await tester.pumpAndSettle();

        expect(changedValue, 'confirmed');
      });
    });

    group('edit mode - segmented', () {
      testWidgets('shows segmented buttons for each option', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'View',
              isEditing: true,
            ),
            value: 'draft',
            options: testOptions,
            asSegmented: true,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Draft'), findsOneWidget);
        expect(find.text('Confirmed'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Cancelled'), findsOneWidget);
      });

      testWidgets('fires onChanged on segment tap', (tester) async {
        String? changedValue;

        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'View',
              isEditing: true,
            ),
            value: 'draft',
            options: testOptions,
            asSegmented: true,
            onChanged: (val) => changedValue = val,
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Done'));
        await tester.pumpAndSettle();

        expect(changedValue, 'done');
      });
    });

    group('formatting', () {
      testWidgets('formatValue returns option label', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'State',
              isEditing: false,
            ),
            value: 'cancel',
            options: testOptions,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Cancelled'), findsOneWidget);
      });

      testWidgets('formatValue returns dash for null', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSelectionField<String>(
            config: const OdooFieldConfig(
              label: 'State',
              isEditing: false,
            ),
            value: null,
            options: testOptions,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('-'), findsOneWidget);
      });
    });
  });

  group('OdooStatusField', () {
    final statusStates = [
      SelectionOption(value: 'draft', label: 'Draft'),
      SelectionOption(
          value: 'confirmed', label: 'Confirmed', color: Colors.blue),
      SelectionOption(value: 'shipped', label: 'Shipped', color: Colors.orange),
      SelectionOption(value: 'done', label: 'Done', color: Colors.green),
    ];

    int getStateIndex(String value) {
      return statusStates.indexWhere((s) => s.value == value);
    }

    testWidgets('renders progress indicator with state labels',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooStatusField<String>(
          config: const OdooFieldConfig(
            label: 'Order Status',
            isEditing: false,
          ),
          value: 'confirmed',
          states: statusStates,
          getStateIndex: getStateIndex,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Order Status'), findsOneWidget);
      expect(find.text('Draft'), findsOneWidget);
      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Shipped'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
    });

    testWidgets('renders state number circles', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooStatusField<String>(
          config: const OdooFieldConfig(
            label: 'Status',
            isEditing: false,
          ),
          value: 'draft',
          states: statusStates,
          getStateIndex: getStateIndex,
        ),
      ));
      await tester.pumpAndSettle();

      // State numbers in circles
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('renders connecting lines between states', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooStatusField<String>(
          config: const OdooFieldConfig(
            label: 'Status',
            isEditing: false,
          ),
          value: 'shipped',
          states: statusStates,
          getStateIndex: getStateIndex,
        ),
      ));
      await tester.pumpAndSettle();

      // All labels should be visible
      for (final state in statusStates) {
        expect(find.text(state.label), findsOneWidget);
      }
    });

    testWidgets('handles null value', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooStatusField<String>(
          config: const OdooFieldConfig(
            label: 'Status',
            isEditing: false,
          ),
          value: null,
          states: statusStates,
          getStateIndex: getStateIndex,
        ),
      ));
      await tester.pumpAndSettle();

      // With null, currentIndex defaults to 0
      expect(find.text('Draft'), findsOneWidget);
    });

    testWidgets('hides label in compact mode', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooStatusField<String>(
          config: const OdooFieldConfig(
            label: 'Status',
            isEditing: false,
            isCompact: true,
          ),
          value: 'draft',
          states: statusStates,
          getStateIndex: getStateIndex,
        ),
      ));
      await tester.pumpAndSettle();

      // The main label should be hidden in compact mode, but state labels still show
      // 'Draft' appears in the state labels row
      expect(find.text('Status'), findsNothing);
    });
  });
}
