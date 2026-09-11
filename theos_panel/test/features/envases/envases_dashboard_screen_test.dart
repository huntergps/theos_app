import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_dashboard_screen.dart';

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

EnvasesDashboardSnapshot _snapshot(String name, {int id = 10}) =>
    EnvasesDashboardSnapshot(
      rows: [_row(name, id: id)],
      cachedAt: DateTime.utc(2026, 9, 11, 15, 30),
    );

Widget _host({
  required Stream<EnvasesDashboardSnapshot?> snapshots,
  bool connected = false,
  VoidCallback? onRefresh,
}) => MaterialApp(
  home: EnvasesDashboardScreen(
    snapshots: snapshots,
    workspaceEnvases: 'Envases',
    isConnected: connected,
    onRefresh: onRefresh,
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
    expect(find.text('10 Unidad'), findsOneWidget);
    expect(find.text('Sin conexión'), findsOneWidget);
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
        ),
      );
      await tester.pump();
      expect(find.text('Cola'), findsOneWidget);
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
