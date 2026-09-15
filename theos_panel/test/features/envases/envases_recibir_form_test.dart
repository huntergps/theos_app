import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_form_draft_port.dart';
import 'package:theos_panel/features/envases/envases_recibir_form.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Puerto de borrador en memoria, para no arrastrar Drift a estos tests de
/// widget: sólo necesitan ver qué se leyó, guardó y borró.
final class _FakeDraftPort implements EnvasesFormDraftPort {
  final Map<String, Map<String, dynamic>> stored = {};
  final List<String> cleared = [];

  void seed(String draftId, Map<String, dynamic> payload) => stored[draftId] = payload;

  @override
  Future<Map<String, dynamic>?> read(String draftId) async => stored[draftId];

  @override
  Future<void> save(String draftId, Map<String, dynamic> payload) async => stored[draftId] = payload;

  @override
  Future<void> clear(String draftId) async {
    stored.remove(draftId);
    cleared.add(draftId);
  }
}

final class _FakeEnvasesOperations implements EnvasesOperations {
  EnvasesRecibirCommand? recibido;

  @override
  Future<EnvasesOperacionLocal> darPorPerdido({required String operacionUuid, required int pickingId}) async =>
      throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> enviar(EnvasesEnviarCommand command) async => throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command) async {
    recibido = command;
    return EnvasesOperacionLocal(
      operacionUuid: command.operacionUuid,
      tipo: 'recepcion',
      estado: EnvasesOperacionEstado.pendienteDeEnviar,
      creadaEn: DateTime.now(),
      pickingId: command.pickingId,
    );
  }

  @override
  Stream<List<EnvasesOperacionLocal>> watchOperaciones() => const Stream.empty();
}

EnvasesPorRecibirRow _row() => EnvasesPorRecibirRow(
  id: 11,
  name: 'WH2/IN/000011',
  unidadesPendientes: 8,
);

EnvasesPickingLineaRow _linea({double pendientes = 8}) => EnvasesPickingLineaRow(
  moveId: 1,
  productId: 50,
  productName: 'Jaba 12',
  uomId: 1,
  uomName: 'Unidades',
  pendientes: pendientes,
);

Widget _host({
  required EnvasesOperations operations,
  VoidCallback? onCompleted,
  EnvasesFormDraftPort? draftPort,
  double pendientes = 8,
}) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: EnvasesRecibirForm(
    row: _row(),
    lineasLoader: () async => [_linea(pendientes: pendientes)],
    operations: operations,
    onCompleted: onCompleted,
    draftPort: draftPort,
  ),
);

/// `NumberBox` (a diferencia del `TextBox` que reemplaza) sólo actualiza su
/// `value` cuando pierde el foco o recibe una acción de envío — nunca en
/// cada tecla — así que cada prueba que teclea una cantidad tiene que cerrar
/// la edición explícitamente para que el `onChanged` del formulario corra.
Future<void> _commitNumberBox(WidgetTester tester) async {
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pump();
}

void main() {
  testWidgets('defaults llegaron to pendientes and enables saving', (tester) async {
    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(_host(operations: operations));
    await tester.pumpAndSettle();

    expect(tester.widget<NumberBox<double>>(find.byKey(const Key('envases-recibir-llegaron-1'))).value, 8);
    final guardar = tester.widget<FilledButton>(find.byKey(const Key('envases-recibir-guardar')));
    expect(guardar.onPressed, isNotNull);
  });

  testWidgets('rejects danadas greater than llegaron', (tester) async {
    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(_host(operations: operations));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-recibir-llegaron-1')), '4');
    await _commitNumberBox(tester);
    await tester.enterText(find.byKey(const Key('envases-recibir-danadas-1')), '5');
    await _commitNumberBox(tester);
    await tester.pumpAndSettle();

    expect(find.text('Las dañadas no pueden ser más de lo que llegó.'), findsOneWidget);
    final guardar = tester.widget<FilledButton>(find.byKey(const Key('envases-recibir-guardar')));
    expect(guardar.onPressed, isNull);
  });

  testWidgets('rejects llegaron greater than pendientes', (tester) async {
    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(_host(operations: operations));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-recibir-llegaron-1')), '9');
    await _commitNumberBox(tester);
    await tester.pumpAndSettle();

    expect(find.text('No puede llegar más de lo que salió.'), findsOneWidget);
  });

  testWidgets('rejects negative quantities', (tester) async {
    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(_host(operations: operations));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-recibir-danadas-1')), '-1');
    await _commitNumberBox(tester);
    await tester.pumpAndSettle();

    expect(find.text('No puede ser negativo.'), findsOneWidget);
  });

  testWidgets('saving calls recibir with a non-empty uuid and the entered quantities', (tester) async {
    final operations = _FakeEnvasesOperations();
    var completed = false;
    await tester.pumpWidget(_host(operations: operations, onCompleted: () => completed = true));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-recibir-llegaron-1')), '6');
    await _commitNumberBox(tester);
    await tester.enterText(find.byKey(const Key('envases-recibir-danadas-1')), '1');
    await _commitNumberBox(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-recibir-guardar')));
    await tester.pumpAndSettle();

    expect(operations.recibido, isNotNull);
    expect(operations.recibido!.pickingId, 11);
    expect(operations.recibido!.operacionUuid, isNotEmpty);
    expect(operations.recibido!.lineas.single.llegaron, 6);
    expect(operations.recibido!.lineas.single.danadas, 1);
    expect(operations.recibido!.lineas.single.productId, 50);
    expect(completed, isTrue);
    expect(
      find.text('Guardado en este equipo. Se envía a Odoo en cuanto haya conexión.'),
      findsOneWidget,
    );
  });

  testWidgets('recepción restores arrived and damaged per line after lines load', (tester) async {
    final port = _FakeDraftPort()
      ..seed(envasesRecepcionDraftId(11), {
        'v': 1,
        'lineas': [
          {'moveId': 1, 'llegaron': 6, 'danadas': 2},
        ],
      });
    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(_host(operations: operations, draftPort: port));
    await tester.pumpAndSettle();

    expect(tester.widget<NumberBox<double>>(find.byKey(const Key('envases-recibir-llegaron-1'))).value, 6);
    expect(tester.widget<NumberBox<double>>(find.byKey(const Key('envases-recibir-danadas-1'))).value, 2);
    expect(find.text('Recuperamos lo que estabas registrando.'), findsOneWidget);
  });

  testWidgets('recepción clears draft after accepted registration', (tester) async {
    final port = _FakeDraftPort();
    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(_host(operations: operations, draftPort: port));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-recibir-llegaron-1')), '6');
    await _commitNumberBox(tester);
    await tester.enterText(find.byKey(const Key('envases-recibir-danadas-1')), '1');
    await _commitNumberBox(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-recibir-guardar')));
    await tester.pumpAndSettle();

    expect(port.cleared, contains(envasesRecepcionDraftId(11)));
  });

  testWidgets('receive table computes apt and pending and shows the differences notice', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(_host(operations: operations, pendientes: 24));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-recibir-llegaron-1')), '23');
    await _commitNumberBox(tester);
    await tester.enterText(find.byKey(const Key('envases-recibir-danadas-1')), '1');
    await _commitNumberBox(tester);
    await tester.pumpAndSettle();

    expect(find.text('22', findRichText: true), findsWidgets); // Aptos
    final aptos = tester.widget<Text>(find.byKey(const Key('envases-recibir-aptos-1')));
    expect(aptos.data, '22');
    final pendiente = tester.widget<Text>(find.byKey(const Key('envases-recibir-pendiente-1')));
    expect(pendiente.data, '1');

    expect(find.byKey(const Key('envases-recibir-diferencias')), findsOneWidget);
    // 🔴 Antes decía «quedan 1 envases pendientes por recibir» para
    // cualquier cifra, singular incluido (queja del dueño, 14-sep-2026).
    expect(
      find.textContaining('Existen diferencias: queda 1 envase pendiente por recibir.'),
      findsOneWidget,
    );
  });

  testWidgets('receive pending text is singular for one', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(_host(operations: operations, pendientes: 5));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-recibir-llegaron-1')), '4');
    await _commitNumberBox(tester);
    await tester.pumpAndSettle();

    expect(find.textContaining('queda 1 envase pendiente por recibir.'), findsOneWidget);
    expect(find.textContaining('quedan 1'), findsNothing);
    expect(find.textContaining('1 envases'), findsNothing);
  });

  testWidgets('receive shows the full product name', (tester) async {
    tester.view.physicalSize = const Size(1920, 1080);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const nombreLargo = 'Envase pequeña Pilsener cerveza 330 ml retornable x24';
    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(
      FluentApp(
        theme: OrbiFluentTheme.light,
        home: EnvasesRecibirForm(
          row: _row(),
          lineasLoader: () async => [
            EnvasesPickingLineaRow(
              moveId: 1,
              productId: 50,
              productName: nombreLargo,
              uomId: 1,
              uomName: 'Unidades',
              pendientes: 24,
            ),
          ],
          operations: operations,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // 🔴 Antes la celda era un `SizedBox(width: 220)` — con «espacio de
    // sobra» a la derecha, el nombre largo se recortaba ahí sin necesidad
    // (queja del dueño, 14-sep-2026). Ahora tiene el ancho flexible que le
    // sobra a la fila, y el texto renderizado se acerca a su ancho natural
    // en vez de quedar atado a 220px.
    final width = tester.getSize(find.text(nombreLargo)).width;
    expect(width, greaterThan(300));
  });
}
