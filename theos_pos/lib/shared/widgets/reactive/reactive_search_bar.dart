import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Represents an active filter displayed as a facet/chip in the search bar
///
/// Based on Odoo's facet system where active filters appear as chips
/// inside the search input field.
class SearchFacet {
  /// Unique identifier for this facet
  final String id;

  /// Display label (e.g., "Estado", "Cliente")
  final String label;

  /// Current value display text (e.g., "Cotización", "Juan Pérez")
  final String value;

  /// Icon to show in the facet label
  final IconData? icon;

  /// Color for the facet label
  final Color? color;

  /// Type of facet for styling (filter, groupBy, field)
  final SearchFacetType type;

  /// Whether this facet can be removed by user
  final bool removable;

  const SearchFacet({
    required this.id,
    required this.label,
    required this.value,
    this.icon,
    this.color,
    this.type = SearchFacetType.filter,
    this.removable = true,
  });

  SearchFacet copyWith({
    String? id,
    String? label,
    String? value,
    IconData? icon,
    Color? color,
    SearchFacetType? type,
    bool? removable,
  }) {
    return SearchFacet(
      id: id ?? this.id,
      label: label ?? this.label,
      value: value ?? this.value,
      icon: icon ?? this.icon,
      color: color ?? this.color,
      type: type ?? this.type,
      removable: removable ?? this.removable,
    );
  }
}

/// Type of search facet for styling
enum SearchFacetType {
  /// Filter facet (blue) - e.g., "Estado: Cotización"
  filter,

  /// Group by facet (purple/action) - e.g., "Agrupar por: Cliente"
  groupBy,

  /// Field search facet (primary) - e.g., "Cliente: Juan"
  field,

  /// Favorite/saved filter (orange) - e.g., "Mis pedidos"
  favorite,
}

/// Configuration for a filter option shown in the dropdown menu
class FilterOption<T> {
  /// Unique identifier
  final String id;

  /// Display label
  final String label;

  /// Icon to show
  final IconData? icon;

  /// The actual filter value
  final T value;

  /// Facet label when this filter is active
  final String? facetLabel;

  const FilterOption({
    required this.id,
    required this.label,
    required this.value,
    this.icon,
    this.facetLabel,
  });
}

/// State for the reactive search bar
///
/// Manages search query, active facets, and dropdown visibility.
class ReactiveSearchBarState {
  /// Current search query text
  final String query;

  /// Active filter facets displayed as chips
  final List<SearchFacet> facets;

  /// Whether the dropdown menu is open
  final bool isDropdownOpen;

  /// Whether search is in progress
  final bool isSearching;

  const ReactiveSearchBarState({
    this.query = '',
    this.facets = const [],
    this.isDropdownOpen = false,
    this.isSearching = false,
  });

  /// Check if any filters are active
  bool get hasActiveFilters => facets.isNotEmpty || query.isNotEmpty;

  /// Get facet by ID
  SearchFacet? getFacet(String id) {
    try {
      return facets.firstWhere((f) => f.id == id);
    } catch (_) {
      return null;
    }
  }

  ReactiveSearchBarState copyWith({
    String? query,
    List<SearchFacet>? facets,
    bool? isDropdownOpen,
    bool? isSearching,
  }) {
    return ReactiveSearchBarState(
      query: query ?? this.query,
      facets: facets ?? this.facets,
      isDropdownOpen: isDropdownOpen ?? this.isDropdownOpen,
      isSearching: isSearching ?? this.isSearching,
    );
  }

  /// Add a facet (or replace if same ID exists)
  ReactiveSearchBarState addFacet(SearchFacet facet) {
    final existing = facets.indexWhere((f) => f.id == facet.id);
    if (existing >= 0) {
      final newFacets = [...facets];
      newFacets[existing] = facet;
      return copyWith(facets: newFacets);
    }
    return copyWith(facets: [...facets, facet]);
  }

  /// Remove a facet by ID
  ReactiveSearchBarState removeFacet(String id) {
    return copyWith(facets: facets.where((f) => f.id != id).toList());
  }

  /// Clear all
  ReactiveSearchBarState clear() {
    return const ReactiveSearchBarState();
  }
}

/// Reactive search bar widget with Odoo-style facets/chips
///
/// Features:
/// - Search input with debouncing
/// - Active filters displayed as removable chips (facets)
/// - Dropdown menu with filter options
/// - Keyboard navigation support
/// - Animation on facet add/remove
///
/// Usage:
/// ```dart
/// // First, create a provider for search bar state:
/// final salesSearchBarProvider = StateProvider.autoDispose(
///   (ref) => const ReactiveSearchBarState(),
/// );
///
/// // Then use the widget:
/// ReactiveSearchBar(
///   provider: salesSearchBarProvider,
///   placeholder: 'Buscar órdenes...',
///   filterSections: [
///     FilterMenuSection(
///       title: 'Estado',
///       options: [
///         FilterOption(id: 'draft', label: 'Cotización', value: 'draft'),
///         FilterOption(id: 'sale', label: 'Orden de venta', value: 'sale'),
///       ],
///     ),
///   ],
/// )
/// ```
class ReactiveSearchBar<T, N extends Notifier<ReactiveSearchBarState>>
    extends ConsumerStatefulWidget {
  /// Provider for search bar state
  final NotifierProvider<N, ReactiveSearchBarState> provider;

  /// Placeholder text for search input
  final String placeholder;

  /// Filter menu sections with options
  final List<FilterMenuSection<T>>? filterSections;

  /// Quick filter buttons shown below the search bar
  final List<QuickFilter>? quickFilters;

  /// Debounce duration for search input
  final Duration debounceDuration;

  /// Callback when search query changes (after debounce)
  final ValueChanged<String>? onSearch;

  /// Callback when facets/filters change
  final ValueChanged<List<SearchFacet>>? onFilterChanged;

  /// Callback when a filter option is selected
  final void Function(String filterId, T value)? onFilterSelected;

  /// Whether to show the filter dropdown button
  final bool showFilterButton;

  /// Custom action buttons to show in the bar
  final List<Widget>? actions;

  const ReactiveSearchBar({
    super.key,
    required this.provider,
    this.placeholder = 'Buscar...',
    this.filterSections,
    this.quickFilters,
    this.debounceDuration = const Duration(milliseconds: 300),
    this.onSearch,
    this.onFilterChanged,
    this.onFilterSelected,
    this.showFilterButton = true,
    this.actions,
  });

  @override
  ConsumerState<ReactiveSearchBar<T, N>> createState() =>
      _ReactiveSearchBarState<T, N>();
}

class _ReactiveSearchBarState<T, N extends Notifier<ReactiveSearchBarState>>
    extends ConsumerState<ReactiveSearchBar<T, N>> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  final _searchFocusNode = FocusNode();
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
    // Initialize controller with persisted query after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncControllerWithState();
    });
  }

  /// Sync the text controller with the current provider state
  void _syncControllerWithState() {
    final state = ref.read(widget.provider);
    if (state.query.isNotEmpty && _searchController.text != state.query) {
      _searchController.text = state.query;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _focusNode.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  void _onSearchChanged() {
    _debounceTimer?.cancel();
    _debounceTimer = Timer(widget.debounceDuration, () {
      final query = _searchController.text;
      _setQuery(query);
      widget.onSearch?.call(query);
    });
  }

  // Helper methods to update state - works with any notifier that has these methods
  void _setQuery(String query) {
    final notifier = ref.read(widget.provider.notifier);
    // Use dynamic to call setQuery if available
    (notifier as dynamic).setQuery(query);
  }

  void _addFacet(SearchFacet facet) {
    final notifier = ref.read(widget.provider.notifier);
    (notifier as dynamic).addFacet(facet);
  }

  void _removeFacetFromState(String id) {
    final notifier = ref.read(widget.provider.notifier);
    (notifier as dynamic).removeFacet(id);
  }

  void _clearState() {
    final notifier = ref.read(widget.provider.notifier);
    (notifier as dynamic).clear();
  }

  void _onFacetRemove(SearchFacet facet) {
    _removeFacetFromState(facet.id);
    widget.onFilterChanged?.call(ref.read(widget.provider).facets);
    _searchFocusNode.requestFocus();
  }

  void _onFilterSelect(FilterOption<T> option, String sectionId) {
    final facet = SearchFacet(
      id: option.id,
      label: option.facetLabel ?? sectionId,
      value: option.label,
      icon: option.icon,
      type: SearchFacetType.filter,
    );

    final state = ref.read(widget.provider);
    final existingFacet = state.getFacet(option.id);

    if (existingFacet != null) {
      _removeFacetFromState(option.id);
    } else {
      _addFacet(facet);
    }

    widget.onFilterSelected?.call(option.id, option.value);
    widget.onFilterChanged?.call(ref.read(widget.provider).facets);
  }

  void _clearAll() {
    _searchController.clear();
    _clearState();
    widget.onSearch?.call('');
    widget.onFilterChanged?.call([]);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(widget.provider);
    final theme = FluentTheme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Main search bar with facets
          Container(
            decoration: BoxDecoration(
              color: theme.cardColor,
              borderRadius: BorderRadius.circular(4),
              border: Border.all(
                color: _searchFocusNode.hasFocus
                    ? theme.accentColor
                    : theme.resources.controlStrokeColorDefault,
              ),
            ),
            child: Row(
              children: [
                // Search icon
                Padding(
                  padding: const EdgeInsets.only(left: 10),
                  child: Icon(
                    FluentIcons.search,
                    size: 16,
                    color: theme.inactiveColor,
                  ),
                ),

                // Facets container + input
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Active facets (filter chips)
                        ...state.facets.map(
                          (facet) => _FacetChip(
                            facet: facet,
                            onRemove: facet.removable
                                ? () => _onFacetRemove(facet)
                                : null,
                          ),
                        ),

                        // Search input
                        SizedBox(
                          width: 200,
                          child: Focus(
                            focusNode: _focusNode,
                            onFocusChange: (hasFocus) => setState(() {}),
                            child: TextBox(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              placeholder: state.facets.isEmpty
                                  ? widget.placeholder
                                  : 'Agregar filtro...',
                              decoration: WidgetStateProperty.all(
                                const BoxDecoration(border: Border()),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 8,
                              ),
                              style: theme.typography.body,
                              onSubmitted: (value) {
                                widget.onSearch?.call(value);
                              },
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Clear all button
                if (state.hasActiveFilters)
                  Tooltip(
                    message: 'Limpiar filtros',
                    child: IconButton(
                      icon: const Icon(FluentIcons.clear, size: 14),
                      onPressed: _clearAll,
                    ),
                  ),

                // Filter dropdown button
                if (widget.showFilterButton && widget.filterSections != null)
                  _FilterDropdownButton<T>(
                    sections: widget.filterSections!,
                    activeFacetIds: state.facets.map((f) => f.id).toSet(),
                    onSelect: _onFilterSelect,
                  ),

                // Custom actions
                if (widget.actions != null) ...widget.actions!,
              ],
            ),
          ),

          // Quick filters row
          if (widget.quickFilters != null && widget.quickFilters!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: widget.quickFilters!.map((qf) {
                  final isActive = state.facets.any((f) => f.id == qf.id);
                  return _QuickFilterChip(
                    filter: qf,
                    isActive: isActive,
                    onTap: () {
                      if (isActive) {
                        _removeFacetFromState(qf.id);
                      } else {
                        _addFacet(
                          SearchFacet(
                            id: qf.id,
                            label: qf.label,
                            value: qf.label,
                            icon: qf.icon,
                            type: SearchFacetType.favorite,
                          ),
                        );
                      }
                      widget.onFilterChanged?.call(
                        ref.read(widget.provider).facets,
                      );
                    },
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

/// A single facet chip displayed in the search bar
class _FacetChip extends StatelessWidget {
  final SearchFacet facet;
  final VoidCallback? onRemove;

  const _FacetChip({required this.facet, this.onRemove});

  Color _getLabelColor(FluentThemeData theme) {
    if (facet.color != null) return facet.color!;

    return switch (facet.type) {
      SearchFacetType.filter => theme.accentColor,
      SearchFacetType.groupBy => Colors.purple,
      SearchFacetType.field => theme.accentColor,
      SearchFacetType.favorite => Colors.orange,
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final labelColor = _getLabelColor(theme);

    // If label equals value, show a single unified chip (like favorites/quick filters)
    final showValueSeparately = facet.label != facet.value;

    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          color: theme.cardColor,
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: theme.resources.controlStrokeColorDefault),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Label with color (if showing separately) or unified chip
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              decoration: BoxDecoration(
                color: labelColor,
                borderRadius: showValueSeparately
                    ? const BorderRadius.only(
                        topLeft: Radius.circular(3),
                        bottomLeft: Radius.circular(3),
                      )
                    : BorderRadius.circular(3),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (facet.icon != null) ...[
                    Icon(facet.icon, size: 12, color: Colors.white),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    facet.label,
                    style: theme.typography.caption?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  // Include remove button inside colored container when unified
                  if (!showValueSeparately && onRemove != null) ...[
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onRemove,
                      child: MouseRegion(
                        cursor: SystemMouseCursors.click,
                        child: Icon(
                          FluentIcons.chrome_close,
                          size: 10,
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Value (only if different from label)
            if (showValueSeparately)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: Text(facet.value, style: theme.typography.caption),
              ),

            // Remove button (only if showing value separately)
            if (showValueSeparately && onRemove != null)
              GestureDetector(
                onTap: onRemove,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Icon(
                      FluentIcons.chrome_close,
                      size: 10,
                      color: Colors.red,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Filter dropdown button with menu - shows options directly (no submenus)
class _FilterDropdownButton<T> extends StatelessWidget {
  final List<FilterMenuSection<T>> sections;
  final Set<String> activeFacetIds;
  final void Function(FilterOption<T>, String) onSelect;

  const _FilterDropdownButton({
    required this.sections,
    required this.activeFacetIds,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    // Flatten all options from all sections into a single list
    final List<MenuFlyoutItemBase> items = [];

    for (int i = 0; i < sections.length; i++) {
      final section = sections[i];

      // Add separator between sections (except before first)
      if (i > 0) {
        items.add(const MenuFlyoutSeparator());
      }

      // Add options directly
      for (final option in section.options) {
        final isActive = activeFacetIds.contains(option.id);
        items.add(
          MenuFlyoutItem(
            leading: isActive
                ? const Icon(FluentIcons.check_mark, size: 14)
                : (option.icon != null
                      ? Icon(option.icon, size: 14)
                      : const SizedBox(width: 14)),
            text: Text(
              option.label,
              style: isActive
                  ? const TextStyle(fontWeight: FontWeight.bold)
                  : null,
            ),
            onPressed: () => onSelect(option, section.title),
          ),
        );
      }
    }

    return DropDownButton(
      leading: Icon(FluentIcons.filter, size: 14, color: theme.inactiveColor),
      title: const Text('Filtros'),
      items: items,
    );
  }
}

/// Quick filter chip button
class _QuickFilterChip extends StatelessWidget {
  final QuickFilter filter;
  final bool isActive;
  final VoidCallback onTap;

  const _QuickFilterChip({
    required this.filter,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isActive
                ? (filter.color ?? theme.accentColor).withValues(alpha: 0.2)
                : theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isActive
                  ? (filter.color ?? theme.accentColor)
                  : theme.resources.controlStrokeColorDefault,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (filter.icon != null) ...[
                Icon(
                  filter.icon,
                  size: 12,
                  color: isActive
                      ? (filter.color ?? theme.accentColor)
                      : theme.inactiveColor,
                ),
                const SizedBox(width: 4),
              ],
              Text(
                filter.label,
                style: theme.typography.caption?.copyWith(
                  color: isActive
                      ? (filter.color ?? theme.accentColor)
                      : theme.inactiveColor,
                  fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Section in the filter dropdown menu
class FilterMenuSection<T> {
  final String title;
  final IconData? icon;
  final List<FilterOption<T>> options;

  const FilterMenuSection({
    required this.title,
    this.icon,
    required this.options,
  });
}

/// Quick filter button shown below the search bar
class QuickFilter {
  final String id;
  final String label;
  final IconData? icon;
  final Color? color;

  const QuickFilter({
    required this.id,
    required this.label,
    this.icon,
    this.color,
  });
}
