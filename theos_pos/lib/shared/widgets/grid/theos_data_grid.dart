import 'dart:convert';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';
import 'package:syncfusion_flutter_datagrid_export/export.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../utils/web_download.dart' as web_download;

import 'theos_data_grid_source.dart';

/// A standardized DataGrid widget for Theos POS.
/// Wraps [SfDataGrid] with standard styling, paging, and export capabilities.
/// Supports persistent column widths.
class TheosDataGrid extends StatefulWidget {
  final GlobalKey<SfDataGridState>? gridKey;
  final DataGridSource source;
  final List<GridColumn> columns;
  final void Function(DataGridCellTapDetails)? onCellTap;
  final bool allowSorting;
  final bool allowMultiColumnSorting;
  final bool allowColumnsResizing;
  final ColumnWidthMode columnWidthMode;
  final SelectionMode selectionMode;
  final GridNavigationMode navigationMode;
  final double headerRowHeight;
  final bool showSortNumbers;

  // Paging
  final bool showPager;
  final int rowsPerPage;
  final VoidCallback? onExport;

  // Storage key for persisting column widths
  final String? storageKey;

  const TheosDataGrid({
    super.key,
    this.gridKey,
    required this.source,
    required this.columns,
    this.onCellTap,
    this.allowSorting = true,
    this.allowMultiColumnSorting = true,
    this.allowColumnsResizing = true,
    this.columnWidthMode = ColumnWidthMode.none,
    this.selectionMode = SelectionMode.single,
    this.navigationMode = GridNavigationMode.cell,
    this.headerRowHeight = 48,
    this.showSortNumbers = false,
    this.showPager = false,
    this.rowsPerPage = 80,
    this.onExport,
    this.storageKey,
  });

  @override
  State<TheosDataGrid> createState() => _TheosDataGridState();

  /// Exports the grid data to Excel
  Future<void> exportToExcel(String fileName) async {
    if (gridKey?.currentState == null) return;

    final workbook = gridKey!.currentState!.exportToExcelWorkbook();
    final List<int> bytes = workbook.saveAsStream();
    workbook.dispose();

    await web_download.shareFile(bytes, '$fileName.xlsx', text: 'Exported Excel File');
  }

  /// Helper to create a standard header label
  static Widget buildHeaderLabel(
    String label,
    BuildContext context, {
    AlignmentGeometry alignment = Alignment.centerLeft,
  }) {
    final theme = FluentTheme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final headerTextColor = isDark ? Colors.white : Colors.black;

    return Container(
      padding: const EdgeInsets.all(8.0),
      alignment: alignment,
      child: Text(
        label,
        style: TextStyle(fontWeight: FontWeight.bold, color: headerTextColor),
      ),
    );
  }
}

class _TheosDataGridState extends State<TheosDataGrid> {
  Map<String, double> _columnWidths = {};
  List<SortColumnDetails>? _savedSortColumns;
  bool _sortingApplied = false;

  @override
  void initState() {
    super.initState();
    _loadPersistedState();
  }

  Future<void> _loadPersistedState() async {
    await _loadColumnWidths();
    await _loadSorting();
    _setupSortingCallback();
  }

  /// Setup sorting callback on the data source if it's a TheosDataGridSource
  void _setupSortingCallback() {
    if (widget.storageKey == null) return;

    final source = widget.source;
    if (source is TheosDataGridSource) {
      source.onSortingChanged = _saveSorting;
    }
  }

  Future<void> _loadColumnWidths() async {
    if (widget.storageKey == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'datagrid_columns_${widget.storageKey}';
      final String? widthsJson = prefs.getString(key);

      if (widthsJson != null) {
        final Map<String, dynamic> decoded = json.decode(widthsJson);
        setState(() {
          _columnWidths = decoded.map(
            (k, v) => MapEntry(k, (v as num).toDouble()),
          );
        });
      }
    } catch (e) {
      // Intentionally empty - preferences are non-critical
    }
  }

  Future<void> _saveColumnWidths() async {
    if (widget.storageKey == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'datagrid_columns_${widget.storageKey}';
      final String widthsJson = json.encode(_columnWidths);
      await prefs.setString(key, widthsJson);
    } catch (e) {
      // Intentionally empty - preferences are non-critical
    }
  }

  void _onColumnResizeUpdate(ColumnResizeUpdateDetails details) {
    setState(() {
      _columnWidths[details.column.columnName] = details.width;
    });
    _saveColumnWidths();
  }

  Future<void> _loadSorting() async {
    if (widget.storageKey == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'datagrid_sorting_${widget.storageKey}';
      final String? sortingJson = prefs.getString(key);

      if (sortingJson != null) {
        final List<dynamic> decoded = json.decode(sortingJson);
        setState(() {
          _savedSortColumns = decoded.map((item) {
            return SortColumnDetails(
              name: item['name'] as String,
              sortDirection: item['direction'] == 'ascending'
                  ? DataGridSortDirection.ascending
                  : DataGridSortDirection.descending,
            );
          }).toList();
        });
      }
    } catch (e) {
      // Intentionally empty - preferences are non-critical
    }
  }

  Future<void> _saveSorting(List<SortColumnDetails> sortColumns) async {
    if (widget.storageKey == null) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'datagrid_sorting_${widget.storageKey}';
      final sortingData = sortColumns
          .map(
            (sc) => {
              'name': sc.name,
              'direction': sc.sortDirection == DataGridSortDirection.ascending
                  ? 'ascending'
                  : 'descending',
            },
          )
          .toList();
      await prefs.setString(key, json.encode(sortingData));
    } catch (e) {
      // Intentionally empty - preferences are non-critical
    }
  }

  void _applySavedSorting() {
    if (_sortingApplied ||
        _savedSortColumns == null ||
        _savedSortColumns!.isEmpty) {
      return;
    }

    _sortingApplied = true;
    // Apply saved sorting to the data source
    widget.source.sortedColumns.clear();
    widget.source.sortedColumns.addAll(_savedSortColumns!);
    widget.source.sort();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final accentColor = theme.accentColor;
    final isDark = theme.brightness == Brightness.dark;

    // Standard header color logic
    final headerColor = accentColor
        .defaultBrushFor(theme.brightness)
        .withValues(alpha: 0.2);

    // Apply saved widths to columns, but only if they don't have special width modes
    final columnsWithWidths = widget.columns.map((column) {
      final savedWidth = _columnWidths[column.columnName];
      // Only apply saved width if the column uses none or fitByCellValue mode
      // Don't apply to fill, fitByColumnName, lastColumnFill, etc.
      final shouldApplySavedWidth =
          savedWidth != null &&
          (column.columnWidthMode == ColumnWidthMode.none ||
              column.columnWidthMode == ColumnWidthMode.fitByCellValue);

      if (shouldApplySavedWidth) {
        return GridColumn(
          columnName: column.columnName,
          width: savedWidth,
          minimumWidth: column.minimumWidth,
          maximumWidth: column.maximumWidth,
          columnWidthMode: column.columnWidthMode,
          allowSorting: column.allowSorting,
          label: column.label,
          autoFitPadding: column.autoFitPadding,
        );
      }
      return column;
    }).toList();

    final grid = SfDataGridTheme(
      data: SfDataGridThemeData(
        headerColor: headerColor,
        headerHoverColor: headerColor.withValues(alpha: 0.3),
        selectionColor: accentColor.withValues(alpha: 0.1),
        rowHoverColor: isDark ? Colors.grey[160] : Colors.grey[20],
      ),
      child: Builder(
        builder: (context) {
          // Apply saved sorting after grid is built
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _applySavedSorting();
          });

          return SfDataGrid(
            key: widget.gridKey,
            source: widget.source,
            columns: columnsWithWidths,
            onCellTap: widget.onCellTap,
            allowSorting: widget.allowSorting,
            allowMultiColumnSorting: widget.allowMultiColumnSorting,
            allowColumnsResizing: widget.allowColumnsResizing,
            onColumnResizeUpdate: widget.storageKey != null
                ? (ColumnResizeUpdateDetails details) {
                    _onColumnResizeUpdate(details);
                    return true;
                  }
                : null,
            columnWidthMode: widget.columnWidthMode,
            selectionMode: widget.selectionMode,
            navigationMode: widget.navigationMode,
            headerRowHeight: widget.headerRowHeight,
            showSortNumbers: widget.showSortNumbers,
            gridLinesVisibility: GridLinesVisibility.both,
            headerGridLinesVisibility: GridLinesVisibility.both,
            rowsPerPage: widget.showPager ? widget.rowsPerPage : null,
          );
        },
      ),
    );

    if (!widget.showPager) return grid;

    return Column(
      children: [
        Expanded(child: grid),
        Container(
          decoration: BoxDecoration(
            color: isDark ? Colors.grey[190] : Colors.grey[10],
            border: Border(
              top: BorderSide(
                color: isDark ? Colors.grey[150] : Colors.grey[30],
                width: 1,
              ),
            ),
          ),
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
          child: Row(
            children: [
              Expanded(
                child: SfDataPagerTheme(
                  data: SfDataPagerThemeData(
                    itemTextStyle: TextStyle(
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    selectedItemTextStyle: TextStyle(
                      color: isDark ? Colors.black : Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                    itemColor: Colors.transparent,
                    selectedItemColor: accentColor,
                    disabledItemColor: Colors.transparent,
                    itemBorderRadius: BorderRadius.circular(4),
                    backgroundColor: Colors.transparent,
                  ),
                  child: SfDataPager(
                    delegate: widget.source,
                    pageCount: (widget.source.rows.length / widget.rowsPerPage)
                        .ceil()
                        .toDouble(),
                    direction: Axis.horizontal,
                    visibleItemsCount: 5,
                  ),
                ),
              ),
              if (widget.onExport != null) ...[
                const SizedBox(width: 16),
                Tooltip(
                  message: 'Exportar a Excel',
                  child: IconButton(
                    icon: Icon(
                      FluentIcons.excel_document,
                      color: isDark ? Colors.white : Colors.black,
                    ),
                    onPressed: widget.onExport,
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
