import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile, CapabilitySnapshot;
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/home/home_center.dart';
import 'package:theos_panel/features/home/home_dashboard_contracts.dart';
import 'package:theos_panel/features/home/home_dashboard_providers.dart';
import 'package:theos_panel/features/home/home_resume_status.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

class _MockCashReader extends Mock implements HomeCashSessionsReader {}

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
