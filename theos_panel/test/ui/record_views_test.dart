import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import 'package:theos_panel/ui/bindings/record_view_controller.dart';
import 'package:theos_panel/ui/components/orbi_record_grid.dart';

void main() {
  final columns = <OrbiRecordColumn<String>>[
    const OrbiRecordColumn(label: 'Nombre', value: _identity),
  ];
  final alternateColumns = <OrbiRecordColumn<String>>[
    const OrbiRecordColumn(label: 'Descripción', value: _identity),
  ];

  OrbiRecordViewController<String> controller() => OrbiRecordViewController(
    records: const [
      OrbiRecord(id: 'a', value: 'A'),
      OrbiRecord(id: 'b', value: 'B'),
    ],
  );

  testWidgets('uses list for compact/medium and Syncfusion grid only wide', (
    tester,
  ) async {
    final view = controller();
    addTearDown(view.dispose);
    for (final width in [390.0, 599.0, 600.0, 839.0]) {
      await tester.binding.setSurfaceSize(Size(width, 480));
      await tester.pumpWidget(
        MaterialApp(
          home: SizedBox.expand(
            child: OrbiRecordGrid(controller: view, columns: columns),
          ),
        ),
      );
      expect(
        find.byType(SfDataGrid),
        findsNothing,
        reason: 'compact/medium must not use a vertical grid at $width',
      );
    }
    await tester.binding.setSurfaceSize(const Size(1000, 480));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: OrbiRecordGrid(controller: view, columns: columns),
        ),
      ),
    );
    expect(find.byType(SfDataGrid), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('selection follows ID across reorder and layout changes', (
    tester,
  ) async {
    final view = controller();
    addTearDown(view.dispose);
    await tester.binding.setSurfaceSize(const Size(1000, 480));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: OrbiRecordGrid(controller: view, columns: columns),
        ),
      ),
    );
    view.select('b');
    view.replaceRecords(const [
      OrbiRecord(id: 'b', value: 'B actualizado'),
      OrbiRecord(id: 'a', value: 'A'),
    ]);
    expect(view.selectedIds, contains('b'));
    await tester.binding.setSurfaceSize(const Size(390, 480));
    await tester.pump();
    expect(view.selectedIds, contains('b'));
    expect(find.text('B actualizado'), findsOneWidget);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('portrait tablet uses cards even when width exceeds 840', (
    tester,
  ) async {
    final view = controller();
    addTearDown(view.dispose);
    await tester.binding.setSurfaceSize(const Size(1024, 1366));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: Size(1024, 1366)),
          child: SizedBox.expand(
            child: OrbiRecordGrid(controller: view, columns: columns),
          ),
        ),
      ),
    );
    expect(find.byType(SfDataGrid), findsNothing);
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('tap selection is restored by ID after reorder and resize', (
    tester,
  ) async {
    final view = controller();
    addTearDown(view.dispose);
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1000, 480));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: OrbiRecordGrid(controller: view, columns: columns),
        ),
      ),
    );
    await tester.tap(find.text('B'));
    await tester.pump();
    expect(view.selectedIds, contains('b'));
    view.replaceRecords(const [
      OrbiRecord(id: 'b', value: 'B'),
      OrbiRecord(id: 'a', value: 'A'),
    ]);
    await tester.pump();
    await tester.binding.setSurfaceSize(const Size(390, 480));
    await tester.pump();
    final node = tester.getSemantics(find.bySemanticsLabel('B'));
    expect(node.flagsCollection.isSelected.name, 'isTrue');
    semantics.dispose();
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('initial selection and changed columns reconcile in place', (
    tester,
  ) async {
    final view = controller();
    view.select('b');
    addTearDown(view.dispose);
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(1000, 480));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: OrbiRecordGrid(controller: view, columns: columns),
        ),
      ),
    );
    await tester.pump();
    await tester.binding.setSurfaceSize(const Size(390, 480));
    await tester.pump();
    expect(
      tester
          .getSemantics(find.bySemanticsLabel('B'))
          .flagsCollection
          .isSelected
          .name,
      'isTrue',
    );
    await tester.binding.setSurfaceSize(const Size(1000, 480));
    await tester.pumpWidget(
      MaterialApp(
        home: SizedBox.expand(
          child: OrbiRecordGrid(controller: view, columns: alternateColumns),
        ),
      ),
    );
    expect(find.text('Descripción'), findsOneWidget);
    semantics.dispose();
    await tester.binding.setSurfaceSize(null);
  });
}

String _identity(String value) => value;
