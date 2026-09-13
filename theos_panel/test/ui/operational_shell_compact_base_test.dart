import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/layouts/operational_shell.dart';

/// Defecto medido en el iPhone del dueño con un panel de diagnóstico
/// (13-sep-2026): en Chrome para iOS, a 440×766 pt, `innerHeight`,
/// `visualViewport`, `html`, `body` y `flutter-view` ya miden los 766 —no hay
/// hueco de navegador— y aun así, al fondo de Inicio, aparecía una franja
/// blanca de unos 26 pt con un ícono ⓘ tenue a la derecha.
///
/// La causa: en ancho estrecho, el último hijo de la `Column` de `_scaffold`
/// es `_compactContextButton`, un `Align` con un `IconButton` sin ningún
/// fondo propio, y el armazón tampoco pintaba una base opaca por debajo. En
/// esa franja no pintaba nadie, así que se veía la página HTML de detrás
/// (`web/index.html`, la foto clara del amanecer en tema claro).
///
/// Esta prueba no comprueba colores concretos —esos los decide
/// `FluentTheme`, nunca este archivo— sino que TODO ancestro entre el botón
/// compacto y `OperationalShell` incluye al menos un fondo opaco, y que el
/// más externo de esos fondos (el que envuelve la `Column` entera) también
/// lo es.
const _context = OperationalContext(
  server: 'erp.test',
  database: 'orbi_test',
  userLabel: 'Erik',
  companyLabel: 'Empresa Demo',
  connectionLabel: 'Conectado',
  syncLabel: '3 pendientes',
);

const _destinations = [
  OperationalDestination(
    label: 'Órdenes',
    path: '/sales',
    icon: FluentIcons.shopping_cart,
    group: 'Ventas',
  ),
];

Widget _host(Size size) => FluentApp(
  theme: OrbiFluentTheme.dark,
  home: MediaQuery(
    data: MediaQueryData(size: size),
    child: OperationalShell(
      destinations: _destinations,
      selectedPath: '/sales',
      onNavigate: (_) {},
      context: _context,
      onLogout: () {},
      // `null`: el valor de producción (1 segundo) es un `Timer.periodic`
      // vivo, y esta prueba usa `pumpAndSettle`, que nunca termina con uno
      // corriendo (ver la nota en `_FooterClock`).
      clockTickInterval: null,
      child: const Center(child: Text('Contenido operativo')),
    ),
  ),
);

void main() {
  testWidgets(
    'a 390×844 en tema oscuro el pie compacto pinta una base opaca hasta el '
    'borde del armazón, sin hueco hacia la página HTML',
    (tester) async {
      const size = Size(390, 844);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(size));
      await tester.pumpAndSettle();

      final boton = find.byKey(const Key('operational-context-button'));
      expect(boton, findsOneWidget);

      // Todos los `ColoredBox` que son ancestros del botón, sea cual sea su
      // origen (los de `FluentApp`/`MediaQuery` incluidos).
      final buttonAncestors = find
          .ancestor(of: boton, matching: find.byType(ColoredBox))
          .evaluate()
          .toList();

      // Los `ColoredBox` que son ancestros del propio `OperationalShell`
      // (fuera del armazón: andamiaje de `FluentApp`, no de este widget).
      final outsideShell = find
          .ancestor(
            of: find.byType(OperationalShell),
            matching: find.byType(ColoredBox),
          )
          .evaluate()
          .toSet();

      // Lo que queda es, por descarte, lo que hay ENTRE el botón y
      // `OperationalShell`: el armazón propio. El orden de `find.ancestor`
      // va del más cercano al más lejano, así que el último es el más
      // externo dentro del armazón.
      final insideShell = buttonAncestors
          .where((element) => !outsideShell.contains(element))
          .map((element) => element.widget as ColoredBox)
          .toList();

      expect(
        insideShell,
        isNotEmpty,
        reason:
            'ningún ancestro del botón compacto, dentro del armazón, pinta '
            'un ColoredBox: la franja queda sin fondo propio',
      );

      expect(
        insideShell.any((box) => box.color.a == 1.0),
        isTrue,
        reason:
            'ningún ColoredBox del armazón, entre el botón y '
            'OperationalShell, es opaco',
      );

      final outermost = insideShell.last;
      expect(
        outermost.color.a,
        1.0,
        reason:
            'el ColoredBox más externo del armazón (el que debe envolver '
            'toda la Column de _scaffold) tiene que ser opaco',
      );
    },
  );
}
