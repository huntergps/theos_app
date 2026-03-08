/// Generic state for list filtering and searching
///
/// This class holds the filter/search state that can be applied to any list.
/// It's designed to be model-agnostic and reusable across features.
///
/// Usage:
/// ```dart
/// final salesFilterProvider = StateProvider((ref) => ListFilterState<String>(
///   stateFilter: 'all',
///   stateOptions: ['all', 'draft', 'sale', 'cancel'],
/// ));
/// ```
class ListFilterState<TFilter> {
  /// Current search query text
  final String searchQuery;

  /// Current filter value (e.g., 'all', 'draft', 'sale')
  final TFilter? stateFilter;

  /// Available filter options
  final List<TFilter> stateOptions;

  /// Sort field name (if applicable)
  final String? sortBy;

  /// Sort direction (true = ascending, false = descending)
  final bool sortAscending;

  const ListFilterState({
    this.searchQuery = '',
    this.stateFilter,
    this.stateOptions = const [],
    this.sortBy,
    this.sortAscending = false,
  });

  /// Check if any filter is active
  bool get hasActiveFilters =>
      searchQuery.isNotEmpty ||
      (stateFilter != null && stateFilter != stateOptions.firstOrNull);

  ListFilterState<TFilter> copyWith({
    String? searchQuery,
    TFilter? stateFilter,
    List<TFilter>? stateOptions,
    String? sortBy,
    bool? sortAscending,
  }) {
    return ListFilterState<TFilter>(
      searchQuery: searchQuery ?? this.searchQuery,
      stateFilter: stateFilter ?? this.stateFilter,
      stateOptions: stateOptions ?? this.stateOptions,
      sortBy: sortBy ?? this.sortBy,
      sortAscending: sortAscending ?? this.sortAscending,
    );
  }

  /// Reset filters to default
  ListFilterState<TFilter> reset() {
    return ListFilterState<TFilter>(
      searchQuery: '',
      stateFilter: stateOptions.firstOrNull,
      stateOptions: stateOptions,
      sortBy: sortBy,
      sortAscending: false,
    );
  }
}

/// Configuration for filtering a list of items
///
/// Defines how to match items against the search query and filter state.
class ListFilterConfig<T, TFilter> {
  /// Function to check if item matches search query
  /// Returns true if the item should be included
  final bool Function(T item, String query) searchMatcher;

  /// Function to check if item matches filter state
  /// Returns true if the item should be included
  final bool Function(T item, TFilter? filter) stateMatcher;

  /// Function to compare items for sorting
  /// If null, items are not sorted
  final int Function(T a, T b)? sorter;

  /// "All" filter value (won't be filtered)
  final TFilter? allFilterValue;

  const ListFilterConfig({
    required this.searchMatcher,
    required this.stateMatcher,
    this.sorter,
    this.allFilterValue,
  });
}

/// Apply filters to a list of items
///
/// This is a pure function that can be used anywhere.
/// Returns a new filtered (and optionally sorted) list.
List<T> applyListFilters<T, TFilter>({
  required List<T> items,
  required ListFilterState<TFilter> filterState,
  required ListFilterConfig<T, TFilter> config,
}) {
  var result = items.toList();

  // Apply state filter (skip if 'all' or null)
  if (filterState.stateFilter != null &&
      filterState.stateFilter != config.allFilterValue) {
    result = result
        .where((item) => config.stateMatcher(item, filterState.stateFilter))
        .toList();
  }

  // Apply search filter
  if (filterState.searchQuery.isNotEmpty) {
    final query = filterState.searchQuery.toLowerCase();
    result =
        result.where((item) => config.searchMatcher(item, query)).toList();
  }

  // Apply sorting
  if (config.sorter != null) {
    result.sort((a, b) {
      final comparison = config.sorter!(a, b);
      return filterState.sortAscending ? comparison : -comparison;
    });
  }

  return result;
}
