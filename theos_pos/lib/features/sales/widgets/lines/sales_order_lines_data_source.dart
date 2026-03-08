import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';

import '../../../products/services/catalog_service.dart';

import '../editable_number_cell.dart';
import '../editable_text_cell.dart';
import '../editable_cell_type.dart';
import '../../../../shared/utils/formatting_utils.dart';
import '../product_description_cell.dart';
import '../uom_cell.dart';
import '../../../taxes/widgets/tax_badge.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// DataGridSource for sale order lines (shared between edit and view)
class SalesOrderLinesDataSource extends DataGridSource {
  List<SaleOrderLine> lines;
  final Map<String, bool> columnVisibility;
  final bool isEditable;
  final FluentThemeData theme;

  /// Servicio para resolver nombres desde catálogos locales.
  /// Si es null, se usan los nombres embebidos directamente.
  final CatalogService? catalogService;

  // Callbacks (nullable if not editable)
  // onUpdateQty uses Function to support async recalculation with pricelist rules
  final Function(SaleOrderLine line, double qty)? onUpdateQty;
  final void Function(SaleOrderLine line, double price)? onUpdatePrice;
  final void Function(SaleOrderLine line, double discount)? onUpdateDiscount;
  final void Function(SaleOrderLine line, String value)? onUpdateName;

  /// Async callback for product code validation
  /// Returns ProductCodeSearchResult to determine navigation behavior
  final Future<ProductCodeSearchResult> Function(SaleOrderLine line, String code)?
      onUpdateCode;

  /// Callback when Escape is pressed or focus lost on code cell
  /// Used to restore original value or delete empty lines
  final void Function(SaleOrderLine line)? onCodeEscape;
  final void Function(SaleOrderLine line, int uomId, String uomName)?
  onUpdateUom;
  final void Function(SaleOrderLine line)? onDeleteLine;
  final void Function(SaleOrderLine line)? onMoveUp;
  final void Function(SaleOrderLine line)? onMoveDown;
  final void Function(SaleOrderLine line)? onDuplicate;
  final void Function(SaleOrderLine line)? onSelectProduct;
  final void Function(SaleOrderLine line)? onSelectUom;
  final void Function(SaleOrderLine line)? onShowProductInfo;
  final void Function(SaleOrderLine line)? onToggleHidePrices;
  final void Function(SaleOrderLine line)? onToggleHideComposition;
  final void Function(SaleOrderLine line)? onToggleOptional;

  /// Callback para notificar cuando se necesita recalcular alturas de filas
  /// Recibe el ID de la línea, si está expandida, y el número de líneas actual
  final void Function(int lineId, bool isExpanded, int lineCount)?
  onRowHeightChanged;

  /// Callback for Tab navigation between cells
  /// Called when Tab is pressed from qty/discount cell
  /// Returns: true if navigation was handled, false to allow default behavior
  final bool Function(int lineId, EditableCellType cellType)? onTabNext;

  /// Callback for Shift+Tab/Previous navigation between cells
  /// Called when Previous is pressed from qty/discount cell
  /// Returns: true if navigation was handled, false to allow default behavior
  final bool Function(int lineId, EditableCellType cellType)? onTabPrevious;

  /// External registry of FocusNodes for editable cells - persists across rebuilds
  /// Key: "lineId_cellType"
  /// This should be provided by the parent widget (SalesOrderLinesGridState)
  final Map<String, FocusNode> focusNodeRegistry;

  SalesOrderLinesDataSource({
    required this.lines,
    required this.columnVisibility,
    required this.theme,
    this.catalogService,
    this.isEditable = false,
    this.onUpdateQty,
    this.onUpdatePrice,
    this.onUpdateDiscount,
    this.onUpdateName,
    this.onUpdateCode,
    this.onCodeEscape,
    this.onUpdateUom,
    this.onDeleteLine,
    this.onMoveUp,
    this.onMoveDown,
    this.onDuplicate,
    this.onSelectProduct,
    this.onSelectUom,
    this.onShowProductInfo,
    this.onToggleHidePrices,
    this.onToggleHideComposition,
    this.onToggleOptional,
    this.onRowHeightChanged,
    this.onTabNext,
    this.onTabPrevious,
    required this.focusNodeRegistry,
  });

  /// Notifica que la altura de una fila debe recalcularse
  void refreshRowHeight(int lineId, bool isExpanded, int lineCount) {
    notifyListeners();
    onRowHeightChanged?.call(lineId, isExpanded, lineCount);
  }

  /// Actualiza las líneas y notifica a los listeners
  /// Útil cuando las líneas cambian sin recrear el DataSource
  void updateLines(List<SaleOrderLine> newLines) {
    if (lines != newLines) {
      lines = newLines;
      notifyListeners();
    }
  }

  /// Generate key for FocusNode registry
  String _focusKey(int lineId, EditableCellType cellType) =>
      '${lineId}_${cellType.name}';

  /// Register a FocusNode for a cell
  void registerFocusNode(
    int lineId,
    EditableCellType cellType,
    FocusNode node,
  ) {
    final key = _focusKey(lineId, cellType);
    focusNodeRegistry[key] = node;
  }

  /// Unregister a FocusNode for a cell
  /// Only removes if the node matches what's in the registry
  /// This prevents old cells from removing new cells' FocusNodes during grid rebuild
  void unregisterFocusNode(int lineId, EditableCellType cellType, FocusNode node) {
    final key = _focusKey(lineId, cellType);
    final existing = focusNodeRegistry[key];
    // Only remove if it's the same node (prevents old cells from removing new cells' nodes)
    if (existing == node) {
      focusNodeRegistry.remove(key);
    }
  }

  /// Get FocusNode for a specific cell
  FocusNode? getFocusNode(int lineId, EditableCellType cellType) {
    return focusNodeRegistry[_focusKey(lineId, cellType)];
  }

  /// Request focus on a specific cell
  bool requestFocusOnCell(int lineId, EditableCellType cellType) {
    final node = getFocusNode(lineId, cellType);
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      return true;
    }
    return false;
  }

  /// Get the index of a line by its ID
  int getLineIndex(int lineId) {
    return lines.indexWhere((l) => l.id == lineId);
  }

  /// Get the next product line index after the given line
  int? getNextProductLineIndex(int afterLineId) {
    final currentIndex = getLineIndex(afterLineId);
    if (currentIndex == -1) return null;

    for (int i = currentIndex + 1; i < lines.length; i++) {
      if (lines[i].isProductLine) {
        return i;
      }
    }
    return null;
  }

  /// Get the previous product line index before the given line
  int? getPreviousProductLineIndex(int beforeLineId) {
    final currentIndex = getLineIndex(beforeLineId);
    if (currentIndex == -1) return null;

    for (int i = currentIndex - 1; i >= 0; i--) {
      if (lines[i].isProductLine) {
        return i;
      }
    }
    return null;
  }

  /// Check if a line is the first product line
  bool isFirstProductLine(int lineId) {
    final index = getLineIndex(lineId);
    if (index == -1) return false;

    for (int i = index - 1; i >= 0; i--) {
      if (lines[i].isProductLine) {
        return false;
      }
    }
    return true;
  }

  /// Check if a line is the last product line
  bool isLastProductLine(int lineId) {
    final index = getLineIndex(lineId);
    if (index == -1) return false;

    for (int i = index + 1; i < lines.length; i++) {
      if (lines[i].isProductLine) {
        return false;
      }
    }
    return true;
  }

  /// Handle Tab navigation from a cell
  /// Returns true if navigation was handled
  bool handleTabNavigation(int lineId, EditableCellType cellType) {

    // From code -> code on next product line
    if (cellType == EditableCellType.code) {
      final nextIndex = getNextProductLineIndex(lineId);

      if (nextIndex != null) {
        final nextLine = lines[nextIndex];
        final success = requestFocusOnCell(
          nextLine.id,
          EditableCellType.code,
        );
        return success;
      }

      // On last line - let parent handle creating new line
      return onTabNext?.call(lineId, cellType) ?? false;
    }

    // From quantity -> discount on same line
    if (cellType == EditableCellType.quantity) {
      final success = requestFocusOnCell(lineId, EditableCellType.discount);
      return success;
    }

    // From discount -> code on next product line (spreadsheet-like navigation)
    // Flow: Code → Quantity → Discount → Code (next line)
    if (cellType == EditableCellType.discount) {
      final nextIndex = getNextProductLineIndex(lineId);

      if (nextIndex != null) {
        final nextLine = lines[nextIndex];
        final success = requestFocusOnCell(
          nextLine.id,
          EditableCellType.code,
        );
        return success;
      }

      // On last line - let parent handle creating new line
      return onTabNext?.call(lineId, cellType) ?? false;
    }

    return false;
  }

  /// Handle Shift+Tab/Previous navigation from a cell
  /// Returns true if navigation was handled
  ///
  /// Reverse flow: Code ← Quantity ← Discount ← Code (prev line)
  bool handleShiftTabNavigation(int lineId, EditableCellType cellType) {

    // From code -> discount on previous product line
    if (cellType == EditableCellType.code) {
      final prevIndex = getPreviousProductLineIndex(lineId);

      if (prevIndex != null) {
        final prevLine = lines[prevIndex];
        final success = requestFocusOnCell(
          prevLine.id,
          EditableCellType.discount,
        );
        return success;
      }

      // On first line - let parent handle if needed
      return onTabPrevious?.call(lineId, cellType) ?? false;
    }

    // From discount -> quantity on same line
    if (cellType == EditableCellType.discount) {
      final success = requestFocusOnCell(lineId, EditableCellType.quantity);
      return success;
    }

    // From quantity -> code on same line
    if (cellType == EditableCellType.quantity) {
      final success = requestFocusOnCell(lineId, EditableCellType.code);
      return success;
    }

    return false;
  }

  /// Handle Arrow Up navigation - move to same column on previous row
  /// Returns true if navigation was handled
  bool handleArrowUp(int lineId, EditableCellType cellType) {

    final prevIndex = getPreviousProductLineIndex(lineId);
    if (prevIndex != null) {
      final prevLine = lines[prevIndex];
      final success = requestFocusOnCell(prevLine.id, cellType);
      return success;
    }

    return false;
  }

  /// Handle Arrow Down navigation - move to same column on next row
  /// Returns true if navigation was handled
  bool handleArrowDown(int lineId, EditableCellType cellType) {

    final nextIndex = getNextProductLineIndex(lineId);
    if (nextIndex != null) {
      final nextLine = lines[nextIndex];
      final success = requestFocusOnCell(nextLine.id, cellType);
      return success;
    }

    return false;
  }

  /// Check if a column is visible
  bool _isColumnVisible(String columnName) {
    // 'product' is always visible
    if (columnName == 'product') return true;
    // 'actions' visibility depends on isEditable and preference
    if (columnName == 'actions') {
      if (!isEditable) {
        return false; // Hide actions in view mode unless we want view-actions?
      }
      // Actually, View mode might want "Show Info" action?
      // For now, let's hide actions in view mode to match original order_lines_grid.
      return columnVisibility['actions'] ?? true;
    }
    return columnVisibility[columnName] ?? true;
  }

  // ============ Catalog Resolution Helpers ============

  /// Resuelve el nombre del producto desde catálogo local o usa embebido
  String _resolveProductName(SaleOrderLine line) {
    if (catalogService != null) {
      return catalogService!.resolveProductName(
        line.productId,
        line.productName,
      );
    }
    return line.productName ?? line.name.split('\n').first;
  }

  /// Resuelve el código del producto desde catálogo local o usa embebido
  String? _resolveProductCode(SaleOrderLine line) {
    if (catalogService != null) {
      return catalogService!.resolveProductCode(
        line.productId,
        line.productCode,
      );
    }
    return line.productCode;
  }

  /// Resuelve el nombre de UoM desde catálogo local o usa embebido
  String _resolveUomName(SaleOrderLine line) {
    if (catalogService != null) {
      return catalogService!.resolveUomName(
        line.productUomId,
        line.productUomName,
      );
    }
    return line.productUomName ?? 'Unid.';
  }

  /// Resuelve los nombres de impuestos desde catálogo local o usa embebido
  String? _resolveTaxNames(SaleOrderLine line) {
    if (catalogService != null) {
      return catalogService!.resolveTaxNames(line.taxIds, line.taxNames);
    }
    return line.taxNames;
  }

  /// Calculate subtotal for all lines under a section
  double _getSectionSubtotal(SaleOrderLine sectionLine) {
    final sectionIndex = lines.indexOf(sectionLine);
    if (sectionIndex == -1) return 0;

    double subtotal = 0;
    for (int i = sectionIndex + 1; i < lines.length; i++) {
      final line = lines[i];
      // Stop when we hit the next section
      if (line.isSection) break;
      // Add product line subtotals
      if (line.isProductLine) {
        subtotal += line.priceSubtotal;
      }
    }
    return subtotal;
  }

  @override
  List<DataGridRow> get rows => lines.asMap().entries.map((entry) {
    final index = entry.key;
    final line = entry.value;

    // Build cells based on column visibility
    final cells = <DataGridCell>[];

    if (_isColumnVisible('index')) {
      cells.add(DataGridCell<int>(columnName: 'index', value: index + 1));
    }
    if (_isColumnVisible('code')) {
      cells.add(
        DataGridCell<String>(
          columnName: 'code',
          value: _resolveProductCode(line) ?? '',
        ),
      );
    }
    // Product always visible
    cells.add(DataGridCell<SaleOrderLine>(columnName: 'product', value: line));

    if (_isColumnVisible('quantity')) {
      cells.add(
        DataGridCell<SaleOrderLine>(columnName: 'quantity', value: line),
      );
    }
    if (_isColumnVisible('uom')) {
      cells.add(DataGridCell<SaleOrderLine>(columnName: 'uom', value: line));
    }
    if (_isColumnVisible('price_unit')) {
      cells.add(
        DataGridCell<SaleOrderLine>(columnName: 'price_unit', value: line),
      );
    }
    if (_isColumnVisible('discount')) {
      cells.add(
        DataGridCell<SaleOrderLine>(columnName: 'discount', value: line),
      );
    }
    if (_isColumnVisible('discount_amount')) {
      cells.add(
        DataGridCell<double>(
          columnName: 'discount_amount',
          value: line.discountAmount,
        ),
      );
    }
    if (_isColumnVisible('tax_name')) {
      cells.add(
        DataGridCell<SaleOrderLine>(columnName: 'tax_name', value: line),
      );
    }
    if (_isColumnVisible('subtotal')) {
      cells.add(
        DataGridCell<SaleOrderLine>(columnName: 'subtotal', value: line),
      );
    }
    if (_isColumnVisible('tax')) {
      cells.add(DataGridCell<SaleOrderLine>(columnName: 'tax', value: line));
    }
    if (_isColumnVisible('total')) {
      cells.add(DataGridCell<SaleOrderLine>(columnName: 'total', value: line));
    }
    // Actions
    if (_isColumnVisible('actions')) {
      cells.add(
        DataGridCell<SaleOrderLine>(columnName: 'actions', value: line),
      );
    }

    return DataGridRow(cells: cells);
  }).toList();

  // Small text style for cells
  // static const _cellFontSize = 14.0;

  @override
  DataGridRowAdapter? buildRow(DataGridRow row) {
    final cells = row.getCells();
    // Get line from product cell (always present)
    final line =
        cells.firstWhere((c) => c.columnName == 'product').value
            as SaleOrderLine;

    // Get index from line position in list (1-based for display)
    final index = lines.indexOf(line) + 1;

    // Handle section headers
    if (line.isSection) {
      return _buildSectionRow(line, index);
    }

    // Handle subsection headers
    if (line.isSubsection) {
      return _buildSubsectionRow(line, index);
    }

    // Handle note lines
    if (line.isNote) {
      return _buildNoteRow(line, index);
    }

    // Regular product line
    return _buildProductRow(line, index);
  }

  /// Helper to build cells array based on column visibility
  List<Widget> _buildVisibleCells(Map<String, Widget> cellWidgets) {
    final cells = <Widget>[];

    if (_isColumnVisible('index') && cellWidgets.containsKey('index')) {
      cells.add(cellWidgets['index']!);
    }
    if (_isColumnVisible('code') && cellWidgets.containsKey('code')) {
      cells.add(cellWidgets['code']!);
    }
    // Product always visible
    cells.add(cellWidgets['product']!);

    if (_isColumnVisible('quantity') && cellWidgets.containsKey('quantity')) {
      cells.add(cellWidgets['quantity']!);
    }
    if (_isColumnVisible('uom') && cellWidgets.containsKey('uom')) {
      cells.add(cellWidgets['uom']!);
    }
    if (_isColumnVisible('price_unit') &&
        cellWidgets.containsKey('price_unit')) {
      cells.add(cellWidgets['price_unit']!);
    }
    if (_isColumnVisible('discount') && cellWidgets.containsKey('discount')) {
      cells.add(cellWidgets['discount']!);
    }
    if (_isColumnVisible('discount_amount') &&
        cellWidgets.containsKey('discount_amount')) {
      cells.add(cellWidgets['discount_amount']!);
    }
    if (_isColumnVisible('tax_name') && cellWidgets.containsKey('tax_name')) {
      cells.add(cellWidgets['tax_name']!);
    }
    if (_isColumnVisible('subtotal') && cellWidgets.containsKey('subtotal')) {
      cells.add(cellWidgets['subtotal']!);
    }
    if (_isColumnVisible('tax') && cellWidgets.containsKey('tax')) {
      cells.add(cellWidgets['tax']!);
    }
    if (_isColumnVisible('total') && cellWidgets.containsKey('total')) {
      cells.add(cellWidgets['total']!);
    }
    if (_isColumnVisible('actions') && cellWidgets.containsKey('actions')) {
      cells.add(cellWidgets['actions']!);
    }

    return cells;
  }

  DataGridRowAdapter _buildSectionRow(SaleOrderLine line, int index) {
    final sectionSubtotal = _getSectionSubtotal(line);
    final sectionTax = sectionSubtotal * 0.15; // Aproximado, IVA 15%
    final sectionTotal = sectionSubtotal + sectionTax;

    final cellWidgets = <String, Widget>{
      'index': const SizedBox.shrink(),
      'code': const SizedBox.shrink(),
      'product': Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerLeft,
        child: isEditable
            ? EditableTextCell(
                key: ValueKey('section_${line.id}_${line.name.hashCode}'),
                initialValue: line.name,
                onChanged: (value) {
                  if (value != line.name) {
                    onUpdateName?.call(line, value);
                  }
                },
                style: const TextStyle(fontWeight: FontWeight.bold),
                cellType: EditableCellType.name,
                lineId: line.id,
                onTabNext: onTabNext,
                onTabPrevious: onTabPrevious,
                onFocusNodeCreated: (node) =>
                    registerFocusNode(line.id, EditableCellType.name, node),
                onFocusNodeDisposed: (node) =>
                    unregisterFocusNode(line.id, EditableCellType.name, node),
              )
            : Text(
                line.name,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
      ),
      'quantity': const SizedBox.shrink(),
      'uom': const SizedBox.shrink(),
      'price_unit': const SizedBox.shrink(),
      'discount': const SizedBox.shrink(),
      'discount_amount': const SizedBox.shrink(),
      'tax_name': const SizedBox.shrink(),
      'subtotal': Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerRight,
        child: Text(
          sectionSubtotal.toCurrency(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            // fontSize: _cellFontSize,
          ),
        ),
      ),
      'tax': Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerRight,
        child: Text(
          sectionTax.toCurrency(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            // fontSize: _cellFontSize,
          ),
        ),
      ),
      'total': Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerRight,
        child: Text(
          sectionTotal.toCurrency(),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            // fontSize: _cellFontSize,
          ),
        ),
      ),
      'actions': isEditable
          ? Center(
              child: _SectionContextMenuButton(
                line: line,
                lineIndex: index - 1,
                totalLines: lines.length,
                theme: theme,
                onMoveUp: () => onMoveUp?.call(line),
                onMoveDown: () => onMoveDown?.call(line),
                onToggleHidePrices: () => onToggleHidePrices?.call(line),
                onToggleHideComposition: () =>
                    onToggleHideComposition?.call(line),
                onToggleOptional: () => onToggleOptional?.call(line),
                onDelete: () => onDeleteLine?.call(line),
              ),
            )
          : const SizedBox.shrink(),
    };

    return DataGridRowAdapter(
      color: theme.accentColor
          .defaultBrushFor(theme.brightness)
          .withValues(alpha: 0.15),
      cells: _buildVisibleCells(cellWidgets),
    );
  }

  DataGridRowAdapter _buildSubsectionRow(SaleOrderLine line, int index) {
    final cellWidgets = <String, Widget>{
      'index': const SizedBox.shrink(),
      'code': const SizedBox.shrink(),
      'product': Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerLeft,
        child: isEditable
            ? EditableTextCell(
                key: ValueKey('subsection_${line.id}_${line.name.hashCode}'),
                initialValue: line.name,
                onChanged: (value) {
                  if (value != line.name) {
                    onUpdateName?.call(line, value);
                  }
                },
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
                cellType: EditableCellType.name,
                lineId: line.id,
                onTabNext: onTabNext,
                onTabPrevious: onTabPrevious,
                onFocusNodeCreated: (node) =>
                    registerFocusNode(line.id, EditableCellType.name, node),
                onFocusNodeDisposed: (node) =>
                    unregisterFocusNode(line.id, EditableCellType.name, node),
              )
            : Text(
                line.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontStyle: FontStyle.italic,
                ),
              ),
      ),
      'quantity': const SizedBox.shrink(),
      'uom': const SizedBox.shrink(),
      'price_unit': const SizedBox.shrink(),
      'discount': const SizedBox.shrink(),
      'discount_amount': const SizedBox.shrink(),
      'tax_name': const SizedBox.shrink(),
      'subtotal': const SizedBox.shrink(),
      'tax': const SizedBox.shrink(),
      'total': const SizedBox.shrink(),
      'actions': isEditable
          ? Center(
              child: _SectionContextMenuButton(
                line: line,
                lineIndex: index - 1,
                totalLines: lines.length,
                theme: theme,
                onMoveUp: () => onMoveUp?.call(line),
                onMoveDown: () => onMoveDown?.call(line),
                onToggleHidePrices: () => onToggleHidePrices?.call(line),
                onToggleHideComposition: () =>
                    onToggleHideComposition?.call(line),
                onToggleOptional: () => onToggleOptional?.call(line),
                onDelete: () => onDeleteLine?.call(line),
              ),
            )
          : const SizedBox.shrink(),
    };

    return DataGridRowAdapter(
      color: theme.resources.subtleFillColorSecondary,
      cells: _buildVisibleCells(cellWidgets),
    );
  }

  DataGridRowAdapter _buildNoteRow(SaleOrderLine line, int index) {
    final cellWidgets = <String, Widget>{
      'index': const SizedBox.shrink(),
      'code': const SizedBox.shrink(),
      'product': Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerLeft,
        child: isEditable
            ? EditableTextCell(
                key: ValueKey('note_${line.id}_${line.name.hashCode}'),
                initialValue: line.name,
                onChanged: (value) {
                  if (value != line.name) {
                    onUpdateName?.call(line, value);
                  }
                },
                style: TextStyle(
                  color: theme.inactiveColor,
                  fontStyle: FontStyle.italic,
                  // fontSize: _cellFontSize,
                ),
                cellType: EditableCellType.name,
                lineId: line.id,
                onTabNext: onTabNext,
                onTabPrevious: onTabPrevious,
                onFocusNodeCreated: (node) =>
                    registerFocusNode(line.id, EditableCellType.name, node),
                onFocusNodeDisposed: (node) =>
                    unregisterFocusNode(line.id, EditableCellType.name, node),
              )
            : Text(
                line.name,
                style: TextStyle(
                  color: theme.inactiveColor,
                  fontStyle: FontStyle.italic,
                  // fontSize: _cellFontSize,
                ),
              ),
      ),
      'quantity': const SizedBox.shrink(),
      'uom': const SizedBox.shrink(),
      'price_unit': const SizedBox.shrink(),
      'discount': const SizedBox.shrink(),
      'discount_amount': const SizedBox.shrink(),
      'tax_name': const SizedBox.shrink(),
      'subtotal': const SizedBox.shrink(),
      'tax': const SizedBox.shrink(),
      'total': const SizedBox.shrink(),
      'actions': isEditable
          ? Center(
              child: IconButton(
                icon: Icon(
                  FluentIcons.delete,
                  size: 14,
                  color: theme.inactiveColor,
                ),
                onPressed: () => onDeleteLine?.call(line),
              ),
            )
          : const SizedBox.shrink(),
    };

    return DataGridRowAdapter(cells: _buildVisibleCells(cellWidgets));
  }

  DataGridRowAdapter _buildProductRow(SaleOrderLine line, int index) {
    final cellWidgets = <String, Widget>{
      'index': Container(
        alignment: Alignment.center,
        child: Text(
          '$index',
          // style: const TextStyle(fontSize: _cellFontSize),
        ),
      ),
      'code': Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerLeft,
        child: isEditable
            ? EditableTextCell(
                key: ValueKey('code_${line.id}_${line.productCode}'),
                initialValue: _resolveProductCode(line) ?? '',
                // Use async code validation callback
                onCodeSubmit: (value) async {
                  if (value.trim().isEmpty) {
                    return ProductCodeSearchResult.unchanged;
                  }
                  // Call the async validation and return result
                  return await onUpdateCode?.call(line, value.trim()) ??
                      ProductCodeSearchResult.cancelled;
                },
                // Handle Escape or focus lost without valid product
                onEscape: () => onCodeEscape?.call(line),
                style: TextStyle(
                  color: theme.inactiveColor,
                  // fontSize: _cellFontSize,
                ),
                cellType: EditableCellType.code,
                lineId: line.id,
                onTabNext: handleTabNavigation,
                onTabPrevious: handleShiftTabNavigation,
                // Navigate to quantity cell on same line (for existing lines)
                onNavigateToQuantity: (lineId) =>
                    requestFocusOnCell(lineId, EditableCellType.quantity),
                // Arrow Up/Down navigation - same column on prev/next row
                onNavigateUp: handleArrowUp,
                onNavigateDown: handleArrowDown,
                onFocusNodeCreated: (node) =>
                    registerFocusNode(line.id, EditableCellType.code, node),
                onFocusNodeDisposed: (node) =>
                    unregisterFocusNode(line.id, EditableCellType.code, node),
                suffix: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: GestureDetector(
                    onTap: () => onSelectProduct?.call(line),
                    child: Icon(
                      FluentIcons.search,
                      size: 14, // Slightly larger target
                      color: theme.accentColor,
                    ),
                  ),
                ),
              )
            : Text(
                _resolveProductCode(line) ?? '',
                style: TextStyle(color: theme.inactiveColor),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
      ),
      'product': Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        alignment: Alignment.topLeft,
        child: ProductDescriptionCell(
          key: ValueKey('product_desc_${line.id}_${line.name.hashCode}'),
          productName: _resolveProductName(line),
          fullDescription: line.name,
          isEditable: isEditable,
          onDescriptionChanged: (newDescription) {
            if (newDescription != line.name) {
              onUpdateName?.call(line, newDescription);
            }
          },
          onShowProductInfo: () => onShowProductInfo?.call(line),
          onExpandChanged: (isExpanded, lineCount) =>
              refreshRowHeight(line.id, isExpanded, lineCount),
        ),
      ),
      'quantity': Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerRight,
        child: EditableNumberCell(
          key: ValueKey('qty_${line.id}'),
          value: line.productUomQty,
          isEditable: isEditable,
          decimals: line.isUnitProduct ? 0 : 2,
          step: line.isUnitProduct ? 1 : 0.01,
          min: 1, // Cantidad mínima 1
          width: 140, // Match previous width
          onChanged: (qty) {
            onUpdateQty?.call(line, qty);
          },
          // FocusNode registration for Tab navigation
          onFocusNodeCreated: isEditable
              ? (node) =>
                  registerFocusNode(line.id, EditableCellType.quantity, node)
              : null,
          onFocusNodeDisposed: isEditable
              ? (node) => unregisterFocusNode(line.id, EditableCellType.quantity, node)
              : null,
          // Tab, Enter, and Escape key handling
          onKeyEvent: isEditable
              ? (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;

                  // Handle Escape - cancel editing
                  // If line has no product, it will be deleted by onCodeEscape
                  // If line has product, just move focus to code cell
                  if (event.logicalKey == LogicalKeyboardKey.escape) {
                    if (line.productId == null) {
                      // Empty line - use same escape handler as code cell
                      onCodeEscape?.call(line);
                    } else {
                      // Line has product - just go back to code
                      requestFocusOnCell(line.id, EditableCellType.code);
                    }
                    return KeyEventResult.handled;
                  }

                  // Handle Enter - same navigation as Tab
                  if (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    handleTabNavigation(line.id, EditableCellType.quantity);
                    return KeyEventResult.handled;
                  }

                  // Handle Tab
                  if (event.logicalKey == LogicalKeyboardKey.tab) {
                    final shiftPressed =
                        HardwareKeyboard.instance.isShiftPressed;
                    if (shiftPressed) {
                      handleShiftTabNavigation(
                        line.id,
                        EditableCellType.quantity,
                      );
                    } else {
                      handleTabNavigation(line.id, EditableCellType.quantity);
                    }
                    return KeyEventResult.handled;
                  }

                  // Handle Arrow Up - same column on previous row
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    handleArrowUp(line.id, EditableCellType.quantity);
                    return KeyEventResult.handled;
                  }

                  // Handle Arrow Down - same column on next row
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    handleArrowDown(line.id, EditableCellType.quantity);
                    return KeyEventResult.handled;
                  }

                  // Handle + key - increment quantity
                  if (event.logicalKey == LogicalKeyboardKey.add ||
                      event.logicalKey == LogicalKeyboardKey.numpadAdd ||
                      event.logicalKey == LogicalKeyboardKey.equal &&
                          HardwareKeyboard.instance.isShiftPressed) {
                    final step = line.isUnitProduct ? 1.0 : 0.01;
                    final newQty = line.productUomQty + step;
                    onUpdateQty?.call(line, newQty);
                    return KeyEventResult.handled;
                  }

                  // Handle - key - decrement quantity
                  if (event.logicalKey == LogicalKeyboardKey.minus ||
                      event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
                    final step = line.isUnitProduct ? 1.0 : 0.01;
                    final newQty = (line.productUomQty - step).clamp(1.0, double.infinity);
                    onUpdateQty?.call(line, newQty);
                    return KeyEventResult.handled;
                  }

                  return KeyEventResult.ignored;
                }
              : null,
        ),
      ),
      'uom': Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerLeft,
        child: UomCell(
          name: _resolveUomName(line),
          isEditable: isEditable,
          onTap: () => onSelectUom?.call(line),
          style: isEditable
              ? TextStyle(color: theme.accentColor)
              : null, // Default style
        ),
      ),
      'price_unit': Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerRight,
        child: Text(
          line.priceUnit.toFixed(2),
          // style: const TextStyle(fontSize: _cellFontSize),
        ),
      ),
      'discount': Container(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        alignment: Alignment.centerRight,
        child: EditableNumberCell(
          key: ValueKey('discount_${line.id}'),
          value: line.discount,
          isEditable: isEditable,
          decimals: 1,
          step: 0.1,
          min: 0,
          max: 100,
          width: 130, // Match previous width
          style: line.discount > 0 ? TextStyle(color: Colors.green) : null,
          onChanged: (discount) {
            onUpdateDiscount?.call(line, discount);
          },
          // FocusNode registration for Tab navigation
          onFocusNodeCreated: isEditable
              ? (node) =>
                  registerFocusNode(line.id, EditableCellType.discount, node)
              : null,
          onFocusNodeDisposed: isEditable
              ? (node) => unregisterFocusNode(line.id, EditableCellType.discount, node)
              : null,
          // Tab, Enter, and Escape key handling
          onKeyEvent: isEditable
              ? (node, event) {
                  if (event is! KeyDownEvent) return KeyEventResult.ignored;

                  // Handle Escape - cancel editing
                  // If line has no product, it will be deleted by onCodeEscape
                  // If line has product, just move focus to code cell
                  if (event.logicalKey == LogicalKeyboardKey.escape) {
                    if (line.productId == null) {
                      // Empty line - use same escape handler as code cell
                      onCodeEscape?.call(line);
                    } else {
                      // Line has product - just go back to code
                      requestFocusOnCell(line.id, EditableCellType.code);
                    }
                    return KeyEventResult.handled;
                  }

                  // Handle Enter - same navigation as Tab
                  if (event.logicalKey == LogicalKeyboardKey.enter ||
                      event.logicalKey == LogicalKeyboardKey.numpadEnter) {
                    handleTabNavigation(line.id, EditableCellType.discount);
                    return KeyEventResult.handled;
                  }

                  // Handle Tab
                  if (event.logicalKey == LogicalKeyboardKey.tab) {
                    final shiftPressed =
                        HardwareKeyboard.instance.isShiftPressed;
                    if (shiftPressed) {
                      handleShiftTabNavigation(
                        line.id,
                        EditableCellType.discount,
                      );
                    } else {
                      handleTabNavigation(line.id, EditableCellType.discount);
                    }
                    return KeyEventResult.handled;
                  }

                  // Handle Arrow Up - same column on previous row
                  if (event.logicalKey == LogicalKeyboardKey.arrowUp) {
                    handleArrowUp(line.id, EditableCellType.discount);
                    return KeyEventResult.handled;
                  }

                  // Handle Arrow Down - same column on next row
                  if (event.logicalKey == LogicalKeyboardKey.arrowDown) {
                    handleArrowDown(line.id, EditableCellType.discount);
                    return KeyEventResult.handled;
                  }

                  // Handle + key - increment discount
                  if (event.logicalKey == LogicalKeyboardKey.add ||
                      event.logicalKey == LogicalKeyboardKey.numpadAdd ||
                      event.logicalKey == LogicalKeyboardKey.equal &&
                          HardwareKeyboard.instance.isShiftPressed) {
                    final newDiscount = (line.discount + 0.1).clamp(0.0, 100.0);
                    onUpdateDiscount?.call(line, newDiscount);
                    return KeyEventResult.handled;
                  }

                  // Handle - key - decrement discount
                  if (event.logicalKey == LogicalKeyboardKey.minus ||
                      event.logicalKey == LogicalKeyboardKey.numpadSubtract) {
                    final newDiscount = (line.discount - 0.1).clamp(0.0, 100.0);
                    onUpdateDiscount?.call(line, newDiscount);
                    return KeyEventResult.handled;
                  }

                  return KeyEventResult.ignored;
                }
              : null,
        ),
      ),
      'discount_amount': Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerRight,
        child: Text(
          line.discountAmount > 0
              ? line.discountAmount.toCurrency()
              : '',
          style: TextStyle(
            // fontSize: _cellFontSize,
            color: line.discountAmount > 0 ? Colors.green : null,
          ),
        ),
      ),
      'tax_name': Container(
        padding: const EdgeInsets.symmetric(horizontal: 2),
        alignment: Alignment.center,
        child: TaxBadge(taxNames: _resolveTaxNames(line)),
      ),
      'subtotal': Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerRight,
        child: Text(line.priceSubtotal.toCurrency()),
      ),
      'tax': Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerRight,
        child: Text(
          line.priceTax.toCurrency(),
          style: TextStyle(color: theme.inactiveColor),
        ),
      ),
      'total': Container(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        alignment: Alignment.centerRight,
        child: Text(
          line.priceTotal.toCurrency(),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      'actions': isEditable
          ? Center(
              child: IconButton(
                icon: Icon(
                  FluentIcons.delete,
                  size: 14,
                  color: theme.inactiveColor,
                ),
                onPressed: () => onDeleteLine?.call(line),
              ),
            )
          : const SizedBox.shrink(),
    };

    return DataGridRowAdapter(cells: _buildVisibleCells(cellWidgets));
  }
}

/// Context menu button for sections/subsections
class _SectionContextMenuButton extends StatefulWidget {
  final SaleOrderLine line;
  final int lineIndex;
  final int totalLines;
  final FluentThemeData theme;
  final VoidCallback? onMoveUp;
  final VoidCallback? onMoveDown;
  final VoidCallback? onToggleHidePrices;
  final VoidCallback? onToggleHideComposition;
  final VoidCallback? onToggleOptional;
  final VoidCallback? onDelete;

  const _SectionContextMenuButton({
    required this.line,
    required this.lineIndex,
    required this.totalLines,
    required this.theme,
    this.onMoveUp,
    this.onMoveDown,
    this.onToggleHidePrices,
    this.onToggleHideComposition,
    this.onToggleOptional,
    this.onDelete,
  });

  @override
  State<_SectionContextMenuButton> createState() =>
      _SectionContextMenuButtonState();
}

class _SectionContextMenuButtonState extends State<_SectionContextMenuButton> {
  final _flyoutController = FlyoutController();

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isFirst = widget.lineIndex == 0;
    final isLast = widget.lineIndex == widget.totalLines - 1;

    return FlyoutTarget(
      controller: _flyoutController,
      child: IconButton(
        icon: const Icon(FluentIcons.more_vertical, size: 16),
        onPressed: () {
          _flyoutController.showFlyout(
            barrierDismissible: true,
            dismissOnPointerMoveAway: false,
            builder: (context) => MenuFlyout(
              items: [
                // Hide Prices
                if (widget.onToggleHidePrices != null)
                  MenuFlyoutItem(
                    leading: Icon(
                      widget.line.collapsePrices
                          ? FluentIcons.checkbox_composite
                          : FluentIcons.checkbox,
                      size: 14,
                    ),
                    text: const Text('Hide Prices'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onToggleHidePrices!();
                    },
                  ),
                // Hide Composition
                if (widget.onToggleHideComposition != null)
                  MenuFlyoutItem(
                    leading: Icon(
                      widget.line.collapseComposition
                          ? FluentIcons.checkbox_composite
                          : FluentIcons.checkbox,
                      size: 14,
                    ),
                    text: const Text('Hide Composition'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onToggleHideComposition!();
                    },
                  ),
                // Set Optional
                if (widget.onToggleOptional != null)
                  MenuFlyoutItem(
                    leading: Icon(
                      widget.line.isOptional
                          ? FluentIcons.checkbox_composite
                          : FluentIcons.checkbox,
                      size: 14,
                    ),
                    text: const Text('Set Optional'),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onToggleOptional!();
                    },
                  ),
                const MenuFlyoutSeparator(),
                // Move up
                if (widget.onMoveUp != null)
                  MenuFlyoutItem(
                    leading: Icon(
                      FluentIcons.up,
                      size: 14,
                      color: isFirst ? widget.theme.inactiveColor : null,
                    ),
                    text: Text(
                      'Mover hacia arriba',
                      style: isFirst
                          ? TextStyle(color: widget.theme.inactiveColor)
                          : null,
                    ),
                    onPressed: isFirst
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onMoveUp!();
                          },
                  ),
                // Move down
                if (widget.onMoveDown != null)
                  MenuFlyoutItem(
                    leading: Icon(
                      FluentIcons.down,
                      size: 14,
                      color: isLast ? widget.theme.inactiveColor : null,
                    ),
                    text: Text(
                      'Mover hacia abajo',
                      style: isLast
                          ? TextStyle(color: widget.theme.inactiveColor)
                          : null,
                    ),
                    onPressed: isLast
                        ? null
                        : () {
                            Navigator.of(context).pop();
                            widget.onMoveDown!();
                          },
                  ),
                const MenuFlyoutSeparator(),
                // Delete
                if (widget.onDelete != null)
                  MenuFlyoutItem(
                    leading: Icon(
                      FluentIcons.delete,
                      size: 14,
                      color: Colors.red,
                    ),
                    text: Text('Eliminar', style: TextStyle(color: Colors.red)),
                    onPressed: () {
                      Navigator.of(context).pop();
                      widget.onDelete!();
                    },
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
