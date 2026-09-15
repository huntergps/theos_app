import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:theos_panel/features/envases/envases_existencias_contracts.dart';
import 'package:theos_panel/features/envases/envases_existencias_screen.dart';
import 'package:theos_panel/ui/fluent/orbi_fluent_theme.dart';

/// Mirrors `EnvasesExistenciasCache.watch()`'s real contract: every new
/// subscriber gets the CURRENT value immediately, and every later
/// replacement reaches whoever is still listening — same shape as the
/// warehouse existences screen's fake repository.
final class _FakeRepository implements EnvasesExistenciasRepository {
  _FakeRepository({EnvasesExistenciasSnapshot? initial}) : _current = initial;

  EnvasesExistenciasSnapshot? _current;
  final _listeners = <void Function(EnvasesExistenciasSnapshot?)>{};
  int refreshCount = 0;
  Object? refreshError;
  EnvasesExistenciasSnapshot? onRefresh;

  @override
  Stream<EnvasesExistenciasSnapshot?> watch() => Stream.multi((controller) {
    controller.add(_current);
    void listener(EnvasesExistenciasSnapshot? value) => controller.add(value);
    _listeners.add(listener);
    controller.onCancel = () => _listeners.remove(listener);
  });

  @override
  Future<void> refresh() async {
    refreshCount++;
    if (refreshError != null) throw refreshError!;
    if (onRefresh != null) _push(onRefresh);
  }

  void pushFromElsewhere(EnvasesExistenciasSnapshot snapshot) => _push(snapshot);

  void _push(EnvasesExistenciasSnapshot? snapshot) {
    _current = snapshot;
    for (final listener in Set.of(_listeners)) {
      listener(snapshot);
    }
  }
}

EnvasesExistenciasData _twoSedes({int pendientes = 0}) =>
    EnvasesExistenciasData.fromJson({
      'columnas': [
        {'id': 'sede-1', 'nombre': 'Sede A', 'location_id': 11, 'tipo': 'sede'},
        {
          'id': 'transito-1-2',
          'nombre': 'Sede A → Sede B',
          'location_id': 13,
          'tipo': 'transito',
        },
        {
          'id': 'transito-2-1',
          'nombre': 'Sede B → Sede A',
          'location_id': 14,
          'tipo': 'transito',
        },
        {'id': 'sede-2', 'nombre': 'Sede B', 'location_id': 12, 'tipo': 'sede'},
      ],
      'filas': [
        {
          'id': 501,
          'nombre': 'Cola',
          'uom': 'Unidad',
          'celdas': {
            'sede-1': 100.0,
            'transito-1-2': 24.0,
            'transito-2-1': 0.0,
            'sede-2': 200.0,
          },
          'total': 324.0,
        },
      ],
      'totales_columna': {
        'sede-1': 100.0,
        'transito-1-2': 24.0,
        'transito-2-1': 0.0,
        'sede-2': 200.0,
      },
      'total_general': 324.0,
      'pendientes': pendientes,
    });

EnvasesExistenciasData _threeSedes() => EnvasesExistenciasData.fromJson({
  'columnas': [
    {'id': 'sede-1', 'nombre': 'Primera sede', 'location_id': 11, 'tipo': 'sede'},
    {'id': 'sede-2', 'nombre': 'Segunda sede', 'location_id': 12, 'tipo': 'sede'},
    {'id': 'sede-3', 'nombre': 'Tercera sede', 'location_id': 13, 'tipo': 'sede'},
  ],
  'filas': [
    {
      'id': 501,
      'nombre': 'Cerveza',
      'uom': 'Unidad',
      'celdas': {'sede-1': 10.0, 'sede-2': 20.0, 'sede-3': 30.0},
      'total': 60.0,
    },
  ],
  'totales_columna': {'sede-1': 10.0, 'sede-2': 20.0, 'sede-3': 30.0},
  'total_general': 60.0,
  'pendientes': 0,
});

EnvasesExistenciasSnapshot _snapshot(EnvasesExistenciasData data) =>
    EnvasesExistenciasSnapshot(data: data, cachedAt: DateTime.utc(2026, 9, 13, 15, 30));

Future<void> _pumpAt(
  WidgetTester tester,
  EnvasesExistenciasRepository repository,
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
        child: EnvasesExistenciasScreen(repository: repository),
      ),
    ),
  );
}

const _desktop = Size(1400, 900);
const _phone = Size(390, 844);

void main() {
  testWidgets('renders every server column, in order, plus the total — desktop grid', (
    tester,
  ) async {
    final repository = _FakeRepository()..onRefresh = _snapshot(_twoSedes());
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    await tester.pumpAndSettle();

    expect(find.byType(SfDataGrid), findsOneWidget);
    expect(find.text('Cola'), findsOneWidget);
    expect(find.text('Sede A'), findsOneWidget);
    expect(find.text('Sede A → Sede B'), findsOneWidget);
    expect(find.text('Sede B → Sede A'), findsOneWidget);
    expect(find.text('Sede B'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
    expect(repository.refreshCount, 1);
  });

  testWidgets('same data as cards on phone width, with the total as the card badge', (
    tester,
  ) async {
    final repository = _FakeRepository()..onRefresh = _snapshot(_twoSedes());
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _phone);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('orbi-listing-cards')), findsOneWidget);
    expect(find.byType(SfDataGrid), findsNothing);
    expect(find.text('Cola'), findsOneWidget);
    expect(find.text('Sede A'), findsOneWidget);
    expect(find.text('Sede A → Sede B'), findsOneWidget);
    expect(find.text('Sede B → Sede A'), findsOneWidget);
    expect(find.text('Sede B'), findsOneWidget);
    expect(find.text('324 propios'), findsOneWidget);
  });

  testWidgets('three server-declared sites render three columns, not a fixed two', (
    tester,
  ) async {
    final repository = _FakeRepository()..onRefresh = _snapshot(_threeSedes());
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    await tester.pumpAndSettle();

    expect(find.text('Primera sede'), findsOneWidget);
    expect(find.text('Segunda sede'), findsOneWidget);
    expect(find.text('Tercera sede'), findsOneWidget);
    expect(find.text('Total'), findsOneWidget);
  });

  testWidgets('shows only the pendientes count, no receiving list', (tester) async {
    final repository = _FakeRepository()
      ..onRefresh = _snapshot(_twoSedes(pendientes: 4));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('envases-existencias-pendientes')), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
  });

  testWidgets(
    'updates on its own when a sync commits a new snapshot — no extra refresh call',
    (tester) async {
      final repository = _FakeRepository()..onRefresh = _snapshot(_twoSedes());
      addTearDown(() => tester.binding.setSurfaceSize(null));

      await _pumpAt(tester, repository, _desktop);
      await tester.pumpAndSettle();
      expect(find.text('Cola'), findsOneWidget);
      expect(repository.refreshCount, 1);

      repository.pushFromElsewhere(_snapshot(_threeSedes()));
      await tester.pumpAndSettle();

      expect(find.text('Cerveza'), findsOneWidget);
      expect(find.text('Cola'), findsNothing);
      expect(
        repository.refreshCount,
        1,
        reason: 'the update must come from watch(), not another refresh()',
      );
    },
  );

  testWidgets('surfaces a refresh failure with a retry action', (tester) async {
    final repository = _FakeRepository()..refreshError = StateError('offline');
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    await tester.pumpAndSettle();

    expect(
      find.text('No se pudo actualizar las existencias de envases.'),
      findsOneWidget,
    );
    expect(find.text('Reintentar'), findsOneWidget);
  });

  testWidgets('filters locally by product, over the local copy only', (tester) async {
    final repository = _FakeRepository()..onRefresh = _snapshot(_threeSedes());
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    await tester.pumpAndSettle();
    expect(find.text('Cerveza'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('orbi-listing-filter')),
      'no coincide',
    );
    await tester.pumpAndSettle();
    expect(find.text('Cerveza'), findsNothing);
    expect(repository.refreshCount, 1);
  });

  testWidgets('null snapshot is distinct from a loaded empty grid', (tester) async {
    final repository = _FakeRepository();
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    await tester.pump();
    expect(find.byKey(const Key('envases-existencias-loading')), findsOneWidget);

    repository.pushFromElsewhere(
      EnvasesExistenciasSnapshot(
        data: EnvasesExistenciasData.fromJson({
          'columnas': const [],
          'filas': const [],
          'totales_columna': const {},
          'total_general': 0.0,
          'pendientes': 0,
        }),
        cachedAt: DateTime.utc(2026),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Sin existencias'), findsOneWidget);
  });

  testWidgets('existencias columns come from server locations, not hardcoded names', (tester) async {
    // Nombres que no existen en ningún sitio cableado de la pantalla —
    // ninguna sede real de Orbi se llama así. Si aparecieran de todos modos,
    // sería porque alguien volvió a poner "Guayaquil"/"Galápagos" a mano.
    final data = EnvasesExistenciasData.fromJson({
      'columnas': [
        {'id': 'c1', 'nombre': 'Depósito Fantasía', 'location_id': 91, 'tipo': 'sede'},
        {'id': 'c2', 'nombre': 'Bodega Zeta', 'location_id': 92, 'tipo': 'sede'},
      ],
      'filas': [
        {
          'id': 700,
          'nombre': 'Producto X',
          'uom': 'Unidad',
          'celdas': {'c1': 5.0, 'c2': 9.0},
          'total': 14.0,
        },
      ],
      'totales_columna': {'c1': 5.0, 'c2': 9.0},
      'total_general': 14.0,
      'pendientes': 0,
    });
    final repository = _FakeRepository()..onRefresh = _snapshot(data);
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await _pumpAt(tester, repository, _desktop);
    await tester.pumpAndSettle();

    expect(find.text('Depósito Fantasía'), findsOneWidget);
    expect(find.text('Bodega Zeta'), findsOneWidget);
    expect(find.text('Guayaquil'), findsNothing);
    expect(find.text('Galápagos'), findsNothing);
  });
}
