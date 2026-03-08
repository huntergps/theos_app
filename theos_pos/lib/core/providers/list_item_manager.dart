import '../services/logger_service.dart';

/// Generic mixin for managing a list of items with CRUD operations
///
/// Provides common patterns for:
/// - Adding items with temporary IDs
/// - Updating existing items
/// - Marking items for deletion
/// - Getting visible (non-deleted) items
///
/// ## Usage
/// ```dart
/// mixin MyItemManager on Notifier<MyState> implements ListItemManager<MyItem, MyState> {
///   @override
///   String get logTag => '[MyItemManager]';
///
///   @override
///   MyState get currentState => state;
///
///   @override
///   set currentState(MyState newState) => state = newState;
///
///   @override
///   List<MyItem> getItems(MyState state) => state.items;
///
///   @override
///   List<MyItem> getNewItems(MyState state) => state.newItems;
///
///   @override
///   List<MyItem> getUpdatedItems(MyState state) => state.updatedItems;
///
///   @override
///   List<int> getDeletedIds(MyState state) => state.deletedItemIds;
///
///   @override
///   int getItemId(MyItem item) => item.id;
///
///   @override
///   MyItem copyItemWithId(MyItem item, int id) => item.copyWith(id: id);
///
///   @override
///   MyState copyStateWithNewItems(List<MyItem> items) =>
///       currentState.copyWith(newItems: items, hasChanges: true);
///
///   @override
///   MyState copyStateWithUpdatedItems(List<MyItem> items) =>
///       currentState.copyWith(updatedItems: items, hasChanges: true);
///
///   @override
///   MyState copyStateWithDeletedIds(List<int> ids, List<MyItem> updatedItems) =>
///       currentState.copyWith(deletedItemIds: ids, updatedItems: updatedItems, hasChanges: true);
/// }
/// ```
abstract interface class ListItemManager<T, S> {
  /// Log tag for this manager
  String get logTag;

  /// Get current state
  S get currentState;

  /// Set current state
  set currentState(S newState);

  /// Get items from state (original items from database)
  List<T> getItems(S state);

  /// Get new items from state (added in current session)
  List<T> getNewItems(S state);

  /// Get updated items from state (modified existing items)
  List<T> getUpdatedItems(S state);

  /// Get deleted item IDs from state
  List<int> getDeletedIds(S state);

  /// Get the ID of an item
  int getItemId(T item);

  /// Create a copy of item with a new ID
  T copyItemWithId(T item, int id);

  /// Create a copy of state with new items list
  S copyStateWithNewItems(List<T> items);

  /// Create a copy of state with updated items list
  S copyStateWithUpdatedItems(List<T> items);

  /// Create a copy of state with deleted IDs and updated items
  S copyStateWithDeletedIds(List<int> ids, List<T> updatedItems);
}

/// Extension providing common list operations
extension ListItemManagerOperations<T, S> on ListItemManager<T, S> {
  /// Add a new item with a temporary negative ID
  void addItem(T item) {
    final newItems = getNewItems(currentState);
    final tempId = -(newItems.length + 1);
    final itemWithId = copyItemWithId(item, tempId);

    currentState = copyStateWithNewItems([...newItems, itemWithId]);
    logger.d(logTag, 'Item added with temp ID: $tempId');
  }

  /// Update an existing item
  void updateItem(T item) {
    final itemId = getItemId(item);
    final newItems = getNewItems(currentState);

    // Check if it's in new items (added this session)
    final isInNewItems = newItems.any((i) => getItemId(i) == itemId);

    if (isInNewItems) {
      // Update in new items list
      final updated = newItems.map((i) => getItemId(i) == itemId ? item : i).toList();
      currentState = copyStateWithNewItems(updated);
      logger.d(logTag, 'Updated new item: $itemId');
    } else {
      // Update in updated items list
      final updatedItems = getUpdatedItems(currentState);
      final existingIndex = updatedItems.indexWhere((i) => getItemId(i) == itemId);

      List<T> newUpdatedItems;
      if (existingIndex >= 0) {
        newUpdatedItems = List<T>.from(updatedItems);
        newUpdatedItems[existingIndex] = item;
      } else {
        newUpdatedItems = [...updatedItems, item];
      }

      currentState = copyStateWithUpdatedItems(newUpdatedItems);
      logger.d(logTag, 'Updated existing item: $itemId');
    }
  }

  /// Delete an item by ID
  void deleteItem(int itemId) {
    final newItems = getNewItems(currentState);
    final isInNewItems = newItems.any((i) => getItemId(i) == itemId);

    if (isInNewItems) {
      // Remove from new items
      final filtered = newItems.where((i) => getItemId(i) != itemId).toList();
      currentState = copyStateWithNewItems(filtered);
      logger.d(logTag, 'Removed new item: $itemId');
    } else {
      // Mark for deletion
      final deletedIds = getDeletedIds(currentState);
      if (!deletedIds.contains(itemId)) {
        final updatedItems = getUpdatedItems(currentState)
            .where((i) => getItemId(i) != itemId)
            .toList();
        currentState = copyStateWithDeletedIds(
          [...deletedIds, itemId],
          updatedItems,
        );
        logger.d(logTag, 'Marked item for deletion: $itemId');
      }
    }
  }

  /// Get an item by ID from any list
  T? getItem(int itemId) {
    // Search in new items
    for (final item in getNewItems(currentState)) {
      if (getItemId(item) == itemId) return item;
    }

    // Search in updated items
    for (final item in getUpdatedItems(currentState)) {
      if (getItemId(item) == itemId) return item;
    }

    // Search in original items
    for (final item in getItems(currentState)) {
      if (getItemId(item) == itemId) return item;
    }

    return null;
  }

  /// Get all visible (non-deleted) items with updates applied
  List<T> getVisibleItems() {
    final result = <T>[];
    final deletedIds = getDeletedIds(currentState);
    final updatedItems = getUpdatedItems(currentState);

    // Original items with updates applied
    for (final item in getItems(currentState)) {
      final itemId = getItemId(item);
      if (deletedIds.contains(itemId)) continue;

      // Check for update
      final updated = updatedItems.cast<T?>().firstWhere(
        (i) => i != null && getItemId(i) == itemId,
        orElse: () => null,
      );

      result.add(updated ?? item);
    }

    // Add new items
    result.addAll(getNewItems(currentState));

    return result;
  }

  /// Get count of visible items
  int get visibleItemsCount => getVisibleItems().length;

  /// Check if there are any changes (new, updated, or deleted items)
  bool get hasItemChanges {
    return getNewItems(currentState).isNotEmpty ||
        getUpdatedItems(currentState).isNotEmpty ||
        getDeletedIds(currentState).isNotEmpty;
  }
}
