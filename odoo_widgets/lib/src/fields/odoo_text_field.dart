import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter/services.dart' show TextCapitalization;

import '../base/odoo_field_base.dart';
import '../config/odoo_field_config.dart';

/// A text field that supports view and edit modes with optional stream.
///
/// Usage:
/// ```dart
/// OdooTextField(
///   config: OdooFieldConfig(label: 'Name', isEditing: isEditMode),
///   value: customerName,
///   onChanged: (value) => updateField('name', value),
/// )
///
/// // Stream mode — auto-refreshes:
/// OdooTextField(
///   config: OdooFieldConfig(label: 'Name', isEditing: true),
///   stream: nameStream,
///   onChanged: (v) => manager.updateField(id, 'name', v),
/// )
/// ```
class OdooTextField extends StatefulWidget {
  final OdooFieldConfig config;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final Stream<String?>? stream;
  final int maxLines;
  final int minLines;
  final TextInputType keyboardType;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final Widget? suffix;
  final VoidCallback? onSubmitted;
  final bool autofocus;

  const OdooTextField({
    super.key,
    required this.config,
    this.value,
    this.onChanged,
    this.stream,
    this.maxLines = 1,
    this.minLines = 1,
    this.keyboardType = TextInputType.text,
    this.obscureText = false,
    this.textCapitalization = TextCapitalization.none,
    this.suffix,
    this.onSubmitted,
    this.autofocus = false,
  });

  @override
  State<OdooTextField> createState() => _OdooTextFieldState();
}

class _OdooTextFieldState extends State<OdooTextField> {
  late TextEditingController _controller;
  late FocusNode _focusNode;
  StreamSubscription<String?>? _subscription;
  String? _streamValue;

  @override
  void initState() {
    super.initState();
    _streamValue = widget.value;
    _controller = TextEditingController(text: widget.value ?? '');
    _focusNode = FocusNode();
    _listenToStream();
  }

  void _listenToStream() {
    _subscription?.cancel();
    if (widget.stream != null) {
      _subscription = widget.stream!.listen(
        (value) {
          if (mounted) {
            setState(() => _streamValue = value);
            if (!_focusNode.hasFocus) {
              _controller.text = value ?? '';
            }
          }
        },
        onError: (_) {},
      );
    }
  }

  @override
  void didUpdateWidget(OdooTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stream != oldWidget.stream) {
      _listenToStream();
    }
    final effectiveValue = widget.stream != null ? _streamValue : widget.value;
    final oldEffectiveValue = oldWidget.stream != null ? _streamValue : oldWidget.value;
    if (effectiveValue != oldEffectiveValue && !_focusNode.hasFocus) {
      _controller.text = effectiveValue ?? '';
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  String get _effectiveValue => widget.stream != null ? (_streamValue ?? '') : (widget.value ?? '');

  String _formatValue(String? value) {
    return value ?? '';
  }

  @override
  Widget build(BuildContext context) {
    if (widget.config.isEditing && widget.config.isEnabled) {
      return _OdooTextFieldEdit(
        config: widget.config,
        controller: _controller,
        focusNode: _focusNode,
        maxLines: widget.maxLines,
        minLines: widget.minLines,
        keyboardType: widget.keyboardType,
        obscureText: widget.obscureText,
        textCapitalization: widget.textCapitalization,
        autofocus: widget.autofocus,
        suffix: widget.suffix,
        hint: widget.config.hint,
        onChanged: widget.onChanged,
        onSubmitted: widget.onSubmitted,
      );
    }

    return _OdooTextFieldView(
      config: widget.config,
      value: _effectiveValue,
      formatValue: _formatValue,
    );
  }
}

class _OdooTextFieldView extends OdooFieldBase<String> {
  final String Function(String?) _formatValueFn;

  const _OdooTextFieldView({
    required super.config,
    required super.value,
    required String Function(String?) formatValue,
  })  : _formatValueFn = formatValue,
        super(onChanged: null);

  @override
  String formatValue(String? value) => _formatValueFn(value);

  @override
  Widget buildViewMode(BuildContext context, FluentThemeData theme, String? effectiveValue) {
    return buildViewLayout(context, theme, effectiveValue: effectiveValue);
  }

  @override
  Widget buildEditMode(BuildContext context, FluentThemeData theme, String? effectiveValue) {
    throw UnimplementedError();
  }
}

class _OdooTextFieldEdit extends OdooFieldBase<String> {
  final TextEditingController controller;
  final FocusNode focusNode;
  final int maxLines;
  final int minLines;
  final TextInputType keyboardType;
  final bool obscureText;
  final TextCapitalization textCapitalization;
  final bool autofocus;
  final Widget? suffix;
  final String? hint;
  final VoidCallback? onSubmitted;

  const _OdooTextFieldEdit({
    required super.config,
    required this.controller,
    required this.focusNode,
    required this.maxLines,
    required this.minLines,
    required this.keyboardType,
    required this.obscureText,
    required this.textCapitalization,
    required this.autofocus,
    this.suffix,
    this.hint,
    super.onChanged,
    this.onSubmitted,
  }) : super(value: null);

  @override
  String formatValue(String? value) => value ?? '';

  @override
  Widget buildViewMode(BuildContext context, FluentThemeData theme, String? effectiveValue) {
    throw UnimplementedError();
  }

  @override
  Widget buildEditMode(BuildContext context, FluentThemeData theme, String? effectiveValue) {
    return buildEditLayout(
      context,
      theme,
      child: TextBox(
        controller: controller,
        focusNode: focusNode,
        placeholder: hint ?? config.hint,
        maxLines: maxLines,
        minLines: minLines,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textCapitalization: textCapitalization,
        autofocus: autofocus,
        suffix: suffix,
        onChanged: onChanged,
        onSubmitted: onSubmitted != null ? (_) => onSubmitted!() : null,
      ),
    );
  }
}

/// A text field that auto-saves on blur (inline editing).
class OdooInlineTextField extends StatefulWidget {
  final OdooFieldConfig config;
  final String? value;
  final Future<void> Function(String) onSave;
  final String? Function(String)? validator;
  final Stream<String?>? stream;

  const OdooInlineTextField({
    super.key,
    required this.config,
    this.value,
    required this.onSave,
    this.validator,
    this.stream,
  });

  @override
  State<OdooInlineTextField> createState() => _OdooInlineTextFieldState();
}

class _OdooInlineTextFieldState extends State<OdooInlineTextField> {
  late TextEditingController _controller;
  bool _isEditing = false;
  bool _isSaving = false;
  String? _error;
  String? _originalValue;
  StreamSubscription<String?>? _subscription;
  String? _streamValue;

  @override
  void initState() {
    super.initState();
    _streamValue = widget.value;
    _controller = TextEditingController(text: widget.value ?? '');
    _originalValue = widget.value;
    _listenToStream();
  }

  void _listenToStream() {
    _subscription?.cancel();
    if (widget.stream != null) {
      _subscription = widget.stream!.listen(
        (value) {
          if (mounted && !_isEditing) {
            setState(() {
              _streamValue = value;
              _controller.text = value ?? '';
              _originalValue = value;
            });
          }
        },
        onError: (_) {},
      );
    }
  }

  @override
  void didUpdateWidget(OdooInlineTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.stream != oldWidget.stream) {
      _listenToStream();
    }
    if (!_isEditing && widget.value != oldWidget.value) {
      _controller.text = widget.value ?? '';
      _originalValue = widget.value;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  String? get _effectiveValue => widget.stream != null ? _streamValue : widget.value;

  Future<void> _handleSave() async {
    final newValue = _controller.text.trim();

    if (newValue == (_originalValue ?? '')) {
      setState(() => _isEditing = false);
      return;
    }

    if (widget.validator != null) {
      final error = widget.validator!(newValue);
      if (error != null) {
        setState(() => _error = error);
        return;
      }
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      await widget.onSave(newValue);
      _originalValue = newValue;
      setState(() => _isEditing = false);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _handleCancel() {
    _controller.text = _originalValue ?? '';
    setState(() {
      _isEditing = false;
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (!widget.config.isEditing) {
      return _buildViewMode(theme);
    }

    if (!_isEditing) {
      return GestureDetector(
        onTap: () => setState(() => _isEditing = true),
        child: MouseRegion(
          cursor: SystemMouseCursors.text,
          child: _buildViewMode(theme, showEditHint: true),
        ),
      );
    }

    return _buildEditMode(theme);
  }

  Widget _buildViewMode(FluentThemeData theme, {bool showEditHint = false}) {
    final displayValue = _effectiveValue;
    final isEmpty = (displayValue ?? '').isEmpty;

    return Row(
      children: [
        if (widget.config.prefixIcon != null) ...[
          Icon(
            widget.config.prefixIcon,
            size: 14,
            color: isEmpty ? theme.inactiveColor : null,
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            isEmpty ? (widget.config.hint ?? '-') : displayValue!,
            style: theme.typography.body?.copyWith(
              color: isEmpty ? theme.inactiveColor : null,
            ),
          ),
        ),
        if (showEditHint)
          Icon(
            FluentIcons.edit,
            size: 12,
            color: theme.inactiveColor,
          ),
      ],
    );
  }

  Widget _buildEditMode(FluentThemeData theme) {
    return Row(
      children: [
        if (widget.config.prefixIcon != null) ...[
          Icon(widget.config.prefixIcon, size: 14),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextBox(
                controller: _controller,
                placeholder: widget.config.hint,
                autofocus: true,
                enabled: !_isSaving,
                onSubmitted: (_) => _handleSave(),
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    _error!,
                    style: theme.typography.caption?.copyWith(
                      color: Colors.red,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 4),
        if (_isSaving)
          const SizedBox(
            width: 20,
            height: 20,
            child: ProgressRing(strokeWidth: 2),
          )
        else ...[
          IconButton(
            icon: Icon(FluentIcons.check_mark, size: 14, color: Colors.green),
            onPressed: _handleSave,
          ),
          IconButton(
            icon: Icon(FluentIcons.cancel, size: 14, color: Colors.red),
            onPressed: _handleCancel,
          ),
        ],
      ],
    );
  }
}

/// Backward-compatible aliases.
typedef ReactiveTextField = OdooTextField;
typedef ReactiveInlineTextField = OdooInlineTextField;
