part of 'pos_order_lines_panel.dart';

/// Payments content switcher (credit vs cash)
class _OrderLinesPaymentsContent extends ConsumerWidget {
  final SaleOrder? order;

  const _OrderLinesPaymentsContent({this.order});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isCreditSale = order?.isCreditSale ?? false;

    if (isCreditSale) {
      return const POSCreditSaleTab();
    }

    return const POSPaymentTab();
  }
}
