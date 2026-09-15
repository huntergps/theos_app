import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/envases_composition.dart';
import 'package:theos_panel/features/envases/envases_enviar_form.dart';

/// Regresión de la falla medida en producción (Orbi web contra un Odoo
/// real): al pulsar "Enviar" en `/envases/enviar` — una entrada del menú
/// lateral, que se abre con `go()` y por tanto sin historial debajo — el
/// `onCompleted` de la pantalla hacía `context.pop()` y GoRouter lanzaba
/// `GoError: There is nothing to pop`. La pantalla mostraba «No se pudo
/// registrar el envío» aunque la operación SÍ había quedado encolada.
///
/// Estas pruebas no atraviesan la composición completa de `/envases/enviar`
/// (`EnvasesEnviarRoute`) porque esa ruta necesita catálogos de sedes y
/// productos que sólo se cargan con un `OdooClient` real — sin una manera de
/// falsear su transporte HTTP (Dio) para pruebas, según
/// `odoo_sdk/lib/src/api/client/odoo_http_client.dart`. En cambio, wirean
/// `EnvasesEnviarForm` exactamente como lo hace `EnvasesEnviarRoute` en
/// `envases_composition.dart` (`onCompleted`/`onCancel` llamando a
/// `volverOEnvases`), montado bajo un `GoRouter` real y mínimo — así se
/// ejercita el mismo helper de navegación que usan los cinco puntos de
/// llamada reales.
void main() {
  const sedes = [
    EnvasesSedeOption(id: 1, name: 'Guayaquil'),
    EnvasesSedeOption(id: 2, name: 'Manta'),
  ];
  const productos = [EnvasesProductoOption(id: 50, name: 'Jaba 12', uomName: 'Unidades')];

  Future<void> commitNumberBox(WidgetTester tester) async {
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  Future<void> fillAndSubmit(WidgetTester tester) async {
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
    await commitNumberBox(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('envases-enviar-confirmar')));
    await tester.pumpAndSettle();
  }

  GoRouter buildRouter({required String initialLocation}) => GoRouter(
    initialLocation: initialLocation,
    routes: [
      GoRoute(path: '/other', builder: (context, state) => const Center(child: Text('Otra pantalla'))),
      GoRoute(path: '/envases', builder: (context, state) => const Center(child: Text('Existencias'))),
      GoRoute(
        path: '/envases/enviar',
        // Mismo wiring que `EnvasesEnviarRoute` en envases_composition.dart:
        // `onCompleted`/`onCancel` llaman a `volverOEnvases`, nunca a
        // `context.pop()` directo.
        builder: (context, state) => EnvasesEnviarForm(
          sedesUsuario: sedes,
          sedesDestinoPosibles: sedes,
          productos: productos,
          operations: _FakeEnvasesOperations(),
          onCompleted: () => volverOEnvases(context, '/envases'),
          onCancel: () => volverOEnvases(context, '/envases'),
        ),
      ),
    ],
  );

  testWidgets(
    '(a) enviar abierto con go() y sin historial: no lanza GoError y cae al destino de respaldo',
    (tester) async {
      final router = buildRouter(initialLocation: '/envases/enviar');
      addTearDown(router.dispose);

      await tester.pumpWidget(FluentApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      // Sin nada debajo: el propio arranque de la ruta ya prueba que no hay
      // historial.
      expect(router.routerDelegate.canPop(), isFalse);

      await fillAndSubmit(tester);

      expect(tester.takeException(), isNull);
      expect(router.state.uri.path, '/envases');
    },
  );

  testWidgets(
    '(b) enviar abierto con push() sobre otra ruta: sigue usando pop() y vuelve a ella',
    (tester) async {
      final router = buildRouter(initialLocation: '/other');
      addTearDown(router.dispose);

      await tester.pumpWidget(FluentApp.router(routerConfig: router));
      await tester.pumpAndSettle();

      router.push('/envases/enviar');
      await tester.pumpAndSettle();
      expect(router.routerDelegate.canPop(), isTrue);

      await fillAndSubmit(tester);

      expect(tester.takeException(), isNull);
      expect(router.state.uri.path, '/other');
    },
  );
}

final class _FakeEnvasesOperations implements EnvasesOperations {
  @override
  Future<EnvasesOperacionLocal> darPorPerdido({required String operacionUuid, required int pickingId}) async =>
      throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> enviar(EnvasesEnviarCommand command) async => EnvasesOperacionLocal(
    operacionUuid: command.operacionUuid,
    tipo: 'envio',
    estado: EnvasesOperacionEstado.pendienteDeEnviar,
    creadaEn: DateTime.now(),
  );

  @override
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command) async => throw UnimplementedError();

  @override
  Stream<List<EnvasesOperacionLocal>> watchOperaciones() => const Stream.empty();
}
