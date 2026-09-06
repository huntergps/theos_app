import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show OdooException, OfflineLocalCommand;
import 'package:odoo_widgets/odoo_widgets.dart' show OdooSummaryCard;
import 'package:uuid/uuid.dart';

import '../../../../../core/adaptive/adaptive_layout_policy.dart';
import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/database/providers.dart'
    show currentSessionProvider, currentUserProvider;
import '../../../../../core/database/repositories/repository_providers.dart';
import '../../../../../core/theme/spacing.dart';

import 'package:theos_pos_core/theos_pos_core.dart'
    hide DatabaseHelper, PartnerBank;

import '../../../providers/service_providers.dart';
import '../../../repositories/sales_repository.dart';
import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../../shared/utils/error_utils.dart';
import '../fast_sale_providers.dart';
import 'pos_payment_providers.dart';
import 'add_payment_dialog.dart';
import 'add_withhold_dialog.dart';
import 'touch_actions_fab.dart' show fastSaleInputCapabilitiesProvider;
import '../../../widgets/payment/overpayment_dialog.dart';
import '../../../../../shared/widgets/dialogs/copyable_info_bar.dart';

/// Tab content for payments in POS
///
/// Shows:
/// - Summary (Total, Paid, Pending)
/// - List of registered payments
/// - Form to add new payments
/// - Quick cash buttons
///
/// Stable retry identity for an existing-invoice collection. Kept outside the
/// widget so it can be tested without mounting the POS dependency graph.
String existingInvoiceCollectionOperationUuid(
  int invoiceId,
  Iterable<PaymentLine> lines,
) {
  final keys =
      lines
          .map((line) => line.lineUuid ?? line.uuid)
          .whereType<String>()
          .where((value) => value.trim().isNotEmpty)
          .toList()
        ..sort();
  return const Uuid().v5(
    Namespace.url.value,
    'theos-pos:invoice-collection:$invoiceId:${keys.join(',')}',
  );
}

typedef ExistingInvoiceCollector = Future<int> Function({
  required int saleOrderId,
  required int invoiceId,
  required int collectionSessionId,
  required int operatorId,
  required String operationUuid,
  required List<PaymentLine> lines,
});

/// Replaceable boundary around the dependencies used by the posted-invoice
/// branch. Production still resolves the real repositories and persistence
/// service; widget tests can exercise the real button without opening Drift or
/// replacing the payment producer itself.
class ExistingInvoiceCollectionUiGateway {
  const ExistingInvoiceCollectionUiGateway({
    required this.loadInvoices,
    required this.loadQueuedLineUuids,
    required this.collect,
    required this.reloadPaymentLines,
  });

  final Future<List<AccountMove>> Function(int saleOrderId) loadInvoices;
  final Future<Set<String>> Function(int saleOrderId) loadQueuedLineUuids;
  final ExistingInvoiceCollector collect;
  final Future<void> Function(int saleOrderId) reloadPaymentLines;
}

final existingInvoiceCollectionUiGatewayProvider =
    Provider<ExistingInvoiceCollectionUiGateway>((ref) {
      return ExistingInvoiceCollectionUiGateway(
        loadInvoices: (saleOrderId) => ref
            .read(invoiceRepositoryProvider)
            .getInvoicesForSaleOrder(saleOrderId, forceRefresh: false),
        loadQueuedLineUuids: (saleOrderId) async {
          final queue = ref.read(offlineQueueDataSourceProvider);
          if (queue == null) return const <String>{};
          final operations = await queue.getOperationsForSaleOrder(saleOrderId);
          final uuids = <String>{};
          for (final operation in operations) {
            if (operation.method ==
                    OfflineLocalCommand.invoiceCollectExisting.storageName ||
                operation.method ==
                    OfflineLocalCommand.paymentWizardApply.storageName ||
                operation.method ==
                    OfflineLocalCommand.invoiceCreateWithPayments.storageName) {
              final rawUuids = operation.values['payment_line_uuids'];
              if (rawUuids is List) {
                uuids.addAll(
                  rawUuids.whereType<String>().where((id) => id.isNotEmpty),
                );
              }
            }
          }
          return uuids;
        },
        collect: ref.read(paymentServiceProvider).collectExistingInvoiceOffline,
        reloadPaymentLines: (saleOrderId) => ref
            .read(posPaymentLinesByOrderProvider.notifier)
            .loadFromDb(saleOrderId),
      );
    });

/// UI adapter for collecting against an already-posted invoice. Keeping the
/// policy here makes the screen testable without replacing the payment
/// persistence service or weakening its native guards.
Future<int> collectExistingInvoiceFromPos({
  required int saleOrderId,
  required AccountMove invoice,
  required int collectionSessionId,
  required int operatorId,
  required List<PaymentLine> lines,
  Set<String> queuedLineUuids = const {},
  required ExistingInvoiceCollector collector,
}) async {
  final newLines = lines
      .where((line) => !queuedLineUuids.contains(line.lineUuid ?? line.uuid))
      .toList(growable: false);
  if (invoice.moveType != 'out_invoice' ||
      invoice.state != 'posted' ||
      invoice.amountResidual <= 0.000001) {
    throw StateError('La factura no tiene saldo pendiente cobrable.');
  }
  if (newLines.isEmpty ||
      newLines.any(
        (line) =>
            line.isSynced ||
            line.type != PaymentLineType.payment ||
            (line.lineUuid ?? line.uuid)?.trim().isEmpty != false,
      )) {
    throw StateError(
      'Agregue sólo pagos nuevos válidos para cobrar la factura.',
    );
  }
  final total = newLines.fold<double>(0, (sum, line) => sum + line.amount);
  if (total > invoice.amountResidual + 0.000001) {
    throw StateError('El cobro supera el saldo pendiente de la factura.');
  }
  return collector(
    saleOrderId: saleOrderId,
    invoiceId: invoice.id,
    collectionSessionId: collectionSessionId,
    operatorId: operatorId,
    operationUuid: existingInvoiceCollectionOperationUuid(invoice.id, newLines),
    lines: newLines,
  );
}

class POSPaymentTab extends ConsumerStatefulWidget {
  const POSPaymentTab({super.key});

  @override
  ConsumerState<POSPaymentTab> createState() => _POSPaymentTabState();
}

class _POSPaymentTabState extends ConsumerState<POSPaymentTab> {
  // State for save button
  bool _isSaving = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final activeTab = ref.watch(fastSaleActiveTabProvider);
    final paymentLines = ref.watch(posPaymentLinesProvider);
    final withholdLines = ref.watch(posWithholdLinesProvider);
    final journalsAsync = ref.watch(posAvailableJournalsProvider);
    final currentSession = ref.watch(currentSessionProvider);
    final inputCapabilities = ref.watch(fastSaleInputCapabilitiesProvider);

    // Calculate totals (considering withholdings)
    final orderTotal = activeTab?.total ?? 0.0;
    final totalWithheld = withholdLines.fold(0.0, (sum, l) => sum + l.amount);
    final amountToCollect =
        orderTotal - totalWithheld; // Total a cobrar = Total - Retención
    final totalPaid = paymentLines.fold(0.0, (sum, l) => sum + l.amount);
    final pendingAmount = amountToCollect - totalPaid;
    final isFullyPaid = pendingAmount <= 0.01;

    // Check if we can add payments (model: state == sale || approved)
    final order = activeTab?.order;
    final canAddPayments =
        order != null &&
        order.canAddPayments &&
        currentSession?.canRegisterTransactions == true;

    // Show "confirm first" message only when order state is not sale/approved
    // NOT when hasQueuedInvoice is true (that case should show payments read-only)
    final isOrderConfirmed =
        order != null &&
        (order.state == SaleOrderState.sale ||
            order.state == SaleOrderState.approved);
    final orderNotConfirmed = order != null && !isOrderConfirmed;

    return Column(
      children: [
        // Summary header
        _buildSummaryHeader(
          theme,
          orderTotal,
          totalWithheld,
          amountToCollect,
          totalPaid,
          pendingAmount,
          isFullyPaid,
          inputCapabilities,
        ),

        // Note: Credit info is displayed in the right panel (POSCreditInfoCard)
        // to avoid duplication and use the single source of truth from local DB
        const SizedBox(height: Spacing.sm),

        // Content
        Expanded(
          child: orderNotConfirmed
              ? _buildConfirmFirstMessage(theme)
              : currentSession == null
              ? _buildNoSessionMessage(theme)
              : !currentSession.canRegisterTransactions
              ? _buildInactiveSessionMessage(theme, currentSession)
              : journalsAsync.when(
                  loading: () => const Center(child: ProgressRing()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (journals) => _buildPaymentContent(
                    context,
                    theme,
                    activeTab,
                    paymentLines,
                    journals,
                    pendingAmount,
                    isFullyPaid,
                    inputCapabilities,
                  ),
                ),
        ),

        // Action buttons:
        // - Show save/invoice buttons when canAddPayments is true and there are payments
        // - Show print button when hasQueuedInvoice is true (even if canAddPayments is false)
        if (activeTab != null &&
            (((canAddPayments || (activeTab.order?.isFullyInvoiced ?? false)) &&
                    paymentLines.isNotEmpty) ||
                (activeTab.order?.hasQueuedInvoice ?? false)))
          _buildActionButtons(
            context,
            theme,
            activeTab,
            paymentLines,
            isFullyPaid,
            inputCapabilities,
          ),
      ],
    );
  }

  Widget _buildSummaryHeader(
    FluentThemeData theme,
    double orderTotal,
    double totalWithheld,
    double amountToCollect,
    double totalPaid,
    double pendingAmount,
    bool isFullyPaid,
    AdaptiveInputCapabilities inputCapabilities,
  ) {
    // Simplified summary: only show what matters for payment
    // A COBRAR = Total - Retenciones (what customer pays)
    // PAGADO = Payments received
    // PENDIENTE = What's left to collect

    return Padding(
      padding: const EdgeInsets.all(Spacing.sm),
      child: OdooSummaryCard(
        backgroundColor: isFullyPaid
            ? AppColors.success.withValues(alpha: 0.1)
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.md,
          vertical: Spacing.sm,
        ),
        children: [
          AdaptivePaymentMetrics(
            inputCapabilities: inputCapabilities,
            items: [
              _buildSummaryItem(
                theme,
                'A COBRAR',
                amountToCollect,
                color: AppColors.info,
              ),
              _buildSummaryItem(
                theme,
                'RETENIDO',
                totalWithheld,
                color: totalWithheld > 0
                    ? AppColors.warning
                    : theme.inactiveColor,
              ),
              _buildSummaryItem(
                theme,
                'PAGADO',
                totalPaid,
                color: AppColors.success,
              ),
              _buildSummaryItem(
                theme,
                isFullyPaid ? 'COMPLETADO' : 'PENDIENTE',
                pendingAmount.abs(),
                color: isFullyPaid ? AppColors.success : AppColors.warning,
                icon: isFullyPaid ? FluentIcons.check_mark : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    FluentThemeData theme,
    String label,
    double amount, {
    Color? color,
    IconData? icon,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.typography.caption?.copyWith(
            color: color ?? theme.inactiveColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: Spacing.xxs),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: color),
              const SizedBox(width: Spacing.xxs),
            ],
            Text(
              amount.toCurrency(),
              style: theme.typography.subtitle?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildConfirmFirstMessage(FluentThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.info,
            size: 48,
            color: AppColors.info.withValues(alpha: 0.5),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Confirme la venta primero',
            style: theme.typography.subtitle?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Debe confirmar la orden antes de registrar pagos',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoSessionMessage(FluentThemeData theme) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.warning,
            size: 48,
            color: AppColors.warning.withValues(alpha: 0.5),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Sin sesión de cobranza',
            style: theme.typography.subtitle?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Abra una sesión de cobranza para registrar pagos',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildInactiveSessionMessage(
    FluentThemeData theme,
    CollectionSession session,
  ) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            FluentIcons.pause,
            size: 48,
            color: AppColors.warning.withValues(alpha: 0.5),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Sesión ${session.displayState.toLowerCase()}',
            style: theme.typography.subtitle?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Reanude la sesión de cobranza antes de registrar pagos',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPaymentContent(
    BuildContext context,
    FluentThemeData theme,
    FastSaleTabState? activeTab,
    List<PaymentLine> paymentLines,
    List<AvailableJournal> journals,
    double pendingAmount,
    bool isFullyPaid,
    AdaptiveInputCapabilities inputCapabilities,
  ) {
    final withholdLines = ref.watch(posWithholdLinesProvider);
    final withholdTaxesAsync = ref.watch(posWithholdTaxesStreamProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Withholdings section
          _buildWithholdingsSection(
            context,
            theme,
            activeTab,
            withholdLines,
            withholdTaxesAsync,
            inputCapabilities,
          ),

          const SizedBox(height: Spacing.md),
          const Divider(),
          const SizedBox(height: Spacing.sm),

          // Registered payments header with add button
          AdaptivePaymentActionRow(
            inputCapabilities: inputCapabilities,
            leading: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.list, size: 14, color: theme.accentColor),
                const SizedBox(width: Spacing.xs),
                Flexible(
                  child: Text(
                    'Pagos registrados (${paymentLines.length})',
                    style: theme.typography.bodyStrong,
                  ),
                ),
              ],
            ),
            trailing: !isFullyPaid && activeTab != null
                ? FilledButton(
                    onPressed: () => _showAddPaymentDialog(
                      context,
                      theme,
                      journals,
                      pendingAmount,
                      activeTab.orderId,
                      activeTab.order?.partnerId,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.add, size: 12),
                        const SizedBox(width: Spacing.xxs),
                        const Text('Agregar'),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          const SizedBox(height: Spacing.sm),

          // Payments list
          if (paymentLines.isNotEmpty && activeTab != null)
            ...paymentLines.map(
              (line) => _buildPaymentLineCard(
                theme,
                line,
                activeTab.orderId,
                isInvoiced: activeTab.order?.isFullyInvoiced ?? false,
              ),
            )
          else if (isFullyPaid)
            _buildFullyPaidMessage(theme)
          else
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.sm,
                vertical: Spacing.md,
              ),
              decoration: BoxDecoration(
                color: theme.cardColor.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: theme.resources.dividerStrokeColorDefault,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(FluentIcons.info, size: 14, color: theme.inactiveColor),
                  const SizedBox(width: Spacing.xs),
                  Text(
                    'Sin pagos registrados',
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Shows the add payment dialog
  void _showAddPaymentDialog(
    BuildContext context,
    FluentThemeData theme,
    List<AvailableJournal> journals,
    double pendingAmount,
    int orderId,
    int? partnerId,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AddPaymentDialogContent(
        theme: theme,
        journals: journals,
        pendingAmount: pendingAmount,
        orderId: orderId,
        partnerId: partnerId,
        onAddLine: (line) {
          ref
              .read(posPaymentLinesByOrderProvider.notifier)
              .addLine(orderId, line);
        },
        advancesProvider: posAvailableAdvancesStream,
        creditNotesProvider: posAvailableCreditNotesStream,
        partnerBanksProvider: posPartnerBanksStreamProvider,
        banksProvider: posAvailableBanksStreamProvider,
        ref: ref,
      ),
    );
  }

  Widget _buildWithholdingsSection(
    BuildContext context,
    FluentThemeData theme,
    FastSaleTabState? activeTab,
    List<WithholdLine> withholdLines,
    AsyncValue<List<AvailableWithholdTax>> withholdTaxesAsync,
    AdaptiveInputCapabilities inputCapabilities,
  ) {
    // Group lines by type
    final vatLines = withholdLines
        .where((l) => l.withholdType == WithholdType.vatSale)
        .toList();
    final incomeLines = withholdLines
        .where((l) => l.withholdType == WithholdType.incomeSale)
        .toList();
    final vatTotal = vatLines.fold(0.0, (sum, l) => sum + l.amount);
    final incomeTotal = incomeLines.fold(0.0, (sum, l) => sum + l.amount);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section header with add button
        AdaptivePaymentActionRow(
          inputCapabilities: inputCapabilities,
          leading: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                FluentIcons.calculator_percentage,
                size: 14,
                color: AppColors.warning,
              ),
              const SizedBox(width: Spacing.xs),
              Text('Retenciones', style: theme.typography.bodyStrong),
            ],
          ),
          trailing: withholdTaxesAsync.when(
            loading: () => const SizedBox(
              width: 16,
              height: 16,
              child: ProgressRing(strokeWidth: 2),
            ),
            error: (_, _) => const SizedBox(),
            data: (taxes) =>
                taxes.isNotEmpty &&
                    !(activeTab?.order?.isFullyInvoiced ?? false)
                ? Button(
                    onPressed: () => _showAddWithholdDialog(
                      context,
                      theme,
                      activeTab,
                      taxes,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.add, size: 12),
                        const SizedBox(width: Spacing.xxs),
                        const Text('Agregar'),
                      ],
                    ),
                  )
                : const SizedBox(),
          ),
        ),
        const SizedBox(height: Spacing.xs),

        // Grouped withholdings (IVA and Renta in one row)
        if (withholdLines.isEmpty)
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xs,
            ),
            decoration: BoxDecoration(
              color: theme.cardColor.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: theme.resources.dividerStrokeColorDefault,
              ),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.info, size: 12, color: theme.inactiveColor),
                const SizedBox(width: Spacing.xs),
                Text(
                  'Sin retenciones',
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),
              ],
            ),
          )
        else
          _buildGroupedWithholdCard(
            theme,
            vatLines: vatLines,
            vatTotal: vatTotal,
            incomeLines: incomeLines,
            incomeTotal: incomeTotal,
            orderId: activeTab!.orderId,
            isInvoiced: activeTab.order?.isFullyInvoiced ?? false,
          ),
      ],
    );
  }

  /// Builds an expandable card showing withholding details
  Widget _buildGroupedWithholdCard(
    FluentThemeData theme, {
    required List<WithholdLine> vatLines,
    required double vatTotal,
    required List<WithholdLine> incomeLines,
    required double incomeTotal,
    required int orderId,
    bool isInvoiced = false,
  }) {
    final allLines = [...vatLines, ...incomeLines];
    final totalAmount = vatTotal + incomeTotal;

    return Expander(
      initiallyExpanded: false,
      headerBackgroundColor: WidgetStateColor.resolveWith(
        (_) => AppColors.warning.withValues(alpha: 0.08),
      ),
      header: Row(
        children: [
          Icon(
            FluentIcons.calculator_percentage,
            size: 16,
            color: AppColors.warning,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Row(
              children: [
                // IVA summary
                if (vatLines.isNotEmpty) ...[
                  _buildWithholdChip(theme, 'IVA', vatTotal, vatLines.length),
                  const SizedBox(width: Spacing.sm),
                ],
                // Renta summary
                if (incomeLines.isNotEmpty)
                  _buildWithholdChip(
                    theme,
                    'Renta',
                    incomeTotal,
                    incomeLines.length,
                  ),
              ],
            ),
          ),
          // Total
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xxs,
            ),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Total: ${totalAmount.toCurrency()}',
              style: theme.typography.bodyStrong?.copyWith(
                color: AppColors.warning,
              ),
            ),
          ),
          const SizedBox(width: Spacing.sm),
          // Delete all button - hidden when invoiced
          if (!isInvoiced)
            Semantics(
              button: true,
              label: 'Eliminar todas las retenciones',
              child: Tooltip(
                message: 'Eliminar todas las retenciones',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: IconButton(
                    icon: Icon(
                      FluentIcons.delete,
                      size: 16,
                      color: AppColors.danger,
                    ),
                    onPressed: () {
                      for (final line in allLines) {
                        ref
                            .read(posWithholdLinesByOrderProvider.notifier)
                            .removeLine(orderId, line.lineUuid);
                      }
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
      content: Container(
        padding: const EdgeInsets.all(Spacing.sm),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Detail table header
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Spacing.xs,
                vertical: Spacing.xxs,
              ),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      'Retención',
                      style: theme.typography.caption?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Base',
                      style: theme.typography.caption?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  Expanded(
                    flex: 1,
                    child: Text(
                      '%',
                      style: theme.typography.caption?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'Monto',
                      style: theme.typography.caption?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  ),
                  const SizedBox(width: 32), // Space for delete button
                ],
              ),
            ),
            const SizedBox(height: Spacing.xxs),
            // Detail rows
            ...allLines.map(
              (line) => _buildWithholdDetailRow(
                theme,
                line,
                orderId,
                isInvoiced: isInvoiced,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Builds a compact chip showing withhold type summary
  Widget _buildWithholdChip(
    FluentThemeData theme,
    String type,
    double amount,
    int count,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Spacing.xs, vertical: 2),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            type,
            style: theme.typography.caption?.copyWith(
              color: AppColors.warning,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: Spacing.xxs),
          Text(
            amount.toCurrency(),
            style: theme.typography.caption?.copyWith(color: AppColors.warning),
          ),
          Text(
            ' ($count)',
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  /// Builds a detail row for a single withhold line
  Widget _buildWithholdDetailRow(
    FluentThemeData theme,
    WithholdLine line,
    int orderId, {
    bool isInvoiced = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs,
        vertical: Spacing.xxs,
      ),
      margin: const EdgeInsets.only(bottom: 2),
      decoration: BoxDecoration(
        color: theme.cardColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          // Tax name
          Expanded(
            flex: 3,
            child: Text(
              line.taxName,
              style: theme.typography.caption,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Base
          Expanded(
            flex: 2,
            child: Text(
              line.base.toCurrency(),
              style: theme.typography.caption,
              textAlign: TextAlign.right,
            ),
          ),
          // Percentage
          Expanded(
            flex: 1,
            child: Text(
              '${line.taxPercent.toFixed(0)}%',
              style: theme.typography.caption?.copyWith(
                color: AppColors.warning,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          // Amount
          Expanded(
            flex: 2,
            child: Text(
              line.amount.toCurrency(),
              style: theme.typography.caption?.copyWith(
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.right,
            ),
          ),
          // Delete button - hidden when order is invoiced
          if (!isInvoiced)
            SizedBox(
              width: 44,
              child: Tooltip(
                message: 'Eliminar retención',
                child: Semantics(
                  button: true,
                  label: 'Eliminar retención',
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: IconButton(
                      icon: Icon(
                        FluentIcons.delete,
                        size: 16,
                        color: AppColors.danger,
                      ),
                      onPressed: () {
                        ref
                            .read(posWithholdLinesByOrderProvider.notifier)
                            .removeLine(orderId, line.lineUuid);
                      },
                    ),
                  ),
                ),
              ),
            )
          else
            const SizedBox(width: 44), // Placeholder to maintain alignment
        ],
      ),
    );
  }

  void _showAddWithholdDialog(
    BuildContext context,
    FluentThemeData theme,
    FastSaleTabState? activeTab,
    List<AvailableWithholdTax> taxes,
  ) {
    if (activeTab == null) return;

    final orderTotal = activeTab.total;
    final orderTax = activeTab.taxTotal;
    final orderSubtotal = activeTab.subtotal;

    // Separate taxes by type
    final vatTaxes = taxes
        .where((t) => t.withholdType == WithholdType.vatSale)
        .toList();
    final incomeTaxes = taxes
        .where((t) => t.withholdType == WithholdType.incomeSale)
        .toList();

    showDialog(
      context: context,
      builder: (context) => AddWithholdDialogContent(
        theme: theme,
        orderTotal: orderTotal,
        orderTax: orderTax,
        orderSubtotal: orderSubtotal,
        vatTaxes: vatTaxes,
        incomeTaxes: incomeTaxes,
        orderId: activeTab.orderId,
        onAddLine: (line) {
          ref
              .read(posWithholdLinesByOrderProvider.notifier)
              .addLine(activeTab.orderId, line);
        },
      ),
    );
  }

  Widget _buildPaymentLineCard(
    FluentThemeData theme,
    PaymentLine line,
    int orderId, {
    bool isInvoiced = false,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Row(
        children: [
          // Icon based on payment type
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _getPaymentTypeColor(line.type).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(
              _getPaymentTypeIcon(line.type),
              size: 16,
              color: _getPaymentTypeColor(line.type),
            ),
          ),
          const SizedBox(width: Spacing.sm),

          // Description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.description,
                  style: theme.typography.body?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (line.reference != null)
                  Text(
                    'Ref: ${line.reference}',
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ),
              ],
            ),
          ),

          // Amount
          Text(
            line.amount.toCurrency(),
            style: theme.typography.bodyStrong?.copyWith(
              color: AppColors.success,
            ),
          ),

          const SizedBox(width: Spacing.xs),

          // Delete button - hidden when order is invoiced
          if (!isInvoiced)
            Tooltip(
              message: 'Eliminar pago',
              child: IconButton(
                icon: Icon(
                  FluentIcons.delete,
                  size: 14,
                  color: AppColors.danger,
                ),
                onPressed: () {
                  ref
                      .read(posPaymentLinesByOrderProvider.notifier)
                      .removeLine(orderId, line.id);
                },
              ),
            ),
        ],
      ),
    );
  }

  // NOTE: Old inline form methods removed - now using AddPaymentDialogContent
  // REMOVED: _buildCashSection, _buildCardSection, _buildChequeSection,
  //          _buildTransferSection, _buildAdvanceFields, _buildCreditNoteFields,
  //          _buildValidationAlerts, _buildAlert, _buildAddButton, _buildQuickCashButtons
  // These are now in AddPaymentDialogContentState class

  Widget _buildFullyPaidMessage(FluentThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.success.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.completed, size: 32, color: AppColors.success),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Pago completo',
                  style: theme.typography.bodyStrong?.copyWith(
                    color: AppColors.success,
                  ),
                ),
                Text(
                  'La orden está lista para facturar',
                  style: theme.typography.caption?.copyWith(
                    color: AppColors.success,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(
    BuildContext context,
    FluentThemeData theme,
    FastSaleTabState activeTab,
    List<PaymentLine> paymentLines,
    bool isFullyPaid,
    AdaptiveInputCapabilities inputCapabilities,
  ) {
    final order = activeTab.order;
    final hasQueuedInvoice = order?.hasQueuedInvoice ?? false;
    final isFullyInvoiced = order?.isFullyInvoiced ?? false;
    final canInvoice = (order?.canInvoice ?? false) || isFullyInvoiced;

    // A queued invoice cannot accept another payment. A posted invoice may,
    // however, receive additional collection lines through the existing-
    // invoice operation below.
    // Print is handled by InvoiceSection which follows offline-first pattern
    if (hasQueuedInvoice || (isFullyInvoiced && paymentLines.isEmpty)) {
      return Container(
        padding: const EdgeInsets.all(Spacing.sm),
        decoration: BoxDecoration(
          color: theme.cardColor,
          border: Border(
            top: BorderSide(color: theme.resources.dividerStrokeColorDefault),
          ),
        ),
        child: Row(
          children: [
            Icon(
              hasQueuedInvoice
                  ? FluentIcons.cloud_upload
                  : FluentIcons.check_mark,
              size: 16,
              color: hasQueuedInvoice ? AppColors.warning : AppColors.success,
            ),
            const SizedBox(width: Spacing.xs),
            Flexible(
              child: Text(
                hasQueuedInvoice
                    ? 'Factura pendiente de sincronización'
                    : 'Orden facturada',
                style: theme.typography.caption?.copyWith(
                  color: hasQueuedInvoice
                      ? AppColors.warning
                      : AppColors.success,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: theme.cardColor,
        border: Border(
          top: BorderSide(color: theme.resources.dividerStrokeColorDefault),
        ),
      ),
      child: AdaptivePaymentActionRow(
        inputCapabilities: inputCapabilities,
        stretchInCompact: true,
        leading:
            // Clear all button
            Button(
              onPressed: _isSaving
                  ? null
                  : () {
                      ref
                          .read(posPaymentLinesByOrderProvider.notifier)
                          .clear(activeTab.orderId);
                    },
              child: Row(
                children: [
                  Icon(FluentIcons.delete, size: 14, color: AppColors.danger),
                  const SizedBox(width: Spacing.xs),
                  const Text('Limpiar'),
                ],
              ),
            ),
        trailing:
            // Save button - only show if can invoice
            FilledButton(
              onPressed: (_isSaving || !canInvoice)
                  ? null
                  : () => _savePayments(
                      context,
                      activeTab,
                      paymentLines,
                      isFullyPaid,
                    ),
              style: ButtonStyle(
                backgroundColor: WidgetStateProperty.all(
                  isFullyPaid ? AppColors.success : theme.accentColor,
                ),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: ProgressRing(strokeWidth: 2),
                    )
                  : Row(
                      children: [
                        Icon(
                          isFullyPaid
                              ? FluentIcons.document_set
                              : FluentIcons.save,
                          size: 16,
                        ),
                        const SizedBox(width: Spacing.xs),
                        Text(
                          isFullyPaid ? 'Guardar y Facturar' : 'Guardar Pagos',
                        ),
                      ],
                    ),
            ),
      ),
    );
  }

  Future<void> _savePayments(
    BuildContext context,
    FastSaleTabState activeTab,
    List<PaymentLine> paymentLines,
    bool isFullyPaid,
  ) async {
    if (activeTab.order == null) return;

    // Prevent duplicate invoice creation - check if already saving
    if (_isSaving) {
      logger.w('[POSPaymentTab]', 'Already saving, ignoring duplicate request');
      return;
    }

    // Check if order already has a queued invoice - prevent duplicates
    final order = activeTab.order!;
    if (order.hasQueuedInvoice) {
      logger.w(
        '[POSPaymentTab]',
        'Order ${order.id} already has invoice (hasQueuedInvoice=${order.hasQueuedInvoice}, isFullyInvoiced=${order.isFullyInvoiced})',
      );
      if (context.mounted) {
        CopyableInfoBar.showWarning(
          context,
          title: 'Factura ya existe',
          message: order.isFullyInvoiced
              ? 'Esta orden ya tiene una factura'
              : 'Esta orden ya tiene una factura pendiente de sincronización',
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final currentSession = ref.read(currentSessionProvider);
      if (currentSession?.canRegisterTransactions != true) {
        if (context.mounted) {
          CopyableInfoBar.showWarning(
            context,
            title: 'Sesión no disponible',
            message: currentSession == null
                ? 'Abra una sesión de cobranza antes de registrar pagos.'
                : 'Reanude la sesión de cobranza antes de registrar pagos.',
          );
        }
        return;
      }
      final withholdLines = ref.read(posWithholdLinesProvider);

      // Already-issued invoices are collected through the dedicated native
      // wizard. Never fall through to the create-invoice operation: that
      // would emit a second invoice and lose the existing invoice's payment
      // history. Payment lines created by the dialog carry stable UUIDs;
      // only unsynced lines are submitted so a retry cannot duplicate old
      // collections.
      if (order.isFullyInvoiced) {
        final gateway = ref.read(existingInvoiceCollectionUiGatewayProvider);
        final invoices = await gateway.loadInvoices(order.id);
        final invoice = invoices
            .where(
              (candidate) =>
                  candidate.moveType == 'out_invoice' &&
                  candidate.state == 'posted' &&
                  candidate.amountResidual > 0.000001,
            )
            .firstOrNull;
        final queuedLineUuids = await gateway.loadQueuedLineUuids(order.id);
        final newLines = paymentLines
            .where((line) => !line.isSynced)
            .toList(growable: false);
        final operatorId =
            currentSession?.userId ??
            (await ref.read(currentUserProvider.future))?.id;
        if (invoice == null || operatorId == null) {
          throw StateError(
            'No se encontró una factura cobrable o un operador válido.',
          );
        }
        await collectExistingInvoiceFromPos(
          saleOrderId: order.id,
          invoice: invoice,
          collectionSessionId: currentSession!.id,
          operatorId: operatorId,
          lines: newLines,
          queuedLineUuids: queuedLineUuids,
          collector: gateway.collect,
        );
        await gateway.reloadPaymentLines(activeTab.orderId);
        if (context.mounted) {
          CopyableInfoBar.showSuccess(
            context,
            title: 'Pago guardado',
            message: 'El cobro se registró sobre la factura existente.',
          );
        }
        return;
      }

      final paymentService = ref.read(paymentServiceProvider);
      final salesRepo = ref.read(salesRepositoryProvider);

      // NOTE: Withhold lines are already saved/queued when added via posWithholdLinesByOrderProvider.addLine()
      // No need to re-save them here - that would create duplicate operations

      if (isFullyPaid) {
        // Save and create invoice
        logger.d(
          '[POSPaymentTab]',
          'Calling savePaymentLinesAndCreateInvoice...',
        );
        var paymentResult = await paymentService
            .savePaymentLinesAndCreateInvoice(
              activeTab.order!.id,
              paymentLines,
              collectionSessionId: currentSession?.id,
            );
        logger.d(
          '[POSPaymentTab]',
          'savePaymentLinesAndCreateInvoice returned: $paymentResult',
        );

        if (paymentResult?.requiresOverpaymentConfirmation == true) {
          if (!context.mounted) return;
          final overpayment = paymentResult!.overpaymentAmount ?? 0;
          final action = await OverpaymentDialog.show(
            context: context,
            orderTotal: activeTab.total,
            totalPaid: paymentLines.fold<double>(
              0,
              (sum, line) => sum + line.amount,
            ),
            overpayment: overpayment,
            // The server never permits cash overpayment here. Any excess
            // returned by this action came from a non-cash line and must be
            // converted into an advance or corrected by the cashier.
            hasCashPayment: false,
            partnerName: activeTab.order!.partnerName,
          );
          if (action != OverpaymentAction.createAdvance) {
            if (context.mounted) {
              CopyableInfoBar.showWarning(
                context,
                title: 'Cobro sin completar',
                message: 'Ajuste los pagos para eliminar el sobrepago antes de facturar.',
              );
            }
            return;
          }
          paymentResult = await paymentService
              .confirmOverpaymentAndCreateInvoice(paymentResult);
        }

        final invoiceId = paymentResult?.invoiceId;

        if (invoiceId != null && context.mounted) {
          // Get invoice number
          final invoiceData = await paymentService.getInvoiceSummary(invoiceId);
          final invoiceName = invoiceData?['name'] as String?;

          // Reload order to update state (should now be 'sale')
          await ref.read(fastSaleProvider.notifier).reloadActiveOrder();

          // After invoicing, payments have been processed to account.payment in Odoo
          // and are no longer in l10n_ec_collection_box.sale.order.payment
          // So we only load from local DB (don't sync from Odoo which would clear them)
          await ref
              .read(posPaymentLinesByOrderProvider.notifier)
              .loadFromDb(activeTab.orderId);
          await ref
              .read(posWithholdLinesByOrderProvider.notifier)
              .loadFromDb(activeTab.orderId);

          if (context.mounted) {
            CopyableInfoBar.showSuccess(
              context,
              title: 'Factura creada',
              message:
                  'Factura ${invoiceName ?? invoiceId} generada correctamente',
            );
          }
        } else if (context.mounted) {
          // Invoice creation failed (likely offline) - create offline invoice and queue for later
          if (salesRepo != null) {
            // Get ALL local payment lines for this order (not just new ones)
            final allLocalPayments = await salesRepo
                .getLocalPaymentLinesForOrder(activeTab.order!.id);
            // bankId/bankName son @OdooLocalOnly; el guard conserva el banco
            // custom l10n.ec.bank y su nombre en el comando offline.
            final allPaymentLinesData = allLocalPayments
                .map(
                  (line) => paymentService.applyBankFieldGuard(
                    paymentLineManager.toOdoo(line),
                    line,
                  ),
                )
                .toList();

            logger.i(
              '[POSPaymentTab]',
              'Creating offline invoice for order ${activeTab.order!.id} with ${allPaymentLinesData.length} payment lines',
            );

            // Create offline invoice with SRI access key and queue for sync
            final offlineInvoice = await salesRepo.queueInvoiceWithPayments(
              saleOrderId: activeTab.order!.id,
              paymentLines: allPaymentLinesData,
              collectionSessionId: currentSession?.id,
            );

            logger.d(
              '[POSPaymentTab]',
              'Offline invoice result: ${offlineInvoice?.invoiceName ?? "NULL"}',
            );

            // El contador de pendientes se actualiza automáticamente via Drift watch

            // Reload order to get hasQueuedInvoice flag
            await ref.read(fastSaleProvider.notifier).reloadActiveOrder();

            // Reload from local DB to show saved payments
            await ref
                .read(posPaymentLinesByOrderProvider.notifier)
                .loadFromDb(activeTab.orderId);
            await ref
                .read(posWithholdLinesByOrderProvider.notifier)
                .loadFromDb(activeTab.orderId);

            // Show appropriate message based on whether offline invoice was created
            if (!context.mounted) return;
            if (offlineInvoice != null) {
              CopyableInfoBar.showSuccess(
                context,
                title: 'Factura creada (offline)',
                message:
                    'Factura ${offlineInvoice.invoiceName} creada localmente.\n'
                    'Se sincronizará con el SRI cuando haya conexión.',
              );
            } else {
              CopyableInfoBar.showWarning(
                context,
                title: 'Pagos guardados',
                message: 'La factura se generará cuando haya conexión',
              );
            }
          }
        }
      } else {
        // Just save payments
        final success = await paymentService.savePaymentLines(
          activeTab.order!.id,
          paymentLines,
          collectionSessionId: currentSession?.id,
        );

        if (success && context.mounted) {
          // Reload payment and withhold lines from DB to show saved state
          // This keeps previously saved payments visible
          await ref
              .read(posPaymentLinesByOrderProvider.notifier)
              .syncAndLoad(activeTab.orderId);
          await ref
              .read(posWithholdLinesByOrderProvider.notifier)
              .syncAndLoad(activeTab.orderId);

          if (!context.mounted) return;
          CopyableInfoBar.showSuccess(
            context,
            title: 'Pagos guardados',
            message:
                'Se guardaron ${paymentLines.length} pago(s)${withholdLines.isNotEmpty ? ' y ${withholdLines.length} retención(es)' : ''}',
          );
        }
      }
    } catch (e) {
      logger.e('[POSPaymentTab]', 'Error saving payments: $e');
      if (context.mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error de pago',
          message: e is OdooException ? e.message : friendlyErrorMessage(e),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  IconData _getPaymentTypeIcon(PaymentLineType type) {
    switch (type) {
      case PaymentLineType.payment:
        return FluentIcons.money;
      case PaymentLineType.advance:
        return FluentIcons.circle_dollar;
      case PaymentLineType.creditNote:
        return FluentIcons.page_list;
    }
  }

  Color _getPaymentTypeColor(PaymentLineType type) {
    switch (type) {
      case PaymentLineType.payment:
        return AppColors.success;
      case PaymentLineType.advance:
        return AppColors.advance;
      case PaymentLineType.creditNote:
        return AppColors.creditNote;
    }
  }
}

/// Reflow de las cuatro métricas de cobro según el ancho local del panel.
class AdaptivePaymentMetrics extends StatelessWidget {
  const AdaptivePaymentMetrics({
    super.key,
    required this.inputCapabilities,
    required this.items,
  }) : assert(items.length == 4);

  static const compactKey = Key('payment-metrics-compact');
  static const inlineKey = Key('payment-metrics-inline');

  final AdaptiveInputCapabilities inputCapabilities;
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : size.width;
        final policy = AdaptiveUiPolicy(
          AdaptiveEnvironment(
            width: width,
            height: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : size.height,
            inputs: inputCapabilities,
          ),
        );

        if (policy.environment.sizeClass == AdaptiveSizeClass.compact) {
          final itemWidth = (width - Spacing.xs) / 2;
          return Wrap(
            key: compactKey,
            spacing: Spacing.xs,
            runSpacing: Spacing.sm,
            children: [
              for (final item in items) SizedBox(width: itemWidth, child: item),
            ],
          );
        }

        return Row(
          key: inlineKey,
          children: [
            for (var index = 0; index < items.length; index++) ...[
              Expanded(child: items[index]),
              if (index < items.length - 1)
                Container(
                  width: 1,
                  height: 50,
                  color: theme.resources.dividerStrokeColorDefault,
                ),
            ],
          ],
        );
      },
    );
  }
}

/// Encabezados y footers que apilan acciones en compact y las mantienen en
/// línea cuando el ancho local lo permite.
class AdaptivePaymentActionRow extends StatelessWidget {
  const AdaptivePaymentActionRow({
    super.key,
    required this.inputCapabilities,
    required this.leading,
    required this.trailing,
    this.stretchInCompact = false,
  });

  static const compactKey = Key('payment-actions-compact');
  static const inlineKey = Key('payment-actions-inline');

  final AdaptiveInputCapabilities inputCapabilities;
  final Widget leading;
  final Widget trailing;
  final bool stretchInCompact;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MediaQuery.sizeOf(context);
        final width = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : size.width;
        final policy = AdaptiveUiPolicy(
          AdaptiveEnvironment(
            width: width,
            height: constraints.maxHeight.isFinite
                ? constraints.maxHeight
                : size.height,
            inputs: inputCapabilities,
          ),
        );
        final minimumExtent = policy.minimumInteractiveExtent;

        Widget target(Widget child) => ConstrainedBox(
          constraints: BoxConstraints(minHeight: minimumExtent),
          child: child,
        );

        if (policy.environment.sizeClass == AdaptiveSizeClass.compact) {
          return Column(
            key: compactKey,
            crossAxisAlignment: stretchInCompact
                ? CrossAxisAlignment.stretch
                : CrossAxisAlignment.start,
            children: [
              target(leading),
              const SizedBox(height: Spacing.xs),
              if (stretchInCompact)
                target(trailing)
              else
                Align(
                  alignment: AlignmentDirectional.centerEnd,
                  child: target(trailing),
                ),
            ],
          );
        }

        return Row(
          key: inlineKey,
          children: [
            Expanded(child: target(leading)),
            const SizedBox(width: Spacing.sm),
            target(trailing),
          ],
        );
      },
    );
  }
}
