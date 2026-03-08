import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/list_filter_providers.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/services/list_filter_persistence_service.dart';
import '../../../shared/widgets/reactive/reactive_search_bar.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import 'sale_order_stream_providers.dart';

part 'sale_orders_list_providers.g.dart';

/// Storage key for persisting sale orders list filters
const _salesFiltersStorageKey = 'sale_orders_list';

/// Default facet for "Mis cotizaciones" (My Quotations) filter
/// This is the default filter like in Odoo's sale order list
const _myQuotationsFacet = SearchFacet(
  id: 'my_orders',
  label: 'Vendedor',
  value: 'Mis cotizaciones',
  icon: FluentIcons.contact,
  type: SearchFacetType.filter,
  removable: true,
);

/// Notifier for search bar state with persistence
class SalesSearchBarNotifier extends Notifier<ReactiveSearchBarState> {
  late final ListFilterPersistenceService _persistenceService;
  bool _initialized = false;

  @override
  ReactiveSearchBarState build() {
    _persistenceService = ref.read(listFilterPersistenceProvider);
    // Load persisted filters on first build
    _loadPersistedFilters();
    return const ReactiveSearchBarState();
  }

  /// Load filters from persistent storage
  ///
  /// If no persisted filters exist, sets the default "Mis cotizaciones" filter
  /// to match Odoo's default behavior.
  Future<void> _loadPersistedFilters() async {
    if (_initialized) return;
    _initialized = true;

    final savedState = await _persistenceService.loadFilters(_salesFiltersStorageKey);
    if (savedState != null) {
      state = savedState;
    } else {
      // Set default filter "Mis cotizaciones" like Odoo
      state = const ReactiveSearchBarState(
        facets: [_myQuotationsFacet],
      );
      // Persist the default state
      _saveFilters();
    }
  }

  /// Save current filters to persistent storage
  Future<void> _saveFilters() async {
    await _persistenceService.saveFilters(_salesFiltersStorageKey, state);
  }

  void setQuery(String query) {
    state = state.copyWith(query: query);
    _saveFilters();
  }

  void addFacet(SearchFacet facet) {
    state = state.addFacet(facet);
    _saveFilters();
  }

  void removeFacet(String id) {
    state = state.removeFacet(id);
    _saveFilters();
  }

  void clear() {
    state = const ReactiveSearchBarState();
    _saveFilters();
  }
}

/// Provider for the sales list search bar state
final salesSearchBarProvider =
    NotifierProvider<SalesSearchBarNotifier, ReactiveSearchBarState>(
  () => SalesSearchBarNotifier(),
);

/// Filter configuration for sale orders
final salesFilterConfig = ListFilterConfig<SaleOrder, String>(
  searchMatcher: (order, query) {
    final lowerQuery = query.toLowerCase();
    return order.name.toLowerCase().contains(lowerQuery) ||
        (order.partnerName?.toLowerCase().contains(lowerQuery) ?? false) ||
        (order.clientOrderRef?.toLowerCase().contains(lowerQuery) ?? false);
  },
  stateMatcher: (order, filter) {
    if (filter == null || filter == 'all') return true;
    return order.state.toString().split('.').last == filter;
  },
  sorter: (a, b) {
    final dateA = a.dateOrder ?? DateTime(1900);
    final dateB = b.dateOrder ?? DateTime(1900);
    return dateB.compareTo(dateA); // Descending by default
  },
  allFilterValue: 'all',
);

/// Filtered sale orders provider
@riverpod
AsyncValue<List<SaleOrder>> filteredSaleOrders(Ref ref) {
  // Watch the source stream
  final ordersAsync = ref.watch(saleOrdersStreamProvider);

  // Watch the search bar state for search query
  final searchState = ref.watch(salesSearchBarProvider);

  // Watch current user for "my_orders" filter
  final currentUser = ref.watch(userProvider);

  // Check if "my_orders" filter is active
  final hasMyOrdersFilter = searchState.facets.any((f) => f.id == 'my_orders');

  // Build filter state from search bar
  final filterState = ListFilterState<String>(
    searchQuery: searchState.query,
    stateFilter: _getStateFilterFromFacets(searchState.facets),
    stateOptions: const ['all', 'draft', 'sent', 'sale', 'cancel'],
    sortBy: 'dateOrder',
    sortAscending: false,
  );

  return ordersAsync.when(
    data: (orders) {
      var filtered = applyListFilters(
        items: orders,
        filterState: filterState,
        config: salesFilterConfig,
      );

      // Apply "my_orders" filter if active
      if (hasMyOrdersFilter && currentUser != null) {
        filtered = filtered.where((o) => o.userId == currentUser.id).toList();
      }

      return AsyncValue.data(filtered);
    },
    loading: () => const AsyncValue.loading(),
    error: (error, stack) => AsyncValue.error(error, stack),
  );
}

/// Extract state filter from facets
String _getStateFilterFromFacets(List<SearchFacet> facets) {
  // Look for state facet
  for (final facet in facets) {
    if (facet.id == 'draft' ||
        facet.id == 'sent' ||
        facet.id == 'sale' ||
        facet.id == 'cancel') {
      return facet.id;
    }
  }
  return 'all';
}

/// Provider for counting orders by state (for badges in filter menu)
@riverpod
Map<String, int> saleOrdersCount(Ref ref) {
  final ordersAsync = ref.watch(saleOrdersStreamProvider);

  return ordersAsync.when(
    data: (orders) {
      final counts = <String, int>{
        'all': orders.length,
        'draft': 0,
        'sent': 0,
        'sale': 0,
        'cancel': 0,
      };

      for (final order in orders) {
        final state = order.state.toString().split('.').last;
        counts[state] = (counts[state] ?? 0) + 1;
      }

      return counts;
    },
    loading: () => const {},
    error: (_, _) => const {},
  );
}

/// Provider for unsynced orders count (for sync badge)
@riverpod
int unsyncedOrdersCount(Ref ref) {
  final ordersAsync = ref.watch(saleOrdersStreamProvider);

  return ordersAsync.when(
    data: (orders) => orders.where((o) => !o.isSynced).length,
    loading: () => 0,
    error: (_, _) => 0,
  );
}
