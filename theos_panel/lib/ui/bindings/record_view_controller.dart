import 'package:flutter/widgets.dart';

/// A presentation record. [id] is the identity used when rows are reconciled;
/// it must not be derived from the row's position.
class OrbiRecord<T> {
  const OrbiRecord({required this.id, required this.value, this.revision});

  final String id;
  final T value;
  final Object? revision;
}

/// A small, UI-only controller shared by the wide grid and compact list.
///
/// It deliberately contains no repository, SQL, Odoo, or authorization logic.
/// A scope adapter owns those concerns and calls [replaceRecords] when its
/// observable query changes. Selection is intersected with the new IDs so a
/// refresh cannot select a different record merely because rows moved.
class OrbiRecordViewController<T> extends ChangeNotifier {
  factory OrbiRecordViewController({
    Iterable<OrbiRecord<T>> records = const [],
    String Function(OrbiRecord<T>)? idOf,
  }) {
    final snapshot = List<OrbiRecord<T>>.unmodifiable(records);
    return OrbiRecordViewController<T>._(snapshot, idOf);
  }

  OrbiRecordViewController._(
    List<OrbiRecord<T>> records,
    String Function(OrbiRecord<T>)? idOf,
  ) : _records = records,
      _idOf = idOf ?? ((record) => record.id),
      recordsListenable = ValueNotifier<List<OrbiRecord<T>>>(records),
      selectedIdsListenable = ValueNotifier<Set<String>>(<String>{});

  final String Function(OrbiRecord<T>) _idOf;
  List<OrbiRecord<T>> _records;
  Set<String> _selectedIds = <String>{};

  /// Observable immutable snapshot consumed by either representation.
  final ValueNotifier<List<OrbiRecord<T>>> recordsListenable;

  /// Observable selection snapshot, keyed by stable record IDs.
  final ValueNotifier<Set<String>> selectedIdsListenable;

  List<OrbiRecord<T>> get records => _records;
  Set<String> get selectedIds => Set.unmodifiable(_selectedIds);
  String idFor(OrbiRecord<T> record) => _idOf(record);

  /// Reconciles records by ID while preserving selection for records still
  /// visible. This method is suitable for refresh, pagination and reordering.
  void replaceRecords(Iterable<OrbiRecord<T>> records) {
    final next = List<OrbiRecord<T>>.unmodifiable(records);
    final visible = next.map(_idOf).toSet();
    final nextSelection = _selectedIds.intersection(visible);
    _records = next;
    _setSelection(nextSelection, notify: false);
    recordsListenable.value = next;
    notifyListeners();
  }

  void setRecords(Iterable<OrbiRecord<T>> records) => replaceRecords(records);

  void select(String id, {bool extend = false}) {
    if (!_records.any((record) => _idOf(record) == id)) return;
    final next = extend ? {..._selectedIds, id} : <String>{id};
    _setSelection(next);
  }

  void selectId(String id, {bool extend = false}) => select(id, extend: extend);

  void toggle(String id) {
    if (_selectedIds.contains(id)) {
      _setSelection({..._selectedIds}..remove(id));
    } else {
      select(id, extend: true);
    }
  }

  void clearSelection() => _setSelection(<String>{});

  bool isSelected(String id) => _selectedIds.contains(id);

  void _setSelection(Set<String> value, {bool notify = true}) {
    _selectedIds = Set.unmodifiable(value);
    selectedIdsListenable.value = Set.unmodifiable(_selectedIds);
    if (notify) notifyListeners();
  }

  @override
  void dispose() {
    recordsListenable.dispose();
    selectedIdsListenable.dispose();
    super.dispose();
  }
}

/// Typed column definition shared by [OrbiRecordGrid] and [OrbiRecordList].
class OrbiRecordColumn<T> {
  const OrbiRecordColumn({
    required this.label,
    required this.value,
    this.id,
    this.width,
    this.textAlign = TextAlign.start,
  });

  final String label;
  final String? id;
  final String Function(T value) value;
  final double? width;
  final TextAlign textAlign;
}
