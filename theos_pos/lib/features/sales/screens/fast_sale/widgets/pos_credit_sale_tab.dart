import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/services/odoo_service.dart';
import '../../../../../core/theme/spacing.dart';
import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../clients/clients.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import '../../../providers/service_providers.dart';
import '../../../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../fast_sale_providers.dart';

/// Tab content for credit sales (orders with payment terms)
///
/// Shows:
/// - Credit status summary
/// - Invoice button (if no credit issues or approved)
/// - Credit approval request (if credit exceeded)
class POSCreditSaleTab extends ConsumerStatefulWidget {
  const POSCreditSaleTab({super.key});

  @override
  ConsumerState<POSCreditSaleTab> createState() => _POSCreditSaleTabState();
}

class _POSCreditSaleTabState extends ConsumerState<POSCreditSaleTab> {
  bool _isLoading = false;
  bool _isValidatingCredit = true;
  CreditValidationResult? _creditResult;
  Client? _client;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _validateCredit();
  }

  Future<void> _validateCredit() async {
    final activeTab = ref.read(fastSaleActiveTabProvider);
    if (activeTab?.order == null || activeTab?.order?.partnerId == null) {
      setState(() {
        _isValidatingCredit = false;
        _errorMessage = 'No hay cliente seleccionado';
      });
      return;
    }

    final order = activeTab!.order!;
    final partnerId = order.partnerId!;

    try {
      // Get client data using ClientRepository
      final clientRepo = ref.read(clientRepositoryProvider);
      if (clientRepo == null) {
        setState(() {
          _isValidatingCredit = false;
          _errorMessage = 'Repositorio no disponible';
        });
        return;
      }

      _client = await clientRepo.getById(partnerId);
      if (_client == null) {
        setState(() {
          _isValidatingCredit = false;
          _errorMessage = 'No se pudo obtener información del cliente';
        });
        return;
      }

      // Check if client has credit control enabled
      if (!_client!.hasCreditLimit) {
        // No credit control, can invoice directly
        setState(() {
          _isValidatingCredit = false;
          _creditResult = null;
        });
        return;
      }

      // Validate credit using ClientCreditService
      final clientCreditService = ref.read(clientCreditServiceProvider);
      if (clientCreditService == null) {
        // Fallback: no credit check if service unavailable
        setState(() {
          _isValidatingCredit = false;
          _creditResult = null;
        });
        return;
      }

      final orderAmount = activeTab.total;
      _creditResult = await clientCreditService.validateOrderCreditForClient(
        client: _client!,
        orderAmount: orderAmount,
        isOnline: ref.read(odooServiceProvider).isLoggedIn,
      );

      setState(() {
        _isValidatingCredit = false;
      });
    } catch (e) {
      logger.e('[POSCreditSaleTab]', 'Error validating credit: $e');
      setState(() {
        _isValidatingCredit = false;
        _errorMessage = 'Error al validar crédito: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final activeTab = ref.watch(fastSaleActiveTabProvider);
    final order = activeTab?.order;

    if (order == null) {
      return _buildEmptyState(theme, 'No hay orden activa');
    }

    if (_isValidatingCredit) {
      return _buildLoadingState(theme, 'Validando crédito...');
    }

    if (_errorMessage != null) {
      return _buildErrorState(theme, _errorMessage!);
    }

    // Check order state
    if (order.state == SaleOrderState.draft) {
      return _buildDraftState(theme, order);
    }

    if (order.state == SaleOrderState.waitingApproval) {
      return _buildWaitingApprovalState(theme, order);
    }

    if (order.invoiceStatus == InvoiceStatus.invoiced) {
      return _buildInvoicedState(theme, order);
    }

    // Order is confirmed (sale state) - show credit info and invoice button
    return _buildCreditSaleContent(theme, order, activeTab!);
  }

  Widget _buildEmptyState(FluentThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.info, size: 48, color: Colors.grey[100]),
          const SizedBox(height: Spacing.sm),
          Text(message, style: theme.typography.body),
        ],
      ),
    );
  }

  Widget _buildLoadingState(FluentThemeData theme, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const ProgressRing(),
          const SizedBox(height: Spacing.sm),
          Text(message, style: theme.typography.body),
        ],
      ),
    );
  }

  Widget _buildErrorState(FluentThemeData theme, String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.error_badge, size: 48, color: Colors.red),
          const SizedBox(height: Spacing.sm),
          Text(error, style: theme.typography.body),
          const SizedBox(height: Spacing.md),
          Button(
            onPressed: () {
              setState(() {
                _isValidatingCredit = true;
                _errorMessage = null;
              });
              _validateCredit();
            },
            child: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }

  Widget _buildDraftState(FluentThemeData theme, SaleOrder order) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.edit, size: 48, color: Colors.orange),
          const SizedBox(height: Spacing.sm),
          Text(
            'Orden en Borrador',
            style: theme.typography.subtitle,
          ),
          const SizedBox(height: Spacing.xs),
          Text(
            'Confirme la orden primero para poder facturar',
            style: theme.typography.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.md),
          Text(
            'Plazo: ${order.paymentTermName ?? "Sin definir"}',
            style: theme.typography.caption,
          ),
        ],
      ),
    );
  }

  Widget _buildWaitingApprovalState(FluentThemeData theme, SaleOrder order) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: Spacing.xl),
          Icon(FluentIcons.clock, size: 64, color: Colors.orange),
          const SizedBox(height: Spacing.md),
          Text(
            'Esperando Aprobación',
            style: theme.typography.subtitle?.copyWith(
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: Spacing.sm),
          Text(
            'Esta orden está pendiente de aprobación de crédito.',
            style: theme.typography.body,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Icon(FluentIcons.info, color: Colors.orange, size: 20),
                    const SizedBox(width: Spacing.sm),
                    Expanded(
                      child: Text(
                        'El cliente excede su límite de crédito.',
                        style: theme.typography.body,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: Spacing.sm),
                Text(
                  'Una vez aprobada, podrá confirmar y facturar la orden.',
                  style: theme.typography.caption,
                ),
              ],
            ),
          ),
          const SizedBox(height: Spacing.md),
          // Credit info if available
          if (_client != null) ...[
            const Divider(),
            const SizedBox(height: Spacing.sm),
            _buildCreditInfoCard(theme, order.amountTotal),
          ],
        ],
      ),
    );
  }

  Widget _buildInvoicedState(FluentThemeData theme, SaleOrder order) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(FluentIcons.completed, size: 48, color: Colors.green),
          const SizedBox(height: Spacing.sm),
          Text(
            'Orden Facturada',
            style: theme.typography.subtitle,
          ),
          const SizedBox(height: Spacing.xs),
          if (order.invoiceCount > 0)
            Text(
              '${order.invoiceCount} factura(s) generada(s)',
              style: theme.typography.body,
            ),
        ],
      ),
    );
  }

  Widget _buildCreditSaleContent(
    FluentThemeData theme,
    SaleOrder order,
    FastSaleTabState activeTab,
  ) {
    final hasIssues = _creditResult != null && !_creditResult!.isValid;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(Spacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          _buildHeader(theme, order),
          const SizedBox(height: Spacing.md),

          // Credit info card
          if (_client != null) _buildCreditInfoCard(theme, activeTab.total),
          const SizedBox(height: Spacing.md),

          // Credit status
          if (_creditResult != null) _buildCreditStatusCard(theme),
          const SizedBox(height: Spacing.lg),

          // Action buttons
          if (hasIssues)
            _buildCreditIssueActions(theme, order, activeTab)
          else
            _buildInvoiceButton(theme, order),
        ],
      ),
    );
  }

  Widget _buildHeader(FluentThemeData theme, SaleOrder order) {
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: Colors.teal.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.teal.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.calendar, color: Colors.teal, size: 24),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Venta a Crédito',
                  style: theme.typography.bodyStrong?.copyWith(
                    color: Colors.teal,
                  ),
                ),
                Text(
                  'Plazo: ${order.paymentTermName ?? "No definido"}',
                  style: theme.typography.caption,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: Spacing.sm,
              vertical: Spacing.xs,
            ),
            decoration: BoxDecoration(
              color: Colors.blue.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              'Confirmada',
              style: theme.typography.caption?.copyWith(
                color: Colors.blue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditInfoCard(FluentThemeData theme, double orderAmount) {
    final client = _client!;
    final creditLimit = client.creditLimit ?? 0;
    final creditUsed = (client.credit ?? 0) + (client.creditToInvoice ?? 0);
    final creditAvailable = client.creditAvailable ?? (creditLimit - creditUsed);

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.dividerStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Información de Crédito',
            style: theme.typography.bodyStrong,
          ),
          const SizedBox(height: Spacing.sm),
          _buildCreditRow(theme, 'Límite de Crédito:', creditLimit),
          _buildCreditRow(theme, 'Crédito Usado:', creditUsed),
          _buildCreditRow(
            theme,
            'Crédito Disponible:',
            creditAvailable,
            color: creditAvailable >= orderAmount ? Colors.green : Colors.red,
          ),
          const Divider(),
          _buildCreditRow(
            theme,
            'Monto de la Venta:',
            orderAmount,
            isBold: true,
          ),
          if (client.totalOverdue != null && client.totalOverdue! > 0)
            _buildCreditRow(
              theme,
              'Deuda Vencida:',
              client.totalOverdue!,
              color: Colors.red,
            ),
        ],
      ),
    );
  }

  Widget _buildCreditRow(
    FluentThemeData theme,
    String label,
    double value, {
    Color? color,
    bool isBold = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: theme.typography.body),
          Text(
            value.toCurrency(),
            style: (isBold ? theme.typography.bodyStrong : theme.typography.body)
                ?.copyWith(color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildCreditStatusCard(FluentThemeData theme) {
    final result = _creditResult!;
    final isOk = result.isValid;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: isOk
            ? Colors.green.withValues(alpha: 0.1)
            : Colors.orange.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isOk
              ? Colors.green.withValues(alpha: 0.3)
              : Colors.orange.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isOk ? FluentIcons.check_mark : FluentIcons.warning,
            color: isOk ? Colors.green : Colors.orange,
            size: 24,
          ),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isOk ? 'Crédito Aprobado' : 'Requiere Aprobación',
                  style: theme.typography.bodyStrong?.copyWith(
                    color: isOk ? Colors.green : Colors.orange,
                  ),
                ),
                if (!isOk && result.message != null)
                  Text(
                    result.message!,
                    style: theme.typography.caption,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInvoiceButton(FluentThemeData theme, SaleOrder order) {
    return FilledButton(
      onPressed: _isLoading ? null : () => _createInvoice(order),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.teal),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: Spacing.md),
        ),
      ),
      child: _isLoading
          ? const SizedBox(
              width: 20,
              height: 20,
              child: ProgressRing(strokeWidth: 2),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(FluentIcons.document, size: 20),
                const SizedBox(width: Spacing.sm),
                Text(
                  'Crear Factura',
                  style: theme.typography.bodyStrong?.copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
    );
  }

  Widget _buildCreditIssueActions(
    FluentThemeData theme,
    SaleOrder order,
    FastSaleTabState activeTab,
  ) {
    return FilledButton(
      onPressed: _isLoading
          ? null
          : () => _showCreditControlDialog(order, activeTab),
      style: ButtonStyle(
        backgroundColor: WidgetStateProperty.all(Colors.orange),
        padding: WidgetStateProperty.all(
          const EdgeInsets.symmetric(vertical: Spacing.md),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(FluentIcons.certificate, size: 20),
          const SizedBox(width: Spacing.sm),
          Text(
            'Solicitar Aprobación de Crédito',
            style: theme.typography.bodyStrong?.copyWith(
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showCreditControlDialog(
    SaleOrder order,
    FastSaleTabState activeTab,
  ) async {
    if (_client == null || _creditResult == null) return;

    final action = await CreditControlDialog.show(
      context: context,
      client: _client!,
      validationResult: _creditResult!,
      orderAmount: activeTab.total,
      isOnline: true,
    );

    if (action == CreditDialogAction.createApproval) {
      await _createApprovalRequest(order);
    }
    // No se permite facturar si no cumple los requisitos de crédito
  }

  Future<void> _createApprovalRequest(SaleOrder order) async {
    setState(() => _isLoading = true);

    try {
      final notifier = ref.read(fastSaleProvider.notifier);
      final checkType = _creditResult?.type.name ?? 'credit_limit_exceeded';

      final approvalId = await notifier.createCreditApprovalRequest(
        checkType: checkType,
        reason: _creditResult?.message ?? 'Excede límite de crédito',
      );

      if (!mounted) return;

      if (approvalId != null) {
        CopyableInfoBar.showSuccess(
          context,
          title: 'Solicitud creada',
          message: 'La solicitud de aprobación ha sido enviada.',
        );
      } else {
        CopyableInfoBar.showError(
          context,
          title: 'Error de aprobacion',
          message: 'No se pudo crear la solicitud',
        );
      }
    } catch (e) {
      if (!mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error de aprobacion',
        message: 'No se pudo crear la solicitud. Intente nuevamente.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _createInvoice(SaleOrder order) async {
    setState(() => _isLoading = true);

    try {
      final paymentService = ref.read(paymentServiceProvider);
      final invoiceId = await paymentService.createInvoiceForCreditSale(order.id);

      if (!mounted) return;

      if (invoiceId != null) {
        // Get invoice name
        String? invoiceName;
        try {
          final odoo = ref.read(odooServiceProvider);
          final invoiceData = await odoo.call(
            model: 'account.move',
            method: 'search_read',
            kwargs: {
              'domain': [['id', '=', invoiceId]],
              'fields': ['name'],
              'limit': 1,
            },
          );
          if (invoiceData is List && invoiceData.isNotEmpty) {
            invoiceName = invoiceData[0]['name'] as String?;
          }
        } catch (_) {}

        if (!mounted) return;
        CopyableInfoBar.showSuccess(
          context,
          title: 'Factura creada',
          message: invoiceName != null
              ? 'Factura $invoiceName generada correctamente'
              : 'Factura generada correctamente',
        );

        // Reload the order to update invoice status
        await ref.read(fastSaleProvider.notifier).reloadActiveOrder();
      } else {
        CopyableInfoBar.showError(
          context,
          title: 'Error de facturación',
          message: 'No se pudo crear la factura',
        );
      }
    } catch (e) {
      if (!mounted) return;
      CopyableInfoBar.showError(
        context,
        title: 'Error de facturación',
        message: 'No se pudo crear la factura. Intente nuevamente.',
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
