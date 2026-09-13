import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_panel/features/clients/catalog_contracts.dart';
import 'package:theos_panel/features/products/products_screen.dart';

/// Local catalog fake: watches never touch Odoo/ERP2, they only replay an
/// in-memory list filtered by the current query.
final class _FakeProductRepository implements CatalogRepository<String> {
  _FakeProductRepository(this.items);
  final List<CatalogEntity<String>> items;
  final _controller = StreamController<CatalogSnapshot<String>>.broadcast();

  @override
  Stream<CatalogSnapshot<String>> watch(CatalogQuery query) {
    Future<void>.microtask(() => _emit(query));
    return _controller.stream;
  }

  @override
  Future<void> refresh(CatalogQuery query) async => _emit(query);

  @override
  Future<void> loadNext(CatalogQuery query) async => _emit(query);

  void _emit(CatalogQuery query) {
    final search = query.search.toLowerCase();
    final filtered = items
        .where((e) => search.isEmpty || e.title.toLowerCase().contains(search))
        .toList(growable: false);
    _controller.add(
      CatalogSnapshot<String>(
        status: filtered.isEmpty
            ? CatalogLoadStatus.empty
            : CatalogLoadStatus.data,
        items: filtered,
        totalCount: filtered.length,
      ),
    );
  }

  Future<void> dispose() => _controller.close();
}

/// Long product descriptions, the same overflow family already found in the
/// design galleries: desktop-shaped content that must still fit tablet width.
List<CatalogEntity<String>> _products() => const [
  CatalogEntity(
    uuid: 'p-1',
    title: 'Cemento Portland Tipo GU saco 50kg Holcim resistente a sulfatos',
    subtitle: 'SKU CEM-0050-GU · Stock 128 · \$7.85',
    value: 'p-1',
  ),
  CatalogEntity(
    uuid: 'p-2',
    title: 'Varilla corrugada de acero 12mm x 12m grado 60 Adelca',
    subtitle: 'SKU VAR-0012-12 · Stock 40 · \$9.20',
    value: 'p-2',
  ),
  CatalogEntity(
    uuid: 'p-3',
    title: 'Pintura látex interior blanco galón Cóndor',
    subtitle: 'SKU PIN-0001-BL · Stock 15 · \$18.50',
    value: 'p-3',
  ),
];

const _sizes = [
  Size(1440, 900), // escritorio
  Size(1180, 820), // tablet horizontal
  Size(820, 1180), // tablet vertical
  Size(390, 844), // teléfono
];

void main() {
  testWidgets(
    'products screen shows the standard listing (table, filter, columns) '
    'without overflow at all four sizes',
    (tester) async {
      final repository = _FakeProductRepository(_products());
      addTearDown(repository.dispose);
      final controller = CatalogController<String>(repository: repository);
      addTearDown(controller.dispose);

      for (final size in _sizes) {
        await tester.binding.setSurfaceSize(size);
        await tester.pumpWidget(
          FluentApp(
            home: MediaQuery(
              data: MediaQueryData(size: size),
              child: ProductsScreen<String>(controller: controller),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Mismo criterio que la pantalla de clientes (dc9d939): rejilla sólo
        // en ancho; estrecho o tableta en vertical, las mismas filas en fichas.
        final ancho = size.width >= 840 && size.width >= size.height;
        expect(
          find.byType(SfDataGrid),
          ancho ? findsOneWidget : findsNothing,
          reason: 'rejilla sólo en ancho; size=$size',
        );
        expect(
          find.byKey(const Key('orbi-listing-cards')),
          ancho ? findsNothing : findsOneWidget,
          reason: 'fichas en estrecho y en vertical; size=$size',
        );
        expect(find.byKey(const Key('orbi-listing-filter')), findsOneWidget);
        expect(find.byKey(const Key('orbi-listing-columns')), findsOneWidget);
        expect(
          tester.takeException(),
          isNull,
          reason: 'no overflow/exception expected at size=$size',
        );
      }
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets(
    'product search narrows the same table instead of replacing it with a '
    'bare results list',
    (tester) async {
      final repository = _FakeProductRepository(_products());
      addTearDown(repository.dispose);
      final controller = CatalogController<String>(repository: repository);
      addTearDown(controller.dispose);

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        FluentApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1440, 900)),
            child: ProductsScreen<String>(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Cemento Portland Tipo GU saco 50kg Holcim resistente a sulfatos',
        ),
        findsWidgets,
      );
      expect(find.text('Varilla corrugada de acero 12mm x 12m grado 60 Adelca'),
          findsWidgets);

      await tester.enterText(
        find.byKey(const Key('orbi-listing-filter')),
        'Cemento',
      );
      await tester.pumpAndSettle();

      // The filter goes through the catalog controller (same query the
      // repository already filters on), so the grid — not a separate
      // results list — narrows to the match.
      expect(find.byType(SfDataGrid), findsOneWidget);
      expect(
        find.text(
          'Cemento Portland Tipo GU saco 50kg Holcim resistente a sulfatos',
        ),
        findsWidgets,
      );
      expect(
        find.text('Varilla corrugada de acero 12mm x 12m grado 60 Adelca'),
        findsNothing,
      );

      await tester.binding.setSurfaceSize(null);
    },
  );
}
