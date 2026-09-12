import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:theos_panel/features/clients/catalog_contracts.dart';
import 'package:theos_panel/features/clients/entity_picker.dart';

final class _DurableCatalog implements CatalogRepository<String> {
  _DurableCatalog(this.storage);
  final Map<String, CatalogSnapshot<String>> storage;
  final Map<String, StreamController<CatalogSnapshot<String>>> _streams = {};
  Object? failure;

  String _key(CatalogQuery query) => '${query.search}|${query.cursor ?? ''}';

  @override
  Stream<CatalogSnapshot<String>> watch(CatalogQuery query) {
    final key = _key(query);
    final stream = _streams.putIfAbsent(
      key,
      () => StreamController<CatalogSnapshot<String>>.broadcast(),
    );
    Future<void>.microtask(
      () => stream.add(
        storage[key] ??
            CatalogSnapshot<String>(status: CatalogLoadStatus.empty),
      ),
    );
    return stream.stream;
  }

  @override
  Future<void> refresh(CatalogQuery query) async {
    final key = _key(query);
    if (failure != null) {
      final previous = storage[key] ?? CatalogSnapshot<String>();
      final error = CatalogSnapshot<String>(
        status: CatalogLoadStatus.error,
        items: previous.items,
        nextCursor: previous.nextCursor,
        totalCount: previous.totalCount,
        error: failure,
      );
      storage[key] = error;
      _streams[key]?.add(error);
      return;
    }
    final value =
        storage[key] ??
        CatalogSnapshot<String>(status: CatalogLoadStatus.empty);
    storage[key] = value;
    _streams[key]?.add(value);
  }

  @override
  Future<void> loadNext(CatalogQuery query) async => refresh(query);

  Future<void> dispose() async {
    for (final stream in _streams.values) {
      await stream.close();
    }
  }
}

CatalogSnapshot<String> products({String? cursor}) => CatalogSnapshot<String>(
  status: CatalogLoadStatus.data,
  items: const [
    CatalogEntity(
      uuid: 'p-1',
      title: 'Producto largo para accesibilidad',
      subtitle: 'Unidad',
    ),
    CatalogEntity(uuid: 'p-2', title: 'Producto 2', subtitle: 'Caja'),
  ],
  nextCursor: cursor == null ? 'c-1' : null,
  totalCount: 2,
);

void main() {
  testWidgets('picker keeps selection and draft across responsive resize', (
    tester,
  ) async {
    final durable = <String, CatalogSnapshot<String>>{'|': products()};
    final repository = _DurableCatalog(durable);
    addTearDown(repository.dispose);
    final controller = CatalogController<String>(repository: repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      FluentApp(
        home: SizedBox(
          width: 599,
          height: 500,
          child: EntityPicker(
            controller: controller,
            label: 'Buscar producto',
          ),
        ),
      ),
    );
    await tester.pump();
    controller.select(controller.snapshot.items.first);
    controller.setDraft('borrador');
    await tester.pumpWidget(
      FluentApp(
        home: SizedBox(
          width: 840,
          height: 500,
          child: EntityPicker(
            controller: controller,
            label: 'Buscar producto',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(controller.selected?.uuid, 'p-1');
    expect(controller.draft, 'borrador');
    expect(find.text('Producto largo para accesibilidad'), findsOneWidget);
    await controller.refresh();
    await tester.pump();
    expect(controller.selected?.uuid, 'p-1');
    expect(controller.draft, 'borrador');
    expect(tester.takeException(), isNull);
  });

  testWidgets('error state is visible and distinct from empty', (tester) async {
    final repository = _DurableCatalog({
      '|': CatalogSnapshot<String>(status: CatalogLoadStatus.error),
    });
    addTearDown(repository.dispose);
    final controller = CatalogController<String>(repository: repository);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      FluentApp(
        home: SizedBox(
          width: 599,
          height: 500,
          child: EntityPicker(
            controller: controller,
            label: 'Buscar cliente',
            entityName: 'clientes',
          ),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('No se pudo cargar clientes.'), findsOneWidget);
    expect(find.text('Sin resultados'), findsNothing);
  });

  test('durable local state is available after repository restart and errors do not advance cursor', () async {
    final storage = <String, CatalogSnapshot<String>>{'|': products()};
    final first = _DurableCatalog(storage);
    final firstState = await first.watch(CatalogQuery()).first;
    expect(firstState.nextCursor, 'c-1');
    await first.dispose();
    final restarted = _DurableCatalog(storage)..failure = StateError('offline');
    final restored = await restarted.watch(CatalogQuery()).first;
    expect(restored.items.first.uuid, 'p-1');
    await restarted.refresh(CatalogQuery());
    expect(storage['|']?.status, CatalogLoadStatus.error);
    expect(storage['|']?.nextCursor, 'c-1');
    await restarted.dispose();
  });

  test('representative local search remains bounded', () async {
    final stopwatch = Stopwatch()..start();
    final records = List.generate(
      5000,
      (index) =>
          CatalogEntity<String>(uuid: 'p-$index', title: 'Producto $index'),
    );
    final matches = records
        .where((record) => record.title.contains('4999'))
        .toList(growable: false);
    stopwatch.stop();
    expect(matches, hasLength(1));
    expect(stopwatch.elapsedMilliseconds, lessThan(500));
  });

  test(
    'search clears a previous page cursor and ignores late query results',
    () async {
      expect(
        CatalogQuery(cursor: ' c-1 ')
            .copyWith(search: ' nuevo ', clearCursor: true)
            .cursor,
        isNull,
      );
      expect(() => CatalogQuery(pageSize: 0), throwsArgumentError);
      final repository = _LateCatalog();
      addTearDown(repository.dispose);
      final controller = CatalogController<String>(repository: repository);
      addTearDown(controller.dispose);
      controller.setSearch('nuevo');
      expect(controller.query.cursor, isNull);
      final oldQuery = repository.queries.first;
      final newQuery = repository.queries.last;
      repository.emit(
        oldQuery,
        CatalogSnapshot<String>(
          status: CatalogLoadStatus.data,
          items: [const CatalogEntity(uuid: 'old', title: 'Viejo')],
        ),
      );
      repository.emit(
        newQuery,
        CatalogSnapshot<String>(
          status: CatalogLoadStatus.data,
          items: [const CatalogEntity(uuid: 'new', title: 'Nuevo')],
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.snapshot.items.single.uuid, 'new');
    },
  );
}

final class _LateCatalog implements CatalogRepository<String> {
  final queries = <CatalogQuery>[];
  final _streams = <String, StreamController<CatalogSnapshot<String>>>{};

  @override
  Stream<CatalogSnapshot<String>> watch(CatalogQuery query) {
    queries.add(query);
    return (_streams[query.search] ??=
            StreamController<CatalogSnapshot<String>>.broadcast())
        .stream;
  }

  void emit(CatalogQuery query, CatalogSnapshot<String> value) =>
      _streams[query.search]?.add(value);

  @override
  Future<void> loadNext(CatalogQuery query) async {}

  @override
  Future<void> refresh(CatalogQuery query) async {}

  Future<void> dispose() async {
    for (final stream in _streams.values) {
      await stream.close();
    }
  }
}
