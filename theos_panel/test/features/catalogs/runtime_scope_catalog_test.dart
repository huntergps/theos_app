import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:orbi_runtime/orbi_runtime.dart';
import 'package:theos_panel/app/scope_catalog_repository.dart';
import 'package:theos_panel/features/clients/catalog_contracts.dart';

final class _Store implements LocalCatalogStore<Map<String, dynamic>> {
  final values = <String, List<CatalogRecord<Map<String, dynamic>>>>{};
  @override Future<CatalogState<Map<String, dynamic>>> read(AppScope scope) async => CatalogState(records: values[scope.scopeKey] ?? const []);
  @override Stream<CatalogState<Map<String, dynamic>>> watch(AppScope scope) async* { yield await read(scope); }
  @override Future<void> commit(AppScope scope, CatalogBatch<Map<String, dynamic>> batch) async => values[scope.scopeKey] = batch.records;
  @override Future<void> recordError(AppScope scope, Object error) async {}
}

AppScope _scope(String installation) => AppScope(appId: 'panel', installationId: installation, normalizedServerUrl: 'https://erp.test', database: 'db', userId: 7);

void main() {
  test('runtime catalog repository isolates login scopes and publishes committed records', () async {
    final store = _Store();
    final a = _scope('a'); final b = _scope('b');
    await store.commit(a, const CatalogBatch(records: [CatalogRecord(uuid: 'a:1', value: {'name': 'Cliente A'})], cursor: null));
    await store.commit(b, const CatalogBatch(records: [CatalogRecord(uuid: 'b:1', value: {'name': 'Cliente B'})], cursor: null));
    final repoA = RuntimeScopeCatalogRepository(store: store, scope: a);
    final repoB = RuntimeScopeCatalogRepository(store: store, scope: b);
    final resultA = await repoA.watch(CatalogQuery()).first;
    final resultB = await repoB.watch(CatalogQuery()).first;
    expect(resultA.items.single.title, 'Cliente A');
    expect(resultB.items.single.title, 'Cliente B');
    expect(resultA.items.single.uuid, isNot(resultB.items.single.uuid));
  });
}
