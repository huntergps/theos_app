import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/database/providers.dart'
    show taxNamesCacheProvider, getTaxNamesFromIds;
import '../../../../../core/database/repositories/repository_providers.dart'
    show offlineSyncServiceProvider, odooClientProvider;
// El analyzer no detecta el uso de esta extensión porque solo se consume
// dentro de un archivo `part` (pos_sync_order_button_inline.dart), no en
// este archivo directamente. El import sí es necesario: sin él, `.hasInvoice`
// y `.invoiceCreated` no resuelven en ningún archivo de esta librería.
// ignore: unused_import
import '../../../../../features/sync/services/offline_sync_service.dart'
    show SyncResultAppExtension;
import '../../../../../core/theme/spacing.dart';
import '../../../../invoices/invoices.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, PartnerBank, CreditIssue;
import '../../../ui/sale_order_ui_extensions.dart';
import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../../products/widgets/product_info_dialog.dart';
import 'product_favorites_grid.dart';
import '../../../../taxes/widgets/tax_badge.dart';
import '../../../widgets/totals/sales_order_totals.dart';
import '../../sale_order_form/select_uom_dialog.dart';
import '../fast_sale_providers.dart';
import 'confirm_order_handler.dart' show confirmOrderWithCreditCheck;
import 'pos_actions_panel.dart' show hasCollectionPermissionsProvider;
import 'pos_credit_sale_tab.dart';
import 'pos_order_tabs.dart' show orderPendingSyncProvider;
import 'pos_payment_tab.dart';

part 'pos_order_lines_header.dart';
part 'pos_order_lines_grid.dart';
part 'pos_order_lines_payments_content.dart';
part 'pos_order_lines_totals.dart';
part 'pos_sub_tab_button.dart';
part 'pos_line_card.dart';
part 'pos_order_state_badge.dart';
part 'pos_sync_order_button_inline.dart';

/// Left panel showing order lines (products in the sale)
///
/// Has sub-tabs: Lineas | Pagos
///
/// Lines tab displays a table/list with columns:
/// - Producto (name + secondary description)
/// - Cantidad (with format "Caja x N")
/// - Unidad (unit price)
/// - Precio
/// - Desc. (discount %)
/// - Empaque (Granel/Caja/Unidad)
/// - Total
///
/// Footer shows: Subtotal, IVA, Total
class POSOrderLinesPanel extends ConsumerStatefulWidget {
  const POSOrderLinesPanel({super.key});

  @override
  ConsumerState<POSOrderLinesPanel> createState() => _POSOrderLinesPanelState();
}

class _POSOrderLinesPanelState extends ConsumerState<POSOrderLinesPanel> {
  @override
  Widget build(BuildContext context) {
    final activeTab = ref.watch(fastSaleActiveTabProvider);
    final currentPanelTab = ref.watch(orderPanelTabProvider);
    final hasCollectionPermissions = ref.watch(hasCollectionPermissionsProvider);

    final order = activeTab?.order;
    final lines = activeTab?.lines ?? [];
    final isCreditSale = order?.isCreditSale ?? false;

    final hasInvoice = order?.hasQueuedInvoice == true || order?.isFullyInvoiced == true;
    final canConfirm =
        order != null &&
        order.canConfirm &&
        lines.isNotEmpty &&
        order.partnerId != null &&
        !hasInvoice;

    // Determina qué mostrar en el área de contenido principal
    Widget contentArea;
    switch (currentPanelTab) {
      case OrderPanelTab.products:
        contentArea = const ProductFavoritesGrid();
      case OrderPanelTab.lines:
        contentArea = _OrderLinesGrid(
          lines: lines,
          selectedIndex: activeTab?.selectedLineIndex ?? -1,
          pricelistId: activeTab?.order?.pricelistId,
          canEdit: order?.isEditable ?? true,
        );
      case OrderPanelTab.payments:
        contentArea = _OrderLinesPaymentsContent(order: order);
    }

    // Mostrar totales sólo cuando estamos en la pestaña de líneas
    final showTotals = currentPanelTab == OrderPanelTab.lines ||
        currentPanelTab == OrderPanelTab.products;

    return Column(
      children: [
        // Header: sub-tabs (Productos | Lineas | Pagos/Credito)
        _OrderLinesHeader(
          showPayments: hasCollectionPermissions,
          orderState: order?.state,
          isCreditSale: isCreditSale,
          currentPanelTab: currentPanelTab,
          linesCount: lines.length,
        ),

        // Content: productos favoritos, líneas de orden, o pagos
        Expanded(child: contentArea),

        // Footer: totales + confirmar + sync + facturas
        _OrderLinesTotals(
          order: order,
          lines: lines,
          canConfirm: canConfirm,
          showTotals: showTotals,
          onConfirm: () => _handleConfirmOrder(context),
        ),
      ],
    );
  }



  /// Delega al handler centralizado que incluye validación de crédito,
  /// diálogo de bypass, indicador de carga y mensaje de resultado.
  Future<void> _handleConfirmOrder(BuildContext context) async {
    await confirmOrderWithCreditCheck(context, ref);
  }

}
