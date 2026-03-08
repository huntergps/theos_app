import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../products/providers/stock_sync_providers.dart';

/// Section showing price and stock changes detected during sync (M7 FASE 3)
///
/// Features:
/// - Shows count of pending price changes
/// - Shows count of pending stock changes
/// - Allows marking changes as notified
class StockChangesSection extends ConsumerWidget {
  const StockChangesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final priceChangesAsync = ref.watch(pendingPriceChangesCountProvider);
    final stockChangesAsync = ref.watch(pendingStockChangesCountProvider);
    final theme = FluentTheme.of(context);

    final priceCount = priceChangesAsync.when(
      data: (count) => count,
      loading: () => 0,
      error: (_, _) => 0,
    );
    final stockCount = stockChangesAsync.when(
      data: (count) => count,
      loading: () => 0,
      error: (_, _) => 0,
    );
    final totalChanges = priceCount + stockCount;

    // Don't show if no changes
    if (totalChanges == 0 &&
        !priceChangesAsync.isLoading &&
        !stockChangesAsync.isLoading) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(
              FluentIcons.sync_status_solid,
              size: 20,
              color: totalChanges > 0
                  ? Colors.orange
                  : theme.resources.textFillColorSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              'Cambios Detectados',
              style: theme.typography.subtitle,
            ),
            const SizedBox(width: 8),
            if (priceChangesAsync.isLoading || stockChangesAsync.isLoading)
              const SizedBox(
                width: 16,
                height: 16,
                child: ProgressRing(strokeWidth: 2),
              )
            else if (totalChanges > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$totalChanges nuevo${totalChanges != 1 ? 's' : ''}',
                  style: theme.typography.caption?.copyWith(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const Spacer(),
            // No manual refresh needed: StreamProviders auto-update
            // when the underlying Drift tables change.
          ],
        ),
        const SizedBox(height: 12),

        // Change indicators
        if (totalChanges > 0)
          Row(
            children: [
              // Price changes
              if (priceCount > 0)
                _ChangeChip(
                  icon: FluentIcons.money,
                  label: 'Precios',
                  count: priceCount,
                  color: Colors.blue,
                ),
              if (priceCount > 0 && stockCount > 0) const SizedBox(width: 12),
              // Stock changes
              if (stockCount > 0)
                _ChangeChip(
                  icon: FluentIcons.product,
                  label: 'Stock',
                  count: stockCount,
                  color: Colors.teal,
                ),
            ],
          ),

        // Empty state
        if (totalChanges == 0 &&
            !priceChangesAsync.isLoading &&
            !stockChangesAsync.isLoading)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Icon(
                    FluentIcons.completed,
                    size: 32,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sin cambios pendientes',
                    style: theme.typography.caption?.copyWith(
                      color: theme.resources.textFillColorSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// Change indicator chip
class _ChangeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final int count;
  final Color color;

  const _ChangeChip({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Text(
            label,
            style: theme.typography.body?.copyWith(
              color: color,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: theme.typography.caption?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
