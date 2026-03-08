import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show CollectionSession;

// =============================================================================
// STAT BUTTONS ROW - Like Odoo button box
// =============================================================================
class StatButtonsRow extends StatelessWidget {
  final CollectionSession session;

  const StatButtonsRow({super.key, required this.session});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _StatButton(
          icon: FluentIcons.shopping_cart,
          label: 'Ordenes',
          count: session.orderCount,
          color: Colors.blue,
        ),
        _StatButton(
          icon: FluentIcons.document,
          label: 'Facturas',
          count: session.invoiceCount,
          color: Colors.teal,
        ),
        _StatButton(
          icon: FluentIcons.money,
          label: 'Pagos',
          count: session.paymentCount,
          color: Colors.green,
        ),
        _StatButton(
          icon: FluentIcons.pinned,
          label: 'Anticipos',
          count: session.advanceCount,
          color: Colors.orange,
        ),
        _StatButton(
          icon: FluentIcons.page,
          label: 'Cheques',
          count: session.chequeRecibidoCount,
          color: Colors.purple,
        ),
        _StatButton(
          icon: FluentIcons.down,
          label: 'Salidas',
          count: session.cashOutCount,
          color: Colors.red,
        ),
        _StatButton(
          icon: FluentIcons.bank,
          label: 'Depositos',
          count: session.depositCount,
          color: Colors.magenta,
        ),
        _StatButton(
          icon: FluentIcons.list,
          label: 'Retenciones',
          count: session.withholdCount,
          color: Colors.orange,
        ),
      ],
    );
  }
}

class _StatButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _StatButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      constraints: const BoxConstraints(minWidth: 100),
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(width: 12),
          Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                count.toString(),
                style: theme.typography.subtitle?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                label,
                style: theme.typography.caption!.copyWith(fontSize: 11),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
