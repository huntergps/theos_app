import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart';

/// Base widget for number input with validation, formatting, and optional stepper buttons.
///
/// Supports integer and decimal values, min/max validation, decimal places formatting,
/// optional increment/decrement buttons, suffix text, and flexible or fixed sizing.
class NumberInputBase extends StatefulWidget {
  final num? value;
  final ValueChanged<num>? onChanged;
  final num? min;
  final num? max;
  final int decimals;
  final num step;
  final bool showButtons;
  final String? suffix;
  final bool allowNegative;
  final bool selectAllOnFocus;
  final String? hint;
  final TextAlign textAlign;
  final double? width;
  final double? height;
  final bool expand;
  final TextStyle? textStyle;
  final EdgeInsets? padding;
  final FocusNode? focusNode;
  final KeyEventResult Function(FocusNode node, KeyEvent event)? onKeyEvent;

  const NumberInputBase({
    super.key,
    required this.value,
    this.onChanged,
    this.min,
    this.max,
    this.decimals = 0,
    this.step = 1,
    this.showButtons = false,
    this.suffix,
    this.allowNegative = false,
    this.selectAllOnFocus = true,
    this.hint,
    this.textAlign = TextAlign.right,
    this.width,
    this.height = 32,
    this.expand = false,
    this.textStyle,
    this.padding,
    this.focusNode,
    this.onKeyEvent,
  });

  @override
  State<NumberInputBase> createState() => _NumberInputBaseState();
}

class _NumberInputBaseState extends State<NumberInputBase> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: _formatForEdit(widget.value));

    if (widget.focusNode != null) {
      _focusNode = widget.focusNode!;
      _ownsFocusNode = false;
    } else {
      _focusNode = FocusNode();
      _ownsFocusNode = true;
    }

    _focusNode.addListener(() {
      if (_focusNode.hasFocus && widget.selectAllOnFocus) {
        _controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: _controller.text.length,
        );
      } else if (!_focusNode.hasFocus) {
        _parseAndNotify();
      }
    });
  }

  @override
  void didUpdateWidget(NumberInputBase oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value) {
      final currentText = _controller.text.trim().replaceAll(',', '.');
      final currentValue = num.tryParse(currentText);
      if (currentValue != widget.value) {
        _controller.text = _formatForEdit(widget.value);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    if (_ownsFocusNode) {
      _focusNode.dispose();
    }
    super.dispose();
  }

  String _formatForEdit(num? value) {
    if (value == null) return '';
    if (widget.decimals == 0) {
      return value.toInt().toString();
    }
    return value.toStringAsFixed(widget.decimals);
  }

  void _parseAndNotify() {
    final text = _controller.text.trim().replaceAll(',', '.');
    if (text.isEmpty) {
      final defaultValue = widget.min ?? 0;
      widget.onChanged?.call(defaultValue);
      return;
    }

    final parsed = num.tryParse(text);
    if (parsed != null) {
      var constrained = parsed;

      final minValue = widget.min;
      if (minValue != null && constrained < minValue) {
        constrained = minValue;
      }
      final maxValue = widget.max;
      if (maxValue != null && constrained > maxValue) {
        constrained = maxValue;
      }
      if (!widget.allowNegative && constrained < 0) {
        constrained = 0;
      }

      _controller.text = _formatForEdit(constrained);
      widget.onChanged?.call(constrained);
    }
  }

  void _increment() {
    final current = widget.value ?? (widget.min ?? 0);
    var newValue = current + widget.step;
    final maxValue = widget.max;
    if (maxValue != null && newValue > maxValue) {
      newValue = maxValue;
    }
    widget.onChanged?.call(newValue);
  }

  void _decrement() {
    final current = widget.value ?? (widget.min ?? 0);
    var newValue = current - widget.step;
    final minValue = widget.min;
    if (minValue != null && newValue < minValue) {
      newValue = minValue;
    }
    if (!widget.allowNegative && newValue < 0) {
      newValue = 0;
    }
    widget.onChanged?.call(newValue);
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isEnabled = widget.onChanged != null;

    final formatters = <TextInputFormatter>[
      FilteringTextInputFormatter.allow(
        widget.allowNegative
            ? RegExp(r'^-?\d*[.,]?\d*$')
            : RegExp(r'^\d*[.,]?\d*$'),
      ),
    ];

    final textBox = TextBox(
      controller: _controller,
      focusNode: _focusNode,
      placeholder: widget.hint,
      enabled: isEnabled,
      textAlign: widget.textAlign,
      keyboardType: TextInputType.numberWithOptions(
        decimal: widget.decimals > 0,
        signed: widget.allowNegative,
      ),
      inputFormatters: formatters,
      style: widget.textStyle ??
          theme.typography.body?.copyWith(fontWeight: FontWeight.w600),
      padding: widget.padding ??
          const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      suffix: widget.suffix != null
          ? Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(widget.suffix!),
            )
          : null,
      onSubmitted: (_) => _parseAndNotify(),
      onChanged: (text) {
        final parsed = num.tryParse(text.replaceAll(',', '.'));
        if (parsed != null) {
          final minValue = widget.min;
          if (minValue == null || parsed >= minValue) {
            final maxValue = widget.max;
            if (maxValue == null || parsed <= maxValue) {
              if (widget.allowNegative || parsed >= 0) {
                widget.onChanged?.call(parsed);
              }
            }
          }
        }
      },
    );

    final textBoxWithFocus = widget.onKeyEvent != null
        ? Focus(
            onKeyEvent: (node, event) {
              return widget.onKeyEvent!(_focusNode, event);
            },
            child: textBox,
          )
        : textBox;

    Widget sizedTextBox;
    if (widget.width != null) {
      sizedTextBox = SizedBox(
        width: widget.width,
        height: widget.height,
        child: textBoxWithFocus,
      );
    } else if (widget.expand) {
      sizedTextBox = Expanded(child: textBoxWithFocus);
    } else {
      sizedTextBox = textBoxWithFocus;
    }

    if (!widget.showButtons) {
      return sizedTextBox;
    }

    final buttonWidth = widget.height ?? 36.0;
    const buttonSpacing = 6.0;
    final totalButtonWidth = (buttonWidth * 2) + (buttonSpacing * 2);

    Widget textBoxForRow = sizedTextBox;
    final specifiedWidth = widget.width;
    if (specifiedWidth != null) {
      final availableWidth = specifiedWidth - totalButtonWidth;
      textBoxForRow = SizedBox(
        width: availableWidth > 0 ? availableWidth : specifiedWidth / 3,
        height: widget.height,
        child: textBoxWithFocus,
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: buttonWidth,
          height: widget.height,
          child: Button(
            style: ButtonStyle(
              padding: WidgetStateProperty.all(EdgeInsets.zero),
            ),
            onPressed:
                isEnabled && _canDecrement() ? () => _decrement() : null,
            child: const Icon(FluentIcons.remove, size: 18),
          ),
        ),
        const SizedBox(width: buttonSpacing),
        textBoxForRow,
        const SizedBox(width: buttonSpacing),
        SizedBox(
          width: buttonWidth,
          height: widget.height,
          child: Button(
            style: ButtonStyle(
              padding: WidgetStateProperty.all(EdgeInsets.zero),
            ),
            onPressed:
                isEnabled && _canIncrement() ? () => _increment() : null,
            child: const Icon(FluentIcons.add, size: 18),
          ),
        ),
      ],
    );
  }

  bool _canIncrement() {
    if (widget.max == null) return true;
    final current = widget.value ?? (widget.min ?? 0);
    return current < widget.max!;
  }

  bool _canDecrement() {
    final current = widget.value ?? (widget.min ?? 0);
    final minValue = widget.min;
    if (minValue != null && current <= minValue) return false;
    if (!widget.allowNegative && current <= 0) return false;
    return true;
  }
}
