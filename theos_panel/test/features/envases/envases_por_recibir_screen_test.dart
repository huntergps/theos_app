import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_panel/features/envases/envases_por_recibir_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

final class _FakeEnvasesOperations implements EnvasesOperations {
  final _controller = StreamController<List<EnvasesOperacionLocal>>.broadcast();

  @override
  Future<EnvasesOperacionLocal> darPorPerdido({
    required String operacionUuid,
    required int pickingId,
  }) async => EnvasesOperacionLocal(
    operacionUuid: operacionUuid,
    tipo: 'perdido',
    estado: EnvasesOperacionEstado.pendienteDeEnviar,
    creadaEn: DateTime.now(),
    pickingId: pickingId,
  );

  @override
  Future<EnvasesOperacionLocal> enviar(EnvasesEnviarCommand command) async =>
      throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command) async =>
      throw UnimplementedError();

  @override
  Stream<List<EnvasesOperacionLocal>> watchOperaciones() => _controller.stream;
}

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
  EnvasesOperations? operations,
  bool canManage = false,
  ValueChanged<EnvasesPorRecibirRow>? onRegistrarRecepcion,
}) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: EnvasesPorRecibirScreen(
    snapshots: snapshots,
    operaciones: operaciones ?? const Stream.empty(),
    onOpenDetail: onOpenDetail ?? (_) {},
    operations: operations,
    canManage: canManage,
    onRegistrarRecepcion: onRegistrarRecepcion,
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

  testWidgets('por recibir desktop shows a table with detail panel on selection', (tester) async {
    final controller = StreamController<EnvasesPorRecibirSnapshot?>();
    final operations = _FakeEnvasesOperations();
    addTearDown(operations._controller.close);
    await _pump(
      tester,
      _host(snapshots: controller.stream, operations: operations, canManage: true),
      size: const Size(1920, 1080),
    );
    controller.add(_snapshot([_row(id: 11, origen: 'Guayaquil', destino: 'Manta')]));
    await tester.pumpAndSettle();

    // Antes de elegir una fila: tabla ancha, sin panel — no se cambia el
    // aspecto que ya medían las pruebas anteriores.
    expect(find.byKey(const Key('envases-por-recibir-detalle-panel')), findsNothing);

    await tester.tap(find.text('WH2/IN/000011'));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('envases-por-recibir-detalle-panel')), findsOneWidget);
    expect(find.byKey(const Key('envases-por-recibir-tabla')), findsOneWidget);
    // El panel es el mismo cuerpo de "Detalle de traslado": origen, destino
    // y la acción de registrar recepción, sin navegar a otra página.
    expect(find.text('Guayaquil'), findsWidgets);
    expect(find.text('Manta'), findsWidgets);
    expect(find.byKey(const Key('envases-detalle-recibir')), findsOneWidget);
    expect(find.byKey(const Key('envases-detalle-dar-por-perdido')), findsOneWidget);

    addTearDown(controller.close);
  });

  testWidgets('registrar recepción from the detail panel calls onRegistrarRecepcion', (tester) async {
    final controller = StreamController<EnvasesPorRecibirSnapshot?>();
    final operations = _FakeEnvasesOperations();
    addTearDown(operations._controller.close);
    EnvasesPorRecibirRow? recibido;
    await _pump(
      tester,
      _host(
        snapshots: controller.stream,
        operations: operations,
        onRegistrarRecepcion: (row) => recibido = row,
      ),
      size: const Size(1920, 1080),
    );
    controller.add(_snapshot([_row(id: 11)]));
    await tester.pumpAndSettle();
    await tester.tap(find.text('WH2/IN/000011'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-detalle-recibir')));
    await tester.pumpAndSettle();

    expect(recibido?.id, 11);
    addTearDown(controller.close);
  });

  testWidgets('por recibir has a single search box and a titled detail panel', (tester) async {
    final controller = StreamController<EnvasesPorRecibirSnapshot?>();
    final operations = _FakeEnvasesOperations();
    addTearDown(operations._controller.close);
    await _pump(
      tester,
      _host(snapshots: controller.stream, operations: operations, canManage: true),
      size: const Size(1920, 1080),
    );
    controller.add(_snapshot([_row(id: 11, origen: 'Guayaquil', destino: 'Manta')]));
    await tester.pumpAndSettle();

    // 🔴 Antes había DOS cajas de búsqueda: «Filtrar por sede o documento»
    // arriba de la pantalla y «Buscar en la lista» dentro de `OrbiListing`
    // — la segunda sin ningún `onFilterChanged` que la conectara (queja del
    // dueño, 14-sep-2026).
    expect(find.byKey(const Key('envases-por-recibir-filter')), findsOneWidget);
    expect(find.byKey(const Key('orbi-listing-filter')), findsNothing);

    await tester.tap(find.text('WH2/IN/000011'));
    await tester.pumpAndSettle();

    // 🔴 El panel «al lado» no tenía ningún encabezado — ni el documento ni
    // su estado, así que no decía de qué traslado se trata (queja del
    // dueño, 14-sep-2026). Como en ENV-03 y en «Detalle de traslado» de
    // BODEGA-ENVASES: el documento en negrita y la etiqueta de estado.
    expect(find.byKey(const Key('envases-detalle-titulo')), findsOneWidget);
    expect(tester.widget<Text>(find.byKey(const Key('envases-detalle-titulo'))).data, 'WH2/IN/000011');
    expect(find.text('En tránsito'), findsOneWidget);
  });

  testWidgets('lists render as cards on phone', (tester) async {
    final controller = StreamController<EnvasesPorRecibirSnapshot?>();
    await _pump(tester, _host(snapshots: controller.stream), size: const Size(390, 844));
    controller.add(_snapshot([_row(id: 11)]));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('envases-por-recibir-grouped')), findsOneWidget);
    expect(find.byType(SfDataGrid), findsNothing);
    addTearDown(controller.close);
  });
}
