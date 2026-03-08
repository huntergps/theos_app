import 'package:fluent_ui/fluent_ui.dart';

import '../base/odoo_field_base.dart';
import '../config/odoo_field_config.dart';

/// A multiline text field (TextArea).
///
/// Usage:
/// ```dart
/// OdooMultilineField(
///   config: OdooFieldConfig(
///     label: 'Internal Notes',
///     isEditing: isEditMode,
///     prefixIcon: FluentIcons.edit_note,
///   ),
///   value: notes,
///   minLines: 3,
///   maxLines: 10,
///   onChanged: (value) => updateField('note', value),
/// )
///
/// // Stream mode — auto-refreshes:
/// OdooMultilineField(
///   config: OdooFieldConfig(label: 'Notes', isEditing: true),
///   stream: notesStream,
///   onChanged: (v) => manager.updateField(id, 'note', v),
/// )
/// ```
class OdooMultilineField extends OdooFieldBase<String> {
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final bool showCharCount;
  final bool expands;
  final String charCountSuffix;

  const OdooMultilineField({
    super.key,
    required super.config,
    required super.value,
    super.onChanged,
    super.stream,
    this.minLines = 3,
    this.maxLines = 10,
    this.maxLength,
    this.showCharCount = false,
    this.expands = false,
    this.charCountSuffix = 'characters',
  });

  @override
  String formatValue(String? value) {
    return value ?? '';
  }

  @override
  Widget buildViewMode(BuildContext context, FluentThemeData theme, String? effectiveValue) {
    final isEmpty = (effectiveValue ?? '').isEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                if (config.prefixIcon != null) ...[
                  Icon(config.prefixIcon, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  config.label,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(
              color: theme.inactiveColor.withValues(alpha: 0.3),
            ),
          ),
          child: Text(
            isEmpty ? '-' : effectiveValue!,
            style: theme.typography.body?.copyWith(
              color: isEmpty ? theme.inactiveColor : null,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildEditMode(BuildContext context, FluentThemeData theme, String? effectiveValue) {
    return buildEditLayout(
      context,
      theme,
      child: _MultilineInput(
        value: effectiveValue,
        hint: config.hint,
        minLines: minLines,
        maxLines: maxLines,
        maxLength: maxLength,
        showCharCount: showCharCount,
        expands: expands,
        charCountSuffix: charCountSuffix,
        onChanged: onChanged,
      ),
    );
  }
}

class _MultilineInput extends StatefulWidget {
  final String? value;
  final String? hint;
  final int minLines;
  final int maxLines;
  final int? maxLength;
  final bool showCharCount;
  final bool expands;
  final String charCountSuffix;
  final ValueChanged<String>? onChanged;

  const _MultilineInput({
    required this.value,
    this.hint,
    required this.minLines,
    required this.maxLines,
    this.maxLength,
    required this.showCharCount,
    required this.expands,
    required this.charCountSuffix,
    this.onChanged,
  });

  @override
  State<_MultilineInput> createState() => _MultilineInputState();
}

class _MultilineInputState extends State<_MultilineInput> {
  late TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value ?? '');
  }

  @override
  void didUpdateWidget(_MultilineInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value && widget.value != _controller.text) {
      _controller.text = widget.value ?? '';
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextBox(
          controller: _controller,
          placeholder: widget.hint,
          minLines: widget.minLines,
          maxLines: widget.expands ? null : widget.maxLines,
          maxLength: widget.maxLength,
          expands: widget.expands,
          onChanged: widget.onChanged,
        ),
        if (widget.showCharCount)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              widget.maxLength != null
                  ? '${_controller.text.length}/${widget.maxLength}'
                  : '${_controller.text.length} ${widget.charCountSuffix}',
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ),
      ],
    );
  }
}

/// A collapsible multiline field for long text.
class OdooCollapsibleTextField extends StatefulWidget {
  final OdooFieldConfig config;
  final String? value;
  final ValueChanged<String?>? onChanged;
  final int collapsedMaxLines;
  final int expandedMaxLines;
  final String showMoreLabel;
  final String showLessLabel;

  const OdooCollapsibleTextField({
    super.key,
    required this.config,
    required this.value,
    this.onChanged,
    this.collapsedMaxLines = 2,
    this.expandedMaxLines = 20,
    this.showMoreLabel = 'Show more',
    this.showLessLabel = 'Show less',
  });

  @override
  State<OdooCollapsibleTextField> createState() =>
      _OdooCollapsibleTextFieldState();
}

class _OdooCollapsibleTextFieldState
    extends State<OdooCollapsibleTextField> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isEmpty = (widget.value ?? '').isEmpty;

    final text = widget.value ?? '';
    final lines = '\n'.allMatches(text).length + 1;
    final needsExpand = lines > widget.collapsedMaxLines || text.length > 100;

    if (widget.config.isEditing) {
      return OdooMultilineField(
        config: widget.config,
        value: widget.value,
        onChanged: widget.onChanged,
        minLines: widget.collapsedMaxLines,
        maxLines: widget.expandedMaxLines,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.config.label.isNotEmpty && !widget.config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Row(
              children: [
                if (widget.config.prefixIcon != null) ...[
                  Icon(widget.config.prefixIcon, size: 14),
                  const SizedBox(width: 4),
                ],
                Text(
                  widget.config.label,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        GestureDetector(
          onTap: needsExpand
              ? () => setState(() => _isExpanded = !_isExpanded)
              : null,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: theme.inactiveColor.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isEmpty ? '-' : text,
                  style: theme.typography.body?.copyWith(
                    color: isEmpty ? theme.inactiveColor : null,
                  ),
                  maxLines: _isExpanded ? null : widget.collapsedMaxLines,
                  overflow: _isExpanded ? null : TextOverflow.ellipsis,
                ),
                if (needsExpand && !isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      _isExpanded ? widget.showLessLabel : widget.showMoreLabel,
                      style: theme.typography.caption?.copyWith(
                        color: theme.accentColor,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Backward-compatible aliases.
typedef ReactiveMultilineField = OdooMultilineField;
typedef ReactiveCollapsibleTextField = OdooCollapsibleTextField;
