part of 'pos_order_lines_panel.dart';

/// Grid/list of order line cards
class _OrderLinesGrid extends ConsumerWidget {
  final List<SaleOrderLine> lines;
  final int selectedIndex;
  final int? pricelistId;
  final bool canEdit;

  const _OrderLinesGrid({
    required this.lines,
    required this.selectedIndex,
    this.pricelistId,
    required this.canEdit,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (lines.isEmpty) {
      return _buildEmptyState(context);
    }

    return ListView.builder(
      padding: const EdgeInsets.all(Spacing.xs),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        final isSelected = index == selectedIndex;

        return _POSLineCard(
          line: line,
          isSelected: isSelected,
          lineIndex: index,
          pricelistId: pricelistId,
          canEdit: canEdit,
          onTap: () {
            ref.read(fastSaleProvider.notifier).selectLine(index);
          },
          onShowProductInfo: line.productId != null
              ? () => _showProductInfoDialog(context, ref, line, pricelistId)
              : null,
          onDelete: canEdit
              ? () async {
                  ref.read(fastSaleProvider.notifier).deleteLine(index);
                  return true;
                }
              : null,
          onIncrement: canEdit
              ? () async {
                  await ref
                      .read(fastSaleProvider.notifier)
                      .incrementLineQuantity(index);
                }
              : null,
          onDecrement: canEdit
              ? () async {
                  await ref
                      .read(fastSaleProvider.notifier)
                      .decrementLineQuantity(index);
                }
              : null,
          onUpdateUom: canEdit
              ? (uomId, uomName, price) async {
                  await ref
                      .read(fastSaleProvider.notifier)
                      .updateLineUom(index, uomId, uomName, dialogPrice: price);
                }
              : null,
          onUpdateDescription: canEdit
              ? (description) {
                  ref
                      .read(fastSaleProvider.notifier)
                      .updateLineDescription(index, description);
                }
              : null,
        );
      },
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = FluentTheme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.shopping_cart,
            size: 64,
            color: theme.inactiveColor.withValues(alpha: 0.3),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Sin productos',
            style: theme.typography.subtitle?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Busque un producto o escanee un codigo de barras',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
        ],
      ),
    );
  }

  void _showProductInfoDialog(
    BuildContext context,
    WidgetRef ref,
    SaleOrderLine line,
    int? pricelistId,
  ) {
    if (line.productId == null) return;

    final activeTab = ref.read(fastSaleActiveTabProvider);
    final order = activeTab?.order;

    showDialog(
      context: context,
      builder: (context) => ProductInfoDialog(
        productId: line.productId!,
        partnerId: order?.partnerId,
        partnerName: order?.partnerName,
        pricelistId: pricelistId ?? order?.pricelistId,
      ),
    );
  }
}
