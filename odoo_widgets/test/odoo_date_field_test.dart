import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
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
  group('OdooDateField', () {
    group('view mode', () {
      testWidgets('displays formatted date in view mode', (tester) async {
        final testDate = DateTime(2025, 3, 15);

        await tester.pumpWidget(buildTestApp(
          OdooDateField(
            config: const OdooFieldConfig(
              label: 'Order Date',
              isEditing: false,
            ),
            value: testDate,
            dateFormat: 'dd/MM/yyyy',
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Order Date:'), findsOneWidget);
        final formatted =
            DateFormat('dd/MM/yyyy', 'en').format(testDate.toLocal());
        expect(find.text(formatted), findsOneWidget);
      });

      testWidgets('displays dash when value is null', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooDateField(
            config: const OdooFieldConfig(
              label: 'Date',
              isEditing: false,
            ),
            value: null,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('-'), findsOneWidget);
      });

      testWidgets('formats date with custom pattern', (tester) async {
        final testDate = DateTime(2025, 12, 25);

        await tester.pumpWidget(buildTestApp(
          OdooDateField(
            config: const OdooFieldConfig(
              label: 'Holiday',
              isEditing: false,
            ),
            value: testDate,
            dateFormat: 'yyyy-MM-dd',
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        final formatted =
            DateFormat('yyyy-MM-dd', 'en').format(testDate.toLocal());
        expect(find.text(formatted), findsOneWidget);
      });

      testWidgets('includes time when showTime is true', (tester) async {
        final testDate = DateTime(2025, 6, 15, 14, 30);

        await tester.pumpWidget(buildTestApp(
          OdooDateField(
            config: const OdooFieldConfig(
              label: 'Meeting',
              isEditing: false,
            ),
            value: testDate,
            showTime: true,
            dateFormat: 'dd/MM/yyyy',
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        final formatted =
            DateFormat('dd/MM/yyyy HH:mm', 'en').format(testDate.toLocal());
        expect(find.text(formatted), findsOneWidget);
      });

      testWidgets('uses inline layout in view mode', (tester) async {
        final testDate = DateTime(2025, 1, 1);

        await tester.pumpWidget(buildTestApp(
          OdooDateField(
            config: const OdooFieldConfig(
              label: 'Start',
              isEditing: false,
            ),
            value: testDate,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        // In inline layout, label shows with colon
        expect(find.text('Start:'), findsOneWidget);
      });

      testWidgets('shows prefix icon when configured', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooDateField(
            config: const OdooFieldConfig(
              label: 'Date',
              isEditing: false,
              prefixIcon: FluentIcons.calendar,
            ),
            value: DateTime(2025, 1, 1),
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byIcon(FluentIcons.calendar), findsOneWidget);
      });
    });

    group('edit mode', () {
      testWidgets('shows date picker button in edit mode', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooDateField(
            config: const OdooFieldConfig(
              label: 'Date',
              isEditing: true,
            ),
            value: DateTime(2025, 5, 10),
            onChanged: (_) {},
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        // The edit mode uses HoverButton for the date picker trigger
        expect(find.byType(HoverButton), findsOneWidget);
      });

      testWidgets('displays formatted date in edit mode button',
          (tester) async {
        final testDate = DateTime(2025, 8, 20);

        await tester.pumpWidget(buildTestApp(
          OdooDateField(
            config: const OdooFieldConfig(
              label: 'Date',
              isEditing: true,
            ),
            value: testDate,
            onChanged: (_) {},
            dateFormat: 'dd/MM/yyyy',
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        final formatted =
            DateFormat('dd/MM/yyyy', 'en').format(testDate.toLocal());
        expect(find.text(formatted), findsOneWidget);
      });

      testWidgets('shows dash in button when no date is set', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooDateField(
            config: const OdooFieldConfig(
              label: 'Due Date',
              isEditing: true,
            ),
            value: null,
            onChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('-'), findsOneWidget);
      });

      testWidgets('shows label beside picker in inline edit layout',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooDateField(
            config: const OdooFieldConfig(
              label: 'Delivery',
              isEditing: true,
            ),
            value: DateTime(2025, 3, 1),
            onChanged: (_) {},
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Delivery:'), findsOneWidget);
      });
    });

    group('formatting', () {
      testWidgets('formats with default dd/MM/yyyy pattern', (tester) async {
        final testDate = DateTime(2025, 11, 5);

        await tester.pumpWidget(buildTestApp(
          OdooDateField(
            config: const OdooFieldConfig(
              label: 'Date',
              isEditing: false,
            ),
            value: testDate,
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        final formatted =
            DateFormat('dd/MM/yyyy', 'en').format(testDate.toLocal());
        expect(find.text(formatted), findsOneWidget);
      });
    });
  });

  group('OdooDateRangeField', () {
    group('view mode', () {
      testWidgets('displays formatted start and end dates', (tester) async {
        final start = DateTime(2025, 1, 1);
        final end = DateTime(2025, 12, 31);
        final formatter = DateFormat('dd/MM/yyyy', 'en');

        await tester.pumpWidget(buildTestApp(
          OdooDateRangeField(
            config: const OdooFieldConfig(
              label: 'Period',
              isEditing: false,
            ),
            startDate: start,
            endDate: end,
            dateFormat: 'dd/MM/yyyy',
            locale: 'en',
          ),
        ));
        await tester.pumpAndSettle();

        final expectedText =
            '${formatter.format(start)} - ${formatter.format(end)}';
        expect(find.text(expectedText), findsOneWidget);
      });

      testWidgets('shows dash for null dates', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooDateRangeField(
            config: const OdooFieldConfig(
              label: 'Range',
              isEditing: false,
            ),
            startDate: null,
            endDate: null,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('- - -'), findsOneWidget);
      });
    });

    group('edit mode', () {
      testWidgets('shows two OdooDateField widgets', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooDateRangeField(
            config: const OdooFieldConfig(
              label: 'Range',
              isEditing: true,
            ),
            startDate: DateTime(2025, 1, 1),
            endDate: DateTime(2025, 6, 30),
            onStartChanged: (_) {},
            onEndChanged: (_) {},
          ),
        ));
        await tester.pumpAndSettle();

        // Should show "From" and "To" labels
        expect(find.text('From:'), findsOneWidget);
        expect(find.text('To:'), findsOneWidget);
      });

      testWidgets('uses custom from/to labels', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooDateRangeField(
            config: const OdooFieldConfig(
              label: 'Range',
              isEditing: true,
            ),
            startDate: DateTime(2025, 1, 1),
            endDate: DateTime(2025, 6, 30),
            onStartChanged: (_) {},
            onEndChanged: (_) {},
            fromLabel: 'Start',
            toLabel: 'End',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Start:'), findsOneWidget);
        expect(find.text('End:'), findsOneWidget);
      });
    });
  });
}
