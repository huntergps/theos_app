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
  group('OdooContentBuilder', () {
    group('loading state', () {
      testWidgets('shows ProgressRing when stream has no data yet',
          (tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: controller.stream,
            builder: (data) => Text(data),
          ),
        ));
        await tester.pump();

        expect(find.byType(ProgressRing), findsOneWidget);

        await controller.close();
      });

      testWidgets('shows loading message when provided', (tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: controller.stream,
            builder: (data) => Text(data),
            loadingMessage: 'Loading products...',
          ),
        ));
        await tester.pump();

        expect(find.byType(ProgressRing), findsOneWidget);
        expect(find.text('Loading products...'), findsOneWidget);

        await controller.close();
      });

      testWidgets('shows custom loading widget when provided', (tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: controller.stream,
            builder: (data) => Text(data),
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
      testWidgets('renders builder content when stream emits data',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: Stream.value('Hello World'),
            builder: (data) => Text(data),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Hello World'), findsOneWidget);
        expect(find.byType(ProgressRing), findsNothing);
      });

      testWidgets('updates when stream emits new data', (tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: controller.stream,
            builder: (data) => Text(data),
          ),
        ));
        await tester.pump();

        // Initially loading
        expect(find.byType(ProgressRing), findsOneWidget);

        // Emit first value
        controller.add('First');
        await tester.pumpAndSettle();
        expect(find.text('First'), findsOneWidget);

        // Emit second value
        controller.add('Second');
        await tester.pumpAndSettle();
        expect(find.text('Second'), findsOneWidget);
        expect(find.text('First'), findsNothing);

        await controller.close();
      });

      testWidgets('uses initialData while waiting for stream', (tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: controller.stream,
            builder: (data) => Text(data),
            initialData: 'Default',
          ),
        ));
        await tester.pump();

        // Should show initialData, not loading
        expect(find.text('Default'), findsOneWidget);
        expect(find.byType(ProgressRing), findsNothing);

        await controller.close();
      });

      testWidgets('renders list data from stream', (tester) async {
        final items = ['Apple', 'Banana', 'Cherry'];

        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<List<String>>(
            stream: Stream.value(items),
            builder: (data) => Column(
              children: data.map((item) => Text(item)).toList(),
            ),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Apple'), findsOneWidget);
        expect(find.text('Banana'), findsOneWidget);
        expect(find.text('Cherry'), findsOneWidget);
      });
    });

    group('error state', () {
      testWidgets('shows error InfoBar when stream has error', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: Stream.error('Network error'),
            builder: (data) => Text(data),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.byType(InfoBar), findsOneWidget);
        expect(find.text('Error loading data'), findsOneWidget);
        expect(find.textContaining('Network error'), findsOneWidget);
      });

      testWidgets('shows custom error title', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: Stream.error('Connection failed'),
            builder: (data) => Text(data),
            errorTitle: 'Connection Error',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Connection Error'), findsOneWidget);
      });

      testWidgets('shows retry button when onRetry is provided',
          (tester) async {
        bool retryClicked = false;

        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: Stream.error('Failed'),
            builder: (data) => Text(data),
            onRetry: () => retryClicked = true,
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsOneWidget);
        expect(find.byType(FilledButton), findsOneWidget);

        await tester.tap(find.text('Retry'));
        await tester.pumpAndSettle();

        expect(retryClicked, true);
      });

      testWidgets('does not show retry button when onRetry is null',
          (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: Stream.error('Failed'),
            builder: (data) => Text(data),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Retry'), findsNothing);
        expect(find.byType(FilledButton), findsNothing);
      });

      testWidgets('uses custom retry label', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: Stream.error('Failed'),
            builder: (data) => Text(data),
            onRetry: () {},
            retryLabel: 'Try Again',
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Try Again'), findsOneWidget);
      });

      testWidgets('shows custom error builder when provided', (tester) async {
        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: Stream.error('Custom error'),
            builder: (data) => Text(data),
            errorBuilder: (error, stack) => Text('Custom: $error'),
          ),
        ));
        await tester.pumpAndSettle();

        expect(find.text('Custom: Custom error'), findsOneWidget);
        expect(find.byType(InfoBar), findsNothing);
      });

      testWidgets('shows error after initial data was displayed',
          (tester) async {
        final controller = StreamController<String>();

        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: controller.stream,
            builder: (data) => Text(data),
          ),
        ));
        await tester.pump();

        // Emit data first
        controller.add('Initial data');
        await tester.pumpAndSettle();
        expect(find.text('Initial data'), findsOneWidget);

        // Then emit error
        controller.addError('Something went wrong');
        await tester.pumpAndSettle();
        expect(find.byType(InfoBar), findsOneWidget);

        await controller.close();
      });
    });

    group('stream lifecycle', () {
      testWidgets('handles stream that completes without emitting',
          (tester) async {
        final controller = StreamController<String>();
        controller.close();

        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<String>(
            stream: controller.stream,
            builder: (data) => Text(data),
          ),
        ));
        // Use pump() instead of pumpAndSettle() because ProgressRing
        // continuously animates and causes pumpAndSettle to time out.
        await tester.pump();

        // Should show loading since no data was emitted
        expect(find.byType(ProgressRing), findsOneWidget);
      });

      testWidgets('handles StreamController with multiple emissions',
          (tester) async {
        final controller = StreamController<int>();

        await tester.pumpWidget(buildTestApp(
          OdooContentBuilder<int>(
            stream: controller.stream,
            builder: (data) => Text('Count: $data'),
          ),
        ));
        await tester.pump();

        controller.add(1);
        await tester.pumpAndSettle();
        expect(find.text('Count: 1'), findsOneWidget);

        controller.add(2);
        await tester.pumpAndSettle();
        expect(find.text('Count: 2'), findsOneWidget);

        controller.add(3);
        await tester.pumpAndSettle();
        expect(find.text('Count: 3'), findsOneWidget);

        await controller.close();
      });
    });
  });

  group('OdooStreamExtension', () {
    testWidgets('builds content using stream extension method', (tester) async {
      final stream = Stream.value('Extension works');

      await tester.pumpWidget(buildTestApp(
        stream.buildContent(
          builder: (data) => Text(data),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Extension works'), findsOneWidget);
    });

    testWidgets('extension method handles errors', (tester) async {
      final stream = Stream<String>.error('Ext error');

      await tester.pumpWidget(buildTestApp(
        stream.buildContent(
          builder: (data) => Text(data),
          errorTitle: 'Extension Error',
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('Extension Error'), findsOneWidget);
    });

    testWidgets('extension method shows loading', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(buildTestApp(
        controller.stream.buildContent(
          builder: (data) => Text(data),
          loadingMessage: 'Please wait...',
        ),
      ));
      await tester.pump();

      expect(find.byType(ProgressRing), findsOneWidget);
      expect(find.text('Please wait...'), findsOneWidget);

      await controller.close();
    });

    testWidgets('extension method with initialData', (tester) async {
      final controller = StreamController<String>();

      await tester.pumpWidget(buildTestApp(
        controller.stream.buildContent(
          builder: (data) => Text(data),
          initialData: 'Preloaded',
        ),
      ));
      await tester.pump();

      expect(find.text('Preloaded'), findsOneWidget);

      await controller.close();
    });
  });
}
