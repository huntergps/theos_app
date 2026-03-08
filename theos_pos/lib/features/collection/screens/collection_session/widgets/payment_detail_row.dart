import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../shared/utils/formatting_utils.dart';

/// Widget para mostrar una fila de detalle de pago con facturas, cartera, anticipos y total
class PaymentDetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final double? facturas;
  final double? cartera;
  final double? anticipos;
  final double total;
  final bool isTotal;
  final bool isGrandTotal;

  const PaymentDetailRow({
    super.key,
    required this.icon,
    required this.label,
    this.facturas,
    this.cartera,
    this.anticipos,
    required this.total,
    this.isTotal = false,
    this.isGrandTotal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final style = isGrandTotal
        ? theme.typography.body?.copyWith(fontWeight: FontWeight.bold)
        : isTotal
        ? theme.typography.body?.copyWith(fontWeight: FontWeight.bold)
        : theme.typography.body;

    return Semantics(
      label: '$label: Total ${total.toCurrency()}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              flex: 2,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: theme.accentColor),
                  const SizedBox(width: 8),
                  Expanded(child: Text(label, style: style)),
                ],
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                facturas != null && facturas != 0
                    ? facturas!.toCurrency()
                    : '-',
                style: style,
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                cartera != null && cartera != 0
                    ? cartera!.toCurrency()
                    : '-',
                style: style,
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                anticipos != null && anticipos != 0
                    ? anticipos!.toCurrency()
                    : '-',
                style: style,
                textAlign: TextAlign.right,
              ),
            ),
            Expanded(
              flex: 1,
              child: Text(
                total.toCurrency(),
                style: style?.copyWith(fontWeight: FontWeight.bold),
                textAlign: TextAlign.right,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
