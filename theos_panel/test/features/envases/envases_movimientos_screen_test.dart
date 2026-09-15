import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_panel/features/envases/envases_movimientos_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

EnvasesMovimientoRow _row({int id = 1, DateTime? date}) => EnvasesMovimientoRow(
  id: id,
  date: date ?? DateTime.utc(2026, 9, 1, 8),
  productId: 50,
  productName: 'Jaba 12',
  quantity: 3,
  desde: 'Guayaquil - Sede',
  hacia: 'Tránsito Guayaquil → Manta',
  warehouseId: 1,
  warehouseName: 'Guayaquil',
  responsableId: 9,
  responsableName: 'Ana',
  pickingId: 11,
  pickingName: 'WH2/IN/000011',
);

Widget _host(Stream<EnvasesMovimientosSnapshot?> snapshots) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: EnvasesMovimientosScreen(snapshots: snapshots),
);

void main() {
  testWidgets('renders movements from the cache', (tester) async {
    final controller = StreamController<EnvasesMovimientosSnapshot?>();
    await tester.pumpWidget(_host(controller.stream));
    controller.add(EnvasesMovimientosSnapshot(rows: [_row()], cachedAt: DateTime.utc(2026, 9, 11)));
    await tester.pumpAndSettle();

    expect(find.text('Jaba 12'), findsOneWidget);
    expect(find.text('WH2/IN/000011'), findsOneWidget);
    addTearDown(controller.close);
  });

  testWidgets('tapping a row opens its detail dialog', (tester) async {
    final controller = StreamController<EnvasesMovimientosSnapshot?>();
    await tester.pumpWidget(_host(controller.stream));
    controller.add(EnvasesMovimientosSnapshot(rows: [_row()], cachedAt: DateTime.utc(2026, 9, 11)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Jaba 12'));
    await tester.pumpAndSettle();

    expect(find.text('Responsable: Ana'), findsOneWidget);
    addTearDown(controller.close);
  });

  testWidgets('lists render as cards on phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = StreamController<EnvasesMovimientosSnapshot?>();
    await tester.pumpWidget(_host(controller.stream));
    controller.add(EnvasesMovimientosSnapshot(rows: [_row()], cachedAt: DateTime.utc(2026, 9, 11)));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orbi-listing-cards')), findsOneWidget);
    expect(find.byType(SfDataGrid), findsNothing);
    expect(find.text('Jaba 12'), findsOneWidget);
    addTearDown(controller.close);
  });

  testWidgets('the free-text filter actually narrows the rows (was dead in 90a37dc)', (tester) async {
    final controller = StreamController<EnvasesMovimientosSnapshot?>();
    await tester.pumpWidget(_host(controller.stream));
    controller.add(
      EnvasesMovimientosSnapshot(
        rows: [_row(id: 1), _row(id: 2)],
        cachedAt: DateTime.utc(2026, 9, 11),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Jaba 12'), findsNWidgets(2));

    await tester.enterText(find.byKey(const Key('orbi-listing-filter')), 'no coincide con nada');
    await tester.pumpAndSettle();

    expect(find.text('Jaba 12'), findsNothing);
    addTearDown(controller.close);
  });
}
