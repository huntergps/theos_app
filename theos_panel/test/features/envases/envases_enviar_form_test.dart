import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_enviar_form.dart';
import 'package:theos_panel/features/envases/envases_form_draft_port.dart';
import 'package:theos_panel/features/envases/widgets/envases_producto_field.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Puerto de borrador en memoria, para no arrastrar Drift a estos tests de
/// widget: sólo necesitan ver qué se leyó, guardó y borró.
final class _FakeDraftPort implements EnvasesFormDraftPort {
  final Map<String, Map<String, dynamic>> stored = {};
  final List<Map<String, dynamic>> saves = [];
  final List<String> cleared = [];

  void seed(String draftId, Map<String, dynamic> payload) => stored[draftId] = payload;

  @override
  Future<Map<String, dynamic>?> read(String draftId) async => stored[draftId];

  @override
  Future<void> save(String draftId, Map<String, dynamic> payload) async {
    stored[draftId] = payload;
    saves.add(payload);
  }

  @override
  Future<void> clear(String draftId) async {
    stored.remove(draftId);
    cleared.add(draftId);
  }
}

final class _ThrowingEnvasesOperations implements EnvasesOperations {
  @override
  Future<EnvasesOperacionLocal> darPorPerdido({required String operacionUuid, required int pickingId}) async =>
      throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> enviar(EnvasesEnviarCommand command) async => throw StateError('sin conexión');

  @override
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command) async => throw UnimplementedError();

  @override
  Stream<List<EnvasesOperacionLocal>> watchOperaciones() => const Stream.empty();
}

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

/// Como `_FakeEnvasesOperations`, pero simula el resultado que
/// `DurableEnvasesOperations` da SIEMPRE (haya o no conexión): la operación
/// queda encolada. Sirve para probar el aviso "Guardado en este equipo..."
/// sin necesitar una operación que realmente falle.
final class _QueuedEnvasesOperations implements EnvasesOperations {
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
      estado: EnvasesOperacionEstado.pendienteDeEnviar,
      creadaEn: DateTime.now(),
    );
  }

  @override
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command) async => throw UnimplementedError();

  @override
  Stream<List<EnvasesOperacionLocal>> watchOperaciones() => const Stream.empty();
}

Widget _host({
  required EnvasesOperations operations,
  VoidCallback? onCompleted,
  EnvasesFormDraftPort? draftPort,
  List<EnvasesProductoOption> productos = const [EnvasesProductoOption(id: 50, name: 'Jaba 12', uomName: 'Unidades')],
}) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: EnvasesEnviarForm(
    sedesUsuario: const [EnvasesSedeOption(id: 1, name: 'Guayaquil'), EnvasesSedeOption(id: 2, name: 'Manta')],
    sedesDestinoPosibles: const [
      EnvasesSedeOption(id: 1, name: 'Guayaquil'),
      EnvasesSedeOption(id: 2, name: 'Manta'),
      EnvasesSedeOption(id: 3, name: 'Quito'),
    ],
    productos: productos,
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
    await _commitNumberBox(tester);
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

  testWidgets('restores origin, destination and lines from draft', (tester) async {
    final port = _FakeDraftPort()
      ..seed(envasesEnvioDraftId, {
        'v': 1,
        'origenId': 2,
        'destinoId': 3,
        'lineas': [
          {'productoId': 50, 'cantidad': 4},
        ],
      });
    await tester.pumpWidget(_host(operations: _FakeEnvasesOperations(), draftPort: port));
    await tester.pumpAndSettle();

    expect(tester.widget<ComboBox<int>>(find.byKey(const Key('envases-enviar-origen'))).value, 2);
    expect(tester.widget<ComboBox<int>>(find.byKey(const Key('envases-enviar-destino'))).value, 3);
    expect(
      tester.widget<EnvasesProductoField>(find.byKey(const Key('envases-enviar-producto-0'))).value?.id,
      50,
    );
    expect(tester.widget<NumberBox<double>>(find.byKey(const Key('envases-enviar-cantidad-0'))).value, 4);
    expect(find.text('Recuperamos lo que estabas registrando.'), findsOneWidget);
  });

  testWidgets('envío saves each change', (tester) async {
    final port = _FakeDraftPort();
    await tester.pumpWidget(_host(operations: _FakeEnvasesOperations(), draftPort: port));
    await tester.pumpAndSettle();

    // Sin origen elegido y sin ningún envase todavía, la tabla de líneas no
    // se muestra (el formulario pide elegir la sede primero) — hay que
    // elegir una para que exista el campo de cantidad que esta prueba
    // teclea.
    await tester.tap(find.byKey(const Key('envases-enviar-origen')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Guayaquil').last);
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(const Key('envases-enviar-cantidad-0')), '5');
    await _commitNumberBox(tester);
    await tester.pump(const Duration(milliseconds: 350));

    expect(port.stored[envasesEnvioDraftId]?['lineas'], [
      {'productoId': null, 'cantidad': 5.0},
    ]);
  });

  testWidgets('envío clears draft only after accepted registration', (tester) async {
    Future<void> fillForm(WidgetTester tester) async {
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
      await _commitNumberBox(tester);
      await tester.pumpAndSettle();
    }

    final acceptedPort = _FakeDraftPort();
    await tester.pumpWidget(_host(operations: _FakeEnvasesOperations(), draftPort: acceptedPort));
    await tester.pumpAndSettle();
    await fillForm(tester);
    await tester.tap(find.byKey(const Key('envases-enviar-confirmar')));
    await tester.pumpAndSettle();
    expect(acceptedPort.cleared, contains(envasesEnvioDraftId));

    final rejectedPort = _FakeDraftPort();
    await tester.pumpWidget(_host(operations: _ThrowingEnvasesOperations(), draftPort: rejectedPort));
    await tester.pumpAndSettle();
    await fillForm(tester);
    await tester.tap(find.byKey(const Key('envases-enviar-confirmar')));
    await tester.pumpAndSettle();
    expect(rejectedPort.cleared, isEmpty);
  });

  testWidgets('envío drops draft lines whose product no longer exists', (tester) async {
    final port = _FakeDraftPort()
      ..seed(envasesEnvioDraftId, {
        'v': 1,
        'origenId': null,
        'destinoId': null,
        'lineas': [
          {'productoId': 50, 'cantidad': 2},
          {'productoId': 999, 'cantidad': 3},
        ],
      });
    await tester.pumpWidget(_host(operations: _FakeEnvasesOperations(), draftPort: port));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('envases-enviar-producto-1')), findsNothing);
    expect(
      tester.widget<EnvasesProductoField>(find.byKey(const Key('envases-enviar-producto-0'))).value?.id,
      50,
    );
    expect(tester.widget<NumberBox<double>>(find.byKey(const Key('envases-enviar-cantidad-0'))).value, 2);
  });

  testWidgets(
    'a throwing onCompleted (navegación sin historial) no reescribe un registro '
    'aceptado como si hubiera fallado',
    (tester) async {
      final operations = _QueuedEnvasesOperations();
      await tester.pumpWidget(
        _host(
          operations: operations,
          // Simula el `GoError: There is nothing to pop` que lanzaba
          // `context.pop()` cuando la pantalla se abre sin historial debajo
          // (menú lateral, o restaurar la última ubicación al recargar).
          onCompleted: () => throw StateError('There is nothing to pop'),
        ),
      );
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
      await _commitNumberBox(tester);
      await tester.pumpAndSettle();

      // `onCompleted` lanza DESPUÉS de un `await` dentro de `_enviar()`, así
      // que el error llega como una excepción de Future sin manejar (nadie
      // espera el `Future<void>` que devuelve el `onPressed`). Se intercepta
      // aquí mismo con `runZonedGuarded` para comprobar que sigue siendo
      // real — no se traga en silencio — sin que tumbe el test entero.
      Object? completionError;
      await runZonedGuarded(
        () async {
          await tester.tap(find.byKey(const Key('envases-enviar-confirmar')));
          await tester.pumpAndSettle();
        },
        (error, stack) => completionError = error,
      );

      // El registro SÍ ocurrió (quedó encolado) antes de que la navegación
      // lanzara.
      expect(operations.enviado, isNotNull);
      // Y ese registro aceptado no se disfraza de error de registro.
      expect(find.textContaining('No se pudo registrar el envío'), findsNothing);
      expect(
        find.text('Guardado en este equipo. Se envía a Odoo en cuanto haya conexión.'),
        findsOneWidget,
      );
      // El throw de `onCompleted` sigue siendo real, sólo que ya no se
      // confunde con un fallo de registro.
      expect(completionError, isA<StateError>());
    },
  );
}
