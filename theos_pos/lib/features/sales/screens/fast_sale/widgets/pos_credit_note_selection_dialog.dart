part of 'pos_actions_panel.dart';

/// Diálogo para seleccionar nota de crédito
class _CreditNoteSelectionDialog extends StatelessWidget {
  final List<AvailableCreditNote> creditNotes;
  final double orderTotal;

  const _CreditNoteSelectionDialog({
    required this.creditNotes,
    required this.orderTotal,
  });

  @override
  Widget build(BuildContext context) {
    return ContentDialog(
      title: const Text('Seleccionar Nota de Crédito'),
      constraints: const BoxConstraints(maxWidth: 500, maxHeight: 400),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Notas de crédito disponibles del cliente:',
            style: FluentTheme.of(context).typography.bodyStrong,
          ),
          const SizedBox(height: Spacing.sm),
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: creditNotes.length,
              itemBuilder: (context, index) {
                final nc = creditNotes[index];
                return ListTile.selectable(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.creditNote.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Icon(
                      FluentIcons.page_list,
                      size: 20,
                      color: AppColors.creditNote,
                    ),
                  ),
                  title: Text(nc.name),
                  subtitle: Text(
                    'Disponible: ${nc.amountResidual.toCurrency()}',
                    style: TextStyle(color: AppColors.success),
                  ),
                  onPressed: () => Navigator.pop(context, nc),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        Button(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}
