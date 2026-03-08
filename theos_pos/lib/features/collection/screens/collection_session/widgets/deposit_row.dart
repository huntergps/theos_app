import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../shared/utils/formatting_utils.dart';

/// Widget para mostrar una fila de deposito con sistema, manual y diferencia
class DepositRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double total;
  final double deposited;
  final double difference;

  const DepositRow({
    super.key,
    required this.icon,
    required this.label,
    required this.total,
    required this.deposited,
    required this.difference,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Row(
      children: [
        Expanded(
          flex: 2,
          child: Row(
            children: [
              Icon(
                icon,
                size: 14,
                color: theme.resources.textFillColorSecondary,
              ),
              const SizedBox(width: 8),
              Text(label, style: theme.typography.body),
            ],
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            total.toCurrency(),
            style: theme.typography.body,
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            deposited.toCurrency(),
            style: theme.typography.body,
            textAlign: TextAlign.right,
          ),
        ),
        Expanded(
          flex: 1,
          child: Text(
            difference.toCurrency(),
            style: theme.typography.body?.copyWith(
              color: difference != 0 ? Colors.red : Colors.green,
              fontWeight: difference != 0 ? FontWeight.bold : FontWeight.normal,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}
