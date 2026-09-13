import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_panel/features/clients/catalog_contracts.dart';
import 'package:theos_panel/features/sales/sale_editor.dart';
import 'package:theos_panel/features/sales/sale_lines_editor.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

class _Repository implements CatalogRepository<SaleCatalogProduct> {
  @override
  Stream<CatalogSnapshot<SaleCatalogProduct>> watch(CatalogQuery query) =>
      Stream.value(
        CatalogSnapshot<SaleCatalogProduct>(
          status: CatalogLoadStatus.data,
          items: [
            CatalogEntity<SaleCatalogProduct>(
              uuid: 'prod-b',
              title: 'Broca',
              value: SaleCatalogProduct(
                localId: 'prod-b',
                name: 'Broca',
                price: 3,
                remoteId: 22,
                uomName: 'PZA',
              ),
            ),
          ],
        ),
      );

  @override
  Future<void> loadNext(CatalogQuery query) async {}

  @override
  Future<void> refresh(CatalogQuery query) async {}
}

SaleDraftSnapshot _draft({bool amountsCalculated = false}) => SaleDraftSnapshot(
  lines: [
    SaleDraftLine(
      uuid: 'line-a',
      name: 'Martillo',
      quantity: 2,
      unitPrice: 12.5,
      uomName: 'PZA',
      amountsCalculated: amountsCalculated,
    ),
  ],
);

Widget _host(
  SaleDraftSnapshot draft, {
  Size? size,
  CatalogController<SaleCatalogProduct>? products,
  ValueChanged<CatalogEntity<SaleCatalogProduct>>? onAddProduct,
  void Function(String, double)? onQuantityChanged,
}) => FluentApp(
  home: MediaQuery(
    data: MediaQueryData(size: size ?? const Size(390, 844)),
    child: ScaffoldPage(
      content: SaleLinesEditor(
        draft: draft,
        products: products,
        onAddProduct: onAddProduct ?? (_) {},
        onRemoveLine: (_) {},
        onQuantityChanged: onQuantityChanged ?? (_, _) {},
      ),
    ),
  ),
);

void main() {
  testWidgets('renders all four viewport sizes without table in portrait', (
    tester,
  ) async {
    for (final size in const [
      Size(390, 844),
      Size(820, 1180),
      Size(1180, 820),
      Size(1440, 900),
    ]) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(_host(_draft(), size: size));
      await tester.pump();
      expect(find.text('Martillo'), findsOneWidget);
      final quantityField = tester.widget<TextBox>(
        find.byKey(const ValueKey('sale-quantity-line-a')),
      );
      expect(quantityField.placeholder, 'Cantidad · Martillo');
      final wide = size.width >= 840 && size.width >= size.height;
      expect(find.byType(SfDataGrid), wide ? findsOneWidget : findsNothing);
      expect(tester.takeException(), isNull);
    }
    await tester.binding.setSurfaceSize(null);
  });

  testWidgets(
    'anchors product search and preserves quantity edit across resize',
    (tester) async {
      final products = CatalogController<SaleCatalogProduct>(
        repository: _Repository(),
      );
      addTearDown(products.dispose);
      final edits = <double>[];
      await tester.pumpWidget(
        _host(
          _draft(),
          products: products,
          onQuantityChanged: (_, value) => edits.add(value),
        ),
      );
      await tester.pump();
      expect(find.text('Buscar producto para nueva línea'), findsOneWidget);
      await tester.tap(find.byKey(const Key('sale-inline-product-search')));
      await tester.pump();
      expect(find.text('Broca'), findsOneWidget);
      CatalogEntity<SaleCatalogProduct>? added;
      await tester.pumpWidget(
        _host(
          _draft(),
          size: const Size(1440, 900),
          products: products,
          onAddProduct: (value) => added = value,
          onQuantityChanged: (_, value) => edits.add(value),
        ),
      );
      await tester.pump();
      // The inline picker is rendered in the final grid row on wide layouts;
      // selecting its catalog result invokes the same typed add callback.
      await tester.tap(find.byKey(const Key('sale-inline-product-search')));
      await tester.pump();
      await tester.tap(find.text('Broca'));
      // Drains Fluent's HoverButton press-feedback timer (100ms, see
      // fluent_ui-4.16.1/lib/src/controls/utils/hover_button.dart:319) so it
      // doesn't leak past this test.
      await tester.pump(const Duration(milliseconds: 100));
      expect(added?.title, 'Broca');
      final quantity = find.byKey(const ValueKey('sale-quantity-line-a'));
      await tester.enterText(quantity, '2.5');
      expect(edits, contains(2.5));

      await tester.binding.setSurfaceSize(const Size(1440, 900));
      await tester.pumpWidget(
        _host(
          _draft(),
          size: const Size(1440, 900),
          products: products,
          onQuantityChanged: (_, value) => edits.add(value),
        ),
      );
      await tester.pump();
      expect(
        find.byKey(const ValueKey('sale-quantity-line-a')),
        findsOneWidget,
      );
      final wideQuantityField = tester.widget<TextBox>(
        find.byKey(const ValueKey('sale-quantity-line-a')),
      );
      expect(wideQuantityField.placeholder, 'Cantidad · Martillo');
      expect(find.text('2.5'), findsOneWidget);
      await tester.binding.setSurfaceSize(null);
    },
  );

  testWidgets('marks uncalculated amounts and preserves calculated zero', (
    tester,
  ) async {
    await tester.pumpWidget(_host(_draft()));
    await tester.pump();
    expect(find.textContaining('Pendiente de cálculo'), findsOneWidget);
    expect(find.textContaining('Por validar'), findsOneWidget);

    await tester.pumpWidget(_host(_draft(amountsCalculated: true)));
    await tester.pump();
    expect(find.textContaining('Total 0.00'), findsOneWidget);
    expect(find.textContaining('Descuento 0.0%'), findsOneWidget);
    expect(find.textContaining('Impuesto 0.0%'), findsOneWidget);
  });
}
