import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../bindings/record_view_controller.dart';
import 'orbi_record_list.dart';

/// Adaptive record surface: Syncfusion's grid on wide windows and the same
/// controller rendered by [OrbiRecordList] below 840 logical pixels.
///
/// The first grid cell carries the stable record ID. It is an implementation
/// detail and is not shown; selection callbacks therefore survive sorting,
/// refresh and layout changes without depending on row indexes.
class OrbiRecordGrid<T> extends StatefulWidget {
  const OrbiRecordGrid({
    super.key,
    required this.controller,
    required this.columns,
    this.onRecordTap,
    this.cardBuilder,
    this.allowMultiSelect = false,
    this.headerRowHeight = 48,
    this.rowHeight = 52,
  });

  final OrbiRecordViewController<T> controller;
  final List<OrbiRecordColumn<T>> columns;
  final ValueChanged<OrbiRecord<T>>? onRecordTap;
  final Widget Function(BuildContext, OrbiRecord<T>)? cardBuilder;
  final bool allowMultiSelect;
  final double headerRowHeight;
  final double rowHeight;

  @override
  State<OrbiRecordGrid<T>> createState() => _OrbiRecordGridState<T>();
}

class _OrbiRecordGridState<T> extends State<OrbiRecordGrid<T>> {
  late final DataGridController _gridController;
  late final _OrbiDataSource<T> _source;
  bool _syncingSelection = false;

  @override
  void initState() {
    super.initState();
    _gridController = DataGridController();
    _source = _OrbiDataSource<T>(
      records: widget.controller.records,
      columns: widget.columns,
      selectedIds: widget.controller.selectedIds,
      idOf: widget.controller.idFor,
    );
    _syncGridSelection();
    widget.controller.recordsListenable.addListener(_onControllerChanged);
    widget.controller.selectedIdsListenable.addListener(_onControllerChanged);
  }

  @override
  void didUpdateWidget(covariant OrbiRecordGrid<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.recordsListenable.removeListener(
        _onControllerChanged,
      );
      oldWidget.controller.selectedIdsListenable.removeListener(
        _onControllerChanged,
      );
      widget.controller.recordsListenable.addListener(_onControllerChanged);
      widget.controller.selectedIdsListenable.addListener(_onControllerChanged);
    }
    _source.updateColumns(widget.columns);
    _onControllerChanged();
  }

  void _onControllerChanged() {
    _source.update(
      records: widget.controller.records,
      selectedIds: widget.controller.selectedIds,
      idOf: widget.controller.idFor,
    );
    _syncGridSelection();
    if (mounted) setState(() {});
  }

  void _syncGridSelection() {
    final rows = _source.effectiveRows.where((row) {
      final id = _rowId(row);
      return id != null && widget.controller.isSelected(id);
    }).toList();
    _syncingSelection = true;
    _gridController.selectedRows = rows;
    _gridController.selectedRow = rows.isEmpty ? null : rows.first;
    _syncingSelection = false;
  }

  @override
  void dispose() {
    widget.controller.recordsListenable.removeListener(_onControllerChanged);
    widget.controller.selectedIdsListenable.removeListener(
      _onControllerChanged,
    );
    _source.dispose();
    _gridController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // A portrait tablet can exceed the nominal width breakpoint while
        // still needing a vertical detail flow instead of compressed columns.
        final window = MediaQuery.sizeOf(context);
        final portraitTablet =
            window.height > window.width && constraints.maxWidth < 1200;
        if (constraints.maxWidth < 840 || portraitTablet) {
          return OrbiRecordList<T>(
            controller: widget.controller,
            columns: widget.columns,
            onRecordTap: widget.onRecordTap,
            cardBuilder: widget.cardBuilder,
          );
        }
        return SfDataGrid(
          source: _source,
          controller: _gridController,
          columnWidthMode: ColumnWidthMode.fill,
          headerRowHeight: widget.headerRowHeight,
          rowHeight: widget.rowHeight,
          selectionMode: widget.allowMultiSelect
              ? SelectionMode.multiple
              : SelectionMode.single,
          onSelectionChanged: (added, removed) {
            if (_syncingSelection) return;
            for (final row in removed) {
              final id = _rowId(row);
              if (id != null && widget.controller.isSelected(id)) {
                widget.controller.toggle(id);
              }
            }
            for (final row in added) {
              final id = _rowId(row);
              if (id != null) {
                widget.controller.select(id, extend: widget.allowMultiSelect);
              }
            }
          },
          columns: [
            // Internal identity column. Keeping it in the source makes
            // row selection independent from the visible column order.
            GridColumn(
              columnName: '__orbi_id',
              visible: false,
              width: 0,
              label: const SizedBox.shrink(),
            ),
            for (final column in widget.columns)
              GridColumn(
                columnName: column.id ?? column.label,
                width: column.width ?? double.nan,
                label: Container(
                  alignment: Alignment.centerLeft,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    column.label,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ),
              ),
          ],
          onCellTap: (details) {
            if (details.rowColumnIndex.rowIndex == 0) return;
            final index = details.rowColumnIndex.rowIndex - 1;
            if (index >= 0 && index < _source.effectiveRows.length) {
              final row = _source.effectiveRows[index];
              final id = _rowId(row);
              OrbiRecord<T>? record;
              for (final item in widget.controller.records) {
                if (id != null && widget.controller.idFor(item) == id) {
                  record = item;
                  break;
                }
              }
              if (record != null && id != null) {
                widget.controller.select(id, extend: widget.allowMultiSelect);
                widget.onRecordTap?.call(record);
              }
            }
          },
        );
      },
    );
  }
}

String? _rowId(DataGridRow row) {
  final cells = row.getCells();
  if (cells.isEmpty) return null;
  final value = cells.first.value;
  return value is String ? value : null;
}

class _OrbiDataSource<T> extends DataGridSource {
  _OrbiDataSource({
    required List<OrbiRecord<T>> records,
    required this.columns,
    required this.selectedIds,
    required String Function(OrbiRecord<T>) idOf,
  }) : _rows = [
         for (final record in records)
           DataGridRow(
             cells: [
               DataGridCell<String>(
                 columnName: '__orbi_id',
                 value: idOf(record),
               ),
               for (final column in columns)
                 DataGridCell<String>(
                   columnName: column.id ?? column.label,
                   value: column.value(record.value),
                 ),
             ],
           ),
       ];

  List<OrbiRecordColumn<T>> columns;
  List<DataGridRow> _rows;
  Set<String> selectedIds;

  void updateColumns(List<OrbiRecordColumn<T>> nextColumns) {
    columns = List<OrbiRecordColumn<T>>.unmodifiable(nextColumns);
  }

  void update({
    required List<OrbiRecord<T>> records,
    required Set<String> selectedIds,
    required String Function(OrbiRecord<T>) idOf,
  }) {
    _rows = [
      for (final record in records)
        DataGridRow(
          cells: [
            DataGridCell<String>(columnName: '__orbi_id', value: idOf(record)),
            for (final column in columns)
              DataGridCell<String>(
                columnName: column.id ?? column.label,
                value: column.value(record.value),
              ),
          ],
        ),
    ];
    this.selectedIds = selectedIds;
    notifyListeners();
  }

  @override
  List<DataGridRow> get rows => _rows;

  @override
  DataGridRowAdapter buildRow(DataGridRow row) {
    final id = _rowId(row);
    final selected = id != null && selectedIds.contains(id);
    return DataGridRowAdapter(
      color: selected ? null : Colors.transparent,
      cells: row.getCells().map((cell) {
        if (cell.columnName == '__orbi_id') {
          return const SizedBox.shrink();
        }
        final column = columns.firstWhere(
          (item) => (item.id ?? item.label) == cell.columnName,
          orElse: () => columns.first,
        );
        return Container(
          alignment: switch (column.textAlign) {
            TextAlign.end => Alignment.centerRight,
            TextAlign.center => Alignment.center,
            _ => Alignment.centerLeft,
          },
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(cell.value?.toString() ?? ''),
        );
      }).toList(),
    );
  }
}
