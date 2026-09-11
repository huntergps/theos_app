import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/scope_catalog_repository.dart';
import 'package:theos_panel/features/clients/catalog_contracts.dart';

final class _ObservableStore
    implements LocalCatalogStore<Map<String, dynamic>> {
  _ObservableStore(this.scope);
  final AppScope scope;
  final records = <CatalogRecord<Map<String, dynamic>>>[];
  final cancelStarted = Completer<void>();
  final allowCancel = Completer<void>();
  bool holdCancellation = false;
  final changes =
      StreamController<CatalogState<Map<String, dynamic>>>.broadcast();
  int activeWatches = 0;

  @override
  Future<CatalogState<Map<String, dynamic>>> read(AppScope requested) async =>
      CatalogState(records: requested == scope ? records : const []);

  @override
  Stream<CatalogState<Map<String, dynamic>>> watch(AppScope requested) {
    late StreamSubscription<CatalogState<Map<String, dynamic>>> forwarding;
    late StreamController<CatalogState<Map<String, dynamic>>> controller;
    controller = StreamController<CatalogState<Map<String, dynamic>>>(
      onListen: () {
        activeWatches++;
        forwarding = changes.stream.listen(
          controller.add,
          onError: controller.addError,
          onDone: controller.close,
        );
        unawaited(
          read(requested).then((state) {
            if (!controller.isClosed) controller.add(state);
          }),
        );
      },
      onCancel: () async {
        await forwarding.cancel();
        activeWatches--;
        if (holdCancellation) {
          if (!cancelStarted.isCompleted) cancelStarted.complete();
          await allowCancel.future;
        }
      },
    );
    return controller.stream;
  }

  @override
  Future<void> commit(
    AppScope requested,
    CatalogBatch<Map<String, dynamic>> batch,
  ) async {
    records
      ..clear()
      ..addAll(batch.records);
    changes.add(await read(requested));
  }

  @override
  Future<void> recordError(AppScope scope, Object error) async {}

  Future<void> close() => changes.close();

  void emitError(Object error) => changes.addError(error);
}

AppScope _scope() => AppScope(
  appId: 'panel',
  installationId: 'lifecycle',
  normalizedServerUrl: 'https://erp.test',
  database: 'db',
  userId: 7,
);

void main() {
  test(
    'maps camelCase and Odoo product fields without changing identity',
    () async {
      final scope = _scope();
      final store = _ObservableStore(scope)
        ..records.addAll([
          const CatalogRecord(
            uuid: 'p-local',
            value: {
              'localId': 'p-local',
              'remoteId': 5,
              'name': 'Cinta',
              'price': 3.25,
              'uomId': 2,
              'uomName': 'Unidad',
              'taxIds': [1],
            },
          ),
          const CatalogRecord(
            uuid: 'product:7',
            value: {
              'id': 7,
              'name': 'Taladro',
              'list_price': 49.9,
              'uom_id': [3, 'Unidad'],
              'taxes_id': [4],
            },
          ),
        ]);
      final repository = RuntimeProductCatalogRepository(
        store: store,
        scope: scope,
      );
      final snapshot = await repository.watch(CatalogQuery()).first;
      expect(snapshot.status, CatalogLoadStatus.data);
      expect(snapshot.items[0].value?.localId, 'p-local');
      expect(snapshot.items[0].value?.remoteId, 5);
      expect(snapshot.items[0].value?.uomId, 2);
      expect(snapshot.items[0].value?.taxIds, [1]);
      expect(snapshot.items[1].value?.localId, 'product:7');
      expect(snapshot.items[1].value?.remoteId, 7);
      expect(snapshot.items[1].value?.uomId, 3);
      expect(snapshot.items[1].value?.taxIds, [4]);
      await repository.dispose();
      await store.close();
    },
  );

  test('invalid product numeric fields become an error snapshot', () async {
    final scope = _scope();
    final store = _ObservableStore(scope)
      ..records.add(
        const CatalogRecord(
          uuid: 'product:8',
          value: {'id': 8, 'name': 'Roto', 'list_price': double.nan},
        ),
      );
    final repository = RuntimeProductCatalogRepository(
      store: store,
      scope: scope,
    );
    final snapshot = await repository.watch(CatalogQuery()).first;
    expect(snapshot.status, CatalogLoadStatus.error);
    expect(snapshot.items, isEmpty);
    expect(snapshot.error, isA<FormatException>());
    await repository.dispose();
    await store.close();
  });

  test(
    'normalizes optional partner false values and rejects wrong types',
    () async {
      final scope = _scope();
      final store = _ObservableStore(scope)
        ..records.add(
          const CatalogRecord(
            uuid: 'partner:9',
            value: {'id': 9, 'name': 'Cliente', 'vat': false, 'email': false},
          ),
        );
      final repository = RuntimePartnerCatalogRepository(
        store: store,
        scope: scope,
      );
      final valid = await repository.watch(CatalogQuery()).first;
      expect(valid.status, CatalogLoadStatus.data);
      expect(valid.items.single.value?.remoteId, 9);
      expect(valid.items.single.value?.vat, isNull);
      expect(valid.items.single.value?.email, isNull);
      await repository.dispose();
      await store.close();

      final invalidStore = _ObservableStore(scope)
        ..records.add(
          const CatalogRecord(
            uuid: 'partner:10',
            value: {'id': 10, 'name': 'Cliente', 'email': 123},
          ),
        );
      final invalidRepository = RuntimePartnerCatalogRepository(
        store: invalidStore,
        scope: scope,
      );
      final invalid = await invalidRepository.watch(CatalogQuery()).first;
      expect(invalid.status, CatalogLoadStatus.error);
      expect(invalid.error, isA<FormatException>());
      await invalidRepository.dispose();
      await invalidStore.close();
    },
  );

  test(
    'dispose closes catalog stream without deleting durable records',
    () async {
      final scope = _scope();
      final store = _ObservableStore(scope);
      final repository = RuntimeScopeCatalogRepository(
        store: store,
        scope: scope,
      );
      final subscription = repository.watch(CatalogQuery()).listen((_) {});

      await pumpEventQueue();
      final late = await repository.watch(CatalogQuery()).first;
      expect(late.items, isEmpty);
      expect(store.activeWatches, 1);
      store.holdCancellation = true;
      final firstCancel = subscription.cancel();
      await store.cancelStarted.future;

      final updates = <CatalogSnapshot<String>>[];
      final active = repository.watch(CatalogQuery()).listen(updates.add);
      await store.commit(
        scope,
        const CatalogBatch(
          records: [
            CatalogRecord(uuid: 'before', value: {'name': 'Antes'}),
          ],
          cursor: null,
        ),
      );
      store.allowCancel.complete();
      await pumpEventQueue();
      updates.clear();
      await store.commit(
        scope,
        const CatalogBatch(
          records: [
            CatalogRecord(uuid: 'after', value: {'name': 'Después'}),
          ],
          cursor: null,
        ),
      );
      await pumpEventQueue();
      expect(updates.last.items.single.title, 'Después');
      await firstCancel;
      expect(store.activeWatches, lessThanOrEqualTo(1));
      await repository.dispose();
      await store.commit(
        scope,
        const CatalogBatch(
          records: [
            CatalogRecord(uuid: '1', value: {'name': 'Retenido'}),
          ],
          cursor: null,
        ),
      );

      expect((await store.read(scope)).records.single.uuid, '1');
      expect(() => repository.watch(CatalogQuery()), throwsStateError);
      await active.cancel();
      await store.close();
    },
  );

  test(
    'store errors become snapshots and completion closes listeners',
    () async {
      final scope = _scope();
      final store = _ObservableStore(scope);
      final repository = RuntimeScopeCatalogRepository(
        store: store,
        scope: scope,
      );
      final snapshots = <CatalogSnapshot<String>>[];
      final done = Completer<void>();
      final subscription = repository
          .watch(CatalogQuery())
          .listen(snapshots.add, onDone: done.complete);
      await pumpEventQueue();
      store.emitError(StateError('catalog failed'));
      await pumpEventQueue();
      expect(snapshots.last.status, CatalogLoadStatus.error);
      await store.close();
      await done.future;
      await subscription.cancel();
      await repository.dispose();
    },
  );
}
