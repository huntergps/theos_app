import 'package:fluent_ui/fluent_ui.dart';

/// A reusable search and filter bar widget for list screens.
/// Provides a search box with debouncing and an optional filter dropdown.
class TheosSearchFilterBar<T> extends StatefulWidget {
  final TextEditingController searchController;
  final String searchPlaceholder;
  final ValueChanged<String>? onSearchChanged;
  final Duration debounceDuration;

  // Optional filter
  final T? filterValue;
  final List<ComboBoxItem<T>>? filterItems;
  final ValueChanged<T?>? onFilterChanged;
  final double? filterWidth;

  const TheosSearchFilterBar({
    super.key,
    required this.searchController,
    this.searchPlaceholder = 'Buscar...',
    this.onSearchChanged,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.filterValue,
    this.filterItems,
    this.onFilterChanged,
    this.filterWidth = 180,
  });

  @override
  State<TheosSearchFilterBar<T>> createState() =>
      _TheosSearchFilterBarState<T>();
}

class _TheosSearchFilterBarState<T> extends State<TheosSearchFilterBar<T>> {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          // Search box
          Expanded(
            child: TextBox(
              controller: widget.searchController,
              placeholder: widget.searchPlaceholder,
              prefix: const Padding(
                padding: EdgeInsets.only(left: 8.0),
                child: Icon(FluentIcons.search),
              ),
              onChanged: (value) {
                // Búsqueda en tiempo real con debounce
                if (widget.onSearchChanged != null) {
                  Future.delayed(widget.debounceDuration, () {
                    if (widget.searchController.text == value) {
                      widget.onSearchChanged!(value);
                    }
                  });
                }
              },
            ),
          ),
          // Optional filter dropdown
          if (widget.filterItems != null && widget.filterItems!.isNotEmpty) ...[
            const SizedBox(width: 12),
            SizedBox(
              width: widget.filterWidth,
              child: ComboBox<T>(
                value: widget.filterValue,
                items: widget.filterItems,
                onChanged: widget.onFilterChanged,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
