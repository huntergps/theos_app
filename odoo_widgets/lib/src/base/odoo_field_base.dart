import 'package:fluent_ui/fluent_ui.dart';

import '../config/odoo_field_config.dart';
import '../theme/responsive.dart';
import '../theme/spacing.dart';

/// Base widget for building Odoo field widgets with optional stream support.
///
/// Handles common layout patterns for view and edit modes.
/// When [stream] is provided, the widget auto-refreshes when the stream emits.
/// State-management agnostic — no dependency on Riverpod, Bloc, or GetX.
abstract class OdooFieldBase<T> extends StatelessWidget {
  final OdooFieldConfig config;
  final T? value;
  final ValueChanged<T?>? onChanged;

  /// Optional stream that drives the field value reactively.
  /// When provided, the widget wraps itself in a [StreamBuilder] and
  /// auto-refreshes whenever the stream emits a new value.
  final Stream<T?>? stream;

  const OdooFieldBase({
    super.key,
    required this.config,
    required this.value,
    this.onChanged,
    this.stream,
  });

  @override
  Widget build(BuildContext context) {
    if (stream != null) {
      return StreamBuilder<T?>(
        stream: stream,
        initialData: value,
        builder: (context, snapshot) {
          if (snapshot.hasError && !snapshot.hasData) {
            return _buildStreamError(context, snapshot.error!);
          }
          return _buildField(context, snapshot.data);
        },
      );
    }
    return _buildField(context, value);
  }

  Widget _buildField(BuildContext context, T? effectiveValue) {
    final theme = FluentTheme.of(context);

    if (config.isEditing && config.isEnabled) {
      return buildEditMode(context, theme, effectiveValue);
    }

    return buildViewMode(context, theme, effectiveValue);
  }

  Widget _buildStreamError(BuildContext context, Object error) {
    final theme = FluentTheme.of(context);
    return Row(
      children: [
        Icon(FluentIcons.error, size: 14, color: Colors.red),
        const SizedBox(width: 4),
        Expanded(
          child: Text(
            error.toString(),
            style: theme.typography.caption?.copyWith(color: Colors.red),
          ),
        ),
      ],
    );
  }

  /// Build the field in view mode (read-only).
  Widget buildViewMode(BuildContext context, FluentThemeData theme, T? effectiveValue);

  /// Build the field in edit mode (editable).
  Widget buildEditMode(BuildContext context, FluentThemeData theme, T? effectiveValue);

  /// Format the value for display in view mode.
  String formatValue(T? value);

  /// Build the standard view layout with icon and text.
  /// Set [inline] to true for single-line layout: Icon Label: Value
  Widget buildViewLayout(
    BuildContext context,
    FluentThemeData theme, {
    T? effectiveValue,
    String? displayValue,
    bool inline = false,
    double? labelWidth,
  }) {
    final text = displayValue ?? formatValue(effectiveValue ?? value);
    final isEmpty = text.isEmpty || text == '-';
    final responsive = ResponsiveValues(context.deviceType);
    final effectiveLabelWidth = labelWidth ?? responsive.labelWidth;

    if (inline) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (config.prefixIcon != null) ...[
            Icon(
              config.prefixIcon,
              size: responsive.iconSize,
              color: theme.inactiveColor,
            ),
            SizedBox(width: Spacing.sm),
          ],
          if (config.label.isNotEmpty && !config.isCompact) ...[
            SizedBox(
              width: effectiveLabelWidth > 0 ? effectiveLabelWidth : null,
              child: Text(
                '${config.label}:',
                style: theme.typography.caption?.copyWith(
                  color: theme.inactiveColor,
                  fontSize: responsive.labelFontSize,
                ),
              ),
            ),
            if (effectiveLabelWidth <= 0) SizedBox(width: Spacing.sm),
          ],
          Expanded(
            child: Text(
              isEmpty ? '-' : text,
              style: theme.typography.body?.copyWith(
                color: isEmpty ? theme.inactiveColor : null,
                fontSize: responsive.valueFontSize,
              ),
            ),
          ),
        ],
      );
    }

    // Default stacked layout
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (config.prefixIcon != null) ...[
          Icon(
            config.prefixIcon,
            size: responsive.iconSize,
            color: isEmpty ? theme.inactiveColor : null,
          ),
          SizedBox(width: Spacing.sm),
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
                    fontSize: responsive.labelFontSize,
                  ),
                ),
              Text(
                isEmpty ? '-' : text,
                style: theme.typography.body?.copyWith(
                  color: isEmpty ? theme.inactiveColor : null,
                  fontSize: responsive.valueFontSize,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// Build inline edit layout: [Icon] Label: [Input]
  /// On mobile uses stacked layout automatically.
  Widget buildInlineEditLayout(
    BuildContext context,
    FluentThemeData theme, {
    required Widget child,
    double? labelWidth,
  }) {
    final responsive = ResponsiveValues(context.deviceType);
    final effectiveLabelWidth = labelWidth ?? responsive.labelWidth;

    if (responsive.useStackedLayout) {
      return buildEditLayout(context, theme, child: child);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (config.prefixIcon != null) ...[
          Icon(
            config.prefixIcon,
            size: responsive.iconSize,
            color: theme.inactiveColor,
          ),
          SizedBox(width: Spacing.sm),
        ],
        SizedBox(
          width: effectiveLabelWidth,
          child: Text(
            '${config.label}:',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
              fontSize: responsive.labelFontSize,
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }

  /// Build the standard edit layout with label and input.
  Widget buildEditLayout(
    BuildContext context,
    FluentThemeData theme, {
    required Widget child,
  }) {
    final responsive = ResponsiveValues(context.deviceType);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (config.label.isNotEmpty && !config.isCompact)
          Padding(
            padding: EdgeInsets.only(bottom: Spacing.xs),
            child: Row(
              children: [
                if (config.prefixIcon != null) ...[
                  Icon(config.prefixIcon, size: responsive.iconSize),
                  SizedBox(width: Spacing.xs),
                ],
                Text(
                  config.label,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w500,
                    fontSize: responsive.labelFontSize,
                  ),
                ),
                if (config.isRequired)
                  Text(' *', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
        child,
        if (config.errorMessage != null)
          Padding(
            padding: EdgeInsets.only(top: Spacing.xs),
            child: Text(
              config.errorMessage!,
              style: theme.typography.caption?.copyWith(color: Colors.red),
            ),
          ),
        if (config.helpText != null && config.errorMessage == null)
          Padding(
            padding: EdgeInsets.only(top: Spacing.xs),
            child: Text(
              config.helpText!,
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ),
      ],
    );
  }
}

/// Backward-compatible alias.
typedef ReactiveFieldBase<T> = OdooFieldBase<T>;
