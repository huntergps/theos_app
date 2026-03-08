import 'package:fluent_ui/fluent_ui.dart';

import 'package:odoo_widgets/odoo_widgets.dart' show ReactiveSummaryCard, ReactiveSummaryRow, ReactiveSummaryHeader;
import '../../../../../shared/utils/formatting_utils.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tabla de conteo manual de la sesion
/// Refactorizado para usar ReactiveSummaryRow.comparison
class ConteoManualTable extends StatelessWidget {
  final CollectionSession session;

  const ConteoManualTable({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ReactiveSummaryCard(
      title: 'Conteo Manual',
      titleIcon: FluentIcons.edit,
      footer: _buildTotalRow(theme),
      children: [
        // Header
        const ReactiveSummaryHeader(
          systemLabel: 'Sistema',
          manualLabel: 'Manual',
          differenceLabel: 'Diferencia',
        ),
        const Divider(),
        const SizedBox(height: 8),

        // Comparison rows
        ReactiveSummaryRow.comparison(
          icon: FluentIcons.check_list,
          label: 'Cheques al Dia',
          systemAmount: session.systemChecksOnDay,
          manualAmount: session.manualChecksOnDay,
        ),
        ReactiveSummaryRow.comparison(
          icon: FluentIcons.calendar,
          label: 'Cheques Postfechados',
          systemAmount: session.systemChecksPostdated,
          manualAmount: session.manualChecksPostdated,
        ),
        ReactiveSummaryRow.comparison(
          icon: FluentIcons.payment_card,
          label: 'Tarjetas de Credito',
          systemAmount: session.systemCardsTotal,
          manualAmount: session.manualCardsTotal,
        ),
        ReactiveSummaryRow.comparison(
          icon: FluentIcons.switch_widget,
          label: 'Transferencias',
          systemAmount: session.systemTransfersTotal,
          manualAmount: session.manualTransfersTotal,
        ),
        ReactiveSummaryRow.comparison(
          icon: FluentIcons.money,
          label: 'Depositos Efectivo',
          systemAmount: session.systemDepositsCashTotal,
          manualAmount: session.manualDepositsCashTotal,
        ),
        ReactiveSummaryRow.comparison(
          icon: FluentIcons.bank,
          label: 'Depositos Cheques',
          systemAmount: session.systemDepositsChecksTotal,
          manualAmount: session.manualDepositsChecksTotal,
        ),
        ReactiveSummaryRow.comparison(
          icon: FluentIcons.pinned,
          label: 'Anticipos de Clientes',
          systemAmount: session.systemAdvancesTotal,
          manualAmount: session.manualAdvancesTotal,
        ),
        ReactiveSummaryRow.comparison(
          icon: FluentIcons.return_key,
          label: 'Notas de Credito',
          systemAmount: session.systemCreditNotesTotal,
          manualAmount: session.manualCreditNotesTotal,
        ),
        ReactiveSummaryRow.comparison(
          icon: FluentIcons.list,
          label: 'Retenciones Cruzadas',
          systemAmount: session.totalWithholdAmount,
          manualAmount: session.manualWithholdsTotal,
        ),
      ],
    );
  }

  Widget _buildTotalRow(FluentThemeData theme) {
    final hasDifference = session.summaryDiffTotal.abs() > 0.01;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      decoration: BoxDecoration(
        color: hasDifference
            ? Colors.red.withValues(alpha: 0.1)
            : Colors.green.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Spacer for icon
          const SizedBox(width: 22),
          // Label
          Expanded(
            flex: 3,
            child: Text(
              'TOTAL',
              style: theme.typography.bodyStrong,
            ),
          ),
          // System total
          Expanded(
            flex: 2,
            child: Text(
              session.summarySystemTotal.toCurrency(),
              style: theme.typography.bodyStrong,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          // Manual total
          Expanded(
            flex: 2,
            child: Text(
              session.summaryManualTotal.toCurrency(),
              style: theme.typography.bodyStrong,
              textAlign: TextAlign.right,
            ),
          ),
          const SizedBox(width: 8),
          // Difference total
          SizedBox(
            width: 90,
            child: Text(
              session.summaryDiffTotal.toCurrency(),
              style: theme.typography.bodyStrong?.copyWith(
                color: hasDifference ? Colors.red : Colors.green,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
