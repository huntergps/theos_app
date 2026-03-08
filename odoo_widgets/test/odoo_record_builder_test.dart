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
  group('OdooRecordBuilder', () {
    group('loading state', () {
      testWidgets('shows ProgressRing when stream has no data yet',
          (tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(buildTestApp(
          OdooRecordBuilder<String>(
            stream: controller.stream,
            builder: (context, data) => Text(data),
          ),
        ));
        await tester.pump();

        expect(find.byType(ProgressRing), findsOneWidget);

        await controller.close();
      });

      testWidgets('shows custom loading widget when provided', (tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(buildTestApp(
          OdooRecordBuilder<String>(
            stream: controller.stream,
            builder: (context, data) => Text(data),
            loading: const Text('Custom loading...'),
          ),
        ));
        await tester.pump();

        expect(find.text('Custom loading...'), findsOneWidget);
        expect(find.byType(ProgressRing), findsNothing);

        await controller.close();
      });
    });

    group('data state', () {
      testWidgets('renders builder when stream emits data', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooRecordBuilder<String>(
            stream: Stream.value('Hello'),
            builder: (context, data) => Text(data),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Hello'), findsOneWidget);
        expect(find.byType(ProgressRing), findsNothing);
      });

      testWidgets('uses initialData before stream emits', (tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(buildTestApp(
          OdooRecordBuilder<String>(
            stream: controller.stream,
            builder: (context, data) => Text(data),
            initialData: 'Initial',
          ),
        ));
        await tester.pump();

        expect(find.text('Initial'), findsOneWidget);
        expect(find.byType(ProgressRing), findsNothing);

        await controller.close();
      });

      testWidgets('updates when stream emits multiple values', (tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(buildTestApp(
          OdooRecordBuilder<String>(
            stream: controller.stream,
            builder: (context, data) => Text(data),
          ),
        ));
        await tester.pump();

        controller.add('First');
        await tester.pumpAndSettle();
        expect(find.text('First'), findsOneWidget);

        controller.add('Second');
        await tester.pumpAndSettle();
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('First'), findsNothing);

        await controller.close();
      });
    });

    group('error state', () {
      testWidgets('shows default error row when stream has error',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooRecordBuilder<String>(
            stream: Stream.error('Network error'),
            builder: (context, data) => Text(data),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.textContaining('Network error'), findsOneWidget);
        expect(find.byIcon(FluentIcons.error), findsOneWidget);
      });

      testWidgets('uses custom errorBuilder when provided', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooRecordBuilder<String>(
            stream: Stream.error('Custom fail'),
            builder: (context, data) => Text(data),
            errorBuilder: (error, stack) => Text('ERR: $error'),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('ERR: Custom fail'), findsOneWidget);
      });
    });
  });

  group('OdooFieldConnector', () {
    group('data state', () {
      testWidgets('extracts field value from record stream', (tester) async {
        final stream = Stream.value({'name': 'Acme Corp', 'id': 1});

        await tester.pumpWidget(buildTestApp(
          OdooFieldConnector<Map<String, dynamic>, String>(
            stream: stream,
            getValue: (record) => record['name'] as String,
            builder: (context, value, onChanged) => Text(value ?? '-'),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Acme Corp'), findsOneWidget);
      });

      testWidgets('shows null value before stream emits', (tester) async {
        final controller = StreamController<Map<String, dynamic>>();

        await tester.pumpWidget(buildTestApp(
          OdooFieldConnector<Map<String, dynamic>, String>(
            stream: controller.stream,
            getValue: (record) => record['name'] as String,
            builder: (context, value, onChanged) =>
                Text(value ?? 'No data'),
          ),
        ));
        await tester.pump();

        expect(find.text('No data'), findsOneWidget);

        await controller.close();
      });

      testWidgets('uses initialData before stream emits', (tester) async {
        final controller = StreamController<Map<String, dynamic>>();

        await tester.pumpWidget(buildTestApp(
          OdooFieldConnector<Map<String, dynamic>, String>(
            stream: controller.stream,
            getValue: (record) => record['name'] as String,
            initialData: {'name': 'Default', 'id': 0},
            builder: (context, value, onChanged) =>
                Text(value ?? 'No data'),
          ),
        ));
        await tester.pump();

        expect(find.text('Default'), findsOneWidget);

        await controller.close();
      });

      testWidgets('updates when stream emits new record', (tester) async {
        final controller = StreamController<Map<String, dynamic>>();

        await tester.pumpWidget(buildTestApp(
          OdooFieldConnector<Map<String, dynamic>, String>(
            stream: controller.stream,
            getValue: (record) => record['name'] as String,
            builder: (context, value, onChanged) => Text(value ?? '-'),
          ),
        ));
        await tester.pump();

        controller.add({'name': 'First', 'id': 1});
        await tester.pumpAndSettle();
        expect(find.text('First'), findsOneWidget);

        controller.add({'name': 'Updated', 'id': 1});
        await tester.pumpAndSettle();
        expect(find.text('Updated'), findsOneWidget);

        await controller.close();
      });
    });

    group('onSave callback', () {
      testWidgets('provides onChanged when onSave is set', (tester) async {
        String? savedValue;

        await tester.pumpWidget(buildTestApp(
          OdooFieldConnector<Map<String, dynamic>, String>(
            stream: Stream.value({'name': 'Test', 'id': 1}),
            getValue: (record) => record['name'] as String,
            onSave: (value) => savedValue = value,
            builder: (context, value, onChanged) {
              return Button(
                child: const Text('Save'),
                onPressed: () => onChanged?.call('New Name'),
              );
            },
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Save'));
        await tester.pumpAndSettle();

        expect(savedValue, 'New Name');
      });

      testWidgets('onChanged is null when onSave is null', (tester) async {
        ValueChanged<String?>? capturedOnChanged;

        await tester.pumpWidget(buildTestApp(
          OdooFieldConnector<Map<String, dynamic>, String>(
            stream: Stream.value({'name': 'Test', 'id': 1}),
            getValue: (record) => record['name'] as String,
            builder: (context, value, onChanged) {
              capturedOnChanged = onChanged;
              return Text(value ?? '-');
            },
          ),
        ));
        await tester.pumpAndSettle();

        expect(capturedOnChanged, isNull);
      });

      testWidgets('does not call onSave when newValue is null',
          (tester) async {
        bool onSaveCalled = false;

        await tester.pumpWidget(buildTestApp(
          OdooFieldConnector<Map<String, dynamic>, String>(
            stream: Stream.value({'name': 'Test', 'id': 1}),
            getValue: (record) => record['name'] as String,
            onSave: (value) => onSaveCalled = true,
            builder: (context, value, onChanged) {
              return Button(
                child: const Text('Clear'),
                onPressed: () => onChanged?.call(null),
              );
            },
          ),
        ));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Clear'));
        await tester.pumpAndSettle();

        expect(onSaveCalled, false);
      });
    });
  });

  group('OdooRecordStreamExtension', () {
    testWidgets('.buildRecord() creates OdooRecordBuilder', (tester) async {
      final stream = Stream.value('Extension data');

      await tester.pumpWidget(buildTestApp(
        stream.buildRecord(
          builder: (context, data) => Text(data),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Extension data'), findsOneWidget);
    });

    testWidgets('.buildRecord() with initialData', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(buildTestApp(
        controller.stream.buildRecord(
          builder: (context, data) => Text(data),
          initialData: 'Preloaded',
        ),
      ));
      await tester.pump();

      expect(find.text('Preloaded'), findsOneWidget);

      await controller.close();
    });

    testWidgets('.connectField() extracts value and provides onChanged',
        (tester) async {
      String? savedValue;
      final stream =
          Stream.value({'name': 'Partner', 'id': 42});

      await tester.pumpWidget(buildTestApp(
        stream.connectField<String>(
          getValue: (record) => record['name'] as String,
          onSave: (value) => savedValue = value,
          builder: (context, value, onChanged) {
            return Column(
              children: [
                Text(value ?? '-'),
                Button(
                  child: const Text('Update'),
                  onPressed: () => onChanged?.call('New Partner'),
                ),
              ],
            );
          },
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Partner'), findsOneWidget);

      await tester.tap(find.text('Update'));
      await tester.pumpAndSettle();

      expect(savedValue, 'New Partner');
    });

    testWidgets('.connectField() shows null before stream emits',
        (tester) async {
      final controller = StreamController<Map<String, dynamic>>();

      await tester.pumpWidget(buildTestApp(
        controller.stream.connectField<String>(
          getValue: (record) => record['name'] as String,
          builder: (context, value, onChanged) =>
              Text(value ?? 'Waiting...'),
        ),
      ));
      await tester.pump();

      expect(find.text('Waiting...'), findsOneWidget);

      await controller.close();
    });
  });
}
