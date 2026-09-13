import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/clients/catalog_contracts.dart';
import 'package:theos_panel/ui/components/fields/orbi_inline_catalog_picker.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Fixed catalog, filtered in-memory the way a real
/// `CatalogRepository` filters durable records: by substring on the title.
class _FakeRepository implements CatalogRepository<String> {
  _FakeRepository(this.entities);

  final List<CatalogEntity<String>> entities;

  @override
  Stream<CatalogSnapshot<String>> watch(CatalogQuery query) {
    final search = query.search.toLowerCase();
    final items = search.isEmpty
        ? entities
        : entities
              .where((e) => e.title.toLowerCase().contains(search))
              .toList(growable: false);
    return Stream.value(
      CatalogSnapshot<String>(
        status: items.isEmpty ? CatalogLoadStatus.empty : CatalogLoadStatus.data,
        items: items,
      ),
    );
  }

  @override
  Future<void> refresh(CatalogQuery query) async {}

  @override
  Future<void> loadNext(CatalogQuery query) async {}
}

const _entities = [
  CatalogEntity<String>(uuid: 'a', title: 'Martillo', value: 'Martillo'),
  CatalogEntity<String>(
    uuid: 'b',
    title: 'Broca 6mm',
    subtitle: 'SKU-6MM',
    value: 'Broca 6mm',
  ),
  CatalogEntity<String>(
    uuid: 'c',
    title: 'Broca 8mm',
    subtitle: 'SKU-8MM',
    value: 'Broca 8mm',
  ),
];

Widget _host(
  CatalogController<String> controller, {
  ValueChanged<CatalogEntity<String>>? onSelected,
  double width = 390,
}) {
  // A DataGrid cell (the real host, see `sale_lines_editor.dart`) gives the
  // picker a bounded width AND height; an unbounded height here would let the
  // underlying `TextBox` grow to fill the whole page and push the overlay
  // below the screen, which is a test-harness artifact, not a widget bug.
  return FluentApp(
    theme: OrbiFluentTheme.light,
    home: ScaffoldPage(
      content: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          height: 44,
          child: OrbiInlineCatalogPicker<String>(
            key: const Key('picker'),
            controller: controller,
            label: 'Buscar',
            onSelected: onSelected ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets('escribir filtra: aparece lo que coincide y desaparece lo que no', (
    tester,
  ) async {
    final controller = CatalogController<String>(
      repository: _FakeRepository(_entities),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(_host(controller));
    await tester.pump();

    await tester.tap(find.byKey(const Key('picker')));
    await tester.pump();
    expect(find.textContaining('Martillo'), findsOneWidget);
    expect(find.textContaining('Broca 6mm'), findsOneWidget);

    await tester.enterText(find.byType(TextBox), 'Broca');
    await tester.pump();
    await tester.pump();

    expect(find.textContaining('Martillo'), findsNothing);
    expect(find.textContaining('Broca 6mm'), findsOneWidget);
    expect(find.textContaining('Broca 8mm'), findsOneWidget);
  });

  testWidgets(
    'flecha abajo dos veces y Enter eligen la segunda coincidencia',
    (tester) async {
      final controller = CatalogController<String>(
        repository: _FakeRepository(_entities),
      );
      addTearDown(controller.dispose);
      CatalogEntity<String>? picked;
      await tester.pumpWidget(
        _host(controller, onSelected: (e) => picked = e),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('picker')));
      await tester.pump();
      await tester.enterText(find.byType(TextBox), 'Broca');
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Broca 6mm'), findsOneWidget);
      expect(find.textContaining('Broca 8mm'), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
      await tester.pump();
      // A physical Enter keydown isn't routed through the platform's
      // TextInputAction pipeline in widget tests; `AutoSuggestBox` submits on
      // that action (see `TextBox.onSubmitted` in
      // fluent_ui-4.16.1/lib/src/controls/form/auto_suggest_box.dart:909),
      // so this is how a real Enter keypress reaches it here.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(picked?.title, 'Broca 8mm');
    },
  );

  testWidgets(
    'Enter sin flechas elige la primera coincidencia (venta rápida: código + Enter)',
    (tester) async {
      final controller = CatalogController<String>(
        repository: _FakeRepository(_entities),
      );
      addTearDown(controller.dispose);
      CatalogEntity<String>? picked;
      await tester.pumpWidget(
        _host(controller, onSelected: (e) => picked = e),
      );
      await tester.pump();

      await tester.tap(find.byKey(const Key('picker')));
      await tester.pump();
      await tester.enterText(find.byType(TextBox), 'Broca');
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Broca 6mm'), findsOneWidget);
      expect(find.textContaining('Broca 8mm'), findsOneWidget);

      // No arrow key pressed here: nothing is highlighted yet, so Enter must
      // fall back to the first of the two filtered matches.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();

      expect(picked?.title, 'Broca 6mm');
    },
  );

  testWidgets('Escape cierra la superposición sin elegir nada', (
    tester,
  ) async {
    final controller = CatalogController<String>(
      repository: _FakeRepository(_entities),
    );
    addTearDown(controller.dispose);
    CatalogEntity<String>? picked;
    await tester.pumpWidget(_host(controller, onSelected: (e) => picked = e));
    await tester.pump();

    await tester.tap(find.byKey(const Key('picker')));
    await tester.pump();
    expect(find.textContaining('Martillo'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();

    expect(find.textContaining('Martillo'), findsNothing);
    expect(picked, isNull);
  });

  testWidgets('a 390px de ancho la lista se ve sin desbordes', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final controller = CatalogController<String>(
      repository: _FakeRepository(_entities),
    );
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      _host(controller, width: 390),
    );
    await tester.pump();

    await tester.tap(find.byKey(const Key('picker')));
    await tester.pump();
    expect(find.textContaining('Broca 6mm'), findsOneWidget);
    expect(tester.takeException(), isNull);

    final overlaySize = tester.getSize(find.byType(TextBox).first);
    expect(overlaySize.width, lessThanOrEqualTo(390));
  });
}
