import 'package:dio/dio.dart';
import 'package:fluent_ui/fluent_ui.dart' hide showDialog;
import 'package:flutter/material.dart' show showDialog;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:odoo_sdk/odoo_sdk.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_constants.dart';

import '../../../../features/sync/repositories/catalog_sync_repository.dart';
import '../../../reports/providers/qweb_template_repository_provider.dart';
import '../../../../core/database/repositories/repository_providers.dart';
import '../../../reports/services/report_service.dart';
import 'package:flutter_qweb/flutter_qweb.dart'
    show RenderOptions, ReportException;
import '../../../../core/theme/spacing.dart';
import '../../../../shared/providers/company_config_provider.dart';
import '../../../../shared/providers/report_provider.dart';
import '../../../../shared/providers/user_provider.dart';
import '../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../../../../shared/widgets/status_indicator.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import '../../providers/providers.dart';
import '../../services/credit_validation_ui_service.dart'
    show UnifiedCreditResult;
import '../../../clients/clients.dart'
    show CreditCheckType, CreditControlDialog, CreditDialogAction;
import '../../widgets/sale_order_status_bar.dart';
import '../fast_sale/fast_sale_providers.dart';
import 'form_fields.dart';

/// Header unificado para SaleOrderFormScreen
///
/// Maneja tres modos:
/// - Vista (isEditing: false): Botones de acción (Confirmar, Cancelar, Editar, etc.)
/// - Edición (isEditing: true): Botones de Guardar, Descartar, Eliminar
/// - Nueva orden (isNew: true): Botones de Guardar, Descartar
class SaleOrderFormHeader extends ConsumerWidget {
  final int orderId;
  final bool isNew;
  final bool isEditing;
  final SaleOrder? order;
  final VoidCallback? onRefresh;

  /// Indica si el teclado está visible (para comprimir cards y ganar espacio)
  final bool isKeyboardVisible;

  const SaleOrderFormHeader({
    super.key,
    required this.orderId,
    required this.isNew,
    required this.isEditing,
    this.order,
    this.onRefresh,
    this.isKeyboardVisible = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Layout unificado para evitar flicker al cambiar modos
    return _buildUnifiedHeader(context, ref);
  }

  // ============================================================
  // HEADER UNIFICADO - Mismo layout para vista y edición
  // ============================================================
  Widget _buildUnifiedHeader(BuildContext context, WidgetRef ref) {
    // ✅ SELECTORES GRANULARES - Solo se reconstruye cuando cambian estos campos específicos
    // Esto evita que cambios en campos individuales (como fechas) regeneren toda la UI
    final isSaving = ref.watch(saleOrderFormProvider.select((s) => s.isSaving));
    final isFinalConsumer = ref.watch(
      saleOrderFormProvider.select((s) => s.isFinalConsumer),
    );
    final exceedsFinalConsumerLimit = ref.watch(
      saleOrderFormProvider.select((s) => s.exceedsFinalConsumerLimit),
    );
    final theme = FluentTheme.of(context);
    final spacing = ref.watch(themedSpacingProvider);
    final currentOrder = order;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact =
            constraints.maxWidth < ScreenBreakpoints.mobileMaxWidth;

        return Padding(
          padding: EdgeInsets.symmetric(horizontal: spacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fila 1: Volver + Título + Badges + Botones
              Row(
                children: [
                  IconButton(
                    icon: const Icon(FluentIcons.back),
                    onPressed: isEditing
                        ? () => _handleBack(context, ref)
                        : () => ref
                              .read(saleOrderTabsProvider.notifier)
                              .goToList(),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      isNew
                          ? 'Nueva Orden de Venta'
                          : currentOrder?.name ?? 'Orden',
                      style: theme.typography.subtitle?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  // Badges - usando StatusIndicator unificado
                  if (currentOrder != null && !currentOrder.isSynced) ...[
                    spacing.horizontal.sm,
                    _PendingSyncBadge(
                      isCompact: isCompact,
                      orderId: currentOrder.id,
                    ),
                  ],
                  if (currentOrder?.locked == true) ...[
                    spacing.horizontal.sm,
                    StatusIndicator.locked(isCompact: isCompact),
                  ],
                  // Botones de acción (en desktop)
                  if (!isCompact) ...[
                    const SizedBox(width: 16),
                    if (isEditing)
                      _EditActionButtons(
                        isNew: isNew,
                        isSaving: isSaving,
                        order: currentOrder,
                        onBack: () => _handleBack(context, ref),
                        onDiscard: () => _handleDiscard(context, ref),
                        onSave: () => _handleSave(context, ref),
                        onDelete: () => _handleDelete(context, ref),
                      )
                    else if (currentOrder != null)
                      _ViewActionButtons(
                        order: currentOrder,
                        onRefresh: onRefresh ?? () {},
                      ),
                  ],
                ],
              ),

              // Botones en móvil (fila separada)
              if (isCompact) ...[
                spacing.vertical.sm,
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: isEditing
                      ? _EditActionButtons(
                          isNew: isNew,
                          isSaving: isSaving,
                          order: currentOrder,
                          onBack: () => _handleBack(context, ref),
                          onDiscard: () => _handleDiscard(context, ref),
                          onSave: () => _handleSave(context, ref),
                          onDelete: () => _handleDelete(context, ref),
                        )
                      : currentOrder != null
                      ? _ViewActionButtons(
                          order: currentOrder,
                          onRefresh: onRefresh ?? () {},
                        )
                      : const SizedBox.shrink(),
                ),
              ],

              // Alertas de consumidor final (l10n_ec_base) - usando StatusIndicator
              // Alerta informativa azul: visible cuando el cliente es consumidor final
              if ((isEditing && isFinalConsumer) ||
                  (!isEditing &&
                      currentOrder != null &&
                      currentOrder.isFinalConsumer)) ...[
                spacing.vertical.sm,
                _FinalConsumerInfoAlert(ref: ref),
              ],
              // Alerta de advertencia amarilla: visible cuando excede el límite
              if ((isEditing && exceedsFinalConsumerLimit) ||
                  (!isEditing &&
                      currentOrder != null &&
                      currentOrder.exceedsFinalConsumerLimit)) ...[
                spacing.vertical.sm,
                StatusIndicator.warningAlert(
                  title: '¡Atención - Excede el límite del SRI!',
                  message:
                      'El monto total de esta orden excede el límite permitido para un consumidor final.',
                  details: const [
                    'Cambiar el cliente por uno con identificación específica',
                    'Reducir el monto de la orden',
                    'Dividir en múltiples órdenes más pequeñas',
                  ],
                ),
              ],
              spacing.vertical.sm,

              // Status bar (siempre visible en ambos modos)
              if (isCompact)
                SaleOrderStatusBar(
                  state: currentOrder?.state ?? SaleOrderState.draft,
                )
              else
                Align(
                  alignment: Alignment.centerRight,
                  child: FractionallySizedBox(
                    widthFactor: 0.5,
                    child: SaleOrderStatusBar(
                      state: currentOrder?.state ?? SaleOrderState.draft,
                    ),
                  ),
                ),
              spacing.vertical.sm,

              // Section 2: Client info + Dates (siempre visible)
              // Pasa isCompact cuando el teclado está visible
              SaleOrderFormFields(
                isEditing: isEditing,
                order: currentOrder,
                isCompact: isKeyboardVisible,
              ),
            ],
          ),
        );
      },
    );
  }

  // ============================================================
  // HANDLERS
  // ============================================================
  void _handleBack(BuildContext context, WidgetRef ref) {
    logger.d('[SaleOrderFormHeader]', 'Navigating back from form');
    ref.read(saleOrderFormProvider.notifier).clearConflict();

    if (isNew) {
      ref.read(saleOrderTabsProvider.notifier).closeCurrentTab();
    } else {
      // Exit edit mode - data stays in unified provider
      ref.read(saleOrderFormProvider.notifier).exitEditMode();
      ref.read(saleOrderTabsProvider.notifier).switchCurrentToView();
    }
  }

  void _handleDiscard(BuildContext context, WidgetRef ref) {
    logger.d('[SaleOrderFormHeader]', 'Discarding changes');
    ref.read(saleOrderFormProvider.notifier).clearConflict();

    if (isNew) {
      ref.read(saleOrderTabsProvider.notifier).closeCurrentTab();
    } else {
      // Discard changes and exit edit mode
      ref.read(saleOrderFormProvider.notifier).discardChanges();
      ref.read(saleOrderTabsProvider.notifier).switchCurrentToView();
    }
  }

  Future<void> _handleSave(BuildContext context, WidgetRef ref) async {
    logger.i('[SaleOrderFormHeader]', 'Saving order');

    final formNotifier = ref.read(saleOrderFormProvider.notifier);
    final tabsNotifier = ref.read(saleOrderTabsProvider.notifier);
    final user = ref.read(userProvider);

    // 1. Validar crédito antes de guardar
    final creditResult = await formNotifier.validateCreditForUI();

    if (creditResult.requiresDialog) {
      if (!context.mounted) return;
      // Mostrar dialog de control de crédito
      final action = await CreditControlDialog.show(
        context: context,
        client: creditResult.client!,
        validationResult: creditResult.validationResult!,
        orderAmount: creditResult.orderAmount,
        isOnline: creditResult.isOnline,
        // Permitir bypass si el usuario tiene permiso o el client lo permite
        canBypass:
            user?.permissions.contains(
              'l10n_ec_sale_credit.group_credit_bypass',
            ) ??
            false,
      );

      switch (action) {
        case CreditDialogAction.cancel:
          // Usuario canceló, no hacer nada
          logger.i('[SaleOrderFormHeader]', 'Credit dialog cancelled by user');
          return;

        case CreditDialogAction.createApproval:
          // Crear solicitud de aprobación en Odoo
          logger.i('[SaleOrderFormHeader]', 'Creating credit approval request');
          if (!context.mounted) return;
          await _createCreditApprovalRequest(context, ref, creditResult);
          return;

        case CreditDialogAction.proceedAnyway:
          // Usuario eligió continuar (bypass)
          logger.i(
            '[SaleOrderFormHeader]',
            'User chose to bypass credit check',
          );
          formNotifier.bypassCreditCheck();
          break;

        case null:
          // Dialog cerrado sin seleccionar
          return;
      }
    }

    // 2. Guardar la orden (skipCreditCheck=true porque ya validamos arriba)
    final savedOrderId = await formNotifier.saveOrder(
      skipCreditCheck: creditResult.requiresDialog,
    );

    if (savedOrderId != null) {
      logger.d('[SaleOrderFormHeader]', 'Order saved with ID: $savedOrderId');
      formNotifier.clearConflict();
      // NOTE: Do NOT call exitEditMode() here - saveOrder() already reloads the order
      // and resets isEditing to false via loadOrder(). Calling exitEditMode() would
      // overwrite the freshly loaded data with stale values from the old state.order.

      if (isNew) {
        tabsNotifier.closeCurrentTab();
      } else {
        tabsNotifier.switchCurrentToView();
      }
    }
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    logger.i('[SaleOrderFormHeader]', 'Delete button pressed');

    final formNotifier = ref.read(saleOrderFormProvider.notifier);
    final tabsNotifier = ref.read(saleOrderTabsProvider.notifier);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => ContentDialog(
        title: const Text('Eliminar Orden'),
        content: const Text(
          'Esta acción eliminará la orden de venta y todas sus líneas de la base de datos local.\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          Button(
            child: const Text('Cancelar'),
            onPressed: () => Navigator.of(dialogContext).pop(false),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(Colors.red),
            ),
            child: const Text('Eliminar'),
            onPressed: () => Navigator.of(dialogContext).pop(true),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    final success = await formNotifier.deleteOrder();

    if (success) {
      logger.i('[SaleOrderFormHeader]', 'Order deleted successfully');
      formNotifier.clearConflict();
      tabsNotifier.closeCurrentTab();
    }
  }

  /// Crear solicitud de aprobación de crédito en Odoo
  Future<void> _createCreditApprovalRequest(
    BuildContext context,
    WidgetRef ref,
    UnifiedCreditResult creditResult,
  ) async {
    final formState = ref.read(saleOrderFormProvider);
    final salesRepo = ref.read(salesRepositoryProvider);

    if (salesRepo == null) {
      if (context.mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error',
          message: 'Repositorio de ventas no disponible',
        );
      }
      return;
    }

    // Verificar que la orden esté guardada (tiene ID válido)
    final orderId = formState.order?.id;
    if (orderId == null || orderId < 0) {
      if (context.mounted) {
        CopyableInfoBar.showWarning(
          context,
          title: 'Orden no guardada',
          message:
              'Debe guardar la orden primero antes de crear una solicitud de aprobación.',
        );
      }
      return;
    }

    // Construir el motivo/razón de la solicitud
    final client = creditResult.client!;
    final validation = creditResult.validationResult!;
    final checkType = validation.type.name;

    String reason;
    if (validation.type == CreditCheckType.overdueDebt) {
      reason =
          '''
<p><strong>Solicitud de Aprobación - Cliente con Deudas Atrasadas</strong></p>
<p><strong>Cliente:</strong> ${client.name}</p>
<p><strong>Monto Transacción:</strong> ${creditResult.orderAmount.toCurrency()}</p>
<p><strong>Total Vencido:</strong> ${client.totalOverdue?.toCurrency() ?? '\$0.00'}</p>
<p><strong>Facturas Vencidas:</strong> ${client.overdueInvoicesCount ?? 0}</p>
<p><strong>Días de Deuda Más Antigua:</strong> ${client.oldestOverdueDays ?? 0} días</p>
<p><strong>Motivo:</strong> Cliente con deudas atrasadas que requiere autorización.</p>
''';
    } else {
      final creditAvailable = client.creditAvailable ?? 0;
      final creditExceeded = creditResult.orderAmount - creditAvailable;
      reason =
          '''
<p><strong>Solicitud de Aprobación - Límite de Crédito Excedido</strong></p>
<p><strong>Cliente:</strong> ${client.name}</p>
<p><strong>Límite Actual:</strong> ${client.creditLimit?.toCurrency() ?? '\$0.00'}</p>
<p><strong>Crédito Usado:</strong> ${client.credit?.toCurrency() ?? '\$0.00'}</p>
<p><strong>Monto Transacción:</strong> ${creditResult.orderAmount.toCurrency()}</p>
<p><strong>Exceso:</strong> ${creditExceeded > 0 ? creditExceeded.toCurrency() : '\$0.00'}</p>
<p><strong>Motivo:</strong> Venta que excede el límite de crédito disponible del cliente.</p>
''';
    }

    try {
      // Mostrar indicador de carga
      if (context.mounted) {
        CopyableInfoBar.showInfo(
          context,
          title: 'Creando solicitud...',
          message: 'Enviando solicitud de aprobación a Odoo',
        );
      }

      final approvalId = await salesRepo.createCreditApprovalRequest(
        orderId: orderId,
        partnerId: client.id,
        amount: creditResult.orderAmount,
        reason: reason,
        checkType: checkType == 'overdueDebt'
            ? 'overdue_debt'
            : 'credit_limit_exceeded',
        paymentTermId: formState.paymentTermId,
      );

      if (approvalId != null && context.mounted) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Solicitud Creada',
          message:
              'Se ha creado la solicitud de aprobación #$approvalId. '
              'La orden está ahora en espera de aprobación.',
        );

        // Recargar la orden para mostrar el nuevo estado
        final formNotifier = ref.read(saleOrderFormProvider.notifier);
        await formNotifier.loadOrder(orderId);
      }
    } catch (e) {
      if (context.mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error de solicitud',
          message: e.toString(),
        );
      }
    }
  }
}

// ============================================================
// BOTONES DE ACCION MODO VISTA
// ============================================================
class _ViewActionButtons extends ConsumerWidget {
  final SaleOrder order;
  final VoidCallback onRefresh;

  const _ViewActionButtons({required this.order, required this.onRefresh});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(themedSpacingProvider);
    final user = ref.watch(userProvider);
    final canConfirm =
        user?.permissions.contains('l10n_ec_base.group_sale_confirm') ?? false;

    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      alignment: WrapAlignment.end,
      children: [
        // Imprimir
        Button(
          onPressed: () => _handlePrint(context, ref),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FluentIcons.print, size: 14),
              SizedBox(width: spacing.xs),
              const Text('Imprimir'),
            ],
          ),
        ),

        // Vista previa
        Button(
          onPressed: () => _handlePreview(context, ref),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FluentIcons.preview, size: 14),
              SizedBox(width: spacing.xs),
              const Text('Vista previa'),
            ],
          ),
        ),

        // Cancelar
        if (order.canCancel &&
            (user?.permissions.contains(
                  'l10n_ec_base.group_allow_delete_records',
                ) ??
                false))
          Button(
            onPressed: () => _handleCancel(context, ref),
            child: const Text('Cancelar'),
          ),

        // Volver a cotización
        if (order.canSetToQuotation)
          Button(
            onPressed: () => _handleSetToQuotation(context, ref),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.undo, size: 14),
                SizedBox(width: spacing.xs),
                const Text('A Cotización'),
              ],
            ),
          ),

        // Confirmar Venta
        if (order.canConfirm && canConfirm)
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(AppColors.success),
            ),
            onPressed: () => _handleConfirm(context, ref),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.check_mark, size: 14),
                SizedBox(width: spacing.xs),
                const Text('Confirmar Venta'),
              ],
            ),
          ),

        // Reservar Stock
        if (order.canReserveStock)
          FilledButton(
            onPressed: () => _handleReserveStock(context, ref),
            child: const Text('Reservar Stock'),
          ),

        // Bloquear - Solo en estado sale y no bloqueada
        if (order.canLock)
          Button(
            onPressed: () => _handleLock(context, ref),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.lock, size: 14),
                SizedBox(width: spacing.xs),
                const Text('Bloquear'),
              ],
            ),
          ),

        // Desbloquear - Solo en estado sale y bloqueada
        if (order.canUnlock)
          Button(
            onPressed: () => _handleUnlock(context, ref),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.unlock, size: 14),
                SizedBox(width: spacing.xs),
                const Text('Desbloquear'),
              ],
            ),
          ),

        // Editar - Solo visible en estados editables (draft, sent)
        // Estados como waiting, approved, sale, done, cancel NO permiten edición
        if (order.isEditable)
          FilledButton(
            onPressed: () {
              logger.i('[_ViewActionButtons]', 'Switching to edit mode');
              // Use unified provider for mode switch
              ref.read(saleOrderFormProvider.notifier).enterEditMode();
              ref.read(saleOrderTabsProvider.notifier).switchCurrentToEdit();
            },
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(FluentIcons.edit, size: 14),
                SizedBox(width: spacing.xs),
                const Text('Editar'),
              ],
            ),
          ),

        // Sincronizar
        Button(
          onPressed: onRefresh,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FluentIcons.sync, size: 14),
              SizedBox(width: spacing.xs),
              const Text('Sincronizar'),
            ],
          ),
        ),
      ],
    );
  }

  /// Get company info for PDF generation
  ///
  /// Returns a map compatible with flutter_qweb's CompanyInfo.fromMap()
  /// Includes document layout configuration from base.document.layout
  Future<Map<String, dynamic>> _getCompanyInfo(WidgetRef ref) async {
    final companyRepo = ref.read(companyRepositoryProvider);
    final company = await companyRepo?.getCurrentUserCompany();

    return <String, dynamic>{
      'name': company?.name ?? '',
      'comercial_name': company?.l10nEcComercialName ?? company?.name ?? '',
      'vat': company?.vat ?? '',
      'street': company?.street ?? '',
      'street2': company?.street2 ?? '',
      'city': company?.city ?? '',
      'state': company?.stateName ?? '',
      'zip': company?.zip ?? '',
      'country': company?.countryName ?? '',
      'phone': company?.phone ?? '',
      'email': company?.email ?? '',
      'website': company?.website ?? '',
      'logo': company?.logo,
      'report_header_image': company?.reportHeaderImage,
      'report_footer': company?.reportFooter ?? '',
      'primary_color': company?.primaryColor ?? '#875A7B',
      'secondary_color': company?.secondaryColor ?? '#dee2e6',
      'font': company?.font ?? 'Lato',
      'layout_background': company?.layoutBackground ?? 'Blank',
      'external_report_layout':
          company?.externalReportLayoutId ?? 'web.external_layout_standard',
    };
  }

  /// Get user info for PDF generation
  Map<String, dynamic> _getUserInfo(WidgetRef ref) {
    final user = ref.read(userProvider);
    return <String, dynamic>{
      'id': user?.id,
      'name': user?.name ?? '',
      'login': user?.login ?? '',
      'email': user?.email ?? '',
    };
  }

  /// Load tax data map from database for lines
  ///
  /// Returns a map of tax Odoo ID -> tax data with name and amount
  Future<Map<int, Map<String, dynamic>>> _loadTaxDataMap(
    CatalogSyncRepository? catalogRepo,
    List<SaleOrderLine> lines,
  ) async {
    logger.d('[_loadTaxDataMap]', 'Starting with ${lines.length} lines');
    final result = <int, Map<String, dynamic>>{};
    if (catalogRepo == null) {
      logger.d('[_loadTaxDataMap]', 'catalogRepo is NULL!');
      return result;
    }

    // Collect all unique tax IDs from lines
    final taxIds = <int>{};
    for (final line in lines) {
      logger.d('[_loadTaxDataMap]', 'Line: taxIds="${line.taxIds}", taxNames="${line.taxNames}"');
      if (line.taxIds != null && line.taxIds!.isNotEmpty) {
        final ids = line.taxIds!
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>();
        taxIds.addAll(ids);
      }
    }

    logger.d('[_loadTaxDataMap]', 'Collected ${taxIds.length} unique tax IDs: $taxIds');

    // If no taxIds from lines, load ALL taxes as fallback
    if (taxIds.isEmpty) {
      logger.d('[_loadTaxDataMap]', 'No taxIds from lines, loading ALL taxes from DB');
      final allTaxes = await catalogRepo.getLocalTaxes();
      logger.d('[_loadTaxDataMap]', 'Loaded ${allTaxes.length} taxes from DB');
      for (final tax in allTaxes) {
        logger.d('[_loadTaxDataMap]', 'Tax ${tax.odooId}: name="${tax.name}", amount=${tax.amount}');
        result[tax.odooId] = {
          'name': tax.name,
          'amount': tax.amount,
          'amount_type': tax.amountType,
        };
      }
      return result;
    }

    // Load taxes from database
    final taxes = await catalogRepo.getLocalTaxesByIds(taxIds.toList());
    logger.d('[_loadTaxDataMap]', 'Loaded ${taxes.length} taxes from DB');
    for (final tax in taxes) {
      logger.d('[_loadTaxDataMap]', 'Tax ${tax.odooId}: name="${tax.name}", amount=${tax.amount}');
      result[tax.odooId] = {
        'name': tax.name,
        'amount': tax.amount,
        'amount_type': tax.amountType,
      };
    }

    return result;
  }

  /// Convert SaleOrder to report context map
  Map<String, dynamic> _orderToReportMap(
    SaleOrder order,
    List<SaleOrderLine> lines, {
    dynamic offlineInvoice,
    Map<int, Map<String, dynamic>>? taxDataMap,
  }) {
    logger.d('[_orderToReportMap]', 'Called with ${lines.length} lines, taxDataMap has ${taxDataMap?.length ?? 0} entries');
    if (taxDataMap != null && taxDataMap.isNotEmpty) {
      taxDataMap.forEach((id, data) {
        logger.d('[_orderToReportMap]', 'TaxData[$id]: ${data['name']}');
      });
    }
    // 1. Get base map from model (fixes tax_ids, gets stored values)
    final baseMap = order.toReportMap(lines: lines, taxDataMap: taxDataMap);

    // 2. Helper functions for formatting
    String formatCurrencyEc(double value, {String symbol = '\$'}) {
      final parts = value.toFixed(2).split('.');
      final intPart = parts[0].replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (match) => '${match[1]}.',
      );
      return '$symbol $intPart,${parts[1]}';
    }

    String? formatDateEc(DateTime? date) {
      if (date == null) return null;
      final day = date.day.toString().padLeft(2, '0');
      final month = date.month.toString().padLeft(2, '0');
      final year = date.year.toString();
      return '$day/$month/$year';
    }

    // 3. Logic to clean line description (Legacy logic ported for consistency)
    String getCleanLineName(SaleOrderLine line) {
      final lineName = line.name;
      final prodName = line.productName ?? '';

      // For sections/notes, return the line name as-is
      if (line.displayType != LineDisplayType.product) {
        return lineName;
      }

      if (lineName.isEmpty) return lineName;

      // PRIORITY 1: Check if line name contains a newline
      if (lineName.contains('\n')) {
        final parts = lineName.split('\n');
        if (parts.length > 1) {
          return parts.sublist(1).join('\n').trim();
        }
      }

      // PRIORITY 2: If line name equals product name exactly
      if (lineName == prodName) return lineName;

      // PRIORITY 3: If line name starts with product name
      if (prodName.isNotEmpty && lineName.startsWith(prodName)) {
        final customPart = lineName.substring(prodName.length).trim();
        if (customPart.isNotEmpty) return customPart;
      }

      return lineName;
    }

    // 4. Enrich Base Map with Header Fields
    baseMap['name'] = offlineInvoice?.invoiceName ?? order.name;
    baseMap['access_key'] = offlineInvoice?.accessKey;
    baseMap['is_offline_invoice'] = offlineInvoice != null;
    baseMap['offline_invoice_date'] = offlineInvoice != null
        ? formatDateEc(offlineInvoice.invoiceDate)
        : null;

    // Overwrite dates with Ecuador format (dd/MM/yyyy)
    baseMap['date_order'] = formatDateEc(order.dateOrder);
    baseMap['validity_date'] = formatDateEc(order.validityDate);
    baseMap['commitment_date'] = formatDateEc(order.commitmentDate);

    // 5. Enrich Lines with Formatted Values & Clean Name
    // order.toReportMap returns 'order_line' as List<Map<String, dynamic>>
    final List<dynamic> reportLines = baseMap['order_line'];
    
    // Get currency symbol map
    final symbol = order.currencySymbol ?? '\$';
    final symbolMap = {
      'USD': '\$',
      'EUR': '€',
      'GBP': '£',
      'PEN': 'S/',
      'COP': '\$',
      'MXN': '\$',
    };
    final currencySymbol = symbolMap[symbol] ?? symbol;

    // Calculate details for tax totals
    final hasDiscounts = order.totalDiscountAmount > 0 ||
        lines.any((l) => l.discount > 0 || l.discountAmount > 0);
        
    // Generate section totals used by template
    final sectionTotals = <int, double>{};
    int? currentSectionIndex;
    // Calculate section totals logic (re-implemented here as it depends on list index)
    for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        final isSection = line.displayType == LineDisplayType.lineSection;
        if (isSection) {
            currentSectionIndex = i;
            sectionTotals[i] = 0.0;
        } else if (currentSectionIndex != null && line.displayType == LineDisplayType.product) {
            sectionTotals[currentSectionIndex] = (sectionTotals[currentSectionIndex] ?? 0.0) + line.priceSubtotal;
        }
    }

    for (var i = 0; i < reportLines.length; i++) {
      final lineMap = reportLines[i] as Map<String, dynamic>;
      final line = lines[i]; // Corresponding line object

      // Overwrite name with cleaned description
      lineMap['name'] = getCleanLineName(line);
      
      // Inject section totals
      lineMap['section_totals'] = sectionTotals[i] ?? 0.0;

      // Add formatted currency fields
      if (lineMap['discount_amount'] is num) {
        lineMap['formatted_discount_amount'] = lineMap['discount_amount'] > 0
            ? formatCurrencyEc(lineMap['discount_amount'])
            : '\$ 0,00';
      }
      if (lineMap['price_subtotal'] is num) {
        lineMap['formatted_price_subtotal'] =
            formatCurrencyEc(lineMap['price_subtotal']);
      }
      if (lineMap['price_tax'] is num) {
        lineMap['formatted_price_tax'] =
            formatCurrencyEc(lineMap['price_tax']);
        lineMap['formatted_tax_amount'] = lineMap['formatted_price_tax'];
      }
      if (lineMap['price_total'] is num) {
        lineMap['formatted_price_total'] =
            formatCurrencyEc(lineMap['price_total']);
      }

      // Ensure currency_id symbol is mapped
      lineMap['currency_id'] = {
        'id': order.currencyId ?? 1,
        'name': symbol,
        'symbol': currencySymbol,
      };
      
      // Add 'is_optional' which might be missing in model map
      // Model doesn't have isOptional field in toReportMap? 
      // Checking SaleOrderLine model again... it doesn't seem to expose isOptional to report map
      // But let's check if SaleOrderLine object has it.
      // Assuming SaleOrderLine has isOptional getter or field (it's not in the common fields in model)
      // If it's used in template, we should add it.
    }

    // 6. Tax Totals (Formatted)
    // We overwrite the tax_totals from model with the formatted structure expected by template
    baseMap['tax_totals'] = {
      'amount_untaxed': order.amountUntaxed,
      'amount_total': order.amountTotal,
      'formatted_amount_untaxed': formatCurrencyEc(
        order.amountUntaxed,
        symbol: currencySymbol,
      ),
      'formatted_amount_total': formatCurrencyEc(
        order.amountTotal,
        symbol: currencySymbol,
      ),
      'subtotals': [
        {
          'name': 'Subtotal',
          'amount': order.amountUntaxed,
          'formatted_amount': formatCurrencyEc(
            order.amountUntaxed,
            symbol: currencySymbol,
          ),
          'base_amount_currency': order.amountUntaxed,
          'tax_groups': [
            // Simplified tax group (assuming single group for now or would need complex calc)
            // Existing logic assumed IVA 15% as main group
            {
              'group_name': 'IVA', // Generic name
              'tax_amount_currency': order.amountTax,
              'base_amount_currency': order.amountUntaxed,
              'display_base_amount_currency': order.amountUntaxed,
            },
          ],
        },
      ],
      'total_amount_currency': order.amountTotal,
      'has_discounts': hasDiscounts,
      'amount_undiscounted_currency': order.amountUntaxedUndiscounted,
      'discount_amount_currency': order.totalDiscountAmount,
    };

    // 7. Additional Template Controls
    baseMap['display_taxes'] = true;
    baseMap['hide_taxes_details'] = false;
    baseMap['display_discount'] = hasDiscounts;
    baseMap['amount_untaxed_undiscounted'] = order.amountUntaxedUndiscounted;
    baseMap['total_discount_amount'] = order.totalDiscountAmount;

    return baseMap;
  }

  /// Ensure templates are loaded from database
  Future<void> _ensureTemplatesLoaded(WidgetRef ref) async {
    final reportService = ref.read(reportServiceProvider);
    if (!reportService.templatesLoaded) {
      final templateRepo = ref.read(qwebTemplateRepositoryProvider);
      if (templateRepo != null) {
        await reportService.loadTemplatesFromDatabase(templateRepo);
      }
    }
  }

  /// Get RenderOptions for PDF generation
  /// Uses paper format from Odoo with Ecuador margin adjustments
  RenderOptions _getRenderOptions(
    ReportService reportService,
    String templateName,
  ) {
    // Get paper format from local database (synced from Odoo)
    final paperFormat = reportService.getPaperFormat(templateName);

    // Apply Ecuador margin rules:
    // - margin_top/bottom: subtract 15mm from Odoo values
    // - margin_left/right: minimum 10mm (if Odoo is 0, use 10)
    // - headerSpacing: always 0
    const double mmToPoints = 72.0 / 25.4;
    const double subtract15mm = 15.0; // mm to subtract from top/bottom
    const double minMargin = 10.0; // minimum left/right margin in mm

    if (paperFormat != null) {
      // Calculate adjusted margins
      final adjustedTop = (paperFormat.marginTop - subtract15mm).clamp(
        0.0,
        double.infinity,
      );
      final adjustedBottom = (paperFormat.marginBottom - subtract15mm).clamp(
        0.0,
        double.infinity,
      );
      final adjustedLeft = paperFormat.marginLeft < minMargin
          ? minMargin
          : paperFormat.marginLeft;
      final adjustedRight = paperFormat.marginRight < minMargin
          ? minMargin
          : paperFormat.marginRight;

      return RenderOptions(
        dpi: paperFormat.dpi,
        marginTop: adjustedTop * mmToPoints,
        marginBottom: adjustedBottom * mmToPoints,
        marginLeft: adjustedLeft * mmToPoints,
        marginRight: adjustedRight * mmToPoints,
        headerSpacing: 0, // Always 0
      );
    } else {
      // Fallback to default values
      return const RenderOptions(
        dpi: 120,
        marginTop: 28.35, // 10mm
        marginBottom: 0, // 0mm (15mm - 15mm)
        marginLeft: 28.35, // 10mm
        marginRight: 28.35, // 10mm
        headerSpacing: 0,
      );
    }
  }

  /// Handle print button - opens system print dialog
  Future<void> _handlePrint(BuildContext context, WidgetRef ref) async {
    logger.i('[_ViewActionButtons]', 'Print pressed for order ${order.name}');

    try {
      // Ensure templates are loaded from database
      await _ensureTemplatesLoaded(ref);

      final reportService = ref.read(reportServiceProvider);
      final formState = ref.read(saleOrderFormProvider);
      final lines = formState.lines;

      // Check if template is registered
      const templateName = 'sale.report_saleorder_document';
      if (!reportService.hasTemplate(templateName)) {
        throw ReportException(
          'Template de reporte no disponible. '
          'Sincronice los templates desde Odoo primero.',
        );
      }

      // Load tax data from database for proper tax names
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      final taxDataMap = await _loadTaxDataMap(catalogRepo, lines);

      final companyInfo = await _getCompanyInfo(ref);
      final userInfo = _getUserInfo(ref);
      final recordMap = _orderToReportMap(
        order,
        lines,
        taxDataMap: taxDataMap,
      );

      // Get consistent render options (same as preview)
      final options = _getRenderOptions(reportService, templateName);

      final success = await reportService.generateAndOpen(
        templateName: templateName,
        records: [recordMap],
        filename: '${order.name}.pdf',
        company: companyInfo,
        user: userInfo,
        options: options,
      );

      if (success) {
        logger.i(
          '[_ViewActionButtons]',
          'Print/Open completed for ${order.name}',
        );
      } else {
        logger.w(
          '[_ViewActionButtons]',
          'Print/Open cancelled/failed for ${order.name}',
        );
      }
    } catch (e) {
      if (context.mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error al imprimir',
          message: e.toString(),
        );
      }
    }
  }

  /// Handle preview button - opens PDF in a new tab (non-blocking)
  ///
  /// Opens the tab immediately in loading state and generates the PDF
  /// asynchronously, allowing the user to continue working in other tabs.
  Future<void> _handlePreview(BuildContext context, WidgetRef ref) async {
    // IMPORTANT: Capture ALL provider references BEFORE opening the new tab
    // because opening the tab switches focus and may unmount this widget,
    // making ref.read() unsafe after that point.
    final tabsNotifier = ref.read(saleOrderTabsProvider.notifier);
    final reportService = ref.read(reportServiceProvider);
    final formState = ref.read(saleOrderFormProvider);
    final lines = formState.lines;
    final templateRepo = ref.read(qwebTemplateRepositoryProvider);
    final companyRepo = ref.read(companyRepositoryProvider);
    final user = ref.read(userProvider);

    final filename = '${order.name}.pdf';

    // Open tab immediately in loading state (non-blocking)
    // After this point, the widget may be unmounted - do NOT use ref anymore!
    final tabId = tabsNotifier.openPdfPreviewLoading(
      orderId: order.id,
      orderName: order.name,
      filename: filename,
    );

    // Generate PDF asynchronously - no dialog blocking the UI
    try {
      // Ensure templates are loaded from database (using captured references)
      if (!reportService.templatesLoaded && templateRepo != null) {
        await reportService.loadTemplatesFromDatabase(templateRepo);
      }

      // Check if template is registered
      const templateName = 'sale.report_saleorder_document';
      if (!reportService.hasTemplate(templateName)) {
        throw ReportException(
          'Template de reporte no disponible. '
          'Sincronice los templates desde Odoo primero.',
        );
      }

      // Get company info using captured reference
      final company = await companyRepo?.getCurrentUserCompany();
      final companyInfo = <String, dynamic>{
        'name': company?.name ?? '',
        'comercial_name': company?.l10nEcComercialName ?? company?.name ?? '',
        'vat': company?.vat ?? '',
        'street': company?.street ?? '',
        'street2': company?.street2 ?? '',
        'city': company?.city ?? '',
        'state': company?.stateName ?? '',
        'zip': company?.zip ?? '',
        'country': company?.countryName ?? '',
        'phone': company?.phone ?? '',
        'email': company?.email ?? '',
        'website': company?.website ?? '',
        'logo': company?.logo,
        'report_header_image': company?.reportHeaderImage,
        'report_footer': company?.reportFooter ?? '',
        'primary_color': company?.primaryColor ?? '#875A7B',
        'secondary_color': company?.secondaryColor ?? '#dee2e6',
        'font': company?.font ?? 'Lato',
        'layout_background': company?.layoutBackground ?? 'Blank',
        'external_report_layout':
            company?.externalReportLayoutId ?? 'web.external_layout_standard',
      };

      // Get user info using captured reference
      final userInfo = <String, dynamic>{
        'id': user?.id,
        'name': user?.name ?? '',
        'login': user?.login ?? '',
        'email': user?.email ?? '',
      };

      // Load tax data from database for proper tax names
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      final taxDataMap = await _loadTaxDataMap(catalogRepo, lines);

      final recordMap = _orderToReportMap(
        order,
        lines,
        taxDataMap: taxDataMap,
      );

      // Get consistent render options (same as print)
      final options = _getRenderOptions(reportService, templateName);

      final pdfBytes = await reportService.getPreviewBytes(
        templateName: templateName,
        records: [recordMap],
        company: companyInfo,
        user: userInfo,
        options: options,
      );

      // Update tab with generated PDF bytes
      tabsNotifier.updatePdfPreviewContent(tabId, pdfBytes);

      logger.i('[FormHeader]', 'PDF preview generated for ${order.name}');
    } catch (e) {
      // Set error on the tab (shows error view instead of loading)
      tabsNotifier.setPdfPreviewError(tabId, e.toString());
    }
  }

  Future<void> _handleCancel(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmDialog(
      context,
      'Cancelar Orden',
      '¿Desea cancelar la orden ${order.name}?',
    );
    if (!confirmed) return;

    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo == null) return;

    try {
      await salesRepo.cancel(order.id);
      onRefresh();
    } on OdooException catch (e) {
      if (context.mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error al cancelar',
          message: e.message,
        );
      }
    } on DioException catch (e) {
      if (context.mounted) {
        String message = 'Ha ocurrido un error al cancelar la orden.';
        if (e.response?.statusCode == 422) {
          message = 'No tienes permisos para cancelar registros.';
        }
        CopyableInfoBar.showError(
          context,
          title: 'Error de permisos',
          message: message,
        );
      }
    }
  }

  Future<void> _handleConfirm(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmDialog(
      context,
      'Confirmar Venta',
      '¿Desea confirmar la orden ${order.name}?',
    );
    if (!confirmed) return;

    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo == null) return;

    try {
      await salesRepo.confirm(order.id);
      onRefresh();
    } on OdooException catch (e) {
      if (context.mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error al confirmar',
          message: e.message,
        );
      }
    }
  }

  Future<void> _handleSetToQuotation(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final title = order.state == SaleOrderState.cancel
        ? 'Reactivar Orden'
        : 'Volver a Cotización';
    final confirmed = await _showConfirmDialog(
      context,
      title,
      '¿Desea cambiar la orden ${order.name}?',
    );
    if (!confirmed) return;

    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo == null) return;

    try {
      await salesRepo.setToDraft(order.id);
      onRefresh();
    } on OdooException catch (e) {
      if (context.mounted) {
        CopyableInfoBar.showError(context, title: 'Error', message: e.message);
      }
    }
  }

  Future<void> _handleReserveStock(BuildContext context, WidgetRef ref) async {
    if (!context.mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => ContentDialog(
        title: const Text('Reservar Stock'),
        content: const Text('Funcionalidad próximamente.'),
        actions: [
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
  }

  /// Lock the order (set locked=true in Odoo)
  Future<void> _handleLock(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmDialog(
      context,
      'Bloquear Orden',
      '¿Está seguro de bloquear esta orden?\n\n'
          'Una vez bloqueada, no se podrá cancelar ni volver a cotización.',
    );
    if (!confirmed || !context.mounted) return;

    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      final order = ref.read(saleOrderFormProvider).order;
      if (salesRepo == null || order == null) return;

      await salesRepo.lockOrder(order.id);

      // Update locked status reactively (no full reload)
      ref.read(saleOrderFormProvider.notifier).updateOrderLocked(true);

      // Sync with Fast Sale provider (cross-provider sync)
      ref.read(fastSaleProvider.notifier).updateOrderLockedById(order.id, true);

      if (context.mounted) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Orden bloqueada',
          message: 'La orden ha sido bloqueada exitosamente.',
        );
      }
    } on OdooException catch (e) {
      if (context.mounted) {
        CopyableInfoBar.showError(context, title: 'Error', message: e.message);
      }
    }
  }

  /// Unlock the order (set locked=false in Odoo)
  Future<void> _handleUnlock(BuildContext context, WidgetRef ref) async {
    final confirmed = await _showConfirmDialog(
      context,
      'Desbloquear Orden',
      '¿Está seguro de desbloquear esta orden?\n\n'
          'Esto permitirá cancelar o volver a cotización.',
    );
    if (!confirmed || !context.mounted) return;

    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      final order = ref.read(saleOrderFormProvider).order;
      if (salesRepo == null || order == null) return;

      await salesRepo.unlockOrder(order.id);

      // Update locked status reactively (no full reload)
      ref.read(saleOrderFormProvider.notifier).updateOrderLocked(false);

      // Sync with Fast Sale provider (cross-provider sync)
      ref
          .read(fastSaleProvider.notifier)
          .updateOrderLockedById(order.id, false);

      if (context.mounted) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Orden desbloqueada',
          message: 'La orden ha sido desbloqueada exitosamente.',
        );
      }
    } on OdooException catch (e) {
      if (context.mounted) {
        CopyableInfoBar.showError(context, title: 'Error', message: e.message);
      }
    }
  }

  Future<bool> _showConfirmDialog(
    BuildContext context,
    String title,
    String message,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => ContentDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              Button(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('No'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Sí'),
              ),
            ],
          ),
        ) ??
        false;
  }
}

// ============================================================
// BOTONES DE ACCION MODO EDICION
// ============================================================
class _EditActionButtons extends ConsumerWidget {
  final bool isNew;
  final bool isSaving;
  final SaleOrder? order;
  final VoidCallback onBack;
  final VoidCallback onDiscard;
  final VoidCallback onSave;
  final VoidCallback onDelete;

  const _EditActionButtons({
    required this.isNew,
    required this.isSaving,
    required this.order,
    required this.onBack,
    required this.onDiscard,
    required this.onSave,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final spacing = ref.watch(themedSpacingProvider);
    final user = ref.watch(userProvider);
    final canDelete =
        user?.permissions.contains('l10n_ec_sale_base.group_sale_delete') ??
        false;

    return Wrap(
      spacing: spacing.sm,
      runSpacing: spacing.sm,
      alignment: WrapAlignment.end,
      children: [
        // Botón Eliminar - Solo visible para órdenes no sincronizadas y con permiso
        if (!isNew && order != null && !order!.isSynced && canDelete)
          Button(
            onPressed: isSaving ? null : onDelete,
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.all(
                Colors.red.withValues(alpha: 0.1),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(FluentIcons.delete, size: 14, color: Colors.red),
                SizedBox(width: spacing.xs),
                Text('Eliminar', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),

        // Botón Descartar
        Button(
          onPressed: isSaving ? null : onDiscard,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(FluentIcons.clear, size: 14),
              SizedBox(width: spacing.xs),
              const Text('Descartar'),
            ],
          ),
        ),

        // Botón Guardar
        FilledButton(
          onPressed: isSaving ? null : onSave,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isSaving)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: ProgressRing(strokeWidth: 2),
                )
              else
                const Icon(FluentIcons.save, size: 14),
              SizedBox(width: spacing.xs),
              const Text('Guardar'),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================
// WIDGETS COMPARTIDOS
// ============================================================
class _PendingSyncBadge extends ConsumerStatefulWidget {
  final bool isCompact;
  final int orderId;

  const _PendingSyncBadge({this.isCompact = false, required this.orderId});

  @override
  ConsumerState<_PendingSyncBadge> createState() => _PendingSyncBadgeState();
}

class _PendingSyncBadgeState extends ConsumerState<_PendingSyncBadge> {
  bool _isSyncing = false;

  Future<void> _syncOrder() async {
    if (_isSyncing) return;

    setState(() => _isSyncing = true);

    logger.i(
      '[_PendingSyncBadge]',
      '🔄 Starting sync for order ID: ${widget.orderId}',
    );

    try {
      // VALIDACIÓN PRE-SYNC: Obtener la orden local y validar
      final localOrder = await saleOrderManager.getSaleOrder(widget.orderId);

      if (localOrder == null) {
        throw Exception('Orden no encontrada en la base de datos local');
      }

      // Validar consumidor final
      if (localOrder.isFinalConsumer &&
          (localOrder.endCustomerName == null ||
              localOrder.endCustomerName!.trim().isEmpty)) {
        if (mounted) {
          CopyableInfoBar.showWarning(
            context,
            title: 'Validación requerida',
            message:
                'El nombre del consumidor final es obligatorio cuando el cliente es Consumidor Final.\n\n'
                'Por favor edite la orden y complete el campo "Nombre Consumidor Final" antes de sincronizar.',
            durationSeconds: 10,
          );
          setState(() => _isSyncing = false);
        }
        return;
      }

      // Use OfflineSyncService to process only this order's pending operations
    final syncService = ref.read(offlineSyncServiceProvider);
    if (syncService == null) {
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error de sincronización',
          message: 'Servicio de sincronización no disponible',
        );
      }
      return;
    }

    final isOnline = ref.read(odooClientProvider)?.isConfigured ?? false;
    if (!isOnline) {
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Sin conexión',
          message: 'No hay conexión con el servidor Odoo',
        );
      }
      return;
    }

      logger.d(
        '[_PendingSyncBadge]',
        '📤 Processing queue for order ${widget.orderId}...',
      );

      // Process only operations for THIS specific order (in FIFO order)
      final result = await syncService.processSaleOrderQueue(widget.orderId);

      logger.d(
        '[_PendingSyncBadge]',
        'Sync result for order ${widget.orderId}: ${result.synced} synced, ${result.failed} failed',
      );

      if (result.hasErrors) {
        throw Exception(
          'Errores durante la sincronización: ${result.errors.join(", ")}',
        );
      }

      // Reload the order from server to get fresh data
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo != null) {
        await salesRepo.getById(widget.orderId, forceRefresh: true);
      }

      // Reload the form with synced data
      ref
          .read(saleOrderFormProvider.notifier)
          .loadOrder(widget.orderId, forceRefresh: true);

      if (mounted) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Sincronizado',
          message: result.synced > 0
              ? 'Se sincronizaron ${result.synced} operaciones'
              : 'Orden sincronizada correctamente',
        );
      }
    } catch (e) {
      if (mounted) {
        CopyableInfoBar.showError(
          context,
          title: 'Error de sincronización',
          message: 'No se pudo sincronizar la orden:\n\n$e',
          durationSeconds: 15,
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
    final theme = FluentTheme.of(context);
    return Tooltip(
      message: 'Clic para sincronizar ahora',
      child: Button(
        onPressed: _isSyncing ? null : _syncOrder,
        style: ButtonStyle(
          padding: WidgetStateProperty.all(
            EdgeInsets.symmetric(
              horizontal: widget.isCompact ? 4 : 8,
              vertical: 4,
            ),
          ),
          backgroundColor: WidgetStateProperty.all(
            Colors.orange.withValues(alpha: 0.15),
          ),
          shape: WidgetStateProperty.all(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(4),
              side: BorderSide(color: Colors.orange),
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_isSyncing)
              const SizedBox(
                width: 12,
                height: 12,
                child: ProgressRing(strokeWidth: 2),
              )
            else
              Icon(FluentIcons.sync, size: 12, color: Colors.orange),
            if (!widget.isCompact) ...[
              const SizedBox(width: 4),
              Text(
                _isSyncing ? 'Sincronizando...' : 'Sincronizar',
                style: theme.typography.caption?.copyWith(
                  color: Colors.orange,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Alerta informativa cuando el cliente es consumidor final (SRI Ecuador)
/// Usa StatusIndicator.infoAlert internamente
class _FinalConsumerInfoAlert extends StatelessWidget {
  final WidgetRef ref;

  const _FinalConsumerInfoAlert({required this.ref});

  @override
  Widget build(BuildContext context) {
    final salesConfig = ref.watch(salesConfigProvider);
    final limit = salesConfig.saleCustomerInvoiceLimitSri ?? 50.0;

    return StatusIndicator.infoAlert(
      title: 'Consumidor Final de Ecuador',
      message:
          'Este cliente está configurado como consumidor final. '
          'Límite máximo permitido según el SRI: ${limit.toCurrency()} USD.',
    );
  }
}
