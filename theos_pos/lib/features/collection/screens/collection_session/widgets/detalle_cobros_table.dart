import 'package:fluent_ui/fluent_ui.dart';

import 'payment_detail_row.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tabla de detalle de cobros
class DetalleCobrosTable extends StatelessWidget {
  final CollectionSession session;

  const DetalleCobrosTable({super.key, required this.session});

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
                  color: Colors.blue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(
                  FluentIcons.payment_card,
                  color: theme.accentColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text('Detalle de Cobros', style: theme.typography.subtitle),
            ],
          ),
          const SizedBox(height: 20),

          // Header
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              Expanded(
                flex: 1,
                child: Text(
                  'Facturas',
                  style: theme.typography.caption,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Cartera',
                  style: theme.typography.caption,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Anticipos',
                  style: theme.typography.caption,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'TOTAL',
                  style: theme.typography.caption,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          PaymentDetailRow(
            icon: FluentIcons.money,
            label: 'Efectivo',
            facturas: session.factCash,
            cartera: session.carteraCash,
            anticipos: session.anticipoCash,
            total: session.totalCash,
          ),
          PaymentDetailRow(
            icon: FluentIcons.payment_card,
            label: 'Tarjetas',
            facturas: session.factCards,
            cartera: session.carteraCards,
            anticipos: session.anticipoCards,
            total: session.totalCards,
          ),
          PaymentDetailRow(
            icon: FluentIcons.switch_widget,
            label: 'Transferencias',
            facturas: session.factTransfers,
            cartera: session.carteraTransfers,
            anticipos: session.anticipoTransfers,
            total: session.totalTransfers,
          ),
          PaymentDetailRow(
            icon: FluentIcons.check_list,
            label: 'Cheques al Dia',
            facturas: session.factChecksDay,
            cartera: session.carteraChecksDay,
            anticipos: session.anticipoChecksDay,
            total: session.totalChecksDay,
          ),
          PaymentDetailRow(
            icon: FluentIcons.calendar,
            label: 'Cheques Posfech.',
            facturas: session.factChecksPost,
            cartera: session.carteraChecksPost,
            anticipos: session.anticipoChecksPost,
            total: session.totalChecksPost,
          ),
          PaymentDetailRow(
            icon: FluentIcons.money,
            label: 'Depositos Efect.',
            facturas: session.factDepositsCash,
            cartera: session.carteraDepositsCash,
            anticipos: session.anticipoDepositsCash,
            total: session.systemDepositsCashTotal,
          ),
          PaymentDetailRow(
            icon: FluentIcons.bank,
            label: 'Depositos Cheq.',
            facturas: session.factDepositsChecks,
            cartera: session.carteraDepositsChecks,
            anticipos: session.anticipoDepositsChecks,
            total: session.systemDepositsChecksTotal,
          ),
          PaymentDetailRow(
            icon: FluentIcons.share,
            label: 'Anticipos Cruzados',
            facturas: session.factAdvancesUsed,
            cartera: session.carteraAdvancesUsed,
            total: session.summaryAdvancesUsedTotal,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),

          PaymentDetailRow(
            icon: FluentIcons.calculator_addition,
            label: 'TOTAL COBROS',
            facturas: session.factTotal,
            cartera: session.carteraTotal,
            anticipos: session.anticipoTotal,
            total: session.totalGeneral,
            isTotal: true,
          ),

          const SizedBox(height: 8),

          PaymentDetailRow(
            icon: FluentIcons.return_key,
            label: 'Notas Credito',
            facturas: session.systemCreditNotesTotal,
            total: session.systemCreditNotesTotal,
          ),
          PaymentDetailRow(
            icon: FluentIcons.list,
            label: 'Retenciones',
            facturas: session.totalWithholdAmount,
            total: session.totalWithholdAmount,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Divider(),
          ),

          PaymentDetailRow(
            icon: FluentIcons.total,
            label: 'TOTAL FACTURAS',
            facturas: session.factTotalWithNcWithholds,
            total: session.factTotalWithNcWithholds,
            isGrandTotal: true,
          ),
        ],
      ),
    );
  }
}
