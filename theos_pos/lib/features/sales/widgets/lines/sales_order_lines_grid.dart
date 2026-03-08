import 'dart:convert';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_datagrid/datagrid.dart';
import 'package:syncfusion_flutter_core/theme.dart';

import '../../../../../core/constants/app_constants.dart';
import '../../../products/providers/product_providers.dart';

import '../editable_cell_type.dart';
import 'sales_order_line_card.dart';
import 'sales_order_lines_data_source.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// A unified grid/list widget for displaying and editing Sale Order Lines.
///
/// Features:
/// - Responsive: Table on desktop, Cards on mobile.
/// - Configurable: Column visibility and widths are persisted.
/// - Editable: Supports editing if [isEditable] is true.
class SalesOrderLinesGrid extends ConsumerStatefulWidget {
  final List<SaleOrderLine> lines;
  final bool isEditable;

  // Callbacks
  // onUpdateQty is FutureOr<void> to support async recalculation with pricelist rules
  final Function(SaleOrderLine line, double qty)? onUpdateQty;
  final void Function(SaleOrderLine line, double price)? onUpdatePrice;
  final void Function(SaleOrderLine line, double discount)? onUpdateDiscount;
  final void Function(SaleOrderLine line, String name)? onUpdateName;

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
  final VoidCallback? onVisibilityChanged;

  /// Callback for Tab navigation on last line
  /// Called when user presses Tab from the last product line
  /// Receives lineId to check if line is empty before creating new
  /// Parent should create a new line (if appropriate) and return true if handled
  final bool Function(int lineId)? onTabOnLastLine;

  // Key for storage preference (allows sharing prefs between different screens if needed)
  final String storageKey;

  const SalesOrderLinesGrid({
    super.key,
    required this.lines,
    this.isEditable = false,
    this.storageKey = 'sale_order_form_lines',
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
    this.onVisibilityChanged,
    this.onTabOnLastLine,
  });

  @override
  ConsumerState<SalesOrderLinesGrid> createState() =>
      SalesOrderLinesGridState();
}

class SalesOrderLinesGridState extends ConsumerState<SalesOrderLinesGrid> {
  // Column visibility state
  final Map<String, bool> _columnVisibility = {
    'index': true,
    'code': true,
    'product': true,
    'quantity': true,
    'uom': true,
    'price_unit': true,
    'discount': true,
    'discount_amount': true,
    'tax_name': true,
    'subtotal': true,
    'tax': true,
    'total': true,
    'actions': true,
  };

  // Column widths state
  Map<String, double> _columnWidths = {};
  bool _preferencesLoaded = false;

  /// Registry of FocusNodes for editable cells - persists across DataSource rebuilds
  /// Key: "lineId_cellType"
  final Map<String, FocusNode> _focusNodeRegistry = {};

  // Default widths
  static const Map<String, double> _defaultColumnWidths = {
    'index': 36,
    'code': 140,
    'quantity': 180,
    'uom': 100,
    'price_unit': 80,
    'discount': 180,
    'discount_amount': 100,
    'tax_name': 80,
    'subtotal': 100,
    'tax': 100,
    'total': 100,
    'actions': 40,
  };

  static const Map<String, String> columnLabels = {
    'index': '#',
    'code': 'Código',
    'product': 'Producto',
    'quantity': 'Cantidad',
    'uom': 'Unidad',
    'price_unit': 'P. Unitario',
    'discount': '% Descuento',
    'discount_amount': 'Mto. Dto.',
    'tax_name': 'Impuesto',
    'subtotal': 'Subtotal',
    'tax': 'IVA',
    'total': 'Total',
    'actions': 'Acciones',
  };

  @override
  void initState() {
    super.initState();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Load column visibility
      final visibilityJson = prefs.getString('${widget.storageKey}_visibility');
      if (visibilityJson != null) {
        final Map<String, dynamic> decoded = json.decode(visibilityJson);
        // Merge loaded visibility with default to ensure all keys exist
        final loaded = decoded.map((k, v) => MapEntry(k, v as bool));
        _columnVisibility.addAll(loaded);
      }

      // Load column widths
      final widthsJson = prefs.getString('${widget.storageKey}_widths');
      if (widthsJson != null) {
        final Map<String, dynamic> decoded = json.decode(widthsJson);
        _columnWidths = decoded.map(
          (k, v) => MapEntry(k, (v as num).toDouble()),
        );
      }

      if (mounted) {
        setState(() {
          _preferencesLoaded = true;
        });
        widget.onVisibilityChanged?.call();
      }
    } catch (e) {
      logger.d('[SalesOrderLinesGrid]', 'Error loading preferences: $e');
      if (mounted) {
        setState(() {
          _preferencesLoaded = true;
        });
      }
    }
  }

  Future<void> _saveColumnVisibility() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final visibilityJson = json.encode(_columnVisibility);
      await prefs.setString('${widget.storageKey}_visibility', visibilityJson);
    } catch (e) {
      logger.d('[SalesOrderLinesGrid]', 'Error saving visibility: $e');
    }
  }

  Future<void> _saveColumnWidths() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final widthsJson = json.encode(_columnWidths);
      await prefs.setString('${widget.storageKey}_widths', widthsJson);
    } catch (e) {
      logger.d('[SalesOrderLinesGrid]', 'Error saving widths: $e');
    }
  }

  double _getColumnWidth(String columnName) {
    return _columnWidths[columnName] ?? _defaultColumnWidths[columnName] ?? 100;
  }

  /// Calcula la altura de una fila basándose en su contenido
  ///
  /// La altura se calcula dinámicamente según:
  /// - Tipo de línea (sección, nota, producto)
  /// - Número de líneas en la descripción
  /// - Si el campo de descripción está expandido y cuántas líneas tiene
  double _calculateRowHeight(int dataIndex) {
    const double sectionHeight = 40.0;
    const double noteHeight = 36.0;
    const double verticalPadding = 16.0; // Top + Bottom padding
    const double minRowHeight = 48.0;

    if (dataIndex < 0 || dataIndex >= widget.lines.length) {
      return minRowHeight;
    }

    final line = widget.lines[dataIndex];

    // Secciones tienen altura fija
    if (line.isSection || line.isSubsection) {
      return sectionHeight;
    }

    // Notas tienen altura fija
    if (line.isNote) {
      return noteHeight;
    }

    // Use TextPainter to calculate exact height required
    final theme = FluentTheme.of(context);
    final textStyle = theme.typography.body;

    // Construct the text to measure: Product Name + Custom Description
    final description = line.name;
    final productName = line.productName ?? description.split('\n').first;

    String customText = '';
    if (description != productName) {
      if (description.startsWith(productName)) {
        customText = description.substring(productName.length).trim();
      } else if (description.contains('\n')) {
        final descLines = description.split('\n');
        if (descLines.length > 1) {
          customText = descLines.sublist(1).join('\n').trim();
        }
      }
    }

    // 1. Measure Product Name (Bold/Medium)
    final namePainter = TextPainter(
      text: TextSpan(
        text: productName,
        style: textStyle?.copyWith(fontWeight: FontWeight.w500),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 2, // Match the visual constraint in _ProductDescriptionView
    );

    // 2. Measure Description (Italic, Accent Color)
    final descPainter = TextPainter(
      text: TextSpan(
        text: customText,
        style: textStyle?.copyWith(
          color: theme.accentColor,
          fontStyle: FontStyle.italic,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 10, // Generous limit for description
    );

    // Estimate column width logic
    // We try to approximate the width available for the product column.
    // If it's too specific to calculate exactly, we use a safe conservative width like 200.0.
    // Overestimating height (by using smaller width) is safer than overflow.
    double productColumnWidth = 250.0;
    final screenWidth = MediaQuery.of(context).size.width;
    if (screenWidth > 1200) {
      productColumnWidth = 400.0;
    } else if (screenWidth > 800) {
      productColumnWidth = 300.0;
    }

    // Layout painters
    namePainter.layout(maxWidth: productColumnWidth);
    descPainter.layout(maxWidth: productColumnWidth);

    final totalHeight =
        verticalPadding +
        namePainter.height +
        (customText.isNotEmpty ? descPainter.height : 0);

    return totalHeight.clamp(minRowHeight, 400.0);
  }

  void _onColumnResizeUpdate(ColumnResizeUpdateDetails details) {
    // Don't save product column width - it should always fill remaining space
    if (details.column.columnName == 'product') {
      return;
    }
    setState(() {
      _columnWidths[details.column.columnName] = details.width;
    });
    _saveColumnWidths();
  }

  // Public methods for external control
  void toggleColumnVisibility(String columnName) {
    if (_columnVisibility.containsKey(columnName)) {
      setState(() {
        _columnVisibility[columnName] = !_columnVisibility[columnName]!;
      });
      _saveColumnVisibility();
      widget.onVisibilityChanged?.call();
    }
  }

  Map<String, bool> get columnVisibility => Map.unmodifiable(_columnVisibility);
  Map<String, String> get labels => columnLabels;

  /// Resets all column widths to their default values
  Future<void> resetColumnWidths() async {
    setState(() {
      _columnWidths = Map.from(_defaultColumnWidths);
    });
    await _saveColumnWidths();
    widget.onVisibilityChanged?.call();
  }

  /// Focus on the code cell of a specific line
  /// Returns true if focus was successfully requested
  bool focusLineCode(int lineId) {
    final key = '${lineId}_code';
    final node = _focusNodeRegistry[key];
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      return true;
    }
    return false;
  }

  /// Focus on the quantity cell of a specific line
  bool focusLineQuantity(int lineId) {
    final key = '${lineId}_quantity';
    final node = _focusNodeRegistry[key];
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    if (!_preferencesLoaded) {
      return const Center(child: ProgressRing());
    }

    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < ScreenBreakpoints.mobileMaxWidth;

    // Content only - header managed externally
    if (widget.lines.isEmpty) {
      return _buildEmptyState(theme);
    } else if (isSmallScreen) {
      return _buildLinesCards(context, theme);
    } else {
      return _buildLinesTable(context, theme, isSmallScreen);
    }
  }

  Widget _buildEmptyState(FluentThemeData theme) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            children: [
              Icon(
                FluentIcons.shopping_cart,
                size: 48,
                color: theme.inactiveColor,
              ),
              const SizedBox(height: 16),
              Text(
                'No hay productos',
                style: theme.typography.subtitle?.copyWith(
                  color: theme.inactiveColor,
                ),
              ),
              if (widget.isEditable) ...[
                const SizedBox(height: 8),
                Text(
                  'Usa los enlaces de abajo para agregar productos',
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLinesCards(BuildContext context, FluentThemeData theme) {
    return Column(
      children: widget.lines.asMap().entries.map((entry) {
        return SalesOrderLineCard(
          line: entry.value,
          index: entry.key + 1,
          allLines: widget.lines,
          isEditable: widget.isEditable,
          onUpdateQty: widget.onUpdateQty,
          onUpdatePrice: widget.onUpdatePrice,
          onUpdateDiscount: widget.onUpdateDiscount,
          onSelectUom: widget.onSelectUom,
          onSelectProduct: widget.onSelectProduct,
          onShowProductInfo: widget.onShowProductInfo,
          onDelete: widget.onDeleteLine,
          onDuplicate: widget.onDuplicate,
        );
      }).toList(),
    );
  }

  Widget _buildLinesTable(
    BuildContext context,
    FluentThemeData theme,
    bool isSmallScreen,
  ) {
    final headerColor = theme.accentColor
        .defaultBrushFor(theme.brightness)
        .withValues(alpha: 0.9);
    final headerTextColor = Colors.white;

    // Obtener el servicio de lookup de catálogos (si está cargado)
    final catalogService = ref.watch(catalogServiceProvider);
    // Cargar el caché si no está cargado (async, pero el servicio es resiliente)
    if (!catalogService.isLoaded) {
      catalogService.loadCatalogs();
    }

    // Effective visibility: Apply defaults for small screen if needed,
    // though we switch to cards for small screens mostly.
    // Also handle actions visibility based on isEditable
    final effectiveVisibility = Map<String, bool>.from(_columnVisibility);

    // If not editable, force actions hidden if desired, OR keep them visible if the user
    // wants to see them (maybe for 'Info'). Logic handled in DataSource too.
    // But here we also need to add/remove the GridColumn.
    if (!widget.isEditable && effectiveVisibility['actions'] == true) {
      // Keep it true if we want read-only actions?
      // If DataSource hides it, we should hide it here too.
      // Let's check DataSource logic: it returns false if !isEditable.
      // So we should hide it here.
      effectiveVisibility['actions'] = false;
    }

    final dataSource = SalesOrderLinesDataSource(
      lines: widget.lines,
      columnVisibility: effectiveVisibility,
      theme: theme,
      isEditable: widget.isEditable,
      catalogService: catalogService,
      focusNodeRegistry: _focusNodeRegistry,
      onUpdateQty: widget.onUpdateQty,
      onUpdatePrice: widget.onUpdatePrice,
      onUpdateDiscount: widget.onUpdateDiscount,
      onUpdateName: widget.onUpdateName,
      onUpdateCode: widget.onUpdateCode,
      onCodeEscape: widget.onCodeEscape,
      onUpdateUom: widget.onUpdateUom,
      onDeleteLine: widget.onDeleteLine,
      onMoveUp: widget.onMoveUp,
      onMoveDown: widget.onMoveDown,
      onDuplicate: widget.onDuplicate,
      onSelectProduct: widget.onSelectProduct,
      onSelectUom: widget.onSelectUom,
      onShowProductInfo: widget.onShowProductInfo,
      onToggleHidePrices: widget.onToggleHidePrices,
      onToggleHideComposition: widget.onToggleHideComposition,
      onToggleOptional: widget.onToggleOptional,
      onTabNext: widget.onTabOnLastLine != null
          ? (lineId, cellType) {
              // Handle Tab on last line - pass lineId to check if empty
              return widget.onTabOnLastLine!(lineId);
            }
          : null,
      onRowHeightChanged: (lineId, isExpanded, lineCount) {
        // Row height changes are handled by onQueryRowHeight callback
        // No need to force rebuild - DataSource notifies listeners
      },
    );

    // Generate key based on line IDs to force SfDataGrid to use new DataSource
    // when lines are added/removed
    final lineIdsKey = widget.lines.map((l) => l.id).join('_');

    // Wrap grid in FocusTraversalGroup to keep Tab navigation within the grid
    // This prevents Tab from escaping to other UI elements while editing
    return FocusTraversalGroup(
      policy: OrderedTraversalPolicy(),
      child: SfDataGridTheme(
        data: SfDataGridThemeData(
          headerColor: headerColor,
          gridLineColor: theme.resources.dividerStrokeColorDefault,
          gridLineStrokeWidth: 1,
        ),
        child: SfDataGrid(
          key: ValueKey('grid_$lineIdsKey'),
          source: dataSource,
        columnWidthMode: ColumnWidthMode.none,
        gridLinesVisibility: GridLinesVisibility.both,
        headerGridLinesVisibility: GridLinesVisibility.both,
        headerRowHeight: 36,
        onQueryRowHeight: (details) {
          // rowIndex 0 es el header, las filas de datos empiezan en 1
          if (details.rowIndex == 0) {
            return 36; // Altura del header
          }
          // Restar 1 para obtener el índice correcto en la lista de líneas
          return _calculateRowHeight(details.rowIndex - 1);
        },
        allowSorting: false,
        allowColumnsResizing: true,
        columnResizeMode: ColumnResizeMode.onResize,
        onColumnResizeStart: (details) {
          logger.d(
            '[SalesOrderLinesGrid]',
            'Column resize started: ${details.column.columnName}',
          );
          return true;
        },
        onColumnResizeUpdate: (details) {
          logger.d(
            '[SalesOrderLinesGrid]',
            'Column resize update: ${details.column.columnName} -> ${details.width}',
          );
          _onColumnResizeUpdate(details);
          return true;
        },
          columns: _buildGridColumns(
            effectiveVisibility,
            headerTextColor,
            isSmallScreen,
          ),
        ),
      ),
    );
  }

  List<GridColumn> _buildGridColumns(
    Map<String, bool> visibility,
    Color headerTextColor,
    bool isSmallScreen,
  ) {
    final columns = <GridColumn>[];

    if (visibility['index'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'index',
          width: _getColumnWidth('index'),
          minimumWidth: 30,
          label: _buildHeaderCell('#', headerTextColor, Alignment.center),
        ),
      );
    }

    if (visibility['code'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'code',
          width: _getColumnWidth('code'),
          minimumWidth: 100,
          label: _buildHeaderCell(
            'Código',
            headerTextColor,
            Alignment.centerLeft,
          ),
        ),
      );
    }

    // Product column always visible and always fills remaining space
    // This column expands/contracts automatically when other columns are resized
    columns.add(
      GridColumn(
        columnName: 'product',
        columnWidthMode: ColumnWidthMode.fill,
        minimumWidth: isSmallScreen ? 100 : 150,
        label: _buildHeaderCell(
          'Producto',
          headerTextColor,
          Alignment.centerLeft,
        ),
      ),
    );

    if (visibility['quantity'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'quantity',
          width: _getColumnWidth('quantity'),
          minimumWidth: 70,
          label: _buildHeaderCell(
            'Cant.',
            headerTextColor,
            Alignment.centerRight,
          ),
        ),
      );
    }

    if (visibility['uom'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'uom',
          width: _getColumnWidth('uom'),
          minimumWidth: 50,
          label: _buildHeaderCell(
            'Unidad',
            headerTextColor,
            Alignment.centerLeft,
          ),
        ),
      );
    }

    if (visibility['price_unit'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'price_unit',
          width: _getColumnWidth('price_unit'),
          minimumWidth: 60,
          label: _buildHeaderCell(
            'P.Unit.',
            headerTextColor,
            Alignment.centerRight,
          ),
        ),
      );
    }

    if (visibility['discount'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'discount',
          width: _getColumnWidth('discount'),
          minimumWidth: 60,
          label: _buildHeaderCell(
            '%Dto.',
            headerTextColor,
            Alignment.centerRight,
          ),
        ),
      );
    }

    if (visibility['discount_amount'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'discount_amount',
          width: _getColumnWidth('discount_amount'),
          minimumWidth: 65,
          label: _buildHeaderCell(
            'Mto.Dto.',
            headerTextColor,
            Alignment.centerRight,
          ),
        ),
      );
    }

    if (visibility['tax_name'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'tax_name',
          width: _getColumnWidth('tax_name'),
          minimumWidth: 60,
          label: _buildHeaderCell('Imp.', headerTextColor, Alignment.center),
        ),
      );
    }

    if (visibility['subtotal'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'subtotal',
          width: _getColumnWidth('subtotal'),
          minimumWidth: 70,
          label: _buildHeaderCell(
            'Subtotal',
            headerTextColor,
            Alignment.centerRight,
          ),
        ),
      );
    }

    if (visibility['tax'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'tax',
          width: _getColumnWidth('tax'),
          minimumWidth: 50,
          label: _buildHeaderCell(
            'IVA',
            headerTextColor,
            Alignment.centerRight,
          ),
        ),
      );
    }

    if (visibility['total'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'total',
          width: _getColumnWidth('total'),
          minimumWidth: 70,
          label: _buildHeaderCell(
            'Total',
            headerTextColor,
            Alignment.centerRight,
          ),
        ),
      );
    }

    if (visibility['actions'] ?? true) {
      columns.add(
        GridColumn(
          columnName: 'actions',
          width: _getColumnWidth('actions'),
          minimumWidth: 35,
          maximumWidth: 50,
          label: const SizedBox.shrink(),
        ),
      );
    }

    return columns;
  }

  Widget _buildHeaderCell(String text, Color color, Alignment alignment) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      alignment: alignment,
      child: Text(
        text,
        style: TextStyle(color: color, fontWeight: FontWeight.bold),
      ),
    );
  }
}
