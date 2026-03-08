import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../shared/widgets/order_config_card.dart';
import '../fast_sale_providers.dart';

/// POS Order Config Card - wrapper around [OrderConfigCard] for Fast Sale
///
/// Connects the unified OrderConfigCard to the fastSaleProvider.
/// Shows: date, pricelist, payment term, warehouse, user
class POSOrderConfigCard extends ConsumerWidget {
  /// Show in compact mode (only date row)
  final bool isCompact;

  const POSOrderConfigCard({
    super.key,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeTab = ref.watch(fastSaleActiveTabProvider);
    final order = activeTab?.order;
    // Only editable in draft or sent state
    final canEdit = order?.isEditable ?? true;

    // Get authorized payment term IDs for filtering
    final partnerPaymentTermIds = activeTab?.partnerPaymentTermIds ?? [];

    return OrderConfigCard(
      isCompact: isCompact,
      isEditing: canEdit,
      dateOrder: order?.dateOrder,
      pricelistId: order?.pricelistId,
      pricelistName: order?.pricelistName,
      paymentTermId: order?.paymentTermId,
      paymentTermName: order?.paymentTermName,
      warehouseId: order?.warehouseId,
      warehouseName: order?.warehouseName,
      userId: order?.userId,
      userName: order?.userName,
      authorizedPaymentTermIds: partnerPaymentTermIds,
      onDateChanged: canEdit
          ? (date) => _updateOrderField(ref, 'date_order', date)
          : null,
      onPricelistChanged: canEdit
          ? (id) => _updateOrderField(ref, 'pricelist_id', id)
          : null,
      onPaymentTermChanged: canEdit
          ? (id) => _updateOrderField(ref, 'payment_term_id', id)
          : null,
      onWarehouseChanged: canEdit
          ? (id) => _updateOrderField(ref, 'warehouse_id', id)
          : null,
      onUserChanged: canEdit
          ? (id) => _updateOrderField(ref, 'user_id', id)
          : null,
    );
  }

  /// Update a field in the active order
  void _updateOrderField(WidgetRef ref, String field, dynamic value) {
    final notifier = ref.read(fastSaleProvider.notifier);
    notifier.updateOrderField(field, value);
  }
}
