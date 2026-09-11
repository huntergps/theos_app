import 'dart:async';

import 'package:orbi_runtime/orbi_runtime.dart';

import '../features/clients/catalog_contracts.dart';
import '../features/sales/sale_editor.dart';

/// Bridges durable, scope-bound catalog state to the UI query contract.
///
/// Every query listens to [LocalCatalogStore.watch], which publishes only
/// after the store's local transaction.  The repository owns those listeners
/// and closes them from [dispose] when its session composition is retired.
final class RuntimeScopeCatalogRepository implements CatalogRepository<String> {
  RuntimeScopeCatalogRepository({required this.store, required this.scope});
  final LocalCatalogStore<Map<String, dynamic>> store;
  final AppScope scope;
  final _channels = <String, _CatalogChannel<String>>{};
  bool _disposed = false;

  String _key(CatalogQuery q) => '${q.search}|${q.cursor ?? ''}|${q.pageSize}';

  @override
  Stream<CatalogSnapshot<String>> watch(CatalogQuery query) {
    _checkOpen();
    final channel = _channels.putIfAbsent(
      _key(query),
      () => _CatalogChannel<String>(
        map: (state) => _mapState(query, state),
        subscribe: (emit, onError, onDone) =>
            store.watch(scope).listen(emit, onError: onError, onDone: onDone),
        read: () => store.read(scope),
      ),
    );
    return channel.streamFor();
  }

  CatalogSnapshot<String> _mapState(
    CatalogQuery query,
    CatalogState<Map<String, dynamic>> state,
  ) {
    final all = state.records
        .where(
          (record) => record.value.values.any(
            (value) =>
                '$value'.toLowerCase().contains(query.search.toLowerCase()),
          ),
        )
        .toList(growable: false);
    final offset = int.tryParse(query.cursor ?? '') ?? 0;
    final page = all.skip(offset).take(query.pageSize).toList(growable: false);
    return CatalogSnapshot(
      status: page.isEmpty ? CatalogLoadStatus.empty : CatalogLoadStatus.data,
      items: [
        for (final record in page)
          CatalogEntity(
            uuid: record.uuid,
            title:
                (record.value['name'] ??
                        record.value['display_name'] ??
                        record.uuid)
                    .toString(),
            subtitle: record.value['email']?.toString(),
            value: record.uuid,
          ),
      ],
      nextCursor: offset + page.length < all.length
          ? '${offset + page.length}'
          : null,
      totalCount: all.length,
      error: state.error,
    );
  }

  @override
  Future<void> refresh(CatalogQuery query) async {
    final channel = _channels[_key(query)];
    if (channel != null) await channel.refresh();
  }

  @override
  Future<void> loadNext(CatalogQuery query) => refresh(query);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final channels = _channels.values.toList(growable: false);
    _channels.clear();
    for (final channel in channels) {
      await channel.dispose();
    }
  }

  void _checkOpen() {
    if (_disposed) throw StateError('Catalog repository is disposed');
  }
}

final class RuntimeProductCatalogRepository
    implements CatalogRepository<SaleCatalogProduct> {
  RuntimeProductCatalogRepository({required this.store, required this.scope});
  final LocalCatalogStore<Map<String, dynamic>> store;
  final AppScope scope;
  final _channels = <String, _CatalogChannel<SaleCatalogProduct>>{};
  bool _disposed = false;

  String _key(CatalogQuery q) => '${q.search}|${q.cursor ?? ''}|${q.pageSize}';

  @override
  Stream<CatalogSnapshot<SaleCatalogProduct>> watch(CatalogQuery query) {
    _checkOpen();
    final channel = _channels.putIfAbsent(
      _key(query),
      () => _CatalogChannel<SaleCatalogProduct>(
        map: _mapState(query),
        subscribe: (emit, onError, onDone) =>
            store.watch(scope).listen(emit, onError: onError, onDone: onDone),
        read: () => store.read(scope),
      ),
    );
    return channel.streamFor();
  }

  CatalogSnapshot<SaleCatalogProduct> Function(
    CatalogState<Map<String, dynamic>>,
  )
  _mapState(CatalogQuery query) => (state) {
    try {
      final all = state.records
          .map(
            (record) => (record.uuid, SaleCatalogProduct.fromMap(record.value)),
          )
          .where(
            (item) =>
                item.$2.name.toLowerCase().contains(query.search.toLowerCase()),
          )
          .toList(growable: false);
      final offset = int.tryParse(query.cursor ?? '') ?? 0;
      final page = all
          .skip(offset)
          .take(query.pageSize)
          .toList(growable: false);
      return CatalogSnapshot(
        status: page.isEmpty ? CatalogLoadStatus.empty : CatalogLoadStatus.data,
        items: [
          for (final item in page)
            CatalogEntity(uuid: item.$1, title: item.$2.name, value: item.$2),
        ],
        nextCursor: offset + page.length < all.length
            ? '${offset + page.length}'
            : null,
        totalCount: all.length,
        error: state.error,
      );
    } catch (error) {
      return CatalogSnapshot(status: CatalogLoadStatus.error, error: error);
    }
  };

  @override
  Future<void> refresh(CatalogQuery query) async {
    final channel = _channels[_key(query)];
    if (channel != null) await channel.refresh();
  }

  @override
  Future<void> loadNext(CatalogQuery query) => refresh(query);

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    final channels = _channels.values.toList(growable: false);
    _channels.clear();
    for (final channel in channels) {
      await channel.dispose();
    }
  }

  void _checkOpen() {
    if (_disposed) throw StateError('Catalog repository is disposed');
  }
}

final class RuntimePartnerCatalogRepository
    implements CatalogRepository<SaleCatalogPartner> {
  RuntimePartnerCatalogRepository({required this.store, required this.scope});
  final LocalCatalogStore<Map<String, dynamic>> store;
  final AppScope scope;
  late final RuntimeScopeCatalogRepository _repository =
      RuntimeScopeCatalogRepository(store: store, scope: scope);

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
  Future<void> dispose() => _repository.dispose();
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

/// Query-local lifecycle adapter; it maps every store emission to one UI
/// snapshot and never owns or deletes durable catalog data.
final class _CatalogChannel<T> {
  _CatalogChannel({
    required this.map,
    required this.subscribe,
    required this.read,
  });
  final CatalogSnapshot<T> Function(CatalogState<Map<String, dynamic>>) map;
  final StreamSubscription<CatalogState<Map<String, dynamic>>> Function(
    void Function(CatalogState<Map<String, dynamic>>) emit,
    void Function(Object error, StackTrace stack) onError,
    void Function() onDone,
  )
  subscribe;
  final Future<CatalogState<Map<String, dynamic>>> Function() read;
  final _events = StreamController<CatalogSnapshot<T>>.broadcast();
  StreamSubscription<CatalogState<Map<String, dynamic>>>? _subscription;
  CatalogSnapshot<T>? _latest;
  int _listeners = 0;
  bool _disposed = false;
  Future<void>? _stopping;

  Stream<CatalogSnapshot<T>> streamFor() {
    return Stream.multi((multi) {
      if (_disposed) {
        multi.addError(StateError('Catalog channel is disposed'));
        multi.close();
        return;
      }
      _listeners++;
      if (_latest != null) multi.add(_latest!);
      final forwarding = _events.stream.listen(
        multi.add,
        onError: multi.addError,
        onDone: multi.close,
      );
      unawaited(_attach());
      multi.onCancel = () async {
        await forwarding.cancel();
        _listeners--;
        if (_listeners == 0) {
          final subscription = _subscription;
          if (subscription != null) {
            // Detach the cancelled handle before awaiting it. A new listener
            // may arrive during cancellation and must wait for `_stopping`
            // before installing a fresh store subscription.
            _subscription = null;
            final stopping = subscription.cancel();
            _stopping = stopping;
            await stopping;
            if (identical(_stopping, stopping)) _stopping = null;
          }
        }
      };
    }, isBroadcast: true);
  }

  Future<void> _attach() async {
    final stopping = _stopping;
    if (stopping != null) await stopping;
    if (_disposed || _listeners == 0 || _subscription != null) return;
    _subscription = subscribe(
      _emit,
      (error, stack) {
        if (_disposed) return;
        final snapshot = CatalogSnapshot<T>(
          status: CatalogLoadStatus.error,
          error: error,
        );
        _latest = snapshot;
        if (!_events.isClosed) _events.add(snapshot);
      },
      () {
        if (!_events.isClosed) unawaited(_events.close());
      },
    );
  }

  void _emit(CatalogState<Map<String, dynamic>> state) {
    if (_disposed) return;
    final snapshot = map(state);
    _latest = snapshot;
    if (!_events.isClosed) _events.add(snapshot);
  }

  Future<void> refresh() async {
    try {
      final state = await read();
      _emit(state);
    } catch (error) {
      if (!_disposed) {
        final snapshot = CatalogSnapshot<T>(
          status: CatalogLoadStatus.error,
          error: error,
        );
        _latest = snapshot;
        if (!_events.isClosed) _events.add(snapshot);
      }
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _subscription?.cancel();
    await _events.close();
  }
}
