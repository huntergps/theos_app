import 'package:fluent_ui/fluent_ui.dart';

import 'package:odoo_widgets/odoo_widgets.dart' show NumberInputBase;

/// A widget that displays a number as text in read-only mode,
/// and as an input with stepper buttons in editable mode.
///
/// Wraps [NumberInputBase] for the editing functionality.
///
/// Creates and manages its own FocusNode, registering it via callbacks
/// for external focus management (Tab navigation between cells).
class EditableNumberCell extends StatefulWidget {
  final double value;
  final bool isEditable;
  final ValueChanged<double>? onChanged;
  final int decimals;
  final double step;
  final double min;
  final double? max;
  final double? width;
  final double height;
  final TextAlign textAlign;
  final TextStyle? style;
  final String? suffix;

  /// Callback for Tab/keyboard navigation handling
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  /// Callbacks for FocusNode registration with parent DataSource
  final void Function(FocusNode node)? onFocusNodeCreated;
  final void Function(FocusNode node)? onFocusNodeDisposed;

  const EditableNumberCell({
    super.key,
    required this.value,
    this.isEditable = false,
    this.onChanged,
    this.decimals = 0,
    this.step = 1,
    this.min = 0,
    this.max,
    this.width,
    this.height = 28,
    this.textAlign = TextAlign.right,
    this.onKeyEvent,
    this.onFocusNodeCreated,
    this.onFocusNodeDisposed,
    this.style,
    this.suffix,
  });

  @override
  State<EditableNumberCell> createState() => _EditableNumberCellState();
}

class _EditableNumberCellState extends State<EditableNumberCell> {
  late FocusNode _focusNode;
  bool _isRegistered = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    // Register FocusNode if editable
    _registerIfNeeded();
  }

  @override
  void didUpdateWidget(EditableNumberCell oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Re-register when switching to editable mode
    if (widget.isEditable && !oldWidget.isEditable) {
      _registerIfNeeded();
    }
    // Unregister when switching to non-editable mode
    if (!widget.isEditable && oldWidget.isEditable) {
      _unregisterIfNeeded();
    }
  }

  void _registerIfNeeded() {
    if (widget.isEditable && !_isRegistered && widget.onFocusNodeCreated != null) {
      widget.onFocusNodeCreated!(_focusNode);
      _isRegistered = true;
    }
  }

  void _unregisterIfNeeded() {
    if (_isRegistered) {
      // Pass the node so registry can verify it's the same one before removing
      widget.onFocusNodeDisposed?.call(_focusNode);
      _isRegistered = false;
    }
  }

  @override
  void dispose() {
    // Unregister FocusNode from parent DataSource
    _unregisterIfNeeded();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isEditable) {
      return NumberInputBase(
        value: widget.value,
        min: widget.min,
        max: widget.max,
        decimals: widget.decimals,
        step: widget.step,
        showButtons: true,
        textAlign: widget.textAlign,
        width: widget.width,
        height: widget.height,
        focusNode: _focusNode,
        onKeyEvent: widget.onKeyEvent,
        suffix: widget.suffix,
        // Wrap onChanged to cast to double, NumberInputBase uses num
        onChanged:
            widget.onChanged != null ? (v) => widget.onChanged!(v.toDouble()) : null,
      );
    }

    // Read-only view
    return Container(
      width: widget.width,
      height: widget.height,
      alignment: _getAlignmentFromTextAlign(widget.textAlign),
      child: Text(
        _formatValue(widget.value),
        style: widget.style,
        textAlign: widget.textAlign,
      ),
    );
  }

  AlignmentGeometry _getAlignmentFromTextAlign(TextAlign textAlign) {
    switch (textAlign) {
      case TextAlign.left:
        return Alignment.centerLeft;
      case TextAlign.right:
        return Alignment.centerRight;
      case TextAlign.center:
        return Alignment.center;
      case TextAlign.justify:
        return Alignment.centerLeft;
      case TextAlign.start:
        return AlignmentDirectional.centerStart;
      case TextAlign.end:
        return AlignmentDirectional.centerEnd;
    }
  }

  String _formatValue(double value) {
    final formatted = value.toStringAsFixed(widget.decimals);
    if (widget.suffix != null) {
      return '$formatted ${widget.suffix}';
    }
    return formatted;
  }
}
