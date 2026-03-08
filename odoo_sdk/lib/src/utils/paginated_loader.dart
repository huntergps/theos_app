/// Configuration for paginated loading
class PaginationConfig {
  /// Number of items to load per page
  final int pageSize;

  /// Whether to automatically load more when reaching threshold
  final bool autoLoadMore;

  /// Threshold for auto-loading (percentage of list scrolled)
  final double loadMoreThreshold;

  /// Maximum items to keep in memory (0 = unlimited)
  final int maxItemsInMemory;

  const PaginationConfig({
    this.pageSize = 50,
    this.autoLoadMore = true,
    this.loadMoreThreshold = 0.8,
    this.maxItemsInMemory = 500,
  });

  /// Preset for large lists (products, clients)
  static const large = PaginationConfig(
    pageSize: 100,
    maxItemsInMemory: 1000,
  );

  /// Preset for medium lists (orders)
  static const medium = PaginationConfig(
    pageSize: 50,
    maxItemsInMemory: 500,
  );

  /// Preset for small lists (search results)
  static const small = PaginationConfig(
    pageSize: 20,
    maxItemsInMemory: 200,
  );
}

/// State for paginated data
class PaginatedState<T> {
  /// All loaded items
  final List<T> items;

  /// Current page (0-based)
  final int currentPage;

  /// Total count of items (if known)
  final int? totalCount;

  /// Whether there are more items to load
  final bool hasMore;

  /// Whether currently loading
  final bool isLoading;

  /// Error message if loading failed
  final String? error;

  /// Whether this is the initial load
  final bool isInitial;

  const PaginatedState({
    this.items = const [],
    this.currentPage = 0,
    this.totalCount,
    this.hasMore = true,
    this.isLoading = false,
    this.error,
    this.isInitial = true,
  });

  /// Create initial state
  factory PaginatedState.initial() => const PaginatedState();

  /// Create loading state
  PaginatedState<T> loading() => PaginatedState<T>(
        items: items,
        currentPage: currentPage,
        totalCount: totalCount,
        hasMore: hasMore,
        isLoading: true,
        error: null,
        isInitial: isInitial,
      );

  /// Create loaded state with new items
  PaginatedState<T> loaded({
    required List<T> newItems,
    required bool hasMore,
    int? totalCount,
  }) =>
      PaginatedState<T>(
        items: [...items, ...newItems],
        currentPage: currentPage + 1,
        totalCount: totalCount ?? this.totalCount,
        hasMore: hasMore,
        isLoading: false,
        error: null,
        isInitial: false,
      );

  /// Create error state
  PaginatedState<T> withError(String error) => PaginatedState<T>(
        items: items,
        currentPage: currentPage,
        totalCount: totalCount,
        hasMore: hasMore,
        isLoading: false,
        error: error,
        isInitial: isInitial,
      );

  /// Create refreshed state (reset with new items)
  PaginatedState<T> refreshed({
    required List<T> items,
    required bool hasMore,
    int? totalCount,
  }) =>
      PaginatedState<T>(
        items: items,
        currentPage: 1,
        totalCount: totalCount,
        hasMore: hasMore,
        isLoading: false,
        error: null,
        isInitial: false,
      );

  /// Number of items loaded
  int get itemCount => items.length;

  /// Whether the list is empty
  bool get isEmpty => items.isEmpty;

  /// Whether there's an error
  bool get hasError => error != null;

  /// Check if we should load more based on scroll position
  bool shouldLoadMore(int itemIndex, PaginationConfig config) {
    if (isLoading || !hasMore) return false;
    final threshold = (itemCount * config.loadMoreThreshold).floor();
    return itemIndex >= threshold;
  }
}

/// Type definition for data loading function
typedef PaginatedLoader<T> = Future<PaginatedResult<T>> Function(
    int offset, int limit);

/// Result from a paginated load operation
class PaginatedResult<T> {
  final List<T> items;
  final bool hasMore;
  final int? totalCount;

  const PaginatedResult({
    required this.items,
    required this.hasMore,
    this.totalCount,
  });
}

/// Generic controller for paginated data
class PaginatedController<T> {
  final PaginatedLoader<T> loader;
  final PaginationConfig config;

  PaginatedState<T> _state = PaginatedState.initial();

  /// Callback when state changes
  void Function(PaginatedState<T>)? onStateChanged;

  PaginatedController({
    required this.loader,
    this.config = const PaginationConfig(),
    this.onStateChanged,
  });

  /// Current state
  PaginatedState<T> get state => _state;

  /// Update state and notify listeners
  void _setState(PaginatedState<T> newState) {
    _state = newState;
    onStateChanged?.call(_state);
  }

  /// Load the first page of data
  Future<void> loadInitial() async {
    if (_state.isLoading) return;

    _setState(_state.loading());

    try {
      final result = await loader(0, config.pageSize);
      _setState(_state.refreshed(
        items: result.items,
        hasMore: result.hasMore,
        totalCount: result.totalCount,
      ));
    } catch (e) {
      _setState(_state.withError(e.toString()));
    }
  }

  /// Load the next page of data
  Future<void> loadMore() async {
    if (_state.isLoading || !_state.hasMore) return;

    _setState(_state.loading());

    try {
      final offset = _state.itemCount;
      final result = await loader(offset, config.pageSize);
      _setState(_state.loaded(
        newItems: result.items,
        hasMore: result.hasMore,
        totalCount: result.totalCount,
      ));

      // Trim items if exceeding max
      if (config.maxItemsInMemory > 0 &&
          _state.itemCount > config.maxItemsInMemory) {
        _trimItems();
      }
    } catch (e) {
      _setState(_state.withError(e.toString()));
    }
  }

  /// Refresh the data (reload from beginning)
  Future<void> refresh() async {
    _setState(PaginatedState.initial());
    await loadInitial();
  }

  /// Trim items to stay within memory limit
  void _trimItems() {
    if (config.maxItemsInMemory <= 0) return;

    final excess = _state.itemCount - config.maxItemsInMemory;
    if (excess > 0) {
      // Remove items from the beginning (oldest)
      _setState(PaginatedState<T>(
        items: _state.items.sublist(excess),
        currentPage: _state.currentPage,
        totalCount: _state.totalCount,
        hasMore: _state.hasMore,
        isLoading: false,
        error: null,
        isInitial: false,
      ));
    }
  }

  /// Check if we should load more based on scroll position
  void onItemVisible(int index) {
    if (config.autoLoadMore && _state.shouldLoadMore(index, config)) {
      loadMore();
    }
  }
}

/// Mixin for scroll controllers to trigger lazy loading
mixin LazyLoadScrollMixin {
  /// Check if scroll position triggers load more
  bool shouldLoadMore(double scrollPosition, double maxScrollExtent,
      {double threshold = 0.8}) {
    if (maxScrollExtent <= 0) return false;
    return scrollPosition / maxScrollExtent >= threshold;
  }
}

/// Helper to calculate visible range for virtualized lists
class VisibleRangeCalculator {
  /// Calculate the visible range of items
  static (int start, int end) calculateVisibleRange({
    required double scrollOffset,
    required double viewportHeight,
    required double itemHeight,
    required int totalItems,
    int buffer = 5,
  }) {
    final firstVisible = (scrollOffset / itemHeight).floor();
    final visibleCount = (viewportHeight / itemHeight).ceil();

    final start = (firstVisible - buffer).clamp(0, totalItems - 1);
    final end = (firstVisible + visibleCount + buffer).clamp(0, totalItems);

    return (start, end);
  }
}

/// Extension for List to implement windowed/virtualized access
extension WindowedListExtension<T> on List<T> {
  /// Get a windowed view of the list for virtualization
  List<T> windowed(int start, int end) {
    final safeStart = start.clamp(0, length);
    final safeEnd = end.clamp(0, length);
    return sublist(safeStart, safeEnd);
  }
}
