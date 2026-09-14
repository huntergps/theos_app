import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_recibir_form.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

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

Widget _host({required EnvasesOperations operations, VoidCallback? onCompleted}) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: EnvasesRecibirForm(
    row: _row(),
    lineasLoader: () async => [_linea()],
    operations: operations,
    onCompleted: onCompleted,
  ),
);

void main() {
  testWidgets('defaults llegaron to pendientes and enables saving', (tester) async {
    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(_host(operations: operations));
    await tester.pumpAndSettle();

    expect(tester.widget<TextBox>(find.byKey(const Key('envases-recibir-llegaron-1'))).controller!.text, '8');
    final guardar = tester.widget<FilledButton>(find.byKey(const Key('envases-recibir-guardar')));
    expect(guardar.onPressed, isNotNull);
  });

  testWidgets('rejects danadas greater than llegaron', (tester) async {
    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(_host(operations: operations));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-recibir-llegaron-1')), '4');
    await tester.enterText(find.byKey(const Key('envases-recibir-danadas-1')), '5');
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
    await tester.pumpAndSettle();

    expect(find.text('No puede llegar más de lo que salió.'), findsOneWidget);
  });

  testWidgets('rejects negative quantities', (tester) async {
    final operations = _FakeEnvasesOperations();
    await tester.pumpWidget(_host(operations: operations));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-recibir-danadas-1')), '-1');
    await tester.pumpAndSettle();

    expect(find.text('No puede ser negativo.'), findsOneWidget);
  });

  testWidgets('saving calls recibir with a non-empty uuid and the entered quantities', (tester) async {
    final operations = _FakeEnvasesOperations();
    var completed = false;
    await tester.pumpWidget(_host(operations: operations, onCompleted: () => completed = true));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-recibir-llegaron-1')), '6');
    await tester.enterText(find.byKey(const Key('envases-recibir-danadas-1')), '1');
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
    expect(find.text('Se enviará a Odoo al recuperar conexión.'), findsOneWidget);
  });
}
