import 'package:fluent_ui/fluent_ui.dart';

import '../base/odoo_field_base.dart';
import '../config/odoo_field_config.dart';

/// A boolean field displayed as checkbox or toggle.
///
/// Usage:
/// ```dart
/// OdooBooleanField(
///   config: OdooFieldConfig(
///     label: 'Is final consumer',
///     isEditing: isEditMode,
///   ),
///   value: isFinalConsumer,
///   onChanged: (value) => updateField('is_final_consumer', value),
/// )
///
/// // Stream mode — auto-refreshes:
/// OdooBooleanField(
///   config: OdooFieldConfig(label: 'Active', isEditing: true),
///   stream: activeStream,
///   onChanged: (v) => manager.updateField(id, 'active', v),
/// )
/// ```
class OdooBooleanField extends OdooFieldBase<bool> {
  final bool asToggle;
  final String trueText;
  final String falseText;
  final bool inlineLabel;

  const OdooBooleanField({
    super.key,
    required super.config,
    required super.value,
    super.onChanged,
    super.stream,
    this.asToggle = false,
    this.trueText = 'Yes',
    this.falseText = 'No',
    this.inlineLabel = true,
  });

  @override
  String formatValue(bool? value) {
    if (value == null) return '-';
    return value ? trueText : falseText;
  }

  @override
  Widget buildViewMode(BuildContext context, FluentThemeData theme, bool? effectiveValue) {
    final isTrue = effectiveValue ?? false;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (config.prefixIcon != null) ...[
          Icon(config.prefixIcon, size: 14),
          const SizedBox(width: 8),
        ],
        if (config.label.isNotEmpty && !config.isCompact) ...[
          Text(
            '${config.label}: ',
            style: theme.typography.body?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: isTrue
                ? Colors.green.withValues(alpha: 0.1)
                : theme.inactiveColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            formatValue(effectiveValue),
            style: theme.typography.body?.copyWith(
              color: isTrue ? Colors.green : theme.inactiveColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget buildEditMode(BuildContext context, FluentThemeData theme, bool? effectiveValue) {
    if (asToggle) {
      return _buildToggle(theme, effectiveValue);
    }
    return _buildCheckbox(theme, effectiveValue);
  }

  Widget _buildCheckbox(FluentThemeData theme, bool? effectiveValue) {
    return Row(
      children: [
        if (config.prefixIcon != null) ...[
          Icon(config.prefixIcon, size: 14),
          const SizedBox(width: 8),
        ],
        Checkbox(
          checked: effectiveValue ?? false,
          onChanged: config.isEnabled
              ? (checked) => onChanged?.call(checked ?? false)
              : null,
          content: inlineLabel && config.label.isNotEmpty
              ? Text(config.label, style: theme.typography.body)
              : null,
        ),
      ],
    );
  }

  Widget _buildToggle(FluentThemeData theme, bool? effectiveValue) {
    return Row(
      children: [
        if (config.prefixIcon != null) ...[
          Icon(config.prefixIcon, size: 14),
          const SizedBox(width: 8),
        ],
        if (inlineLabel && config.label.isNotEmpty) ...[
          Text(config.label, style: theme.typography.body),
          const SizedBox(width: 8),
        ],
        ToggleSwitch(
          checked: effectiveValue ?? false,
          onChanged: config.isEnabled
              ? (checked) => onChanged?.call(checked)
              : null,
        ),
      ],
    );
  }
}

/// A tristate boolean (true/false/null).
class OdooTristateBooleanField extends StatelessWidget {
  final OdooFieldConfig config;
  final bool? value;
  final ValueChanged<bool?>? onChanged;
  final String trueText;
  final String falseText;
  final String nullText;

  const OdooTristateBooleanField({
    super.key,
    required this.config,
    required this.value,
    this.onChanged,
    this.trueText = 'Yes',
    this.falseText = 'No',
    this.nullText = 'Undefined',
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (!config.isEditing) {
      String text;
      Color color;

      if (value == null) {
        text = nullText;
        color = theme.inactiveColor;
      } else if (value!) {
        text = trueText;
        color = Colors.green;
      } else {
        text = falseText;
        color = Colors.red;
      }

      return Row(
        children: [
          if (config.prefixIcon != null) ...[
            Icon(config.prefixIcon, size: 14),
            const SizedBox(width: 8),
          ],
          if (config.label.isNotEmpty) ...[
            Text(
              '${config.label}: ',
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              text,
              style: theme.typography.body?.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      );
    }

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
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SegmentButton(
              label: falseText,
              isSelected: value == false,
              onTap: () => onChanged?.call(false),
            ),
            _SegmentButton(
              label: nullText,
              isSelected: value == null,
              onTap: () => onChanged?.call(null),
            ),
            _SegmentButton(
              label: trueText,
              isSelected: value == true,
              onTap: () => onChanged?.call(true),
            ),
          ],
        ),
      ],
    );
  }
}

class _SegmentButton extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _SegmentButton({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? theme.accentColor : theme.cardColor,
          border: Border.all(
            color: isSelected ? theme.accentColor : theme.inactiveColor,
          ),
        ),
        child: Text(
          label,
          style: theme.typography.body?.copyWith(
            color: isSelected ? Colors.white : null,
          ),
        ),
      ),
    );
  }
}

/// Backward-compatible aliases.
typedef ReactiveBooleanField = OdooBooleanField;
typedef ReactiveTristateBooleanField = OdooTristateBooleanField;
