import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/read/json2_read_adapters.dart';
import 'package:orbi_runtime/src/sync/catalog_sync.dart';

/// Hueco 4 del encargo del 14-sep-2026: un catálogo grande tardaba tantos
/// CICLOS de sincronización como páginas tuviera su primera carga, uno por
/// vez (`RuntimeCatalogLoader` pide una página de 100 filas por llamada,
/// `json2_read_adapters.dart:558-566,579`, y `CatalogSyncJob.run()` sólo
/// llamaba al cargador una vez por ciclo). Esta prueba fija que, mientras
/// dure la carga inicial, un solo `run()` agote todas las páginas que hagan
/// falta (con tope), y que las pasadas incrementales sigan siendo de una
/// página por ciclo, como siempre.
final class _Reader implements Json2ReadPort {
  _Reader(this.rows);
  final List<Map<String, dynamic>> rows;
  int callCount = 0;

  @override
  Future<List<Map<String, dynamic>>> searchRead({
    required String model,
    required List<String> fields,
    List<dynamic>? domain,
    int? limit,
    int? offset,
    String? order,
  }) async {
    callCount++;
    final start = offset ?? 0;
    if (start >= rows.length) return const [];
    final end = limit == null
        ? rows.length
        : (start + limit).clamp(start, rows.length);
    return rows.sublist(start, end);
  }
}

final class _MemoryStore implements LocalCatalogStore<Map<String, dynamic>> {
  CatalogState<Map<String, dynamic>> _state = CatalogState<Map<String, dynamic>>();
  int commitCount = 0;

  @override
  Future<CatalogState<Map<String, dynamic>>> read(AppScope scope) async => _state;

  @override
  Stream<CatalogState<Map<String, dynamic>>> watch(AppScope scope) =>
      const Stream.empty();

  @override
  Future<void> commit(
    AppScope scope,
    CatalogBatch<Map<String, dynamic>> batch,
  ) async {
    commitCount++;
    _state = CatalogState<Map<String, dynamic>>(
      records: [..._state.records, ...batch.records],
      cursor: batch.cursor,
    );
  }

  @override
  Future<void> recordError(AppScope scope, Object error) async {
    _state = CatalogState<Map<String, dynamic>>(
      records: _state.records,
      cursor: _state.cursor,
      error: error,
    );
  }
}

AppScope _scope() => AppScope(
  appId: 'panel',
  installationId: 'i',
  normalizedServerUrl: 'https://erp.test',
  database: 'db',
  userId: 2,
);

const _descriptor = RuntimeCatalogDescriptor(
  key: 'k',
  model: 'x.model',
  fields: ['id', 'name', 'write_date'],
  order: 'id asc',
);

List<Map<String, dynamic>> _rows(int count) => [
  for (var i = 1; i <= count; i++)
    {'id': i, 'name': 'row-$i', 'write_date': '2026-09-14 00:00:00'},
];

void main() {
  test(
    'un catálogo con 250 filas y páginas de 100 queda completo en UN solo '
    'ciclo (una sola llamada a run())',
    () async {
      final reader = _Reader(_rows(250));
      final loader = RuntimeCatalogLoader(reader, pageSize: 100);
      final store = _MemoryStore();
      final job = CatalogSyncJob<Map<String, dynamic>>(
        id: 'catalog:test',
        store: store,
        load: loader.loader(_descriptor),
      );

      final result = await job.run(_scope());

      expect(result.cursorConfirmed, isTrue);
      // Tres páginas para 250 filas con tamaño 100: 100 + 100 + 50.
      expect(reader.callCount, 3);
      final state = await store.read(_scope());
      expect(state.records, hasLength(250));
      // La carga inicial terminó dentro de este mismo ciclo: el cursor ya
      // pasó a modo incremental, no se quedó a medio camino.
      final decoded = jsonDecode(state.cursor!) as Map<String, dynamic>;
      expect(decoded['mode'], 'since');
    },
  );

  test(
    'una carga incremental (ya con cursor "since") sigue pidiendo el '
    'cargador UNA sola vez por ciclo, como antes de este cambio — '
    'CatalogSyncJob nunca vuelve a entrar al bucle cuando la página no '
    'enciende moreInInitialLoad',
    () async {
      // Primero se agota la carga inicial (una fila, cabe en una página).
      final reader = _Reader(_rows(1));
      final loader = RuntimeCatalogLoader(reader, pageSize: 100);
      final store = _MemoryStore();
      var loaderCalls = 0;
      final job = CatalogSyncJob<Map<String, dynamic>>(
        id: 'catalog:test',
        store: store,
        load: (scope, cursor) {
          loaderCalls++;
          return loader.loader(_descriptor)(scope, cursor);
        },
      );
      await job.run(_scope());
      expect(loaderCalls, 1);

      // Ciclo incremental: sin cambios nuevos, sigue siendo UNA sola llamada
      // al cargador, aunque `RuntimeCatalogLoader` haga, dentro de ESA
      // llamada, su propia reconciliación incidental de la primera pasada
      // (`_runSincePage`, `cycle % reconcileEveryNCycles == 0` con
      // `cycle == 0`) — eso es una llamada de red DENTRO de una misma
      // invocación del cargador, no una vuelta extra del bucle que este
      // cambio añade.
      await job.run(_scope());
      expect(loaderCalls, 2);
    },
  );

  test(
    'el tope por ciclo corta una carga inicial enorme: se retoma en el '
    'ciclo siguiente en vez de agotar todas las páginas de una sentada',
    () async {
      // 60 páginas de 100 (6000 filas) con un tope de 5 páginas por ciclo.
      final reader = _Reader(_rows(6000));
      final loader = RuntimeCatalogLoader(reader, pageSize: 100);
      final store = _MemoryStore();
      final job = CatalogSyncJob<Map<String, dynamic>>(
        id: 'catalog:test',
        store: store,
        load: loader.loader(_descriptor),
        maxPagesPerCycle: 5,
      );

      final first = await job.run(_scope());
      expect(reader.callCount, 5);
      expect(first.cursorConfirmed, isTrue);
      final afterFirst = await store.read(_scope());
      expect(afterFirst.records, hasLength(500));
      // Sigue en carga completa: el próximo ciclo debe seguir pidiendo.
      final decoded = jsonDecode(afterFirst.cursor!) as Map<String, dynamic>;
      expect(decoded['mode'], 'full');

      final second = await job.run(_scope());
      expect(reader.callCount, 10);
      expect(second.cursorConfirmed, isTrue);
    },
  );
}
