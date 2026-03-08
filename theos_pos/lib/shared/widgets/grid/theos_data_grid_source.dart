import 'package:fluent_ui/fluent_ui.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

/// A generic DataGridSource implementation for TheosDataGrid.
/// Allows reusing the same source logic for different models.
class TheosDataGridSource<T> extends DataGridSource {
  List<T> _data = [];
  List<DataGridRow> _dataGridRows = [];

  /// Current page index (0-based) for pagination
  int _currentPageIndex = 0;

  /// Rows per page for pagination
  int _rowsPerPage = 80;

  /// Callback to convert a model item into a list of DataGridCells.
  final List<DataGridCell> Function(T item) rowBuilder;

  /// Optional map of column names to cell builder functions.
  /// Use this to provide custom widgets for specific columns (e.g. chips, formatting).
  /// If not provided for a column, a default Text widget is used.
  final Map<String, Widget Function(BuildContext context, DataGridCell cell)>?
  cellBuilders;

  /// Callback fired after sorting is performed
  void Function(List<SortColumnDetails>)? onSortingChanged;

  TheosDataGridSource({
    required List<T> data,
    required this.rowBuilder,
    this.cellBuilders,
    this.onSortingChanged,
  }) {
    updateData(data);
  }

  /// Set the rows per page for pagination calculations
  void setRowsPerPage(int rowsPerPage) {
    _rowsPerPage = rowsPerPage;
  }

  /// Updates the data source with a new list of items.
  void updateData(List<T> data) {
    _data = data;
    _buildDataGridRows();
    notifyListeners();
  }

  /// Returns the current list of items.
  List<T> get data => _data;

  final Map<DataGridRow, T> _rowMap = {};

  /// Returns the item corresponding to the visual row index on the current page
  ///
  /// This accounts for:
  /// - Current page offset (for pagination)
  /// - Current sort order
  T? getItem(int visualRowIndex) {
    // Calculate absolute index accounting for pagination
    final absoluteIndex = (_currentPageIndex * _rowsPerPage) + visualRowIndex;

    if (absoluteIndex < 0 || absoluteIndex >= _dataGridRows.length) return null;
    final row = _dataGridRows[absoluteIndex];
    return _rowMap[row];
  }

  @override
  Future<bool> handlePageChange(int oldPageIndex, int newPageIndex) async {
    _currentPageIndex = newPageIndex;
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

  @override
  List<DataGridRow> get rows => _dataGridRows;

  @override
  Future<void> performSorting(List<DataGridRow> rows) async {
    if (sortedColumns.isEmpty) return;

    for (final sortColumn in sortedColumns.reversed) {
      rows.sort((a, b) {
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

    // IMPORTANT: Update _dataGridRows with the sorted order so getItem() works correctly
    _dataGridRows = List.from(rows);

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
