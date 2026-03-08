import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/utils/formatting_utils.dart';
import '../providers/sale_order_stream_providers.dart';

/// Example reactive line widget that watches database changes
///
/// This widget demonstrates how to use Stream Providers for reactive updates.
/// When the line data changes in the database (from any source - WebSocket,
/// another screen, etc.), this widget automatically rebuilds.
///
/// Usage:
/// ```dart
/// // In a list builder:
/// final lineIds = ref.watch(saleOrderLineIdsStreamProvider(orderId));
/// lineIds.when(
///   data: (ids) => Column(
///     children: ids.map((id) => ReactiveLineWidget(lineId: id)).toList(),
///   ),
///   loading: () => const ProgressRing(),
///   error: (e, _) => Text('Error: $e'),
/// )
/// ```
class ReactiveLineWidget extends ConsumerWidget {
  final int lineId;
  final VoidCallback? onTap;
  final bool isSelected;

  const ReactiveLineWidget({
    super.key,
    required this.lineId,
    this.onTap,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Watch the specific line - only rebuilds when THIS line changes
    final lineAsync = ref.watch(saleOrderLineStreamProvider(lineId));

    return lineAsync.when(
      data: (line) {
        if (line == null) {
          return const SizedBox.shrink();
        }

        return GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected
                  ? FluentTheme.of(context).accentColor.withValues(alpha: 0.1)
                  : null,
              border: Border(
                bottom: BorderSide(
                  color: FluentTheme.of(context).resources.dividerStrokeColorDefault,
                ),
              ),
            ),
            child: Row(
              children: [
                // Product name
                Expanded(
                  flex: 3,
                  child: Text(
                    line.productName ?? line.name,
                    style: FluentTheme.of(context).typography.body,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                // Quantity
                SizedBox(
                  width: 80,
                  child: Text(
                    '${line.productUomQty}',
                    style: FluentTheme.of(context).typography.body,
                    textAlign: TextAlign.center,
                  ),
                ),
                // Price
                SizedBox(
                  width: 100,
                  child: Text(
                    line.priceUnit.toCurrency(),
                    style: FluentTheme.of(context).typography.body,
                    textAlign: TextAlign.right,
                  ),
                ),
                // Total
                SizedBox(
                  width: 120,
                  child: Text(
                    line.priceTotal.toCurrency(),
                    style: FluentTheme.of(context).typography.bodyStrong,
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.all(8.0),
        child: ProgressRing(),
      ),
      error: (e, _) => Text('Error: $e'),
    );
  }
}

/// Reactive order total widget that watches database changes
///
/// Automatically updates when order totals change in the database.
class ReactiveOrderTotalWidget extends ConsumerWidget {
  final int orderId;

  const ReactiveOrderTotalWidget({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orderAsync = ref.watch(saleOrderStreamProvider(orderId));

    return orderAsync.when(
      data: (order) {
        if (order == null) {
          return const Text('--');
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _buildRow(context, 'Subtotal:', order.amountUntaxed),
            _buildRow(context, 'IVA:', order.amountTax),
            const SizedBox(height: 4),
            _buildRow(
              context,
              'Total:',
              order.amountTotal,
              isTotal: true,
            ),
          ],
        );
      },
      loading: () => const ProgressRing(),
      error: (e, _) => Text('Error: $e'),
    );
  }

  Widget _buildRow(BuildContext context, String label, double value, {bool isTotal = false}) {
    final style = isTotal
        ? FluentTheme.of(context).typography.subtitle
        : FluentTheme.of(context).typography.body;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: style),
          const SizedBox(width: 16),
          Text(
            value.toCurrency(),
            style: style,
          ),
        ],
      ),
    );
  }
}

/// Reactive order status badge
class ReactiveOrderStatusBadge extends ConsumerWidget {
  final int orderId;

  const ReactiveOrderStatusBadge({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(saleOrderStateProvider(orderId));

    if (state == null) {
      return const SizedBox.shrink();
    }

    Color backgroundColor;
    String label;

    switch (state.name) {
      case 'draft':
        backgroundColor = Colors.grey;
        label = 'Borrador';
      case 'sent':
        backgroundColor = Colors.blue;
        label = 'Enviado';
      case 'sale':
        backgroundColor = Colors.green;
        label = 'Confirmado';
      case 'cancel':
        backgroundColor = Colors.red;
        label = 'Cancelado';
      default:
        backgroundColor = Colors.grey;
        label = state.name;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: backgroundColor),
      ),
      child: Text(
        label,
        style: FluentTheme.of(context).typography.caption?.copyWith(
          color: backgroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Reactive sync status indicator
class ReactiveOrderSyncIndicator extends ConsumerWidget {
  final int orderId;

  const ReactiveOrderSyncIndicator({
    super.key,
    required this.orderId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSynced = ref.watch(saleOrderIsSyncedProvider(orderId));

    return Tooltip(
      message: isSynced ? 'Sincronizado' : 'Pendiente de sincronización',
      child: Icon(
        isSynced ? FluentIcons.cloud_download : FluentIcons.cloud_upload,
        size: 16,
        color: isSynced ? Colors.green : Colors.orange,
      ),
    );
  }
}
