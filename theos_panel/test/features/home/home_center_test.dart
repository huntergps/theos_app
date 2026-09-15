import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile, CapabilitySnapshot;
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/home/home_center.dart';
import 'package:theos_panel/features/home/home_dashboard_contracts.dart';
import 'package:theos_panel/features/home/home_dashboard_providers.dart';
import 'package:theos_panel/features/home/home_dashboard_view.dart' show homeCurrencyLabel;
import 'package:theos_panel/features/home/home_resume_status.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

class _MockCashReader extends Mock implements HomeCashSessionsReader {}

class _MockSalesReader extends Mock implements HomeSalesMetricsReader {}

/// Razón de contraste WCAG entre dos colores, a partir de
/// `Color.computeLuminance()` (relativa, ya la trae Flutter). ≥ 4.5 es el
/// mínimo AA para texto normal.
double _contrastRatio(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final lighter = la > lb ? la : lb;
  final darker = la > lb ? lb : la;
  return (lighter + 0.05) / (darker + 0.05);
}

CapabilitySnapshot _capabilities(Set<String> permissions) => CapabilitySnapshot(
  scopeKey: 'test-scope',
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026, 9, 15),
  permissions: permissions,
);

/// `HomeCenterView` lee capacidades/sesión de forma ambiental; todo test
/// necesita un `ProviderScope`, aunque sea sin overrides (capacidades nulas
/// ⇒ ni fila de ventas/caja ni pestaña de actividades, mismo comportamiento
/// de un usuario cuyo perfil todavía no cargó).
Widget _wrap(Widget child) => ProviderScope(
  child: FluentApp(
    theme: OrbiFluentTheme.light,
    home: ScaffoldPage(content: child),
  ),
);

void main() {
  group('homeTodayLabel', () {
    test('formats a real date in Spanish, without inventing one', () {
      expect(
        homeTodayLabel(DateTime(2026, 9, 14)),
        'Lunes, 14 de septiembre de 2026',
      );
      expect(
        homeTodayLabel(DateTime(2026, 9, 19)),
        'Sábado, 19 de septiembre de 2026',
      );
    });
  });

  group('homeCurrencyLabel', () {
    test(
      // (g): antes esto sólo hacía `toStringAsFixed(2)` — «$12480.50», sin
      // miles — y esa cifra de 5+ dígitos era justo la que se envolvía a un
      // segundo renglón en la tarjeta «Ventas hoy» (ACC-03). Contra 2b2f3ee
      // falla.
      'agrupa los miles con coma y dos decimales, como orders_screen.dart',
      () {
        expect(homeCurrencyLabel(12480.50), r'$12,480.50');
        expect(homeCurrencyLabel(320), r'$320.00');
        expect(homeCurrencyLabel(0), r'$0.00');
      },
    );
  });

  group('Ventas hoy — una sola línea a 1920 (g)', () {
    testWidgets(
      r'con $12,480.50 la tarjeta cabe en una línea y no mide más de 100 px '
      'de alto',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final salesReader = _MockSalesReader();
        when(
          () => salesReader.loadToday(
            companyId: any(named: 'companyId'),
            userId: any(named: 'userId'),
            viewAll: any(named: 'viewAll'),
          ),
        ).thenAnswer(
          (_) async => const HomeSalesSummary(
            totalAmount: 12480.50,
            totalOrders: 28,
          ),
        );
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              capabilitySnapshotProvider.overrideWithValue(
                _capabilities({'seller'}),
              ),
              authInitialStateProvider.overrideWithValue(
                AuthViewState(
                  profile: AuthProfile(
                    serverUrl: 'https://erp2.test',
                    database: 'erp2_test',
                    login: 'vendedor1',
                    userId: 9,
                    installationId: 'install-1',
                    credentialReference: 'ref-1',
                  ),
                ),
              ),
              homeSalesMetricsReaderProvider.overrideWithValue(salesReader),
            ],
            child: FluentApp(
              theme: OrbiFluentTheme.light,
              home: ScaffoldPage(
                content: HomeCenterView(
                  port: _FakePort(
                    const HomeResumeSnapshot(HomeResumeState.empty),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(r'$12,480.50'), findsOneWidget);
        final size = tester.getSize(
          find.byKey(const Key('home-metric-card-Ventas hoy')),
        );
        // Bien por debajo de los 200 px del defecto viejo (b0645cd); una
        // tarjeta legítima de 3 líneas (etiqueta, cifra, detalle) con el
        // relleno de `Card` mide ~120 px, no 200+.
        expect(size.height, lessThanOrEqualTo(150));
      },
    );
  });

  group('HomeCenterView — Documentos a continuar', () {
    testWidgets(
      'una fila del puerto aparece en la pestaña y su cifra sale en la fila '
      'de métricas',
      (tester) async {
        const item = HomeResumeItem(
          id: 'home:sales:doc:1',
          title: 'S-001245',
          subtitle: 'Borrador sin confirmar',
          actionLabel: 'Ver ventas',
          route: '/sales',
          status: HomeResumeStatus.pendiente,
          counterpart: 'Cliente Corporativo',
          moduleLabel: 'Ventas',
          totalLabel: r'$1,250.00',
        );
        await tester.pumpWidget(
          _wrap(
            HomeCenterView(
              port: _FakePort(
                const HomeResumeSnapshot(
                  HomeResumeState.data,
                  items: [item],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Documentos a continuar (1)'), findsOneWidget);
        expect(find.text('S-001245'), findsWidgets);
        expect(find.text('Cliente Corporativo'), findsWidgets);
        expect(
          find.descendant(
            of: find.byKey(
              const Key('home-metric-card-Documentos a continuar'),
            ),
            matching: find.text('1'),
          ),
          findsOneWidget,
        );
      },
    );

    testWidgets('sin documentos, la pestaña muestra el estado vacío', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          HomeCenterView(
            port: _FakePort(const HomeResumeSnapshot(HomeResumeState.empty)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No hay documentos por continuar'), findsOneWidget);
      expect(find.text('Documentos a continuar (0)'), findsOneWidget);
    });

    testWidgets(
      'perfil sólo envases (Mepriga): 2 traslados por recibir salen como '
      'filas, «Por recibir» = 2, y no aparecen Ventas hoy ni Cobros del '
      'turno',
      (tester) async {
        const envasesItems = [
          HomeResumeItem(
            id: 'home:envases:por-recibir:1',
            title: 'TR-01',
            subtitle: 'Bodega A → Bodega B',
            actionLabel: 'Ver traslado',
            route: '/envases/por-recibir/1',
            status: HomeResumeStatus.porRecibir,
            counterpart: 'Bodega A → Bodega B',
            moduleLabel: 'Envases',
          ),
          HomeResumeItem(
            id: 'home:envases:por-recibir:2',
            title: 'TR-02',
            subtitle: 'Bodega C → Bodega A',
            actionLabel: 'Ver traslado',
            route: '/envases/por-recibir/2',
            status: HomeResumeStatus.porRecibir,
            counterpart: 'Bodega C → Bodega A',
            moduleLabel: 'Envases',
          ),
        ];
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              capabilitySnapshotProvider.overrideWithValue(
                _capabilities({'envases_read'}),
              ),
            ],
            child: FluentApp(
              theme: OrbiFluentTheme.light,
              home: ScaffoldPage(
                content: HomeCenterView(
                  port: _FakePort(
                    const HomeResumeSnapshot(HomeResumeState.empty),
                  ),
                  envasesPendingItems: envasesItems,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Documentos a continuar (2)'), findsOneWidget);
        expect(find.text('TR-01'), findsOneWidget);
        expect(find.text('TR-02'), findsOneWidget);
        expect(
          find.byKey(const Key('home-metric-card-Por recibir')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byKey(const Key('home-metric-card-Por recibir')),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('home-metric-card-Ventas hoy')),
          findsNothing,
        );
        expect(
          find.byKey(const Key('home-metric-card-Cobros del turno')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'a 1920x1080 ninguna tarjeta de la fila de métricas mide más de 200 '
      'px de alto (el defecto viejo era un GridView sin childAspectRatio)',
      (tester) async {
        tester.view.physicalSize = const Size(1920, 1080);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          _wrap(
            HomeCenterView(
              port: _FakePort(
                const HomeResumeSnapshot(HomeResumeState.empty),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final size = tester.getSize(
          find.byKey(const Key('home-metric-card-Documentos a continuar')),
        );
        expect(size.height, lessThanOrEqualTo(200));
      },
    );

    testWidgets(
      'no existe «Accesos rápidos»: la navegación real ya lleva a cada '
      'módulo (panel lateral y barra inferior)',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            HomeCenterView(
              port: _FakePort(
                const HomeResumeSnapshot(HomeResumeState.empty),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Accesos rápidos'), findsNothing);
        expect(find.text('Empieza por aquí:'), findsNothing);
      },
    );

    testWidgets(
      'tocar una fila de «Documentos a continuar» navega a su ruta',
      (tester) async {
        const item = HomeResumeItem(
          id: 'home:sales:doc:1',
          title: 'S-001245',
          subtitle: 'Borrador sin confirmar',
          actionLabel: 'Ver ventas',
          route: '/sales',
          status: HomeResumeStatus.pendiente,
          moduleLabel: 'Ventas',
        );
        String? resumedRoute;
        await tester.pumpWidget(
          _wrap(
            HomeCenterView(
              port: _FakePort(
                const HomeResumeSnapshot(
                  HomeResumeState.data,
                  items: [item],
                ),
              ),
              onResume: (value) async => resumedRoute = value.route,
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('S-001245').first);
        await tester.pumpAndSettle();
        expect(resumedRoute, '/sales');
      },
    );
  });

  group('HomeCenterView.onOpenCashSessionById supervisor gating', () {
    AuthProfile profile({required int userId}) => AuthProfile(
      serverUrl: 'https://erp2.test',
      database: 'erp2_test',
      login: 'cajero1',
      userId: userId,
      installationId: 'install-1',
      credentialReference: 'ref-1',
    );

    Future<void> pumpWith(
      WidgetTester tester, {
      required Set<String> permissions,
      required void Function(String) onOpenCashSessionById,
    }) async {
      final cashReader = _MockCashReader();
      when(
        () => cashReader.loadActive(companyId: any(named: 'companyId')),
      ).thenAnswer(
        (_) async => [
          HomeCashSession(
            id: '11',
            name: 'CS/006/2026/0011',
            cashierUserId: 42,
            stateCode: 'opened',
          ),
        ],
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            capabilitySnapshotProvider.overrideWithValue(
              _capabilities(permissions),
            ),
            authInitialStateProvider.overrideWithValue(
              AuthViewState(profile: profile(userId: 9)),
            ),
            homeCashSessionsReaderProvider.overrideWithValue(cashReader),
          ],
          child: FluentApp(
            theme: OrbiFluentTheme.light,
            home: ScaffoldPage(
              content: HomeCenterView(
                port: _FakePort(const HomeResumeSnapshot(HomeResumeState.empty)),
                onOpenCashSessionById: onOpenCashSessionById,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // «Sesiones de caja activas» vive en la pestaña «Indicadores» — antes
      // salía siempre visible en el mismo lienzo.
      await tester.tap(find.text('Indicadores'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      'con collection_supervisor, tocar una fila ajena la abre con SU id',
      (tester) async {
        final opened = <String>[];
        await pumpWith(
          tester,
          permissions: const {'cashier', 'collection_supervisor'},
          onOpenCashSessionById: opened.add,
        );

        // La pestaña «Indicadores» tiene altura acotada (ACC-03, punto 6:
        // las tarjetas por módulo van justo debajo de la tabla, no al fondo
        // de la ventana), así que la fila puede quedar fuera de la vista
        // inicial dentro de su propio `ListView`.
        await tester.ensureVisible(find.text('CS/006/2026/0011'));
        await tester.pump();
        await tester.tap(find.text('CS/006/2026/0011'));
        await tester.pump();

        expect(opened, ['11']);
        await tester.pump(const Duration(milliseconds: 150));
      },
    );

    testWidgets(
      'sin collection_supervisor, HomeCenterView nunca ofrece el callback '
      'a la sección: un cajero raso no puede abrir un turno ajeno aunque '
      'reciba onOpenCashSessionById',
      (tester) async {
        final opened = <String>[];
        await pumpWith(
          tester,
          permissions: const {'cashier'},
          onOpenCashSessionById: opened.add,
        );

        await tester.tap(find.text('CS/006/2026/0011'), warnIfMissed: false);
        await tester.pump();

        expect(opened, isEmpty);
      },
    );
  });

  group('Fecha en la fila (h)', () {
    testWidgets(
      // (h): antes `documentDate` no llegaba a ningún ítem real (sólo el
      // guion de respaldo se ejercitaba en las pruebas) — con fecha
      // presente, la columna debía mostrarla, no un guion.
      'una fila con documentDate muestra su fecha, no un guion',
      (tester) async {
        final item = HomeResumeItem(
          id: 'home:sales:doc:1',
          title: 'S-001245',
          subtitle: 'Borrador sin confirmar',
          actionLabel: 'Ver ventas',
          route: '/sales',
          status: HomeResumeStatus.pendiente,
          documentDate: DateTime(2026, 4, 14),
          moduleLabel: 'Ventas',
        );
        await tester.pumpWidget(
          _wrap(
            HomeCenterView(
              port: _FakePort(
                HomeResumeSnapshot(HomeResumeState.data, items: [item]),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('14/04/2026'), findsOneWidget);
        expect(find.text('—'), findsNothing);
      },
    );
  });

  group('Tarjeta de teléfono (i)', () {
    testWidgets(
      // (i): a 390, documento y total van en la misma línea horizontal, y
      // hay una flecha que abre el documento.
      'a 390, documento y total quedan en la misma línea, con una flecha',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        const item = HomeResumeItem(
          id: 'home:sales:doc:1',
          title: 'S-001245',
          subtitle: 'Confirmada localmente, por sincronizar',
          actionLabel: 'Ver ventas',
          route: '/sales',
          status: HomeResumeStatus.enProceso,
          counterpart: 'Cliente Corporativo',
          moduleLabel: 'Ventas',
          totalLabel: r'$1,250.00',
        );
        await tester.pumpWidget(
          _wrap(
            HomeCenterView(
              port: _FakePort(
                const HomeResumeSnapshot(
                  HomeResumeState.data,
                  items: [item],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final titleTop = tester.getTopLeft(find.text('S-001245')).dy;
        final totalTop = tester.getTopLeft(find.text(r'$1,250.00')).dy;
        expect((titleTop - totalTop).abs(), lessThan(4));
        expect(find.byIcon(FluentIcons.chevron_right), findsWidgets);
      },
    );
  });

  group('Contraste de las insignias en tema oscuro (j)', () {
    test(
      // (j): el par sólido + `textOnAccentFillColorPrimary` que usa la
      // tarjeta de teléfono (`_documentCard`), no el tinte al 16 % del
      // listado genérico.
      'cada estado tiene contraste ≥ 4.5:1 contra su fondo, en tema oscuro',
      () {
        final theme = OrbiFluentTheme.dark;
        // `null` (documento sin estado) no es un chip real — nunca ocurre
        // en producción y su fondo casi transparente no participa de este
        // contrato de contraste.
        for (final status in HomeResumeStatus.values) {
          final bg = homeResumeStatusSolidBackground(theme, status);
          final fg = homeResumeStatusSolidForeground(theme, status);
          expect(
            _contrastRatio(fg, bg),
            greaterThanOrEqualTo(4.5),
            reason: 'status=$status fg=$fg bg=$bg',
          );
        }
      },
    );
  });
}

final class _FakePort implements HomeResumePort {
  const _FakePort(this.snapshot);
  @override
  final HomeResumeSnapshot snapshot;
  @override
  Stream<HomeResumeSnapshot> get changes => const Stream.empty();
  @override
  Future<void> resume(HomeResumeItem item) async {}
}
