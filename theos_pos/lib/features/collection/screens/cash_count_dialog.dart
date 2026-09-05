import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show CollectionSessionCash, SessionState, CashType;

import '../../../core/adaptive/adaptive_layout_policy.dart';
import '../../../shared/widgets/dialogs/base_form_dialog.dart';
import '../../../shared/widgets/common/theos_info_bars.dart';
import '../../../shared/widgets/reactive/reactive_cash_count_field.dart';
import '../../../shared/widgets/reactive/reactive_field_base.dart';

// =============================================================================
// CASH COUNT DIALOG - Migrado a StatefulFormDialog
// =============================================================================

/// Diálogo para conteo de efectivo (apertura/cierre de sesión)
///
/// Usa [StatefulFormDialog] como base para mantener consistencia
/// con otros diálogos de formulario.
class CashCountDialog extends StatefulFormDialog<CollectionSessionCash> {
  static const compactPresentationKey = Key('cash-count-dialog-compact');
  static const modalPresentationKey = Key('cash-count-dialog-modal');
  static const stackedActionsKey = Key('cash-count-actions-stacked');
  static const inlineActionsKey = Key('cash-count-actions-inline');

  final String title;
  final int? sessionId;
  final SessionState sessionState;
  final CashType cashType;
  final String? description;
  final CollectionSessionCash? initialCash;
  final AdaptiveInputCapabilities inputCapabilities;

  const CashCountDialog({
    super.key,
    required this.title,
    this.sessionId,
    required this.sessionState,
    required this.cashType,
    this.description,
    this.initialCash,
    this.inputCapabilities = const AdaptiveInputCapabilities(touch: true),
  });

  @override
  FormDialogConfig get config => FormDialogConfig(
    title: title,
    icon: cashType == CashType.opening ? FluentIcons.unlock : FluentIcons.lock,
    description: description,
    maxWidth: 720,
    primaryButtonText: 'Confirmar',
  );

  @override
  StatefulFormDialogState<CollectionSessionCash, CashCountDialog>
  createState() => _CashCountDialogState();
}

class _CashCountDialogState
    extends StatefulFormDialogState<CollectionSessionCash, CashCountDialog> {
  late CashCountState _cashCountState;

  @override
  void initState() {
    super.initState();
    // Mover el foco al primer campo interactivo al abrir el diálogo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        FocusScope.of(context).nextFocus();
      }
    });
    final initial = widget.initialCash;
    _cashCountState = CashCountState.fromCashModel(
      bills100: initial?.bills100 ?? 0,
      bills50: initial?.bills50 ?? 0,
      bills20: initial?.bills20 ?? 0,
      bills10: initial?.bills10 ?? 0,
      bills5: initial?.bills5 ?? 0,
      bills1: initial?.bills1 ?? 0,
      coins1: initial?.coins1 ?? 0,
      coins50Cent: initial?.coins50 ?? 0,
      coins25Cent: initial?.coins25 ?? 0,
      coins10Cent: initial?.coins10 ?? 0,
      coins5Cent: initial?.coins5 ?? 0,
      coins1Cent: initial?.coins1Cent ?? 0,
    );
  }

  bool get _isConfirmEnabled {
    if (widget.sessionId == null) return true;

    if (widget.cashType == CashType.opening) {
      return widget.sessionState != SessionState.closed;
    } else {
      return widget.sessionState == SessionState.opened ||
          widget.sessionState == SessionState.closingControl;
    }
  }

  @override
  FormDialogConfig get currentConfig =>
      widget.config.copyWith(isPrimaryEnabled: _isConfirmEnabled);

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
    final config = currentConfig;
    final policy = CashCountLayoutPolicy.fromWidth(
      windowSize.width,
      inputs: widget.inputCapabilities,
    );
    final isCompact = policy.usesFullScreenDialog;

    return ContentDialog(
      key: isCompact
          ? CashCountDialog.compactPresentationKey
          : CashCountDialog.modalPresentationKey,
      constraints: isCompact
          ? BoxConstraints.tightFor(
              width: windowSize.width,
              height: windowSize.height,
            )
          : BoxConstraints(
              maxWidth: config.maxWidth,
              maxHeight: windowSize.height * 0.9,
            ),
      title: Row(
        children: [
          if (config.icon != null) ...[
            Icon(config.icon, color: config.iconColor ?? theme.accentColor),
            const SizedBox(width: 10),
          ],
          Expanded(child: Text(config.title)),
        ],
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (config.description != null) ...[
            _buildDescription(theme, config.description!),
            const SizedBox(height: 16),
          ],
          if (validationErrors.isNotEmpty) ...[
            TheosInfoBars.validation(
              errors: validationErrors,
              onClose: () => setState(validationErrors.clear),
            ),
            const SizedBox(height: 16),
          ],
          Flexible(
            child: SingleChildScrollView(
              padding: config.contentPadding,
              child: buildForm(context),
            ),
          ),
        ],
      ),
      actions: _buildAdaptiveActions(policy, config),
    );
  }

  Widget _buildDescription(FluentThemeData theme, String description) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: theme.inactiveColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        children: [
          Icon(FluentIcons.info, size: 16, color: theme.inactiveColor),
          const SizedBox(width: 8),
          Expanded(child: Text(description, style: theme.typography.body)),
        ],
      ),
    );
  }

  List<Widget> _buildAdaptiveActions(
    CashCountLayoutPolicy policy,
    FormDialogConfig config,
  ) {
    final cancel = SizedBox(
      height: policy.minimumInteractiveExtent,
      child: Button(
        onPressed: isLoading ? null : handleCancel,
        child: Text(config.cancelButtonText),
      ),
    );
    final confirm = SizedBox(
      height: policy.minimumInteractiveExtent,
      child: FilledButton(
        onPressed: (isLoading || !config.isPrimaryEnabled)
            ? null
            : handleSubmit,
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: ProgressRing(strokeWidth: 2),
              )
            : Text(config.primaryButtonText),
      ),
    );

    if (policy.stacksActions) {
      return [
        SizedBox(
          key: CashCountDialog.stackedActionsKey,
          width: double.infinity,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [confirm, const SizedBox(height: 8), cancel],
          ),
        ),
      ];
    }

    return [
      KeyedSubtree(key: CashCountDialog.inlineActionsKey, child: cancel),
      confirm,
    ];
  }

  @override
  Widget buildForm(BuildContext context) {
    return ReactiveCashCountField(
      config: OdooFieldConfig(
        label: 'Conteo de Efectivo',
        isEditing: true,
        isEnabled: _isConfirmEnabled,
        prefixIcon: FluentIcons.money,
      ),
      value: _cashCountState,
      showBills: true,
      showCoins: true,
      showTotals: true,
      showSteppers: true,
      inputCapabilities: widget.inputCapabilities,
      onChanged: (newState) {
        setState(() {
          _cashCountState = newState;
        });
      },
    );
  }

  @override
  Future<CollectionSessionCash?> onSubmit() async {
    // Extraer los conteos del estado
    final counts = _cashCountState.counts;

    return CollectionSessionCash(
      collectionSessionId: widget.sessionId ?? 0,
      cashType: widget.cashType,
      bills100: counts[100.0] ?? 0,
      bills50: counts[50.0] ?? 0,
      bills20: counts[20.0] ?? 0,
      bills10: counts[10.0] ?? 0,
      bills5: counts[5.0] ?? 0,
      bills1: _getBills1Count(),
      coins1: _getCoins1Count(),
      coins50: counts[0.50] ?? 0,
      coins25: counts[0.25] ?? 0,
      coins10: counts[0.10] ?? 0,
      coins5: counts[0.05] ?? 0,
      coins1Cent: counts[0.01] ?? 0,
    );
  }

  // El modelo tiene bills1 y coins1 separados, pero el widget los combina
  // Por simplicidad, asumimos que $1 en billetes es el valor de 1.0
  int _getBills1Count() {
    // Si el valor total de $1 es mayor que las monedas, hay billetes
    return _cashCountState.counts[1.0] ?? 0;
  }

  int _getCoins1Count() {
    // Para este caso simplificado, no separamos monedas de $1 de billetes de $1
    // En una implementación más completa, se podría agregar una denominación separada
    return 0;
  }
}
