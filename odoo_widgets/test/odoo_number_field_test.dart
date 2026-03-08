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
  group('OdooNumberField', () {
    group('view mode', () {
      testWidgets('displays formatted number with locale', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooNumberField(
            config: const OdooFieldConfig(
              label: 'Quantity',
              isEditing: false,
            ),
            value: 1234.56,
            decimals: 2,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Quantity'), findsOneWidget);
        // en locale formats with comma separator: 1,234.56
        expect(find.text('1,234.56'), findsOneWidget);
      });

      testWidgets('displays empty string when value is null', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooNumberField(
            config: const OdooFieldConfig(
              label: 'Amount',
              isEditing: false,
            ),
            value: null,
          ),
        ));
        await tester.pumpAndSettle();

        // Null formats to '' which then shows as '-'
        expect(find.text('-'), findsOneWidget);
      });

      testWidgets('displays suffix with value', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooNumberField(
            config: const OdooFieldConfig(
              label: 'Weight',
              isEditing: false,
            ),
            value: 75.5,
            decimals: 1,
            suffix: 'kg',
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('75.5 kg'), findsOneWidget);
      });

      testWidgets('does not show NumberInputBase in view mode',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooNumberField(
            config: const OdooFieldConfig(
              label: 'Qty',
              isEditing: false,
            ),
            value: 10.0,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(NumberInputBase), findsNothing);
      });
    });

    group('edit mode', () {
      testWidgets('shows NumberInputBase in edit mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooNumberField(
            config: const OdooFieldConfig(
              label: 'Quantity',
              isEditing: true,
            ),
            value: 5.0,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(NumberInputBase), findsOneWidget);
      });

      testWidgets('shows label above input in edit mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooNumberField(
            config: const OdooFieldConfig(
              label: 'Price',
              isEditing: true,
            ),
            value: 99.99,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Price'), findsOneWidget);
        expect(find.byType(NumberInputBase), findsOneWidget);
      });

      testWidgets('shows TextBox inside NumberInputBase for editing',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooNumberField(
            config: const OdooFieldConfig(
              label: 'Value',
              isEditing: true,
            ),
            value: 42.0,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(TextBox), findsOneWidget);
      });
    });

    group('formatting', () {
      testWidgets('respects decimal places setting', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooNumberField(
            config: const OdooFieldConfig(
              label: 'Precision',
              isEditing: false,
            ),
            value: 3.14159,
            decimals: 4,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('3.1416'), findsOneWidget);
      });

      testWidgets('formats zero-decimal integers', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooNumberField(
            config: const OdooFieldConfig(
              label: 'Count',
              isEditing: false,
            ),
            value: 100.0,
            decimals: 0,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('100'), findsOneWidget);
      });
    });
  });

  group('OdooMoneyField', () {
    group('view mode', () {
      testWidgets('displays formatted currency', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMoneyField(
            config: const OdooFieldConfig(
              label: 'Total',
              isEditing: false,
            ),
            value: 1500.00,
            currency: 'USD',
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Total'), findsOneWidget);
        // The currency formatter uses $ symbol
        expect(find.textContaining('\$'), findsOneWidget);
        expect(find.textContaining('1,500.00'), findsOneWidget);
      });

      testWidgets('displays dash for null value', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMoneyField(
            config: const OdooFieldConfig(
              label: 'Price',
              isEditing: false,
            ),
            value: null,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('-'), findsOneWidget);
      });

      testWidgets('does not show NumberInputBase in view mode',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMoneyField(
            config: const OdooFieldConfig(
              label: 'Amount',
              isEditing: false,
            ),
            value: 100.0,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(NumberInputBase), findsNothing);
      });
    });

    group('edit mode', () {
      testWidgets('shows NumberInputBase for editing', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMoneyField(
            config: const OdooFieldConfig(
              label: 'Price',
              isEditing: true,
            ),
            value: 50.0,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(NumberInputBase), findsOneWidget);
      });
    });

    group('formatting', () {
      testWidgets('hides currency symbol when showCurrency is false',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMoneyField(
            config: const OdooFieldConfig(
              label: 'Amount',
              isEditing: false,
            ),
            value: 250.00,
            showCurrency: false,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        // Should show the number without $ prefix
        expect(find.textContaining('250.00'), findsOneWidget);
      });

      testWidgets('respects custom decimal places', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooMoneyField(
            config: const OdooFieldConfig(
              label: 'Cost',
              isEditing: false,
            ),
            value: 99.9,
            decimals: 3,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('99.900'), findsOneWidget);
      });
    });
  });

  group('OdooPercentField', () {
    group('view mode', () {
      testWidgets('displays percentage value with % suffix', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooPercentField(
            config: const OdooFieldConfig(
              label: 'Tax Rate',
              isEditing: false,
            ),
            value: 15.0,
            decimals: 0,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Tax Rate'), findsOneWidget);
        expect(find.textContaining('15%'), findsOneWidget);
      });

      testWidgets('displays dash for null value', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooPercentField(
            config: const OdooFieldConfig(
              label: 'Discount',
              isEditing: false,
            ),
            value: null,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('-'), findsOneWidget);
      });
    });

    group('edit mode', () {
      testWidgets('shows NumberInputBase with % suffix', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooPercentField(
            config: const OdooFieldConfig(
              label: 'Discount',
              isEditing: true,
            ),
            value: 10.0,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(NumberInputBase), findsOneWidget);
        expect(find.text('%'), findsOneWidget);
      });
    });

    group('formatting', () {
      testWidgets('formats with specified decimal places', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooPercentField(
            config: const OdooFieldConfig(
              label: 'Rate',
              isEditing: false,
            ),
            value: 12.345,
            decimals: 2,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('12.35%'), findsOneWidget);
      });
    });
  });

  group('OdooNumberInput', () {
    testWidgets('renders NumberInputBase with stepper buttons',
        (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooNumberInput(
          value: 5,
          onChanged: (_) {},
          showSteppers: true,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byType(NumberInputBase), findsOneWidget);
      // Stepper buttons: remove and add icons
      expect(find.byIcon(FluentIcons.remove), findsOneWidget);
      expect(find.byIcon(FluentIcons.add), findsOneWidget);
    });

    testWidgets('does not show stepper buttons when disabled', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooNumberInput(
          value: 5,
          showSteppers: false,
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.remove), findsNothing);
      expect(find.byIcon(FluentIcons.add), findsNothing);
    });
  });
}
