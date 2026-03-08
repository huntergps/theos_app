import 'package:fluent_ui/fluent_ui.dart' hide showDialog;
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/providers.dart'
    show taxNamesCacheProvider, getTaxNamesFromIds;
import '../../../../../core/database/repositories/repository_providers.dart'
    show offlineSyncServiceProvider, odooClientProvider;
import '../../../../../features/sync/services/offline_sync_service.dart'
    show SyncResultAppExtension;
import '../../../../../core/theme/spacing.dart';
import '../../../../clients/clients.dart'
    show Client, CreditCheckType, CreditControlDialog, CreditDialogAction, CreditValidationResult, clientRepositoryProvider;
import '../../../../invoices/invoices.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, PartnerBank, CreditIssue;
import '../../../ui/sale_order_ui_extensions.dart';
import '../../../repositories/sales_repository.dart' show CreditIssue;
import '../../../services/credit_validation_ui_service.dart'
    show UnifiedCreditResult;
import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../../products/widgets/product_info_dialog.dart';
import '../../../../taxes/widgets/tax_badge.dart';
import '../../../widgets/totals/sales_order_totals.dart';
import '../../sale_order_form/select_uom_dialog.dart';
import '../fast_sale_providers.dart';
import 'pos_actions_panel.dart' show hasCollectionPermissionsProvider;
import 'pos_credit_sale_tab.dart';
import 'pos_order_tabs.dart' show orderPendingSyncProvider;
import 'pos_payment_tab.dart';

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
    final theme = FluentTheme.of(context);
    final activeTab = ref.watch(fastSaleActiveTabProvider);
    final lines = activeTab?.lines ?? [];
    final selectedIndex = activeTab?.selectedLineIndex ?? -1;
    final currentPanelTab = ref.watch(orderPanelTabProvider);

    // Only show Pagos tab for cashiers/supervisors
    final hasCollectionPermissions = ref.watch(
      hasCollectionPermissionsProvider,
    );

    final order = activeTab?.order;
    // Use model's canConfirm + business rules (needs lines and partner)
    // Don't allow confirm if order already has invoice (queued or synced)
    final hasInvoice = order?.hasQueuedInvoice == true || order?.isFullyInvoiced == true;
    final canConfirm =
        order != null &&
        order.canConfirm &&
        lines.isNotEmpty &&
        order.partnerId != null &&
        !hasInvoice;

    // Check if this is a credit sale (NOT immediate payment)
    final isCreditSale = order?.isCreditSale ?? false;

    return Column(
      children: [
        // Sub-tabs: Lineas | Pagos/Credito (only for cashiers)
        _buildSubTabs(
          theme,
          showPayments: hasCollectionPermissions,
          orderState: order?.state,
          isCreditSale: isCreditSale,
          currentPanelTab: currentPanelTab,
        ),

        // Content based on selected sub-tab
        Expanded(
          child: currentPanelTab == OrderPanelTab.lines
              ? _buildLinesContent(
                  context,
                  theme,
                  lines,
                  selectedIndex,
                  activeTab?.order?.pricelistId,
                  order?.isEditable ?? true,
                )
              : _buildPaymentsContent(theme),
        ),

        // Footer with totals and confirm button (totals only on lines tab)
        _buildFooter(
          context,
          theme,
          order,
          lines,
          canConfirm,
          showTotals: currentPanelTab == OrderPanelTab.lines,
        ),
      ],
    );
  }

  Widget _buildSubTabs(
    FluentThemeData theme, {
    required bool showPayments,
    SaleOrderState? orderState,
    bool isCreditSale = false,
    required OrderPanelTab currentPanelTab,
  }) {
    // Determine the label for the second tab based on sale type
    final secondTabLabel = isCreditSale ? 'Crédito' : 'Pagos';

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
          // Lineas tab
          _SubTabButton(
            label: 'Lineas',
            isActive: currentPanelTab == OrderPanelTab.lines,
            onTap: () => ref.read(orderPanelTabProvider.notifier).goToLines(),
          ),
          // Pagos/Credito tab - only visible for cashiers/supervisors
          if (showPayments)
            _SubTabButton(
              label: secondTabLabel,
              isActive: currentPanelTab == OrderPanelTab.payments,
              onTap: () => ref.read(orderPanelTabProvider.notifier).goToPayments(),
            ),
          const Spacer(),
          // Order state badge
          if (orderState != null)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.sm),
              child: _OrderStateBadge(state: orderState),
            ),
        ],
      ),
    );
  }

  Widget _buildLinesContent(
    BuildContext context,
    FluentThemeData theme,
    List<SaleOrderLine> lines,
    int selectedIndex,
    int? pricelistId,
    bool canEdit,
  ) {
    if (lines.isEmpty) {
      return _buildEmptyState(theme);
    }

    // Use cards instead of table
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
          // listPrice and productTmplId will be loaded in the widget
          onTap: () {
            ref.read(fastSaleProvider.notifier).selectLine(index);
          },
          onShowProductInfo: line.productId != null
              ? () => _showProductInfoDialog(context, line, pricelistId)
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

  Widget _buildPaymentsContent(FluentThemeData theme) {
    final activeTab = ref.watch(fastSaleActiveTabProvider);
    final order = activeTab?.order;

    // Check if this is a credit sale (NOT immediate payment)
    final isCreditSale = order?.isCreditSale ?? false;

    if (isCreditSale) {
      // Credit sale: show credit control tab
      return const POSCreditSaleTab();
    }

    // Cash sale: show normal payment tab
    return const POSPaymentTab();
  }

  /// Footer with totals and confirm button
  /// [showTotals] - only show totals panel when on lines tab
  Widget _buildFooter(
    BuildContext context,
    FluentThemeData theme,
    SaleOrder? order,
    List<SaleOrderLine> lines,
    bool canConfirm, {
    bool showTotals = true,
  }) {
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
          // Totals - only show on lines tab
          if (showTotals) ...[
            SalesOrderTotals(order: order, lines: lines),
            const SizedBox(height: Spacing.xs),
          ],
          // Confirm button - visible when order is in draft and has no invoice yet
          if (order != null && order.state == SaleOrderState.draft && !order.hasQueuedInvoice && !order.isFullyInvoiced)
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canConfirm
                    ? () => _handleConfirmOrder(context)
                    : null,
                style: ButtonStyle(
                  backgroundColor: canConfirm
                      ? WidgetStateProperty.all(Colors.green.dark)
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
                        'Confirmar Venta',
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
          // Show "Invoice queued" indicator when invoice is pending sync
          if (order != null && order.hasQueuedInvoice)
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.orange.lightest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.sync,
                          size: 16,
                          color: Colors.orange.dark,
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'Factura pendiente de sync',
                          style: TextStyle(
                            color: Colors.orange.dark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Sync button (inline)
                _SyncOrderButtonInline(orderId: order.id),
              ],
            )
          // Show "Ready to invoice" indicator + sync button in a row
          else if (order != null &&
              order.state == SaleOrderState.sale &&
              order.isFullyInvoiced == false)
            Row(
              children: [
                // Ready to invoice indicator
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: Spacing.sm),
                    decoration: BoxDecoration(
                      color: Colors.blue.lightest,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          FluentIcons.completed,
                          size: 16,
                          color: Colors.blue.dark,
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          'Listo para facturar',
                          style: TextStyle(
                            color: Colors.blue.dark,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Sync button (inline, next to "Listo para facturar")
                _SyncOrderButtonInline(orderId: order.id),
              ],
            )
          else if (order != null)
            // Show sync button alone when not ready to invoice
            _SyncOrderButtonInline(orderId: order.id, fullWidth: true),

          // Invoice section (when order has invoices OR has offline invoice)
          // Offline invoices have AccountMove stored locally with negative odooId
          if (order != null &&
              ((order.isSynced && order.invoiceCount > 0) ||
                  order.hasQueuedInvoice)) ...[
            const SizedBox(height: Spacing.sm),
            InvoiceSection(orderId: order.id),
          ],
        ],
      ),
    );
  }

  /// Handle confirm order button press
  Future<void> _handleConfirmOrder(BuildContext context) async {
    final notifier = ref.read(fastSaleProvider.notifier);

    // Step 1: Validate credit before confirming
    final creditResult = await notifier.validateCreditForConfirmation();

    // Check for error
    if (creditResult.errorMessage != null) {
      if (!context.mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error',
        message: creditResult.errorMessage!,
      );
      return;
    }

    // Step 2: If dialog required, show credit control dialog
    if (creditResult.requiresDialog &&
        creditResult.client != null &&
        creditResult.validationResult != null) {
      if (!context.mounted) return;

      final action = await CreditControlDialog.show(
        context: context,
        client: creditResult.client!,
        validationResult: creditResult.validationResult!,
        orderAmount: creditResult.orderAmount,
        isOnline: creditResult.isOnline,
      );

      if (action == null || action == CreditDialogAction.cancel) {
        // User cancelled
        return;
      }

      if (action == CreditDialogAction.createApproval) {
        // Create approval request
        if (!context.mounted) return;
        await _createApprovalRequest(context, creditResult);
        return;
      }

      // action == CreditDialogAction.proceedAnyway
      // Continue to confirm with skipCreditCheck
      logger.i('[POS]', 'User chose to proceed anyway (bypass credit check)');
    }

    // Step 3: Confirm the order
    if (!context.mounted) return;
    await _executeConfirmOrder(
      context,
      skipCreditCheck: creditResult.requiresDialog,
    );
  }

  /// Execute the actual order confirmation
  Future<void> _executeConfirmOrder(
    BuildContext context, {
    bool skipCreditCheck = false,
  }) async {
    final notifier = ref.read(fastSaleProvider.notifier);

    // Show loading indicator
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ContentDialog(
        content: SizedBox(
          height: 80,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProgressRing(),
                SizedBox(height: 16),
                Text('Confirmando orden...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final success = await notifier.confirmActiveOrder(
        skipCreditCheck: skipCreditCheck,
      );

      // Close loading dialog safely using root navigator
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (!context.mounted) return;

      if (success) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Orden confirmada',
          message: 'La orden está lista para facturar',
        );
      } else {
        // Check if there's a credit issue from Odoo
        final currentState = ref.read(fastSaleProvider);
        final creditIssue = currentState.lastCreditIssue;

        if (creditIssue != null && !skipCreditCheck) {
          // Convert CreditIssue to CreditValidationResult for dialog
          final validationResult = _creditIssueToValidationResult(creditIssue);

          // Get client from active tab
          final client = currentState.activeTab?.order?.partnerId != null
              ? await _getClientForCreditDialog(
                  ref,
                  creditIssue.partnerId,
                  creditIssue,
                )
              : null;

          if (!context.mounted) return;

          if (client != null) {
            // Show credit control dialog
            final action = await CreditControlDialog.show(
              context: context,
              client: client,
              validationResult: validationResult,
              orderAmount:
                  creditIssue.orderAmount ?? currentState.activeTab?.total ?? 0,
              isOnline: true, // We got this from Odoo, so we're online
              canBypass: true, // Allow bypass from POS
            );

            // Clear the credit issue
            notifier.clearCreditIssue();

            if (action == CreditDialogAction.proceedAnyway) {
              // Retry with skip credit check
              if (!context.mounted) return;
              await _executeConfirmOrder(context, skipCreditCheck: true);
              return;
            }

            if (action == CreditDialogAction.createApproval) {
              // Create approval request using Odoo credit issue data
              if (!context.mounted) return;
              await _createApprovalRequestFromCreditIssue(context, creditIssue);
              return;
            }

            // User cancelled
            return;
          }
        }

        // Show regular error message
        final errorMsg = currentState.error ?? 'No se pudo confirmar la orden';
        CopyableInfoBar.showError(
          context,
          title: 'Error',
          message: errorMsg,
        );
      }
    } catch (e) {
      // Close loading dialog safely using root navigator
      if (context.mounted) {
        try {
          Navigator.of(context, rootNavigator: true).pop();
        } catch (_) {
          // Dialog might already be closed
        }
      }

      if (!context.mounted) return;

      CopyableInfoBar.showError(
        context,
        title: 'Error',
        message: 'Error al confirmar: $e',
      );
    }
  }

  /// Create approval request for credit exception
  Future<void> _createApprovalRequest(
    BuildContext context,
    UnifiedCreditResult creditResult,
  ) async {
    final notifier = ref.read(fastSaleProvider.notifier);

    // Show loading indicator
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ContentDialog(
        content: SizedBox(
          height: 80,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProgressRing(),
                SizedBox(height: 16),
                Text('Creando solicitud de aprobación...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final checkType = creditResult.validationResult!.type;
      final approvalId = await notifier.createCreditApprovalRequest(
        checkType: checkType.name,
        reason: checkType == CreditCheckType.creditLimitExceeded
            ? 'Límite de crédito excedido'
            : 'Deuda vencida',
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      if (approvalId != null) {
        logger.i('[POS]', 'Approval request created with ID: $approvalId');
        CopyableInfoBar.showSuccess(
          context,
          title: 'Solicitud creada',
          message: 'La solicitud de aprobación ha sido enviada.\n'
              'La orden quedará en estado "Esperando aprobación".',
        );
      } else {
        CopyableInfoBar.showError(
          context,
          title: 'Error',
          message: 'No se pudo crear la solicitud de aprobación',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      try {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
      } catch (_) {}

      CopyableInfoBar.showError(
        context,
        title: 'Error',
        message: 'Error al crear solicitud: $e',
      );
    }
  }

  /// Convert CreditIssue from Odoo to CreditValidationResult from clients module
  CreditValidationResult _creditIssueToValidationResult(CreditIssue issue) {
    switch (issue.type) {
      case 'overdue_debt':
        return CreditValidationResult.overdueDebt(
          message: issue.message,
          isOffline: false,
        );
      case 'credit_limit_exceeded':
        return CreditValidationResult.creditExceeded(
          creditAvailable: issue.creditAvailable ?? 0,
          exceededAmount: issue.excessAmount ?? 0,
          isOffline: false,
        );
      case 'pending_requests':
        return CreditValidationResult(
          type: CreditCheckType.warning,
          isValid: false,
          message: issue.message,
        );
      default:
        return CreditValidationResult(
          type: CreditCheckType.warning,
          isValid: false,
          message: issue.message,
        );
    }
  }

  /// Get client data for credit dialog from CreditIssue
  Future<Client?> _getClientForCreditDialog(
    WidgetRef ref,
    int partnerId,
    CreditIssue issue,
  ) async {
    try {
      // Try to get client from local DB for avatar and other details
      final clientRepo = ref.read(clientRepositoryProvider);
      if (clientRepo == null) return null;

      final localClient = await clientRepo.getById(partnerId);

      if (localClient != null) {
        // Enrich with credit data from CreditIssue
        return localClient.copyWith(
          creditLimit: issue.creditLimit ?? localClient.creditLimit,
          credit: issue.creditUsed ?? localClient.credit,
          totalOverdue: issue.totalOverdue ?? localClient.totalOverdue,
          overdueInvoicesCount:
              issue.overdueInvoicesCount ?? localClient.overdueInvoicesCount,
          oldestOverdueDays:
              issue.oldestOverdueDays ?? localClient.oldestOverdueDays,
        );
      }

      // Fallback: create minimal client from CreditIssue
      return Client(
        id: partnerId,
        name: issue.partnerName,
        creditLimit: issue.creditLimit ?? 0,
        credit: issue.creditUsed ?? 0,
        totalOverdue: issue.totalOverdue,
        overdueInvoicesCount: issue.overdueInvoicesCount,
        oldestOverdueDays: issue.oldestOverdueDays,
      );
    } catch (e) {
      return null;
    }
  }

  /// Create approval request from Odoo CreditIssue
  Future<void> _createApprovalRequestFromCreditIssue(
    BuildContext context,
    CreditIssue issue,
  ) async {
    final notifier = ref.read(fastSaleProvider.notifier);

    // Show loading indicator
    if (!context.mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const ContentDialog(
        content: SizedBox(
          height: 80,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProgressRing(),
                SizedBox(height: 16),
                Text('Creando solicitud de aprobación...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final checkType = issue.isOverdueDebt
          ? 'overdue_debt'
          : 'credit_limit_exceeded';
      final approvalId = await notifier.createCreditApprovalRequest(
        checkType: checkType,
        reason: issue.isOverdueDebt
            ? 'Deuda vencida'
            : 'Límite de crédito excedido',
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      if (approvalId != null) {
        logger.i('[POS]', 'Approval request created with ID: $approvalId');
        CopyableInfoBar.showSuccess(
          context,
          title: 'Solicitud creada',
          message: 'La solicitud de aprobación ha sido enviada.\n'
              'La orden quedará en estado "Esperando aprobación".',
        );
      } else {
        CopyableInfoBar.showError(
          context,
          title: 'Error',
          message: 'No se pudo crear la solicitud de aprobación',
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      try {
        Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog
      } catch (_) {}

      CopyableInfoBar.showError(
        context,
        title: 'Error',
        message: 'Error al crear solicitud: $e',
      );
    }
  }

  /// Show product info dialog for a line
  void _showProductInfoDialog(
    BuildContext context,
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

  Widget _buildEmptyState(FluentThemeData theme) {
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
}

/// Sub-tab button (Lineas | Pagos)
class _SubTabButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SubTabButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.sm,
          vertical: Spacing.xs,
        ),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isActive ? theme.accentColor : Colors.transparent,
              width: 2,
            ),
          ),
        ),
        child: Text(
          label,
          style: theme.typography.body?.copyWith(
            fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
            color: isActive ? theme.accentColor : theme.inactiveColor,
          ),
        ),
      ),
    );
  }
}

/// Card-based line widget for POS (similar to normal order form)
///
/// Shows complete line information:
/// - Product code and custom description (or product name)
/// - Quantity with +/- buttons, UoM selector, unit price
/// - Discount (percentage and amount)
/// - Tax badge with tax amount
/// - Subtotal, Tax, Total
///
/// Features:
/// - Clickable UoM to change unit of measure
/// - Large +/- buttons for quick quantity adjustment
/// - Custom description field (shows instead of product name)
/// - Expanded view shows real product name and details
/// - Delete action requires confirmation dialog
class _POSLineCard extends ConsumerStatefulWidget {
  final SaleOrderLine line;
  final bool isSelected;
  final int lineIndex;
  final VoidCallback onTap;
  final Future<bool> Function()? onDelete;
  final Future<void> Function()? onIncrement;
  final Future<void> Function()? onDecrement;
  final Future<void> Function(int uomId, String uomName, double? price)?
  onUpdateUom;
  final void Function(String description)? onUpdateDescription;
  final VoidCallback? onShowProductInfo;

  /// Whether this line can be edited (order in draft/sent state)
  final bool canEdit;

  /// Pricelist ID for price calculation in UoM dialog
  final int? pricelistId;

  const _POSLineCard({
    required this.line,
    required this.isSelected,
    required this.lineIndex,
    required this.onTap,
    this.onDelete,
    this.onIncrement,
    this.onDecrement,
    this.onUpdateUom,
    this.onUpdateDescription,
    this.onShowProductInfo,
    this.canEdit = true,
    this.pricelistId,
  });

  @override
  ConsumerState<_POSLineCard> createState() => _POSLineCardState();
}

class _POSLineCardState extends ConsumerState<_POSLineCard> {
  bool _isExpanded = false;
  bool _isEditingDescription = false;
  late TextEditingController _descriptionController;
  String? _productBarcode;

  @override
  void initState() {
    super.initState();
    // Only pre-fill if there's a custom description (different from product name)
    final hasCustom =
        widget.line.name != (widget.line.productName ?? '') &&
        (widget.line.productName ?? '').isNotEmpty;
    _descriptionController = TextEditingController(
      text: hasCustom ? widget.line.name : '',
    );
    _loadProductBarcode();
  }

  /// Load barcode from product_uom table (packaging barcodes) or product table
  Future<void> _loadProductBarcode() async {
    if (widget.line.productId == null) return;

    // First, try to get barcode from product_uom table (packaging barcode)
    if (widget.line.productUomId != null) {
      final productUoms = await productUomManager.getForProduct(
        widget.line.productId!,
      );

      // Find barcode for the specific UoM
      for (final pu in productUoms) {
        if (pu.uomId == widget.line.productUomId && pu.barcode.isNotEmpty) {
          if (mounted) {
            setState(() {
              _productBarcode = pu.barcode;
            });
          }
          return;
        }
      }
    }

    // Fallback: try product's main barcode
    final product = await productManager.readLocal(widget.line.productId!);

    if (product?.barcode != null && product!.barcode!.isNotEmpty && mounted) {
      setState(() {
        _productBarcode = product.barcode;
      });
    }
  }

  @override
  void didUpdateWidget(covariant _POSLineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.line.name != widget.line.name && !_isEditingDescription) {
      // Only show custom description if different from product name
      final hasCustom =
          widget.line.name != (widget.line.productName ?? '') &&
          (widget.line.productName ?? '').isNotEmpty;
      _descriptionController.text = hasCustom ? widget.line.name : '';
    }
    // Reload barcode if product or UoM changed
    if (oldWidget.line.productId != widget.line.productId ||
        oldWidget.line.productUomId != widget.line.productUomId) {
      _productBarcode = null;
      _loadProductBarcode();
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  /// Check if the line has a custom description (different from product name)
  bool get _hasCustomDescription {
    final productName = widget.line.productName ?? '';
    return widget.line.name != productName && productName.isNotEmpty;
  }

  /// Get display name (custom description or product name)
  String get _displayName {
    // If there's a custom description that's different from product name, show it
    if (_hasCustomDescription) {
      return widget.line.name;
    }
    // Otherwise show product name
    return widget.line.productName ?? widget.line.name;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final line = widget.line;

    // Get tax names from cache (lookup from taxIds if taxNames is empty)
    final taxNamesCache = ref.watch(taxNamesCacheProvider);
    String effectiveTaxNames = line.taxNames ?? '';
    if (effectiveTaxNames.isEmpty &&
        line.taxIds != null &&
        line.taxIds!.isNotEmpty) {
      taxNamesCache.whenData((cache) {
        effectiveTaxNames = getTaxNamesFromIds(line.taxIds, cache);
      });
    }

    // Handle non-product lines (sections, notes)
    if (!line.isProductLine) {
      return _buildInfoLine(theme);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: Spacing.xs),
      child: GestureDetector(
        onTap: () {
          setState(() => _isExpanded = !_isExpanded);
          widget.onTap();
        },
        onDoubleTap: widget.onShowProductInfo,
        child: Card(
          padding: EdgeInsets.zero,
          backgroundColor: widget.isSelected
              ? theme.accentColor.withValues(alpha: 0.08)
              : null,
          child: Column(
            children: [
              // Main card content
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: widget.isSelected
                          ? theme.accentColor
                          : Colors.transparent,
                      width: 3,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Row 1: Line index, codes, description/name, delete button and total
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Line index
                        Container(
                          width: 24,
                          height: 24,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: theme.resources.subtleFillColorSecondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            '${widget.lineIndex + 1}',
                            style: theme.typography.caption?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: Spacing.xs),

                        // Codes column (code + barcode)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Product code badge (always visible if exists)
                            if (line.productCode != null &&
                                line.productCode!.isNotEmpty)
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.accentColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  line.productCode!,
                                  style: theme.typography.body?.copyWith(
                                    color: theme.accentColor,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            // Barcode badge (if different from code)
                            if (_productBarcode != null &&
                                _productBarcode != line.productCode) ...[
                              const SizedBox(height: Spacing.xxs),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: theme.inactiveColor.withValues(
                                    alpha: 0.15,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      FluentIcons.bar_chart4,
                                      size: 12,
                                      color: theme.inactiveColor,
                                    ),
                                    const SizedBox(width: Spacing.xxs),
                                    Text(
                                      _productBarcode!,
                                      style: theme.typography.body?.copyWith(
                                        color: theme.inactiveColor,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),

                        const SizedBox(width: Spacing.xs),

                        // Expand icon
                        Icon(
                          _isExpanded
                              ? FluentIcons.chevron_down
                              : FluentIcons.chevron_right,
                          size: 12,
                          color: theme.inactiveColor,
                        ),
                        const SizedBox(width: Spacing.xxs),

                        // Display name (custom description or product name)
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _displayName,
                                style: theme.typography.body?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              // Show "personalized" indicator if custom description
                              if (_hasCustomDescription)
                                Text(
                                  'Descripción personalizada',
                                  style: theme.typography.caption?.copyWith(
                                    color: theme.accentColor,
                                    fontStyle: FontStyle.italic,
                                    fontSize: 10,
                                  ),
                                ),
                            ],
                          ),
                        ),

                        const SizedBox(width: Spacing.xs),

                        // Total price
                        Text(
                          line.priceTotal.toCurrency(),
                          style: theme.typography.bodyStrong?.copyWith(
                            fontSize: 16,
                          ),
                        ),

                        const SizedBox(width: Spacing.sm),

                        // Info button - show product details
                        if (widget.onShowProductInfo != null)
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              icon: Icon(
                                FluentIcons.info,
                                size: 18,
                                color: theme.accentColor,
                              ),
                              onPressed: widget.onShowProductInfo,
                            ),
                          ),

                        // Delete button (at the end, bigger) - only if can edit
                        if (widget.canEdit)
                          SizedBox(
                            width: 40,
                            height: 40,
                            child: IconButton(
                              icon: Icon(
                                FluentIcons.delete,
                                size: 20,
                                color: Colors.red.light,
                              ),
                              onPressed: widget.onDelete != null
                                  ? () => _confirmDelete(context)
                                  : null,
                            ),
                          ),
                      ],
                    ),

                    const SizedBox(height: 10),

                    // Row 2: +/- buttons, Qty, UoM (clickable), Price, Discount, Tax
                    Row(
                      children: [
                        // Large - button (only if can edit)
                        if (widget.canEdit)
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: Button(
                              onPressed: widget.onDecrement,
                              child: const Icon(FluentIcons.remove, size: 16),
                            ),
                          ),
                        if (widget.canEdit) const SizedBox(width: Spacing.xs),

                        // Quantity display
                        Container(
                          constraints: const BoxConstraints(minWidth: 50),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: theme.resources.subtleFillColorSecondary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _formatQuantity(line.productUomQty),
                            style: theme.typography.bodyStrong?.copyWith(
                              fontSize: 16,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),

                        const SizedBox(width: Spacing.xs),

                        // Large + button (only if can edit)
                        if (widget.canEdit)
                          SizedBox(
                            width: 36,
                            height: 36,
                            child: FilledButton(
                              onPressed: widget.onIncrement,
                              child: const Icon(FluentIcons.add, size: 16),
                            ),
                          ),

                        const SizedBox(width: Spacing.sm),

                        // UoM badge (clickable only if can edit)
                        GestureDetector(
                          onTap: widget.canEdit
                              ? () => _showUomSelector(context)
                              : null,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: widget.canEdit
                                  ? theme.accentColor.withValues(alpha: 0.1)
                                  : theme.resources.subtleFillColorSecondary,
                              borderRadius: BorderRadius.circular(4),
                              border: widget.canEdit
                                  ? Border.all(
                                      color: theme.accentColor.withValues(
                                        alpha: 0.3,
                                      ),
                                    )
                                  : null,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  line.productUomName ?? 'Unid',
                                  style: theme.typography.caption?.copyWith(
                                    color: widget.canEdit
                                        ? theme.accentColor
                                        : theme.inactiveColor,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                if (widget.canEdit) ...[
                                  const SizedBox(width: Spacing.xxs),
                                  Icon(
                                    FluentIcons.chevron_down,
                                    size: 10,
                                    color: theme.accentColor,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(width: Spacing.xs),

                        // "x" separator and unit price
                        Text(
                          'x ${line.priceUnit.toCurrency()}',
                          style: theme.typography.body?.copyWith(
                            color: theme.inactiveColor,
                          ),
                        ),

                        // Discount badge (if any)
                        if (line.discount > 0) ...[
                          const SizedBox(width: Spacing.xs),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.green.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${line.discount.toFixed(0)}%',
                              style: theme.typography.caption?.copyWith(
                                color: Colors.green,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],

                        const Spacer(),

                        // Tax badge with amount
                        if (line.priceTax > 0) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.blue.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                TaxBadge(
                                  taxNames: effectiveTaxNames.isNotEmpty
                                      ? effectiveTaxNames
                                      : line.taxNames,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  line.priceTax.toCurrency(),
                                  style: theme.typography.caption?.copyWith(
                                    color: Colors.blue,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else
                          TaxBadge(
                            taxNames: effectiveTaxNames.isNotEmpty
                                ? effectiveTaxNames
                                : line.taxNames,
                          ),
                      ],
                    ),
                  ],
                ),
              ),

              // Expanded details section
              if (_isExpanded) _buildExpandedDetails(theme, effectiveTaxNames),
            ],
          ),
        ),
      ),
    );
  }

  /// Show UoM selector dialog with pricelist info for price display
  Future<void> _showUomSelector(BuildContext context) async {
    final line = widget.line;
    if (line.productId == null) return;

    // Get allowed UoMs from product (Odoo 19 compatible)
    List<int>? allowedUomIds;
    final product = await productManager.readLocal(line.productId!);

    if (product != null) {
      final uomIds = <int>{};
      if (product.uomId != null) {
        uomIds.add(product.uomId!);
      }
      if (product.uomIds != null && product.uomIds!.isNotEmpty) {
        uomIds.addAll(product.uomIds!);
      }
      if (uomIds.isNotEmpty) {
        allowedUomIds = uomIds.toList();
      }
    }

    if (!context.mounted) return;

    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => SelectUomDialog(
        currentUomId: line.productUomId,
        currentUomName: line.productUomName,
        productId: line.productId,
        productTmplId: product?.productTmplId,
        pricelistId: widget.pricelistId,
        listPrice: product?.listPrice,
        allowedUomIds: allowedUomIds,
      ),
    );

    if (result != null && context.mounted) {
      final uomId = result['id'] as int;
      final uomName = result['name'] as String;
      final price = result['price'] as double?;
      await widget.onUpdateUom?.call(uomId, uomName, price);
    }
  }

  Widget _buildInfoLine(FluentThemeData theme) {
    final line = widget.line;

    if (line.isSection) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Spacing.xs),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.accentColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.section, size: 14, color: theme.accentColor),
              const SizedBox(width: Spacing.xs),
              Text(
                line.name,
                style: theme.typography.bodyStrong?.copyWith(
                  color: theme.accentColor,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (line.isNote) {
      return Padding(
        padding: const EdgeInsets.only(bottom: Spacing.xs),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.sm,
            vertical: Spacing.xs,
          ),
          decoration: BoxDecoration(
            color: theme.resources.subtleFillColorSecondary,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(FluentIcons.edit_note, size: 14, color: theme.inactiveColor),
              const SizedBox(width: Spacing.xs),
              Expanded(
                child: Text(
                  line.name,
                  style: theme.typography.caption?.copyWith(
                    fontStyle: FontStyle.italic,
                    color: theme.inactiveColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildExpandedDetails(
    FluentThemeData theme,
    String effectiveTaxNames,
  ) {
    final line = widget.line;

    return Container(
      padding: const EdgeInsets.fromLTRB(Spacing.sm, 0, Spacing.sm, Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Divider
          Container(
            height: 1,
            margin: const EdgeInsets.only(bottom: Spacing.sm),
            color: theme.resources.dividerStrokeColorDefault,
          ),

          // Real product name (shown when there's a custom description)
          if (_hasCustomDescription) ...[
            Container(
              padding: const EdgeInsets.all(Spacing.xs),
              margin: const EdgeInsets.only(bottom: Spacing.sm),
              decoration: BoxDecoration(
                color: theme.resources.subtleFillColorSecondary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Icon(
                    FluentIcons.product,
                    size: 14,
                    color: theme.inactiveColor,
                  ),
                  const SizedBox(width: Spacing.xs),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Producto original:',
                          style: theme.typography.caption?.copyWith(
                            color: theme.inactiveColor,
                            fontSize: 10,
                          ),
                        ),
                        Text(
                          line.productName ?? '',
                          style: theme.typography.body?.copyWith(
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Custom description field (only if can edit)
          if (widget.canEdit)
            Container(
              margin: const EdgeInsets.only(bottom: Spacing.sm),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        FluentIcons.edit,
                        size: 12,
                        color: theme.inactiveColor,
                      ),
                      const SizedBox(width: Spacing.xxs),
                      Text(
                        'Descripción personalizada:',
                        style: theme.typography.caption?.copyWith(
                          color: theme.inactiveColor,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: Spacing.xxs),
                  TextBox(
                    controller: _descriptionController,
                    placeholder: line.productName ?? 'Descripción del producto',
                    maxLines: 2,
                    onTap: () {
                      setState(() => _isEditingDescription = true);
                    },
                    onChanged: (value) {
                      // Real-time update as user types
                    },
                    onSubmitted: (value) {
                      setState(() => _isEditingDescription = false);
                      if (value.trim().isNotEmpty) {
                        widget.onUpdateDescription?.call(value.trim());
                      } else {
                        // If empty, reset to product name
                        widget.onUpdateDescription?.call(
                          line.productName ?? '',
                        );
                        _descriptionController.text = line.productName ?? '';
                      }
                    },
                    suffix: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Save button
                        IconButton(
                          icon: Icon(
                            FluentIcons.check_mark,
                            size: 14,
                            color: Colors.green,
                          ),
                          onPressed: () {
                            final value = _descriptionController.text.trim();
                            setState(() => _isEditingDescription = false);
                            if (value.isNotEmpty) {
                              widget.onUpdateDescription?.call(value);
                            } else {
                              widget.onUpdateDescription?.call(
                                line.productName ?? '',
                              );
                              _descriptionController.text =
                                  line.productName ?? '';
                            }
                          },
                        ),
                        // Reset button (show only if different from product name)
                        if (_hasCustomDescription)
                          IconButton(
                            icon: Icon(
                              FluentIcons.undo,
                              size: 14,
                              color: theme.inactiveColor,
                            ),
                            onPressed: () {
                              final productName = line.productName ?? '';
                              _descriptionController.text = productName;
                              widget.onUpdateDescription?.call(productName);
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

          // Discount info (if any)
          if (line.discount > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: Spacing.sm),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: Spacing.xs,
                  vertical: Spacing.xxs,
                ),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Descuento ${line.discount.toFixed(1)}% = -${line.discountAmount.toCurrency()}',
                  style: theme.typography.caption?.copyWith(
                    color: Colors.green,
                  ),
                ),
              ),
            ),

          // Price breakdown row
          Row(
            children: [
              // Subtotal
              _buildDetailColumn(
                theme,
                'Subtotal',
                line.priceSubtotal.toCurrency(),
              ),
              const SizedBox(width: 16),

              // Tax
              _buildDetailColumn(
                theme,
                effectiveTaxNames.isNotEmpty
                    ? effectiveTaxNames
                    : (line.taxNames ?? 'IVA'),
                line.priceTax.toCurrency(),
              ),
              const SizedBox(width: 16),

              // Total
              _buildDetailColumn(
                theme,
                'Total',
                line.priceTotal.toCurrency(),
                isBold: true,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Shows confirmation dialog before deleting the line
  Future<void> _confirmDelete(BuildContext context) async {
    final line = widget.line;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Eliminar linea'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('¿Desea eliminar esta linea?'),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(Spacing.sm),
              decoration: BoxDecoration(
                color: FluentTheme.of(
                  context,
                ).resources.subtleFillColorSecondary,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (line.productCode != null &&
                            line.productCode!.isNotEmpty)
                          Text(
                            '[${line.productCode}]',
                            style: FluentTheme.of(context).typography.caption
                                ?.copyWith(
                                  color: FluentTheme.of(context).accentColor,
                                ),
                          ),
                        Text(
                          line.productName ?? line.name,
                          style: FluentTheme.of(context).typography.body,
                        ),
                        const SizedBox(height: Spacing.xxs),
                        Text(
                          '${_formatQuantity(line.productUomQty)} ${line.productUomName ?? 'Unid'} x ${line.priceUnit.toCurrency()}',
                          style: FluentTheme.of(context).typography.caption
                              ?.copyWith(
                                color: FluentTheme.of(context).inactiveColor,
                              ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    line.priceTotal.toCurrency(),
                    style: FluentTheme.of(context).typography.bodyStrong,
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );

    if (confirmed == true && widget.onDelete != null) {
      await widget.onDelete!();
    }
  }

  Widget _buildDetailColumn(
    FluentThemeData theme,
    String label,
    String value, {
    bool isBold = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.typography.caption?.copyWith(color: theme.inactiveColor),
        ),
        Text(
          value,
          style: theme.typography.body?.copyWith(
            fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    );
  }

  String _formatQuantity(double qty) {
    if (qty == qty.roundToDouble()) {
      return qty.toInt().toString();
    }
    return qty.toFixed(2);
  }
}

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

/// Inline sync button for pending offline operations
class _SyncOrderButtonInline extends ConsumerStatefulWidget {
  final int orderId;
  final bool fullWidth;

  const _SyncOrderButtonInline({required this.orderId, this.fullWidth = false});

  @override
  ConsumerState<_SyncOrderButtonInline> createState() => _SyncOrderButtonInlineState();
}

class _SyncOrderButtonInlineState extends ConsumerState<_SyncOrderButtonInline> {
  bool _isSyncing = false;

  Future<void> _syncOrder() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    try {
      final offlineSyncService = ref.read(offlineSyncServiceProvider);
      if (offlineSyncService == null) {
        logger.w('[SyncOrderButton]', 'Cannot sync: no sync service available');
        return;
      }

      final result = await offlineSyncService.processSaleOrderQueue(widget.orderId);

      if (mounted) {
        // Refresh the pending count
        ref.invalidate(orderPendingSyncProvider(widget.orderId));

        // Show result message
        if (result.synced > 0 || result.failed > 0) {
          String message;
          String title;

          if (result.hasInvoice) {
            // Invoice was created
            title = 'Factura creada';
            message = 'Factura #${result.invoiceCreated} creada exitosamente';
          } else if (result.failed == 0) {
            title = 'Sincronizado';
            message = 'Sincronizado: ${result.synced} operaciones';
          } else {
            title = 'Sync parcial';
            message = 'Sync: ${result.synced} ok, ${result.failed} fallidas';
          }

          if (result.failed == 0) {
            CopyableInfoBar.showSuccess(
              context,
              title: title,
              message: message,
            );
          } else {
            CopyableInfoBar.showWarning(
              context,
              title: title,
              message: message,
            );
          }
        } else if (result.isEmpty) {
          // No operations were processed (might have been filtered or already synced)
          CopyableInfoBar.showInfo(
            context,
            title: 'Sin cambios',
            message: 'No hay operaciones pendientes para sincronizar',
          );
        } else if (result.hasConflicts) {
          // Conflicts detected
          CopyableInfoBar.showWarning(
            context,
            title: 'Conflictos detectados',
            message: '${result.conflicts.length} operaciones tienen conflictos con el servidor',
          );
        }
      }
    } catch (e) {
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error',
          message: 'Error al sincronizar: $e',
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch pending sync count for this order
    final pendingSyncAsync = ref.watch(orderPendingSyncProvider(widget.orderId));
    final pendingCount = pendingSyncAsync.when(
      data: (count) => count,
      loading: () => 0,
      error: (_, _) => 0,
    );

    // Don't show if no pending operations
    if (pendingCount == 0) return const SizedBox.shrink();

    // Check if we're online using OdooClient (HTTP connectivity)
    // WebSocket is for real-time notifications, but sync uses HTTP
    final odooClient = ref.watch(odooClientProvider);
    final isOnline = odooClient?.isConfigured ?? false;

    final button = Tooltip(
      message: isOnline
          ? 'Sincronizar $pendingCount operaciones pendientes con Odoo'
          : 'Sin conexión a Odoo - $pendingCount operaciones pendientes',
      child: FilledButton(
        onPressed: isOnline && !_isSyncing ? _syncOrder : null,
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return Colors.red.withValues(alpha: 0.7);
            }
            return Colors.green;
          }),
          padding: WidgetStateProperty.all(
            const EdgeInsets.symmetric(horizontal: Spacing.md, vertical: Spacing.sm),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_isSyncing)
              const SizedBox(
                width: 14,
                height: 14,
                child: ProgressRing(strokeWidth: 2, activeColor: Colors.white),
              )
            else
              Icon(
                isOnline ? FluentIcons.sync : FluentIcons.cloud_not_synced,
                size: 14,
                color: Colors.white,
              ),
            const SizedBox(width: 6),
            Text(
              _isSyncing
                  ? 'Sincronizando...'
                  : isOnline
                      ? 'Sincronizar ($pendingCount)'
                      : 'Offline ($pendingCount)',
              style: const TextStyle(
                fontSize: 12,
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    if (widget.fullWidth) {
      return SizedBox(width: double.infinity, child: button);
    }

    return Padding(
      padding: const EdgeInsets.only(left: Spacing.xs),
      child: button,
    );
  }
}
