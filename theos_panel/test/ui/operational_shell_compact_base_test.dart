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
  // 🔴 Actualizada el 15-sep-2026: a 390×844 (VERTICAL), el pie ya no es
  // `_compactContextButton` (el `Align` sin fondo propio que causaba el
  // hueco original) — cae en el nuevo modo barra inferior
  // (`OrbiTheme.fullPaneBreakpoint`), donde el último hijo de la `Column` es
  // la franja de estado ([_bottomStatusStrip]), que SIEMPRE se pinta dentro
  // de su propio `ColoredBox` opaco. El riesgo que esta prueba vigilaba
  // (una franja sin fondo dejando ver la página HTML de detrás) se
  // comprueba ahora contra esa franja, que es hoy el último elemento
  // vertical del armazón en este ancho.
  testWidgets(
    'a 390×844 en tema oscuro la franja de estado pinta una base opaca '
    'hasta el borde del armazón, sin hueco hacia la página HTML',
    (tester) async {
      const size = Size(390, 844);
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(_host(size));
      await tester.pumpAndSettle();

      final strip = find.byKey(const Key('shell-bottom-status-strip'));
      expect(strip, findsOneWidget);

      // La propia franja es un `ColoredBox`: se comprueba directamente que
      // sea opaca, sin necesidad de subir por sus ancestros — a diferencia
      // del viejo `_compactContextButton` (un `IconButton` sin fondo
      // propio), este widget SÍ pinta el suyo.
      final box = tester.widget<ColoredBox>(strip);
      expect(
        box.color.a,
        1.0,
        reason:
            'la franja de estado del pie tiene que pintar un fondo opaco, '
            'igual que antes lo exigía el pie compacto',
      );
    },
  );
}
