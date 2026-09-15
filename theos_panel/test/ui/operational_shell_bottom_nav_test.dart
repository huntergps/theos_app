import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/app/theme/orbi_theme.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';
import 'package:theos_panel/ui/layouts/operational_shell.dart';

/// El armazón operativo en vertical angosto (teléfono e iPad vertical),
/// comparado contra las láminas aprobadas
/// (`docs/orbi_panel/visual_baselines/approved/round-02/ENV-01.png`,
/// `round-03/SHELL-01.png`): barra inferior con hasta cuatro destinos más
/// «Más» (o tres más el «+» en su propio puesto, con acción principal),
/// barra superior compacta (menú, marca, avisos, avatar) y una franja de
/// estado fina al pie — orden del dueño, 15-sep-2026, corregido el mismo día
/// tras revisión: el corte de ancho es el del iPad vertical de la lámina
/// (1024), el «+» tiene su propio puesto en la fila, y «Actividades» entra
/// al panel de «Más».
///
/// Seis nav destinations reales (más «Sistema», que nunca entra al menú
/// principal salvo «Actividades» en modo barra inferior): con selectedPath
/// en el sexto, sobra para probar que la pantalla activa se abre paso en la
/// barra inferior aunque no esté entre los primeros cuatro.
const _destinations = [
  OperationalDestination(
    label: 'Inicio',
    path: '/',
    icon: FluentIcons.home,
    group: 'Workspace',
  ),
  OperationalDestination(
    label: 'Envases',
    path: '/inventario/envases',
    icon: FluentIcons.product,
    group: 'Inventario',
  ),
  OperationalDestination(
    label: 'Movimientos',
    path: '/inventario/movimientos',
    icon: FluentIcons.issue_tracking,
    group: 'Inventario',
  ),
  OperationalDestination(
    label: 'Reportes',
    path: '/reportes',
    icon: FluentIcons.bar_chart_vertical_fill,
    group: 'Reportes',
  ),
  OperationalDestination(
    label: 'Clientes',
    path: '/clientes',
    icon: FluentIcons.people,
    group: 'Comercial',
  ),
  OperationalDestination(
    label: 'Proveedores',
    path: '/proveedores',
    icon: FluentIcons.product_variant,
    group: 'Compras',
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

const _context = OperationalContext(
  server: 'erp.test',
  database: 'orbi_test',
  userLabel: 'Erik',
  companyLabel: 'Empresa Demo',
  connectionLabel: 'Conectado',
  syncLabel: '3 pendientes',
);

Widget _host(
  Size size, {
  String selectedPath = '/inventario/envases',
  ValueChanged<String>? onNavigate,
  String? primaryActionPath,
  FluentThemeData? theme,
}) => FluentApp(
  theme: theme ?? OrbiFluentTheme.light,
  home: MediaQuery(
    data: MediaQueryData(size: size),
    child: OperationalShell(
      destinations: _destinations,
      selectedPath: selectedPath,
      onNavigate: onNavigate ?? (_) {},
      context: _context,
      onLogout: () {},
      primaryActionPath: primaryActionPath,
      // `null`: un `Timer.periodic` vivo nunca deja terminar a
      // `pumpAndSettle()` (ver la nota en `_FooterClock`).
      clockTickInterval: null,
      child: const Center(child: Text('Contenido operativo')),
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
  group('barra inferior en teléfono e iPad vertical', () {
    // (a) 390×844.
    testWidgets(
      'a 390×844 hay barra inferior con Inicio y Más, sin carril lateral '
      'ni píldoras arriba',
      (tester) async {
        const size = Size(390, 844);
        await _pump(tester, _host(size), size);

        expect(find.byKey(const Key('shell-bottom-nav-bar')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('shell-bottom-nav-bar')),
            matching: find.text('Inicio'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('shell-bottom-nav-bar')),
            matching: find.text('Más'),
          ),
          findsOneWidget,
        );

        // Sin carril lateral: Fluent queda forzado a `minimal`, nunca a
        // `compact` (el carril de sólo iconos que antes se veía a este
        // ancho de iPad, ver la nota de [_pane]).
        expect(
          tester
              .state<NavigationViewState>(find.byType(NavigationView))
              .displayMode,
          PaneDisplayMode.minimal,
        );

        // Las píldoras de conexión/tiempo real ya no viven arriba.
        expect(
          find.byKey(const Key('shell-connectivity-pill')),
          findsNothing,
        );
        expect(find.byKey(const Key('shell-realtime-pill')), findsNothing);

        // La franja de estado, en cambio, sí se ve siempre — sin pedirse.
        final strip = find.byKey(const Key('shell-bottom-status-strip'));
        expect(strip, findsOneWidget);
        expect(find.text('Conectado'), findsOneWidget);
        expect(find.text('3 pendientes'), findsOneWidget);

        // Y queda DEBAJO de la barra inferior, como en `SHELL-01`.
        final barBottom = tester
            .getBottomLeft(find.byKey(const Key('shell-bottom-nav-bar')))
            .dy;
        final stripTop = tester.getTopLeft(strip).dy;
        expect(stripTop, greaterThanOrEqualTo(barBottom));
      },
    );

    // (b) 834×1194: mismas comprobaciones — antes de este cambio, este
    // ancho caía en el carril de sólo iconos de Fluent (`compact`), no en
    // `minimal`.
    testWidgets(
      'a 834×1194 (iPad vertical) también, sin el carril compacto de '
      'iconos',
      (tester) async {
        const size = Size(834, 1194);
        await _pump(tester, _host(size), size);

        expect(find.byKey(const Key('shell-bottom-nav-bar')), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const Key('shell-bottom-nav-bar')),
            matching: find.text('Inicio'),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('shell-bottom-nav-bar')),
            matching: find.text('Más'),
          ),
          findsOneWidget,
        );
        expect(
          tester
              .state<NavigationViewState>(find.byType(NavigationView))
              .displayMode,
          isNot(PaneDisplayMode.compact),
        );
        expect(
          tester
              .state<NavigationViewState>(find.byType(NavigationView))
              .displayMode,
          PaneDisplayMode.minimal,
        );
        expect(
          find.byKey(const Key('shell-connectivity-pill')),
          findsNothing,
        );
        expect(find.byKey(const Key('shell-bottom-status-strip')), findsOneWidget);
      },
    );

    // (c) no-regresión: en horizontal el armazón se queda exactamente como
    // antes — sin barra inferior, con el panel de Fluent resuelto por su
    // propio ancho. Esta prueba tiene que seguir en VERDE contra b0645cd.
    for (final size in [const Size(1366, 1024), const Size(1920, 1080)]) {
      testWidgets(
        'a ${size.width.toInt()}×${size.height.toInt()} (horizontal) no '
        'hay barra inferior: el panel se ve como siempre',
        (tester) async {
          await _pump(tester, _host(size), size);

          expect(find.byKey(const Key('shell-bottom-nav-bar')), findsNothing);
          expect(
            find.byKey(const Key('shell-bottom-status-strip')),
            findsNothing,
          );
          expect(
            tester
                .state<NavigationViewState>(find.byType(NavigationView))
                .displayMode,
            PaneDisplayMode.expanded,
          );
        },
      );
    }

    // (g) 1024×1366: el iPad vertical EXACTO de `round-03/SHELL-01.png`
    // (rotulado ahí «iPad Vertical (1024 × 1366)», dibujado con barra
    // inferior). Contra a3eba8d falla: esa versión usaba el corte de Fluent
    // (1008), que deja 1024 fuera.
    testWidgets(
      'a 1024×1366 (el iPad vertical exacto de SHELL-01) también hay barra '
      'inferior',
      (tester) async {
        const size = Size(1024, 1366);
        await _pump(tester, _host(size), size);

        expect(find.byKey(const Key('shell-bottom-nav-bar')), findsOneWidget);
        expect(
          tester
              .state<NavigationViewState>(find.byType(NavigationView))
              .displayMode,
          PaneDisplayMode.minimal,
        );
      },
    );

    // No-regresión complementaria a (c): un pelo más ancho que el iPad
    // vertical de la lámina ya NO lleva barra inferior.
    testWidgets(
      'a 1025×1366 (más ancho que el iPad vertical de la lámina) no hay '
      'barra inferior',
      (tester) async {
        const size = Size(1025, 1366);
        await _pump(tester, _host(size), size);

        expect(find.byKey(const Key('shell-bottom-nav-bar')), findsNothing);
        expect(
          tester
              .state<NavigationViewState>(find.byType(NavigationView))
              .displayMode,
          PaneDisplayMode.expanded,
        );
      },
    );

    // (d) «Más» abre el panel completo, y un destino navega a su ruta.
    testWidgets('«Más» abre el panel; un destino navega a su ruta', (
      tester,
    ) async {
      const size = Size(390, 844);
      String? navegado;
      await _pump(
        tester,
        _host(size, onNavigate: (p) => navegado = p),
        size,
      );

      final state = tester.state<NavigationViewState>(
        find.byType(NavigationView),
      );
      expect(state.isMinimalPaneOpen, isFalse);
      await tester.tap(find.byKey(const Key('shell-bottom-nav-more')));
      await tester.pumpAndSettle();
      expect(state.isMinimalPaneOpen, isTrue);

      // Cierra el panel para poder tocar la pestaña de abajo sin que la
      // cortina del panel se lo trague.
      state.isMinimalPaneOpen = false;
      await tester.pumpAndSettle();

      await tester.tap(
        find.byKey(const Key('shell-bottom-nav-tab-/inventario/movimientos')),
      );
      await tester.pumpAndSettle();
      expect(navegado, '/inventario/movimientos');
    });

    // (e) la ruta actual se abre paso aunque no esté entre los primeros
    // cuatro destinos, y queda marcada con el color de acento.
    testWidgets(
      'la ruta actual (quinta en orden) desplaza a la cuarta y se marca '
      'con el acento',
      (tester) async {
        const size = Size(390, 844);
        final theme = OrbiFluentTheme.light;
        await _pump(
          tester,
          _host(size, selectedPath: '/proveedores', theme: theme),
          size,
        );

        // Orden del menú principal: Inicio, Envases, Movimientos, Reportes,
        // Clientes, Proveedores — «Proveedores» es el sexto, fuera de los
        // primeros cuatro (Inicio, Envases, Movimientos, Reportes).
        expect(
          find.byKey(const Key('shell-bottom-nav-tab-/proveedores')),
          findsOneWidget,
          reason: 'la pantalla activa tiene que verse, aunque desplace a otra',
        );
        expect(
          find.byKey(const Key('shell-bottom-nav-tab-/reportes')),
          findsNothing,
          reason: 'desplazada: sólo caben cuatro destinos más «Más»',
        );
        // Los tres primeros, intactos.
        expect(find.byKey(const Key('shell-bottom-nav-tab-/')), findsOneWidget);
        expect(
          find.byKey(const Key('shell-bottom-nav-tab-/inventario/envases')),
          findsOneWidget,
        );
        expect(
          find.byKey(
            const Key('shell-bottom-nav-tab-/inventario/movimientos'),
          ),
          findsOneWidget,
        );

        final icon = tester.widget<Icon>(
          find.descendant(
            of: find.byKey(const Key('shell-bottom-nav-tab-/proveedores')),
            matching: find.byIcon(FluentIcons.product_variant),
          ),
        );
        expect(icon.color, theme.accentColor.normal);
      },
    );
  });

  group('el botón «+» de acción principal', () {
    // (f) con acción principal declarada, se ve y navega.
    testWidgets('con primaryActionPath se ve el «+» y navega', (
      tester,
    ) async {
      const size = Size(390, 844);
      String? navegado;
      await _pump(
        tester,
        _host(
          size,
          onNavigate: (p) => navegado = p,
          primaryActionPath: '/inventario/envases/enviar',
        ),
        size,
      );

      final boton = find.byKey(const Key('shell-bottom-nav-primary-action'));
      expect(boton, findsOneWidget);

      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(navegado, '/inventario/envases/enviar');
    });

    // (f) sin acción principal, no hay botón.
    testWidgets('sin primaryActionPath no hay «+»', (tester) async {
      const size = Size(390, 844);
      await _pump(tester, _host(size), size);

      expect(
        find.byKey(const Key('shell-bottom-nav-primary-action')),
        findsNothing,
      );
    });

    // (h) el «+» ocupa su PROPIO puesto en la fila: nunca se superpone con
    // ninguna de las cuatro pestañas (los tres destinos reales más «Más»).
    // Contra a3eba8d falla: el «+» flotaba centrado sobre TODA la barra y
    // caía encima de la segunda pestaña.
    testWidgets(
      'con acción principal, el «+» y las 4 pestañas no se superponen',
      (tester) async {
        const size = Size(390, 844);
        await _pump(
          tester,
          _host(size, primaryActionPath: '/inventario/envases/enviar'),
          size,
        );

        final primaryActionRect = tester.getRect(
          find.byKey(const Key('shell-bottom-nav-primary-action')),
        );
        final tabKeys = [
          const Key('shell-bottom-nav-tab-/'),
          const Key('shell-bottom-nav-tab-/inventario/envases'),
          const Key('shell-bottom-nav-tab-/inventario/movimientos'),
          const Key('shell-bottom-nav-more'),
        ];
        for (final key in tabKeys) {
          final tabRect = tester.getRect(find.byKey(key));
          expect(
            primaryActionRect.overlaps(tabRect),
            isFalse,
            reason:
                'el «+» ($primaryActionRect) se superpone con la pestaña '
                '$key ($tabRect)',
          );
        }
      },
    );
  });

  group('«Actividades» en modo barra inferior', () {
    // (i) sólo alcanzable desde «Más» (o el menú) en este modo — nunca en la
    // barra superior compacta. Contra a3eba8d falla: Actividades no tenía
    // ningún punto de entrada en modo barra inferior.
    testWidgets(
      'abrir «Más» muestra Actividades y navega a su ruta',
      (tester) async {
        const size = Size(390, 844);
        String? navegado;
        await _pump(
          tester,
          _host(size, onNavigate: (p) => navegado = p),
          size,
        );

        // No vive en la barra superior compacta: ahí sólo hay campana de
        // avisos y avatar.
        expect(
          find.byKey(const Key('shell-activities-button')),
          findsNothing,
        );

        await tester.tap(find.byKey(const Key('shell-bottom-nav-more')));
        await tester.pumpAndSettle();

        expect(find.text('Actividades'), findsOneWidget);
        await tester.tap(find.text('Actividades'));
        await tester.pumpAndSettle();
        expect(navegado, '/activities');
      },
    );
  });

  // El corte en sí: el ancho del iPad vertical EXACTO de `SHELL-01.png`
  // («iPad Vertical (1024 × 1366)»), no el de Fluent (1008) — corregido el
  // 15-sep-2026 tras revisión: la primera versión reutilizaba el de Fluent y
  // dejaba fuera a ese iPad.
  test(
    'el corte del armazón es el ancho del iPad vertical de SHELL-01 (1024)',
    () {
      expect(OrbiTheme.bottomNavigationMaxPortraitWidth, 1024.0);
    },
  );
}
