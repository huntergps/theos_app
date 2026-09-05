part of 'pos_order_lines_panel.dart';

/// Footer with totals, confirm button, sync status, and invoice section
class _OrderLinesTotals extends StatelessWidget {
  final SaleOrder? order;
  final List<SaleOrderLine> lines;
  final bool canConfirm;
  final bool showTotals;
  final VoidCallback onConfirm;

  const _OrderLinesTotals({
    this.order,
    required this.lines,
    required this.canConfirm,
    required this.showTotals,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      padding: const EdgeInsets.all(8.0),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showTotals) ...[
            SalesOrderTotals(order: order, lines: lines),
            const SizedBox(height: Spacing.xs),
          ],
          // Confirm button
          if (order != null &&
              order!.state == SaleOrderState.draft &&
              !order!.hasQueuedInvoice &&
              !order!.isFullyInvoiced)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canConfirm ? onConfirm : null,
                style: ButtonStyle(
                  backgroundColor: canConfirm
                      ? WidgetStateProperty.all(AppColors.success)
                      : null,
                  padding: WidgetStateProperty.all(
                    const EdgeInsets.symmetric(vertical: Spacing.sm),
                  ),
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: Spacing.xl,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        FluentIcons.check_mark,
                        size: 16,
                        color: canConfirm ? Colors.white : null,
                      ),
                      const SizedBox(width: Spacing.xs),
                      Text(
                        'Confirmar Venta (F9)',
                        style: TextStyle(
                          color: canConfirm ? Colors.white : null,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // Invoice queued indicator
          if (order != null && order!.hasQueuedInvoice)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.warning,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.sync,
                          size: 16,
                          color: AppColors.warning,
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'Factura pendiente de enviar',
                          style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _SyncOrderButtonInline(orderId: order!.id),
              ],
            )
          // Ready to invoice indicator
          else if (order != null &&
              order!.state == SaleOrderState.sale &&
              order!.isFullyInvoiced == false)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                    decoration: BoxDecoration(
                      color: AppColors.info,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.completed,
                          size: 16,
                          color: AppColors.info,
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'Listo para facturar',
                          style: TextStyle(
                            color: AppColors.info,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                _SyncOrderButtonInline(orderId: order!.id),
              ],
            )
          else if (order != null)
            _SyncOrderButtonInline(orderId: order!.id, fullWidth: true),

          // Invoice section
          if (order != null &&
              ((order!.isSynced && order!.invoiceCount > 0) ||
                  order!.hasQueuedInvoice)) ...[
            const SizedBox(height: Spacing.sm),
            InvoiceSection(orderId: order!.id),
          ],
        ],
      ),
    );
  }
}
