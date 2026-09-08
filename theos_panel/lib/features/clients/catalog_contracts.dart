// The repository is intentionally private/injected; it is not a public field
// parameter and therefore cannot use an initializing formal.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';

int _positivePageSize(int value) {
  if (value <= 0) {
    throw ArgumentError.value(value, 'pageSize', 'Must be positive');
  }
  return value;
}

enum CatalogLoadStatus { initial, loading, data, empty, error }

final class CatalogQuery {
  CatalogQuery({String search = '', int pageSize = 25, String? cursor})
    : search = search.trim(),
      pageSize = _positivePageSize(pageSize),
      cursor = cursor == null || cursor.trim().isEmpty ? null : cursor.trim();

  final String search;
  final int pageSize;
  final String? cursor;

  CatalogQuery copyWith({
    String? search,
    int? pageSize,
    String? cursor,
    bool clearCursor = false,
  }) => CatalogQuery(
    search: search ?? this.search,
    pageSize: pageSize ?? this.pageSize,
    cursor: clearCursor ? null : cursor ?? this.cursor,
  );
}

final class CatalogEntity<T> {
  const CatalogEntity({
    required this.uuid,
    required this.title,
    this.subtitle,
    this.value,
  });

  final String uuid;
  final String title;
  final String? subtitle;
  final T? value;
}

final class CatalogPage<T> {
  CatalogPage({
    required List<CatalogEntity<T>> items,
    this.nextCursor,
    this.totalCount,
  }) : items = List.unmodifiable(items);

  final List<CatalogEntity<T>> items;
  final String? nextCursor;
  final int? totalCount;
}

final class CatalogSnapshot<T> {
  CatalogSnapshot({
    this.status = CatalogLoadStatus.initial,
    List<CatalogEntity<T>> items = const [],
    this.nextCursor,
    this.totalCount,
    this.error,
  }) : items = List.unmodifiable(items);

  final CatalogLoadStatus status;
  final List<CatalogEntity<T>> items;
  final String? nextCursor;
  final int? totalCount;
  final Object? error;
}

/// Local query boundary. Implementations own durable records and publish only
/// after their local transaction; UI never calls Odoo or owns persistence.
abstract interface class CatalogRepository<T> {
  Stream<CatalogSnapshot<T>> watch(CatalogQuery query);
  Future<void> refresh(CatalogQuery query);
  Future<void> loadNext(CatalogQuery query);
}

final class CatalogController<T> {
  CatalogController({required CatalogRepository<T> repository})
    : _repository = repository {
    _subscribe();
  }

  final CatalogRepository<T> _repository;
  CatalogQuery _query = CatalogQuery();
  StreamSubscription<CatalogSnapshot<T>>? _subscription;
  CatalogSnapshot<T> _snapshot = CatalogSnapshot<T>();
  CatalogEntity<T>? _selected;
  String _draft = '';
  final _changes = StreamController<CatalogSnapshot<T>>.broadcast();
  int _epoch = 0;

  CatalogQuery get query => _query;
  CatalogSnapshot<T> get snapshot => _snapshot;
  CatalogEntity<T>? get selected => _selected;
  String get draft => _draft;
  Stream<CatalogSnapshot<T>> get changes => _changes.stream;

  void setSearch(String value) {
    final next = _query.copyWith(search: value, clearCursor: true);
    if (next.search == _query.search) return;
    _query = next;
    _subscribe();
  }

  void setDraft(String value) {
    _draft = value;
    _publish();
  }

  void select(CatalogEntity<T>? entity) {
    _selected = entity;
    _publish();
  }

  Future<void> refresh() => _repository.refresh(_query);

  Future<void> loadNext() {
    if (_snapshot.nextCursor == null) return Future<void>.value();
    _query = _query.copyWith(cursor: _snapshot.nextCursor);
    return _repository.loadNext(_query);
  }

  void _subscribe() {
    final epoch = ++_epoch;
    final old = _subscription;
    _subscription = null;
    old?.cancel();
    _snapshot = CatalogSnapshot<T>(status: CatalogLoadStatus.loading);
    _publish();
    _subscription = _repository.watch(_query).listen((value) {
      if (epoch != _epoch) return;
      _snapshot = value;
      _publish();
    });
  }

  void _publish() {
    if (!_changes.isClosed) _changes.add(_snapshot);
  }

  Future<void> dispose() async {
    _epoch++;
    await _subscription?.cancel();
    await _changes.close();
  }
}
