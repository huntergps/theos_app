import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../shared/providers/list_filter_providers.dart';
import '../../../shared/providers/user_provider.dart';
import '../../../shared/constants/user_groups.dart';
import '../../../shared/services/list_filter_persistence_service.dart';
import '../../../shared/widgets/reactive/reactive_search_bar.dart';
import '../../../core/database/repositories/repository_providers.dart';

import 'package:theos_pos_core/theos_pos_core.dart';

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

const _saleOrderStateFacetIds = {
  'draft',
  'sent',
  'waiting',
  'approved',
  'rejected',
  'sale',
  'cancel',
};

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

    final savedState = await _persistenceService.loadFilters(
      _salesFiltersStorageKey,
    );
    if (savedState != null) {
      state = savedState;
    } else {
      // Set default filter "Mis cotizaciones" like Odoo
      state = const ReactiveSearchBarState(facets: [_myQuotationsFacet]);
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
    ref.read(salesListPageIndexProvider.notifier).reset();
    _saveFilters();
  }

  void addFacet(SearchFacet facet) {
    // An order can only have one state. Keeping several state facets active
    // made the chips contradict each other while the provider silently used
    // whichever happened to be first.
    if (_saleOrderStateFacetIds.contains(facet.id)) {
      state = state.copyWith(
        facets: [
          ...state.facets.where(
            (item) => !_saleOrderStateFacetIds.contains(item.id),
          ),
          facet,
        ],
      );
    } else {
      state = state.addFacet(facet);
    }
    ref.read(salesListPageIndexProvider.notifier).reset();
    _saveFilters();
  }

  void removeFacet(String id) {
    state = state.removeFacet(id);
    ref.read(salesListPageIndexProvider.notifier).reset();
    _saveFilters();
  }

  void clear() {
    state = const ReactiveSearchBarState();
    ref.read(salesListPageIndexProvider.notifier).reset();
    _saveFilters();
  }
}

class SalesListPageIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void setPage(int pageIndex) {
    if (pageIndex < 0 || pageIndex == state) return;
    state = pageIndex;
  }

  void reset() => state = 0;
}

final salesListPageIndexProvider =
    NotifierProvider<SalesListPageIndexNotifier, int>(
      SalesListPageIndexNotifier.new,
    );

const salesListPageSize = 80;

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
    // The generic filter reverses this comparator when sortAscending=false.
    // Keep this comparator natural so the default is actually newest first.
    return dateA.compareTo(dateB);
  },
  allFilterValue: 'all',
);

/// Atomic projection consumed by the sales list, its state badges and the
/// pending-sync badge.
///
/// Keeping these values in one snapshot prevents the UI from painting counts
/// calculated with a different user/filter revision than the visible rows.
class SaleOrdersListSnapshot {
  final List<SaleOrder> visibleOrders;
  final Map<String, int> countsByState;
  final int unsyncedCount;
  final int totalCount;
  final int pageIndex;
  final int pageSize;

  SaleOrdersListSnapshot({
    required List<SaleOrder> visibleOrders,
    required Map<String, int> countsByState,
    required this.unsyncedCount,
    int? totalCount,
    this.pageIndex = 0,
    this.pageSize = salesListPageSize,
  }) : visibleOrders = List.unmodifiable(visibleOrders),
       countsByState = Map.unmodifiable(countsByState),
       totalCount = totalCount ?? visibleOrders.length;
}

/// Builds every sales-list projection from exactly the same input revision.
SaleOrdersListSnapshot buildSaleOrdersListSnapshot({
  required List<SaleOrder> orders,
  required ReactiveSearchBarState searchState,
  User? currentUser,
}) {
  final visibleOrders = applySaleOrderFilters(
    orders: orders,
    searchState: searchState,
    currentUser: currentUser,
  );
  final badgeScope = applySaleOrderFilters(
    orders: orders,
    searchState: searchState,
    currentUser: currentUser,
    includeStateFilter: false,
  );
  final counts = <String, int>{
    'all': badgeScope.length,
    'draft': 0,
    'sent': 0,
    'waiting': 0,
    'approved': 0,
    'rejected': 0,
    'sale': 0,
    'cancel': 0,
  };

  for (final order in badgeScope) {
    final state = order.state.toString().split('.').last;
    counts[state] = (counts[state] ?? 0) + 1;
  }

  return SaleOrdersListSnapshot(
    visibleOrders: visibleOrders,
    countsByState: counts,
    unsyncedCount: orders.where((order) => !order.isSynced).length,
    totalCount: visibleOrders.length,
  );
}

/// Shared database-backed sales-list page. Errors from Drift remain visible.
@riverpod
Stream<SaleOrdersListSnapshot> saleOrdersListSnapshot(Ref ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) {
    return Stream.value(
      SaleOrdersListSnapshot(
        visibleOrders: const [],
        countsByState: const {
          'all': 0,
          'draft': 0,
          'sent': 0,
          'waiting': 0,
          'approved': 0,
          'rejected': 0,
          'sale': 0,
          'cancel': 0,
        },
        unsyncedCount: 0,
        totalCount: 0,
      ),
    );
  }
  final searchState = ref.watch(salesSearchBarProvider);
  final currentUser = ref.watch(userProvider);
  final pageIndex = ref.watch(salesListPageIndexProvider);
  final hasMyOrdersFilter = searchState.facets.any(
    (facet) => facet.id == 'my_orders',
  );
  final scopedUserId = hasMyOrdersFilter && _isPersonalSellerScope(currentUser)
      ? currentUser!.id
      : null;

  return saleOrderManager
      .watchListPage(
        searchQuery: searchState.query,
        state: _getStateFilterFromFacets(searchState.facets),
        userId: scopedUserId,
        pageIndex: pageIndex,
        pageSize: salesListPageSize,
      )
      .map(
        (page) => SaleOrdersListSnapshot(
          visibleOrders: page.rows,
          countsByState: page.countsByState,
          unsyncedCount: page.unsyncedCount,
          totalCount: page.totalCount,
          pageIndex: page.pageIndex,
          pageSize: page.pageSize,
        ),
      );
}

/// Filtered sale orders provider.
@riverpod
AsyncValue<List<SaleOrder>> filteredSaleOrders(Ref ref) {
  return ref
      .watch(saleOrdersListSnapshotProvider)
      .whenData((snapshot) => snapshot.visibleOrders);
}

/// Applies the exact list semantics used by the screen.
///
/// The default "Mis cotizaciones" facet only scopes a plain salesperson.
/// Managers, administrators and API/service identities must not be reduced to
/// an empty list merely because their technical user ID differs from the
/// salesperson assigned to existing orders.
List<SaleOrder> applySaleOrderFilters({
  required List<SaleOrder> orders,
  required ReactiveSearchBarState searchState,
  User? currentUser,
  bool includeStateFilter = true,
}) {
  final filterState = ListFilterState<String>(
    searchQuery: searchState.query,
    stateFilter: includeStateFilter
        ? _getStateFilterFromFacets(searchState.facets)
        : 'all',
    stateOptions: const [
      'all',
      'draft',
      'sent',
      'waiting',
      'approved',
      'rejected',
      'sale',
      'cancel',
    ],
    sortBy: 'dateOrder',
    sortAscending: false,
  );

  var filtered = applyListFilters(
    items: orders,
    filterState: filterState,
    config: salesFilterConfig,
  );

  final hasMyOrdersFilter = searchState.facets.any((f) => f.id == 'my_orders');
  if (hasMyOrdersFilter && _isPersonalSellerScope(currentUser)) {
    filtered = filtered
        .where((order) => order.userId == currentUser!.id)
        .toList();
  }

  return filtered;
}

bool _isPersonalSellerScope(User? user) {
  if (user == null) return false;
  final permissions = user.permissions.toSet();
  return permissions.contains(OdooUserGroup.salesUser) &&
      !permissions.contains(OdooUserGroup.salesManager) &&
      !resolveTheosUserRoles(permissions).contains(TheosUserRole.administrator);
}

/// Extract state filter from facets
String _getStateFilterFromFacets(List<SearchFacet> facets) {
  // Look for state facet
  for (final facet in facets) {
    if (_saleOrderStateFacetIds.contains(facet.id)) {
      return facet.id;
    }
  }
  return 'all';
}

/// Provider for counting orders by state (for badges in filter menu).
/// Loading and database errors remain observable instead of becoming zeros.
@riverpod
AsyncValue<Map<String, int>> saleOrdersCount(Ref ref) {
  return ref
      .watch(saleOrdersListSnapshotProvider)
      .whenData((snapshot) => snapshot.countsByState);
}

/// Provider for unsynced orders count (for sync badge).
@riverpod
AsyncValue<int> unsyncedOrdersCount(Ref ref) {
  return ref
      .watch(saleOrdersListSnapshotProvider)
      .whenData((snapshot) => snapshot.unsyncedCount);
}
