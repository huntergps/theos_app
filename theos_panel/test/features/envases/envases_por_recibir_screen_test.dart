import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_por_recibir_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

EnvasesPorRecibirRow _row({
  int id = 11,
  String origen = 'Guayaquil',
  String destino = 'Manta',
  double pendientes = 5,
}) => EnvasesPorRecibirRow(
  id: id,
  name: 'WH2/IN/0000$id',
  fechaSalida: DateTime.utc(2026, 9, 1, 8),
  origenId: 1,
  origenName: origen,
  destinoId: 2,
  destinoName: destino,
  unidadesPendientes: pendientes,
);

EnvasesPorRecibirSnapshot _snapshot(List<EnvasesPorRecibirRow> rows) =>
    EnvasesPorRecibirSnapshot(rows: rows, cachedAt: DateTime.utc(2026, 9, 11, 15, 30));

Future<void> _pump(
  WidgetTester tester,
  Widget host, {
  Size size = const Size(1280, 900),
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host);
}

Widget _host({
  required Stream<EnvasesPorRecibirSnapshot?> snapshots,
  Stream<List<EnvasesOperacionLocal>>? operaciones,
  ValueChanged<EnvasesPorRecibirRow>? onOpenDetail,
}) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: EnvasesPorRecibirScreen(
    snapshots: snapshots,
    operaciones: operaciones ?? const Stream.empty(),
    onOpenDetail: onOpenDetail ?? (_) {},
  ),
);

void main() {
  testWidgets('renders a wide table with pending transfers', (tester) async {
    final controller = StreamController<EnvasesPorRecibirSnapshot?>();
    await _pump(tester, _host(snapshots: controller.stream));
    controller.add(_snapshot([_row()]));
    await tester.pumpAndSettle();

    expect(find.text('WH2/IN/000011'), findsOneWidget);
    expect(find.byKey(const Key('envases-por-recibir-grouped')), findsNothing);
    addTearDown(controller.close);
  });

  testWidgets('groups rows by sentido (origen → destino) in phone width', (tester) async {
    final controller = StreamController<EnvasesPorRecibirSnapshot?>();
    await _pump(tester, _host(snapshots: controller.stream), size: const Size(390, 844));
    controller.add(
      _snapshot([
        _row(id: 11, origen: 'Guayaquil', destino: 'Manta'),
        _row(id: 12, origen: 'Guayaquil', destino: 'Manta'),
        _row(id: 13, origen: 'Quito', destino: 'Cuenca'),
      ]),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('envases-por-recibir-grouped')), findsOneWidget);
    expect(find.byKey(const Key('envases-grupo-Guayaquil → Manta')), findsOneWidget);
    expect(find.byKey(const Key('envases-grupo-Quito → Cuenca')), findsOneWidget);
    addTearDown(controller.close);
  });

  testWidgets('shows local operation status alongside a pending row', (tester) async {
    final controller = StreamController<EnvasesPorRecibirSnapshot?>();
    final operacionesController = StreamController<List<EnvasesOperacionLocal>>();
    await _pump(
      tester,
      _host(snapshots: controller.stream, operaciones: operacionesController.stream),
      size: const Size(390, 844),
    );
    controller.add(_snapshot([_row(id: 11)]));
    operacionesController.add([
      EnvasesOperacionLocal(
        operacionUuid: 'u1',
        tipo: 'recepcion',
        estado: EnvasesOperacionEstado.pendienteDeEnviar,
        creadaEn: DateTime.utc(2026, 9, 11),
        pickingId: 11,
      ),
    ]);
    await tester.pumpAndSettle();

    expect(find.text('Pendiente de enviar'), findsOneWidget);
    addTearDown(controller.close);
    addTearDown(operacionesController.close);
  });

  testWidgets('tapping a row opens its detail', (tester) async {
    final controller = StreamController<EnvasesPorRecibirSnapshot?>();
    EnvasesPorRecibirRow? tapped;
    await _pump(
      tester,
      _host(snapshots: controller.stream, onOpenDetail: (row) => tapped = row),
      size: const Size(390, 844),
    );
    controller.add(_snapshot([_row(id: 11)]));
    await tester.pumpAndSettle();

    await tester.tap(find.text('WH2/IN/000011'));
    await tester.pumpAndSettle();

    expect(tapped?.id, 11);
    addTearDown(controller.close);
  });
}
