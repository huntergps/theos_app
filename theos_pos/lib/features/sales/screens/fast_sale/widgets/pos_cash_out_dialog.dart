part of 'pos_actions_panel.dart';

/// Resultado del diálogo de salida de dinero
class _CashOutResult {
  final bool success;
  final double amount;
  final String? reason;

  _CashOutResult({
    required this.success,
    required this.amount,
    this.reason,
  });
}

/// Diálogo para registrar salida de dinero
class _CashOutDialog extends ConsumerStatefulWidget {
  final int sessionId;

  const _CashOutDialog({required this.sessionId});

  @override
  ConsumerState<_CashOutDialog> createState() => _CashOutDialogState();
}

class _CashOutDialogState extends ConsumerState<_CashOutDialog> {
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _amountController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _saveCashOut() async {
    final amount = double.tryParse(_amountController.text) ?? 0;
    if (amount <= 0) {
      CopyableInfoBar.showError(
        context,
        title: 'Error de validacion',
        message: 'Ingrese un monto válido',
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final cashOutService = ref.read(cashOutServiceProvider);

      // Obtener diarios de efectivo disponibles
      final cashJournals = await cashOutService.getCashJournals();
      if (cashJournals.isEmpty) {
        throw Exception('No hay diarios de efectivo configurados');
      }

      // Usar el primer diario de efectivo
      final cashJournal = cashJournals.firstWhere(
        (j) => j.type == 'cash',
        orElse: () => cashJournals.first,
      );

      // Crear retiro de seguridad (tipo más común)
      final result = await cashOutService.createSecurityWithdrawal(
        amount: amount,
        journalId: cashJournal.id,
        sessionId: widget.sessionId,
        note: _reasonController.text.isEmpty ? null : _reasonController.text,
      );

      if (mounted) {
        Navigator.pop(
          context,
          _CashOutResult(
            success: result.success,
            amount: amount,
            reason: _reasonController.text,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        CopyableInfoBar.showError(
          context,
          title: 'Error de retiro de efectivo',
          message: 'No se pudo registrar la salida de efectivo. Intente nuevamente.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Salida de Dinero'),
      constraints: const BoxConstraints(maxWidth: 400),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InfoLabel(
            label: 'Monto',
            child: TextBox(
              controller: _amountController,
              placeholder: '0.00',
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Text('\$'),
              ),
            ),
          ),
          const SizedBox(height: Spacing.sm),
          InfoLabel(
            label: 'Motivo (opcional)',
            child: TextBox(
              controller: _reasonController,
              placeholder: 'Ej: Pago a proveedor, gastos varios...',
              maxLines: 2,
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: _isLoading ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _isLoading ? null : _saveCashOut,
          child: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: ProgressRing(strokeWidth: 2),
                )
              : const Text('Registrar Salida'),
        ),
      ],
    );
  }
}
