import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../shared/utils/formatting_utils.dart';

/// Widget reutilizable para mostrar una fila de resumen con icono y valor
class SummaryRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final double amount;
  final Color? amountColor;
  final bool isBold;
  final Color? backgroundColor;

  const SummaryRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.amount,
    this.amountColor,
    this.isBold = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final formattedAmount = amount.toCurrency();

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
