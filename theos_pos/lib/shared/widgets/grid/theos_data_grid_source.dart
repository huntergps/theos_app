import 'package:fluent_ui/fluent_ui.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

/// A generic DataGridSource implementation for TheosDataGrid.
/// Allows reusing the same source logic for different models.
class TheosDataGridSource<T> extends DataGridSource {
  List<T> _data = [];
  List<DataGridRow> _dataGridRows = [];
  List<DataGridRow> _visibleRows = [];

  /// Current page index (0-based) for pagination
  int _currentPageIndex = 0;

  /// Rows per page for pagination
  int _rowsPerPage = 80;

  bool _paginationEnabled = false;

  /// Callback to convert a model item into a list of DataGridCells.
  final List<DataGridCell> Function(T item) rowBuilder;

  /// Optional map of column names to cell builder functions.
  /// Use this to provide custom widgets for specific columns (e.g. chips, formatting).
  /// If not provided for a column, a default Text widget is used.
  final Map<String, Widget Function(BuildContext context, DataGridCell cell)>?
  cellBuilders;

  /// Callback fired after sorting is performed
  void Function(List<SortColumnDetails>)? onSortingChanged;

  /// Optional external page loader. When present, rows already represent one
  /// database-backed page and this source must not slice them again.
  Future<bool> Function(int pageIndex)? onExternalPageChange;

  TheosDataGridSource({
    required List<T> data,
    required this.rowBuilder,
    this.cellBuilders,
    this.onSortingChanged,
  }) {
    updateData(data);
  }

  /// Configures whether [rows] exposes a bounded page or the complete source.
  void configurePagination({required bool enabled, required int rowsPerPage}) {
    assert(rowsPerPage > 0, 'rowsPerPage must be positive');
    final changed =
        _paginationEnabled != enabled || _rowsPerPage != rowsPerPage;
    _paginationEnabled = enabled;
    _rowsPerPage = rowsPerPage;
    if (changed) {
      _clampCurrentPage();
      _refreshVisibleRows();
      notifyListeners();
    }
  }

  /// Total number of model rows, independent from the current page.
  int get totalRowCount => _dataGridRows.length;

  /// Current page index, exposed for deterministic tests and pager state.
  int get currentPageIndex => _currentPageIndex;

  /// Updates the data source with a new list of items.
  bool updateData(List<T> data, {bool notify = true}) {
    // Providers may emit a new list instance for an unchanged query. Avoid
    // rebuilding every DataGridRow in that case.
    if (identical(data, _data) ||
        (data.length == _data.length &&
            data.asMap().entries.every(
              (entry) =>
                  identical(entry.value, _data[entry.key]) ||
                  entry.value == _data[entry.key],
            ))) {
      return false;
    }
    _data = data;
    _buildDataGridRows();
    _clampCurrentPage();
    _refreshVisibleRows();
    if (notify) notifyListeners();
    return true;
  }

  /// Notifies a mounted grid after a build-safe batched update.
  void notifyDataChanged() => notifyListeners();

  /// Returns the current list of items.
  List<T> get data => _data;

  final Map<DataGridRow, T> _rowMap = {};

  /// Returns the item corresponding to the visual row index on the current page
  ///
  /// This accounts for:
  /// - Current page offset (for pagination)
  /// - Current sort order
  T? getItem(int visualRowIndex) {
    if (visualRowIndex < 0 || visualRowIndex >= _visibleRows.length) {
      return null;
    }
    final row = _visibleRows[visualRowIndex];
    return _rowMap[row];
  }

  @override
  Future<bool> handlePageChange(int oldPageIndex, int newPageIndex) async {
    final externalPageChange = onExternalPageChange;
    if (externalPageChange != null) {
      final accepted = await externalPageChange(newPageIndex);
      if (accepted) _currentPageIndex = newPageIndex;
      return accepted;
    }
    if (!_paginationEnabled || newPageIndex == _currentPageIndex) {
      return true;
    }
    _currentPageIndex = newPageIndex;
    _clampCurrentPage();
    _refreshVisibleRows();
    notifyListeners();
    return true;
  }

  void _buildDataGridRows() {
    _rowMap.clear();
    _dataGridRows = _data.map<DataGridRow>((item) {
      final row = DataGridRow(cells: rowBuilder(item));
      _rowMap[row] = item;
      return row;
    }).toList();
  }

  void _clampCurrentPage() {
    if (!_paginationEnabled || _dataGridRows.isEmpty) {
      _currentPageIndex = 0;
      return;
    }
    final lastPage = (_dataGridRows.length - 1) ~/ _rowsPerPage;
    if (_currentPageIndex > lastPage) _currentPageIndex = lastPage;
  }

  void _refreshVisibleRows() {
    if (!_paginationEnabled) {
      _visibleRows = List.of(_dataGridRows);
      return;
    }
    final start = _currentPageIndex * _rowsPerPage;
    if (start >= _dataGridRows.length) {
      _visibleRows = [];
      return;
    }
    final end = (start + _rowsPerPage).clamp(0, _dataGridRows.length);
    _visibleRows = _dataGridRows.sublist(start, end);
  }

  @override
  List<DataGridRow> get rows => _visibleRows;

  @override
  Future<void> performSorting(List<DataGridRow> rows) async {
    if (sortedColumns.isEmpty) return;

    for (final sortColumn in sortedColumns.reversed) {
      _dataGridRows.sort((a, b) {
        final cellA = a.getCells().firstWhere(
          (cell) => cell.columnName == sortColumn.name,
          orElse: () => const DataGridCell(columnName: '', value: null),
        );
        final cellB = b.getCells().firstWhere(
          (cell) => cell.columnName == sortColumn.name,
          orElse: () => const DataGridCell(columnName: '', value: null),
        );

        final valueA = _getSortableValue(cellA.value);
        final valueB = _getSortableValue(cellB.value);

        int comparison;
        if (valueA == null && valueB == null) {
          comparison = 0;
        } else if (valueA == null) {
          comparison = -1;
        } else if (valueB == null) {
          comparison = 1;
        } else if (valueA is Comparable && valueB is Comparable) {
          comparison = valueA.compareTo(valueB);
        } else {
          comparison = valueA.toString().compareTo(valueB.toString());
        }

        return sortColumn.sortDirection == DataGridSortDirection.ascending
            ? comparison
            : -comparison;
      });
    }

    _currentPageIndex = 0;
    _refreshVisibleRows();

    // Notify listeners about sorting change
    onSortingChanged?.call(sortedColumns);
  }

  /// Extract a sortable value from complex types like Maps
  dynamic _getSortableValue(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      // For reference column, extract 'name' for sorting
      return value['name'] ?? value.values.firstOrNull;
    }
    return value;
  }

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    return DataGridRowAdapter(
      cells: row.getCells().map<Widget>((cell) {
        // Check if a custom builder exists for this column
        if (cellBuilders != null &&
            cellBuilders!.containsKey(cell.columnName)) {
          return Builder(
            builder: (context) =>
                cellBuilders![cell.columnName]!(context, cell),
          );
        }

        // Default cell rendering
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          alignment: Alignment.centerLeft,
          child: Text(
            cell.value?.toString() ?? '',
            overflow: TextOverflow.ellipsis,
          ),
        );
      }).toList(),
    );
  }
}
