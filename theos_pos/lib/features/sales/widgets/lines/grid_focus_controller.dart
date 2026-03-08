import 'package:fluent_ui/fluent_ui.dart';

import '../editable_cell_type.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Centralized focus controller for sales order lines grid.
///
/// Manages:
/// - FocusNode registry for editable cells
/// - Tab/Shift+Tab navigation between cells
/// - New line creation on Tab from last line
///
/// Navigation flow (spreadsheet-like):
/// ```
/// Code → Quantity → Discount → Code (next line)
/// ```
///
/// Usage:
/// ```dart
/// final controller = GridFocusController(
///   getLines: () => lines,
///   onCreateNewLine: () => _addEmptyLine(),
/// );
///
/// // In cell widget:
/// EditableNumberCell(
///   focusNode: controller.getFocusNode(lineId, EditableCellType.quantity),
///   onKeyEvent: (node, event) => controller.handleKeyEvent(lineId, cellType, event),
/// )
/// ```
class GridFocusController {
  /// Callback to get current lines
  final List<SaleOrderLine> Function() getLines;

  /// Callback to create a new empty line (returns true if line was created)
  final bool Function()? onCreateNewLine;

  /// Callback when Tab is pressed on first line (Shift+Tab)
  final VoidCallback? onNavigateBeforeFirst;

  /// FocusNode registry: key = "lineId_cellType"
  final Map<String, FocusNode> _focusNodes = {};

  GridFocusController({
    required this.getLines,
    this.onCreateNewLine,
    this.onNavigateBeforeFirst,
  });

  /// Clean up all focus nodes
  void dispose() {
    for (final node in _focusNodes.values) {
      node.dispose();
    }
    _focusNodes.clear();
  }

  // ============================================================================
  // FOCUS NODE MANAGEMENT
  // ============================================================================

  String _key(int lineId, EditableCellType cellType) =>
      '${lineId}_${cellType.name}';

  /// Register a FocusNode for a cell
  void registerFocusNode(int lineId, EditableCellType cellType, FocusNode node) {
    _focusNodes[_key(lineId, cellType)] = node;
  }

  /// Unregister a FocusNode for a cell
  void unregisterFocusNode(int lineId, EditableCellType cellType) {
    _focusNodes.remove(_key(lineId, cellType));
  }

  /// Get FocusNode for a specific cell
  FocusNode? getFocusNode(int lineId, EditableCellType cellType) {
    return _focusNodes[_key(lineId, cellType)];
  }

  /// Request focus on a specific cell
  bool requestFocus(int lineId, EditableCellType cellType) {
    final node = getFocusNode(lineId, cellType);
    if (node != null && node.canRequestFocus) {
      node.requestFocus();
      return true;
    }
    return false;
  }

  /// Get or create FocusNode for a cell (for widgets that manage their own nodes)
  FocusNode getOrCreateFocusNode(int lineId, EditableCellType cellType) {
    final key = _key(lineId, cellType);
    return _focusNodes.putIfAbsent(key, () => FocusNode());
  }

  // ============================================================================
  // LINE HELPERS
  // ============================================================================

  List<SaleOrderLine> get _lines => getLines();

  int _getLineIndex(int lineId) {
    return _lines.indexWhere((l) => l.id == lineId);
  }

  /// Get the next product line index after the given line
  int? _getNextProductLineIndex(int afterLineId) {
    final currentIndex = _getLineIndex(afterLineId);
    if (currentIndex == -1) return null;

    for (int i = currentIndex + 1; i < _lines.length; i++) {
      if (_lines[i].isProductLine) {
        return i;
      }
    }
    return null;
  }

  /// Get the previous product line index before the given line
  int? _getPreviousProductLineIndex(int beforeLineId) {
    final currentIndex = _getLineIndex(beforeLineId);
    if (currentIndex == -1) return null;

    for (int i = currentIndex - 1; i >= 0; i--) {
      if (_lines[i].isProductLine) {
        return i;
      }
    }
    return null;
  }

  /// Check if a line is the last product line
  bool isLastProductLine(int lineId) {
    return _getNextProductLineIndex(lineId) == null;
  }

  /// Check if a line is the first product line
  bool isFirstProductLine(int lineId) {
    return _getPreviousProductLineIndex(lineId) == null;
  }

  /// Check if line has a product (not empty)
  bool lineHasProduct(int lineId) {
    final index = _getLineIndex(lineId);
    if (index == -1) return false;
    return _lines[index].productId != null;
  }

  // ============================================================================
  // NAVIGATION
  // ============================================================================

  /// Handle Tab navigation from a cell.
  ///
  /// Navigation flow:
  /// - Code → Quantity (same line)
  /// - Quantity → Discount (same line)
  /// - Discount → Code (next line, or create new line if last)
  ///
  /// Returns true if navigation was handled.
  bool handleTabNavigation(int lineId, EditableCellType cellType) {

    switch (cellType) {
      case EditableCellType.code:
        // Code → Quantity (same line)
        return requestFocus(lineId, EditableCellType.quantity);

      case EditableCellType.quantity:
        // Quantity → Discount (same line)
        return requestFocus(lineId, EditableCellType.discount);

      case EditableCellType.discount:
        // Discount → Code (next line)
        return _navigateToNextLineCode(lineId);

      case EditableCellType.name:
      case EditableCellType.other:
        // For other cell types, just move to next line's same cell type
        final nextIndex = _getNextProductLineIndex(lineId);
        if (nextIndex != null) {
          return requestFocus(_lines[nextIndex].id, cellType);
        }
        return false;
    }
  }

  /// Handle Shift+Tab navigation from a cell.
  ///
  /// Reverse flow:
  /// - Code → Discount (previous line)
  /// - Quantity → Code (same line)
  /// - Discount → Quantity (same line)
  ///
  /// Returns true if navigation was handled.
  bool handleShiftTabNavigation(int lineId, EditableCellType cellType) {

    switch (cellType) {
      case EditableCellType.code:
        // Code → Discount (previous line)
        return _navigateToPreviousLineDiscount(lineId);

      case EditableCellType.quantity:
        // Quantity → Code (same line)
        return requestFocus(lineId, EditableCellType.code);

      case EditableCellType.discount:
        // Discount → Quantity (same line)
        return requestFocus(lineId, EditableCellType.quantity);

      case EditableCellType.name:
      case EditableCellType.other:
        // For other cell types, just move to previous line's same cell type
        final prevIndex = _getPreviousProductLineIndex(lineId);
        if (prevIndex != null) {
          return requestFocus(_lines[prevIndex].id, cellType);
        }
        return false;
    }
  }

  /// Navigate to code cell on next line, creating new line if needed
  bool _navigateToNextLineCode(int currentLineId) {
    final nextIndex = _getNextProductLineIndex(currentLineId);

    if (nextIndex != null) {
      // Navigate to existing next line
      final nextLine = _lines[nextIndex];
      return requestFocus(nextLine.id, EditableCellType.code);
    }

    // On last line - check if we should create a new line
    if (lineHasProduct(currentLineId) && onCreateNewLine != null) {
      // Current line has product, create new empty line
      final created = onCreateNewLine!();
      if (created) {
        // Focus will be set when new line is rendered
        // The DataSource should auto-focus the new line's code cell
        return true;
      }
    }

    return false;
  }

  /// Navigate to discount cell on previous line
  bool _navigateToPreviousLineDiscount(int currentLineId) {
    final prevIndex = _getPreviousProductLineIndex(currentLineId);

    if (prevIndex != null) {
      final prevLine = _lines[prevIndex];
      return requestFocus(prevLine.id, EditableCellType.discount);
    }

    // On first line
    onNavigateBeforeFirst?.call();
    return false;
  }

  /// Focus the code cell of a specific line
  bool focusLineCode(int lineId) {
    return requestFocus(lineId, EditableCellType.code);
  }

  /// Focus the quantity cell of a specific line
  bool focusLineQuantity(int lineId) {
    return requestFocus(lineId, EditableCellType.quantity);
  }

  /// Focus the first editable cell of the first product line
  bool focusFirstLine() {
    for (final line in _lines) {
      if (line.isProductLine) {
        return requestFocus(line.id, EditableCellType.code);
      }
    }
    return false;
  }

  /// Focus the first editable cell of the last product line
  bool focusLastLine() {
    for (int i = _lines.length - 1; i >= 0; i--) {
      if (_lines[i].isProductLine) {
        return requestFocus(_lines[i].id, EditableCellType.code);
      }
    }
    return false;
  }
}
