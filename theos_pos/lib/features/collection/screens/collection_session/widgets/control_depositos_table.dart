import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../shared/utils/formatting_utils.dart';

import 'deposit_row.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tabla de control de depositos
class ControlDepositosTable extends StatelessWidget {
  final CollectionSession session;

  const ControlDepositosTable({super.key, required this.session});

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
                  FluentIcons.bank,
                  color: theme.accentColor,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text('Control de Depositos', style: theme.typography.subtitle),
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
                  'Total',
                  style: theme.typography.caption,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Depositado',
                  style: theme.typography.caption,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Diferencia',
                  style: theme.typography.caption,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          // Cash Deposits
          DepositRow(
            icon: FluentIcons.money,
            label: 'Efectivo',
            total: session.systemDepositsCashTotal,
            deposited: session.manualDepositsCashTotal,
            difference: session.diffDepositsCashTotal,
          ),
          const SizedBox(height: 8),

          // Check Deposits
          DepositRow(
            icon: FluentIcons.check_list,
            label: 'Cheques',
            total: session.systemDepositsChecksTotal,
            deposited: session.manualDepositsChecksTotal,
            difference: session.diffDepositsChecksTotal,
          ),

          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Divider(),
          ),

          // Total
          Row(
            children: [
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    const SizedBox(width: 32),
                    Text(
                      'TOTAL',
                      style: theme.typography.body?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  '-',
                  style: theme.typography.body,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  session.totalDepositAmount.toCurrency(),
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              const Expanded(flex: 1, child: SizedBox()),
            ],
          ),
        ],
      ),
    );
  }
}
