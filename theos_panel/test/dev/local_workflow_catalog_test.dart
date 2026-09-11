import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';

import '../../dev/local_workflow_fixtures.dart';

import 'package:theos_panel/app/scope_catalog_repository.dart';
import 'package:theos_panel/features/clients/catalog_contracts.dart';

AppScope _scope() => AppScope(
  appId: 'theos_panel',
  installationId: 'local-catalog-test',
  normalizedServerUrl: 'https://orbi.invalid',
  database: 'local_workflow',
  userId: 7,
);

void main() {
  late Directory directory;
  late File file;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('local-catalog-');
    file = File('${directory.path}/runtime.sqlite');
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  test(
    'seeds and maps real local product, partner, and term projections',
    () async {
      final owner = RuntimeDatabaseOwner(
        factory: (_) => AppDatabase(NativeDatabase(file)),
      );
      addTearDown(owner.close);
      final runtime = SessionRuntime(databaseOwner: owner);
      final scope = _scope();
      final activation = await runtime.activate(scope);
      final composition = await seedLocalSaleCatalogs(
        runtime: runtime,
        scope: scope,
      );

      final productState = await composition.stores['product']!.read(scope);
      expect(productState.records, isNotEmpty);
      final productRepository = RuntimeProductCatalogRepository(
        store: composition.stores['product']!,
        scope: scope,
      );
      final productQuery = CatalogQuery(search: 'Taladro');
      final productSnapshotFuture = productRepository
          .watch(productQuery)
          .firstWhere((snapshot) => snapshot.status == CatalogLoadStatus.data);
      await productRepository.refresh(productQuery);
      final productSnapshot = await productSnapshotFuture;
      final product = productSnapshot.items.single.value!;
      expect(product.localId, 'product:101');
      expect(product.remoteId, 101);
      expect(product.name, contains('Taladro'));
      expect(product.price, 49.90);
      await productRepository.dispose();

      final partnerState = await composition.stores['partner']!.read(scope);
      expect(partnerState.records, hasLength(2));
      expect(partnerState.records.first.value['name'], contains('demo'));
      final partnerRepository = RuntimePartnerCatalogRepository(
        store: composition.stores['partner']!,
        scope: scope,
      );
      final partnerSnapshot = await partnerRepository
          .watch(CatalogQuery())
          .first;
      expect(partnerSnapshot.items.first.value?.remoteId, 201);
      expect(partnerSnapshot.items.first.value?.email, 'compras@demo.invalid');
      await partnerRepository.dispose();
      final terms = await composition.stores['paymentTerm']!.read(scope);
      expect(
        terms.records.map((record) => record.value['name']),
        contains('Contado demo'),
      );
      expect(activation.scope, scope);
    },
  );

  test(
    'malformed product identity becomes an error, never a zero product',
    () async {
      final scope = _scope();
      final store = _StaticCatalogStore(
        CatalogState(
          records: [
            CatalogRecord(
              uuid: 'product:bad',
              value: {'id': 'bad', 'name': 'X'},
            ),
          ],
        ),
      );
      final repository = RuntimeProductCatalogRepository(
        store: store,
        scope: scope,
      );
      final query = CatalogQuery();
      final errorFuture = repository
          .watch(query)
          .firstWhere((snapshot) => snapshot.status == CatalogLoadStatus.error);
      await repository.refresh(query);
      final snapshot = await errorFuture;
      expect(snapshot.items, isEmpty);
      expect(snapshot.error, isA<FormatException>());
      await repository.dispose();
    },
  );
}

final class _StaticCatalogStore
    implements LocalCatalogStore<Map<String, dynamic>> {
  _StaticCatalogStore(this.state);
  CatalogState<Map<String, dynamic>> state;
  @override
  Future<CatalogState<Map<String, dynamic>>> read(AppScope scope) async =>
      state;
  @override
  Stream<CatalogState<Map<String, dynamic>>> watch(AppScope scope) =>
      Stream<CatalogState<Map<String, dynamic>>>.value(state);
  @override
  Future<void> commit(
    AppScope scope,
    CatalogBatch<Map<String, dynamic>> batch,
  ) async {}
  @override
  Future<void> recordError(AppScope scope, Object error) async {}
}
