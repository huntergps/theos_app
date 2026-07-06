import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/constants/app_colors.dart';
import '../../../../../core/database/providers.dart';
import '../../../../../core/database/repositories/repository_providers.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../shared/providers/menu_provider.dart';
import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../../shared/providers/user_provider.dart';
import '../../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../../clients/clients.dart' show clientRepositoryProvider;
import 'package:theos_pos_core/theos_pos_core.dart';
import '../../../../invoices/invoices.dart';
import '../../../providers/service_providers.dart';
import '../../../widgets/payment/withholding_dialog.dart';
import '../../../../advances/widgets/advance_registration_dialog.dart';
import '../../../providers/providers.dart' show saleOrderFormProvider;
import '../fast_sale_providers.dart';
import 'confirm_order_handler.dart' show confirmOrderWithCreditCheck;

part 'pos_overflow_actions_button.dart';
part 'pos_action_item_button.dart';
part 'pos_close_current_tab_widget.dart';
part 'pos_final_consumer_warning_banner.dart';
part 'pos_credit_note_selection_dialog.dart';
part 'pos_cash_out_dialog.dart';

/// Helper to ensure collection session is loaded (offline-first).
///
/// Delegado único para cargar la sesión: usa [CurrentSession.ensureLoaded()]
/// que centraliza la lógica de "cargar desde BD si el provider está vacío".
/// Esto elimina la duplicación con [posAvailableJournalsProvider] y splash_screen.
Future<CollectionSession?> ensureSessionLoaded(WidgetRef ref) async {
  return ref.read(currentSessionProvider.notifier).ensureLoaded();
}

/// Navigate to payments tab, confirming order first if it is in draft state.
///
/// If the active order is still in draft (quotation), shows a quick dialog
/// asking the user to confirm and pay in one step. On acceptance, the order
/// is confirmed (with credit check) and then the payments tab is opened.
///
/// Top-level (no `_` prefix) para que también pueda invocarse desde el
/// atajo de teclado F6 ("Cobrar") en `fast_sale_screen.dart`, no solo desde
/// el botón "Cobrar" del panel de acciones.
Future<void> goToPaymentsWithAutoConfirm(
  BuildContext context,
  WidgetRef ref,
  FastSaleTabState? activeTab,
) async {
  final order = activeTab?.order;

  // If the order is in draft/quotation, auto-confirm before going to payments
  if (order != null && order.state == SaleOrderState.draft) {
    final hasLines = activeTab != null && activeTab.lines.isNotEmpty;
    final hasPartner = order.partnerId != null;

    // Check minimum requirements to confirm
    if (!hasLines || !hasPartner) {
      final missing = <String>[];
      if (!hasLines) missing.add('líneas de producto');
      if (!hasPartner) missing.add('un cliente');
      if (!context.mounted) return;
      CopyableInfoBar.showWarning(
        context,
        title: 'Faltan datos para confirmar',
        message: 'Agrega ${missing.join(' y ')} antes de registrar el cobro.',
      );
      return;
    }

    if (!context.mounted) return;

    // Show quick confirm-and-pay dialog
    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Confirmar y Cobrar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'La orden ${order.name} está en borrador.',
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            const SizedBox(height: Spacing.sm),
            const Text(
              'Para registrar el cobro, primero se debe confirmar la orden.',
            ),
            const SizedBox(height: Spacing.sm),
            const Text(
              '¿Confirmar la orden y continuar al cobro?',
            ),
          ],
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppColors.success),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar y Cobrar'),
          ),
        ],
      ),
    );

    if (proceed != true || !context.mounted) return;

    // Confirm the order (full flow with credit check)
    await confirmOrderWithCreditCheck(context, ref);

    // After confirmation, check if it succeeded (state should no longer be draft)
    if (!context.mounted) return;
    final updatedOrder = ref.read(fastSaleActiveTabProvider)?.order;
    if (updatedOrder?.state == SaleOrderState.draft) {
      // Confirmation failed or was cancelled — do not navigate to payments
      return;
    }
  }

  // Navigate to payments tab
  ref.read(orderPanelTabProvider.notifier).goToPayments();
}

/// Provider to check if current user has collection permissions
final hasCollectionPermissionsProvider = Provider<bool>((ref) {
  final user = ref.watch(userProvider);
  if (user == null) return false;

  final permissions = user.permissions;

  // Check admin groups first
  for (final adminGroup in adminGroups) {
    if (permissions.contains(adminGroup)) return true;
  }

  // Check collection groups
  for (final collectionGroup in collectionGroups) {
    if (permissions.contains(collectionGroup)) return true;
  }

  return false;
});

/// Right panel with quick action buttons
///
/// Vertical buttons with icon + text:
/// 1. Retencion (withholding tax)
/// 2. Nota de Credito (credit note)
/// 3. Anadir Cliente (add customer)
/// 4. Salida de Dinero (cash out)
/// 5. Registrar Pago (register payment)
/// 6. Registrar Anticipo (register advance)
class POSActionsPanel extends ConsumerWidget {
  /// Whether to show actions horizontally (for tablet/mobile bottom bar)
  final bool isHorizontal;

  /// Whether to show in compact mode (smaller icons, no text)
  final bool isCompact;

  const POSActionsPanel({
    super.key,
    this.isHorizontal = false,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final activeTab = ref.watch(fastSaleActiveTabProvider);

    // Check if user has collection permissions
    final hasCollectionPermissions = ref.watch(hasCollectionPermissionsProvider);
    if (!hasCollectionPermissions) {
      return const SizedBox.shrink();
    }

    // Get order state info from model getters
    final order = activeTab?.order;
    final hasOrder = order != null;
    final hasLines = activeTab != null && activeTab.lines.isNotEmpty;
    final hasPartner = order?.partnerId != null;

    // Use model getters for action visibility
    // Note: canLock/canUnlock already include isFullyInvoiced check in the model
    // Don't show Confirmar if order already has invoice (queued or synced)
    final hasInvoice = order?.hasQueuedInvoice == true || order?.isFullyInvoiced == true;
    final canConfirm = hasOrder && order.canConfirm && hasLines && hasPartner && !hasInvoice;
    final canCancel = hasOrder && order.canCancel;
    final canLock = hasOrder && order.canLock;
    final canUnlock = hasOrder && order.canUnlock;

    // Check if order needs sync (not synced)
    final needsSync = hasOrder && order.isSynced == false;

    // Consumidor final sin nombre: se marca visualmente desde el inicio
    // (no solo cuando falla la sincronización — ver _handleSyncAll).
    final needsFinalConsumerName = hasOrder &&
        order.isFinalConsumer &&
        (order.endCustomerName == null || order.endCustomerName!.trim().isEmpty);

    final actions = <_ActionItem>[
      // Sincronizar: envía pendientes + actualiza datos del cliente y orden
      if (hasOrder)
        _ActionItem(
          icon: FluentIcons.sync,
          label: 'Sincronizar',
          color: needsSync ? AppColors.warning : AppColors.primaryBackground,
          onTap: () => _handleSyncAll(context, ref, activeTab),
        ),
      // Confirmar Venta button - only visible for draft, sent, approved states
      if (canConfirm)
        _ActionItem(
          icon: FluentIcons.check_mark,
          label: 'Confirmar (F9)',
          color: AppColors.success,
          onTap: () => _handleConfirmOrder(context, ref, activeTab),
          isPrimary: true,
        ),
      // Cancelar - visible based on order state and lock
      if (canCancel)
        _ActionItem(
          icon: FluentIcons.cancel,
          label: 'Cancelar',
          color: AppColors.danger,
          onTap: () => _handleCancelOrder(context, ref, activeTab),
        ),
      // Bloquear - only for sale state, not locked
      if (canLock)
        _ActionItem(
          icon: FluentIcons.lock,
          label: 'Bloquear',
          color: AppColors.textSecondary,
          onTap: () => _handleLockOrder(context, ref, order),
        ),
      // Desbloquear - only for sale state, locked
      if (canUnlock)
        _ActionItem(
          icon: FluentIcons.unlock,
          label: 'Desbloquear',
          color: AppColors.primaryBackground,
          onTap: () => _handleUnlockOrder(context, ref, order),
        ),
      // Facturar button removed - now handled in credit tab for credit sales
      _ActionItem(
        icon: FluentIcons.bank,
        label: 'Retencion',
        // TODO: Migrar a TheosTheme.info(context) cuando _ActionItem soporte BuildContext
        color: AppColors.primaryBackground,
        onTap: () => _showRetentionDialog(context, ref, activeTab),
      ),
      _ActionItem(
        icon: FluentIcons.page_list,
        label: 'Nota Credito',
        color: AppColors.creditNote,
        onTap: () => _showCreditNoteDialog(context, ref, activeTab),
      ),
      _ActionItem(
        icon: FluentIcons.money,
        label: 'Salida Dinero',
        color: AppColors.warning,
        onTap: () => _showCashOutDialog(context, ref),
      ),
      _ActionItem(
        icon: FluentIcons.payment_card,
        label: 'Cobrar',
        color: AppColors.success,
        onTap: () => goToPaymentsWithAutoConfirm(context, ref, activeTab),
      ),
      _ActionItem(
        icon: FluentIcons.circle_dollar,
        label: 'Anticipo',
        color: AppColors.advance,
        onTap: () => _showAdvanceDialog(context, ref, activeTab),
      ),
      _ActionItem(
        icon: FluentIcons.save,
        label: 'Guardar (F10)',
        color: AppColors.textSecondary,
        onTap: () => ref.read(fastSaleProvider.notifier).saveActiveOrder(),
      ),
      _ActionItem(
        icon: FluentIcons.add,
        label: 'Nueva Orden (F4)',
        color: AppColors.primaryBackground,
        onTap: () => ref.read(fastSaleProvider.notifier).addNewTab(),
      ),
    ];

    if (isHorizontal) {
      return _buildHorizontalLayout(
        context,
        ref,
        theme,
        actions,
        activeTab,
        needsFinalConsumerName,
      );
    }

    return _buildVerticalLayout(
      context,
      ref,
      theme,
      actions,
      activeTab,
      needsFinalConsumerName,
    );
  }

  Widget _buildVerticalLayout(
    BuildContext context,
    WidgetRef ref,
    FluentThemeData theme,
    List<_ActionItem> actions,
    FastSaleTabState? activeTab,
    bool needsFinalConsumerName,
  ) {
    return Container(
      color: theme.menuColor,
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
      child: SingleChildScrollView(
        child: Column(
        children: [
          // Close current tab widget
          if (activeTab != null)
            _CloseCurrentTabWidget(
              orderName: activeTab.orderName,
              onClose: () => _confirmCloseTab(context, ref, activeTab),
            ),
          if (needsFinalConsumerName) ...[
            const SizedBox(height: Spacing.xs),
            const _FinalConsumerWarningBanner(),
          ],
          const SizedBox(height: Spacing.sm),

          // Actions
          for (int i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(height: Spacing.xs),
            _ActionButton(
              action: actions[i],
              isCompact: isCompact,
            ),
          ],
        ],
      ),
      ),
    );
  }

  /// Labels de acciones primarias que siempre son visibles en la barra horizontal.
  ///
  /// Se seleccionaron las 5 más frecuentes para que quepan con área táctil
  /// de al menos 44 px de alto y evitar botones de 10px ilegibles junto a
  /// acciones destructivas (Cancelar junto a Confirmar).
  static const _primaryActionLabels = {
    'Confirmar (F9)',
    'Cobrar',
    'Guardar (F10)',
    'Nueva Orden (F4)',
    'Sincronizar',
  };

  Widget _buildHorizontalLayout(
    BuildContext context,
    WidgetRef ref,
    FluentThemeData theme,
    List<_ActionItem> actions,
    FastSaleTabState? activeTab,
    bool needsFinalConsumerName,
  ) {
    // Separa acciones primarias (visibles) de secundarias (overflow)
    final primaryActions =
        actions.where((a) => _primaryActionLabels.contains(a.label)).toList();
    final secondaryActions =
        actions.where((a) => !_primaryActionLabels.contains(a.label)).toList();

    return Container(
      color: theme.menuColor,
      // Mínimo 48 px de alto para área táctil accesible
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(
        vertical: Spacing.xs,
        horizontal: Spacing.sm,
      ),
      child: Row(
        children: [
          // Cierre de pestaña actual (compacto)
          if (activeTab != null)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.xs),
              child: _CloseCurrentTabWidget(
                orderName: activeTab.orderName,
                onClose: () => _confirmCloseTab(context, ref, activeTab),
                isCompact: true,
              ),
            ),

          // Alerta compacta de consumidor final sin nombre
          if (needsFinalConsumerName)
            const Padding(
              padding: EdgeInsets.only(right: Spacing.xs),
              child: _FinalConsumerWarningBanner(isCompact: true),
            ),

          // Acciones primarias — siempre visibles
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final action in primaryActions)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.xxs,
                      ),
                      child: _ActionButton(
                        action: action,
                        isCompact: isCompact,
                        isHorizontal: true,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // Menú de desbordamiento: acciones secundarias en Flyout de Fluent UI
          if (secondaryActions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(left: Spacing.xs),
              child: _OverflowActionsButton(actions: secondaryActions),
            ),
        ],
      ),
    );
  }



  /// Safely pop the navigator, deferring if it is locked during a transition.
  void _safePop(BuildContext context) {
    if (!context.mounted) return;
    try {
      Navigator.of(context).pop();
    } catch (_) {
      // Navigator was locked (e.g. during a route transition).
      // Defer the pop to the next frame when the navigator is idle.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          Navigator.of(context).pop();
        }
      });
    }
  }

  /// Handle sync order action
  /// Unified sync: sends pending operations + refreshes client + order data
  Future<void> _handleSyncAll(
    BuildContext context,
    WidgetRef ref,
    FastSaleTabState? activeTab,
  ) async {
    if (activeTab?.order == null) return;

    final order = activeTab!.order!;
    final orderId = order.id;

    logger.i('[POSActions]', '🔄 Starting sync for order ID: $orderId');

    // VALIDACIÓN PRE-SYNC: Obtener la orden local y validar
    final localOrder = await saleOrderManager.getSaleOrder(orderId);

    if (localOrder == null) {
      if (context.mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error al sincronizar',
          message: 'Orden no encontrada en la base de datos local',
        );
      }
      return;
    }

    // Validar consumidor final
    if (localOrder.isFinalConsumer &&
        (localOrder.endCustomerName == null ||
            localOrder.endCustomerName!.trim().isEmpty)) {
      if (context.mounted) {
        CopyableInfoBar.showWarning(
          context,
          title: 'Validación requerida',
          message:
              'El nombre del consumidor final es obligatorio cuando el cliente es Consumidor Final.\n\n'
              'Por favor edite la orden y complete el campo "Nombre Consumidor Final" antes de sincronizar.',
          durationSeconds: 10,
        );
      }
      return;
    }

    if (!context.mounted) return;

    try {
      final syncService = ref.read(offlineSyncServiceProvider);
      if (syncService == null) {
        throw Exception('Servicio de sincronización no disponible');
      }

      logger.d('[POSActions]', '📤 Processing queue for order $orderId...');

      // Process only operations for THIS specific order (in FIFO order)
      final result = await syncService.processSaleOrderQueue(orderId);

      logger.d(
        '[POSActions]',
        'Sync result for order $orderId: ${result.synced} synced, ${result.failed} failed',
      );

      if (result.hasErrors) {
        throw Exception(
          'Errores durante la sincronización: ${result.errors.join(", ")}',
        );
      }

      // Reload the order from server to get fresh data
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo != null) {
        await salesRepo.getById(orderId, forceRefresh: true);
        await salesRepo.getWithLines(orderId, forceRefresh: true);
      }

      // Refresh partner data (vat, phone, street, email, credit)
      final partnerId = order.partnerId;
      if (partnerId != null) {
        try {
          final clientRepo = ref.read(clientRepositoryProvider);
          await clientRepo?.refreshCreditData(partnerId);
        } catch (e) {
          logger.w('[POSActions]', 'Error refreshing partner $partnerId: $e');
        }
      }

      // Reload the active tab order
      await ref.read(fastSaleProvider.notifier).reloadActiveOrder();

      if (!context.mounted) return;
      CopyableInfoBar.showSuccess(
        context,
        title: 'Sincronizado',
        message: 'Orden y datos del cliente actualizados',
      );
    } catch (e) {
      logger.e('[POSActions]', 'Sync error: $e');

      if (!context.mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error de sincronización',
        message: 'No se pudo sincronizar la orden. Verifique su conexion e intente nuevamente.',
      );
    }
  }

  /// Show retention/withholding dialog with invoice search
  ///
  /// Flow:
  /// 1. Show invoice search dialog (pre-filled with order's invoice if available)
  /// 2. Check for existing active withholds on selected invoice
  /// 3. If has active withholds → BLOCK (don't allow another)
  /// 4. If invoice has a sale order with withhold lines → pre-fill dialog
  /// 5. Open WithholdingDialog to register retention
  Future<void> _showRetentionDialog(
    BuildContext context,
    WidgetRef ref,
    FastSaleTabState? activeTab,
  ) async {
    final invoiceRepo = ref.read(invoiceRepositoryProvider);

    // Determine initial search query from active order's invoice (if any)
    String? initialInvoiceQuery;
    int? orderPartnerId;
    String? orderPartnerName;

    if (activeTab?.order != null) {
      final order = activeTab!.order!;
      orderPartnerId = order.partnerId;
      orderPartnerName = order.partnerName;

      // If order has an invoice, get its name to pre-fill search
      if (order.state != SaleOrderState.draft) {
        try {
          final invoices = await invoiceRepo.getInvoicesForSaleOrder(order.id);
          if (invoices.isNotEmpty) {
            // Pre-fill with first invoice name
            initialInvoiceQuery = invoices.first.name.isNotEmpty
                ? invoices.first.name
                : null;
          }
        } catch (e) {
          // Ignore errors getting invoices, user can search manually
          logger.d('[POSActions]', 'Error getting order invoices: $e');
        }
      }
    }

    if (!context.mounted) return;

    // Step 1: Show invoice search dialog
    final selectedInvoice = await showSelectInvoiceDialog(
      context,
      initialQuery: initialInvoiceQuery,
    );

    if (selectedInvoice == null) return; // User cancelled

    if (!context.mounted) return;

    // Step 2: Check for existing active withholds - BLOCK if has any
    final withholdCount = await invoiceRepo.getActiveWithholdsCount(selectedInvoice.id);

    if (!context.mounted) return;

    if (withholdCount > 0) {
      // Invoice has existing active withholds - BLOCK registration
      await showDialog<void>(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Factura con retención activa'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(FluentIcons.warning, size: 48, color: AppColors.warning),
              const SizedBox(height: 16),
              Text(
                'La factura ${selectedInvoice.name.isNotEmpty ? selectedInvoice.name : selectedInvoice.id} '
                'ya tiene $withholdCount retención(es) activa(s) registrada(s).',
              ),
              const SizedBox(height: 12),
              const Text(
                'No se puede registrar otra retención en esta factura.',
                style: TextStyle(fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return; // Don't proceed
    }

    // Step 3: Get withhold lines from sale order (if any) to pre-fill
    List<WithholdLine> initialWithholdLines = [];
    final saleOrderId = selectedInvoice.saleOrderId;

    logger.i('[POSActions]', '=== WITHHOLD PRE-FILL DEBUG ===');
    logger.i('[POSActions]', 'Invoice: ${selectedInvoice.name} (odooId: ${selectedInvoice.id})');
    logger.i('[POSActions]', 'Invoice saleOrderId: $saleOrderId');

    if (saleOrderId != null) {
      try {
        final withholdService = ref.read(withholdServiceProvider);
        logger.i('[POSActions]', 'Calling getWithholdLines($saleOrderId)...');
        initialWithholdLines = await withholdService.getWithholdLines(saleOrderId);
        logger.i('[POSActions]', 'Got ${initialWithholdLines.length} withhold lines from order $saleOrderId');
        for (final line in initialWithholdLines) {
          logger.i('[POSActions]', '  - Line: taxId=${line.taxId}, taxName=${line.taxName}, base=${line.base}, amount=${line.amount}');
        }
      } catch (e, st) {
        logger.e('[POSActions]', 'Error getting withhold lines from order: $e', e, st);
        // Continue without pre-fill
      }
    } else {
      logger.w('[POSActions]', 'No saleOrderId on invoice, cannot pre-fill withhold lines');
    }

    if (!context.mounted) return;

    // Step 4: Show withholding dialog (with pre-filled lines if available)
    // Use partner from invoice or fallback to order
    final partnerId = selectedInvoice.partnerId ?? orderPartnerId;
    final partnerName = selectedInvoice.partnerName ?? orderPartnerName;

    final result = await WithholdingDialog.show(
      context: context,
      invoiceId: selectedInvoice.id,
      invoiceName: selectedInvoice.name.isNotEmpty
          ? selectedInvoice.name
          : 'Factura ${selectedInvoice.id}',
      invoiceTotal: selectedInvoice.amountTotal,
      invoiceTaxBase: selectedInvoice.amountUntaxed,
      invoiceTaxAmount: selectedInvoice.amountTax,
      partnerId: partnerId,
      partnerName: partnerName,
      initialWithholdLines: initialWithholdLines,
    );

    if (result != null && result.success) {
      if (!context.mounted) return;
      CopyableInfoBar.showSuccess(
        context,
        title: 'Retención registrada',
        message: 'Total retenido: ${result.totalWithheld.toCurrency()}',
      );
    }
  }

  Future<void> _showCreditNoteDialog(
    BuildContext context,
    WidgetRef ref,
    FastSaleTabState? activeTab,
  ) async {
    // Verificar que hay una orden con cliente
    if (activeTab?.order == null || activeTab?.order?.partnerId == null) {
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Sin cliente'),
          content: const Text(
            'Seleccione un cliente antes de aplicar notas de crédito.',
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    // Obtener notas de crédito disponibles del cliente
    final paymentService = ref.read(paymentServiceProvider);
    final creditNotes = await paymentService.getAvailableCreditNotes(
      activeTab!.order!.partnerId!,
    );

    if (creditNotes.isEmpty) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Sin notas de crédito'),
          content: Text(
            'El cliente "${activeTab.order!.partnerName}" no tiene '
            'notas de crédito disponibles.',
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;

    // Mostrar selector de notas de crédito
    final selected = await showDialog<AvailableCreditNote>(
      context: context,
      builder: (context) => _CreditNoteSelectionDialog(
        creditNotes: creditNotes,
        orderTotal: activeTab.total,
      ),
    );

    if (selected != null && context.mounted) {
      // Obtener sesión actual (offline-first)
      final currentSession = await ensureSessionLoaded(ref);
      if (!context.mounted) return;

      // Determinar monto a aplicar (menor entre disponible y total)
      final amountToApply = selected.amountResidual < activeTab.total
          ? selected.amountResidual
          : activeTab.total;

      // Mostrar diálogo de confirmación
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Aplicar Nota de Crédito'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Nota de Crédito: ${selected.name}'),
              const SizedBox(height: Spacing.xs),
              Text(
                'Disponible: ${selected.amountResidual.toCurrency()}',
                style: TextStyle(color: AppColors.success),
              ),
              Text('Total de la orden: ${activeTab.total.toCurrency()}'),
              const SizedBox(height: Spacing.sm),
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primaryBackground.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Se aplicará: ${amountToApply.toCurrency()}',
                  style: FluentTheme.of(context).typography.bodyStrong,
                ),
              ),
            ],
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Aplicar'),
            ),
          ],
        ),
      );

      if (confirm == true && context.mounted) {
        // Crear línea de pago con la NC (use negative temp ID for local line)
        final paymentLine = PaymentLine(
          id: -DateTime.now().millisecondsSinceEpoch,
          type: PaymentLineType.creditNote,
          date: DateTime.now(),
          amount: amountToApply,
          creditNoteId: selected.id,
          creditNoteName: selected.name,
        );

        // Guardar la aplicación de NC
        final success = await paymentService.savePaymentLines(
          activeTab.order!.id,
          [paymentLine],
          collectionSessionId: currentSession?.id,
        );

        if (success && context.mounted) {
          CopyableInfoBar.showSuccess(
            context,
            title: 'Nota de crédito aplicada',
            message: 'NC ${selected.name} aplicada por ${amountToApply.toCurrency()}',
          );
        } else if (context.mounted) {
          CopyableInfoBar.showError(
            context,
            title: 'Error de nota de credito',
            message: 'No se pudo aplicar la nota de crédito',
          );
        }
      }
    }
  }



  Future<void> _showCashOutDialog(BuildContext context, WidgetRef ref) async {
    // Verificar que hay una sesión de cobranza abierta (offline-first)
    final currentSession = await ensureSessionLoaded(ref);
    if (currentSession == null) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Sin sesión'),
          content: const Text(
            'Debe tener una sesión de cobranza abierta para registrar salidas de dinero.',
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    // Mostrar diálogo de salida de dinero
    if (!context.mounted) return;
    final result = await showDialog<_CashOutResult>(
      context: context,
      builder: (context) => _CashOutDialog(sessionId: currentSession.id),
    );

    if (result != null && result.success && context.mounted) {
      CopyableInfoBar.showSuccess(
        context,
        title: 'Salida registrada',
        message: 'Salida de ${result.amount.toCurrency()} registrada correctamente',
      );
    }
  }

  Future<void> _showAdvanceDialog(
    BuildContext context,
    WidgetRef ref,
    FastSaleTabState? activeTab,
  ) async {
    // Verificar que hay una orden con cliente
    if (activeTab?.order == null || activeTab?.order?.partnerId == null) {
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Sin cliente'),
          content: const Text(
            'Seleccione un cliente antes de registrar anticipos.',
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    // Verificar sesión de cobranza (offline-first)
    final currentSession = await ensureSessionLoaded(ref);
    if (currentSession == null) {
      if (!context.mounted) return;
      showDialog(
        context: context,
        builder: (context) => ContentDialog(
          title: const Text('Sin sesión'),
          content: const Text(
            'Debe tener una sesión de cobranza abierta para registrar anticipos.',
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(context),
              child: const Text('Aceptar'),
            ),
          ],
        ),
      );
      return;
    }

    if (!context.mounted) return;

    // Mostrar diálogo de registro de anticipo
    final result = await AdvanceRegistrationDialog.show(
      context: context,
      partnerId: activeTab!.order!.partnerId!,
      partnerName: activeTab.order!.partnerName ?? 'Cliente',
      sessionId: currentSession.id,
    );

    if (result != null && result.success && context.mounted) {
      CopyableInfoBar.showSuccess(
        context,
        title: 'Anticipo registrado',
        message: 'Anticipo de ${result.amount.toCurrency()} registrado correctamente',
      );
    }
  }

  void _confirmCloseTab(
    BuildContext context,
    WidgetRef ref,
    FastSaleTabState activeTab,
  ) {
    // If order has unsaved changes, show confirmation
    if (activeTab.hasChanges) {
      showDialog(
        context: context,
        builder: (dialogContext) => ContentDialog(
          title: const Text('Cerrar Venta'),
          content: Text(
            'La venta "${activeTab.orderName}" tiene cambios sin guardar.\n\n'
            '¿Desea cerrarla de todas formas?',
          ),
          actions: [
            Button(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                final activeIndex = ref.read(
                  fastSaleProvider.select((s) => s.activeTabIndex),
                );
                ref.read(fastSaleProvider.notifier).closeTab(activeIndex);
              },
              child: const Text('Cerrar sin guardar'),
            ),
          ],
        ),
      );
    } else {
      // No changes, just close the tab
      final activeIndex = ref.read(
        fastSaleProvider.select((s) => s.activeTabIndex),
      );
      ref.read(fastSaleProvider.notifier).closeTab(activeIndex);
    }
  }

  /// Delega al handler centralizado que incluye validación de crédito,
  /// diálogo de bypass con canBypass, indicador de carga y mensaje de resultado.
  ///
  /// Antes este método omitía [canBypass], por lo que supervisores con el grupo
  /// 'l10n_ec_sale_credit.group_credit_bypass' no veían el botón "Continuar de
  /// todas formas". Ahora ambos puntos de entrada usan exactamente el mismo flujo.
  Future<void> _handleConfirmOrder(
    BuildContext context,
    WidgetRef ref,
    FastSaleTabState? activeTab,
  ) async {
    if (activeTab == null) return;
    await confirmOrderWithCreditCheck(context, ref);
  }

  /// Handle cancel order action
  Future<void> _handleCancelOrder(
    BuildContext context,
    WidgetRef ref,
    FastSaleTabState? activeTab,
  ) async {
    if (activeTab?.order == null) return;

    final order = activeTab!.order!;

    // Confirm cancellation
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Cancelar Orden'),
        content: Text(
          '¿Está seguro de cancelar la orden ${order.name}?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppColors.danger),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, cancelar'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    // Show loading
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
                SizedBox(height: Spacing.sm),
                Text('Cancelando orden...'),
              ],
            ),
          ),
        ),
      ),
    );

    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) throw Exception('Repositorio no disponible');

      await salesRepo.cancel(order.id);

      // Close dialog first
      if (!context.mounted) return;
      _safePop(context);

      // Then show success and reload
      if (!context.mounted) return;
      CopyableInfoBar.showSuccess(
        context,
        title: 'Orden cancelada',
        message: 'La orden ${order.name} ha sido cancelada',
      );

      // Reload order
      await ref.read(fastSaleProvider.notifier).reloadActiveOrder();
    } catch (e) {
      // Close dialog first
      if (!context.mounted) return;
      _safePop(context);

      if (!context.mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error al cancelar',
        message: 'No se pudo cancelar la orden. Intente nuevamente.',
      );
    }
  }

  /// Handle lock order action
  Future<void> _handleLockOrder(
    BuildContext context,
    WidgetRef ref,
    SaleOrder? order,
  ) async {
    if (order == null) return;

    // Confirm lock
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Bloquear Orden'),
        content: Text(
          '¿Está seguro de bloquear la orden ${order.name}?\n\n'
          'Una vez bloqueada, no se podrá cancelar ni volver a cotización.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, bloquear'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) throw Exception('Repositorio no disponible');

      await salesRepo.lockOrder(order.id);

      // Update locked status reactively (no full reload)
      ref.read(fastSaleProvider.notifier).updateActiveOrderLocked(true);

      // Sync with Form Sale provider (cross-provider sync)
      ref.read(saleOrderFormProvider.notifier).updateOrderLockedById(order.id, true);

      if (!context.mounted) return;
      CopyableInfoBar.showSuccess(
        context,
        title: 'Orden bloqueada',
        message: 'La orden ${order.name} ha sido bloqueada',
      );
    } catch (e) {
      if (!context.mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error al bloquear orden',
        message: 'No se pudo bloquear la orden. Intente nuevamente.',
      );
    }
  }

  /// Handle unlock order action
  Future<void> _handleUnlockOrder(
    BuildContext context,
    WidgetRef ref,
    SaleOrder? order,
  ) async {
    if (order == null) return;

    // Confirm unlock
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Desbloquear Orden'),
        content: Text(
          '¿Está seguro de desbloquear la orden ${order.name}?\n\n'
          'Esto permitirá cancelar o volver a cotización.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('No'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sí, desbloquear'),
          ),
        ],
      ),
    );

    if (confirm != true || !context.mounted) return;

    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) throw Exception('Repositorio no disponible');

      await salesRepo.unlockOrder(order.id);

      // Update locked status reactively (no full reload)
      ref.read(fastSaleProvider.notifier).updateActiveOrderLocked(false);

      // Sync with Form Sale provider (cross-provider sync)
      ref.read(saleOrderFormProvider.notifier).updateOrderLockedById(order.id, false);

      if (!context.mounted) return;
      CopyableInfoBar.showSuccess(
        context,
        title: 'Orden desbloqueada',
        message: 'La orden ${order.name} ha sido desbloqueada',
      );
    } catch (e) {
      if (!context.mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error al desbloquear orden',
        message: 'No se pudo desbloquear la orden. Intente nuevamente.',
      );
    }
  }

}
