import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_panel/features/clients/catalog_contracts.dart';
import 'package:theos_panel/features/clients/clients_screen.dart';
import 'package:theos_panel/ui/components/records/orbi_record_list.dart';

/// Local catalog fake: watches never touch Odoo/ERP2, they only replay an
/// in-memory list filtered by the current query, as [CatalogRepository]
/// documents for real observable repositories.
final class _FakeClientRepository implements CatalogRepository<String> {
  _FakeClientRepository(this.items);
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

/// Client names/subtitles long enough to break a fixed-size, desktop-shaped
/// cell as soon as the viewport narrows — the same overflow family already
/// found in the design galleries (desktop content, tablet width).
List<CatalogEntity<String>> _clients() => const [
  CatalogEntity(
    uuid: 'c-1',
    title: 'Distribuidora Comercial del Norte y Asociados Cía. Ltda.',
    subtitle: 'RUC 0999999999001 · Av. Amazonas y Naciones Unidas, Quito',
    value: 'c-1',
  ),
  CatalogEntity(
    uuid: 'c-2',
    title: 'Importadora y Exportadora San Vicente del Pacífico S.A.',
    subtitle: 'RUC 0992222222001 · Vía a la Costa km 12.5, Guayaquil',
    value: 'c-2',
  ),
  CatalogEntity(
    uuid: 'c-3',
    title: 'Ferretería Industrial El Constructor',
    subtitle: 'RUC 1791111111001 · Cuenca',
    value: 'c-3',
  ),
];

const _sizes = [
  Size(1440, 900), // escritorio
  Size(1180, 820), // tablet horizontal
  Size(820, 1180), // tablet vertical
  Size(390, 844), // teléfono
];

void main() {
  testWidgets('clients screen shows a real grid on wide/landscape and a '
      'list on portrait/phone, without overflow, at all four sizes', (
    tester,
  ) async {
    final repository = _FakeClientRepository(_clients());
    addTearDown(repository.dispose);
    final controller = CatalogController<String>(repository: repository);
    addTearDown(controller.dispose);

    for (final size in _sizes) {
      await tester.binding.setSurfaceSize(size);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: ClientsScreen<String>(controller: controller),
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
}
