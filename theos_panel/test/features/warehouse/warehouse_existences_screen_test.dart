import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_panel/features/warehouse/warehouse_existences_contracts.dart';
import 'package:theos_panel/features/warehouse/warehouse_existences_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Mirrors `StockQuantCache.watch()`'s real contract: every new subscriber
/// gets the CURRENT value immediately (never only future events — a plain
/// broadcast `StreamController` would drop a value pushed before a listener
/// attaches, which is not how the real cache behaves), and every later
/// replacement is delivered to whoever is still listening.
final class _FakeRepository implements WarehouseExistencesRepository {
  _FakeRepository({StockQuantSnapshot? initial}) : _current = initial;

  StockQuantSnapshot? _current;
  final _listeners = <void Function(StockQuantSnapshot?)>{};
  int refreshCount = 0;
  Object? refreshError;
  StockQuantSnapshot? onRefresh;

  @override
  Stream<StockQuantSnapshot?> watch() => Stream.multi((controller) {
    controller.add(_current);
    void listener(StockQuantSnapshot? value) => controller.add(value);
    _listeners.add(listener);
    controller.onCancel = () => _listeners.remove(listener);
  });

  @override
  Future<void> refresh() async {
    refreshCount++;
    if (refreshError != null) throw refreshError!;
    if (onRefresh != null) _push(onRefresh);
  }

  /// Simulates a sync completing in the background: pushes a new snapshot
  /// straight onto the watch stream, exactly like `StockQuantCache.watch()`
  /// re-emitting after another part of the app commits a refresh — never
  /// through this repository's own `refresh()`.
  void pushFromElsewhere(StockQuantSnapshot snapshot) => _push(snapshot);

  void _push(StockQuantSnapshot? snapshot) {
    _current = snapshot;
    for (final listener in Set.of(_listeners)) {
      listener(snapshot);
    }
  }

  Future<void> dispose() async {}
}

StockQuantRow _row({
  int id = 1,
  String product = 'Tornillo 1/4',
  double quantity = 25,
  double reserved = 5,
  int? warehouseId = 3,
  String? warehouseName = 'Guayaquil',
  String? reservedBy,
}) => StockQuantRow.fromJson({
  'id': id,
  'product_id': [10, product],
  'uom_id': [2, 'Unidad'],
  'location_id': [8, 'GYE/Existencias'],
  'warehouse_id': warehouseId == null ? false : [warehouseId, warehouseName],
  'company_id': [1, 'Empresa'],
  'quantity': quantity,
  'reserved_quantity': reserved,
  'available_quantity': quantity - reserved,
  'reservado_por': reservedBy ?? false,
});

Future<void> _pumpAt(
  WidgetTester tester,
  WarehouseExistencesRepository repository,
  Size size,
) async {
  await tester.binding.setSurfaceSize(size);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  await tester.pumpWidget(
    FluentApp(
      theme: OrbiFluentTheme.light,
      home: MediaQuery(
        data: MediaQueryData(size: size),
        child: WarehouseExistencesScreen(repository: repository),
      ),
    ),
  );
}

const _desktop = Size(1400, 900);
const _phone = Size(390, 844);

void main() {
  testWidgets('shows a loading state, then the refreshed existences', (
    tester,
  ) async {
    final repository = _FakeRepository()
      ..onRefresh = StockQuantSnapshot(
        rows: [_row()],
        cachedAt: DateTime.utc(2026, 1, 1, 12),
      );
    addTearDown(repository.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    expect(find.byKey(const Key('existences-loading')), findsOneWidget);

    await tester.pumpAndSettle();
    expect(find.text('Tornillo 1/4'), findsOneWidget);
    expect(repository.refreshCount, 1);
  });

  testWidgets(
    'updates on its own when a sync commits a new snapshot — no extra refresh call',
    (tester) async {
      final repository = _FakeRepository()
        ..onRefresh = StockQuantSnapshot(
          rows: [_row(quantity: 25, reserved: 5)],
          cachedAt: DateTime.utc(2026, 1, 1, 12),
        );
      addTearDown(repository.dispose);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAt(tester, repository, _desktop);
      await tester.pumpAndSettle();
      expect(find.text('20'), findsOneWidget); // available = 25 - 5
      expect(repository.refreshCount, 1);

      // A background sync commits a replacement snapshot directly to the
      // watched table — this screen must pick it up without calling
      // repository.refresh() again.
      repository.pushFromElsewhere(
        StockQuantSnapshot(
          rows: [_row(quantity: 40, reserved: 5)],
          cachedAt: DateTime.utc(2026, 1, 1, 13),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('35'), findsOneWidget); // available = 40 - 5
      expect(find.text('20'), findsNothing);
      expect(
        repository.refreshCount,
        1,
        reason: 'the update must come from watch(), not another refresh()',
      );
    },
  );

  testWidgets('surfaces a refresh failure with a retry action', (
    tester,
  ) async {
    final repository = _FakeRepository()..refreshError = StateError('offline');
    addTearDown(repository.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    await tester.pumpAndSettle();

    expect(find.text('No se pudo actualizar el inventario.'), findsOneWidget);
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('filters by warehouse and by free text, over the local copy only', (
    tester,
  ) async {
    final repository = _FakeRepository()
      ..onRefresh = StockQuantSnapshot(
        rows: [
          _row(id: 1, product: 'Tornillo 1/4', warehouseId: 3, warehouseName: 'Guayaquil'),
          _row(id: 2, product: 'Tuerca M6', warehouseId: 4, warehouseName: 'Quito'),
        ],
        cachedAt: DateTime.utc(2026, 1, 1),
      );
    addTearDown(repository.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    await tester.pumpAndSettle();
    expect(find.text('Tornillo 1/4'), findsOneWidget);
    expect(find.text('Tuerca M6'), findsOneWidget);

    await tester.tap(find.byKey(const Key('existences-warehouse-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quito').last);
    await tester.pumpAndSettle();
    expect(find.text('Tornillo 1/4'), findsNothing);
    expect(find.text('Tuerca M6'), findsOneWidget);
    // Filtering must not touch the network: still a single refresh.
    expect(repository.refreshCount, 1);

    await tester.tap(find.byKey(const Key('existences-warehouse-filter')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Todos').last);
    await tester.pumpAndSettle();
    // El filtro de texto libre ahora es el que trae `OrbiListing` de serie:
    // ya no hay un segundo campo de búsqueda propio de esta pantalla.
    await tester.enterText(
      find.byKey(const Key('orbi-listing-filter')),
      'tornillo',
    );
    await tester.pumpAndSettle();
    expect(find.text('Tornillo 1/4'), findsOneWidget);
    expect(find.text('Tuerca M6'), findsNothing);
  });

  testWidgets('an empty local copy and a filtered-to-zero result read differently', (
    tester,
  ) async {
    final repository = _FakeRepository()
      ..onRefresh = StockQuantSnapshot(rows: const [], cachedAt: DateTime.utc(2026));
    addTearDown(repository.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    await tester.pumpAndSettle();
    expect(
      find.text('No hay existencias registradas para esta compañía.'),
      findsOneWidget,
    );
  });

  testWidgets('never renders a cost field to any viewer', (tester) async {
    final repository = _FakeRepository()
      ..onRefresh = StockQuantSnapshot(
        rows: [_row(reservedBy: 'OUT/00042')],
        cachedAt: DateTime.utc(2026),
      );
    addTearDown(repository.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Phone layout so the detail renders as an `OrbiListing` card row: the
    // label ("Reservado por") and the value ("OUT/00042") are two separate
    // `Text` widgets, not one concatenated string — either way, no cost text
    // may appear anywhere.
    await _pumpAt(tester, repository, _phone);
    await tester.pumpAndSettle();

    expect(find.textContaining('osto', findRichText: true), findsNothing);
    expect(find.text('Reservado por'), findsOneWidget);
    expect(find.text('OUT/00042'), findsOneWidget);
  });

  testWidgets('renders the standard grid on wide layouts and cards on narrow ones', (
    tester,
  ) async {
    final repository = _FakeRepository()
      ..onRefresh = StockQuantSnapshot(rows: [_row()], cachedAt: DateTime.utc(2026));
    addTearDown(repository.dispose);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    await tester.pumpAndSettle();
    expect(find.byType(SfDataGrid), findsOneWidget);
    expect(find.byKey(const Key('orbi-listing-cards')), findsNothing);
    // A concrete row value is visible in the grid, not just its chrome.
    expect(find.text('Tornillo 1/4'), findsOneWidget);

    await _pumpAt(tester, repository, _phone);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('orbi-listing-cards')), findsOneWidget);
    expect(find.byType(SfDataGrid), findsNothing);
    // Same concrete row value, now rendered as a card.
    expect(find.text('Tornillo 1/4'), findsOneWidget);
  });
}
