import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile, CapabilitySnapshot;
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/home/home_center.dart';
import 'package:theos_panel/features/home/home_dashboard_contracts.dart';
import 'package:theos_panel/features/home/home_dashboard_providers.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

class _MockCashReader extends Mock implements HomeCashSessionsReader {}

/// `HomeCenterView` pasó a `ConsumerWidget` para leer capacidades/sesión de
/// forma ambiental; todo test necesita un `ProviderScope`, aunque sea sin
/// overrides (capacidades nulas ⇒ panel de indicadores apagado, mismo
/// comportamiento de antes).
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

  group('HomeCenterView', () {
    testWidgets(
      'shows a KPI card only for items that carry a real count',
      (tester) async {
        const withCount = HomeResumeItem(
          id: 'home:sales:draft',
          title: 'Ventas por continuar',
          subtitle: '3 pedidos locales',
          actionLabel: 'Ver ventas',
          route: '/sales',
          count: 3,
        );
        const withoutCount = HomeResumeItem(
          id: 'home:other',
          title: 'Otro pendiente',
          subtitle: 'sin cifra',
          actionLabel: 'Abrir',
        );
        await tester.pumpWidget(
          _wrap(
            HomeCenterView(
              port: _FakePort(
                const HomeResumeSnapshot(
                  HomeResumeState.data,
                  items: [withCount, withoutCount],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // La cifra real aparece una vez como KPI y otra dentro de la tarjeta
        // del ítem ("3 pedidos locales"); nunca aparece un cero fabricado
        // para el ítem que no trae cifra.
        expect(find.text('3'), findsOneWidget);
        // El título se repite: una vez en la tarjeta KPI, otra en la lista.
        expect(find.text('Ventas por continuar'), findsNWidgets(2));
        expect(find.text('Otro pendiente'), findsOneWidget);
        expect(find.text('0'), findsNothing);
      },
    );

    testWidgets(
      'empty state offers only the quick starts it was given, and they navigate',
      (tester) async {
        const sales = HomeResumeItem(
          id: 'home:quickstart:/sales',
          title: 'Ventas',
          subtitle: 'Ir a Ventas',
          actionLabel: 'Abrir',
          route: '/sales',
        );
        String? resumedRoute;
        await tester.pumpWidget(
          _wrap(
            HomeCenterView(
              port: _FakePort(const HomeResumeSnapshot(HomeResumeState.empty)),
              quickStarts: const [sales],
              onResume: (item) async => resumedRoute = item.route,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No hay trabajo pendiente'), findsOneWidget);
        expect(find.text('Ventas'), findsOneWidget);
        // Sólo la candidata que se le pasó: nunca inventa una propia.
        expect(find.text('Bodega'), findsNothing);

        await tester.tap(find.text('Ventas'));
        await tester.pump();
        expect(resumedRoute, '/sales');
        // Fluent's `HoverButton` (under `Button`) schedules a 100ms timer on
        // tap-up to reset its pressed state; flush it before teardown.
        await tester.pump(const Duration(milliseconds: 150));
      },
    );

    testWidgets(
      'empty state without quick starts stays silent about where to go',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            HomeCenterView(
              port: _FakePort(const HomeResumeSnapshot(HomeResumeState.empty)),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No hay trabajo pendiente'), findsOneWidget);
        expect(find.text('Empieza por aquí:'), findsNothing);
      },
    );
  });

  group('HomeCenterView.onOpenCashSessionById supervisor gating', () {
    CapabilitySnapshot capabilities(Set<String> permissions) =>
        CapabilitySnapshot(
          scopeKey: 'test-scope',
          companyId: 1,
          revision: 1,
          fetchedAt: DateTime.utc(2026, 9, 13),
          permissions: permissions,
        );

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
              capabilities(permissions),
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
