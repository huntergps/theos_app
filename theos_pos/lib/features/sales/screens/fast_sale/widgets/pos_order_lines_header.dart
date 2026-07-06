part of 'pos_order_lines_panel.dart';

/// Header con sub-pestañas: Productos | Lineas [N] | Pagos/Credito
///
/// - "Productos": muestra el grid de productos favoritos/frecuentes
/// - "Lineas": muestra la tabla de líneas de la orden (con contador si hay líneas)
/// - "Pagos/Credito": muestra la pestaña de pagos (solo si el usuario tiene permisos)
class _OrderLinesHeader extends ConsumerWidget {
  final bool showPayments;
  final SaleOrderState? orderState;
  final bool isCreditSale;
  final OrderPanelTab currentPanelTab;
  final int linesCount;

  const _OrderLinesHeader({
    required this.showPayments,
    this.orderState,
    this.isCreditSale = false,
    required this.currentPanelTab,
    required this.linesCount,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final paymentsTabLabel = isCreditSale ? 'Credito' : 'Pagos';

    // Etiqueta de la pestaña Lineas: muestra el contador cuando hay líneas
    final linesTabLabel =
        linesCount > 0 ? 'Lineas ($linesCount)' : 'Lineas';

    return Container(
      height: 36,
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor,
        border: Border(
          bottom: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: Row(
        children: [
          // Pestaña: Productos favoritos/frecuentes
          _SubTabButton(
            label: 'Productos',
            isActive: currentPanelTab == OrderPanelTab.products,
            onTap: () =>
                ref.read(orderPanelTabProvider.notifier).goToProducts(),
          ),
          // Pestaña: Líneas de la orden
          _SubTabButton(
            label: linesTabLabel,
            isActive: currentPanelTab == OrderPanelTab.lines,
            onTap: () =>
                ref.read(orderPanelTabProvider.notifier).goToLines(),
          ),
          // Pestaña: Pagos/Crédito (condicional)
          if (showPayments)
            _SubTabButton(
              label: paymentsTabLabel,
              isActive: currentPanelTab == OrderPanelTab.payments,
              onTap: () =>
                  ref.read(orderPanelTabProvider.notifier).goToPayments(),
            ),
          const Spacer(),
          if (orderState != null)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: _OrderStateBadge(state: orderState!),
            ),
        ],
      ),
    );
  }
}
