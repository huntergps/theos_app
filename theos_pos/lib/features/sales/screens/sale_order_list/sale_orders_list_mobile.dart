import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import '../../ui/sale_order_ui_extensions.dart';
import '../../../../../shared/widgets/common_form_widgets.dart';
import '../../../../../shared/widgets/grid/theos_date_cell.dart';
import '../../../../../shared/widgets/grid/theos_number_cell.dart';

class SaleOrdersMobile extends StatelessWidget {
  final List<SaleOrder> orders;
  final Function(SaleOrder) onOrderTap;
  final bool canDelete;
  final Function(SaleOrder)? onDelete;
  final bool canConfirm;
  final Function(SaleOrder)? onConfirm;

  const SaleOrdersMobile({
    super.key,
    required this.orders,
    required this.onOrderTap,
    this.canDelete = false,
    this.onDelete,
    this.canConfirm = false,
    this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      itemCount: orders.length,
      itemBuilder: (context, index) {
        final order = orders[index];
        final card = _SaleOrderCard(
          order: order,
          onTap: () => onOrderTap(order),
        );

        if ((canDelete && onDelete != null) ||
            (canConfirm && onConfirm != null)) {
          return Dismissible(
            key: ValueKey(order.id),
            // Allow swiping left (delete) if permitted, right (confirm) if permitted
            direction: (canDelete && canConfirm && order.canConfirm)
                ? DismissDirection.horizontal
                : (canDelete
                      ? DismissDirection.endToStart
                      : (canConfirm && order.canConfirm
                            ? DismissDirection.startToEnd
                            : DismissDirection.none)),

            // DELETE Background (Red, Swipe Left)
            background: Container(
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.only(left: 20),
              color: Colors.green,
              child: const Icon(FluentIcons.accept, color: Colors.white),
            ),

            // CONFIRM Background (Green, Swipe Right)
            secondaryBackground: Container(
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              color: Colors.red,
              child: const Icon(FluentIcons.delete, color: Colors.white),
            ),

            confirmDismiss: (direction) async {
              if (direction == DismissDirection.endToStart &&
                  canDelete &&
                  onDelete != null) {
                // DELETE
                onDelete!(order);
                return false;
              } else if (direction == DismissDirection.startToEnd &&
                  canConfirm &&
                  onConfirm != null &&
                  order.canConfirm) {
                // CONFIRM
                onConfirm!(order);
                return false;
              }
              return false;
            },
            child: card,
          );
        }

        return card;
      },
    );
  }
}

class _SaleOrderCard extends StatelessWidget {
  final SaleOrder order;
  final VoidCallback onTap;

  const _SaleOrderCard({required this.order, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Button(
          onPressed: onTap,
          style: ButtonStyle(padding: WidgetStateProperty.all(EdgeInsets.zero)),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header: Nombre y estado
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        order.name,
                        style: theme.typography.subtitle?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    TheosStateChip(
                      label: order.state.label,
                      color: order.state.color,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                // Cliente
                Row(
                  children: [
                    Icon(
                      FluentIcons.contact,
                      size: 16,
                      color: theme.inactiveColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        (order.partnerName?.isNotEmpty ?? false)
                            ? order.partnerName!
                            : 'Sin cliente',
                        style: theme.typography.body,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                // Fecha
                Row(
                  children: [
                    Icon(
                      FluentIcons.calendar,
                      size: 16,
                      color: theme.inactiveColor,
                    ),
                    const SizedBox(width: 4),
                    TheosDateCell(
                      value: order.dateOrder,
                      format: 'dd/MM/yyyy HH:mm',
                      style: theme.typography.caption?.copyWith(
                        color: theme.inactiveColor,
                      ),
                      placeholder: 'Sin fecha',
                    ),
                  ],
                ),
                const Divider(),
                // Totales
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Subtotal',
                          style: theme.typography.caption?.copyWith(
                            color: theme.inactiveColor,
                          ),
                        ),
                        TheosNumberCell(
                          value: order.amountUntaxed,
                          currencySymbol: order.currencySymbol ?? '\$',
                          alignment: Alignment.centerLeft,
                          style: theme.typography.body,
                        ),
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'Total',
                          style: theme.typography.caption?.copyWith(
                            color: theme.inactiveColor,
                          ),
                        ),
                        TheosNumberCell(
                          value: order.amountTotal,
                          currencySymbol: order.currencySymbol ?? '\$',
                          isBold: true,
                          alignment: Alignment.centerRight,
                          style: theme.typography.subtitle?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.accentColor,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // Estado de facturación
                if (order.invoiceStatus != InvoiceStatus.no) ...[
                  const SizedBox(height: 8),
                  _buildInvoiceStatusChip(order.invoiceStatus, theme),
                ],
                // Indicador de sincronización
                if (!order.isSynced) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Icon(
                        FluentIcons.cloud_upload,
                        size: 16,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Pendiente de sincronizar',
                        style: theme.typography.caption?.copyWith(
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInvoiceStatusChip(InvoiceStatus status, FluentThemeData theme) {
    if (status == InvoiceStatus.no) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(status.icon, size: 16, color: status.color),
        const SizedBox(width: 4),
        Text(
          status.label,
          style: theme.typography.caption?.copyWith(color: status.color),
        ),
      ],
    );
  }
}
