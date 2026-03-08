import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/repositories/repository_providers.dart';
import '../../../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, PartnerBank, CreditIssue;
import '../../../services/withhold_line_local_service.dart';
import 'pos_order_tabs.dart' show orderPendingSyncProvider;

/// Notifier for managing withhold lines by order
class POSWithholdLinesByOrderNotifier extends Notifier<Map<int, List<WithholdLine>>> {
  WithholdLineLocalService get _localService =>
      WithholdLineLocalService(ref.read(appDatabaseProvider));

  @override
  Map<int, List<WithholdLine>> build() => {};

  /// Add a withhold line for a specific order (also persists to DB and syncs to Odoo)
  Future<void> addLine(int orderId, WithholdLine line) async {
    final currentLines = state[orderId] ?? [];
    state = {...state, orderId: [...currentLines, line]};

    // Use SalesRepository for offline-first sync (same as sale.order.line)
    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo != null) {
      await salesRepo.createWithholdLine(orderId, {
        'uuid': line.lineUuid,
        'tax_id': line.taxId,
        'tax_name': line.taxName,
        'tax_percent': line.taxPercent,
        'taxsupport_code': line.taxSupportCode?.code,
        'base': line.base,
        'amount': line.amount,
        'notes': line.notes,
      });
      // Refresh the pending sync counter
      ref.invalidate(orderPendingSyncProvider(orderId));
    } else {
      // Fallback to local-only save if repository not available
      await _localService.saveLineToDb(orderId, line);
    }
  }

  /// Remove a withhold line by uuid from a specific order (also syncs to Odoo)
  Future<void> removeLine(int orderId, String uuid) async {
    // Find the line to get its Odoo ID before removing
    final currentLines = state[orderId] ?? [];
    final lineToRemove = currentLines.where((l) => l.lineUuid == uuid).firstOrNull;
    final odooId = lineToRemove?.id;

    // Update state immediately for responsive UI
    state = {...state, orderId: currentLines.where((l) => l.lineUuid != uuid).toList()};

    // Use SalesRepository for offline-first sync (same as sale.order.line)
    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo != null) {
      await salesRepo.deleteWithholdLine(orderId, odooId: odooId, uuid: uuid);
      // Refresh the pending sync counter
      ref.invalidate(orderPendingSyncProvider(orderId));
    } else {
      // Fallback to local-only delete if repository not available
      await _localService.removeLineFromDb(orderId, uuid);
    }
  }

  /// Clear all withhold lines for a specific order (also syncs deletion to Odoo)
  /// Follows the same pattern as removeLine - syncs each line deletion to Odoo
  Future<void> clear(int orderId) async {
    // Get all lines before clearing
    final linesToRemove = List<WithholdLine>.from(state[orderId] ?? []);

    // Update state immediately for responsive UI
    final newState = Map<int, List<WithholdLine>>.from(state);
    newState.remove(orderId);
    state = newState;

    // Use SalesRepository for offline-first sync (same pattern as removeLine)
    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo != null) {
      // Delete each line through the repository (handles Odoo sync)
      for (final line in linesToRemove) {
        await salesRepo.deleteWithholdLine(
          orderId,
          odooId: line.id,
          uuid: line.lineUuid,
        );
      }
      // Refresh the pending sync counter
      ref.invalidate(orderPendingSyncProvider(orderId));
      logger.d('[WithholdProvider]', 'Cleared ${linesToRemove.length} withhold lines (synced to Odoo) for order $orderId');
    } else {
      // Fallback to local-only clear if repository not available
      await _localService.clearLinesFromDb(orderId);
    }
  }

  /// Clear all withhold lines for all orders
  void clearAll() {
    state = {};
  }

  /// Get lines for a specific order
  List<WithholdLine> getLines(int orderId) => state[orderId] ?? [];

  /// Get total withheld amount for a specific order
  double totalWithheld(int orderId) =>
      (state[orderId] ?? []).fold(0.0, (sum, l) => sum + l.amount);

  /// Set all withhold lines for an order from server (WebSocket sync)
  void setLinesFromServer(int orderId, List<WithholdLine> lines) {
    state = {...state, orderId: lines};
  }

  /// Load withhold lines from local database for an order
  Future<void> loadFromDb(int orderId) async {
    final lines = await _localService.loadFromDb(orderId);

    if (lines.isEmpty) {
      // No lines in DB, check if we have in-memory lines that should be kept
      if (state[orderId]?.isEmpty ?? true) {
        state = {...state, orderId: <WithholdLine>[]};
      }
      return;
    }

    state = {...state, orderId: lines};
    logger.d('[WithholdProvider]', 'Loaded ${lines.length} withhold lines from DB for order $orderId');
  }

  /// Sync withhold lines from Odoo (if online) and then load from local DB
  /// This ensures we have the latest data from server while maintaining offline-first pattern
  Future<void> syncAndLoad(int orderId) async {
    // First, try to sync from Odoo if online
    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo != null && salesRepo.isOnline) {
      try {
        await salesRepo.syncWithholdLinesFromOdoo(orderId);
        logger.d('[WithholdProvider]', 'Synced withhold lines from Odoo for order $orderId');
      } catch (e) {
        logger.w('[WithholdProvider]', 'Failed to sync from Odoo (will use local): $e');
      }
    }
    // Then load from local DB (includes synced data if sync succeeded)
    await loadFromDb(orderId);
  }
}
