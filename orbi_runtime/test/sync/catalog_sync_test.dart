import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/src/contracts.dart';
import 'package:orbi_runtime/src/sync/catalog_sync.dart';

AppScope scope() => AppScope(
  appId: 'orbi-panel',
  installationId: 'install',
  normalizedServerUrl: 'https://erp.test',
  database: 'db',
  userId: 1,
);

final class _PersistentStore implements LocalCatalogStore<String> {
  _PersistentStore(this.states);
  final Map<String, CatalogState<String>> states;
  final _events = <String, StreamController<CatalogState<String>>>{};

  String key(AppScope value) => value.scopeKey;

  @override
  Future<CatalogState<String>> read(AppScope value) async =>
      states[key(value)] ?? CatalogState<String>();

  @override
  Stream<CatalogState<String>> watch(AppScope value) {
    final controller = _events.putIfAbsent(
      key(value),
      () => StreamController<CatalogState<String>>.broadcast(),
    );
    return controller.stream;
  }

  @override
  Future<void> commit(AppScope value, CatalogBatch<String> batch) async {
    final next = CatalogState<String>(records: batch.records, cursor: batch.cursor);
    states[key(value)] = next;
    _events[key(value)]?.add(next);
  }

  @override
  Future<void> recordError(AppScope value, Object error) async {
    final current = await read(value);
    final next = CatalogState<String>(records: current.records, cursor: current.cursor, error: error);
    states[key(value)] = next;
    _events[key(value)]?.add(next);
  }

  Future<void> dispose() async {
    for (final controller in _events.values) {
      await controller.close();
    }
  }
}

void main() {
  test('publishes count and cursor only after committed local update', () async {
    final store = _PersistentStore({});
    addTearDown(store.dispose);
    final states = <CatalogState<String>>[];
    final subscription = store.watch(scope()).listen(states.add);
    final job = CatalogSyncJob<String>(
      id: 'products',
      store: store,
      load: (_, cursor) async {
        expect(cursor, isNull);
        return const CatalogBatch<String>(
          records: [CatalogRecord(uuid: 'p-1', value: 'Product', dependencies: ['tax-1'])],
          cursor: 'c-1',
        );
      },
    );
    final result = await job.run(scope());
    await Future<void>.delayed(Duration.zero);
    expect(result.cursorConfirmed, isTrue);
    expect(states.single.count, 1);
    expect(states.single.cursor, 'c-1');
    expect(states.single.records.single.uuid, 'p-1');
    expect(states.single.records.single.dependencies, ['tax-1']);
    await subscription.cancel();
  });

  test('visible error preserves cursor and records for retry/restart', () async {
    final persisted = <String, CatalogState<String>>{};
    final firstStore = _PersistentStore(persisted);
    addTearDown(firstStore.dispose);
    final initial = CatalogBatch<String>(
      records: const [CatalogRecord(uuid: 'p-1', value: 'Product')],
      cursor: 'c-1',
    );
    await firstStore.commit(scope(), initial);
    final failed = CatalogSyncJob<String>(
      id: 'products',
      store: firstStore,
      load: (_, cursor) async {
        expect(cursor, 'c-1');
        throw StateError('backend unavailable');
      },
    );
    final result = await failed.run(scope());
    expect(result.cursorConfirmed, isFalse);
    final afterFailure = await firstStore.read(scope());
    expect(afterFailure.cursor, 'c-1');
    expect(afterFailure.records.single.uuid, 'p-1');
    expect(afterFailure.error, isA<StateError>());

    final restartedStore = _PersistentStore(persisted);
    addTearDown(restartedStore.dispose);
    final retry = CatalogSyncJob<String>(
      id: 'products',
      store: restartedStore,
      load: (_, cursor) async {
        expect(cursor, 'c-1');
        return const CatalogBatch<String>(
          records: [CatalogRecord(uuid: 'p-2', value: 'Product 2', dependencies: ['p-1'])],
          cursor: 'c-2',
        );
      },
    );
    expect((await retry.run(scope())).cursor, 'c-2');
    final afterRetry = await restartedStore.read(scope());
    expect(afterRetry.records.single.uuid, 'p-2');
    expect(afterRetry.records.single.dependencies, ['p-1']);
    expect(afterRetry.cursor, 'c-2');
  });
}
