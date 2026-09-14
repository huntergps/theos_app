import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_enviar_form.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

final class _FakeEnvasesOperations implements EnvasesOperations {
  EnvasesEnviarCommand? enviado;

  @override
  Future<EnvasesOperacionLocal> darPorPerdido({required String operacionUuid, required int pickingId}) async =>
      throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> enviar(EnvasesEnviarCommand command) async {
    enviado = command;
    return EnvasesOperacionLocal(
      operacionUuid: command.operacionUuid,
      tipo: 'envio',
      estado: EnvasesOperacionEstado.enviada,
      creadaEn: DateTime.now(),
    );
  }

  @override
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command) async => throw UnimplementedError();

  @override
  Stream<List<EnvasesOperacionLocal>> watchOperaciones() => const Stream.empty();
}

Widget _host({required EnvasesOperations operations, VoidCallback? onCompleted}) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: EnvasesEnviarForm(
    sedesUsuario: const [EnvasesSedeOption(id: 1, name: 'Guayaquil'), EnvasesSedeOption(id: 2, name: 'Manta')],
    sedesDestinoPosibles: const [
      EnvasesSedeOption(id: 1, name: 'Guayaquil'),
      EnvasesSedeOption(id: 2, name: 'Manta'),
      EnvasesSedeOption(id: 3, name: 'Quito'),
    ],
    productos: const [EnvasesProductoOption(id: 50, name: 'Jaba 12', uomName: 'Unidades')],
    operations: operations,
    onCompleted: onCompleted,
  ),
);

void main() {
  testWidgets('destino combo box never offers the chosen origen', (tester) async {
    await tester.pumpWidget(_host(operations: _FakeEnvasesOperations()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-enviar-origen')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guayaquil').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-enviar-destino')));
    await tester.pumpAndSettle();

    expect(find.text('Guayaquil').hitTestable(), findsNothing);
    expect(find.text('Manta').hitTestable(), findsOneWidget);
    expect(find.text('Quito').hitTestable(), findsOneWidget);
  });

  testWidgets('clears a stale destino when it becomes the new origen', (tester) async {
    await tester.pumpWidget(_host(operations: _FakeEnvasesOperations()));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-enviar-origen')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guayaquil').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-enviar-destino')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manta').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-enviar-origen')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manta').last);
    await tester.pumpAndSettle();

    final destino = tester.widget<ComboBox<int>>(find.byKey(const Key('envases-enviar-destino')));
    expect(destino.value, isNull);
  });

  testWidgets('confirming sends a non-empty uuid and the chosen origen/destino/lines', (tester) async {
    final operations = _FakeEnvasesOperations();
    var completed = false;
    await tester.pumpWidget(_host(operations: operations, onCompleted: () => completed = true));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-enviar-origen')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guayaquil').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-enviar-destino')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Manta').last);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-enviar-producto-0')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Jaba 12').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-enviar-cantidad-0')), '3');
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-enviar-confirmar')));
    await tester.pumpAndSettle();

    expect(operations.enviado, isNotNull);
    expect(operations.enviado!.origenId, 1);
    expect(operations.enviado!.destinoId, 2);
    expect(operations.enviado!.operacionUuid, isNotEmpty);
    expect(operations.enviado!.lineas.single.productId, 50);
    expect(operations.enviado!.lineas.single.cantidad, 3);
    expect(completed, isTrue);
  });
}
