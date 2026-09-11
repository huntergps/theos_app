import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_dashboard_screen.dart';
import 'package:theos_panel/ui/components/records/orbi_record_list.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

EnvasesDashboardRow _row(String name, {int id = 10}) => EnvasesDashboardRow(
  id: id,
  productId: id,
  productName: name,
  uomId: 1,
  uomName: 'Unidad',
  companyId: 1,
  companyName: 'Empresa',
  totalPropio: 10,
  enSede: 8,
  danados: 1,
  enCustodiaCliente: 2,
  enCustodiaProveedor: 3,
  enTransito: 4,
);

EnvasesDashboardRow _secondRow() => _row('Cerveza', id: 11);

EnvasesDashboardSnapshot _snapshot(String name, {int id = 10}) =>
    EnvasesDashboardSnapshot(
      rows: [_row(name, id: id)],
      cachedAt: DateTime.utc(2026, 9, 11, 15, 30),
    );

Widget _host({
  required Stream<EnvasesDashboardSnapshot?> snapshots,
  bool connected = false,
  VoidCallback? onRefresh,
  Size? size,
}) => MaterialApp(
  home: size == null
      ? EnvasesDashboardScreen(
          snapshots: snapshots,
          workspaceEnvases: 'Envases',
          isConnected: connected,
          onRefresh: onRefresh,
        )
      : MediaQuery(
          data: MediaQueryData(size: size),
          child: EnvasesDashboardScreen(
            snapshots: snapshots,
            workspaceEnvases: 'Envases',
            isConnected: connected,
            onRefresh: onRefresh,
          ),
        ),
);

void main() {
  testWidgets('renders stream updates and local cache label', (tester) async {
    final stream = StreamController<EnvasesDashboardSnapshot?>();
    addTearDown(stream.close);
    await tester.pumpWidget(_host(snapshots: stream.stream));
    stream.add(_snapshot('Cola'));
    await tester.pump();

    expect(find.text('Cola'), findsOneWidget);
    expect(
      find.textContaining('Última descarga en este equipo'),
      findsOneWidget,
    );
    expect(find.text('10 propios'), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);
    expect(find.text('Dañados'), findsOneWidget);
    expect(find.text('Mostrando 1 de 1 registros'), findsOneWidget);
    expect(
      find.textContaining('detalle por ubicación no disponible'),
      findsOneWidget,
    );
  });

  testWidgets('filters locally by product and keeps updated snapshots', (
    tester,
  ) async {
    final stream = StreamController<EnvasesDashboardSnapshot?>();
    addTearDown(stream.close);
    await tester.pumpWidget(_host(snapshots: stream.stream));
    stream.add(
      EnvasesDashboardSnapshot(
        rows: [_row('Cola'), _secondRow()],
        cachedAt: DateTime.utc(2026, 9, 11),
      ),
    );
    await tester.pump();
    await tester.enterText(
      find.byKey(const Key('envases-product-filter')),
      'cerveza',
    );
    await tester.pump();
    expect(find.text('Cerveza'), findsOneWidget);
    expect(find.text('Cola'), findsNothing);
    stream.add(_snapshot('Cerveza', id: 12));
    await tester.pump();
    expect(find.text('Cerveza'), findsOneWidget);
  });

  testWidgets('uses cards compact and grid only wide landscape', (
    tester,
  ) async {
    for (final size in const [
      Size(390, 844),
      Size(768, 1024),
      Size(900, 1200),
      Size(1200, 800),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        _host(
          snapshots: Stream<EnvasesDashboardSnapshot?>.value(_snapshot('Cola')),
          size: size,
        ),
      );
      await tester.pump();
      expect(find.text('Cola'), findsOneWidget);
      final horizontalGrid = size.width >= 840 && size.width >= size.height;
      expect(
        find.byType(SfDataGrid),
        horizontalGrid ? findsOneWidget : findsNothing,
      );
      expect(
        find.byType(OrbiRecordList<EnvasesDashboardRow>),
        horizontalGrid ? findsNothing : findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets('null snapshot is distinct from loaded empty snapshot', (
    tester,
  ) async {
    final stream = StreamController<EnvasesDashboardSnapshot?>();
    addTearDown(stream.close);
    await tester.pumpWidget(_host(snapshots: stream.stream));
    stream.add(null);
    await tester.pump();
    expect(find.text('Sin datos descargados'), findsOneWidget);

    stream.add(
      EnvasesDashboardSnapshot(rows: const [], cachedAt: DateTime.utc(2026)),
    );
    await tester.pump();
    expect(find.text('Sin registros'), findsOneWidget);
  });

  testWidgets('error retains last data and stream replacement clears it', (
    tester,
  ) async {
    final first = StreamController<EnvasesDashboardSnapshot?>();
    final second = StreamController<EnvasesDashboardSnapshot?>();
    addTearDown(first.close);
    addTearDown(second.close);
    await tester.pumpWidget(_host(snapshots: first.stream));
    first.add(_snapshot('Primero'));
    await tester.pump();
    first.addError(StateError('offline'));
    await tester.pump();
    expect(find.text('Primero'), findsOneWidget);
    expect(find.textContaining('Se conserva la última copia'), findsOneWidget);

    await tester.pumpWidget(_host(snapshots: second.stream));
    await tester.pump();
    expect(find.text('Primero'), findsNothing);
    first.add(_snapshot('Tarde'));
    await tester.pump();
    expect(find.text('Tarde'), findsNothing);
    second.add(null);
    await tester.pump();
    expect(find.text('Sin datos descargados'), findsOneWidget);
  });
}
