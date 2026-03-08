import 'package:fluent_ui/fluent_ui.dart';

import 'summary_row.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tabla de facturas emitidas en el cierre
class FacturasEmitidasTable extends StatelessWidget {
  final CollectionSession session;

  const FacturasEmitidasTable({super.key, required this.session});

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
                  color: Colors.teal.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  FluentIcons.invoice,
                  color: theme.accentColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Facturas Emitidas del Cierre',
                style: theme.typography.subtitle,
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Cash Invoices Section
          Text(
            'VENTAS CONTADO',
            style: theme.typography.caption?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SummaryRow(
            icon: FluentIcons.shopping_cart,
            iconColor: Colors.blue,
            label: 'Total Facturado Contado',
            amount: session.totalCashInvoicesAmount,
          ),
          const SizedBox(height: 4),
          SummaryRow(
            icon: FluentIcons.money,
            iconColor: Colors.green,
            label: 'Total Cobrado Contado',
            amount: session.totalCashCollectedAmount,
          ),
          const SizedBox(height: 4),
          SummaryRow(
            icon: FluentIcons.warning,
            iconColor: Colors.orange,
            label: 'Total por Cobrar Contado',
            amount: session.totalCashPendingAmount,
            amountColor: session.totalCashPendingAmount > 0
                ? Colors.orange
                : null,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),

          // Credit Invoices Section
          Text(
            'VENTAS CREDITO',
            style: theme.typography.caption?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          SummaryRow(
            icon: FluentIcons.payment_card,
            iconColor: Colors.purple,
            label: 'Total Ordenes Credito',
            amount: session.totalCreditOrdersAmount,
          ),
          const SizedBox(height: 4),
          SummaryRow(
            icon: FluentIcons.invoice,
            iconColor: Colors.teal,
            label: 'Total Facturas Credito',
            amount: session.totalCreditInvoicesAmount,
          ),
          const SizedBox(height: 4),
          SummaryRow(
            icon: FluentIcons.calculator,
            iconColor: Colors.grey,
            label: 'Diferencia Ventas Credito',
            amount: session.creditSalesDifference,
            amountColor: session.creditSalesDifference != 0 ? Colors.red : null,
          ),
        ],
      ),
    );
  }
}
