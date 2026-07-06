import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show CollectionSession, SessionState, SessionStateExtension;

import '../../../core/constants/app_colors.dart';
import '../../../core/services/logger_service.dart';
import '../../../core/services/odoo_service.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/utils/formatting_utils.dart';

/// Resultado de la validación de sesión
class SessionValidationResult {
  final bool success;
  final String? message;

  SessionValidationResult({required this.success, this.message});
}

/// Diálogo de validación de supervisor para cierre de sesión
///
/// Replica la funcionalidad de `collection.session.validation.wizard` de Odoo
/// Permite al supervisor:
/// - Revisar el resumen de la sesión
/// - Agregar notas
/// - Validar el cierre
class SessionValidationDialog extends ConsumerStatefulWidget {
  final CollectionSession session;

  const SessionValidationDialog({super.key, required this.session});

  /// Muestra el diálogo de validación
  static Future<SessionValidationResult?> show({
    required BuildContext context,
    required CollectionSession session,
  }) {
    return showDialog<SessionValidationResult>(
      context: context,
      builder: (context) => SessionValidationDialog(session: session),
    );
  }

  @override
  ConsumerState<SessionValidationDialog> createState() =>
      _SessionValidationDialogState();
}

class _SessionValidationDialogState
    extends ConsumerState<SessionValidationDialog> {
  final _notesController = TextEditingController();
  bool _isValidating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final session = widget.session;

    // Calculate difference
    final difference = session.cashRegisterBalanceEndReal -
        session.cashRegisterBalanceEnd;
    final hasDifference = difference.abs() > 0.01;

    return ContentDialog(
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 700),
      title: Row(
        children: [
          Icon(FluentIcons.check_list, color: theme.accentColor),
          const SizedBox(width: Spacing.sm),
          const Text('Validar Cierre de Sesión'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Session info
            _buildSessionInfoCard(theme, session),
            const SizedBox(height: Spacing.md),

            // Cash summary
            _buildCashSummaryCard(theme, session, difference, hasDifference),
            const SizedBox(height: Spacing.md),

            // Transactions summary
            _buildTransactionsSummary(theme, session),
            const SizedBox(height: Spacing.md),

            // Supervisor notes
            InfoLabel(
              label: 'Notas del Supervisor',
              child: TextBox(
                controller: _notesController,
                placeholder: 'Comentarios opcionales sobre el cierre...',
                maxLines: 3,
              ),
            ),

            // Warning for difference
            if (hasDifference) ...[
              const SizedBox(height: Spacing.md),
              _buildDifferenceWarning(theme, difference),
            ],

            // Error message
            if (_errorMessage != null) ...[
              const SizedBox(height: Spacing.md),
              Container(
                padding: const EdgeInsets.all(Spacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(FluentIcons.error, size: 16, color: AppColors.danger),
                    const SizedBox(width: Spacing.xs),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: theme.typography.body?.copyWith(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        Button(
          onPressed: _isValidating ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isValidating ? null : _validateSession,
          child: _isValidating
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Validar y Cerrar'),
        ),
      ],
    );
  }

  Widget _buildSessionInfoCard(FluentThemeData theme, CollectionSession session) {
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
      ),
      child: Column(
        children: [
          _buildInfoRow(theme, 'Sesión', session.name),
          const SizedBox(height: Spacing.xs),
          _buildInfoRow(theme, 'Cajero', session.userName ?? 'N/A'),
          const SizedBox(height: Spacing.xs),
          _buildInfoRow(
            theme,
            'Estado',
            session.state.label,
            valueColor: _getStateColor(session.state),
          ),
        ],
      ),
    );
  }

  Widget _buildCashSummaryCard(
    FluentThemeData theme,
    CollectionSession session,
    double difference,
    bool hasDifference,
  ) {
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: hasDifference
            ? AppColors.warning.withValues(alpha: 0.1)
            : AppColors.success.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasDifference
              ? AppColors.warning.withValues(alpha: 0.3)
              : AppColors.success.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                FluentIcons.money,
                size: 16,
                color: hasDifference ? AppColors.warning : AppColors.success,
              ),
              const SizedBox(width: Spacing.xs),
              Text(
                'Resumen de Efectivo',
                style: theme.typography.bodyStrong?.copyWith(
                  color: hasDifference ? AppColors.warning : AppColors.success,
                ),
              ),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          _buildInfoRow(
            theme,
            'Saldo Inicial',
            session.cashRegisterBalanceStart.toCurrency(),
          ),
          const SizedBox(height: Spacing.xs),
          _buildInfoRow(
            theme,
            'Saldo Final Teórico',
            session.cashRegisterBalanceEnd.toCurrency(),
          ),
          const SizedBox(height: Spacing.xs),
          _buildInfoRow(
            theme,
            'Saldo Final Real',
            session.cashRegisterBalanceEndReal.toCurrency(),
          ),
          if (hasDifference) ...[
            const Divider(),
            _buildInfoRow(
              theme,
              'Diferencia',
              difference.toCurrency(),
              valueColor: AppColors.warning,
              bold: true,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTransactionsSummary(
    FluentThemeData theme,
    CollectionSession session,
  ) {
    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: theme.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: theme.resources.controlStrokeColorDefault),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(FluentIcons.list, size: 16, color: theme.accentColor),
              const SizedBox(width: Spacing.xs),
              Text('Transacciones', style: theme.typography.bodyStrong),
            ],
          ),
          const SizedBox(height: Spacing.sm),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildCountItem(theme, 'Órdenes', session.orderCount, Colors.blue),
              _buildCountItem(
                  theme, 'Cobros', session.paymentCount, Colors.green),
              _buildCountItem(
                  theme, 'Anticipos', session.advanceCount, Colors.magenta),
              _buildCountItem(
                  theme, 'Cheques', session.chequeRecibidoCount, Colors.orange),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCountItem(
    FluentThemeData theme,
    String label,
    int count,
    Color color,
  ) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: theme.typography.subtitle?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          label,
          style: theme.typography.caption?.copyWith(color: theme.inactiveColor),
        ),
      ],
    );
  }

  Widget _buildDifferenceWarning(FluentThemeData theme, double difference) {
    final isPositive = difference > 0;

    return Container(
      padding: const EdgeInsets.all(Spacing.sm),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.3)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(FluentIcons.warning, size: 20, color: AppColors.warning),
          const SizedBox(width: Spacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isPositive ? 'Sobrante de efectivo' : 'Faltante de efectivo',
                  style: theme.typography.bodyStrong?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
                Text(
                  isPositive
                      ? 'El efectivo contado es mayor al esperado. Se creará un asiento de ajuste.'
                      : 'El efectivo contado es menor al esperado. Se creará un asiento de ajuste.',
                  style: theme.typography.caption?.copyWith(
                    color: AppColors.warning,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(
    FluentThemeData theme,
    String label,
    String value, {
    Color? valueColor,
    bool bold = false,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: theme.typography.body),
        Text(
          value,
          style: theme.typography.body?.copyWith(
            color: valueColor,
            fontWeight: bold ? FontWeight.bold : null,
          ),
        ),
      ],
    );
  }

  Color _getStateColor(SessionState state) {
    switch (state) {
      case SessionState.openingControl:
        return AppColors.textSecondary;
      case SessionState.opened:
        return AppColors.success;
      case SessionState.closingControl:
        return AppColors.warning;
      case SessionState.closed:
        return Colors.blue;
    }
  }

  Future<void> _validateSession() async {
    setState(() {
      _isValidating = true;
      _errorMessage = null;
    });

    try {
      final odoo = ref.read(odooServiceProvider);

      // action_session_validate(self) no acepta parametros (ver
      // l10n_ec_collection_box/models/collection_session.py) — las notas del
      // supervisor son un campo normal del modelo (supervisor_notes), asi
      // que se guardan con write() ANTES de validar. Antes esto se enviaba
      // como args:[id] + kwargs:{supervisor_notes:...}, lo cual siempre
      // fallaba con HTTP 422 porque el dispatcher JSON-2 no trata "args"
      // como posicionales (ver OdooClient.call).
      if (_notesController.text.isNotEmpty) {
        await odoo.call(
          model: 'collection.session',
          method: 'write',
          kwargs: {
            'ids': [widget.session.id],
            'vals': {'supervisor_notes': _notesController.text},
          },
        );
      }

      // Call Odoo to validate and close session (metodo de recordset: usa ids)
      await odoo.call(
        model: 'collection.session',
        method: 'action_session_validate',
        ids: [widget.session.id],
      );

      logger.i('[SessionValidation]',
          'Session ${widget.session.name} validated successfully');

      if (mounted) {
        Navigator.of(context).pop(SessionValidationResult(
          success: true,
          message: 'Sesión cerrada correctamente',
        ));
      }
    } catch (e) {
      logger.e('[SessionValidation]', 'Error validating session', e);
      setState(() {
        _errorMessage = 'Error al validar sesión: $e';
        _isValidating = false;
      });
    }
  }
}
