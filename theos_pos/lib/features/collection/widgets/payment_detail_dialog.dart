import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/spacing.dart';
import '../../../shared/utils/formatting_utils.dart';
import '../../../shared/widgets/dialogs/base_detail_dialog.dart';
import '../../sales/providers/service_providers.dart';
import '../../sales/services/payment_service.dart';

/// Provider para detalle del cobro
final paymentDetailProvider =
    FutureProvider.family<SessionPayment?, int>((ref, paymentId) async {
  final paymentService = ref.watch(paymentServiceProvider);
  return paymentService.getPaymentDetail(paymentId);
});

/// Diálogo de detalle de cobro.
///
/// Migrado a usar [AsyncDetailDialog] para mantener consistencia
/// con otros diálogos de detalle.
///
/// Muestra información completa del cobro:
/// - Datos generales (nombre, fecha, estado)
/// - Cliente
/// - Método de pago (diario, categoría)
/// - Origen del pago
/// - Monto
/// - Referencia
class PaymentDetailDialog extends ConsumerWidget {
  final int paymentId;

  const PaymentDetailDialog({super.key, required this.paymentId});

  static Future<void> show({
    required BuildContext context,
    required int paymentId,
  }) {
    return showDialog(
      context: context,
      builder: (context) => PaymentDetailDialog(paymentId: paymentId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paymentAsync = ref.watch(paymentDetailProvider(paymentId));

    return AsyncDetailDialog<SessionPayment>(
      config: DetailDialogConfig(
        title: 'Detalle del Cobro',
        maxWidth: 500,
        maxHeight: 600,
        showRefreshButton: true,
      ),
      asyncValue: paymentAsync,
      onRefresh: () => ref.invalidate(paymentDetailProvider(paymentId)),
      notFoundMessage: 'Cobro no encontrado',
      errorPrefix: 'Error cargando cobro',
      contentBuilder: (context, ref, payment) => _PaymentDetailContent(
        payment: payment,
      ),
    );
  }
}

/// Widget interno con el contenido del detalle
class _PaymentDetailContent extends StatelessWidget {
  final SessionPayment payment;

  const _PaymentDetailContent({required this.payment});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final dateFormat = DateFormat('dd/MM/yyyy HH:mm');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header con estado
        _buildHeader(theme),
        const SizedBox(height: Spacing.md),

        // Monto
        _buildAmountCard(theme),
        const SizedBox(height: Spacing.md),

        // Información del cliente
        DetailSection(
          title: 'Cliente',
          children: [
            DetailInfoRow(
              label: 'Nombre',
              value: payment.partnerName ?? 'Desconocido',
            ),
            DetailInfoRow(
              label: 'ID',
              value: payment.partnerId?.toString() ?? '-',
            ),
          ],
        ),

        // Método de pago
        DetailSection(
          title: 'Método de Pago',
          children: [
            DetailInfoRow(
              label: 'Diario',
              value: payment.journalName ?? '-',
            ),
            DetailInfoRow(
              label: 'Método',
              value: payment.paymentMethodLineName ?? '-',
            ),
            DetailInfoRow(
              label: 'Categoría',
              value: payment.methodCategory.label,
            ),
          ],
        ),

        // Detalles
        DetailSection(
          title: 'Detalles',
          showDivider: false,
          children: [
            DetailInfoRow(
              label: 'Fecha',
              value: payment.date != null
                  ? dateFormat.format(payment.date!)
                  : 'Sin fecha',
            ),
            DetailInfoRow(
              label: 'Referencia',
              value: payment.ref ?? '-',
            ),
            if (payment.originType != null)
              DetailInfoRow(
                label: 'Origen',
                value: payment.originType!.label,
              ),
            DetailInfoRow(
              label: 'Tipo',
              value: payment.isInbound ? 'Cobro' : 'Pago',
            ),
            if (payment.invoiceIds != null && payment.invoiceIds!.isNotEmpty)
              DetailInfoRow(
                label: 'Facturas',
                value: payment.invoiceIds!.map((id) => '#$id').join(', '),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildHeader(FluentThemeData theme) {
    final stateColor = _getStateColor(payment.state);
    final categoryColor = _getCategoryColor(payment.methodCategory);

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: categoryColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: categoryColor.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _getCategoryIcon(payment.methodCategory),
              color: categoryColor,
              size: 28,
            ),
          ),
          const SizedBox(width: Spacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  payment.name ?? 'Sin nombre',
                  style: theme.typography.subtitle,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: stateColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(
                          color: stateColor.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Text(
                        payment.state.label,
                        style: theme.typography.caption?.copyWith(
                          color: stateColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: Spacing.xs),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Spacing.xs,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        payment.methodCategory.label,
                        style: theme.typography.caption?.copyWith(
                          color: categoryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountCard(FluentThemeData theme) {
    final amountColor = payment.isInbound ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: amountColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: amountColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            payment.isInbound ? FluentIcons.add : FluentIcons.remove,
            color: amountColor,
            size: 24,
          ),
          const SizedBox(width: Spacing.sm),
          Text(
            payment.amount.toCurrency(),
            style: theme.typography.title?.copyWith(
              color: amountColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Color _getStateColor(PaymentState state) {
    switch (state) {
      case PaymentState.draft:
        return Colors.grey;
      case PaymentState.posted:
        return Colors.green;
      case PaymentState.canceled:
        return Colors.red;
      case PaymentState.rejected:
        return Colors.red.darker;
    }
  }

  Color _getCategoryColor(PaymentMethodCategory category) {
    switch (category) {
      case PaymentMethodCategory.cash:
        return Colors.green;
      case PaymentMethodCategory.cardCredit:
        return Colors.blue;
      case PaymentMethodCategory.cardDebit:
        return Colors.teal;
      case PaymentMethodCategory.cheque:
        return Colors.orange;
      case PaymentMethodCategory.transfer:
        return Colors.purple;
      case PaymentMethodCategory.other:
        return Colors.grey;
    }
  }

  IconData _getCategoryIcon(PaymentMethodCategory category) {
    switch (category) {
      case PaymentMethodCategory.cash:
        return FluentIcons.money;
      case PaymentMethodCategory.cardCredit:
      case PaymentMethodCategory.cardDebit:
        return FluentIcons.payment_card;
      case PaymentMethodCategory.cheque:
        return FluentIcons.page;
      case PaymentMethodCategory.transfer:
        return FluentIcons.bank;
      case PaymentMethodCategory.other:
        return FluentIcons.more;
    }
  }
}
