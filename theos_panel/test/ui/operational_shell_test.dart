import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/layouts/operational_shell.dart';

/// El marco, reescrito contra Fluent.
///
/// Las pruebas anteriores comprobaban el andamiaje de Material que se
/// construía a mano: buscaban un `Drawer`, una etiqueta de accesibilidad
/// propia, un carril hecho aquí. Todo eso lo hace ahora `NavigationView`, y
/// probar que Fluent existe no prueba nada nuestro. Lo que se comprueba aquí
/// es **lo que decidimos nosotros**: dónde están los cortes, qué dice el pie,
/// qué botones se ofrecen y qué pasa al bloquear.
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
  OperationalDestination(
    label: 'Clientes',
    path: '/clients',
    icon: FluentIcons.people,
    group: 'Ventas',
  ),
  OperationalDestination(
    label: 'Panel',
    path: '/envases',
    icon: FluentIcons.product,
    group: 'Envases',
  ),
];

Widget _host(
  Size size, {
  ValueChanged<String>? onNavigate,
  bool locked = false,
  VoidCallback? onLock,
  Future<bool> Function(String password)? onUnlock,
  VoidCallback? onSwitchUser,
  Widget? child,
  OperationalContext context = _context,
}) => FluentApp(
  theme: OrbiFluentTheme.light,
  home: MediaQuery(
    data: MediaQueryData(size: size),
    child: OperationalShell(
      destinations: _destinations,
      selectedPath: '/sales',
      onNavigate: onNavigate ?? (_) {},
      context: context,
      onLogout: () {},
      locked: locked,
      onLock: onLock,
      onUnlock: onUnlock,
      onSwitchUser: onSwitchUser,
      child: child ?? const Center(child: Text('Contenido operativo')),
    ),
  ),
);

Future<void> _pump(WidgetTester tester, Widget host, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(host);
  await tester.pumpAndSettle();
}

void main() {
  group('dónde están los cortes, que son nuestros y no los de Fluent', () {
    // Fluent abriría su carril a partir de 1008. La lámina aprobada enseña
    // sólo iconos a 1366, así que el corte es nuestro y hay que sostenerlo.
    testWidgets('a 1920 en horizontal el carril lleva etiquetas', (
      tester,
    ) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);

      final pane = tester.widget<NavigationView>(find.byType(NavigationView));
      expect(pane.pane!.displayMode, PaneDisplayMode.expanded);
      expect(find.text('Órdenes'), findsWidgets);
    });

    testWidgets('a 1366 en horizontal el carril es de sólo iconos', (
      tester,
    ) async {
      const size = Size(1366, 1024);
      await _pump(tester, _host(size), size);

      final view = tester.widget<NavigationView>(find.byType(NavigationView));
      expect(view.pane!.displayMode, PaneDisplayMode.compact);
    });

    // Un iPad vertical de 1024 de ancho no lleva carril, igual que el
    // teléfono: la orientación cuenta tanto como el ancho.
    testWidgets('en vertical no hay carril permanente, por ancho que sea', (
      tester,
    ) async {
      const size = Size(1024, 1366);
      await _pump(tester, _host(size), size);

      final view = tester.widget<NavigationView>(find.byType(NavigationView));
      expect(view.pane!.displayMode, PaneDisplayMode.minimal);
    });

    testWidgets('en teléfono tampoco', (tester) async {
      const size = Size(390, 844);
      await _pump(tester, _host(size), size);

      final view = tester.widget<NavigationView>(find.byType(NavigationView));
      expect(view.pane!.displayMode, PaneDisplayMode.minimal);
    });
  });

  group('el menú', () {
    testWidgets('agrupa por área y marca la pantalla que se está viendo', (
      tester,
    ) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);

      final view = tester.widget<NavigationView>(find.byType(NavigationView));
      // La selección se cuenta sobre las entradas navegables, no sobre las
      // filas del menú: si se desplaza, se marca en azul una pantalla
      // distinta de la que se está viendo.
      expect(view.pane!.selected, 0);
      expect(find.text('Ventas'), findsWidgets);
      expect(find.text('Envases'), findsWidgets);
    });

    testWidgets('pulsar un destino avisa con su ruta', (tester) async {
      const size = Size(1920, 1080);
      String? navegado;
      await _pump(tester, _host(size, onNavigate: (p) => navegado = p), size);

      await tester.tap(find.text('Clientes').first);
      await tester.pumpAndSettle();
      expect(navegado, '/clients');
    });
  });

  group('el pie', () {
    testWidgets('en ancho dice servidor, base, hora y estado', (tester) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);

      expect(find.text('Servidor: erp.test'), findsOneWidget);
      expect(find.text('BD: orbi_test'), findsOneWidget);
      // El valor no repite la etiqueta: «Hora del servidor: Hora del servidor
      // no disponible» es lo que llegó a leerse en pantalla.
      expect(find.text('Hora servidor: sin dato'), findsOneWidget);
      expect(find.textContaining('Hora del servidor'), findsNothing);
      expect(find.text('3 pendientes'), findsOneWidget);
    });

    testWidgets(
      'sin medida dice que no está verificado, nunca que todo va bien',
      (tester) async {
        const size = Size(1920, 1080);
        await _pump(
          tester,
          _host(
            size,
            context: const OperationalContext(
              server: 'erp.test',
              database: 'orbi_test',
              userLabel: 'Erik',
              companyLabel: 'Empresa Demo',
              connectionLabel: 'Red sin verificar',
              connectionStatus: ConnectionStatus.unknown,
              syncLabel: 'al día',
            ),
          ),
          size,
        );

        expect(find.text('Red sin verificar'), findsOneWidget);
        expect(find.text('Conectado'), findsNothing);
      },
    );

    testWidgets('con el servidor caído lo dice distinto de quedarse sin red', (
      tester,
    ) async {
      const size = Size(1920, 1080);
      await _pump(
        tester,
        _host(
          size,
          context: const OperationalContext(
            server: 'erp.test',
            database: 'orbi_test',
            userLabel: 'Erik',
            companyLabel: 'Empresa Demo',
            connectionLabel: 'da igual, manda el estado medido',
            connectionStatus: ConnectionStatus.backendUnreachable,
            syncLabel: 'al día',
          ),
        ),
        size,
      );

      expect(find.text('Red sin servidor'), findsOneWidget);
      expect(find.text('Sin red'), findsNothing);
    });

    testWidgets('en estrecho el pie se pide, y se puede abrir', (tester) async {
      const size = Size(390, 844);
      await _pump(tester, _host(size), size);

      expect(find.text('Servidor: erp.test'), findsNothing);
      final boton = find.byKey(const Key('operational-context-button'));
      expect(boton, findsOneWidget);

      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(find.text('Servidor: erp.test'), findsOneWidget);
    });
  });

  group('sesión', () {
    testWidgets(
      'no ofrece bloquear ni cambiar de usuario si no puede hacerlo',
      (tester) async {
        const size = Size(1920, 1080);
        await _pump(tester, _host(size), size);

        expect(find.byKey(const Key('lock-button')), findsNothing);
        expect(find.byKey(const Key('switch-user-button')), findsNothing);
        // Cerrar sesión siempre se puede.
        expect(find.byKey(const Key('logout-button')), findsOneWidget);
      },
    );

    testWidgets('con sus manejadores sí los ofrece, y son acciones distintas', (
      tester,
    ) async {
      const size = Size(1920, 1080);
      var bloqueado = false;
      var cambiado = false;
      await _pump(
        tester,
        _host(
          size,
          onLock: () => bloqueado = true,
          onUnlock: (_) async => true,
          onSwitchUser: () => cambiado = true,
        ),
        size,
      );

      await tester.tap(find.byKey(const Key('lock-button')));
      await tester.pumpAndSettle();
      expect(bloqueado, isTrue);
      expect(cambiado, isFalse);

      await tester.tap(find.byKey(const Key('switch-user-button')));
      await tester.pumpAndSettle();
      expect(cambiado, isTrue);
    });

    // Un borrador a medio escribir no puede perderse porque alguien pulsara
    // «Bloquear»: el marco sigue montado debajo, sólo deja de responder.
    testWidgets('bloquear tapa el contenido sin descartarlo', (tester) async {
      const size = Size(1920, 1080);
      await _pump(
        tester,
        _host(
          size,
          locked: true,
          onLock: () {},
          onUnlock: (_) async => true,
          child: const Center(child: Text('Borrador a medias')),
        ),
        size,
      );

      // Sigue en el árbol, pero fuera del alcance de quien mire o toque.
      expect(
        find.text('Borrador a medias', skipOffstage: false),
        findsOneWidget,
      );
      final ignora = tester.widget<IgnorePointer>(
        find.byKey(const Key('operational-shell-interactivity')),
      );
      expect(ignora.ignoring, isTrue);
    });
  });

  group('la cabecera y el pie los pone Fluent, no nosotros', () {
    // Antes esto era una fila escrita a mano encima de todo. Ahora vive en
    // `NavigationPane.header`, que Fluent coloca y esconde por su cuenta.
    testWidgets('la empresa se ve en el carril abierto', (tester) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);

      expect(find.text('Empresa Demo'), findsOneWidget);
    });

    // Fluent esconde la cabecera del panel en el carril de sólo iconos, donde
    // un nombre de empresa no cabría de todas formas. Se fija aquí para que
    // nadie lo tome por un fallo y le construya una fila propia encima.
    testWidgets('en el carril de iconos Fluent la esconde, y está bien', (
      tester,
    ) async {
      const size = Size(1366, 1024);
      await _pump(tester, _host(size), size);

      expect(find.text('Empresa Demo'), findsNothing);
      // Lo que sí se ve siempre es el pie con el contexto del servidor.
      expect(find.text('Servidor: erp.test'), findsOneWidget);
    });
  });
}
