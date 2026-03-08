import 'package:fluent_ui/fluent_ui.dart';

import '../../../../core/theme/spacing.dart';
import '../../../../shared/utils/formatting_utils.dart';

/// Resultado del diálogo de sobrepago
enum OverpaymentAction {
  /// Crear anticipo con el excedente
  createAdvance,
  /// Dar cambio en efectivo
  giveChange,
  /// Cancelar (ajustar monto)
  cancel,
}

/// Diálogo de confirmación de sobrepago
///
/// Se muestra cuando el total de pagos excede el monto a cobrar.
/// Permite al usuario elegir entre:
/// - Crear un anticipo con el excedente
/// - Dar cambio en efectivo
/// - Cancelar y ajustar el monto
class OverpaymentDialog extends StatelessWidget {
  final double orderTotal;
  final double totalPaid;
  final double overpayment;
  final bool hasCashPayment;
  final String? partnerName;

  const OverpaymentDialog({
    super.key,
    required this.orderTotal,
    required this.totalPaid,
    required this.overpayment,
    required this.hasCashPayment,
    this.partnerName,
  });

  /// Muestra el diálogo y retorna la acción seleccionada
  static Future<OverpaymentAction?> show({
    required BuildContext context,
    required double orderTotal,
    required double totalPaid,
    required double overpayment,
    required bool hasCashPayment,
    String? partnerName,
  }) {
    return showDialog<OverpaymentAction>(
      context: context,
      builder: (context) => OverpaymentDialog(
        orderTotal: orderTotal,
        totalPaid: totalPaid,
        overpayment: overpayment,
        hasCashPayment: hasCashPayment,
        partnerName: partnerName,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 450),
      title: Row(
        children: [
          Icon(FluentIcons.warning, color: Colors.orange),
          const SizedBox(width: Spacing.sm),
          const Text('Sobrepago Detectado'),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(Spacing.md),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
            ),
            child: Column(
              children: [
                _buildInfoRow(theme, 'Total a cobrar', orderTotal),
                const SizedBox(height: Spacing.xs),
                _buildInfoRow(theme, 'Total pagado', totalPaid),
                const Divider(),
                _buildInfoRow(
                  theme,
                  'Excedente',
                  overpayment,
                  color: Colors.orange,
                  bold: true,
                ),
              ],
            ),
          ),

          const SizedBox(height: Spacing.md),

          Text(
            '¿Qué desea hacer con el excedente de ${overpayment.toCurrency()}?',
            style: theme.typography.body,
          ),

          const SizedBox(height: Spacing.md),

          // Options
          _buildOptionCard(
            context,
            theme,
            icon: FluentIcons.circle_dollar,
            title: 'Crear Anticipo',
            description: partnerName != null
                ? 'Crear un anticipo de ${overpayment.toCurrency()} para $partnerName'
                : 'Crear un anticipo con el excedente para uso futuro',
            color: Colors.magenta,
            action: OverpaymentAction.createAdvance,
          ),

          if (hasCashPayment) ...[
            const SizedBox(height: Spacing.sm),
            _buildOptionCard(
              context,
              theme,
              icon: FluentIcons.money,
              title: 'Dar Cambio',
              description:
                  'Devolver ${overpayment.toCurrency()} en efectivo al cliente',
              color: Colors.green,
              action: OverpaymentAction.giveChange,
            ),
          ],

          const SizedBox(height: Spacing.sm),
          _buildOptionCard(
            context,
            theme,
            icon: FluentIcons.cancel,
            title: 'Cancelar',
            description: 'Volver atrás y ajustar los montos de pago',
            color: Colors.grey,
            action: OverpaymentAction.cancel,
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    FluentThemeData theme,
    String label,
    double amount, {
    Color? color,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.typography.body),
        Text(
          amount.toCurrency(),
          style: theme.typography.body?.copyWith(
            color: color,
            fontWeight: bold ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }

  Widget _buildOptionCard(
    BuildContext context,
    FluentThemeData theme, {
    required IconData icon,
    required String title,
    required String description,
    required Color color,
    required OverpaymentAction action,
  }) {
    return HoverButton(
      onPressed: () => Navigator.of(context).pop(action),
      builder: (context, states) {
        final isHovered = states.isHovered;

        return Container(
          padding: const EdgeInsets.all(Spacing.sm),
          decoration: BoxDecoration(
            color: isHovered
                ? color.withValues(alpha: 0.1)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isHovered
                  ? color
                  : theme.resources.controlStrokeColorDefault,
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: Spacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: theme.typography.bodyStrong?.copyWith(
                        color: isHovered ? color : null,
                      ),
                    ),
                    Text(
                      description,
                      style: theme.typography.caption?.copyWith(
                        color: theme.inactiveColor,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                FluentIcons.chevron_right,
                size: 14,
                color: isHovered ? color : theme.inactiveColor,
              ),
            ],
          ),
        );
      },
    );
  }
}
