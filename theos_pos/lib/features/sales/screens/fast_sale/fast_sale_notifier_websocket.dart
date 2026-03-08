// ignore_for_file: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
part of 'fast_sale_providers.dart';

/// WebSocket reactive updates, state management, and conflict resolution
/// for FastSaleNotifier.
extension FastSaleNotifierWebSocket on FastSaleNotifier {
  void _updateActiveTab(FastSaleTabState updatedTab) {
    logger.d(
      '[FastSale]',
      '>>> _updateActiveTab: partner=${updatedTab.order?.partnerId}/${updatedTab.order?.partnerName}, '
      'isNewOrder=${updatedTab.isNewOrder}',
    );

    final newTabs = List<FastSaleTabState>.from(state.tabs);
    if (state.activeTabIndex >= 0 && state.activeTabIndex < newTabs.length) {
      newTabs[state.activeTabIndex] = updatedTab;
      state = state.copyWith(tabs: newTabs);
      logger.d('[FastSale]', '>>> _updateActiveTab: state.tabs updated');

      // Sync to unified cache for cross-provider updates (Form, List)
      final order = updatedTab.order;
      if (order != null && !updatedTab.isNewOrder) {
        logger.d(
          '[FastSale]',
          '>>> _updateActiveTab: Syncing to orderCache: partner=${order.partnerId}/${order.partnerName}',
        );
        ref.read(orderCacheProvider.notifier).cacheOrder(
              order,
              lines: updatedTab.lines,
            );
        logger.d('[FastSale]', '>>> _updateActiveTab: cacheOrder DONE');
      } else {
        logger.d('[FastSale]', '>>> _updateActiveTab: Skipping cache sync (order=$order, isNew=${updatedTab.isNewOrder})');
      }
    } else {
      logger.w('[FastSale]', '>>> _updateActiveTab: Invalid activeTabIndex=${state.activeTabIndex}');
    }
  }

  // ============================================================
  // ORDER STATE UPDATES (Reactive)
  // ============================================================

  /// Update the locked status of the active order reactively
  ///
  /// Only updates the `locked` field without reloading the entire order.
  /// Widgets watching order.locked will update automatically.
  /// Also updates the unified cache for cross-provider synchronization.
  void updateActiveOrderLocked(bool locked) {
    final activeTab = state.activeTab;
    final order = activeTab?.order;
    if (activeTab == null || order == null) return;

    final orderId = order.id;

    // Update unified cache (single source of truth)
    ref.read(orderCacheProvider.notifier).updateOrderLocked(orderId, locked);

    // Update local tab state for immediate UI response
    final updatedOrder = order.copyWith(locked: locked);
    final updatedTab = activeTab.copyWith(order: updatedOrder);
    _updateActiveTab(updatedTab);

    logger.d('[FastSale]', 'Order $orderId locked=$locked (cache + local)');
  }

  /// Update the state of the active order reactively
  ///
  /// Only updates the `state` field without reloading the entire order.
  /// Widgets watching order.state will update automatically.
  /// Also updates the unified cache for cross-provider synchronization.
  void updateActiveOrderState(SaleOrderState newState) {
    final activeTab = state.activeTab;
    final order = activeTab?.order;
    if (activeTab == null || order == null) return;

    final orderId = order.id;

    // Update unified cache (single source of truth)
    ref.read(orderCacheProvider.notifier).updateOrderState(orderId, newState);

    // Update local tab state for immediate UI response
    final updatedOrder = order.copyWith(state: newState);
    final updatedTab = activeTab.copyWith(order: updatedOrder);
    _updateActiveTab(updatedTab);

    logger.d('[FastSale]', 'Order $orderId state=${newState.name} (cache + local)');
  }

  /// Update the locked status of a specific order by ID
  ///
  /// Updates the unified cache and any tab that contains the specified order.
  /// With the unified cache architecture, this ensures all consumers
  /// automatically see the update.
  void updateOrderLockedById(int orderId, bool locked) {
    // Update unified cache (single source of truth)
    ref.read(orderCacheProvider.notifier).updateOrderLocked(orderId, locked);

    // Also update local tab state for immediate UI response
    final tabs = state.tabs;
    bool updated = false;

    final newTabs = tabs.map((tab) {
      if (tab.orderId == orderId && tab.order != null) {
        updated = true;
        final updatedOrder = tab.order!.copyWith(locked: locked);
        return tab.copyWith(order: updatedOrder);
      }
      return tab;
    }).toList();

    if (updated) {
      state = state.copyWith(tabs: newTabs);
    }

    logger.d('[FastSale]', 'Order $orderId locked=$locked (cache updated)');
  }

  /// Update the state of a specific order by ID
  ///
  /// Updates the unified cache and any tab that contains the specified order.
  /// With the unified cache architecture, this ensures all consumers
  /// automatically see the update.
  void updateOrderStateById(int orderId, SaleOrderState newState) {
    // Update unified cache (single source of truth)
    ref.read(orderCacheProvider.notifier).updateOrderState(orderId, newState);

    // Also update local tab state for immediate UI response
    final tabs = state.tabs;
    bool updated = false;

    final newTabs = tabs.map((tab) {
      if (tab.orderId == orderId && tab.order != null) {
        updated = true;
        final updatedOrder = tab.order!.copyWith(state: newState);
        return tab.copyWith(order: updatedOrder);
      }
      return tab;
    }).toList();

    if (updated) {
      state = state.copyWith(tabs: newTabs);
    }

    logger.d('[FastSale]', 'Order $orderId state=${newState.name} (cache updated)');
  }

  /// Clear error message and credit issue
  void clearError() {
    state = state.copyWith(error: null, lastCreditIssue: null);

    // Also clear active tab error
    final activeTab = state.activeTab;
    if (activeTab != null && activeTab.error != null) {
      _updateActiveTab(activeTab.copyWith(error: null));
    }
  }

  /// Clear only the credit issue (used after dialog is dismissed)
  void clearCreditIssue() {
    state = state.copyWith(lastCreditIssue: null);
  }

  // ============================================================
  // WEBSOCKET REACTIVE UPDATES
  // ============================================================

  /// Update a line from WebSocket notification
  ///
  /// This method updates a specific line in the relevant tab without
  /// reloading all data. Increments linesVersion to force UI rebuild.
  /// Now includes conflict detection for locally modified lines.
  void updateLineFromWebSocket(
    SaleOrderLine updatedLine, {
    String? serverUserName,
  }) {
    final orderId = updatedLine.orderId;
    final tabIndex = state.tabs.indexWhere((t) => t.orderId == orderId);
    if (tabIndex < 0) return; // Order not open in POS

    final tab = state.tabs[tabIndex];
    final lineIndex = tab.lines.indexWhere((l) => l.id == updatedLine.id);

    // Check for conflict if this line was locally modified
    if (lineIndex >= 0 && tab.modifiedLineIds.contains(updatedLine.id)) {
      final localLine = tab.lines[lineIndex];
      final lineConflicts = conflictDetectionService.detectLineConflicts(
        localLines: [localLine],
        serverLines: [updatedLine],
        modifiedLineIds: {updatedLine.id},
        serverUserName: serverUserName,
      );

      final result = lineConflicts[updatedLine.id];
      if (result != null && result.hasConflicts) {
        // Found conflict - notify user but still apply server changes
        final conflictMap = <String, ConflictDetail>{
          ...?tab.conflicts,
          for (var c in result.conflicts)
            'line_${updatedLine.id}_${c.fieldName}': c,
        };

        final updatedTab = tab.copyWith(
          hasConflict: true,
          conflicts: conflictMap,
          conflictMessage:
              result.conflictMessage ??
              'La línea ${updatedLine.productName} fue modificada por ${serverUserName ?? "otro usuario"}.',
        );

        final newTabs = List<FastSaleTabState>.from(state.tabs);
        newTabs[tabIndex] = updatedTab;
        state = state.copyWith(tabs: newTabs);

        logger.w(
          '[FastSale]',
          'Line conflict detected for line ${updatedLine.id}: ${result.conflictingFieldNames}',
        );
      }
    }

    List<SaleOrderLine> newLines;
    if (lineIndex >= 0) {
      // Update existing line
      final currentLine = tab.lines[lineIndex];
      if (currentLine == updatedLine) {
        logger.d(
          '[FastSale]',
          'Line ${updatedLine.id} unchanged, skipping update',
        );
        return;
      }
      newLines = List<SaleOrderLine>.from(tab.lines);
      newLines[lineIndex] = updatedLine;
    } else {
      // Add new line
      newLines = List<SaleOrderLine>.from(tab.lines)..add(updatedLine);
      newLines.sort((a, b) => a.sequence.compareTo(b.sequence));
    }

    // Update tab with new lines and increment version
    // Clear modified flag for this line since we applied server changes
    final newModifiedIds = Set<int>.from(tab.modifiedLineIds)
      ..remove(updatedLine.id);
    final updatedTab = tab.copyWith(
      lines: newLines,
      linesVersion: tab.linesVersion + 1,
      modifiedLineIds: newModifiedIds,
    );

    final newTabs = List<FastSaleTabState>.from(state.tabs);
    newTabs[tabIndex] = updatedTab;
    state = state.copyWith(tabs: newTabs);

    logger.d(
      '[FastSale]',
      'Line ${updatedLine.id} updated via WebSocket (version: ${updatedTab.linesVersion})',
    );
  }

  /// Update order header from WebSocket notification
  ///
  /// Updates order fields without reloading all data.
  /// Now includes conflict detection for locally modified fields.
  void updateOrderFromWebSocket(
    int orderId,
    Map<String, dynamic> values, {
    String? serverUserName,
  }) {
    final tabIndex = state.tabs.indexWhere((t) => t.orderId == orderId);
    if (tabIndex < 0) return; // Order not open in POS

    final tab = state.tabs[tabIndex];
    final currentOrder = tab.order;
    if (currentOrder == null) return;

    // Check for conflicts if there are local changes
    if (tab.changedFields.isNotEmpty) {
      // Build a temporary order from server values
      final serverOrder = currentOrder.copyWith(
        partnerId: values['partner_id'] as int? ?? currentOrder.partnerId,
        partnerName:
            values['partner_name'] as String? ?? currentOrder.partnerName,
        pricelistId: values['pricelist_id'] as int? ?? currentOrder.pricelistId,
        paymentTermId:
            values['payment_term_id'] as int? ?? currentOrder.paymentTermId,
      );

      final conflictResult = conflictDetectionService.detectOrderConflicts(
        localOrder: currentOrder,
        serverOrder: serverOrder,
        changedFields: tab.changedFields,
        serverUserName: serverUserName,
      );

      if (conflictResult.hasConflicts) {
        final conflictMap = <String, ConflictDetail>{
          ...?tab.conflicts,
          for (var c in conflictResult.conflicts) c.fieldName: c,
        };

        // Update tab with conflict info (but still apply server changes)
        final conflictTab = tab.copyWith(
          hasConflict: true,
          conflicts: conflictMap,
          conflictMessage: conflictResult.conflictMessage,
        );

        final newTabs = List<FastSaleTabState>.from(state.tabs);
        newTabs[tabIndex] = conflictTab;
        state = state.copyWith(tabs: newTabs);

        logger.w(
          '[FastSale]',
          'Order conflict detected: ${conflictResult.conflictingFieldNames}',
        );
      }
    }

    // Parse state if provided
    SaleOrderState? newState;
    if (values['state'] != null) {
      final stateStr = values['state'] as String;
      newState = SaleOrderState.values
          .where((e) => e.name == stateStr)
          .firstOrNull;
    }

    // Build updated order from values
    final updatedOrder = currentOrder.copyWith(
      amountUntaxed:
          (values['amount_untaxed'] as num?)?.toDouble() ??
          currentOrder.amountUntaxed,
      amountTax:
          (values['amount_tax'] as num?)?.toDouble() ?? currentOrder.amountTax,
      amountTotal:
          (values['amount_total'] as num?)?.toDouble() ??
          currentOrder.amountTotal,
      state: newState ?? currentOrder.state,
      partnerId: values['partner_id'] as int? ?? currentOrder.partnerId,
      partnerName:
          values['partner_name'] as String? ?? currentOrder.partnerName,
    );

    if (currentOrder == updatedOrder) {
      logger.d('[FastSale]', 'Order $orderId unchanged, skipping update');
      return;
    }

    // Update tab with new order and clear changed fields (server values applied)
    final updatedTab = tab.copyWith(
      order: updatedOrder,
      changedFields:
          const {}, // Clear local changes since server values are now applied
    );
    final newTabs = List<FastSaleTabState>.from(state.tabs);
    newTabs[tabIndex] = updatedTab;
    state = state.copyWith(tabs: newTabs);

    logger.d('[FastSale]', 'Order $orderId updated via WebSocket');
  }

  /// Remove a line from WebSocket notification (line deleted on server)
  void removeLineFromWebSocket(int orderId, int lineId) {
    final tabIndex = state.tabs.indexWhere((t) => t.orderId == orderId);
    if (tabIndex < 0) return; // Order not open in POS

    final tab = state.tabs[tabIndex];
    final lineIndex = tab.lines.indexWhere((l) => l.id == lineId);
    if (lineIndex < 0) return; // Line not in this tab

    final newLines = List<SaleOrderLine>.from(tab.lines);
    newLines.removeAt(lineIndex);

    // Adjust selected line index if needed
    int newSelectedIndex = tab.selectedLineIndex;
    if (tab.selectedLineIndex >= lineIndex) {
      newSelectedIndex = (tab.selectedLineIndex - 1).clamp(
        -1,
        newLines.length - 1,
      );
    }

    final updatedTab = tab.copyWith(
      lines: newLines,
      selectedLineIndex: newSelectedIndex,
      linesVersion: tab.linesVersion + 1,
    );

    final newTabs = List<FastSaleTabState>.from(state.tabs);
    newTabs[tabIndex] = updatedTab;
    state = state.copyWith(tabs: newTabs);

    logger.d(
      '[FastSale]',
      'Line $lineId removed via WebSocket (version: ${updatedTab.linesVersion})',
    );
  }

  /// Check if an order is currently open in POS
  bool hasOrderOpen(int orderId) {
    return state.tabs.any((t) => t.orderId == orderId);
  }

  // ============================================================
  // CONFLICT RESOLUTION
  // ============================================================

  /// Accept server changes and discard local modifications
  ///
  /// This clears the conflict state and refreshes the order from server.
  Future<void> acceptServerChanges() async {
    final activeTab = state.activeTab;
    if (activeTab == null || !activeTab.hasConflict) return;

    logger.d(
      '[FastSale]',
      'Accepting server changes for order ${activeTab.orderId}',
    );

    // Clear conflict state
    final updatedTab = activeTab.copyWith(
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
      changedFields: const {},
      modifiedLineIds: const {},
      hasChanges: false,
    );

    _updateActiveTab(updatedTab);

    // Optionally reload from server for fresh data
    if (activeTab.orderId > 0) {
      await _reloadCurrentTabFromServer();
    }
  }

  /// Keep local changes and dismiss conflict notification
  ///
  /// User will need to re-save to push local changes to server.
  void keepLocalChanges() {
    final activeTab = state.activeTab;
    if (activeTab == null || !activeTab.hasConflict) return;

    logger.d(
      '[FastSale]',
      'Keeping local changes for order ${activeTab.orderId}',
    );

    // Clear conflict state but keep hasChanges flag
    final updatedTab = activeTab.copyWith(
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
    );

    _updateActiveTab(updatedTab);
  }

  /// Clear conflict state without any other action
  void clearConflict() {
    final activeTab = state.activeTab;
    if (activeTab == null) return;

    final updatedTab = activeTab.copyWith(
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
    );

    _updateActiveTab(updatedTab);
  }

  /// Track a field change for conflict detection
  ///
  /// Call this when modifying order header fields.
  void trackFieldChange(String fieldName, dynamic oldValue, dynamic newValue) {
    final activeTab = state.activeTab;
    if (activeTab == null) return;

    final newChangedFields = Map<String, dynamic>.from(activeTab.changedFields);
    newChangedFields[fieldName] = {'old': oldValue, 'new': newValue};

    final updatedTab = activeTab.copyWith(
      changedFields: newChangedFields,
      hasChanges: true,
    );

    _updateActiveTab(updatedTab);
  }

  /// Track a line modification for conflict detection
  ///
  /// Call this when modifying a line locally.
  void trackLineModification(int lineId) {
    final activeTab = state.activeTab;
    if (activeTab == null || lineId < 0) return; // Don't track new lines

    final newModifiedIds = Set<int>.from(activeTab.modifiedLineIds)
      ..add(lineId);

    final updatedTab = activeTab.copyWith(
      modifiedLineIds: newModifiedIds,
      hasChanges: true,
    );

    _updateActiveTab(updatedTab);
  }

  /// Clear all tracked changes (e.g., after successful save)
  void clearTrackedChanges() {
    final activeTab = state.activeTab;
    if (activeTab == null) return;

    final updatedTab = activeTab.copyWith(
      changedFields: const {},
      modifiedLineIds: const {},
      hasChanges: false,
      hasConflict: false,
      conflicts: null,
      conflictMessage: null,
    );

    _updateActiveTab(updatedTab);
  }

  /// Reload current tab from server
  Future<void> _reloadCurrentTabFromServer() async {
    final activeTab = state.activeTab;
    if (activeTab == null || activeTab.orderId < 0) return;

    await reloadActiveOrder();
  }
}
