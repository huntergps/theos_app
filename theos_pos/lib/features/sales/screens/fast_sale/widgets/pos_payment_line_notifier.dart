import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../../core/database/repositories/repository_providers.dart';
import '../../../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper, PartnerBank, CreditIssue;
import '../../../services/payment_line_local_service.dart';
import 'pos_order_tabs.dart' show orderPendingSyncProvider;

/// Notifier for managing payment lines by order
class POSPaymentLinesByOrderNotifier extends Notifier<Map<int, List<PaymentLine>>> {
  /// Counter for generating temporary negative IDs (like SaleOrderLine)
  static int _tempIdCounter = -1;

  /// Generate a temporary negative ID for local-only lines
  static int getNextTempId() => _tempIdCounter--;

  PaymentLineLocalService get _localService =>
      PaymentLineLocalService(ref.read(appDatabaseProvider));

  @override
  Map<int, List<PaymentLine>> build() => {};

  /// Add a payment line for a specific order (also persists to DB and syncs to Odoo)
  Future<void> addLine(int orderId, PaymentLine line) async {
    final currentLines = state[orderId] ?? [];
    state = {...state, orderId: [...currentLines, line]};

    // Use SalesRepository for offline-first sync (same as sale.order.line)
    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo != null) {
      await salesRepo.createPaymentLine(orderId, {
        'id': line.id,
        'line_uuid': line.lineUuid,
        'payment_type': 'inbound',
        'journal_id': line.journalId,
        'journal_name': line.journalName,
        'journal_type': line.journalType,
        'payment_method_line_id': line.paymentMethodLineId,
        'payment_method_code': line.paymentMethodCode,
        'payment_method_name': line.paymentMethodName,
        'amount': line.amount,
        'date': line.date,
        'payment_reference': line.reference,
        'credit_note_id': line.creditNoteId,
        'credit_note_name': line.creditNoteName,
        'advance_id': line.advanceId,
        'advance_name': line.advanceName,
        'card_type': line.cardType?.name,
        'card_brand_id': line.cardBrandId,
        'card_brand_name': line.cardBrandName,
        'card_deadline_id': line.cardDeadlineId,
        'card_deadline_name': line.cardDeadlineName,
        'lote_id': line.loteId,
        'lote_name': line.loteName,
        'bank_id': line.bankId,
        'bank_name': line.bankName,
        'partner_bank_id': line.partnerBankId,
        'partner_bank_name': line.partnerBankName,
        'effective_date': line.effectiveDate,
        'bank_reference_date': line.voucherDate,
      });
      // Refresh the pending sync counter
      ref.invalidate(orderPendingSyncProvider(orderId));
    } else {
      // Fallback to local-only save if repository not available
      await _localService.saveLineToDb(orderId, line);
    }
  }

  /// Remove a payment line by ID from a specific order (also syncs to Odoo)
  /// Follows the same pattern as SaleOrderLine - uses ID as primary identifier
  Future<void> removeLine(int orderId, int lineId) async {
    // Find the line before removing
    final currentLines = state[orderId] ?? [];
    final lineToRemove = currentLines.where((l) => l.id == lineId).firstOrNull;

    // Update state immediately for responsive UI
    state = {...state, orderId: currentLines.where((l) => l.id != lineId).toList()};

    // Use SalesRepository for offline-first sync (same as sale.order.line)
    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo != null) {
      // Use ID directly - positive = Odoo ID, negative = local only
      await salesRepo.deletePaymentLine(
        orderId,
        odooId: lineId > 0 ? lineId : null,
        uuid: lineToRemove?.lineUuid,
      );
      // Refresh the pending sync counter
      ref.invalidate(orderPendingSyncProvider(orderId));
    } else {
      // Fallback to local-only delete if repository not available
      await _localService.removeLineFromDb(orderId, lineId);
    }
  }

  /// Clear all payment lines for a specific order (also syncs deletion to Odoo)
  /// Follows the same pattern as removeLine - syncs each line deletion to Odoo
  Future<void> clear(int orderId) async {
    // Get all lines before clearing
    final linesToRemove = List<PaymentLine>.from(state[orderId] ?? []);

    // Update state immediately for responsive UI
    final newState = Map<int, List<PaymentLine>>.from(state);
    newState.remove(orderId);
    state = newState;

    // Use SalesRepository for offline-first sync (same pattern as removeLine)
    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo != null) {
      // Delete each line through the repository (handles Odoo sync)
      for (final line in linesToRemove) {
        await salesRepo.deletePaymentLine(
          orderId,
          odooId: line.id > 0 ? line.id : null,
          uuid: line.lineUuid,
        );
      }
      // Refresh the pending sync counter
      ref.invalidate(orderPendingSyncProvider(orderId));
      logger.d('[PaymentProvider]', 'Cleared ${linesToRemove.length} payment lines (synced to Odoo) for order $orderId');
    } else {
      // Fallback to local-only clear if repository not available
      await _localService.clearLinesFromDb(orderId);
    }
  }

  /// Clear all payment lines for all orders
  void clearAll() {
    state = {};
  }

  /// Get lines for a specific order
  List<PaymentLine> getLines(int orderId) => state[orderId] ?? [];

  /// Get total paid amount for a specific order
  double totalPaid(int orderId) =>
      (state[orderId] ?? []).fold(0.0, (sum, l) => sum + l.amount);

  /// Set all payment lines for an order from server (WebSocket sync)
  void setLinesFromServer(int orderId, List<PaymentLine> lines) {
    state = {...state, orderId: lines};
  }

  /// Load payment lines from local database for an order
  Future<void> loadFromDb(int orderId) async {
    final lines = await _localService.loadFromDb(orderId);

    if (lines.isEmpty) {
      logger.d('[PaymentProvider]', 'No payment lines in DB for order $orderId');
      return;
    }

    state = {...state, orderId: lines};
    logger.i('[PaymentProvider]', 'Loaded ${lines.length} payment lines from DB for order $orderId');
  }

  /// Sync payment lines from Odoo (if online) and then load from local DB
  /// This ensures we have the latest data from server while maintaining offline-first pattern
  Future<void> syncAndLoad(int orderId) async {
    // First, try to sync from Odoo if online
    final salesRepo = ref.read(salesRepositoryProvider);
    if (salesRepo != null && salesRepo.isOnline) {
      try {
        await salesRepo.syncPaymentLinesFromOdoo(orderId);
        logger.d('[PaymentProvider]', 'Synced payment lines from Odoo for order $orderId');
      } catch (e) {
        logger.w('[PaymentProvider]', 'Failed to sync from Odoo (will use local): $e');
      }
    }
    // Then load from local DB (includes synced data if sync succeeded)
    await loadFromDb(orderId);
  }
}
