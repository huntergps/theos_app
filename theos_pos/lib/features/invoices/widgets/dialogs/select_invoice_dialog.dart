import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/repositories/repository_providers.dart';
import '../../../../shared/utils/formatting_utils.dart';
import '../../../../shared/widgets/dialogs/base_search_dialog.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Dialog for searching and selecting an invoice
///
/// Uses [BaseSearchDialog] for search functionality.
/// Searches by invoice number (name) or partner name.
///
/// Returns the selected [AccountMove] or null if cancelled.
///
/// Usage:
/// ```dart
/// final invoice = await showSelectInvoiceDialog(
///   context,
///   initialQuery: 'FAC-001',
/// );
/// if (invoice != null) {
///   // Handle selected invoice
/// }
/// ```
class SelectInvoiceDialog extends BaseSearchDialog<AccountMove> {
  /// Initial search query (optional)
  /// If provided, the dialog will search immediately and select all text
  final String? initialQuery;

  const SelectInvoiceDialog({
    super.key,
    this.initialQuery,
  });

  @override
  SearchDialogConfig get config => SearchDialogConfig(
        title: 'Buscar Factura',
        searchPlaceholder: 'Buscar por número o cliente...',
        emptySearchMessage: 'Escriba para buscar facturas',
        noResultsMessage: 'No se encontraron facturas',
        minSearchLength: 2,
        initialSearch: initialQuery,
      );

  @override
  Future<List<AccountMove>> performSearch(WidgetRef ref, String query) async {
    final repository = ref.read(invoiceRepositoryProvider);
    return repository.searchInvoices(query);
  }

  @override
  Widget buildResultItem(
    BuildContext context,
    AccountMove invoice,
    VoidCallback onSelect,
  ) {
    final theme = FluentTheme.of(context);

    // Determine status color
    Color statusColor;
    String statusText;
    switch (invoice.paymentState) {
      case 'paid':
        statusColor = Colors.green;
        statusText = 'Pagada';
        break;
      case 'partial':
        statusColor = Colors.orange;
        statusText = 'Parcial';
        break;
      case 'not_paid':
      default:
        statusColor = Colors.red;
        statusText = 'Pendiente';
        break;
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: GestureDetector(
        onTap: onSelect,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: theme.resources.controlStrokeColorDefault),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Invoice name and status
              Row(
                children: [
                  Expanded(
                    child: Text(
                      invoice.name.isNotEmpty ? invoice.name : 'Factura ${invoice.id}',
                      style: theme.typography.bodyStrong,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      statusText,
                      style: theme.typography.caption?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),

              // Partner name
              if (invoice.partnerName != null)
                Text(
                  invoice.partnerName!,
                  style: theme.typography.body?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),

              const SizedBox(height: 4),

              // Amounts
              Row(
                children: [
                  Text(
                    'Total: ${invoice.amountTotal.toCurrency()}',
                    style: theme.typography.caption,
                  ),
                  const SizedBox(width: 16),
                  if (invoice.amountResidual > 0)
                    Text(
                      'Pendiente: ${invoice.amountResidual.toCurrency()}',
                      style: theme.typography.caption?.copyWith(
                        color: Colors.orange,
                      ),
                    ),
                ],
              ),

              // Date
              if (invoice.invoiceDate != null)
                Text(
                  'Fecha: ${invoice.invoiceDate!.day}/${invoice.invoiceDate!.month}/${invoice.invoiceDate!.year}',
                  style: theme.typography.caption?.copyWith(
                    color: theme.inactiveColor,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  AccountMove getReturnValue(AccountMove item) => item;
}

/// Helper function to show select invoice dialog
///
/// Returns the selected [AccountMove] or null if cancelled.
///
/// [initialQuery] - Pre-fill the search field with this value.
/// If coming from an order with an invoice, pass the invoice number
/// to pre-fill and auto-search.
///
/// Usage:
/// ```dart
/// // Pre-fill with invoice number from current order
/// final invoice = await showSelectInvoiceDialog(
///   context,
///   initialQuery: order.invoiceNumber,
/// );
/// ```
Future<AccountMove?> showSelectInvoiceDialog(
  BuildContext context, {
  String? initialQuery,
}) {
  return showDialog<AccountMove>(
    context: context,
    builder: (_) => SelectInvoiceDialog(
      initialQuery: initialQuery,
    ),
  );
}
