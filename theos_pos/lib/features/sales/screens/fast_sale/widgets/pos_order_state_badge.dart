part of 'pos_order_lines_panel.dart';

/// Badge showing the order state with color coding
///
/// Uses centralized [SaleOrderStateExtension.label] and [SaleOrderStateUI]
/// for consistent state display across the app.
class _OrderStateBadge extends StatelessWidget {
  final SaleOrderState state;

  const _OrderStateBadge({required this.state});

  @override
  Widget build(BuildContext context) {
    // Use centralized model label and UI extension colors
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.sm,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: state.backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        state.label,
        style: TextStyle(
          color: state.textColor,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
