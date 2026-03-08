import 'package:fluent_ui/fluent_ui.dart';
import 'package:intl/intl.dart';

/// A reactive summary row for displaying monetary values.
///
/// Supports:
/// - Single value display: Icon | Label | Amount
/// - Comparison display: Icon | Label | System | Manual | Difference
///
/// Usage:
/// ```dart
/// OdooSummaryRow(
///   icon: FluentIcons.money,
///   label: 'Total Cash',
///   amount: 1500.00,
///   highlightPositive: true,
/// )
///
/// OdooSummaryRow.comparison(
///   icon: FluentIcons.compare,
///   label: 'Checks',
///   systemAmount: 500.00,
///   manualAmount: 480.00,
/// )
/// ```
class OdooSummaryRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final double? amount;
  final double? systemAmount;
  final double? manualAmount;
  final bool isComparison;
  final bool highlightPositive;
  final bool highlightNegative;
  final bool showDifferenceOnly;
  final String? prefix;
  final String? suffix;
  final int decimals;
  final String locale;
  final TextStyle? labelStyle;
  final TextStyle? amountStyle;
  final Color? iconColor;
  final bool compact;

  /// Single value display.
  const OdooSummaryRow({
    super.key,
    this.icon,
    required this.label,
    required this.amount,
    this.highlightPositive = false,
    this.highlightNegative = true,
    this.prefix = '\$',
    this.suffix,
    this.decimals = 2,
    this.locale = 'es',
    this.labelStyle,
    this.amountStyle,
    this.iconColor,
    this.compact = false,
  })  : systemAmount = null,
        manualAmount = null,
        isComparison = false,
        showDifferenceOnly = false;

  /// Comparison display with system, manual, and difference.
  const OdooSummaryRow.comparison({
    super.key,
    this.icon,
    required this.label,
    required this.systemAmount,
    required this.manualAmount,
    this.showDifferenceOnly = false,
    this.prefix = '\$',
    this.suffix,
    this.decimals = 2,
    this.locale = 'es',
    this.labelStyle,
    this.amountStyle,
    this.iconColor,
    this.compact = false,
  })  : amount = null,
        isComparison = true,
        highlightPositive = false,
        highlightNegative = true;

  double get difference => (systemAmount ?? 0) - (manualAmount ?? 0);

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (isComparison) {
      return _buildComparisonRow(context, theme);
    }

    return _buildSingleRow(context, theme);
  }

  Widget _buildSingleRow(BuildContext context, FluentThemeData theme) {
    final displayAmount = amount ?? 0;
    final isPositive = displayAmount > 0;
    final isNegative = displayAmount < 0;

    Color? valueColor;
    if (highlightPositive && isPositive) {
      valueColor = Colors.green;
    } else if (highlightNegative && isNegative) {
      valueColor = Colors.red;
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: compact ? 12 : 14,
              color: iconColor ?? theme.inactiveColor,
            ),
            SizedBox(width: compact ? 6 : 8),
          ],
          Expanded(
            child: Text(
              label,
              style: labelStyle ??
                  (compact ? theme.typography.caption : theme.typography.body),
            ),
          ),
          Text(
            _formatAmount(displayAmount),
            style: (amountStyle ??
                    (compact
                        ? theme.typography.caption
                        : theme.typography.body))
                ?.copyWith(
              color: valueColor,
              fontWeight: valueColor != null ? FontWeight.w600 : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildComparisonRow(BuildContext context, FluentThemeData theme) {
    final diff = difference;
    final hasDifference = diff.abs() > 0.01;

    Color? diffColor;
    if (hasDifference) {
      diffColor = diff > 0 ? Colors.green : Colors.red;
    }

    if (showDifferenceOnly) {
      return Padding(
        padding: EdgeInsets.symmetric(vertical: compact ? 2 : 6),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: compact ? 12 : 14,
                color: iconColor ?? theme.inactiveColor,
              ),
              SizedBox(width: compact ? 6 : 8),
            ],
            Expanded(
              child: Text(
                label,
                style: labelStyle ??
                    (compact
                        ? theme.typography.caption
                        : theme.typography.body),
              ),
            ),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: hasDifference
                  ? BoxDecoration(
                      color: diffColor!.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                _formatAmount(diff, showSign: true),
                style: (amountStyle ??
                        (compact
                            ? theme.typography.caption
                            : theme.typography.body))
                    ?.copyWith(
                  color: diffColor,
                  fontWeight: hasDifference ? FontWeight.w600 : null,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 2 : 6),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: compact ? 12 : 14,
              color: iconColor ?? theme.inactiveColor,
            ),
            SizedBox(width: compact ? 6 : 8),
          ],
          Expanded(
            flex: 3,
            child: Text(
              label,
              style: labelStyle ??
                  (compact ? theme.typography.caption : theme.typography.body),
            ),
          ),
          Expanded(
            flex: 2,
            child: Text(
              _formatAmount(systemAmount ?? 0),
              style: (compact
                      ? theme.typography.caption
                      : theme.typography.body)
                  ?.copyWith(color: theme.inactiveColor),
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              _formatAmount(manualAmount ?? 0),
              style:
                  compact ? theme.typography.caption : theme.typography.body,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: compact ? 70 : 90,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: hasDifference
                  ? BoxDecoration(
                      color: diffColor!.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    )
                  : null,
              child: Text(
                _formatAmount(diff, showSign: true),
                style: (amountStyle ??
                        (compact
                            ? theme.typography.caption
                            : theme.typography.body))
                    ?.copyWith(
                  color: diffColor,
                  fontWeight: hasDifference ? FontWeight.w600 : null,
                ),
                textAlign: TextAlign.right,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAmount(double value, {bool showSign = false}) {
    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: prefix ?? '',
      decimalDigits: decimals,
    );

    String formatted = formatter.format(value.abs());
    if (suffix != null) {
      formatted += suffix!;
    }

    if (showSign) {
      if (value > 0) {
        return '+$formatted';
      } else if (value < 0) {
        return '-$formatted';
      }
    } else if (value < 0) {
      return '-$formatted';
    }

    return formatted;
  }
}

/// A header row for comparison tables.
class OdooSummaryHeader extends StatelessWidget {
  final String? label;
  final String systemLabel;
  final String manualLabel;
  final String differenceLabel;
  final bool compact;

  const OdooSummaryHeader({
    super.key,
    this.label,
    this.systemLabel = 'System',
    this.manualLabel = 'Manual',
    this.differenceLabel = 'Difference',
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final style = theme.typography.caption?.copyWith(
      color: theme.inactiveColor,
      fontWeight: FontWeight.w600,
    );

    return Padding(
      padding: EdgeInsets.only(bottom: compact ? 4 : 8),
      child: Row(
        children: [
          const SizedBox(width: 22),
          Expanded(
            flex: 3,
            child: Text(label ?? '', style: style),
          ),
          Expanded(
            flex: 2,
            child: Text(
              systemLabel,
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            flex: 2,
            child: Text(
              manualLabel,
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: compact ? 70 : 90,
            child: Text(
              differenceLabel,
              style: style,
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}

/// A card containing multiple summary rows with optional title.
class OdooSummaryCard extends StatelessWidget {
  final String? title;
  final IconData? titleIcon;
  final List<Widget> children;
  final Widget? footer;
  final EdgeInsetsGeometry? padding;
  final Color? backgroundColor;

  const OdooSummaryCard({
    super.key,
    this.title,
    this.titleIcon,
    required this.children,
    this.footer,
    this.padding,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: theme.resources.cardStrokeColorDefault,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  if (titleIcon != null) ...[
                    Icon(titleIcon, size: 16, color: theme.accentColor),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    title!,
                    style: theme.typography.bodyStrong,
                  ),
                ],
              ),
            ),
          if (title != null)
            const Divider(
                style: DividerThemeData(
                    horizontalMargin: EdgeInsets.zero)),
          Padding(
            padding: padding ?? const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: children,
            ),
          ),
          if (footer != null) ...[
            const Divider(
                style: DividerThemeData(
                    horizontalMargin: EdgeInsets.zero)),
            Padding(
              padding: const EdgeInsets.all(12),
              child: footer!,
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Backward-compatible aliases
// ---------------------------------------------------------------------------

/// @nodoc Deprecated: use [OdooSummaryRow] instead.
typedef ReactiveSummaryRow = OdooSummaryRow;

/// @nodoc Deprecated: use [OdooSummaryHeader] instead.
typedef ReactiveSummaryHeader = OdooSummaryHeader;

/// @nodoc Deprecated: use [OdooSummaryCard] instead.
typedef ReactiveSummaryCard = OdooSummaryCard;
