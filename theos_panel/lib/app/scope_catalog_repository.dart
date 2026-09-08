import 'dart:async';

import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/clients/catalog_contracts.dart';
import '../features/sales/sale_editor.dart';

final class RuntimeScopeCatalogRepository implements CatalogRepository<String> {
  RuntimeScopeCatalogRepository({required this.store, required this.scope});
  final LocalCatalogStore<Map<String, dynamic>> store;
  final AppScope scope;
  final _streams = <String, StreamController<CatalogSnapshot<String>>>{};
  String _key(CatalogQuery query) =>
      '${query.search}|${query.cursor ?? ''}|${query.pageSize}';
  @override
  Stream<CatalogSnapshot<String>> watch(CatalogQuery query) {
    final key = _key(query);
    final controller = _streams.putIfAbsent(
      key,
      () => StreamController.broadcast(),
    );
    unawaited(_read(query, controller));
    return controller.stream;
  }

  Future<void> _read(
    CatalogQuery query,
    StreamController<CatalogSnapshot<String>> out,
  ) async {
    try {
      final state = await store.read(scope);
      final all = state.records
          .where(
            (r) => r.value.values.any(
              (v) => '$v'.toLowerCase().contains(query.search.toLowerCase()),
            ),
          )
          .toList();
      final offset = query.cursor == null
          ? 0
          : int.tryParse(query.cursor!) ?? 0;
      final page = all.skip(offset).take(query.pageSize).toList();
      out.add(
        CatalogSnapshot(
          status: page.isEmpty
              ? CatalogLoadStatus.empty
              : CatalogLoadStatus.data,
          items: [
            for (final r in page)
              CatalogEntity(
                uuid: r.uuid,
                title: (r.value['name'] ?? r.value['display_name'] ?? r.uuid)
                    .toString(),
                subtitle: r.value['email']?.toString(),
                value: r.uuid,
              ),
          ],
          nextCursor: offset + page.length < all.length
              ? '${offset + page.length}'
              : null,
          totalCount: all.length,
          error: state.error,
        ),
      );
    } catch (error) {
      out.add(CatalogSnapshot(status: CatalogLoadStatus.error, error: error));
    }
  }

  @override
  Future<void> refresh(CatalogQuery query) async {
    final controller = _streams[_key(query)];
    if (controller != null) await _read(query, controller);
  }

  @override
  Future<void> loadNext(CatalogQuery query) => refresh(query);
}

final class RuntimeProductCatalogRepository
    implements CatalogRepository<SaleCatalogProduct> {
  RuntimeProductCatalogRepository({required this.store, required this.scope});
  final LocalCatalogStore<Map<String, dynamic>> store;
  final AppScope scope;
  final _streams =
      <String, StreamController<CatalogSnapshot<SaleCatalogProduct>>>{};
  String _key(CatalogQuery q) => '${q.search}|${q.cursor ?? ''}|${q.pageSize}';
  @override
  Stream<CatalogSnapshot<SaleCatalogProduct>> watch(CatalogQuery query) {
    final controller = _streams.putIfAbsent(
      _key(query),
      () => StreamController.broadcast(),
    );
    unawaited(_read(query, controller));
    return controller.stream;
  }

  Future<void> _read(
    CatalogQuery query,
    StreamController<CatalogSnapshot<SaleCatalogProduct>> out,
  ) async {
    try {
      final state = await store.read(scope);
      final all = state.records
          .map(
            (record) => (record.uuid, SaleCatalogProduct.fromMap(record.value)),
          )
          .where(
            (item) =>
                item.$2.name.toLowerCase().contains(query.search.toLowerCase()),
          )
          .toList();
      final offset = int.tryParse(query.cursor ?? '') ?? 0;
      final page = all.skip(offset).take(query.pageSize).toList();
      out.add(
        CatalogSnapshot(
          status: page.isEmpty
              ? CatalogLoadStatus.empty
              : CatalogLoadStatus.data,
          items: [
            for (final item in page)
              CatalogEntity(uuid: item.$1, title: item.$2.name, value: item.$2),
          ],
          nextCursor: offset + page.length < all.length
              ? '${offset + page.length}'
              : null,
          totalCount: all.length,
          error: state.error,
        ),
      );
    } catch (error) {
      out.add(CatalogSnapshot(status: CatalogLoadStatus.error, error: error));
    }
  }

  @override
  Future<void> refresh(CatalogQuery query) async {
    final controller = _streams[_key(query)];
    if (controller != null) await _read(query, controller);
  }

  @override
  Future<void> loadNext(CatalogQuery query) => refresh(query);
}

final class RuntimePartnerCatalogRepository
    implements CatalogRepository<SaleCatalogPartner> {
  RuntimePartnerCatalogRepository({required this.store, required this.scope});
  final LocalCatalogStore<Map<String, dynamic>> store;
  final AppScope scope;
  final _base = <String, RuntimeScopeCatalogRepository>{};
  RuntimeScopeCatalogRepository get _repository => _base.putIfAbsent(
    scope.scopeKey,
    () => RuntimeScopeCatalogRepository(store: store, scope: scope),
  );
  @override
  Stream<CatalogSnapshot<SaleCatalogPartner>> watch(CatalogQuery query) async* {
    await for (final snapshot in _repository.watch(query)) {
      yield CatalogSnapshot(
        status: snapshot.status,
        nextCursor: snapshot.nextCursor,
        totalCount: snapshot.totalCount,
        error: snapshot.error,
        items: [
          for (final item in snapshot.items)
            CatalogEntity(
              uuid: item.uuid,
              title: item.title,
              subtitle: item.subtitle,
              value: SaleCatalogPartner.fromMap({
                'id': int.tryParse(item.uuid),
                'name': item.title,
                'email': item.subtitle,
              }),
            ),
        ],
      );
    }
  }

  @override
  Future<void> refresh(CatalogQuery query) => _repository.refresh(query);
  @override
  Future<void> loadNext(CatalogQuery query) => _repository.loadNext(query);
}

final class RuntimeSaleCatalogPort implements SaleCatalogPort {
  RuntimeSaleCatalogPort({required this.store, required this.scope});
  final LocalCatalogStore<Map<String, dynamic>> store;
  final AppScope scope;
  @override
  Future<List<SalePaymentTerm>> paymentTerms() async {
    final state = await store.read(scope);
    return [
      for (final record in state.records)
        SalePaymentTerm(
          id: (record.value['id'] as num?)?.toInt() ?? 0,
          label: (record.value['name'] ?? record.uuid).toString(),
          installments: [
            PaymentTermInstallment(
              dueDays: (record.value['due_days'] as num?)?.toInt() ?? 0,
            ),
          ],
        ),
    ];
  }
}
