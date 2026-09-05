import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show CollectionSession, SessionState, SessionStateExtension;

import '../../../core/adaptive/adaptive_layout_policy.dart';
import '../../../core/constants/app_colors.dart';

import 'package:odoo_sdk/odoo_sdk.dart' show logger;

import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/theme/spacing.dart';
import '../../../shared/utils/formatting_utils.dart';
import '../../../shared/widgets/reactive/reactive_cash_count_field.dart';

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
  static const compactPresentationKey = Key(
    'session-validation-dialog-compact',
  );
  static const modalPresentationKey = Key('session-validation-dialog-modal');
  static const stackedInformationKey = Key(
    'session-validation-information-stacked',
  );
  static const splitInformationKey = Key(
    'session-validation-information-split',
  );
  static const transactionGridKey = Key('session-validation-transaction-grid');
  static const stackedActionsKey = Key('session-validation-actions-stacked');
  static const inlineActionsKey = Key('session-validation-actions-inline');

  final CollectionSession session;
  final AdaptiveInputCapabilities inputCapabilities;

  const SessionValidationDialog({
    super.key,
    required this.session,
    this.inputCapabilities = const AdaptiveInputCapabilities(touch: true),
  });

  /// Muestra el diálogo de validación
  static Future<SessionValidationResult?> show({
    required BuildContext context,
    required CollectionSession session,
    AdaptiveInputCapabilities inputCapabilities =
        const AdaptiveInputCapabilities(touch: true),
  }) {
    return showDialog<SessionValidationResult>(
      context: context,
      builder: (context) => SessionValidationDialog(
        session: session,
        inputCapabilities: inputCapabilities,
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final mediaSize = MediaQuery.sizeOf(context);
        final windowSize = Size(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : mediaSize.width,
          constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : mediaSize.height,
        );
        return _buildDialog(context, windowSize);
      },
    );
  }

  Widget _buildDialog(BuildContext context, Size windowSize) {
    final theme = FluentTheme.of(context);
    final session = widget.session;
    final policy = CashCountLayoutPolicy.fromWidth(
      windowSize.width,
      inputs: widget.inputCapabilities,
    );
    final isCompact = policy.usesFullScreenDialog;

    // Calculate difference
    final difference =
        session.cashRegisterBalanceEndReal - session.cashRegisterBalanceEnd;
    final hasDifference = difference.abs() > 0.01;

    return ContentDialog(
      key: isCompact
          ? SessionValidationDialog.compactPresentationKey
          : SessionValidationDialog.modalPresentationKey,
      constraints: isCompact
          ? BoxConstraints.tightFor(
              width: windowSize.width,
              height: windowSize.height,
            )
          : BoxConstraints(maxWidth: 720, maxHeight: windowSize.height * 0.9),
      title: Row(
        children: [
          Icon(FluentIcons.check_list, color: theme.accentColor),
          const SizedBox(width: Spacing.sm),
          const Expanded(child: Text('Validar Cierre de Sesión')),
        ],
      ),
      content: LayoutBuilder(
        builder: (context, constraints) {
          final availableWidth = constraints.hasBoundedWidth
              ? constraints.maxWidth
              : windowSize.width;
          final contentPolicy = CashCountLayoutPolicy.fromWidth(availableWidth);
          return SingleChildScrollView(
            child: _buildContent(
              theme,
              session,
              difference,
              hasDifference,
              contentPolicy,
            ),
          );
        },
      ),
      actions: _buildActions(policy),
    );
  }

  Widget _buildContent(
    FluentThemeData theme,
    CollectionSession session,
    double difference,
    bool hasDifference,
    CashCountLayoutPolicy policy,
  ) {
    final information = policy.stacksInformation
        ? Column(
            key: SessionValidationDialog.stackedInformationKey,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSessionInfoCard(theme, session),
              const SizedBox(height: Spacing.md),
              _buildCashSummaryCard(theme, session, difference, hasDifference),
            ],
          )
        : Row(
            key: SessionValidationDialog.splitInformationKey,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: _buildSessionInfoCard(theme, session)),
              const SizedBox(width: Spacing.md),
              Expanded(
                child: _buildCashSummaryCard(
                  theme,
                  session,
                  difference,
                  hasDifference,
                ),
              ),
            ],
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        information,
        const SizedBox(height: Spacing.md),
        _buildTransactionsSummary(theme, session),
        const SizedBox(height: Spacing.md),
        InfoLabel(
          label: 'Notas del Supervisor',
          child: TextBox(
            controller: _notesController,
            placeholder: 'Comentarios opcionales sobre el cierre...',
            maxLines: 3,
          ),
        ),
        if (hasDifference) ...[
          const SizedBox(height: Spacing.md),
          _buildDifferenceWarning(theme, difference),
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: Spacing.md),
          Container(
            padding: const EdgeInsets.all(Spacing.sm),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.3),
              ),
            ),
            child: Row(
              children: [
                Icon(FluentIcons.error, size: 16, color: AppColors.danger),
                const SizedBox(width: Spacing.xs),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: theme.typography.body?.copyWith(
                      color: AppColors.danger,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  List<Widget> _buildActions(CashCountLayoutPolicy policy) {
    final cancel = SizedBox(
      height: policy.minimumInteractiveExtent,
      child: Button(
        onPressed: _isValidating ? null : () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
    );
    final validate = SizedBox(
      height: policy.minimumInteractiveExtent,
      child: FilledButton(
        onPressed: _isValidating ? null : _validateSession,
        child: _isValidating
            ? const SizedBox(
                width: 16,
                height: 16,
                child: ProgressRing(strokeWidth: 2),
              )
            : const Text('Validar y Cerrar'),
      ),
    );

    if (policy.stacksActions) {
      return [
        SizedBox(
          key: SessionValidationDialog.stackedActionsKey,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              validate,
              const SizedBox(height: Spacing.sm),
              cancel,
            ],
          ),
        ),
      ];
    }

    return [
      KeyedSubtree(
        key: SessionValidationDialog.inlineActionsKey,
        child: cancel,
      ),
      validate,
    ];
  }

  Widget _buildSessionInfoCard(
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
          LayoutBuilder(
            builder: (context, constraints) {
              final policy = CashCountLayoutPolicy.fromWidth(
                constraints.maxWidth,
              );
              const spacing = Spacing.sm;
              final columns = policy.transactionColumns;
              final itemWidth =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;

              return Wrap(
                key: SessionValidationDialog.transactionGridKey,
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  SizedBox(
                    width: itemWidth,
                    child: _buildCountItem(
                      theme,
                      'Órdenes',
                      session.orderCount,
                      Colors.blue,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildCountItem(
                      theme,
                      'Cobros',
                      session.paymentCount,
                      Colors.green,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildCountItem(
                      theme,
                      'Anticipos',
                      session.advanceCount,
                      Colors.magenta,
                    ),
                  ),
                  SizedBox(
                    width: itemWidth,
                    child: _buildCountItem(
                      theme,
                      'Cheques',
                      session.chequeRecibidoCount,
                      Colors.orange,
                    ),
                  ),
                ],
              );
            },
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final policy = CashCountLayoutPolicy.fromWidth(constraints.maxWidth);
        final valueText = Text(
          value,
          textAlign: policy.stacksInformation
              ? TextAlign.left
              : TextAlign.right,
          style: theme.typography.body?.copyWith(
            color: valueColor,
            fontWeight: bold ? FontWeight.bold : null,
          ),
        );

        if (policy.stacksInformation) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: theme.typography.body),
              const SizedBox(height: 2),
              valueText,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: Text(label, style: theme.typography.body)),
            const SizedBox(width: Spacing.sm),
            Flexible(child: valueText),
          ],
        );
      },
    );
  }

  Color _getStateColor(SessionState state) {
    switch (state) {
      case SessionState.openingControl:
        return AppColors.textSecondary;
      case SessionState.opened:
        return AppColors.success;
      case SessionState.paused:
        return Colors.orange;
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
      final repository = ref.read(collectionRepositoryProvider);
      if (repository == null) {
        throw StateError('Repositorio de sesiones no disponible');
      }
      await repository.validateSession(
        widget.session.id,
        supervisorNotes: _notesController.text,
      );

      logger.i(
        '[SessionValidation]',
        'Session ${widget.session.name} validated successfully',
      );

      if (mounted) {
        Navigator.of(context).pop(
          SessionValidationResult(
            success: true,
            message: 'Sesión cerrada correctamente',
          ),
        );
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
