import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show Advance, AdvanceState, AdvanceLine;

import '../../../core/services/logger_service.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/utils/formatting_utils.dart';
import '../../../shared/widgets/dialogs/copyable_info_bar.dart';
import '../providers/advance_providers.dart';

/// Provider para detalle de un anticipo
final advanceDetailProvider = FutureProvider.family<Advance?, int>((
  ref,
  advanceId,
) async {
  final advanceService = ref.watch(advanceServiceProvider);
  return advanceService.getAdvance(advanceId);
});

/// Diálogo de detalle de anticipo
///
/// Muestra información completa del anticipo:
/// - Datos generales (número, fecha, estado)
/// - Información del cliente
/// - Montos (total, usado, disponible)
/// - Líneas de pago utilizadas
/// - Historial de uso (si aplica)
/// - Botones de acción según estado
class AdvanceDetailDialog extends ConsumerWidget {
  final int advanceId;

  const AdvanceDetailDialog({super.key, required this.advanceId});

  /// Muestra el diálogo
  static Future<void> show({
    required BuildContext context,
    required int advanceId,
  }) {
    return showDialog(
      context: context,
      builder: (context) => AdvanceDetailDialog(advanceId: advanceId),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = FluentTheme.of(context);
    final advanceAsync = ref.watch(advanceDetailProvider(advanceId));

    return ContentDialog(
      title: Row(
        children: [
          const Icon(FluentIcons.money, size: 24),
          const SizedBox(width: Spacing.sm),
          const Expanded(child: Text('Detalle de Anticipo')),
          IconButton(
            icon: const Icon(FluentIcons.refresh, size: 16),
            onPressed: () => ref.invalidate(advanceDetailProvider(advanceId)),
          ),
        ],
      ),
      constraints: const BoxConstraints(maxWidth: 600, maxHeight: 700),
      content: advanceAsync.when(
        loading: () => const Center(child: ProgressRing()),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(FluentIcons.error, size: 48, color: Colors.red),
              const SizedBox(height: Spacing.sm),
              Text('Error cargando anticipo: $e'),
            ],
          ),
        ),
        data: (advance) {
          if (advance == null) {
            return const Center(child: Text('Anticipo no encontrado'));
          }
          return _buildContent(context, theme, advance, ref);
        },
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cerrar'),
        ),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    FluentThemeData theme,
    Advance advance,
    WidgetRef ref,
  ) {
    final dateFormat = DateFormat('dd/MM/yyyy');
    final stateColor = _getStateColor(advance.state);

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header con estado y nombre
          _buildHeaderCard(theme, advance, stateColor, dateFormat),
          const SizedBox(height: Spacing.md),

          // Montos
          _buildAmountsCard(theme, advance),
          const SizedBox(height: Spacing.md),

          // Información del cliente
          _buildCustomerCard(theme, advance),
          const SizedBox(height: Spacing.md),

          // Referencia/Glosa
          _buildReferenceCard(theme, advance),
          const SizedBox(height: Spacing.md),

          // Líneas de pago (si tiene)
          if (advance.lines.isNotEmpty) ...[
            _buildPaymentLinesCard(theme, advance),
            const SizedBox(height: Spacing.md),
          ],

          // Fechas importantes
          _buildDatesCard(theme, advance, dateFormat),
          const SizedBox(height: Spacing.md),

          // Alertas y advertencias
          if (advance.isExpired ||
              (advance.daysToExpire != null && advance.daysToExpire! <= 7))
            _buildWarningsCard(theme, advance),

          // Acciones según estado
          if (advance.state == AdvanceState.posted ||
              advance.state == AdvanceState.inUse)
            _buildActionsCard(context, theme, advance, ref),
        ],
      ),
    );
  }

  Widget _buildHeaderCard(
    FluentThemeData theme,
    Advance advance,
    Color stateColor,
    DateFormat dateFormat,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            // Icono de estado
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: stateColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                _getStateIcon(advance.state),
                size: 28,
                color: stateColor,
              ),
            ),
            const SizedBox(width: Spacing.md),

            // Nombre y estado
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    advance.name ?? 'Sin número',
                    style: theme.typography.subtitle?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: Spacing.sm,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: stateColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: stateColor.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          advance.state.label.toUpperCase(),
                          style: theme.typography.caption?.copyWith(
                            color: stateColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: Spacing.sm),
                      Text(
                        advance.advanceType.label,
                        style: theme.typography.caption?.copyWith(
                          color: theme.inactiveColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmountsCard(FluentThemeData theme, Advance advance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Montos', style: theme.typography.bodyStrong),
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                Expanded(
                  child: _buildAmountTile(
                    theme,
                    'Total',
                    advance.amount,
                    theme.accentColor,
                    FluentIcons.money,
                  ),
                ),
                Expanded(
                  child: _buildAmountTile(
                    theme,
                    'Disponible',
                    advance.amountAvailable,
                    Colors.green,
                    FluentIcons.check_mark,
                  ),
                ),
              ],
            ),
            const SizedBox(height: Spacing.sm),
            Row(
              children: [
                Expanded(
                  child: _buildAmountTile(
                    theme,
                    'Usado',
                    advance.amountUsed,
                    Colors.blue,
                    FluentIcons.completed,
                  ),
                ),
                Expanded(
                  child: _buildAmountTile(
                    theme,
                    'Devuelto',
                    advance.amountReturned,
                    Colors.orange,
                    FluentIcons.undo,
                  ),
                ),
              ],
            ),

            // Barra de progreso
            if (advance.amount > 0) ...[
              const SizedBox(height: Spacing.md),
              Row(
                children: [
                  Text(
                    'Uso: ${advance.usagePercentage.toPercent()}',
                    style: theme.typography.caption,
                  ),
                  const SizedBox(width: Spacing.sm),
                  Expanded(child: ProgressBar(value: advance.usagePercentage)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAmountTile(
    FluentThemeData theme,
    String label,
    double amount,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.typography.caption?.copyWith(color: color),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            amount.toCurrency(),
            style: theme.typography.bodyStrong?.copyWith(
              color: color,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(FluentThemeData theme, Advance advance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: theme.accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(FluentIcons.contact, color: theme.accentColor),
            ),
            const SizedBox(width: Spacing.sm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Cliente',
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ),
                  Text(
                    advance.partnerName ?? 'Sin nombre',
                    style: theme.typography.bodyStrong,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildReferenceCard(FluentThemeData theme, Advance advance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Referencia / Glosa', style: theme.typography.bodyStrong),
            const SizedBox(height: Spacing.xs),
            Text(
              advance.reference.isNotEmpty
                  ? advance.reference
                  : 'Sin referencia',
              style: theme.typography.body?.copyWith(
                color: advance.reference.isEmpty ? theme.inactiveColor : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentLinesCard(FluentThemeData theme, Advance advance) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Formas de Pago Recibidas',
              style: theme.typography.bodyStrong,
            ),
            const SizedBox(height: Spacing.sm),
            ...advance.lines.map((line) => _buildPaymentLine(theme, line)),
          ],
        ),
      ),
    );
  }

  Widget _buildPaymentLine(FluentThemeData theme, AdvanceLine line) {
    IconData icon;
    String details = '';

    if (line.isCash) {
      icon = FluentIcons.money;
    } else if (line.isCard) {
      icon = FluentIcons.payment_card;
      if (line.cardBrandName != null) {
        details = line.cardBrandName!;
        if (line.cardDeadlineName != null) {
          details += ' - ${line.cardDeadlineName}';
        }
      }
    } else if (line.isCheck) {
      icon = FluentIcons.page;
      if (line.documentNumber != null) {
        details = 'Cheque #${line.documentNumber}';
      }
    } else {
      icon = FluentIcons.bank;
      if (line.documentNumber != null) {
        details = 'Ref: ${line.documentNumber}';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.xs),
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.accentColor),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  line.journalName ?? 'Desconocido',
                  style: theme.typography.body,
                ),
                if (details.isNotEmpty)
                  Text(
                    details,
                    style: theme.typography.caption?.copyWith(
                      color: theme.inactiveColor,
                    ),
                  ),
              ],
            ),
          ),
          Text(
            line.amount.toCurrency(),
            style: theme.typography.bodyStrong?.copyWith(
              color: theme.accentColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDatesCard(
    FluentThemeData theme,
    Advance advance,
    DateFormat dateFormat,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Fechas', style: theme.typography.bodyStrong),
            const SizedBox(height: Spacing.sm),
            _buildDateRow(
              theme,
              'Fecha de Registro',
              dateFormat.format(advance.date),
              FluentIcons.calendar,
            ),
            _buildDateRow(
              theme,
              'Fecha Estimada de Uso',
              dateFormat.format(advance.dateEstimated),
              FluentIcons.date_time,
            ),
            if (advance.dateDue != null)
              _buildDateRow(
                theme,
                'Fecha de Vencimiento',
                dateFormat.format(advance.dateDue!),
                FluentIcons.clock,
                color: advance.isExpired ? Colors.red : null,
              ),
            if (advance.daysToExpire != null)
              _buildDateRow(
                theme,
                'Días para Vencer',
                '${advance.daysToExpire} días',
                FluentIcons.timer,
                color: advance.daysToExpire! <= 7 ? Colors.orange : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateRow(
    FluentThemeData theme,
    String label,
    String value,
    IconData icon, {
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? theme.inactiveColor),
          const SizedBox(width: Spacing.sm),
          Text(
            label,
            style: theme.typography.caption?.copyWith(
              color: theme.inactiveColor,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: theme.typography.body?.copyWith(
              color: color,
              fontWeight: color != null ? FontWeight.bold : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningsCard(FluentThemeData theme, Advance advance) {
    final isExpired = advance.isExpired;
    final color = isExpired ? Colors.red : Colors.orange;
    final icon = isExpired ? FluentIcons.error_badge : FluentIcons.warning;
    final message = isExpired
        ? 'Este anticipo ha vencido. Considere devolverlo al cliente.'
        : 'Este anticipo vence pronto (${advance.daysToExpire} días restantes).';

    return Container(
      margin: const EdgeInsets.only(bottom: Spacing.md),
      padding: const EdgeInsets.all(Spacing.md),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Text(
              message,
              style: theme.typography.body?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionsCard(
    BuildContext context,
    FluentThemeData theme,
    Advance advance,
    WidgetRef ref,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Acciones', style: theme.typography.bodyStrong),
            const SizedBox(height: Spacing.sm),
            Wrap(
              spacing: Spacing.sm,
              runSpacing: Spacing.sm,
              children: [
                if (advance.amountAvailable > 0)
                  Button(
                    onPressed: () => _markAsUsed(context, advance, ref),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.completed, size: 14),
                        SizedBox(width: 4),
                        Text('Marcar como Usado'),
                      ],
                    ),
                  ),
                if (advance.amountAvailable > 0)
                  Button(
                    onPressed: () => _returnAdvance(context, advance, ref),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(FluentIcons.undo, size: 14),
                        SizedBox(width: 4),
                        Text('Devolver Saldo'),
                      ],
                    ),
                  ),
                Button(
                  onPressed: () => _cancelAdvance(context, advance, ref),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(FluentIcons.cancel, size: 14, color: Colors.red),
                      const SizedBox(width: 4),
                      Text('Cancelar', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _markAsUsed(
    BuildContext context,
    Advance advance,
    WidgetRef ref,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Marcar como Usado'),
        content: Text(
          '¿Está seguro de marcar el anticipo ${advance.name} como totalmente usado?\n\n'
          'Saldo disponible: ${advance.amountAvailable.toCurrency()}',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      // TODO: Implementar llamada a Odoo action_mark_as_used
      logger.i('[AdvanceDetail]', 'Mark as used: ${advance.id}');
      ref.invalidate(advanceDetailProvider(advanceId));
    }
  }

  Future<void> _returnAdvance(
    BuildContext context,
    Advance advance,
    WidgetRef ref,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Devolver Saldo de Anticipo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Se devolverá el saldo disponible del anticipo ${advance.name} al cliente.',
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Monto total:'),
                      Text(
                        advance.amount.toCurrency(),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Monto a devolver:'),
                      Text(
                        advance.amountAvailable.toCurrency(),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: Spacing.md),
            Text(
              'Esta acción generará el asiento contable de devolución.',
              style: TextStyle(
                color: FluentTheme.of(context).inactiveColor,
                fontSize: 12,
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
            child: const Text('Confirmar Devolución'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final advanceService = ref.read(advanceServiceProvider);
        final success = await advanceService.returnAdvance(advance.id);

        if (success && context.mounted) {
          CopyableInfoBar.showSuccess(
            context,
            title: 'Anticipo devuelto',
            message:
                'Se devolvió ${advance.amountAvailable.toCurrency()} del anticipo ${advance.name} al cliente.',
          );
          ref.invalidate(advanceDetailProvider(advanceId));
        }
      } catch (e) {
        if (context.mounted) {
          CopyableInfoBar.showError(
            context,
            title: 'Error al devolver anticipo',
            message: 'No se pudo devolver el anticipo: $e',
          );
        }
      }
    }
  }

  Future<void> _cancelAdvance(
    BuildContext context,
    Advance advance,
    WidgetRef ref,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => ContentDialog(
        title: const Text('Cancelar Anticipo'),
        content: Text(
          '¿Está seguro de cancelar el anticipo ${advance.name}?\n\n'
          'Esta acción no se puede deshacer.',
        ),
        actions: [
          Button(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          FilledButton(
            style: ButtonStyle(
              backgroundColor: WidgetStatePropertyAll(Colors.red),
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final advanceService = ref.read(advanceServiceProvider);
        final success = await advanceService.cancelAdvance(advance.id);

        if (success && context.mounted) {
          CopyableInfoBar.showSuccess(
            context,
            title: 'Anticipo cancelado',
            message: 'El anticipo ${advance.name} ha sido cancelado.',
          );
          ref.invalidate(advanceDetailProvider(advanceId));
        }
      } catch (e) {
        if (context.mounted) {
          CopyableInfoBar.showError(
            context,
            title: 'Error al cancelar anticipo',
            message: 'No se pudo cancelar el anticipo. Intente nuevamente.',
          );
        }
      }
    }
  }

  Color _getStateColor(AdvanceState state) {
    switch (state) {
      case AdvanceState.draft:
        return Colors.grey;
      case AdvanceState.posted:
        return Colors.green;
      case AdvanceState.inUse:
        return Colors.blue;
      case AdvanceState.used:
        return Colors.teal;
      case AdvanceState.expired:
        return Colors.orange;
      case AdvanceState.canceled:
        return Colors.red;
      case AdvanceState.rejected:
        return Colors.red.darker;
    }
  }

  IconData _getStateIcon(AdvanceState state) {
    switch (state) {
      case AdvanceState.draft:
        return FluentIcons.edit;
      case AdvanceState.posted:
        return FluentIcons.check_mark;
      case AdvanceState.inUse:
        return FluentIcons.sync;
      case AdvanceState.used:
        return FluentIcons.completed;
      case AdvanceState.expired:
        return FluentIcons.warning;
      case AdvanceState.canceled:
        return FluentIcons.cancel;
      case AdvanceState.rejected:
        return FluentIcons.blocked;
    }
  }
}
