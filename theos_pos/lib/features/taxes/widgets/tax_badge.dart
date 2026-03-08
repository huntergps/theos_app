import 'package:fluent_ui/fluent_ui.dart';

import '../../taxes/taxes.dart';

/// Tax badge widget to display tax name like Odoo
class TaxBadge extends StatelessWidget {
  final String? taxNames;

  const TaxBadge({super.key, required this.taxNames});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    if (taxNames == null || taxNames!.isEmpty) {
      return Text('-', style: TextStyle(color: theme.inactiveColor));
    }

    final displayName = TaxCalculatorService.getFirstSimplifiedTaxName(taxNames);

    return Tooltip(
      message: taxNames!,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        decoration: BoxDecoration(
          color: theme.accentColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(
            color: theme.accentColor.withValues(alpha: 0.3),
            width: 1,
          ),
        ),
        child: Text(
          displayName,
          style: TextStyle(
            fontSize: theme.typography.caption?.fontSize,
            fontWeight: FontWeight.w500,
            color: theme.accentColor,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}
