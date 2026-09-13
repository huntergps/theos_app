import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/activities/activity_center.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

final class _FakeActivityPort implements ActivityPort {
  _FakeActivityPort(this._items);

  List<ActivityItem> _items;
  final _controller = StreamController<List<ActivityItem>>.broadcast();
  final completed = <String>[];
  bool completeResult = true;

  @override
  List<ActivityItem> get snapshot => _items;

  @override
  Stream<List<ActivityItem>> get changes => _controller.stream;

  @override
  Future<bool> complete(ActivityItem item) async {
    completed.add(item.id);
    return completeResult;
  }

  void publish(List<ActivityItem> items) {
    _items = items;
    _controller.add(items);
  }

  Future<void> dispose() => _controller.close();
}

Widget _host(Widget child) =>
    FluentApp(theme: OrbiFluentTheme.light, home: child);

void main() {
  testWidgets('an overdue activity is listed under Vencidas and not under Hoy', (
    tester,
  ) async {
    final port = _FakeActivityPort([
      const ActivityItem(
        id: '1',
        title: 'Llamar a cliente moroso',
        status: ActivityStatus.overdue,
      ),
    ]);
    addTearDown(port.dispose);

    await tester.pumpWidget(_host(ActivityCenterView(port: port)));
    await tester.pump();

    expect(find.text('Vencidas (1)'), findsOneWidget);
    expect(find.text('Llamar a cliente moroso'), findsOneWidget);
    expect(find.textContaining('Hoy ('), findsNothing);
  });

  testWidgets('Mías hides activities that belong to another responsible', (
    tester,
  ) async {
    final port = _FakeActivityPort([
      const ActivityItem(
        id: '1',
        title: 'Actividad propia',
        status: ActivityStatus.today,
        responsibleId: 7,
        responsibleName: 'Ana',
      ),
      const ActivityItem(
        id: '2',
        title: 'Actividad de otro vendedor',
        status: ActivityStatus.today,
        responsibleId: 9,
        responsibleName: 'Luis',
      ),
    ]);
    addTearDown(port.dispose);

    await tester.pumpWidget(
      _host(ActivityCenterView(port: port, currentUserId: 7)),
    );
    await tester.pump();

    // Sin filtrar, ambas actividades están a la vista.
    expect(find.text('Actividad propia'), findsOneWidget);
    expect(find.text('Actividad de otro vendedor'), findsOneWidget);

    await tester.tap(find.text('Mías'));
    // Fluent's `ToggleButton` runs its press feedback through `HoverButton`,
    // which schedules a 100ms timer to reset the pressed state after the
    // tap. A single `pump()` leaves it pending at teardown.
    await tester.pump(const Duration(milliseconds: 150));

    expect(find.text('Actividad propia'), findsOneWidget);
    expect(find.text('Actividad de otro vendedor'), findsNothing);
  });

  testWidgets('the Mías/Todas toggle stays hidden without a known session user', (
    tester,
  ) async {
    final port = _FakeActivityPort([
      const ActivityItem(
        id: '1',
        title: 'Actividad propia',
        status: ActivityStatus.today,
        responsibleId: 7,
      ),
      const ActivityItem(
        id: '2',
        title: 'Actividad de otro vendedor',
        status: ActivityStatus.today,
        responsibleId: 9,
      ),
    ]);
    addTearDown(port.dispose);

    await tester.pumpWidget(_host(ActivityCenterView(port: port)));
    await tester.pump();

    expect(find.text('Mías'), findsNothing);
    expect(find.text('Actividad de otro vendedor'), findsOneWidget);
  });

  testWidgets('marking an activity done asks for confirmation before calling the port', (
    tester,
  ) async {
    final port = _FakeActivityPort([
      const ActivityItem(
        id: '1',
        title: 'Confirmar entrega',
        status: ActivityStatus.today,
        canComplete: true,
      ),
    ]);
    addTearDown(port.dispose);

    await tester.pumpWidget(_host(ActivityCenterView(port: port)));
    await tester.pump();

    await tester.tap(find.byTooltip('Marcar como hecha'));
    await tester.pumpAndSettle();

    // El diálogo de confirmación aparece y el port todavía no fue llamado.
    expect(find.text('Marcar actividad como hecha'), findsOneWidget);
    expect(port.completed, isEmpty);

    await tester.tap(find.text('Marcar hecha'));
    await tester.pumpAndSettle();

    expect(port.completed, ['1']);
  });

  testWidgets('an empty activity list shows the empty state', (tester) async {
    final port = _FakeActivityPort(const []);
    addTearDown(port.dispose);

    await tester.pumpWidget(_host(ActivityCenterView(port: port)));
    await tester.pump();

    expect(find.text('No hay actividades'), findsOneWidget);
  });

  testWidgets('activities do not overflow at 400, 800 and 1280 px', (
    tester,
  ) async {
    final port = _FakeActivityPort([
      ActivityItem(
        id: '1',
        title:
            'Una actividad con un título bastante largo para forzar el ajuste de línea en pantallas angostas',
        status: ActivityStatus.overdue,
        activityType: 'Llamada telefónica',
        documentLabel:
            'VENTA0001 Consumidor final de una empresa con nombre muy largo',
        documentModel: 'sale.order',
        responsibleName: 'Erik Andrés Aldas Romero',
        deadline: DateTime.now().subtract(const Duration(days: 3)),
        note:
            'Nota extensa para verificar que el recorte funciona correctamente en pantallas angostas sin desbordar el layout.',
        canComplete: true,
      ),
    ]);
    addTearDown(port.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final width in [400.0, 800.0, 1280.0]) {
      await tester.binding.setSurfaceSize(Size(width, 800));
      await tester.pumpWidget(_host(ActivityCenterView(port: port)));
      await tester.pump();
      expect(
        tester.takeException(),
        isNull,
        reason: 'overflow at width $width',
      );
    }
  });
}
