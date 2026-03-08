import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../shared/utils/formatting_utils.dart';

import 'check_row.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Tabla de cheques recibidos
class ChequesRecibidosTable extends StatelessWidget {
  final CollectionSession session;

  const ChequesRecibidosTable({super.key, required this.session});

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
                  color: Colors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Icon(FluentIcons.page, color: Colors.purple, size: 16),
              ),
              const SizedBox(width: 12),
              Text('Cheques Recibidos', style: theme.typography.subtitle),
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
                  'Al Dia',
                  style: theme.typography.caption,
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  'Posfechados',
                  style: theme.typography.caption,
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Divider(),
          const SizedBox(height: 8),

          // Check Rows
          CheckRow(
            icon: FluentIcons.money,
            label: 'Cheques de Cobros',
            onDay: session.checksOnDayTotal,
            postdated: session.checksPostdatedTotal,
          ),
          const SizedBox(height: 8),
          CheckRow(
            icon: FluentIcons.pinned,
            label: 'Cheques de Anticipos',
            onDay: session.advanceChecksOnDayTotal,
            postdated: session.advanceChecksPostdatedTotal,
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
                  session.totalChecksOnDay.toCurrency(),
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
              Expanded(
                flex: 1,
                child: Text(
                  session.totalChecksPostdated.toCurrency(),
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.right,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
