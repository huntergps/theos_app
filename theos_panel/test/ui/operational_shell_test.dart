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

/// Un catálogo más completo, con las cuatro rutas que el armazón ya no
/// pinta como el resto: «Inicio» (grupo «Workspace», de un solo hijo) y las
/// cuatro del viejo grupo «Sistema» que ahora se reparten entre la barra
/// superior (Actividades, Avisos) y el pie del panel (Sincronización,
/// Configuración).
const _richDestinations = [
  OperationalDestination(
    label: 'Inicio',
    path: '/',
    icon: FluentIcons.home,
    group: 'Workspace',
  ),
  OperationalDestination(
    label: 'Órdenes',
    path: '/sales',
    icon: FluentIcons.shopping_cart,
    group: 'Ventas',
  ),
  OperationalDestination(
    label: 'Actividades',
    path: '/activities',
    icon: FluentIcons.calendar,
    group: 'Sistema',
  ),
  OperationalDestination(
    label: 'Avisos',
    path: '/notifications',
    icon: FluentIcons.ringer,
    group: 'Sistema',
  ),
  OperationalDestination(
    label: 'Sincronización',
    path: '/sync',
    icon: FluentIcons.sync,
    group: 'Sistema',
  ),
  OperationalDestination(
    label: 'Configuración',
    path: '/settings',
    icon: FluentIcons.settings,
    group: 'Sistema',
  ),
];

Widget _host(
  Size size, {
  ValueChanged<String>? onNavigate,
  bool locked = false,
  VoidCallback? onLock,
  Future<bool> Function(String password)? onUnlock,
  VoidCallback? onSwitchUser,
  VoidCallback? onToggleTheme,
  Widget? child,
  OperationalContext context = _context,
  List<OperationalDestination> destinations = _destinations,
  String selectedPath = '/sales',
  PaneDisplayMode navigationDisplayMode = PaneDisplayMode.auto,
  Widget navigationIndicator = const StickyNavigationIndicator(),
  FluentThemeData? theme,
}) => FluentApp(
  theme: theme ?? OrbiFluentTheme.light,
  home: MediaQuery(
    data: MediaQueryData(size: size),
    child: OperationalShell(
      destinations: destinations,
      selectedPath: selectedPath,
      onNavigate: onNavigate ?? (_) {},
      context: context,
      onLogout: () {},
      locked: locked,
      onLock: onLock,
      onUnlock: onUnlock,
      onSwitchUser: onSwitchUser,
      onToggleTheme: onToggleTheme,
      navigationDisplayMode: navigationDisplayMode,
      navigationIndicator: navigationIndicator,
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
  group('dónde están los cortes: los de Fluent', () {
    // Decisión del dueño del 13-sep-2026: sin cortes propios; el menú usa
    // PaneDisplayMode.auto (≤640 oculto, 641–1007 iconos, ≥1008 abierto).
    testWidgets('a 1920 en horizontal el carril lleva etiquetas', (
      tester,
    ) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);
      expect(
        tester
            .state<NavigationViewState>(find.byType(NavigationView))
            .displayMode,
        PaneDisplayMode.expanded,
      );
      expect(find.text('Órdenes'), findsWidgets);
    });

    testWidgets('a 1366 en horizontal el carril ya lleva etiquetas', (
      tester,
    ) async {
      const size = Size(1366, 1024);
      await _pump(tester, _host(size), size);
      expect(
        tester
            .state<NavigationViewState>(find.byType(NavigationView))
            .displayMode,
        PaneDisplayMode.expanded,
      );
    });

    testWidgets('justo por debajo de 1008 en horizontal no lleva etiquetas', (
      tester,
    ) async {
      const size = Size(1000, 700);
      await _pump(tester, _host(size), size);
      expect(
        tester
            .state<NavigationViewState>(find.byType(NavigationView))
            .displayMode,
        isNot(PaneDisplayMode.expanded),
      );
    });

    // Fluent decide sólo por el ancho: un iPad vertical de 1024 ya pasa de
    // 1008 y abre el menú, como en cualquier otra app de Fluent.
    testWidgets('en vertical manda el ancho, como en Fluent', (tester) async {
      const size = Size(1024, 1366);
      await _pump(tester, _host(size), size);
      expect(
        tester
            .state<NavigationViewState>(find.byType(NavigationView))
            .displayMode,
        PaneDisplayMode.expanded,
      );
    });

    testWidgets('en teléfono tampoco', (tester) async {
      const size = Size(390, 844);
      await _pump(tester, _host(size), size);
      expect(
        tester
            .state<NavigationViewState>(find.byType(NavigationView))
            .displayMode,
        PaneDisplayMode.minimal,
      );
    });
  });

  group('la barra superior en teléfono', () {
    // Reporte del dueño (captura de iPhone, Safari, tema oscuro,
    // 13-sep-2026): a este ancho sólo se veía una franja oscura vacía,
    // sin botón de menú ni avatar. Fijado el ancho a 390×844 —el mismo de
    // la captura— y el tema oscuro para reproducirlo.
    testWidgets(
      'a 390×844 en tema oscuro muestra el botón de menú y el avatar',
      (tester) async {
        const size = Size(390, 844);
        await _pump(
          tester,
          _host(size, theme: OrbiFluentTheme.dark),
          size,
        );
        expect(tester.takeException(), isNull);

        final menuButton = find.byKey(
          const Key('operational-menu-button'),
        );
        final avatar = find.byKey(const Key('shell-avatar-button'));
        expect(menuButton, findsOneWidget);
        expect(avatar, findsOneWidget);

        // No basta con que existan en el árbol: tienen que caer dentro del
        // rectángulo visible (390×844), nunca en tamaño cero ni fuera de
        // pantalla.
        final menuSize = tester.getSize(menuButton);
        final avatarSize = tester.getSize(avatar);
        expect(menuSize.width, greaterThan(0));
        expect(menuSize.height, greaterThan(0));
        expect(avatarSize.width, greaterThan(0));
        expect(avatarSize.height, greaterThan(0));

        final menuTopLeft = tester.getTopLeft(menuButton);
        final avatarTopLeft = tester.getTopLeft(avatar);
        expect(menuTopLeft.dx, greaterThanOrEqualTo(0));
        expect(menuTopLeft.dy, greaterThanOrEqualTo(0));
        expect(menuTopLeft.dy, lessThan(size.height));
        expect(avatarTopLeft.dx, greaterThanOrEqualTo(0));
        expect(avatarTopLeft.dx, lessThan(size.width));
        expect(avatarTopLeft.dy, greaterThanOrEqualTo(0));
        expect(avatarTopLeft.dy, lessThan(size.height));
      },
    );
  });

  // Orden del dueño, 13-sep-2026: el modo del carril y su indicador ahora se
  // eligen desde Ajustes; el marco sólo recibe y aplica lo que llega, sin
  // saber de preferencias (ver `router.dart`, que hace la traducción).
  group('el modo y el indicador del carril, parametrizados', () {
    testWidgets(
      'con la preferencia "compact" el marco usa compact incluso a 1920×1080',
      (tester) async {
        const size = Size(1920, 1080);
        await _pump(
          tester,
          _host(size, navigationDisplayMode: PaneDisplayMode.compact),
          size,
        );
        expect(
          tester
              .state<NavigationViewState>(find.byType(NavigationView))
              .displayMode,
          PaneDisplayMode.compact,
        );
      },
    );

    testWidgets('con "auto" (el valor por defecto) sigue resolviendo Fluent', (
      tester,
    ) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);
      expect(
        tester
            .state<NavigationViewState>(find.byType(NavigationView))
            .displayMode,
        PaneDisplayMode.expanded,
      );
    });

    testWidgets(
      'con el indicador "end", NavigationPane.indicator es EndNavigationIndicator',
      (tester) async {
        const size = Size(1920, 1080);
        await _pump(
          tester,
          _host(size, navigationIndicator: const EndNavigationIndicator()),
          size,
        );
        expect(
          tester
              .widget<NavigationView>(find.byType(NavigationView))
              .pane!
              .indicator,
          isA<EndNavigationIndicator>(),
        );
      },
    );

    // El dueño pidió comprobar explícitamente que "top" no rompe la barra
    // mínima ni la cabecera de empresa.
    //
    // 🔴 Sí rompía: Fluent mide la cabecera de `top` con ancho SIN LÍMITE, y
    // el `Expanded` que llevaba el nombre de empresa reventaba con «RenderFlex
    // children have non-zero flex but incoming width constraints are
    // unbounded» — ver la nota en `_paneHeader`. La cabecera del panel ya no
    // lleva el nombre de empresa (vive siempre en la barra superior, ver el
    // grupo «la barra superior» más abajo), así que ahora ni siquiera hay
    // ese `Expanded` que vigilar; esta prueba se queda para que nadie lo
    // vuelva a añadir sin pensar en `top`.
    testWidgets('con "top" no rompe la barra ni la cabecera', (tester) async {
      const size = Size(1920, 1080);
      await _pump(
        tester,
        _host(size, navigationDisplayMode: PaneDisplayMode.top),
        size,
      );
      expect(tester.takeException(), isNull);
      // En `top` los destinos de un grupo van dentro de su desplegable, así
      // que el texto de la hoja ("Órdenes") no está en pantalla sin abrirlo
      // — lo que sí está siempre es el título del grupo y el pie.
      expect(find.text('Ventas'), findsWidgets);
      expect(find.text('Servidor: erp.test'), findsOneWidget);
    });
  });

  group('el menú', () {
    testWidgets('agrupa por área y marca la pantalla que se está viendo', (
      tester,
    ) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);
      // La selección se cuenta sobre las entradas navegables, no sobre las
      // filas del menú: si se desplaza, se marca en azul una pantalla
      // distinta de la que se está viendo.
      expect(
        tester
            .widget<NavigationView>(find.byType(NavigationView))
            .pane!
            .selected,
        0,
      );
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

    // Orden del dueño, 13-sep-2026, comparando con `theos_pos`: «Inicio» es
    // hoy un grupo «Workspace» con un único hijo, que Fluent pintaría como un
    // desplegable de una sola fila. Se pide de primer nivel.
    group('«Inicio» ya no va en un desplegable de un solo hijo', () {
      testWidgets('se pinta como PaneItem de primer nivel', (tester) async {
        const size = Size(1920, 1080);
        await _pump(
          tester,
          _host(size, destinations: _richDestinations, selectedPath: '/'),
          size,
        );
        expect(find.text('Inicio'), findsOneWidget);
        // `PaneItem`/`PaneItemExpander` son datos, no widgets montados —
        // Fluent nunca los deja buscables por tipo. Lo comprobable es que ya
        // no exista el título de grupo «Workspace»: si Inicio siguiera
        // agrupado, Fluent lo pintaría igual que pinta «Ventas»/«Envases»
        // en las otras pruebas de este archivo.
        expect(find.text('Workspace'), findsNothing);
        expect(
          tester
              .widget<NavigationView>(find.byType(NavigationView))
              .pane!
              .selected,
          0,
          reason: 'Inicio sigue siendo el primer destino del índice plano',
        );
      });
    });

    // Actividades y Avisos se mudan a la barra superior (mismo grupo
    // «Sistema» que trae `router.dart`, pero repetirlos en el menú lateral
    // los mostraba dos veces); Sincronización y Configuración, al pie.
    group('«Sistema» se reparte entre la barra superior y el pie', () {
      testWidgets('ya no queda un desplegable "Sistema" en el menú', (
        tester,
      ) async {
        const size = Size(1920, 1080);
        await _pump(tester, _host(size, destinations: _richDestinations), size);
        expect(find.widgetWithText(PaneItemExpander, 'Sistema'), findsNothing);
      });

      testWidgets('Actividades y Avisos están en la barra superior', (
        tester,
      ) async {
        const size = Size(1920, 1080);
        await _pump(tester, _host(size, destinations: _richDestinations), size);
        expect(find.byKey(const Key('shell-activities-button')), findsOneWidget);
        expect(find.byKey(const Key('shell-notices-button')), findsOneWidget);
      });

      testWidgets(
        'Sincronización y Configuración están en el pie del panel',
        (tester) async {
          const size = Size(1920, 1080);
          await _pump(
            tester,
            _host(size, destinations: _richDestinations),
            size,
          );
          final pane = tester
              .widget<NavigationView>(find.byType(NavigationView))
              .pane!;
          final footerPaths = pane.footerItems
              .whereType<PaneItem>()
              .map((item) => (item.key! as ValueKey<String>).value)
              .toSet();
          expect(footerPaths, {'/sync', '/settings'});
        },
      );
    });
  });

  group('el pie', () {
    testWidgets('en ancho dice servidor, base y estado', (tester) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);

      expect(find.text('Servidor: erp.test'), findsOneWidget);
      expect(find.text('BD: orbi_test'), findsOneWidget);
      expect(find.text('3 pendientes'), findsOneWidget);
    });

    // Causa raíz medida el 13-sep-2026: `router.dart` nunca llenaba
    // `serverTime` (ver la nota en `operational_shell.dart:_contextFooter`),
    // y no hay de dónde sacar la hora real del servidor — ni `orbi_runtime`
    // la mide, ni `theos_pos` la tiene de verdad (su desfase es cero
    // siempre). Se opta por mostrar la hora del dispositivo, con una
    // etiqueta que no finge ser la del servidor.
    testWidgets('nunca dice "sin dato": sin hora de servidor, muestra la '
        'del dispositivo', (tester) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);

      expect(find.textContaining('sin dato'), findsNothing);
      expect(
        find.byWidgetPredicate(
          (widget) => widget is Text && (widget.data ?? '').startsWith('Hora: '),
        ),
        findsOneWidget,
      );
    });

    testWidgets('con hora de servidor, la usa y la etiqueta como tal', (
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
            serverTime: '13/09/2026 10:00:00',
            connectionLabel: 'Conectado',
            syncLabel: 'al día',
          ),
        ),
        size,
      );

      expect(find.text('Hora servidor: 13/09/2026 10:00:00'), findsOneWidget);
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

        // Dos veces a propósito: la píldora de la barra superior reusa este
        // mismo texto para "unknown" (no tiene una redacción propia para un
        // estado que el dueño no nombró), y el pie de abajo también lo dice.
        expect(find.text('Red sin verificar'), findsNWidgets(2));
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

  group('la barra superior', () {
    testWidgets('la empresa se ve, siempre, junto al usuario', (
      tester,
    ) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);
      expect(find.text('Empresa Demo'), findsOneWidget);
      expect(find.text('Erik'), findsOneWidget);
    });

    // El bloque de usuario/avatar decide por su propio ancho (840, el mismo
    // corte de `OrbiTheme.mediumBreakpoint`), no por el modo del carril: en
    // angosto sólo el avatar es alcanzable, sin que el nombre se corte a la
    // mitad.
    testWidgets('bajo 840 de ancho el texto se esconde y sólo queda el avatar', (
      tester,
    ) async {
      const size = Size(800, 900);
      await _pump(tester, _host(size), size);
      expect(find.text('Empresa Demo'), findsNothing);
      expect(find.byKey(const Key('shell-avatar-button')), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'sin red la píldora dice «Sin conexión», sin latencia inventada',
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
              connectionLabel: 'da igual, manda el estado medido',
              connectionStatus: ConnectionStatus.offline,
              syncLabel: 'al día',
            ),
          ),
          size,
        );

        expect(find.text('Sin conexión'), findsOneWidget);
        expect(find.textContaining(' ms'), findsNothing);
      },
    );

    testWidgets('en línea, sin una medida de ida y vuelta, no inventa milisegundos', (
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
            connectionLabel: 'Conectado',
            connectionStatus: ConnectionStatus.online,
            syncLabel: 'al día',
          ),
        ),
        size,
      );

      expect(find.text('En línea'), findsOneWidget);
      expect(find.textContaining(' ms'), findsNothing);
    });

    testWidgets(
      'en línea y con latencia medida, la muestra tal cual llega',
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
              connectionLabel: 'Conectado',
              connectionStatus: ConnectionStatus.online,
              connectionLatency: Duration(milliseconds: 349),
              syncLabel: 'al día',
            ),
          ),
          size,
        );

        expect(find.text('En línea 349 ms'), findsOneWidget);
      },
    );

    testWidgets('sin onToggleTheme no se ofrece el botón de tema', (
      tester,
    ) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);
      expect(find.byKey(const Key('shell-theme-toggle')), findsNothing);
    });

    testWidgets('con onToggleTheme, tocarlo lo llama', (tester) async {
      const size = Size(1920, 1080);
      var toggled = false;
      await _pump(
        tester,
        _host(size, onToggleTheme: () => toggled = true),
        size,
      );
      await tester.tap(find.byKey(const Key('shell-theme-toggle')));
      await tester.pumpAndSettle();
      expect(toggled, isTrue);
    });

    // Una prueba por ancho, cada una con su propio `tester` limpio: Fluent
    // ANIMA la apertura/cierre del carril al cambiar de modo, y reusar el
    // mismo árbol para saltar de 800 (carril de iconos) a 1280 (carril
    // abierto) atrapa un fotograma intermedio de esa animación —no un
    // defecto real, sino el mismo tipo de sobresalto transitorio que ya
    // documenta `pane_items.dart` de Fluent. Medido el 13-sep-2026.
    for (final width in [400.0, 800.0, 1280.0]) {
      testWidgets(
        'a ${width.toInt()} px no desborda: las acciones se ven o están '
        'en el desbordamiento, nunca se cortan',
        (tester) async {
          final size = Size(width, 900);
          await _pump(
            tester,
            _host(size, destinations: _richDestinations, onToggleTheme: () {}),
            size,
          );
          expect(tester.takeException(), isNull);

          final overflow = find.byKey(const Key('shell-topbar-overflow'));
          if (find.text('Avisos').evaluate().isEmpty &&
              overflow.evaluate().isNotEmpty) {
            await tester.tap(overflow);
            await tester.pumpAndSettle();
          }
          expect(
            find.text('Avisos'),
            findsWidgets,
            reason: 'Avisos debe verse o estar en el "…"',
          );
          expect(
            find.text('Actividades'),
            findsWidgets,
            reason: 'Actividades debe verse o estar en el "…"',
          );
        },
      );
    }
  });

  group('sesión', () {
    testWidgets(
      'no ofrece bloquear ni cambiar de usuario si no puede hacerlo',
      (tester) async {
        const size = Size(1920, 1080);
        await _pump(tester, _host(size), size);

        await tester.tap(find.byKey(const Key('shell-avatar-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lock-button')), findsNothing);
        expect(find.byKey(const Key('switch-user-button')), findsNothing);
        // Cerrar sesión siempre se puede.
        expect(find.byKey(const Key('logout-button')), findsOneWidget);
      },
    );

    // El pie del panel ya no lleva estas acciones sueltas (orden del dueño,
    // 13-sep-2026): viven en el menú del avatar de la barra superior.
    testWidgets(
      'el menú del avatar trae Bloquear, Cambiar de usuario y Cerrar '
      'sesión, y el pie del panel ya no',
      (tester) async {
        const size = Size(1920, 1080);
        await _pump(
          tester,
          _host(
            size,
            onLock: () {},
            onUnlock: (_) async => true,
            onSwitchUser: () {},
          ),
          size,
        );

        // Sin abrir el menú, ninguna de las tres está suelta en el pie.
        expect(find.byKey(const Key('lock-button')), findsNothing);
        expect(find.byKey(const Key('switch-user-button')), findsNothing);
        expect(find.byKey(const Key('logout-button')), findsNothing);

        await tester.tap(find.byKey(const Key('shell-avatar-button')));
        await tester.pumpAndSettle();

        expect(find.byKey(const Key('lock-button')), findsOneWidget);
        expect(find.byKey(const Key('switch-user-button')), findsOneWidget);
        expect(find.byKey(const Key('logout-button')), findsOneWidget);
        expect(find.text('Mis preferencias'), findsOneWidget);
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

      await tester.tap(find.byKey(const Key('shell-avatar-button')));
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('lock-button')));
      await tester.pumpAndSettle();
      expect(bloqueado, isTrue);
      expect(cambiado, isFalse);

      await tester.tap(find.byKey(const Key('shell-avatar-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('switch-user-button')));
      await tester.pumpAndSettle();
      expect(cambiado, isTrue);
    });

    testWidgets('«Mis preferencias» navega a Configuración', (tester) async {
      const size = Size(1920, 1080);
      String? navegado;
      await _pump(tester, _host(size, onNavigate: (p) => navegado = p), size);

      await tester.tap(find.byKey(const Key('shell-avatar-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('shell-preferences-item')));
      await tester.pumpAndSettle();

      expect(navegado, '/settings');
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

  group('la cabecera del panel la pone Fluent, no nosotros', () {
    // La marca vive en `NavigationPane.header`, que Fluent coloca y esconde
    // por su cuenta. La empresa ya NO se repite aquí (orden del dueño,
    // 13-sep-2026): vive siempre en la barra superior, así que el panel sólo
    // lleva el logo.
    testWidgets('el carril abierto sólo trae la marca, no la empresa', (
      tester,
    ) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);

      // Un solo "Empresa Demo" en toda la pantalla: si el panel también lo
      // repitiera, esto encontraría dos.
      expect(find.text('Empresa Demo'), findsOneWidget);
    });

    // Fluent esconde la cabecera del panel en el carril de sólo iconos. La
    // barra superior (con el contexto de servidor y la empresa) sigue
    // viéndose siempre, y con ella el pie.
    testWidgets('en el carril de iconos, la barra y el pie no dependen de él', (
      tester,
    ) async {
      // 1000 px horizontal: por debajo del corte de 1008, el carril es de iconos.
      const size = Size(1000, 700);
      await _pump(tester, _host(size), size);

      expect(find.text('Servidor: erp.test'), findsOneWidget);
      // A 1000 ya se pasa del corte de 840 de la barra superior, así que la
      // empresa se ve ahí — el carril de iconos no la esconde por debajo.
      expect(find.text('Empresa Demo'), findsOneWidget);
    });
  });

  // 🔴 La prueba que faltaba, y el defecto más grave de la migración: en
  // vertical y en teléfono **no había forma de abrir el menú**. Ni carril, ni
  // hamburguesa, ni nada: quien entrara se quedaba encerrado en la pantalla en
  // la que estuviese. Se vio abriendo la aplicación a 500 de ancho, no aquí.
  group('en estrecho SIEMPRE hay forma de llegar al menú', () {
    testWidgets('a 500 en vertical hay un botón de menú y abre el panel', (
      tester,
    ) async {
      const size = Size(500, 613);
      await _pump(tester, _host(size), size);

      final boton = find.byKey(const Key('operational-menu-button'));
      expect(
        boton,
        findsOneWidget,
        reason: 'sin esto la persona queda encerrada en la pantalla actual',
      );

      // Y abre de verdad. Se comprueba contra el estado del propio
      // `NavigationView` y no contra si el texto está en el árbol: en modo
      // estrecho el panel se construye igual, sólo que fuera de la vista, así
      // que buscar el texto daría verde con el menú cerrado.
      final estado = tester.state<NavigationViewState>(
        find.byType(NavigationView),
      );
      expect(estado.isMinimalPaneOpen, isFalse);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(estado.isMinimalPaneOpen, isTrue);
    });

    testWidgets('a 390 en teléfono también', (tester) async {
      const size = Size(390, 844);
      await _pump(tester, _host(size), size);

      expect(find.byKey(const Key('operational-menu-button')), findsOneWidget);
    });

    // En ancho el carril ya está a la vista, así que un botón de menú sobraría
    // y ocuparía sitio.
    testWidgets('en ancho no aparece, porque el carril ya está', (
      tester,
    ) async {
      const size = Size(1920, 1080);
      await _pump(tester, _host(size), size);

      expect(find.byKey(const Key('operational-menu-button')), findsNothing);
    });
  });
}
