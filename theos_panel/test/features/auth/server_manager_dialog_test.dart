import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:theos_panel/app/theme/orbi_theme.dart';
import 'package:theos_panel/features/auth/saved_servers.dart';
import 'package:theos_panel/features/auth/server_manager_dialog.dart';

void main() {
  late SavedServersStore store;
  SavedServer? selected;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    store = SavedServersStore(await SharedPreferences.getInstance());
  });

  Future<void> open(
    WidgetTester tester, {
    double width = 1000,
    double height = 760,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: OrbiTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                selected = await showSavedServerManager(context, store: store);
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('creates, filters and selects a saved server', (tester) async {
    await open(tester);
    await tester.enterText(find.byKey(const ValueKey('server_name')), 'Demo');
    await tester.enterText(
      find.byKey(const ValueKey('server_url')),
      'https://demo.example.com',
    );
    await tester.enterText(
      find.byKey(const ValueKey('server_database')),
      'demo',
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('save_server')));
    });
    await tester.pumpAndSettle();
    expect(store.load().single.name, 'Demo');
    await tester.enterText(
      find.byKey(const ValueKey('server_name')),
      'Demo editado',
    );
    await tester.runAsync(() async {
      await tester.tap(find.byKey(const ValueKey('save_server')));
    });
    await tester.pumpAndSettle();
    expect(store.load().single.name, 'Demo editado');
    await tester.enterText(
      find.byKey(const ValueKey('server_search')),
      'no-existe',
    );
    await tester.pumpAndSettle();
    expect(find.text('No hay coincidencias.'), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('server_search')), 'demo');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('use_server')));
    await tester.pumpAndSettle();
    expect(selected?.name, 'Demo editado');
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Borrar'));
    await tester.pumpAndSettle();
    expect(store.load(), hasLength(1));
    await tester.runAsync(() async {
      await tester.tap(find.text('Eliminar'));
    });
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pumpAndSettle();
    expect(store.load(), isEmpty);
    expect(tester.takeException(), isNull);
  });

  testWidgets('renders legibly in compact and phone viewports', (tester) async {
    await open(tester, width: 560, height: 760);
    expect(find.text('Nuevo servidor'), findsOneWidget);
    expect(find.byKey(const ValueKey('server_url')), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(390, 700));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byKey(const ValueKey('server_database')), findsOneWidget);
    await tester.binding.setSurfaceSize(const Size(390, 400));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.ensureVisible(find.byKey(const ValueKey('save_server')));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('closing an edited connection asks before discarding', (
    tester,
  ) async {
    await open(tester);
    await tester.enterText(
      find.byKey(const ValueKey('server_name')),
      'Borrador',
    );
    await tester.tap(find.byTooltip('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('¿Descartar cambios?'), findsOneWidget);
    await tester.tap(find.text('Seguir editando'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextField>(find.byKey(const ValueKey('server_name')))
          .controller!
          .text,
      'Borrador',
    );
    expect(store.load(), isEmpty);
  });

  testWidgets('shows corrupt storage error without resetting it', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({SavedServersStore.key: '{broken'});
    store = SavedServersStore(
      (await tester.runAsync(() => SharedPreferences.getInstance()))!,
    );
    await open(tester);
    expect(find.textContaining('No se pudieron leer'), findsOneWidget);
  });
}
