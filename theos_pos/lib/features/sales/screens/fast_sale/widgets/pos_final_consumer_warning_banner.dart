part of 'pos_actions_panel.dart';

/// Alerta visual persistente cuando el cliente es "Consumidor Final" y aún
/// no se ha completado el nombre. Antes esto solo se avisaba al fallar la
/// sincronización (ver [POSActionsPanel._handleSyncAll]) — ahora se marca
/// desde el primer momento en que se detecta la condición.
class _FinalConsumerWarningBanner extends StatelessWidget {
  /// Versión compacta (solo ícono con tooltip) para la barra horizontal.
  final bool isCompact;

  const _FinalConsumerWarningBanner({this.isCompact = false});

  static const _message = 'Nombre de consumidor final requerido *';

  @override
  Widget build(BuildContext context) {
    if (isCompact) {
      return Tooltip(
        message: _message,
        child: Icon(FluentIcons.warning, size: 16, color: AppColors.warning),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.xs,
        vertical: Spacing.xxs,
      ),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(FluentIcons.warning, size: 12, color: AppColors.warning),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              _message,
              style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ).copyWith(color: AppColors.warning),
              maxLines: 2,
            ),
          ),
        ],
      ),
    );
  }
}
