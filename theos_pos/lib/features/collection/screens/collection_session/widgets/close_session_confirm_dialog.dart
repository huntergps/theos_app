import 'package:fluent_ui/fluent_ui.dart';

import '../../../../../shared/utils/formatting_utils.dart';
import '../../../../../shared/widgets/dialogs/confirm_action_dialog.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Diálogo de confirmación para cerrar una sesión de cobranza.
/// 
/// Migrado a usar [ConfirmActionDialog] para mantener consistencia
/// con otros diálogos de confirmación.
class CloseSessionConfirmDialog extends StatelessWidget {
  final CollectionSession session;

  const CloseSessionConfirmDialog({super.key, required this.session});

  /// Muestra el diálogo y retorna true si el usuario confirma.
  static Future<bool> show(BuildContext context, CollectionSession session) async {
    final value = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => CloseSessionConfirmDialog(session: session),
    );
    return value ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final hasDifference = session.cashRegisterDifference != 0;

    return ConfirmActionDialog(
      title: 'Confirmar Cierre',
      message: '¿Está seguro que desea cerrar esta sesión?',
      confirmText: 'Cerrar Sesión',
      icon: FluentIcons.lock,
      iconColor: theme.accentColor,
      isDestructive: hasDifference && session.cashRegisterDifference < 0,
      additionalContent: _SessionBalanceSummary(
        session: session,
        theme: theme,
      ),
    );
  }
}

/// Widget interno para mostrar el resumen de balance de la sesión
class _SessionBalanceSummary extends StatelessWidget {
  final CollectionSession session;
  final FluentThemeData theme;

  const _SessionBalanceSummary({
    required this.session,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    final difference = session.cashRegisterDifference;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildBalanceRow('Saldo Teórico', session.cashRegisterBalanceEnd),
        const SizedBox(height: 8),
        _buildBalanceRow('Saldo Real', session.cashRegisterBalanceEndReal),
        const SizedBox(height: 8),
        _buildDifferenceRow(difference),
        if (difference != 0) ...[
          const SizedBox(height: 16),
          InfoBar(
            title: const Text('Atención'),
            content: Text(
              difference > 0
                  ? 'Hay un sobrante de efectivo.'
                  : 'Hay un faltante de efectivo.',
            ),
            severity: difference > 0
                ? InfoBarSeverity.warning
                : InfoBarSeverity.error,
          ),
        ],
      ],
    );
  }

  Widget _buildBalanceRow(String label, double value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: theme.typography.caption),
        Text(
          value.toCurrency(),
          style: theme.typography.bodyStrong,
        ),
      ],
    );
  }

  Widget _buildDifferenceRow(double difference) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Diferencia', style: theme.typography.caption),
        Text(
          difference.toCurrency(),
          style: theme.typography.bodyStrong?.copyWith(
            color: difference != 0 ? Colors.red : Colors.green,
          ),
        ),
      ],
    );
  }
}
