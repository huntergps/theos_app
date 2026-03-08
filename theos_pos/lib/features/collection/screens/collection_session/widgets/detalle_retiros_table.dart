import 'package:fluent_ui/fluent_ui.dart';

import 'summary_row.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tabla de detalle de retiros de efectivo
class DetalleRetirosTable extends StatelessWidget {
  final CollectionSession session;

  const DetalleRetirosTable({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Card(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(FluentIcons.remove, color: Colors.red, size: 16),
              ),
              const SizedBox(width: 12),
              Text(
                'Detalle de Retiros de Efectivo',
                style: theme.typography.subtitle,
              ),
            ],
          ),
          const SizedBox(height: 20),

          SummaryRow(
            icon: FluentIcons.lock,
            iconColor: Colors.grey,
            label: 'Retiro por Seguridad',
            amount: session.cashOutSecurityTotal,
          ),
          const SizedBox(height: 8),
          SummaryRow(
            icon: FluentIcons.bill,
            iconColor: Colors.blue,
            label: 'Pago de Facturas',
            amount: session.cashOutInvoiceTotal,
          ),
          const SizedBox(height: 8),
          SummaryRow(
            icon: FluentIcons.return_key,
            iconColor: Colors.orange,
            label: 'Devoluciones',
            amount: session.cashOutRefundTotal,
          ),
          const SizedBox(height: 8),
          SummaryRow(
            icon: FluentIcons.list,
            iconColor: Colors.purple,
            label: 'Retenciones',
            amount: session.cashOutWithholdTotal,
          ),
          const SizedBox(height: 8),
          SummaryRow(
            icon: FluentIcons.more,
            iconColor: Colors.teal,
            label: 'Otros',
            amount: session.cashOutOtherTotal,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),

          SummaryRow(
            icon: FluentIcons.total,
            iconColor: Colors.red,
            label: 'TOTAL RETIROS',
            amount: session.totalCashOutAmount,
            isBold: true,
            backgroundColor: Colors.red.withValues(alpha: 0.1),
          ),
        ],
      ),
    );
  }
}
