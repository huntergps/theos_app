import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_panel/features/clients/catalog_contracts.dart';
import 'package:theos_panel/features/products/products_screen.dart';
import 'package:theos_panel/ui/components/fields/orbi_inline_catalog_picker.dart';
import 'package:theos_panel/ui/components/records/orbi_record_list.dart';

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
  testWidgets('products screen shows a real grid on wide/landscape and a '
      'list on portrait/phone, without overflow, at all four sizes', (
    tester,
  ) async {
    final repository = _FakeProductRepository(_products());
    addTearDown(repository.dispose);
    final controller = CatalogController<String>(repository: repository);
    addTearDown(controller.dispose);

    for (final size in _sizes) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: ProductsScreen<String>(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final isWideLandscape = size.width >= 840 && size.width > size.height;
      expect(
        find.byType(SfDataGrid),
        isWideLandscape ? findsOneWidget : findsNothing,
        reason: 'grid expected only on desktop/tablet horizontal, size=$size',
      );
      expect(
        find.byType(OrbiRecordList<CatalogEntity<String>>),
        isWideLandscape ? findsNothing : findsOneWidget,
        reason: 'list expected on tablet vertical/phone, size=$size',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'no overflow/exception expected at size=$size',
      );
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'product search is inline inside the grid area, not an external '
    'search bar replacing it',
    (tester) async {
      final repository = _FakeProductRepository(_products());
      addTearDown(repository.dispose);
      final controller = CatalogController<String>(repository: repository);
      addTearDown(controller.dispose);

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(1440, 900)),
            child: ProductsScreen<String>(controller: controller),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // The reusable inline picker component is used for product search...
      expect(find.byType(OrbiInlineCatalogPicker<String>), findsOneWidget);
      // ...and the full catalog grid stays visible at the same time: the
      // inline search augments the grid, it does not replace it with a bare
      // results list.
      expect(find.byType(SfDataGrid), findsOneWidget);
      expect(find.text('Cemento Portland Tipo GU saco 50kg Holcim resistente a sulfatos'),
          findsWidgets);

      await tester.binding.setSurfaceSize(null);
    },
  );
}
