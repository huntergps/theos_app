import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart'; // For SaleOrderLine extensions

import '../../../../core/constants/app_constants.dart';
import '../../../../core/theme/spacing.dart';
import '../../../../shared/widgets/reactive/reactive_sale_order_line.dart';
import '../../providers/providers.dart';
import '../../widgets/lines/sales_order_line_card.dart';
import '../../widgets/lines/sales_order_lines_grid.dart';
import 'form_lines_dialogs.dart';
import 'line_actions_mixin.dart';

/// Unified lines section for SaleOrderFormScreen (Section 3)
///
/// Single widget that handles both view and edit modes using the same provider.
/// The mode is determined by [isEditing] flag.
///
/// Features:
/// - Single source of truth: always uses [saleOrderFormVisibleLinesProvider]
/// - Unified toolbar with action links (edit) or empty space (view)
/// - Single [SalesOrderLinesGrid] with isEditable based on mode
/// - Responsive: Grid on desktop, Cards on mobile
class SaleOrderFormLines extends ConsumerStatefulWidget {
  final int orderId;
  final bool isNew;
  final bool isEditing;

  const SaleOrderFormLines({
    super.key,
    required this.orderId,
    this.isNew = false,
    this.isEditing = false,
  });

  @override
  ConsumerState<SaleOrderFormLines> createState() => SaleOrderFormLinesState();
}

/// Public typedef for the GlobalKey type
typedef SaleOrderFormLinesKey = GlobalKey<SaleOrderFormLinesState>;

class SaleOrderFormLinesState extends ConsumerState<SaleOrderFormLines>
    with
        SaleOrderFormLineActionsMixin<SaleOrderFormLines>,
        SaleOrderFormDialogsMixin<SaleOrderFormLines> {
  final GlobalKey<SalesOrderLinesGridState> _gridKey = GlobalKey();
  final FocusNode _addProductButtonFocus = FocusNode();
  final FocusNode _addSectionButtonFocus = FocusNode();
  final FocusNode _addNoteButtonFocus = FocusNode();

  /// FocusNode to capture Tab entering the grid area
  /// When this receives focus, it triggers focusLastLineOrCreate behavior
  late final FocusNode _gridEntryFocus;

  @override
  void initState() {
    super.initState();
    _gridEntryFocus = FocusNode(debugLabel: 'GridEntry');
    _gridEntryFocus.addListener(_onGridEntryFocusChange);
  }

  @override
  void dispose() {
    _gridEntryFocus.removeListener(_onGridEntryFocusChange);
    _gridEntryFocus.dispose();
    _addProductButtonFocus.dispose();
    _addSectionButtonFocus.dispose();
    _addNoteButtonFocus.dispose();
    super.dispose();
  }

  /// Called when the grid entry FocusNode gains/loses focus
  void _onGridEntryFocusChange() {
    if (_gridEntryFocus.hasFocus && widget.isEditing) {
      // Tab entered the grid area - behave like Edit button
      // Use post-frame callback to avoid focus conflicts
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          focusLastLineOrCreate();
        }
      });
    }
  }

  // Mixin requirements
  @override
  bool get isLineEditingEnabled => widget.isEditing;

  @override
  int get currentOrderId => widget.orderId;

  @override
  bool get isDialogsEnabled => widget.isEditing;

  @override
  int get dialogOrderId => widget.orderId;

  @override
  void didUpdateWidget(SaleOrderFormLines oldWidget) {
    super.didUpdateWidget(oldWidget);

    // When entering edit mode, focus on the last line or create a new one
    if (widget.isEditing && !oldWidget.isEditing) {
      // Use post-frame callback to ensure grid is built
      WidgetsBinding.instance.addPostFrameCallback((_) {
        focusLastLineOrCreate();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final spacing = ref.watch(themedSpacingProvider);

    // Single source of truth - always use provider
    final visibleLines = ref.watch(saleOrderFormVisibleLinesProvider);

    // Use LayoutBuilder to handle keyboard-constrained height
    return LayoutBuilder(
      builder: (context, constraints) {
        final showToolbar =
            (widget.isEditing || visibleLines.isNotEmpty) &&
            constraints.maxHeight > 150;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Unified toolbar - hide when height is too constrained (keyboard open)
            if (showToolbar) _buildToolbar(context, theme, spacing),
            if (showToolbar) SizedBox(height: spacing.sm),
            // Content - Grid or Cards based on screen size
            // Use Flexible to allow shrinking when keyboard opens
            Flexible(
              fit: FlexFit.tight,
              child: _buildContent(context, theme, visibleLines),
            ),
          ],
        );
      },
    );
  }

  // ============================================================================
  // TOOLBAR
  // ============================================================================

  Widget _buildToolbar(
    BuildContext context,
    FluentThemeData theme,
    ThemedSpacing spacing,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        // Left side: action links (edit mode) or empty space (view mode)
        if (widget.isEditing)
          _buildActionLinks(context, theme, spacing)
        else
          const SizedBox.shrink(),
        // Right side: column toggle (always visible)
        _buildColumnToggleButton(context, theme, spacing),
      ],
    );
  }

  Widget _buildActionLinks(
    BuildContext context,
    FluentThemeData theme,
    ThemedSpacing spacing,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Wrap(
          spacing: spacing.lg,
          runSpacing: spacing.sm,
          children: [
            HyperlinkButton(
              focusNode: _addProductButtonFocus,
              onPressed: () => showAddProductDialog(context),
              child: Text(
                'Agregar un producto',
                style: TextStyle(color: theme.accentColor),
              ),
            ),
            HyperlinkButton(
              focusNode: _addSectionButtonFocus,
              onPressed: () => addSection(context),
              child: Text(
                'Agregar una seccion',
                style: TextStyle(color: theme.accentColor),
              ),
            ),
            HyperlinkButton(
              focusNode: _addNoteButtonFocus,
              onPressed: () => addNote(context),
              child: Text(
                'Agregar una nota',
                style: TextStyle(color: theme.accentColor),
              ),
            ),
          ],
        ),
        // Grid entry point - invisible focus receiver after note button
        // Tab will go: Note -> Grid Entry -> (focus moves to grid cells)
        Focus(
          focusNode: _gridEntryFocus,
          canRequestFocus: true,
          child: const SizedBox(width: 1, height: 1),
        ),
      ],
    );
  }

  Widget _buildColumnToggleButton(
    BuildContext context,
    FluentThemeData theme,
    ThemedSpacing spacing,
  ) {
    final items = _buildColumnMenuItems(theme);
    if (items.isEmpty) return const SizedBox.shrink();

    return DropDownButton(
      title: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.column_options, size: 14, color: theme.accentColor),
          SizedBox(width: spacing.xs),
          Text(
            'Columnas',
            style: TextStyle(fontSize: 12, color: theme.accentColor),
          ),
        ],
      ),
      items: items,
    );
  }

  List<MenuFlyoutItemBase> _buildColumnMenuItems(FluentThemeData theme) {
    final gridState = _gridKey.currentState;
    if (gridState == null) return [];

    final visibility = gridState.columnVisibility;
    final labels = gridState.labels;

    final List<MenuFlyoutItemBase> items = labels.entries
        .where((e) => e.key != 'product' && e.key != 'actions')
        .map<MenuFlyoutItemBase>((entry) {
          final isVisible = visibility[entry.key] ?? true;
          return MenuFlyoutItem(
            leading: Icon(
              isVisible ? FluentIcons.checkbox_composite : FluentIcons.checkbox,
              size: 14,
            ),
            text: Text(entry.value),
            onPressed: () => gridState.toggleColumnVisibility(entry.key),
          );
        })
        .toList();

    // Add separator and reset option at the end
    items.add(const MenuFlyoutSeparator());
    items.add(
      MenuFlyoutItem(
        leading: const Icon(FluentIcons.reset, size: 14),
        text: const Text('Restablecer anchos'),
        onPressed: () => gridState.resetColumnWidths(),
      ),
    );

    return items;
  }

  // ============================================================================
  // CONTENT - Grid or Cards
  // ============================================================================

  Widget _buildContent(
    BuildContext context,
    FluentThemeData theme,
    List<SaleOrderLine> lines,
  ) {
    if (lines.isEmpty) {
      return _buildEmptyState(theme);
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= ScreenBreakpoints.mobileMaxWidth) {
          // Desktop/Tablet: Use grid
          // Focus entry point is now in _buildActionLinks after "Agregar nota" button
          return SalesOrderLinesGrid(
              key: _gridKey,
              lines: lines,
              isEditable: widget.isEditing,
              storageKey: 'sale_order_form_lines',
              onVisibilityChanged: () {
                if (mounted) setState(() {});
              },
              // Edit callbacks - delegate to mixin methods
              onUpdateQty: updateLineQty,
              onUpdatePrice: updateLinePrice,
              onUpdateDiscount: updateLineDiscount,
              onUpdateName: updateLineName,
              onUpdateCode: (line, code) =>
                  updateLineProductByCode(context, line, code),
              onCodeEscape: _handleCodeEscape,
              onUpdateUom: updateLineUom,
              onDeleteLine: (line) => _deleteLineWithFocus(context, line),
              onMoveUp: moveLineUp,
              onMoveDown: moveLineDown,
              onDuplicate: duplicateLine,
              onSelectProduct: (line) => selectProductForLine(context, line),
              onSelectUom: (line) => selectUomForLine(context, line),
              onShowProductInfo: (line) => showProductInfo(context, line),
              onToggleHidePrices: toggleHidePrices,
              onToggleHideComposition: toggleHideComposition,
              onToggleOptional: toggleOptional,
              onTabOnLastLine: (lineId) => _onTabOnLastLine(context, lineId),
          );
        }

        // Mobile: Use reactive cards in view mode for granular updates
        // In edit mode, use regular cards to handle unsaved changes
        if (!widget.isEditing && widget.orderId > 0) {
          return _buildReactiveMobileCards(widget.orderId);
        }
        return _buildMobileCards(lines);
      },
    );
  }

  /// Build mobile cards using reactive stream providers for granular updates.
  /// Only used in view mode when the order exists in the database.
  Widget _buildReactiveMobileCards(int orderId) {
    return Consumer(
      builder: (context, ref, _) {
        final lineIdsAsync = ref.watch(saleOrderLineIdsStreamProvider(orderId));

        return lineIdsAsync.when(
          data: (lineIds) {
            if (lineIds.isEmpty) {
              return _buildEmptyState(FluentTheme.of(context));
            }

            return ListView.builder(
              itemCount: lineIds.length,
              itemBuilder: (context, index) {
                final lineId = lineIds[index];
                return ReactiveSaleOrderLine(
                  key: ValueKey(lineId),
                  lineId: lineId,
                  isEditing: false,
                  onTap: () {
                    // Could open line details in future
                  },
                );
              },
            );
          },
          loading: () => const Center(child: ProgressRing()),
          error: (error, _) => Center(
            child: Text(
              'Error cargando líneas: $error',
              style: TextStyle(color: Colors.red),
            ),
          ),
        );
      },
    );
  }

  Widget _buildEmptyState(FluentThemeData theme) {
    final spacing = ref.watch(themedSpacingProvider);
    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.lg),
        child: Center(
          child: Text(
            'No hay líneas en esta orden',
            style: theme.typography.body?.copyWith(color: theme.inactiveColor),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCards(List<SaleOrderLine> lines) {
    final sortedLines = lines.sortedBySequence;
    final visibleLines = sortedLines
        .where((line) => lines.shouldShowLine(line))
        .toList();

    // Use ListView.builder for scrollable list on mobile/tablet
    return ListView.builder(
      itemCount: visibleLines.length,
      itemBuilder: (context, index) {
        final line = visibleLines[index];
        return SalesOrderLineCard(
          line: line,
          index: index + 1,
          allLines: sortedLines,
          showPrice: lines.shouldShowPrice(line),
          isEditable: widget.isEditing,
          // Edit callbacks for mobile cards
          onUpdateQty: widget.isEditing
              ? (line, qty) => updateLineQty(line, qty)
              : null,
          onDelete: widget.isEditing
              ? (line) => _deleteLineWithFocus(context, line)
              : null,
          onUpdateDescription: widget.isEditing
              ? (line, desc) => updateLineName(line, desc)
              : null,
        );
      },
    );
  }

  // ============================================================================
  // TAB NAVIGATION & EMPTY LINE HANDLING
  // ============================================================================

  /// Called when Tab is pressed on the last line's code field
  /// Creates a new empty line ready for code input ONLY if current line is not empty
  bool _onTabOnLastLine(BuildContext context, int lineId) {
    if (!widget.isEditing) return false;

    // Find the current line to check if it's empty
    final lines = ref.read(saleOrderFormVisibleLinesProvider);
    final currentLine = lines.where((l) => l.id == lineId).firstOrNull;

    // Only create new line if current line has a product
    if (currentLine == null || currentLine.productId == null) {
      // Current line is empty - don't create a new one
      return false;
    }

    // Create a new empty line and focus on it
    _addEmptyLineAndFocus();

    // Return true to indicate we handled the Tab
    return true;
  }

  /// Handle Escape or focus lost on code cell
  /// If the line is empty (no product), delete it and focus appropriately:
  /// 1. Previous line's code cell (if exists)
  /// 2. Next line's code cell (if first line but others remain)
  /// 3. "Add product" button (if all lines deleted)
  void _handleCodeEscape(SaleOrderLine line) {
    if (!widget.isEditing) return;

    // Check if this is an empty line (no product selected)
    final isEmptyLine = line.productId == null &&
                        (line.productCode == null || line.productCode!.isEmpty) &&
                        line.name.isEmpty;

    if (isEmptyLine) {
      // Find position and adjacent lines before deleting
      final lines = ref.read(saleOrderFormVisibleLinesProvider);
      final productLines = lines.where((l) => l.isProductLine).toList();
      final currentIndex = productLines.indexWhere((l) => l.id == line.id);
      final previousLine = currentIndex > 0 ? productLines[currentIndex - 1] : null;
      final nextLine = currentIndex < productLines.length - 1
          ? productLines[currentIndex + 1]
          : null;
      final willHaveRemainingLines = productLines.length > 1;

      // Delete the empty line
      ref.read(saleOrderFormProvider.notifier).deleteLine(line.id);

      // Focus on appropriate cell after deletion
      // Use double addPostFrameCallback to ensure grid is rebuilt and FocusNodes are registered
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;

          if (previousLine != null) {
            // Focus previous line's code cell
            _gridKey.currentState?.focusLineCode(previousLine.id);
          } else if (nextLine != null && willHaveRemainingLines) {
            // First line deleted but others remain - focus next line
            _gridKey.currentState?.focusLineCode(nextLine.id);
          } else {
            // All lines deleted - focus add button
            _addProductButtonFocus.requestFocus();
          }
        });
      });
    }
    // If line has a product, the EditableTextCell already restored the original value
  }

  /// Delete a line and focus on the appropriate cell after deletion.
  /// Focus priority:
  /// 1. Previous line's code cell (if exists)
  /// 2. Next line's code cell (if first line deleted but others remain)
  /// 3. "Add product" button (if all lines deleted)
  Future<void> _deleteLineWithFocus(BuildContext context, SaleOrderLine line) async {
    if (!widget.isEditing) return;

    // Get current lines and find position before deletion
    final lines = ref.read(saleOrderFormVisibleLinesProvider);
    final productLines = lines.where((l) => l.isProductLine).toList();
    final currentIndex = productLines.indexWhere((l) => l.id == line.id);

    // Determine where to focus after deletion
    final previousLine = currentIndex > 0 ? productLines[currentIndex - 1] : null;
    final nextLine = currentIndex < productLines.length - 1
        ? productLines[currentIndex + 1]
        : null;
    final willHaveRemainingLines = productLines.length > 1;

    // Call the mixin's deleteLine which shows confirmation dialog
    final deleted = await deleteLine(context, line);

    if (!deleted || !mounted) return;

    // Focus on appropriate cell after deletion
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        if (previousLine != null) {
          // Focus previous line's code cell
          _gridKey.currentState?.focusLineCode(previousLine.id);
        } else if (nextLine != null && willHaveRemainingLines) {
          // First line deleted but others remain - focus next line
          _gridKey.currentState?.focusLineCode(nextLine.id);
        } else {
          // All lines deleted - focus add button
          _addProductButtonFocus.requestFocus();
        }
      });
    });
  }

  /// Add an empty line and focus on its code cell
  void _addEmptyLineAndFocus() {
    final newLine = SaleOrderLine(
      id: 0, // Will be assigned by provider
      lineUuid: 'temp_${DateTime.now().millisecondsSinceEpoch}',
      orderId: widget.orderId,
      sequence: 0, // Will be adjusted by provider
      displayType: LineDisplayType.product,
      name: '',
      productUomQty: 1.0,
      priceUnit: 0.0,
      discount: 0.0,
      priceSubtotal: 0.0,
      priceTax: 0.0,
      priceTotal: 0.0,
    );

    ref.read(saleOrderFormProvider.notifier).addLine(newLine);

    // Schedule focus on the new line's code cell after it's rendered
    // We need to get the actual line ID from the provider (it assigns a temp ID)
    // Use double post-frame callback to ensure widgets are built and FocusNodes registered
    WidgetsBinding.instance.addPostFrameCallback((_) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final lines = ref.read(saleOrderFormVisibleLinesProvider);
        final productLines = lines.where((l) => l.isProductLine).toList();
        if (productLines.isNotEmpty) {
          final lastLine = productLines.last;
          _gridKey.currentState?.focusLineCode(lastLine.id);
        }
      });
    });
  }

  /// Focus on the last line's code cell, or create a new line if no lines exist
  /// Called when entering edit mode
  void focusLastLineOrCreate() {
    final lines = ref.read(saleOrderFormVisibleLinesProvider);
    final productLines = lines.where((l) => l.isProductLine).toList();

    if (productLines.isEmpty) {
      // No lines - create a new one and focus
      _addEmptyLineAndFocus();
    } else {
      // Focus on the last product line's code cell
      // Use double post-frame callback to ensure grid is built and FocusNodes registered
      final lastLine = productLines.last;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _gridKey.currentState?.focusLineCode(lastLine.id);
        });
      });
    }
  }
}
