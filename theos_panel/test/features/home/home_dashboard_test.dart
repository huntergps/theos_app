import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orbi_runtime/orbi_runtime.dart' show AuthProfile, CapabilitySnapshot;
import 'package:theos_panel/features/auth/auth_controller.dart';
import 'package:theos_panel/features/home/home_dashboard_contracts.dart';
import 'package:theos_panel/features/home/home_dashboard_providers.dart';
import 'package:theos_panel/features/home/home_dashboard_view.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

class _MockSalesReader extends Mock implements HomeSalesMetricsReader {}

class _MockCashReader extends Mock implements HomeCashSessionsReader {}

CapabilitySnapshot _capabilities(Set<String> permissions) => CapabilitySnapshot(
  scopeKey: 'test-scope',
  companyId: 1,
  revision: 1,
  fetchedAt: DateTime.utc(2026, 9, 13),
  permissions: permissions,
);

AuthProfile _profile({required int userId, String login = 'usuario1'}) =>
    AuthProfile(
      serverUrl: 'https://erp2.test',
      database: 'erp2_test',
      login: login,
      userId: userId,
      installationId: 'install-1',
      credentialReference: 'ref-1',
    );

void main() {
  setUpAll(() {
    registerFallbackValue(false);
  });

  group('homeDashboardColumns', () {
    test('1 columna a 400px, 2 a 800px, 4 a 1280px', () {
      expect(homeDashboardColumns(400), 1);
      expect(homeDashboardColumns(799), 1);
      expect(homeDashboardColumns(800), 2);
      expect(homeDashboardColumns(1279), 2);
      expect(homeDashboardColumns(1280), 4);
      expect(homeDashboardColumns(1600), 4);
    });
  });

  group('HomeIndicatorGrid', () {
    testWidgets(
      'con un vendedor aparecen las tarjetas de ventas y nunca se llama al lector de pagos',
      (tester) async {
        final salesReader = _MockSalesReader();
        when(
          () => salesReader.loadToday(
            companyId: any(named: 'companyId'),
            userId: any(named: 'userId'),
            viewAll: any(named: 'viewAll'),
          ),
        ).thenAnswer(
          (_) async => const HomeSalesSummary(
            totalAmount: 125.5,
            totalOrders: 4,
            draftCount: 1,
            confirmedCount: 2,
            doneCount: 1,
          ),
        );
        final cashReader = _MockCashReader();
        final capabilities = _capabilities(const {'seller'});
        final profile = _profile(userId: 9);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              capabilitySnapshotProvider.overrideWithValue(capabilities),
              authInitialStateProvider.overrideWithValue(
                AuthViewState(profile: profile),
              ),
              homeSalesMetricsReaderProvider.overrideWithValue(salesReader),
              homeCashSessionsReaderProvider.overrideWithValue(cashReader),
            ],
            child: FluentApp(
              theme: OrbiFluentTheme.light,
              home: ScaffoldPage(
                content: HomeIndicatorGrid(capabilities: capabilities),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Total ventas del día'), findsOneWidget);
        expect(find.text('\$125.50'), findsOneWidget);
        expect(find.text('Borradores'), findsOneWidget);
        expect(find.text('Sesiones de caja abiertas'), findsNothing);
        verifyNever(
          () => cashReader.loadActive(companyId: any(named: 'companyId')),
        );
      },
    );

    testWidgets(
      'con un cajero aparece la sección de sesiones de caja con los datos del lector',
      (tester) async {
        final cashReader = _MockCashReader();
        when(
          () => cashReader.loadActive(companyId: any(named: 'companyId')),
        ).thenAnswer(
          (_) async => [
            HomeCashSession(
              id: '8',
              name: 'CS/005/2026/0008',
              cashierUserId: 9,
              cashierName: 'Erik Aldas',
              configName: '005 JACQUELINE',
              startAt: DateTime.utc(2026, 8, 27, 13, 34),
              stateCode: 'opened',
              paymentCount: 3,
              totalPaymentsAmount: 250,
            ),
          ],
        );
        final capabilities = _capabilities(const {'cashier'});
        final profile = _profile(userId: 9, login: 'cajero1');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              capabilitySnapshotProvider.overrideWithValue(capabilities),
              authInitialStateProvider.overrideWithValue(
                AuthViewState(profile: profile),
              ),
              homeCashSessionsReaderProvider.overrideWithValue(cashReader),
            ],
            child: FluentApp(
              theme: OrbiFluentTheme.light,
              home: const ScaffoldPage(content: HomeCashSessionsSection()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Sesiones de caja activas'), findsOneWidget);
        expect(find.text('CS/005/2026/0008'), findsOneWidget);
        expect(find.textContaining('Erik Aldas'), findsOneWidget);
        expect(find.text('Abierta'), findsOneWidget);
        verify(() => cashReader.loadActive(companyId: 1)).called(1);
      },
    );

    testWidgets(
      'la rejilla de indicadores no desborda a 400, 800 ni 1280px',
      (tester) async {
        final salesReader = _MockSalesReader();
        when(
          () => salesReader.loadToday(
            companyId: any(named: 'companyId'),
            userId: any(named: 'userId'),
            viewAll: any(named: 'viewAll'),
          ),
        ).thenAnswer(
          (_) async => const HomeSalesSummary(
            totalAmount: 10,
            totalOrders: 1,
            draftCount: 1,
            confirmedCount: 1,
            doneCount: 1,
          ),
        );
        final cashReader = _MockCashReader();
        when(
          () => cashReader.loadActive(companyId: any(named: 'companyId')),
        ).thenAnswer(
          (_) async => [
            HomeCashSession(
              id: '1',
              name: 'CS-1',
              cashierUserId: 1,
              stateCode: 'opened',
              paymentCount: 1,
              totalPaymentsAmount: 5,
            ),
          ],
        );
        final capabilities = _capabilities(const {'seller', 'cashier'});
        final profile = _profile(userId: 1, login: 'admin');

        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        Future<void> pumpAt(double width) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                capabilitySnapshotProvider.overrideWithValue(capabilities),
                authInitialStateProvider.overrideWithValue(
                  AuthViewState(profile: profile),
                ),
                homeSalesMetricsReaderProvider.overrideWithValue(salesReader),
                homeCashSessionsReaderProvider.overrideWithValue(cashReader),
              ],
              child: FluentApp(
                theme: OrbiFluentTheme.light,
                home: ScaffoldPage(
                  content: HomeIndicatorGrid(capabilities: capabilities),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
        }

        await pumpAt(400);
        expect(tester.takeException(), isNull);
        await pumpAt(800);
        expect(tester.takeException(), isNull);
        await pumpAt(1280);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'con capacidad de bodega nunca aparece un indicador: el dato no está sincronizado localmente',
      (tester) async {
        // `sale_order.delivery_status` no viaja en el sync de Orbi
        // (`orbi_runtime/lib/src/read/runtime_order_reader.dart`) y no hay
        // tabla local de `stock.picking`, así que un pedido `state='sale'`
        // con `picking_ids` no vacío pero ya entregado (`delivery_status`
        // `full`, si existiera local) no tendría cómo distinguirse — de ahí
        // que el indicador se omita en vez de usar ese proxy.
        final capabilities = _capabilities(const {'warehouse'});

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              capabilitySnapshotProvider.overrideWithValue(capabilities),
            ],
            child: FluentApp(
              theme: OrbiFluentTheme.light,
              home: ScaffoldPage(
                content: HomeIndicatorGrid(capabilities: capabilities),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('bodega'), findsNothing);
        expect(find.textContaining('Bodega'), findsNothing);
        expect(find.textContaining('entregar'), findsNothing);
      },
    );
  });

  group('HomeCashSessionsSection onOpenSession', () {
    testWidgets(
      'sólo la fila propia del cajero autenticado dispara la acción; una ajena no',
      (tester) async {
        final cashReader = _MockCashReader();
        when(
          () => cashReader.loadActive(companyId: any(named: 'companyId')),
        ).thenAnswer(
          (_) async => [
            HomeCashSession(
              id: '8',
              name: 'CS/005/2026/0008',
              cashierUserId: 9,
              stateCode: 'opened',
            ),
            HomeCashSession(
              id: '11',
              name: 'CS/006/2026/0011',
              cashierUserId: 42,
              stateCode: 'opened',
            ),
          ],
        );
        final capabilities = _capabilities(const {'cashier'});
        final profile = _profile(userId: 9, login: 'cajero1');
        var ownTapped = 0;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              capabilitySnapshotProvider.overrideWithValue(capabilities),
              authInitialStateProvider.overrideWithValue(
                AuthViewState(profile: profile),
              ),
              homeCashSessionsReaderProvider.overrideWithValue(cashReader),
            ],
            child: FluentApp(
              theme: OrbiFluentTheme.light,
              home: ScaffoldPage(
                content: HomeCashSessionsSection(
                  onOpenOwnSession: () => ownTapped++,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('CS/006/2026/0011'), warnIfMissed: false);
        await tester.pump();
        expect(ownTapped, 0);

        await tester.tap(find.text('CS/005/2026/0008'));
        await tester.pump();
        expect(ownTapped, 1);

        // Fluent's `HoverButton` (under `ListTile`) schedules a 100ms timer
        // on tap-up to reset its pressed state; flush it before teardown.
        await tester.pump(const Duration(milliseconds: 150));
      },
    );

    testWidgets(
      'un supervisor ve tocable la fila de un turno ajeno y la abre con ESE '
      'id, nunca con el propio',
      (tester) async {
        final cashReader = _MockCashReader();
        when(
          () => cashReader.loadActive(companyId: any(named: 'companyId')),
        ).thenAnswer(
          (_) async => [
            HomeCashSession(
              id: '8',
              name: 'CS/005/2026/0008',
              cashierUserId: 9,
              stateCode: 'opened',
            ),
            HomeCashSession(
              id: '11',
              name: 'CS/006/2026/0011',
              cashierUserId: 42,
              stateCode: 'opened',
            ),
          ],
        );
        // El permiso de supervisor ya se comprobó antes de llegar aquí (lo
        // hace `HomeCenterView`); esta sección sólo pinta lo que le pasaron.
        final capabilities = _capabilities(const {
          'cashier',
          'collection_supervisor',
        });
        final profile = _profile(userId: 9, login: 'supervisor1');
        final openedIds = <String>[];

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              capabilitySnapshotProvider.overrideWithValue(capabilities),
              authInitialStateProvider.overrideWithValue(
                AuthViewState(profile: profile),
              ),
              homeCashSessionsReaderProvider.overrideWithValue(cashReader),
            ],
            child: FluentApp(
              theme: OrbiFluentTheme.light,
              home: ScaffoldPage(
                content: HomeCashSessionsSection(
                  onOpenOwnSession: () => openedIds.add('own'),
                  onOpenSupervisedSession: openedIds.add,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('CS/006/2026/0011'));
        await tester.pump();

        expect(openedIds, ['11']);

        await tester.pump(const Duration(milliseconds: 150));
      },
    );
  });

  group('HomeLastSyncCard', () {
    testWidgets(
      'sin sincronización previa, la tarjeta dice que nunca se sincronizó',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            child: FluentApp(
              theme: OrbiFluentTheme.light,
              home: const ScaffoldPage(content: HomeLastSyncCard()),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Nunca se sincronizó'), findsOneWidget);
        expect(find.text('Sin pendientes'), findsOneWidget);
      },
    );
  });
}
