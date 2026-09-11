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
            (record) => (
              record.uuid,
              SaleCatalogProduct.fromMap(_productValue(record)),
            ),
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

  static Map<String, dynamic> _productValue(
    CatalogRecord<Map<String, dynamic>> record,
  ) {
    final raw = record.value;
    final explicitRemote = raw['remoteId'] ?? raw['odooId'];
    final legacyId = raw['id'];
    final remoteId = explicitRemote ?? (legacyId is int ? legacyId : null);
    if (explicitRemote != null &&
        (explicitRemote is! int || explicitRemote <= 0)) {
      throw const FormatException('product requires a positive remote id');
    }
    if (legacyId != null && legacyId is! int && raw['localId'] == null) {
      throw const FormatException('product id');
    }
    final value = <String, dynamic>{...raw, 'localId': record.uuid};
    if (remoteId != null) value['remoteId'] = remoteId;
    final price = raw['price'] ?? raw['list_price'];
    if (price != null) {
      if (price is! num || !price.isFinite) {
        throw const FormatException('product price');
      }
      value['price'] = price;
    }
    final uom = raw['uomId'] ?? raw['uom_id'];
    if (uom != null) {
      if (uom is int) {
        if (uom <= 0) throw const FormatException('product uom');
        value['uomId'] = uom;
      } else if (uom is! List ||
          uom.isEmpty ||
          uom.first is! int ||
          uom.first <= 0) {
        throw const FormatException('product uom');
      } else {
        value['uomId'] = uom.first;
        if (uom.length > 1) {
          if (uom[1] is! String) {
            throw const FormatException('product uom name');
          }
          value['uomName'] = uom[1];
        }
      }
    }
    final taxes = raw['taxIds'] ?? raw['taxes_id'];
    if (taxes != null) {
      if (taxes is! List || taxes.any((tax) => tax is! int || tax <= 0)) {
        throw const FormatException('product taxes');
      }
      value['taxIds'] = taxes;
    }
    return value;
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

final class RuntimePartnerCatalogRepository
    implements CatalogRepository<SaleCatalogPartner> {
  RuntimePartnerCatalogRepository({required this.store, required this.scope});
  final LocalCatalogStore<Map<String, dynamic>> store;
  final AppScope scope;
  final _channels = <String, _CatalogChannel<SaleCatalogPartner>>{};
  bool _disposed = false;

  @override
  Stream<CatalogSnapshot<SaleCatalogPartner>> watch(CatalogQuery query) async* {
    if (_disposed) throw StateError('Catalog repository is disposed');
    final channel = _channels.putIfAbsent(
      _key(query),
      () => _CatalogChannel<SaleCatalogPartner>(
        map: _mapState(query),
        subscribe: (emit, onError, onDone) =>
            store.watch(scope).listen(emit, onError: onError, onDone: onDone),
        read: () => store.read(scope),
      ),
    );
    yield* channel.streamFor();
  }

  CatalogSnapshot<SaleCatalogPartner> Function(
    CatalogState<Map<String, dynamic>>,
  )
  _mapState(CatalogQuery query) => (state) {
    try {
      final all = state.records
          .map((record) {
            final id = record.value['id'];
            if (id is! int || id <= 0) {
              throw const FormatException('partner requires a positive id');
            }
            final name = record.value['name'] ?? record.value['display_name'];
            if (name is! String || name.trim().isEmpty) {
              throw const FormatException('partner requires a non-empty name');
            }
            final value = <String, dynamic>{...record.value, 'name': name};
            for (final field in ['vat', 'email']) {
              final fieldValue = value[field];
              if (fieldValue == false) {
                value[field] = null;
              } else if (fieldValue != null && fieldValue is! String) {
                throw FormatException('partner $field');
              }
            }
            final partner = SaleCatalogPartner.fromMap(value);
            return (record.uuid, partner);
          })
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
            CatalogEntity(
              uuid: item.$1,
              title: item.$2.name,
              subtitle: item.$2.email,
              value: item.$2,
            ),
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

  String _key(CatalogQuery q) => '${q.search}|${q.cursor ?? ''}|${q.pageSize}';

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
