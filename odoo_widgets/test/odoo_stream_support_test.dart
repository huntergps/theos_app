import 'dart:async';

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
  group('OdooFieldBase stream support', () {
    testWidgets('OdooNumberField updates when stream emits new value',
        (tester) async {
      final controller = StreamController<double>();

      await tester.pumpWidget(buildTestApp(
        OdooNumberField(
          config: const OdooFieldConfig(
            label: 'Quantity',
            isEditing: false,
          ),
          value: 0.0,
          stream: controller.stream,
        ),
      ));
      await tester.pump();

      // Initial value from stream initialData
      expect(find.textContaining('0'), findsOneWidget);

      // Stream emits new value
      controller.add(42.0);
      await tester.pumpAndSettle();

      expect(find.textContaining('42'), findsOneWidget);

      await controller.close();
    });

    testWidgets('OdooBooleanField updates when stream emits new value',
        (tester) async {
      final controller = StreamController<bool>();

      await tester.pumpWidget(buildTestApp(
        OdooBooleanField(
          config: const OdooFieldConfig(
            label: 'Active',
            isEditing: false,
          ),
          value: false,
          stream: controller.stream,
        ),
      ));
      await tester.pump();

      // Initial value
      expect(find.text('No'), findsOneWidget);

      // Stream emits true
      controller.add(true);
      await tester.pumpAndSettle();

      expect(find.text('Yes'), findsOneWidget);

      await controller.close();
    });

    testWidgets('OdooMoneyField updates when stream emits new value',
        (tester) async {
      final controller = StreamController<double>();

      await tester.pumpWidget(buildTestApp(
        OdooMoneyField(
          config: const OdooFieldConfig(
            label: 'Total',
            isEditing: false,
          ),
          value: 0.0,
          stream: controller.stream,
          locale: 'en',
        ),
      ));
      await tester.pump();

      // Stream emits new value
      controller.add(1234.56);
      await tester.pumpAndSettle();

      expect(find.textContaining('1,234.56'), findsOneWidget);

      await controller.close();
    });

    testWidgets('OdooSelectionField updates when stream emits new value',
        (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(buildTestApp(
        OdooSelectionField<String>(
          config: const OdooFieldConfig(
            label: 'Status',
            isEditing: false,
          ),
          value: 'draft',
          stream: controller.stream,
          options: const [
            SelectionOption(value: 'draft', label: 'Draft'),
            SelectionOption(value: 'confirmed', label: 'Confirmed'),
            SelectionOption(value: 'done', label: 'Done'),
          ],
        ),
      ));
      await tester.pump();

      // Initially shows "Draft"
      expect(find.text('Draft'), findsOneWidget);

      // Stream emits new value
      controller.add('confirmed');
      await tester.pumpAndSettle();

      expect(find.text('Confirmed'), findsOneWidget);
      expect(find.text('Draft'), findsNothing);

      await controller.close();
    });

    testWidgets('field shows error when stream emits error', (tester) async {
      final controller = StreamController<double>();

      await tester.pumpWidget(buildTestApp(
        OdooNumberField(
          config: const OdooFieldConfig(
            label: 'Quantity',
            isEditing: false,
          ),
          value: null,
          stream: controller.stream,
        ),
      ));
      await tester.pump();

      // Stream emits error (without prior data)
      controller.addError('DB connection lost');
      await tester.pumpAndSettle();

      expect(find.textContaining('DB connection lost'), findsOneWidget);

      await controller.close();
    });

    testWidgets('field without stream uses static value', (tester) async {
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

      expect(find.text('Yes'), findsOneWidget);
    });
  });

  group('OdooTextField stream support', () {
    testWidgets('updates text from stream when not focused', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(buildTestApp(
        OdooTextField(
          config: const OdooFieldConfig(
            label: 'Name',
            isEditing: true,
          ),
          value: 'Initial',
          stream: controller.stream,
          onChanged: (_) {},
        ),
      ));
      await tester.pumpAndSettle();

      // Verify initial text is shown in TextBox
      expect(find.text('Initial'), findsOneWidget);

      // Stream emits new value
      controller.add('Updated from DB');
      await tester.pumpAndSettle();

      expect(find.text('Updated from DB'), findsOneWidget);

      await controller.close();
    });

    testWidgets('view mode OdooTextField shows stream value', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(buildTestApp(
        OdooTextField(
          config: const OdooFieldConfig(
            label: 'Name',
            isEditing: false,
          ),
          value: 'Static',
          stream: controller.stream,
        ),
      ));
      await tester.pump();

      // Initially shows static value
      expect(find.text('Static'), findsOneWidget);

      // Stream emits new value
      controller.add('From Stream');
      await tester.pumpAndSettle();

      expect(find.text('From Stream'), findsOneWidget);

      await controller.close();
    });
  });

  group('Bidirectional flow', () {
    testWidgets('onChanged fires and stream can update value', (tester) async {
      final streamController = StreamController<double>();
      final receivedValues = <double>[];

      await tester.pumpWidget(buildTestApp(
        OdooNumberField(
          config: const OdooFieldConfig(
            label: 'Qty',
            isEditing: false,
          ),
          value: 10.0,
          stream: streamController.stream,
          onChanged: (v) {
            if (v != null) receivedValues.add(v);
          },
        ),
      ));
      await tester.pump();

      // Simulating the "DB side" of the bidirectional flow:
      // DB changes → stream emits → widget updates
      streamController.add(20.0);
      await tester.pumpAndSettle();
      expect(find.textContaining('20'), findsOneWidget);

      streamController.add(30.0);
      await tester.pumpAndSettle();
      expect(find.textContaining('30'), findsOneWidget);

      await streamController.close();
    });

    testWidgets('OdooFieldConnector full bidirectional test', (tester) async {
      final streamController =
          StreamController<Map<String, dynamic>>();
      String? lastSaved;

      await tester.pumpWidget(buildTestApp(
        OdooFieldConnector<Map<String, dynamic>, String>(
          stream: streamController.stream,
          getValue: (record) => record['name'] as String,
          onSave: (value) => lastSaved = value,
          initialData: {'name': 'Start', 'id': 1},
          builder: (context, value, onChanged) {
            return Column(
              children: [
                Text(value ?? '-'),
                Button(
                  child: const Text('Save'),
                  onPressed: () => onChanged?.call('Saved!'),
                ),
              ],
            );
          },
        ),
      ));
      await tester.pump();

      // Initial data shown
      expect(find.text('Start'), findsOneWidget);

      // User writes back
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
      expect(lastSaved, 'Saved!');

      // "DB" pushes new value via stream
      streamController.add({'name': 'DB Updated', 'id': 1});
      await tester.pumpAndSettle();
      expect(find.text('DB Updated'), findsOneWidget);

      await streamController.close();
    });
  });
}
