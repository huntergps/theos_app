import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/envases/envases_enviar_form.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Cubre la queja del dueño del 14-sep-2026 sobre `/#/envases/enviar` en
/// escritorio (1.900 px): combos pegados a los extremos, «Fecha de salida»
/// sin campo visible, el desplegable del envase tapando el formulario
/// entero, cantidad y quitar lejos del envase, y el botón «Enviar» como
/// barra gris a todo el ancho sin explicar por qué está deshabilitado.
final class _NoopEnvasesOperations implements EnvasesOperations {
  @override
  Future<EnvasesOperacionLocal> darPorPerdido({required String operacionUuid, required int pickingId}) async =>
      throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> enviar(EnvasesEnviarCommand command) async => throw UnimplementedError();

  @override
  Future<EnvasesOperacionLocal> recibir(EnvasesRecibirCommand command) async => throw UnimplementedError();

  @override
  Stream<List<EnvasesOperacionLocal>> watchOperaciones() => const Stream.empty();
}

void setDesktopSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1920, 1080);
  tester.view.devicePixelRatio = 1;
}

void setPhoneSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
}

Widget _enviarHost({List<EnvasesProductoOption> productos = const []}) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: EnvasesEnviarForm(
    sedesUsuario: const [EnvasesSedeOption(id: 1, name: 'Guayaquil'), EnvasesSedeOption(id: 2, name: 'Manta')],
    sedesDestinoPosibles: const [
      EnvasesSedeOption(id: 1, name: 'Guayaquil'),
      EnvasesSedeOption(id: 2, name: 'Manta'),
      EnvasesSedeOption(id: 3, name: 'Quito'),
    ],
    productos: productos.isEmpty
        ? const [
            EnvasesProductoOption(id: 50, name: 'Jaba 12', uomName: 'Unidades'),
            EnvasesProductoOption(
              id: 51,
              name: 'Cajón retornable de 24 unidades para gaseosa familiar',
              uomName: 'Unidades',
            ),
          ]
        : productos,
    operations: _NoopEnvasesOperations(),
    onCancel: () {},
  ),
);

Future<void> _elegirOrigen(WidgetTester tester, String sede) async {
  await tester.tap(find.byKey(const Key('envases-enviar-origen')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(sede).last);
  await tester.pumpAndSettle();
}

void main() {
  group('EnvasesEnviarForm — escritorio', () {
    testWidgets('desktop send form lays out origin, destination and date in one compact row', (tester) async {
      setDesktopSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_enviarHost());
      await tester.pumpAndSettle();

      // Las etiquetas son el borde superior de cada campo — si el `Wrap`
      // los mandara a filas distintas (el defecto reportado: origen y
      // destino a los dos extremos, «Fecha de salida» debajo), sus
      // etiquetas también quedarían en `dy` distintos.
      final origen = tester.getTopLeft(find.text('Sede de origen'));
      final destino = tester.getTopLeft(find.text('Sede de destino'));
      final fecha = tester.getTopLeft(find.text('Fecha de salida'));

      // Misma fila: la misma `dy`, no una debajo de otra.
      expect((origen.dy - destino.dy).abs(), lessThan(2));
      expect((destino.dy - fecha.dy).abs(), lessThan(2));

      // Compactos: separados poco entre sí, no a los extremos de la
      // pantalla con un vacío enorme en medio.
      expect(destino.dx - origen.dx, lessThan(400));
      expect(fecha.dx - destino.dx, lessThan(400));
    });

    testWidgets('desktop send lines are a table with quantity and remove next to the product', (tester) async {
      setDesktopSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_enviarHost());
      await tester.pumpAndSettle();
      await _elegirOrigen(tester, 'Guayaquil');

      final producto = tester.getTopLeft(find.byKey(const Key('envases-enviar-producto-0')));
      final cantidad = tester.getTopLeft(find.byKey(const Key('envases-enviar-cantidad-0')));

      expect((producto.dy - cantidad.dy).abs(), lessThan(2));
      expect(cantidad.dx - producto.dx, lessThan(600));

      final quitar = tester.getTopLeft(find.byKey(const Key('envases-enviar-quitar-0')));
      expect(quitar.dx, greaterThan(cantidad.dx));
    });

    testWidgets('product suggestion list is not wider than its field', (tester) async {
      setDesktopSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_enviarHost());
      await tester.pumpAndSettle();
      await _elegirOrigen(tester, 'Guayaquil');

      final fieldFinder = find.byKey(const Key('envases-enviar-producto-0'));
      final fieldRect = tester.getRect(fieldFinder);

      await tester.tap(fieldFinder);
      await tester.pumpAndSettle();

      // El nombre largo es justo el que, con un `ComboBox` (cuyo
      // desplegable mide lo que pide el contenido, no el control), se
      // habría salido del ancho del campo.
      final itemFinder = find.text('Cajón retornable de 24 unidades para gaseosa familiar');
      expect(itemFinder, findsOneWidget);
      final itemRect = tester.getRect(itemFinder);
      expect(itemRect.right, lessThanOrEqualTo(fieldRect.right + 16));
      expect(itemRect.left, greaterThanOrEqualTo(fieldRect.left - 16));
    });

    testWidgets('disabled send explains what is missing', (tester) async {
      setDesktopSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_enviarHost());
      await tester.pumpAndSettle();

      final confirmar = tester.widget<FilledButton>(find.byKey(const Key('envases-enviar-confirmar')));
      expect(confirmar.onPressed, isNull);
      expect(find.byKey(const Key('envases-form-ayuda')), findsOneWidget);
      expect(
        find.text('Elige la sede de origen, la de destino y al menos un envase.'),
        findsOneWidget,
      );
    });

    testWidgets('actions are right-aligned, not full width', (tester) async {
      setDesktopSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_enviarHost());
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byKey(const Key('envases-enviar-confirmar')));
      expect(size.width, lessThan(400));

      expect(find.text('Cancelar'), findsOneWidget);
      final cancelar = tester.getTopLeft(find.text('Cancelar'));
      final confirmar = tester.getTopLeft(find.byKey(const Key('envases-enviar-confirmar')));
      // «Cancelar» a la izquierda de «Enviar», el orden que usa toda la app.
      expect(cancelar.dx, lessThan(confirmar.dx));
    });
  });

  group('EnvasesEnviarForm — teléfono', () {
    testWidgets('phone renders lines as cards with a full-width primary button', (tester) async {
      setPhoneSize(tester);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_enviarHost());
      await tester.pumpAndSettle();
      await _elegirOrigen(tester, 'Guayaquil');

      expect(find.byType(Card), findsWidgets);

      final buttonSize = tester.getSize(find.byKey(const Key('envases-enviar-confirmar')));
      final screenWidth = tester.view.physicalSize.width / tester.view.devicePixelRatio;
      expect(buttonSize.width, greaterThan(screenWidth - 80));
    });
  });
}
