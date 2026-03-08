import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

import '../base/number_input_base.dart';
import '../base/odoo_field_base.dart';

/// A number field for integers and decimals with optional stream.
class OdooNumberField extends OdooFieldBase<double> {
  final int decimals;
  final double? min;
  final double? max;
  final double step;
  final bool showButtons;
  final String? suffix;
  final bool allowNegative;
  final bool selectAllOnFocus;
  final String locale;

  const OdooNumberField({
    super.key,
    required super.config,
    required super.value,
    super.onChanged,
    super.stream,
    this.decimals = 2,
    this.min,
    this.max,
    this.step = 1,
    this.showButtons = false,
    this.suffix,
    this.allowNegative = false,
    this.selectAllOnFocus = true,
    this.locale = 'es',
  });

  @override
  String formatValue(double? value) {
    if (value == null) return '';
    final formatter = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: decimals,
    );
    return formatter.format(value);
  }

  @override
  Widget buildViewMode(BuildContext context, FluentThemeData theme, double? effectiveValue) {
    final displayValue = formatValue(effectiveValue);
    final fullText = suffix != null ? '$displayValue $suffix' : displayValue;
    return buildViewLayout(context, theme, effectiveValue: effectiveValue, displayValue: fullText);
  }

  @override
  Widget buildEditMode(BuildContext context, FluentThemeData theme, double? effectiveValue) {
    return buildEditLayout(
      context,
      theme,
      child: NumberInputBase(
        value: effectiveValue,
        decimals: decimals,
        min: min,
        max: max,
        step: step,
        showButtons: showButtons,
        suffix: suffix,
        allowNegative: allowNegative,
        selectAllOnFocus: selectAllOnFocus,
        hint: config.hint,
        onChanged: onChanged != null
            ? (value) => onChanged?.call(value.toDouble())
            : null,
        textAlign: TextAlign.right,
        expand: true,
      ),
    );
  }
}

/// A money field with currency formatting.
class OdooMoneyField extends OdooFieldBase<double> {
  final String currency;
  final bool showCurrency;
  final int decimals;
  final bool allowNegative;
  final bool highlightNegative;
  final String locale;

  const OdooMoneyField({
    super.key,
    required super.config,
    required super.value,
    super.onChanged,
    super.stream,
    this.currency = 'USD',
    this.showCurrency = true,
    this.decimals = 2,
    this.allowNegative = false,
    this.highlightNegative = true,
    this.locale = 'es',
  });

  @override
  String formatValue(double? value) {
    if (value == null) return '-';
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: showCurrency ? '\$' : '',
      decimalDigits: decimals,
    );
    return formatter.format(value);
  }

  @override
  Widget buildViewMode(BuildContext context, FluentThemeData theme, double? effectiveValue) {
    final isNegative = (effectiveValue ?? 0) < 0;
    final color = isNegative && highlightNegative ? Colors.red : null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.prefixIcon != null) ...[
          Icon(config.prefixIcon, size: 14),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (config.label.isNotEmpty && !config.isCompact)
                Text(
                  config.label,
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),
              Text(
                formatValue(effectiveValue),
                style: theme.typography.body?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  Widget buildEditMode(BuildContext context, FluentThemeData theme, double? effectiveValue) {
    return buildEditLayout(
      context,
      theme,
      child: NumberInputBase(
        value: effectiveValue,
        decimals: decimals,
        min: allowNegative ? null : 0,
        max: null,
        allowNegative: allowNegative,
        suffix: showCurrency ? currency : null,
        onChanged: onChanged != null
            ? (value) => onChanged?.call(value.toDouble())
            : null,
        textAlign: TextAlign.right,
        expand: true,
      ),
    );
  }
}

/// A percentage field (0-100).
class OdooPercentField extends OdooFieldBase<double> {
  final double maxPercent;
  final int decimals;

  const OdooPercentField({
    super.key,
    required super.config,
    required super.value,
    super.onChanged,
    super.stream,
    this.maxPercent = 100,
    this.decimals = 2,
  });

  @override
  String formatValue(double? value) {
    if (value == null) return '-';
    return '${value.toStringAsFixed(decimals)}%';
  }

  @override
  Widget buildViewMode(BuildContext context, FluentThemeData theme, double? effectiveValue) {
    return buildViewLayout(context, theme, effectiveValue: effectiveValue);
  }

  @override
  Widget buildEditMode(BuildContext context, FluentThemeData theme, double? effectiveValue) {
    return buildEditLayout(
      context,
      theme,
      child: NumberInputBase(
        value: effectiveValue,
        decimals: decimals,
        min: 0,
        max: maxPercent,
        suffix: '%',
        onChanged: onChanged != null
            ? (value) => onChanged?.call(value.toDouble())
            : null,
        textAlign: TextAlign.right,
        expand: true,
      ),
    );
  }
}

/// A reusable number input widget with optional stepper buttons.
class OdooNumberInput extends StatelessWidget {
  final num value;
  final ValueChanged<num>? onChanged;
  final num min;
  final num? max;
  final int decimalPlaces;
  final num step;
  final bool showSteppers;
  final double width;
  final double height;

  const OdooNumberInput({
    super.key,
    required this.value,
    this.onChanged,
    this.min = 0,
    this.max,
    this.decimalPlaces = 0,
    this.step = 1,
    this.showSteppers = true,
    this.width = 50,
    this.height = 28,
  });

  @override
  Widget build(BuildContext context) {
    return NumberInputBase(
      value: value,
      onChanged: onChanged,
      min: min,
      max: max,
      decimals: decimalPlaces,
      step: step,
      showButtons: showSteppers,
      textAlign: TextAlign.center,
      width: width,
      height: height,
      allowNegative: false,
    );
  }
}

/// Backward-compatible aliases.
typedef ReactiveNumberField = OdooNumberField;
typedef ReactiveMoneyField = OdooMoneyField;
typedef ReactivePercentField = OdooPercentField;
typedef ReactiveNumberInput = OdooNumberInput;
