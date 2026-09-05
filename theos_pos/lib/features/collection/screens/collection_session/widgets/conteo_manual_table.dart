import 'package:fluent_ui/fluent_ui.dart';

import 'package:odoo_widgets/odoo_widgets.dart'
    show OdooSummaryCard, OdooSummaryRow, OdooSummaryHeader;

import '../../../../../core/constants/app_colors.dart';
import '../../../../../shared/utils/formatting_utils.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

/// Tabla de conteo manual de la sesion
/// Refactorizado para usar OdooSummaryRow.comparison
class ConteoManualTable extends StatelessWidget {
  final CollectionSession session;

  const ConteoManualTable({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return OdooSummaryCard(
      title: 'Conteo Manual',
      titleIcon: FluentIcons.edit,
      footer: _buildTotalRow(theme),
      children: [
        // Header
        const OdooSummaryHeader(
          systemLabel: 'Sistema',
          manualLabel: 'Manual',
          differenceLabel: 'Diferencia',
        ),
        const Divider(),
        const SizedBox(height: 8),

        // Comparison rows
        OdooSummaryRow.comparison(
          icon: FluentIcons.check_list,
          label: 'Cheques al Día',
          systemAmount: session.systemChecksOnDay,
          manualAmount: session.manualChecksOnDay,
        ),
        OdooSummaryRow.comparison(
          icon: FluentIcons.calendar,
          label: 'Cheques Postfechados',
          systemAmount: session.systemChecksPostdated,
          manualAmount: session.manualChecksPostdated,
        ),
        OdooSummaryRow.comparison(
          icon: FluentIcons.payment_card,
          label: 'Tarjetas de Crédito',
          systemAmount: session.systemCardsTotal,
          manualAmount: session.manualCardsTotal,
        ),
        OdooSummaryRow.comparison(
          icon: FluentIcons.switch_widget,
          label: 'Transferencias',
          systemAmount: session.systemTransfersTotal,
          manualAmount: session.manualTransfersTotal,
        ),
        OdooSummaryRow.comparison(
          icon: FluentIcons.money,
          label: 'Depósitos Efectivo',
          systemAmount: session.systemDepositsCashTotal,
          manualAmount: session.manualDepositsCashTotal,
        ),
        OdooSummaryRow.comparison(
          icon: FluentIcons.bank,
          label: 'Depósitos Cheques',
          systemAmount: session.systemDepositsChecksTotal,
          manualAmount: session.manualDepositsChecksTotal,
        ),
        OdooSummaryRow.comparison(
          icon: FluentIcons.pinned,
          label: 'Anticipos de Clientes',
          systemAmount: session.systemAdvancesTotal,
          manualAmount: session.manualAdvancesTotal,
        ),
        OdooSummaryRow.comparison(
          icon: FluentIcons.return_key,
          label: 'Notas de Crédito',
          systemAmount: session.systemCreditNotesTotal,
          manualAmount: session.manualCreditNotesTotal,
        ),
        OdooSummaryRow.comparison(
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
            ? AppColors.danger.withValues(alpha: 0.1)
            : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Spacer for icon
          const SizedBox(width: 22),
          // Label
          Expanded(
            flex: 3,
            child: Text('TOTAL', style: theme.typography.bodyStrong),
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
                color: hasDifference ? AppColors.danger : AppColors.success,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }
}
