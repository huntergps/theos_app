import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/dialogs/base_search_dialog.dart';

import '../../providers/client_providers.dart';
import '../client_card.dart';
import 'package:theos_pos_core/theos_pos_core.dart';

/// Dialog for searching and selecting a client
///
/// Uses [BaseSearchDialog] for search functionality and displays
/// clients using [ClientCard] in compact mode.
///
/// Returns the selected [Client] or null if cancelled.
///
/// Usage:
/// ```dart
/// final client = await showDialog<Client>(
///   context: context,
///   builder: (_) => const SelectClientDialog(),
/// );
/// if (client != null) {
///   // Handle selected client
/// }
/// ```
class SelectClientDialog extends BaseSearchDialog<Client> {
  /// Initial search query (optional)
  final String? initialQuery;

  /// Whether to show client credit status
  final bool showCreditStatus;

  const SelectClientDialog({
    super.key,
    this.initialQuery,
    this.showCreditStatus = true,
  });

  @override
  SearchDialogConfig get config => SearchDialogConfig(
        title: 'Seleccionar Cliente',
        searchPlaceholder: 'Buscar por nombre, RUC o email...',
        emptySearchMessage: 'Escriba para buscar clientes',
        noResultsMessage: 'No se encontraron clientes',
        minSearchLength: 2,
        initialSearch: initialQuery,
      );

  @override
  Future<List<Client>> performSearch(WidgetRef ref, String query) async {
    final repository = ref.read(clientRepositoryProvider);
    if (repository == null) return [];
    return repository.search(query);
  }

  @override
  Widget buildResultItem(
    BuildContext context,
    Client client,
    VoidCallback onSelect,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: ClientCard(
        client: client,
        onTap: onSelect,
        compact: true,
        showCreditStatus: showCreditStatus,
        showContactInfo: false,
      ),
    );
  }

  @override
  Client getReturnValue(Client item) => item;
}

/// Helper function to show select client dialog
///
/// Returns the selected [Client] or null if cancelled.
///
/// Usage:
/// ```dart
/// final client = await showSelectClientDialog(context);
/// ```
Future<Client?> showSelectClientDialog(
  BuildContext context, {
  String? initialQuery,
  bool showCreditStatus = true,
}) {
  return showDialog<Client>(
    context: context,
    builder: (_) => SelectClientDialog(
      initialQuery: initialQuery,
      showCreditStatus: showCreditStatus,
    ),
  );
}
