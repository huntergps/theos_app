import 'package:fluent_ui/fluent_ui.dart';
import '../../../core/constants/app_colors.dart';
import '../../utils/formatting_utils.dart';

/// A widget to display a label and a value, commonly used in detail screens.
///
/// Uso:
/// ```dart
/// // Básico
/// TheosInfoRow(label: 'Nombre', value: 'Juan Pérez')
///
/// // Como enlace
/// TheosInfoRow(
///   label: 'Email',
///   value: 'juan@email.com',
///   isLink: true,
///   onPressed: () => _sendEmail(),
/// )
///
/// // Monetario
/// TheosInfoRow.currency(label: 'Total', amount: 1234.56)
///
/// // Con icono
/// TheosInfoRow.withIcon(
///   icon: FluentIcons.calendar,
///   label: 'Fecha',
///   value: '01/01/2025',
/// )
/// ```
class TheosInfoRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isLink;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? iconColor;
  final Color? valueColor;
  final bool isBold;
  final double labelWidth;

  const TheosInfoRow({
    super.key,
    required this.label,
    required this.value,
    this.isLink = false,
    this.onPressed,
    this.icon,
    this.iconColor,
    this.valueColor,
    this.isBold = false,
    this.labelWidth = 140,
  });

  /// Constructor para valores monetarios
  factory TheosInfoRow.currency({
    Key? key,
    required String label,
    required double amount,
    String symbol = '\$',
    Color? valueColor,
    bool isBold = false,
    double labelWidth = 140,
    IconData? icon,
    Color? iconColor,
  }) {
    return TheosInfoRow(
      key: key,
      label: label,
      value: amount.toCurrency(symbol: symbol),
      valueColor: valueColor,
      isBold: isBold,
      labelWidth: labelWidth,
      icon: icon,
      iconColor: iconColor,
    );
  }

  /// Constructor para valores de porcentaje
  factory TheosInfoRow.percentage({
    Key? key,
    required String label,
    required double percentage,
    Color? valueColor,
    bool isBold = false,
    double labelWidth = 140,
  }) {
    return TheosInfoRow(
      key: key,
      label: label,
      value: percentage.toPercent(),
      valueColor: valueColor,
      isBold: isBold,
      labelWidth: labelWidth,
    );
  }

  /// Constructor con icono a la izquierda
  factory TheosInfoRow.withIcon({
    Key? key,
    required IconData icon,
    required String label,
    required String value,
    Color? iconColor,
    Color? valueColor,
    bool isBold = false,
    double labelWidth = 140,
    bool isLink = false,
    VoidCallback? onPressed,
  }) {
    return TheosInfoRow(
      key: key,
      icon: icon,
      iconColor: iconColor,
      label: label,
      value: value,
      valueColor: valueColor,
      isBold: isBold,
      labelWidth: labelWidth,
      isLink: isLink,
      onPressed: onPressed,
    );
  }

  /// Constructor para fechas
  factory TheosInfoRow.date({
    Key? key,
    required String label,
    required DateTime? date,
    String pattern = 'dd/MM/yyyy',
    bool showTime = false,
    Color? valueColor,
    double labelWidth = 140,
    IconData? icon,
    Color? iconColor,
  }) {
    final datePattern = showTime ? '$pattern HH:mm' : pattern;
    return TheosInfoRow(
      key: key,
      label: label,
      value: date != null
          ? FormattingUtils.formatDate(date, pattern: datePattern)
          : '-',
      valueColor: valueColor,
      labelWidth: labelWidth,
      icon: icon ?? FluentIcons.calendar,
      iconColor: iconColor,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: iconColor ?? theme.inactiveColor),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: labelWidth,
            child: Text(
              label,
              style: theme.typography.caption?.copyWith(
                color: theme.inactiveColor,
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: isLink ? onPressed : null,
              child: Text(
                value,
                style: isLink
                    ? const TextStyle(
                        color: AppColors.referenceText,
                        fontWeight: FontWeight.w500,
                      )
                    : theme.typography.body?.copyWith(
                        color: valueColor,
                        fontWeight: isBold ? FontWeight.w600 : null,
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Widget de fila de resumen con icono y valor monetario
///
/// Uso:
/// ```dart
/// TheosSummaryRow(
///   icon: FluentIcons.money,
///   iconColor: Colors.green,
///   label: 'Total Efectivo',
///   amount: 1500.00,
///   isBold: true,
/// )
/// ```
class TheosSummaryRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double amount;
  final Color? amountColor;
  final bool isBold;
  final Color? backgroundColor;
  final String currencySymbol;

  const TheosSummaryRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.amount,
    this.amountColor,
    this.isBold = false,
    this.backgroundColor,
    this.currencySymbol = '\$',
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final formattedAmount = amount.toCurrency(symbol: currencySymbol);

    Widget content = Semantics(
      label: '$label: $formattedAmount',
      excludeSemantics: true,
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(icon, size: 14, color: iconColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: theme.typography.body?.copyWith(
                fontWeight: isBold ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          ),
          Text(
            formattedAmount,
            style: theme.typography.body?.copyWith(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              color: amountColor ?? (isBold ? theme.accentColor : null),
            ),
          ),
        ],
      ),
    );

    if (backgroundColor != null) {
      return Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(4),
        ),
        child: content,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: content,
    );
  }
}
