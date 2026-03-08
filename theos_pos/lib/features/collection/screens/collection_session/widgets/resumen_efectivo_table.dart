import 'package:fluent_ui/fluent_ui.dart';

import 'package:odoo_widgets/odoo_widgets.dart' show ReactiveSummaryCard, ReactiveSummaryRow;
import '../../../../../shared/utils/formatting_utils.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tabla de resumen de efectivo de la sesion
/// Refactorizado para usar ReactiveSummaryCard
class ResumenEfectivoTable extends StatelessWidget {
  final CollectionSession session;

  const ResumenEfectivoTable({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final difference = session.cashRegisterDifference;

    return ReactiveSummaryCard(
      title: 'Resumen de Efectivo',
      titleIcon: FluentIcons.money,
      footer: _buildFooterTotal(theme),
      children: [
        // Entradas
        _buildSectionHeader(theme, 'Entradas', Colors.green),
        const SizedBox(height: 8),
        ReactiveSummaryRow(
          icon: FluentIcons.add,
          iconColor: Colors.green,
          label: 'Cobros en Efectivo',
          amount: session.totalCash,
        ),
        ReactiveSummaryRow(
          icon: FluentIcons.pinned,
          iconColor: Colors.orange,
          label: 'Anticipos en Efectivo',
          amount: session.totalCashAdvanceAmount,
        ),

        const SizedBox(height: 12),

        // Salidas
        _buildSectionHeader(theme, 'Salidas', Colors.red),
        const SizedBox(height: 8),
        ReactiveSummaryRow(
          icon: FluentIcons.remove,
          iconColor: Colors.red,
          label: 'Retiros Efectivo',
          amount: -session.totalCashOutAmount,
          highlightNegative: true,
        ),

        const SizedBox(height: 12),
        const Divider(),
        const SizedBox(height: 12),

        // Balance calculado
        _buildSectionHeader(theme, 'Balance', theme.accentColor),
        const SizedBox(height: 8),
        ReactiveSummaryRow(
          icon: FluentIcons.money,
          iconColor: theme.accentColor,
          label: 'Dinero Registrado (En Caja)',
          amount: session.cashRegisterBalanceEndReal,
          amountStyle: theme.typography.bodyStrong,
        ),
        ReactiveSummaryRow(
          icon: FluentIcons.calculator,
          iconColor: Colors.grey,
          label: 'Diferencia',
          amount: difference,
          highlightPositive: difference > 0,
          highlightNegative: difference < 0,
        ),
        ReactiveSummaryRow(
          icon: FluentIcons.bank,
          iconColor: Colors.blue,
          label: 'Fondo de Caja',
          amount: session.cashRegisterBalanceStart,
        ),
      ],
    );
  }

  Widget _buildSectionHeader(FluentThemeData theme, String label, Color color) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterTotal(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.flag, size: 18, color: theme.accentColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Diferencia al Cierre',
              style: theme.typography.bodyStrong,
            ),
          ),
          Text(
            session.cashRegisterBalanceEnd.toCurrency(),
            style: theme.typography.subtitle?.copyWith(
              color: theme.accentColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
