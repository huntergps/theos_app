import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/scope_catalog_repository.dart';
import 'package:theos_panel/features/clients/catalog_contracts.dart';

final class _Store implements LocalCatalogStore<Map<String, dynamic>> {
  final values = <String, List<CatalogRecord<Map<String, dynamic>>>>{};
  final streams =
      <String, StreamController<CatalogState<Map<String, dynamic>>>>{};
  int activeWatches = 0;

  @override
  Future<CatalogState<Map<String, dynamic>>> read(AppScope scope) async =>
      CatalogState(records: values[scope.scopeKey] ?? const []);

  @override
  Stream<CatalogState<Map<String, dynamic>>> watch(AppScope scope) async* {
    activeWatches++;
    try {
      yield await read(scope);
      yield* (streams[scope.scopeKey] ??= StreamController.broadcast()).stream;
    } finally {
      activeWatches--;
    }
  }

  @override
  Future<void> commit(
    AppScope scope,
    CatalogBatch<Map<String, dynamic>> batch,
  ) async {
    values[scope.scopeKey] = batch.records;
    streams[scope.scopeKey]?.add(await read(scope));
  }

  @override
  Future<void> recordError(AppScope scope, Object error) async {}

  Future<void> dispose() async {
    for (final stream in streams.values) {
      await stream.close();
    }
  }
}

AppScope _scope(String installation) => AppScope(
  appId: 'panel',
  installationId: installation,
  normalizedServerUrl: 'https://erp.test',
  database: 'db',
  userId: 7,
);

void main() {
  test('runtime catalog repository isolates login scopes and publishes committed records', () async {
    final store = _Store();
    final a = _scope('a');
    final b = _scope('b');
    await store.commit(
      a,
      const CatalogBatch(
        records: [
          CatalogRecord(uuid: 'a:1', value: {'name': 'Cliente A'}),
        ],
        cursor: null,
      ),
    );
    await store.commit(
      b,
      const CatalogBatch(
        records: [
          CatalogRecord(uuid: 'b:1', value: {'name': 'Cliente B'}),
        ],
        cursor: null,
      ),
    );
    final repoA = RuntimeScopeCatalogRepository(store: store, scope: a);
    final repoB = RuntimeScopeCatalogRepository(store: store, scope: b);
    final resultA = await repoA.watch(CatalogQuery()).first;
    final resultB = await repoB.watch(CatalogQuery()).first;
    expect(resultA.items.single.title, 'Cliente A');
    expect(resultB.items.single.title, 'Cliente B');
    expect(resultA.items.single.uuid, isNot(resultB.items.single.uuid));

    final updates = <CatalogSnapshot<String>>[];
    final updateSubscription = repoA.watch(CatalogQuery()).listen(updates.add);
    await store.commit(
      a,
      const CatalogBatch(
        records: [
          CatalogRecord(uuid: 'a:2', value: {'name': 'Cliente A actualizado'}),
        ],
        cursor: null,
      ),
    );
    await pumpEventQueue();
    expect(updates.last.items.single.title, 'Cliente A actualizado');

    // A late listener receives the latest snapshot immediately, without
    // requiring another durable commit.
    final late = await repoA.watch(CatalogQuery()).first;
    expect(late.items.single.title, 'Cliente A actualizado');
    expect(store.activeWatches, 1);
    await updateSubscription.cancel();
    await repoA.dispose();
    await pumpEventQueue();
    expect(store.activeWatches, 0);

    await repoB.dispose();
    await store.dispose();
  });
}
