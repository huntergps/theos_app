import 'package:fluent_ui/fluent_ui.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show CollectionSessionCash, SessionState, CashType;

import '../../../shared/widgets/dialogs/base_form_dialog.dart';
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
  final String title;
  final int? sessionId;
  final SessionState sessionState;
  final CashType cashType;
  final String? description;
  final CollectionSessionCash? initialCash;

  const CashCountDialog({
    super.key,
    required this.title,
    this.sessionId,
    required this.sessionState,
    required this.cashType,
    this.description,
    this.initialCash,
  });

  @override
  FormDialogConfig get config => FormDialogConfig(
    title: title,
    icon: cashType == CashType.opening ? FluentIcons.unlock : FluentIcons.lock,
    description: description,
    maxWidth: 550,
    primaryButtonText: 'Confirmar',
  );

  @override
  StatefulFormDialogState<CollectionSessionCash, CashCountDialog> createState() =>
      _CashCountDialogState();
}

class _CashCountDialogState
    extends StatefulFormDialogState<CollectionSessionCash, CashCountDialog> {
  late CashCountState _cashCountState;

  @override
  void initState() {
    super.initState();
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
  FormDialogConfig get currentConfig => widget.config.copyWith(
    isPrimaryEnabled: _isConfirmEnabled,
  );

  @override
  Widget buildForm(BuildContext context) {
    return SizedBox(
      width: 500,
      child: ReactiveCashCountField(
        config: ReactiveFieldConfig(
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
        onChanged: (newState) {
          setState(() {
            _cashCountState = newState;
          });
        },
      ),
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
