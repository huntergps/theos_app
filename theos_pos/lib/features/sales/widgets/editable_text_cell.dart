import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'editable_cell_type.dart';

/// Editable text cell widget that triggers callback on Enter or focus loss
///
/// Supports Tab navigation:
/// - Physical keyboard: intercepts KeyDownEvent for Tab key
/// - Virtual keyboard: Uses TextInputAction.next
///
/// For product code cells, use [onCodeSubmit] instead of [onChanged] to get
/// async validation with result-based navigation.
///
/// NOTE: This is for TEXT inputs (names, notes, codes).
/// For quantity/numeric inputs, use [EditableNumberCell].
class EditableTextCell extends ConsumerStatefulWidget {
  final String initialValue;

  /// Simple callback for value changes (non-async, always navigates)
  /// Use this for simple text fields like names, notes, etc.
  final void Function(String value)? onChanged;

  /// Async callback for code validation with result
  /// Use this for product code cells that need validation before navigation
  /// Returns ProductCodeSearchResult to determine navigation behavior
  final Future<ProductCodeSearchResult> Function(String value)? onCodeSubmit;

  /// Callback when Escape is pressed or focus lost without valid submission
  /// Used to restore original value or delete empty lines
  final VoidCallback? onEscape;

  final TextStyle? style;
  final TextAlign textAlign;
  final Widget? suffix;

  /// Cell type for Tab navigation
  final EditableCellType cellType;

  /// Line ID for identifying which line this cell belongs to
  final int lineId;

  /// Callback when Tab/Next is pressed - returns true if navigation was handled
  final bool Function(int lineId, EditableCellType cellType)? onTabNext;

  /// Callback when Previous is pressed - returns true if navigation was handled
  final bool Function(int lineId, EditableCellType cellType)? onTabPrevious;

  /// Callback to navigate to quantity cell on same line (for existing lines)
  final bool Function(int lineId)? onNavigateToQuantity;

  /// Callback when Arrow Up is pressed - navigate to same column on previous row
  final bool Function(int lineId, EditableCellType cellType)? onNavigateUp;

  /// Callback when Arrow Down is pressed - navigate to same column on next row
  final bool Function(int lineId, EditableCellType cellType)? onNavigateDown;

  /// Callbacks for FocusNode registration with parent DataSource
  final void Function(FocusNode node)? onFocusNodeCreated;
  final void Function(FocusNode node)? onFocusNodeDisposed;

  const EditableTextCell({
    super.key,
    required this.initialValue,
    this.onChanged,
    this.onCodeSubmit,
    this.onEscape,
    this.style,
    this.textAlign = TextAlign.left,
    this.suffix,
    this.cellType = EditableCellType.other,
    this.lineId = 0,
    this.onTabNext,
    this.onTabPrevious,
    this.onNavigateToQuantity,
    this.onNavigateUp,
    this.onNavigateDown,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
  }) : assert(
          onChanged != null || onCodeSubmit != null,
          'Either onChanged or onCodeSubmit must be provided',
        );

  @override
  ConsumerState<EditableTextCell> createState() => _EditableTextCellState();
}

class _EditableTextCellState extends ConsumerState<EditableTextCell> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  String _lastSubmittedValue = '';
  bool _isSubmitting = false;
  bool _escapedOrCancelled = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _lastSubmittedValue = widget.initialValue;
    _focusNode = FocusNode();
    _focusNode.addListener(_onFocusChange);

    // Register FocusNode with parent DataSource for Tab navigation
    widget.onFocusNodeCreated?.call(_focusNode);
  }

  @override
  void didUpdateWidget(EditableTextCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // CRITICAL: Only update the text if the cell does NOT have focus
    // If the user is currently editing this cell, we should NOT reset their input
    if (oldWidget.initialValue != widget.initialValue && !_focusNode.hasFocus) {
      _controller.text = widget.initialValue;
      _lastSubmittedValue = widget.initialValue;
    }
  }

  @override
  void dispose() {
    // Unregister FocusNode from parent DataSource
    // Pass the node so registry can verify it's the same one before removing
    widget.onFocusNodeDisposed?.call(_focusNode);

    _focusNode.removeListener(_onFocusChange);
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onFocusChange() {
    // Wrap in try-catch to handle Flutter KeyDownEvent bug on macOS
    try {
      if (_focusNode.hasFocus) {
        // Reset escape flag when gaining focus
        _escapedOrCancelled = false;
        // Seleccionar todo el texto para que se reemplace al escribir
        _selectAllText();
      } else {
        // Focus lost - handle based on whether escape was pressed
        if (_escapedOrCancelled) {
          // Escape was pressed or cancelled - restore original value
          _restoreOriginalValue();
        } else {
          // Normal focus loss - submit value
          _submitValue();
        }
      }
    } catch (e) {
      // Intentionally empty - focus handling errors are non-critical
    }
  }

  /// Seleccionar todo el texto del campo
  void _selectAllText() {
    if (_controller.text.isNotEmpty) {
      _controller.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _controller.text.length,
      );
    }
  }

  /// Restore the original value (used when Escape is pressed or validation fails)
  void _restoreOriginalValue() {
    _controller.text = widget.initialValue;
    _lastSubmittedValue = widget.initialValue;
    widget.onEscape?.call();
  }

  /// Submit value - handles both sync and async callbacks
  ///
  /// Navigation flow for code cells:
  ///   Code → Quantity → Discount → Code (next line)
  /// All successful code submissions navigate to Quantity on same line.
  Future<void> _submitValue({bool navigateOnSuccess = false}) async {
    if (_isSubmitting) return;

    final value = _controller.text.trim();

    // If value unchanged
    if (value == _lastSubmittedValue) {
      if (navigateOnSuccess) {
        // For code cells, go to quantity on same line (spreadsheet-like flow)
        if (widget.cellType == EditableCellType.code &&
            widget.onNavigateToQuantity != null) {
          widget.onNavigateToQuantity!(widget.lineId);
        } else if (widget.onTabNext != null) {
          widget.onTabNext!(widget.lineId, widget.cellType);
        }
      }
      return;
    }

    // If using async code validation
    if (widget.onCodeSubmit != null) {
      _isSubmitting = true;

      try {
        final result = await widget.onCodeSubmit!(value);

        if (!mounted) return;

        switch (result) {
          // ALL success cases navigate to quantity on same line
          case ProductCodeSearchResult.successExistingLine:
          case ProductCodeSearchResult.successNewLine:
          case ProductCodeSearchResult.multipleSelectedExisting:
          case ProductCodeSearchResult.multipleSelectedNew:
          case ProductCodeSearchResult.unchanged:
            _lastSubmittedValue = value;
            if (navigateOnSuccess && widget.onNavigateToQuantity != null) {
              widget.onNavigateToQuantity!(widget.lineId);
            }
            break;

          case ProductCodeSearchResult.notFound:
            // Product not found - keep focus, select text for easy correction
            // Do NOT update _lastSubmittedValue so we can restore on escape
            _focusNode.requestFocus();
            // Use Future.delayed to ensure focus is set before selecting
            Future.delayed(const Duration(milliseconds: 50), () {
              if (mounted && _focusNode.hasFocus) {
                _selectAllText();
              }
            });
            break;

          case ProductCodeSearchResult.cancelled:
            // User cancelled (from dialog) - restore original value
            _restoreOriginalValue();
            break;
        }
      } finally {
        _isSubmitting = false;
      }
    } else {
      // Simple sync callback (for non-code cells like names, notes)
      _lastSubmittedValue = value;
      widget.onChanged?.call(value);
      if (navigateOnSuccess && widget.onTabNext != null) {
        widget.onTabNext!(widget.lineId, widget.cellType);
      }
    }
  }

  /// Handle key events (Tab, Escape, Enter)
  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    // Handle Escape key - restore original value or delete empty line
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      _escapedOrCancelled = true;
      // Restore the text field to original value
      _controller.text = widget.initialValue;
      _lastSubmittedValue = widget.initialValue;
      // Call onEscape which handles line deletion and focus management
      // Don't call unfocus() here - if line is deleted, focus will be managed by parent
      widget.onEscape?.call();
      return KeyEventResult.handled;
    }

    // Handle Enter key - same navigation as Tab
    if (event.logicalKey == LogicalKeyboardKey.enter ||
        event.logicalKey == LogicalKeyboardKey.numpadEnter) {
      _submitValue(navigateOnSuccess: true);
      return KeyEventResult.handled;
    }

    // Handle Tab key for navigation
    if (event.logicalKey == LogicalKeyboardKey.tab && widget.onTabNext != null) {
      // Check for Shift+Tab
      final shiftPressed = HardwareKeyboard.instance.isShiftPressed;
      if (shiftPressed && widget.onTabPrevious != null) {
        _submitValue(navigateOnSuccess: false);
        widget.onTabPrevious!(widget.lineId, widget.cellType);
      } else {
        // Submit and navigate on success
        _submitValue(navigateOnSuccess: true);
      }
      return KeyEventResult.handled;
    }

    // Handle Arrow Up - navigate to same column on previous row
    if (event.logicalKey == LogicalKeyboardKey.arrowUp &&
        widget.onNavigateUp != null) {
      _submitValue(navigateOnSuccess: false);
      widget.onNavigateUp!(widget.lineId, widget.cellType);
      return KeyEventResult.handled;
    }

    // Handle Arrow Down - navigate to same column on next row
    if (event.logicalKey == LogicalKeyboardKey.arrowDown &&
        widget.onNavigateDown != null) {
      _submitValue(navigateOnSuccess: false);
      widget.onNavigateDown!(widget.lineId, widget.cellType);
      return KeyEventResult.handled;
    }

    return KeyEventResult.ignored;
  }

  /// Handle Enter key submission
  void _handleEnterSubmit(String _) {
    _submitValue(navigateOnSuccess: true);
  }

  /// Handle onEditingComplete - called when virtual keyboard "Next" button is pressed
  void _handleEditingComplete() {
    _submitValue(navigateOnSuccess: true);
  }

  @override
  Widget build(BuildContext context) {
    // For single-line cells with Tab navigation, use "next" action
    final TextInputAction inputAction = widget.onTabNext != null
        ? TextInputAction.next
        : TextInputAction.done;

    return Focus(
      onKeyEvent: _handleKeyEvent,
      child: TextBox(
        controller: _controller,
        focusNode: _focusNode,
        textAlign: widget.textAlign,
        style: widget.style,
        maxLines: 1,
        textInputAction: inputAction,
        // Submit on Enter key (physical keyboard)
        onSubmitted: _handleEnterSubmit,
        // Handle "Next" button on virtual keyboard
        onEditingComplete: _handleEditingComplete,
        suffix: widget.suffix,
      ),
    );
  }
}
