import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/features/sync/sync_data_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

class _MockSyncDataPort extends Mock implements SyncDataPort {}

Future<void> _pumpAt(
  WidgetTester tester,
  Widget screen, {
  required double width,
  double height = 900,
}) async {
  tester.view.physicalSize = Size(width, height);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    FluentApp(theme: OrbiFluentTheme.light, home: ScaffoldPage(content: screen)),
  );
  // Dos frames: uno para que corran los `Future.value` de carga inicial
  // (catálogos + operaciones pendientes), otro para que `setState` pinte
  // el resultado.
  await tester.pump();
  await tester.pump();
}

void _stubBaseline(
  _MockSyncDataPort port, {
  int pending = 0,
  List<SyncCatalogCardData> cards = const [],
  bool online = true,
  bool routeMode = false,
}) {
  when(() => port.isOnline).thenReturn(online);
  when(() => port.userCanCollect).thenReturn(false);
  when(() => port.routeModeEnabled).thenReturn(routeMode);
  when(() => port.syncSnapshot).thenReturn(SyncSnapshot());
  when(() => port.syncSnapshots).thenAnswer((_) => const Stream<SyncSnapshot>.empty());
  when(() => port.loadCatalogCards()).thenAnswer((_) async => cards);
  when(() => port.loadPendingOperationsCount()).thenAnswer((_) async => pending);
}

void main() {
  testWidgets('Vaciar Tablas se deshabilita mientras haya operaciones pendientes', (
    tester,
  ) async {
    final port = _MockSyncDataPort();
    _stubBaseline(port, pending: 3);

    await _pumpAt(tester, SyncDataScreen(port: port), width: 1400);

    // `CommandBarButton` no es un `Widget` (es un `CommandBarItem`): en modo
    // primario se renderiza como un `IconButton` real que conserva la misma
    // `key` — ver `commandbar.dart:CommandBarButton.build`.
    final button = tester.widget<IconButton>(
      find.byKey(const Key('clear-all-tables-button')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'Sincronizar un catálogo llama al puerto (coordinador), y un segundo '
    'toque mientras corre no lanza otra pasada',
    (tester) async {
      final port = _MockSyncDataPort();
      const card = SyncCatalogCardData(
        key: 'partner',
        label: 'Clientes',
        icon: FluentIcons.people,
        localCount: 12,
        freshness: CatalogFreshness.readyIncremental,
      );
      _stubBaseline(port, cards: const [card]);

      final inFlight = Completer<void>();
      when(() => port.syncCatalog('partner')).thenAnswer((_) => inFlight.future);

      await _pumpAt(tester, SyncDataScreen(port: port), width: 1400);

      final syncButton = find.byKey(const Key('sync-catalog-partner-button'));
      expect(syncButton, findsOneWidget);
      await tester.ensureVisible(syncButton);
      await tester.pump();

      // Dos toques SIN dejar que el árbol se reconstruya entre ellos: si la
      // pantalla dependiera sólo de deshabilitar el botón tras `setState`,
      // esto lanzaría dos pasadas.
      await tester.tap(syncButton);
      await tester.tap(syncButton);
      await tester.pump();

      verify(() => port.syncCatalog('partner')).called(1);
      verifyNever(() => port.syncAll());

      inFlight.complete();
      await tester.pump();
      await tester.pump();
      // Fluent's `Button` corre por `HoverButton`, que agenda un timer de
      // 100ms al soltar el toque para restablecer su estado de presionado;
      // hay que dejarlo correr antes de que termine la prueba (mismo gotcha
      // documentado en sync_center_test.dart).
      await tester.pump(const Duration(milliseconds: 150));
    },
  );

  testWidgets(
    'Vaciar Tablas y Forzar Sync Completo se deshabilitan mientras hay una '
    'sincronización en curso',
    (tester) async {
      final port = _MockSyncDataPort();
      _stubBaseline(port);
      when(() => port.syncSnapshot).thenReturn(SyncSnapshot(active: true));

      await _pumpAt(tester, SyncDataScreen(port: port), width: 1400);

      final clearButton = tester.widget<IconButton>(
        find.byKey(const Key('clear-all-tables-button')),
      );
      expect(clearButton.onPressed, isNull);

      final forceFullButton = tester.widget<IconButton>(
        find.byKey(const Key('force-full-sync-button')),
      );
      expect(forceFullButton.onPressed, isNull);
    },
  );

  testWidgets('no hay desbordamiento a 400, 800 y 1280 px', (tester) async {
    final port = _MockSyncDataPort();
    final cards = [
      for (final key in orbiCatalogKeys)
        SyncCatalogCardData(
          key: key,
          label: key,
          icon: catalogIconFor(key),
          localCount: 5,
          freshness: CatalogFreshness.readyIncremental,
        ),
    ];
    _stubBaseline(port, cards: cards);

    for (final width in [400.0, 800.0, 1280.0]) {
      await _pumpAt(tester, SyncDataScreen(port: port), width: width, height: 1400);
      expect(tester.takeException(), isNull, reason: 'desbordamiento a ${width}px');
    }
  });

  testWidgets(
    'la pantalla de Sincronización muestra el interruptor de Modo Ruta y al '
    'activarlo persiste la preferencia',
    (tester) async {
      final port = _MockSyncDataPort();
      _stubBaseline(port);
      when(() => port.setRouteMode(true)).thenAnswer((_) async {});

      await _pumpAt(tester, SyncDataScreen(port: port), width: 1400);

      expect(find.text('Modo Ruta'), findsOneWidget);
      expect(find.text('Inactivo'), findsOneWidget);

      final toggle = find.byKey(const Key('route-mode-toggle'));
      expect(toggle, findsOneWidget);
      await tester.tap(toggle);
      await tester.pumpAndSettle();

      verify(() => port.setRouteMode(true)).called(1);
    },
  );

  test(
    'clearCatalog/clearAllTables/forceFullReloadCatalog/forceFullReloadAll '
    'respetan una pausa ajena (Modo Ruta): no la levantan y no marcan '
    'sincronizado hasta que termine',
    () async {
      // `RuntimeCatalogComposition` es `final class` (no se puede fingir
      // desde una prueba), así que esto ejercita directamente el mecanismo
      // compartido del que dependen las cuatro acciones del puerto real
      // (`SyncMaintenanceGuard`, en sync_data_screen.dart) contra un
      // `SyncCoordinatorImpl` real y sin trabajos — sólo hace falta el
      // coordinador para comprobar la pausa/el drenaje, no un catálogo real.
      final coordinator = SyncCoordinatorImpl(jobs: const []);
      await coordinator.pause(PauseReason('route_mode'));
      expect(coordinator.isPaused, isTrue);

      final guard = SyncMaintenanceGuard(coordinator);
      var ran = false;
      final tookThePauseItself = await guard.run(() async => ran = true);

      expect(ran, isTrue, reason: 'la acción sí debe correr');
      expect(
        tookThePauseItself,
        isFalse,
        reason: 'no fue este guard quien pausó, así que no debe reanudar',
      );
      expect(
        coordinator.isPaused,
        isTrue,
        reason: 'Modo Ruta sigue decidiendo cuándo termina la pausa',
      );
      expect(
        coordinator.snapshot.active,
        isFalse,
        reason: 'no debió haber ningún drenaje',
      );
    },
  );
}
