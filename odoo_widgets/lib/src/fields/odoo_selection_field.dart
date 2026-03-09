import 'package:fluent_ui/fluent_ui.dart';

import '../base/odoo_field_base.dart';
import '../config/odoo_field_config.dart';

/// Option for selection fields.
class SelectionOption<T> {
  final T value;
  final String label;
  final IconData? icon;
  final Color? color;
  final bool isDisabled;

  const SelectionOption({
    required this.value,
    required this.label,
    this.icon,
    this.color,
    this.isDisabled = false,
  });
}

/// A selection field (dropdown/combobox).
///
/// Usage:
/// ```dart
/// OdooSelectionField<String>(
///   config: OdooFieldConfig(label: 'Status', isEditing: isEditMode),
///   value: state,
///   options: [
///     SelectionOption(value: 'draft', label: 'Draft'),
///     SelectionOption(value: 'sale', label: 'Confirmed', color: Colors.green),
///     SelectionOption(value: 'cancel', label: 'Cancelled', color: Colors.red),
///   ],
///   onChanged: (value) => updateField('state', value),
/// )
///
/// // Stream mode — auto-refreshes:
/// OdooSelectionField<String>(
///   config: OdooFieldConfig(label: 'Status', isEditing: true),
///   stream: stateStream,
///   options: [...],
///   onChanged: (v) => manager.updateField(id, 'state', v),
/// )
/// ```
class OdooSelectionField<T> extends OdooFieldBase<T> {
  final List<SelectionOption<T>> options;
  final bool asRadio;
  final bool asSegmented;
  final String placeholder;

  const OdooSelectionField({
    super.key,
    required super.config,
    required super.value,
    required this.options,
    super.onChanged,
    super.stream,
    this.asRadio = false,
    this.asSegmented = false,
    this.placeholder = 'Select...',
  });

  @override
  String formatValue(T? value) {
    if (value == null) return '-';
    final option = options.firstWhere(
      (o) => o.value == value,
      orElse: () => SelectionOption(value: value, label: value.toString()),
    );
    return option.label;
  }

  @override
  Widget buildViewMode(BuildContext context, FluentThemeData theme, T? effectiveValue) {
    final option = effectiveValue != null
        ? options.firstWhere(
            (o) => o.value == effectiveValue,
            orElse: () => SelectionOption(value: effectiveValue, label: '-'),
          )
        : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (config.prefixIcon != null) ...[
          Icon(config.prefixIcon, size: 14, color: theme.inactiveColor),
          const SizedBox(width: 8),
        ],
        if (config.label.isNotEmpty && !config.isCompact) ...[
          Text(
            '${config.label}:',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (option != null) ...[
          if (option.icon != null) ...[
            Icon(option.icon, size: 14, color: option.color),
            const SizedBox(width: 4),
          ],
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: option.color != null
                ? BoxDecoration(
                    color: option.color!.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  )
                : null,
            child: Text(
              option.label,
              style: theme.typography.body?.copyWith(
                color: option.color,
                fontWeight: option.color != null ? FontWeight.w500 : null,
              ),
            ),
          ),
        ] else
          Text('-', style: theme.typography.body),
      ],
    );
  }

  @override
  Widget buildEditMode(BuildContext context, FluentThemeData theme, T? effectiveValue) {
    if (asSegmented) {
      return _buildSegmented(theme, effectiveValue);
    }
    if (asRadio) {
      return _buildRadio(theme, effectiveValue);
    }
    return _buildComboBox(context, theme, effectiveValue);
  }

  Widget _buildComboBox(BuildContext context, FluentThemeData theme, T? effectiveValue) {
    final selectedOption = effectiveValue != null
        ? options.firstWhere(
            (o) => o.value == effectiveValue,
            orElse: () => SelectionOption(value: effectiveValue, label: '-'),
          )
        : null;
    final displayText = selectedOption?.label ?? placeholder;
    final isEmpty = selectedOption == null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (config.prefixIcon != null) ...[
          Icon(config.prefixIcon, size: 14, color: theme.inactiveColor),
          const SizedBox(width: 8),
        ],
        SizedBox(
          width: 130,
          child: Text(
            '${config.label}:',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
        ),
        Expanded(
          child: _InlineSelectionButton<T>(
            displayText: displayText,
            isEmpty: isEmpty,
            selectedColor: selectedOption?.color,
            options: options,
            currentValue: effectiveValue,
            onSelected: onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildRadio(FluentThemeData theme, T? effectiveValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
                if (config.isRequired)
                  Text(' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        RadioGroup<T?>(
          groupValue: effectiveValue,
          onChanged: (v) {
            if (config.isEnabled && v != null) onChanged?.call(v);
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: options.map((option) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: RadioButton<T?>(
                  value: option.value,
                  content: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (option.icon != null) ...[
                        Icon(option.icon, size: 14, color: option.color),
                        const SizedBox(width: 4),
                      ],
                      Text(
                        option.label,
                        style: TextStyle(color: option.color),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSegmented(FluentThemeData theme, T? effectiveValue) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
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
        Wrap(
          spacing: 0,
          children: options.asMap().entries.map((entry) {
            final index = entry.key;
            final option = entry.value;
            final isSelected = effectiveValue == option.value;
            final isFirst = index == 0;
            final isLast = index == options.length - 1;

            return GestureDetector(
              onTap: config.isEnabled && !option.isDisabled
                  ? () => onChanged?.call(option.value)
                  : null,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? (option.color ?? theme.accentColor)
                      : theme.cardColor,
                  border: Border.all(
                    color: isSelected
                        ? (option.color ?? theme.accentColor)
                        : theme.inactiveColor.withValues(alpha: 0.5),
                  ),
                  borderRadius: BorderRadius.horizontal(
                    left: isFirst ? const Radius.circular(4) : Radius.zero,
                    right: isLast ? const Radius.circular(4) : Radius.zero,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (option.icon != null) ...[
                      Icon(
                        option.icon,
                        size: 14,
                        color: isSelected ? Colors.white : option.color,
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      option.label,
                      style: theme.typography.body?.copyWith(
                        color: isSelected ? Colors.white : option.color,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Inline selection button with hover effect.
class _InlineSelectionButton<T> extends StatelessWidget {
  final String displayText;
  final bool isEmpty;
  final Color? selectedColor;
  final List<SelectionOption<T>> options;
  final T? currentValue;
  final ValueChanged<T?>? onSelected;

  const _InlineSelectionButton({
    required this.displayText,
    required this.isEmpty,
    this.selectedColor,
    required this.options,
    this.currentValue,
    this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return HoverButton(
      onPressed: () => _showSelectionMenu(context),
      builder: (context, states) {
        final isHovered = states.isHovered;
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: isHovered
                ? theme.accentColor.withValues(alpha: 0.1)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (selectedColor != null && !isEmpty) ...[
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: selectedColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ],
              Expanded(
                child: Text(
                  displayText,
                  style: theme.typography.body?.copyWith(
                    color: isEmpty ? theme.inactiveColor : theme.accentColor,
                  ),
                ),
              ),
              if (isHovered)
                Icon(
                  FluentIcons.chevron_down,
                  size: 12,
                  color: theme.accentColor,
                ),
            ],
          ),
        );
      },
    );
  }

  void _showSelectionMenu(BuildContext context) {
    final theme = FluentTheme.of(context);
    final RenderBox button = context.findRenderObject() as RenderBox;
    final RenderBox overlay =
        Navigator.of(context).overlay!.context.findRenderObject() as RenderBox;
    final Offset position =
        button.localToGlobal(Offset.zero, ancestor: overlay);

    showDialog(
      context: context,
      barrierColor: Colors.transparent,
      builder: (context) => Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.of(context).pop(),
              child: Container(color: Colors.transparent),
            ),
          ),
          Positioned(
            left: position.dx,
            top: position.dy + button.size.height + 4,
            child: Container(
              constraints: BoxConstraints(
                minWidth: button.size.width,
                maxWidth: 250,
                maxHeight: 300,
              ),
              decoration: BoxDecoration(
                color: theme.menuColor,
                borderRadius: BorderRadius.circular(6),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: options.map((option) {
                    final isSelected = currentValue == option.value;
                    return HoverButton(
                      onPressed: option.isDisabled
                          ? null
                          : () {
                              Navigator.of(context).pop();
                              onSelected?.call(option.value);
                            },
                      builder: (context, states) {
                        final isHovered = states.isHovered;
                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? theme.accentColor.withValues(alpha: 0.1)
                                : isHovered
                                    ? theme.inactiveColor.withValues(alpha: 0.1)
                                    : Colors.transparent,
                          ),
                          child: Row(
                            children: [
                              if (option.color != null) ...[
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 8),
                                  decoration: BoxDecoration(
                                    color: option.color,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                              if (option.icon != null) ...[
                                Icon(
                                  option.icon,
                                  size: 14,
                                  color: option.color ??
                                      theme.typography.body?.color,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                child: Text(
                                  option.label,
                                  style: theme.typography.body?.copyWith(
                                    color: option.isDisabled
                                        ? theme.inactiveColor
                                        : option.color,
                                    fontWeight:
                                        isSelected ? FontWeight.w600 : null,
                                  ),
                                ),
                              ),
                              if (isSelected)
                                Icon(
                                  FluentIcons.check_mark,
                                  size: 12,
                                  color: theme.accentColor,
                                ),
                            ],
                          ),
                        );
                      },
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A status field that displays workflow states with progress indicator.
class OdooStatusField<T> extends StatelessWidget {
  final OdooFieldConfig config;
  final T? value;
  final List<SelectionOption<T>> states;
  final int Function(T) getStateIndex;

  const OdooStatusField({
    super.key,
    required this.config,
    required this.value,
    required this.states,
    required this.getStateIndex,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final currentIndex = value != null ? getStateIndex(value as T) : 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              config.label,
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        Row(
          children: states.asMap().entries.map((entry) {
            final index = entry.key;
            final state = entry.value;
            final isActive = index <= currentIndex;
            final isCurrent = index == currentIndex;
            final isLast = index == states.length - 1;

            return Expanded(
              child: Row(
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isActive
                          ? (state.color ?? theme.accentColor)
                          : theme.inactiveColor.withValues(alpha: 0.3),
                      border: isCurrent
                          ? Border.all(
                              color: state.color ?? theme.accentColor,
                              width: 2,
                            )
                          : null,
                    ),
                    child: Center(
                      child: state.icon != null
                          ? Icon(
                              state.icon,
                              size: 12,
                              color: isActive
                                  ? Colors.white
                                  : theme.inactiveColor,
                            )
                          : Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isActive
                                    ? Colors.white
                                    : theme.inactiveColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        height: 2,
                        color: isActive
                            ? (state.color ?? theme.accentColor)
                            : theme.inactiveColor.withValues(alpha: 0.3),
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 4),
        Row(
          children: states.map((state) {
            final isActive = states.indexOf(state) <= currentIndex;
            return Expanded(
              child: Text(
                state.label,
                style: theme.typography.caption?.copyWith(
                  color: isActive
                      ? (state.color ?? theme.accentColor)
                      : theme.inactiveColor,
                  fontWeight: isActive ? FontWeight.w500 : null,
                ),
                textAlign: TextAlign.center,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Backward-compatible aliases.
typedef ReactiveSelectionField<T> = OdooSelectionField<T>;
typedef ReactiveStatusField<T> = OdooStatusField<T>;
