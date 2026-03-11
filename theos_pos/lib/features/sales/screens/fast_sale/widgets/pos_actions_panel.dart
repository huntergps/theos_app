import 'package:fluent_ui/fluent_ui.dart' hide showDialog;
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/providers.dart';
import '../../../../../core/database/repositories/repository_providers.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../shared/providers/menu_provider.dart';
import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../../shared/providers/user_provider.dart';
import '../../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../../clients/clients.dart'
    show
        CreditCheckType,
        CreditControlDialog,
        CreditDialogAction,
        clientWithCreditProvider,
        clientCreditServiceProvider,
        clientRepositoryProvider;
import 'package:theos_pos_core/theos_pos_core.dart';
import '../../../../invoices/invoices.dart';
import '../../../services/credit_validation_ui_service.dart' show UnifiedCreditResult;
import '../../../providers/service_providers.dart';
import '../../../widgets/payment/withholding_dialog.dart';
import '../../../../advances/widgets/advance_registration_dialog.dart';
import '../../../providers/providers.dart' show saleOrderFormProvider;
import '../fast_sale_providers.dart';

/// Helper to ensure collection session is loaded (offline-first)
///
/// If session is not in provider, loads from local database first.
/// Returns the session or null if no active session.
Future<CollectionSession?> ensureSessionLoaded(WidgetRef ref) async {
  var currentSession = ref.read(currentSessionProvider);
  if (currentSession != null) return currentSession;

  logger.d('[POSActions] Session not in provider, loading from database...');
  final collectionRepo = ref.read(collectionRepositoryProvider);
  final userRepo = ref.read(userRepositoryProvider);

  if (collectionRepo == null || userRepo == null) {
    logger.d('[POSActions] Repositories not available');
    return null;
  }

  try {
    final user = await userRepo.getCurrentUser();
    if (user == null) {
      logger.d('[POSActions] No current user found');
      return null;
    }

    // Offline-first: load from local database
    // IMPORTANT: User.id is the Odoo user ID
    // CollectionSession.userId stores the Odoo user ID
    final session = await collectionRepo.getActiveUserSession(user.id);
    if (session != null) {
      ref.read(currentSessionProvider.notifier).set(session);
      logger.d('[POSActions] Loaded session: ${session.name} (id=${session.id})');
      return session;
    }

    logger.d('[POSActions] No active session for user ${user.name}');
    return null;
  } catch (e) {
    logger.e('[POSActions]', 'Error loading session: $e');
    return null;
  }
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

    final actions = <_ActionItem>[
      // Sincronizar orden - only visible when order is not synced
      if (needsSync)
        _ActionItem(
          icon: FluentIcons.sync,
          label: 'Sincronizar',
          color: Colors.orange,
          onTap: () => _handleSyncOrder(context, ref, activeTab),
        ),
      // Sincronizar datos (cliente, crédito, etc.) - always visible when has partner
      if (hasPartner)
        _ActionItem(
          icon: FluentIcons.sync,
          label: 'Actualizar Datos',
          color: Colors.blue,
          onTap: () => _handleSyncData(context, ref, activeTab),
        ),
      // Confirmar Venta button - only visible for draft, sent, approved states
      if (canConfirm)
        _ActionItem(
          icon: FluentIcons.check_mark,
          label: 'Confirmar',
          color: Colors.green.dark,
          onTap: () => _handleConfirmOrder(context, ref, activeTab),
          isPrimary: true,
        ),
      // Cancelar - visible based on order state and lock
      if (canCancel)
        _ActionItem(
          icon: FluentIcons.cancel,
          label: 'Cancelar',
          color: Colors.red,
          onTap: () => _handleCancelOrder(context, ref, activeTab),
        ),
      // Bloquear - only for sale state, not locked
      if (canLock)
        _ActionItem(
          icon: FluentIcons.lock,
          label: 'Bloquear',
          color: Colors.grey,
          onTap: () => _handleLockOrder(context, ref, order),
        ),
      // Desbloquear - only for sale state, locked
      if (canUnlock)
        _ActionItem(
          icon: FluentIcons.unlock,
          label: 'Desbloquear',
          color: Colors.teal,
          onTap: () => _handleUnlockOrder(context, ref, order),
        ),
      // Facturar button removed - now handled in credit tab for credit sales
      _ActionItem(
        icon: FluentIcons.bank,
        label: 'Retencion',
        color: Colors.blue.light,
        onTap: () => _showRetentionDialog(context, ref, activeTab),
      ),
      _ActionItem(
        icon: FluentIcons.page_list,
        label: 'Nota Credito',
        color: Colors.purple,
        onTap: () => _showCreditNoteDialog(context, ref, activeTab),
      ),
      _ActionItem(
        icon: FluentIcons.money,
        label: 'Salida Dinero',
        color: Colors.orange,
        onTap: () => _showCashOutDialog(context, ref),
      ),
      _ActionItem(
        icon: FluentIcons.payment_card,
        label: 'Ver Pagos',
        color: Colors.green,
        onTap: () => _goToPaymentsTab(context, ref),
      ),
      _ActionItem(
        icon: FluentIcons.circle_dollar,
        label: 'Anticipo',
        color: Colors.magenta,
        onTap: () => _showAdvanceDialog(context, ref, activeTab),
      ),
    ];

    if (isHorizontal) {
      return _buildHorizontalLayout(context, ref, theme, actions, activeTab);
    }

    return _buildVerticalLayout(context, ref, theme, actions, activeTab);
  }

  Widget _buildVerticalLayout(
    BuildContext context,
    WidgetRef ref,
    FluentThemeData theme,
    List<_ActionItem> actions,
    FastSaleTabState? activeTab,
  ) {
    return Container(
      color: theme.menuColor,
      padding: const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
      child: Column(
        children: [
          // Close current tab widget
          if (activeTab != null)
            _CloseCurrentTabWidget(
              orderName: activeTab.orderName,
              onClose: () => _confirmCloseTab(context, ref, activeTab),
            ),
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
    );
  }

  Widget _buildHorizontalLayout(
    BuildContext context,
    WidgetRef ref,
    FluentThemeData theme,
    List<_ActionItem> actions,
    FastSaleTabState? activeTab,
  ) {
    return Container(
      color: theme.menuColor,
      padding: const EdgeInsets.symmetric(vertical: Spacing.xs, horizontal: Spacing.sm),
      child: Row(
        children: [
          // Close current tab widget (compact)
          if (activeTab != null)
            Padding(
              padding: const EdgeInsets.only(right: Spacing.xs),
              child: _CloseCurrentTabWidget(
                orderName: activeTab.orderName,
                onClose: () => _confirmCloseTab(context, ref, activeTab),
                isCompact: true,
              ),
            ),

          // Actions
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final action in actions)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: Spacing.xxs),
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
        ],
      ),
    );
  }



  /// Handle sync order action
  Future<void> _handleSyncOrder(
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
          title: 'Error',
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

    // Show loading dialog
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
                SizedBox(height: Spacing.sm),
                Text('Sincronizando orden...'),
              ],
            ),
          ),
        ),
      ),
    );

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
      }

      // Reload the active tab order
      await ref.read(fastSaleProvider.notifier).reloadActiveOrder();

      // Close dialog
      if (context.mounted) Navigator.of(context).pop();

      if (!context.mounted) return;
      CopyableInfoBar.showSuccess(
        context,
        title: 'Sincronizado',
        message: result.synced > 0
            ? 'Se sincronizaron ${result.synced} operaciones'
            : 'Orden sincronizada correctamente',
      );
    } catch (e) {
      // Close dialog
      if (context.mounted) Navigator.of(context).pop();

      logger.e('[POSActions]', 'Sync error: $e');

      if (!context.mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error de sincronización',
        message: e.toString(),
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
              Icon(FluentIcons.warning, size: 48, color: Colors.orange),
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
                style: TextStyle(color: Colors.green.dark),
              ),
              Text('Total de la orden: ${activeTab.total.toCurrency()}'),
              const SizedBox(height: Spacing.sm),
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.1),
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
            title: 'Error',
            message: 'No se pudo aplicar la nota de crédito',
          );
        }
      }
    }
  }



  /// Navigate to payments tab
  void _goToPaymentsTab(BuildContext context, WidgetRef ref) {
    ref.read(orderPanelTabProvider.notifier).goToPayments();
  }

  /// Sync ALL data related to the current order (client, credit, order, lines)
  Future<void> _handleSyncData(
    BuildContext context,
    WidgetRef ref,
    FastSaleTabState? activeTab,
  ) async {
    if (activeTab?.order == null) return;

    final order = activeTab!.order!;
    final partnerId = order.partnerId;
    final orderId = order.id;

    if (partnerId == null) return;

    logger.i('[POSActions]', '🔄 Starting data sync for partner $partnerId, order $orderId');

    // Show loading dialog and track if it's open
    if (!context.mounted) return;

    bool dialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => const ContentDialog(
        content: SizedBox(
          height: 80,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ProgressRing(),
                SizedBox(height: Spacing.sm),
                Text('Sincronizando datos...'),
              ],
            ),
          ),
        ),
      ),
    );

    void closeDialog() {
      if (dialogOpen && context.mounted) {
        dialogOpen = false;
        Navigator.of(context, rootNavigator: true).pop();
      }
    }

    final syncedItems = <String>[];
    final errors = <String>[];

    try {
      // 1. Sync partner/client data
      try {
        final clientRepo = ref.read(clientRepositoryProvider);
        if (clientRepo != null) {
          await clientRepo.refreshCreditData(partnerId);
          syncedItems.add('Cliente');
        } else {
          logger.w('[POSActions]', 'clientRepository is null');
        }
      } catch (e) {
        logger.e('[POSActions]', 'Error syncing client: $e');
        errors.add('Cliente: $e');
      }

      // 2. Sync sale order, lines, payments, withholds, invoices
      if (orderId > 0) {
        try {
          final salesRepo = ref.read(salesRepositoryProvider);
          if (salesRepo != null) {
            await salesRepo.getWithLines(orderId, forceRefresh: true);
            syncedItems.addAll(['Orden', 'Líneas', 'Pagos']);
          }
        } catch (e) {
          logger.e('[POSActions]', 'Error syncing order: $e');
          errors.add('Orden: $e');
        }
      }

      // 3. Refresh credit info
      try {
        final creditService = ref.read(clientCreditServiceProvider);
        if (creditService != null) {
          await creditService.getClientWithCredit(partnerId, forceRefresh: true);
          syncedItems.add('Crédito');
        }
        // Invalidate the provider to reload UI
        ref.invalidate(clientWithCreditProvider(partnerId));
      } catch (e) {
        logger.e('[POSActions]', 'Error syncing credit: $e');
        errors.add('Crédito: $e');
      }

      // Reload the active tab order
      await ref.read(fastSaleProvider.notifier).reloadActiveOrder();

      // Close dialog
      closeDialog();

      logger.i('[POSActions]', 'Sync completed. Items: ${syncedItems.join(", ")}. Errors: ${errors.length}');

      // Show result
      if (!context.mounted) return;
      if (errors.isEmpty) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Sincronizado',
          message: 'Actualizado: ${syncedItems.join(", ")}',
        );
      } else {
        CopyableInfoBar.showWarning(
          context,
          title: 'Sincronización parcial',
          message: 'OK: ${syncedItems.join(", ")}\n\nErrores:\n${errors.join("\n")}',
        );
      }
    } catch (e) {
      // Close dialog
      closeDialog();

      logger.e('[POSActions]', 'Sync data error: $e');

      if (!context.mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error de sincronización',
        message: e.toString(),
      );
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

  /// Handle confirm order action with credit validation
  Future<void> _handleConfirmOrder(
    BuildContext context,
    WidgetRef ref,
    FastSaleTabState? activeTab,
  ) async {
    if (activeTab == null) return;

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
        await _createApprovalRequest(
          context,
          ref,
          activeTab,
          creditResult,
        );
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
      ref,
      skipCreditCheck: creditResult.requiresDialog,
    );
  }

  /// Execute the actual order confirmation
  ///
  /// Note: No loading dialog is shown to avoid navigator lock issues
  /// when state updates trigger widget rebuilds. The UI shows loading
  /// state via the tab's isLoading flag instead.
  Future<void> _executeConfirmOrder(
    BuildContext context,
    WidgetRef ref, {
    bool skipCreditCheck = false,
  }) async {
    final notifier = ref.read(fastSaleProvider.notifier);

    try {
      final success =
          await notifier.confirmActiveOrder(skipCreditCheck: skipCreditCheck);

      if (!context.mounted) return;

      if (success) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Orden confirmada',
          message: 'La orden está lista para facturar',
        );
      } else {
        // Get error message from state for better user feedback
        final error = ref.read(fastSaleProvider).error;
        CopyableInfoBar.showError(
          context,
          title: 'Error',
          message: error ?? 'No se pudo confirmar la orden',
        );
      }
    } catch (e) {
      if (!context.mounted) return;

      CopyableInfoBar.showError(
        context,
        title: 'Error',
        message: 'Error al confirmar: $e',
      );
    }
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
              backgroundColor: WidgetStateProperty.all(Colors.red),
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
      if (context.mounted) Navigator.of(context).pop();

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
      if (context.mounted) Navigator.of(context).pop();

      if (!context.mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error',
        message: 'Error al cancelar: $e',
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
        title: 'Error',
        message: 'Error al bloquear: $e',
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
        title: 'Error',
        message: 'Error al desbloquear: $e',
      );
    }
  }

  /// Create approval request for credit exception
  Future<void> _createApprovalRequest(
    BuildContext context,
    WidgetRef ref,
    FastSaleTabState activeTab,
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
                SizedBox(height: Spacing.sm),
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
        checkType: checkType.name, // Convert enum to string
        reason: checkType == CreditCheckType.creditLimitExceeded
            ? 'Límite de crédito excedido'
            : 'Deuda vencida',
      );

      // Close dialog first
      if (context.mounted) Navigator.of(context).pop();

      if (!context.mounted) return;

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
      // Close dialog first
      if (context.mounted) Navigator.of(context).pop();

      if (!context.mounted) return;

      logger.e('[POS]', 'Error creating approval request: $e');
      CopyableInfoBar.showError(
        context,
        title: 'Error',
        message: 'Error al crear solicitud: $e',
      );
    }
  }
}

/// Action item data
class _ActionItem {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback? onTap;
  final bool isPrimary;

  const _ActionItem({
    required this.icon,
    required this.label,
    required this.color,
    this.onTap,
    this.isPrimary = false,
  });

  bool get isEnabled => onTap != null;
}

/// Individual action button
class _ActionButton extends StatelessWidget {
  final _ActionItem action;
  final bool isCompact;
  final bool isHorizontal;

  const _ActionButton({
    required this.action,
    this.isCompact = false,
    this.isHorizontal = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final isEnabled = action.isEnabled;
    final effectiveColor = isEnabled ? action.color : Colors.grey[100];

    if (isCompact) {
      return IconButton(
        icon: Icon(
          action.icon,
          size: 20,
          color: effectiveColor,
        ),
        onPressed: action.onTap,
      );
    }

    if (isHorizontal) {
      return Button(
        onPressed: action.onTap,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(action.icon, size: 20, color: effectiveColor),
            const SizedBox(height: Spacing.xxs),
            Text(
              action.label,
              style: theme.typography.caption?.copyWith(
                fontSize: 10,
                color: isEnabled ? null : Colors.grey[100],
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    // Vertical layout - full button with colored icon background
    // Use FilledButton for primary actions
    final buttonWidget = action.isPrimary && isEnabled
        ? FilledButton(
            onPressed: action.onTap,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
              ),
              backgroundColor: WidgetStateProperty.all(
                action.color.withValues(alpha: 0.9),
              ),
            ),
            child: _buildButtonContent(theme, Colors.white, isEnabled),
          )
        : Button(
            onPressed: action.onTap,
            style: ButtonStyle(
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(vertical: Spacing.sm, horizontal: Spacing.xs),
              ),
            ),
            child: _buildButtonContent(theme, effectiveColor, isEnabled),
          );

    return SizedBox(
      width: double.infinity,
      child: buttonWidget,
    );
  }

  Widget _buildButtonContent(
    FluentThemeData theme,
    Color iconColor,
    bool isEnabled,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            color: action.isPrimary && isEnabled
                ? Colors.white.withValues(alpha: 0.2)
                : action.color.withValues(alpha: isEnabled ? 0.1 : 0.05),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(
            action.icon,
            size: 24,
            color: iconColor,
          ),
        ),
        const SizedBox(height: Spacing.xs),
        Text(
          action.label,
          style: theme.typography.caption?.copyWith(
            fontWeight: FontWeight.w500,
            color: action.isPrimary && isEnabled ? Colors.white : null,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
        ),
      ],
    );
  }
}


/// Widget to display current order name with close button [Nuevo-2][X]
class _CloseCurrentTabWidget extends StatelessWidget {
  final String orderName;
  final VoidCallback onClose;
  final bool isCompact;

  const _CloseCurrentTabWidget({
    required this.orderName,
    required this.onClose,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.accentColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: theme.accentColor.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Order name section
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isCompact ? 8 : 12,
              vertical: isCompact ? 4 : 8,
            ),
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(
                  color: theme.accentColor.withValues(alpha: 0.3),
                ),
              ),
            ),
            child: Text(
              orderName,
              style: theme.typography.body?.copyWith(
                fontWeight: FontWeight.w600,
                color: theme.accentColor,
                fontSize: isCompact ? 12 : 14,
              ),
            ),
          ),

          // Close button section [X]
          GestureDetector(
            onTap: onClose,
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: isCompact ? 6 : 10,
                vertical: isCompact ? 4 : 8,
              ),
              child: Icon(
                FluentIcons.chrome_close,
                size: isCompact ? 10 : 12,
                color: theme.accentColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// Widgets de soporte para diálogos de acciones
// ============================================================================

/// Diálogo para seleccionar nota de crédito
class _CreditNoteSelectionDialog extends StatelessWidget {
  final List<AvailableCreditNote> creditNotes;
  final double orderTotal;

  const _CreditNoteSelectionDialog({
    required this.creditNotes,
    required this.orderTotal,
  });

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Seleccionar Nota de Crédito'),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notas de crédito disponibles del cliente:',
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
          const SizedBox(height: Spacing.sm),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: creditNotes.length,
              itemBuilder: (context, index) {
                final nc = creditNotes[index];
                return ListTile.selectable(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.purple.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      FluentIcons.page_list,
                      size: 20,
                      color: Colors.purple,
                    ),
                  ),
                  title: Text(nc.name),
                  subtitle: Text(
                    'Disponible: ${nc.amountResidual.toCurrency()}',
                    style: TextStyle(color: Colors.green.dark),
                  ),
                  onPressed: () => Navigator.pop(context, nc),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// Resultado del diálogo de salida de dinero
class _CashOutResult {
  final bool success;
  final double amount;
  final String? reason;

  _CashOutResult({
    required this.success,
    required this.amount,
    this.reason,
  });
}

/// Diálogo para registrar salida de dinero
class _CashOutDialog extends ConsumerStatefulWidget {
  final int sessionId;

  const _CashOutDialog({required this.sessionId});

  @override
  ConsumerState<_CashOutDialog> createState() => _CashOutDialogState();
}

class _CashOutDialogState extends ConsumerState<_CashOutDialog> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveCashOut() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      CopyableInfoBar.showError(
        context,
        title: 'Error',
        message: 'Ingrese un monto válido',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cashOutService = ref.read(cashOutServiceProvider);

      // Obtener diarios de efectivo disponibles
      final cashJournals = await cashOutService.getCashJournals();
      if (cashJournals.isEmpty) {
        throw Exception('No hay diarios de efectivo configurados');
      }

      // Usar el primer diario de efectivo
      final cashJournal = cashJournals.firstWhere(
        (j) => j.type == 'cash',
        orElse: () => cashJournals.first,
      );

      // Crear retiro de seguridad (tipo más común)
      final result = await cashOutService.createSecurityWithdrawal(
        amount: amount,
        journalId: cashJournal.id,
        sessionId: widget.sessionId,
        note: _reasonController.text.isEmpty ? null : _reasonController.text,
      );

      if (mounted) {
        Navigator.pop(
          context,
          _CashOutResult(
            success: result.success,
            amount: amount,
            reason: _reasonController.text,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CopyableInfoBar.showError(
          context,
          title: 'Error',
          message: 'Error al registrar salida: $e',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Salida de Dinero'),
      constraints: const BoxConstraints(maxWidth: 400),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: 'Monto',
            child: TextBox(
              controller: _amountController,
              placeholder: '0.00',
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('\$'),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          InfoLabel(
            label: 'Motivo (opcional)',
            child: TextBox(
              controller: _reasonController,
              placeholder: 'Ej: Pago a proveedor, gastos varios...',
              maxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveCashOut,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Registrar Salida'),
        ),
      ],
    );
  }
}
