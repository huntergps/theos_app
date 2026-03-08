import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/database/repositories/repository_providers.dart';
import '../../../../core/services/logger_service.dart';
import '../../../../shared/utils/formatting_utils.dart';
import '../../../../shared/widgets/dialogs/base_search_dialog.dart';

/// Dialog for selecting a product
///
/// Uses [BaseSearchDialog] for search functionality.
/// Returns the selected product data as Map or null if cancelled.
///
/// Usage:
/// ```dart
/// final product = await showDialog<Map<String, dynamic>>(
///   context: context,
///   builder: (_) => const SelectProductDialog(),
/// );
/// if (product != null) {
///   // Handle selected product
/// }
/// ```
class SelectProductDialog extends BaseSearchDialog<Map<String, dynamic>> {
  /// Initial search query (optional)
  final String? initialSearch;

  const SelectProductDialog({super.key, this.initialSearch});

  @override
  SearchDialogConfig get config => SearchDialogConfig(
        title: 'Agregar Producto',
        searchPlaceholder: 'Buscar por nombre, codigo o codigo de barras...',
        emptySearchMessage: 'Escriba para buscar productos',
        noResultsMessage: 'No se encontraron productos',
        maxWidth: DialogSizes.mediumWidth,
        maxHeight: DialogSizes.mediumHeight,
        initialSearch: initialSearch,
      );

  @override
  Future<List<Map<String, dynamic>>> performSearch(
    WidgetRef ref,
    String query,
  ) async {
    final productRepo = ref.read(productRepositoryProvider);
    if (productRepo == null) return [];

    try {
      return await productRepo.searchProductsEnriched(query);
    } catch (e) {
      logger.e('[SelectProductDialog]', 'Error searching products', e);
      return [];
    }
  }

  @override
  Widget buildResultItem(
    BuildContext context,
    Map<String, dynamic> item,
    VoidCallback onSelect,
  ) {
    final theme = FluentTheme.of(context);
    final price = (item['list_price'] as num?)?.toDouble() ?? 0;
    final code = item['default_code'];

    return ListTile.selectable(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: theme.accentColor.withAlpha(30),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(FluentIcons.product, color: theme.accentColor),
      ),
      title: Text(item['display_name'] ?? item['name'] ?? ''),
      subtitle: Text(
        [
          if (code != null && code != false) '[$code]',
          price.toCurrency(),
        ].join(' - '),
      ),
      onPressed: onSelect,
    );
  }
}

/// Helper function to show select product dialog
///
/// Returns the selected product data or null if cancelled.
///
/// Usage:
/// ```dart
/// final product = await showSelectProductDialog(context);
/// ```
Future<Map<String, dynamic>?> showSelectProductDialog(
  BuildContext context, {
  String? initialSearch,
}) {
  return showDialog<Map<String, dynamic>>(
    context: context,
    builder: (_) => SelectProductDialog(initialSearch: initialSearch),
  );
}
