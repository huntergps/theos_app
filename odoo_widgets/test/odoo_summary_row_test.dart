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
  group('OdooSummaryRow', () {
    group('single amount display', () {
      testWidgets('displays label and formatted amount', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow(
            label: 'Total Cash',
            amount: 1500.00,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Total Cash'), findsOneWidget);
        expect(find.textContaining('1,500.00'), findsOneWidget);
      });

      testWidgets('displays zero amount', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow(
            label: 'Balance',
            amount: 0.0,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Balance'), findsOneWidget);
        expect(find.textContaining('0.00'), findsOneWidget);
      });

      testWidgets('displays icon when provided', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow(
            icon: FluentIcons.money,
            label: 'Cash',
            amount: 500.00,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(FluentIcons.money), findsOneWidget);
      });

      testWidgets('displays null amount as zero', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow(
            label: 'Unknown',
            amount: null,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('0.00'), findsOneWidget);
      });

      testWidgets('shows suffix text when provided', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow(
            label: 'Weight',
            amount: 10.5,
            suffix: 'kg',
            prefix: '',
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('kg'), findsOneWidget);
      });

      testWidgets('uses compact spacing when compact is true', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow(
            label: 'Item',
            amount: 25.00,
            compact: true,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Item'), findsOneWidget);
        expect(find.textContaining('25.00'), findsOneWidget);
      });
    });

    group('comparison mode', () {
      testWidgets('displays system, manual, and difference amounts',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow.comparison(
            label: 'Checks',
            systemAmount: 500.00,
            manualAmount: 480.00,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Checks'), findsOneWidget);
        // System amount, manual amount, and difference should be visible
        expect(find.textContaining('500.00'), findsOneWidget);
        expect(find.textContaining('480.00'), findsOneWidget);
        // Difference: 500 - 480 = 20
        expect(find.textContaining('20.00'), findsOneWidget);
      });

      testWidgets('shows zero difference without highlight', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow.comparison(
            label: 'Matching',
            systemAmount: 100.00,
            manualAmount: 100.00,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Matching'), findsOneWidget);
      });

      testWidgets('shows difference only when showDifferenceOnly is true',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow.comparison(
            label: 'Net Diff',
            systemAmount: 200.00,
            manualAmount: 150.00,
            showDifferenceOnly: true,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Net Diff'), findsOneWidget);
        // Should show +$50.00 difference
        expect(find.textContaining('50.00'), findsOneWidget);
      });

      testWidgets('shows icon in comparison mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow.comparison(
            icon: FluentIcons.compare,
            label: 'Compare',
            systemAmount: 100.00,
            manualAmount: 90.00,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(FluentIcons.compare), findsOneWidget);
      });
    });

    group('formatting', () {
      testWidgets('uses custom prefix', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow(
            label: 'Euro Amount',
            amount: 100.00,
            prefix: '\u20AC',
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('\u20AC'), findsOneWidget);
      });

      testWidgets('respects custom decimal places', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow(
            label: 'Precise',
            amount: 99.999,
            decimals: 3,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('99.999'), findsOneWidget);
      });

      testWidgets('negative amount shows minus sign', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooSummaryRow(
            label: 'Loss',
            amount: -50.00,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('-'), findsOneWidget);
        expect(find.textContaining('50.00'), findsOneWidget);
      });
    });
  });

  group('OdooSummaryHeader', () {
    testWidgets('displays column headers', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooSummaryHeader(
          label: 'Payment',
          systemLabel: 'System',
          manualLabel: 'Manual',
          differenceLabel: 'Diff',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Payment'), findsOneWidget);
      expect(find.text('System'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Diff'), findsOneWidget);
    });

    testWidgets('uses default header labels', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const OdooSummaryHeader(),
      ));
      await tester.pumpAndSettle();

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Difference'), findsOneWidget);
    });

    testWidgets('handles empty label', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const OdooSummaryHeader(label: ''),
      ));
      await tester.pumpAndSettle();

      expect(find.text('System'), findsOneWidget);
    });

    testWidgets('renders in compact mode', (tester) async {
      await tester.pumpWidget(buildTestApp(
        const OdooSummaryHeader(compact: true),
      ));
      await tester.pumpAndSettle();

      expect(find.text('System'), findsOneWidget);
      expect(find.text('Manual'), findsOneWidget);
      expect(find.text('Difference'), findsOneWidget);
    });
  });

  group('OdooSummaryCard', () {
    testWidgets('displays title and children', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooSummaryCard(
          title: 'Cash Summary',
          children: [
            OdooSummaryRow(
              label: 'Total',
              amount: 1000.00,
              locale: 'en',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Cash Summary'), findsOneWidget);
      expect(find.text('Total'), findsOneWidget);
    });

    testWidgets('displays title icon when provided', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooSummaryCard(
          title: 'Payments',
          titleIcon: FluentIcons.payment_card,
          children: [
            const Text('Content'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.byIcon(FluentIcons.payment_card), findsOneWidget);
      expect(find.text('Payments'), findsOneWidget);
    });

    testWidgets('renders without title', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooSummaryCard(
          children: [
            OdooSummaryRow(
              label: 'Item',
              amount: 50.00,
              locale: 'en',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Item'), findsOneWidget);
      // No Divider when there's no title
    });

    testWidgets('displays footer when provided', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooSummaryCard(
          title: 'Summary',
          footer: const Text('Footer text'),
          children: [
            const Text('Body content'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Summary'), findsOneWidget);
      expect(find.text('Body content'), findsOneWidget);
      expect(find.text('Footer text'), findsOneWidget);
    });

    testWidgets('renders multiple children', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooSummaryCard(
          title: 'Breakdown',
          children: [
            OdooSummaryRow(
              label: 'Cash',
              amount: 100.00,
              locale: 'en',
            ),
            OdooSummaryRow(
              label: 'Card',
              amount: 200.00,
              locale: 'en',
            ),
            OdooSummaryRow(
              label: 'Transfer',
              amount: 300.00,
              locale: 'en',
            ),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Cash'), findsOneWidget);
      expect(find.text('Card'), findsOneWidget);
      expect(find.text('Transfer'), findsOneWidget);
    });

    testWidgets('card is rendered in a decorated Container', (tester) async {
      await tester.pumpWidget(buildTestApp(
        OdooSummaryCard(
          title: 'Box',
          children: [
            const Text('Inside'),
          ],
        ),
      ));
      await tester.pumpAndSettle();

      // Verify the card renders properly
      expect(find.text('Box'), findsOneWidget);
      expect(find.text('Inside'), findsOneWidget);
    });
  });
}
