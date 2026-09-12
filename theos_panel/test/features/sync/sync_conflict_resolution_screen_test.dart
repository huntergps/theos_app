import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/sync/sync_conflict_resolution_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

final class _FakeSyncConflictPort implements SyncConflictPort {
  _FakeSyncConflictPort(List<SyncReviewItem> items) : _items = items;

  final List<SyncReviewItem> _items;
  final _controller = StreamController<List<SyncReviewItem>>.broadcast();
  final decisions = <(int, SyncReviewDecision)>[];

  @override
  List<SyncReviewItem> get items => _items;

  @override
  Stream<List<SyncReviewItem>> get changes => _controller.stream;

  @override
  Future<void> decide(int operationId, SyncReviewDecision decision) async {
    decisions.add((operationId, decision));
  }

  @override
  void dispose() => unawaited(_controller.close());
}

const _conflictItem = SyncReviewItem(
  operationId: 1,
  model: 'sale.order',
  recordId: 14,
  commandLabel: 'Comparación de datos',
  kind: SyncReviewKind.conflict,
  fields: [
    SyncFieldDiff(field: 'price_unit', localValue: 100.0, serverValue: 120.0),
    SyncFieldDiff(field: 'currency', localValue: 'USD', serverValue: 'USD'),
  ],
);

const _uncertainItem = SyncReviewItem(
  operationId: 2,
  model: 'sale.order',
  recordId: 21,
  commandLabel: 'Confirmación de pedido',
  kind: SyncReviewKind.uncertain,
  reason: 'Recovered an operation after an interrupted dispatch without a '
      'server reconciliation contract. Manual review is required.',
  retryCount: 0,
);

const _failedItem = SyncReviewItem(
  operationId: 3,
  model: 'account.move',
  recordId: 55,
  commandLabel: 'Emisión de factura',
  kind: SyncReviewKind.failed,
  reason: 'Op 3 (account.move.invoice_create_with_payments): timeout',
  retryCount: 10,
);

Future<void> _pumpAt(
  WidgetTester tester,
  SyncConflictPort port,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    FluentApp(
      theme: OrbiFluentTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: ScaffoldPage(content: SyncConflictResolutionView(port: port)),
      ),
    ),
  );
}

void main() {
  tearDown(() {});

  testWidgets(
    'an uncertain operation is labelled distinctly and offers no retry',
    (tester) async {
      final port = _FakeSyncConflictPort([_uncertainItem, _failedItem]);
      addTearDown(port.dispose);
      await _pumpAt(tester, port, const Size(393, 852));

      // Select the uncertain item explicitly (list order is stable, but be
      // precise about which document is under test).
      await tester.tap(find.text('sale.order #21 · Incierta'));
      await tester.pumpAndSettle();

      expect(find.text('Incierta'), findsWidgets);
      expect(
        find.textContaining('no llegó confirmación del servidor'),
        findsOneWidget,
      );

      // No BUTTON anywhere in this tree may offer a bare retry: that would
      // be exactly the auto-resend B01 forbids for manual_after_ambiguous
      // operations. (Explanatory prose is allowed to use the word — it is
      // exactly the sentence telling the person retry is unsafe here — so
      // this checks actionable buttons, not every Text node.)
      final buttonLabels = <String>{};
      for (final type in [FilledButton, OutlinedButton, Button]) {
        for (final widget in tester.widgetList(find.byType(type))) {
          final child = (widget as dynamic).child;
          if (child is Text && child.data != null) {
            buttonLabels.add(child.data!);
          }
        }
      }
      expect(
        buttonLabels.where((l) => l.toLowerCase().contains('reintentar')),
        isEmpty,
      );

      // The only two actions offered are the manual, non-resending ones.
      expect(buttonLabels.length, 2);
      expect(buttonLabels, contains('Revisar con supervisor'));
      expect(buttonLabels, contains('Mantener pendiente'));

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'an uncertain operation renders differently than a failed one',
    (tester) async {
      final port = _FakeSyncConflictPort([_uncertainItem, _failedItem]);
      addTearDown(port.dispose);
      await _pumpAt(tester, port, const Size(393, 852));

      expect(find.text('sale.order #21 · Incierta'), findsOneWidget);
      expect(find.text('account.move #55 · Fallida'), findsOneWidget);

      await tester.tap(find.text('account.move #55 · Fallida'));
      await tester.pumpAndSettle();
      expect(
        find.textContaining('Se agotaron los reintentos automáticos'),
        findsOneWidget,
      );
      expect(
        find.textContaining('no llegó confirmación del servidor'),
        findsNothing,
      );

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'keepPending and reviewWithSupervisor never call anything but decide()',
    (tester) async {
      final port = _FakeSyncConflictPort([_uncertainItem]);
      addTearDown(port.dispose);
      await _pumpAt(tester, port, const Size(393, 852));

      await tester.tap(find.widgetWithText(OutlinedButton, 'Mantener pendiente'));
      await tester.pumpAndSettle();
      expect(port.decisions, [(2, SyncReviewDecision.keepPending)]);

      await tester.tap(
        find.widgetWithText(FilledButton, 'Revisar con supervisor'),
      );
      await tester.pumpAndSettle();
      expect(
        port.decisions,
        [(2, SyncReviewDecision.keepPending), (2, SyncReviewDecision.reviewWithSupervisor)],
      );
    },
  );

  testWidgets(
    'a conflict item renders the field-by-field local vs. server comparison',
    (tester) async {
      final port = _FakeSyncConflictPort([_conflictItem]);
      addTearDown(port.dispose);
      // Wide surface so the comparison renders as the Syncfusion grid.
      await _pumpAt(tester, port, const Size(1366, 1024));

      expect(find.text('price_unit'), findsOneWidget);
      expect(find.text('100.0'), findsOneWidget);
      expect(find.text('120.0'), findsOneWidget);
      expect(find.text('Diferente'), findsOneWidget);
      expect(find.text('currency'), findsOneWidget);
      expect(find.text('Sin cambios'), findsOneWidget);

      // The wide/grid family exposes the two-step decision (select, then
      // save) instead of the compact direct-action buttons.
      expect(find.text('Guardar decisión'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'saving a decision on the wide layout requires a selection first',
    (tester) async {
      final port = _FakeSyncConflictPort([_conflictItem]);
      addTearDown(port.dispose);
      await _pumpAt(tester, port, const Size(1920, 1080));

      final saveButtonBefore = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Guardar decisión'),
      );
      expect(saveButtonBefore.onPressed, isNull);

      await tester.tap(find.text('Mantener pendiente'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Guardar decisión'));
      await tester.pumpAndSettle();

      expect(port.decisions, [(1, SyncReviewDecision.keepPending)]);

      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('lists every pending review, closing the missing-list gap', (
    tester,
  ) async {
    final port = _FakeSyncConflictPort([
      _conflictItem,
      _uncertainItem,
      _failedItem,
    ]);
    addTearDown(port.dispose);
    await _pumpAt(tester, port, const Size(1366, 1024));

    expect(find.textContaining('sale.order #14'), findsWidgets);
    expect(find.textContaining('sale.order #21'), findsWidgets);
    expect(find.textContaining('account.move #55'), findsWidgets);

    await tester.binding.setSurfaceSize(null);
  });

  group('composes without overflow at the four approved sizes', () {
    const sizes = {
      'Desktop 1920x1080': Size(1920, 1080),
      'iPad horizontal 1366x1024': Size(1366, 1024),
      'iPad vertical 768x1024': Size(768, 1024),
      'Teléfono 393x852': Size(393, 852),
    };

    for (final entry in sizes.entries) {
      testWidgets(entry.key, (tester) async {
        final port = _FakeSyncConflictPort([
          _conflictItem,
          _uncertainItem,
          _failedItem,
        ]);
        addTearDown(port.dispose);
        await _pumpAt(tester, port, entry.value);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        await tester.binding.setSurfaceSize(null);
      });
    }
  });
}
