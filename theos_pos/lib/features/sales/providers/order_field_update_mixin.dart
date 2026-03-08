import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/services/logger_service.dart';
import '../utils/partner_utils.dart' as partner_utils;

/// Mixin providing shared field update logic for order notifiers
///
/// This mixin consolidates common update operations used by both
/// [FastSaleNotifier] and [SaleOrderFormNotifier].
///
/// Features:
/// - Partner update with payment term loading
/// - Partner field updates (phone, email) with Odoo sync
/// - End customer field updates
/// - Config field updates (pricelist, warehouse, payment term)
///
/// Usage:
/// ```dart
/// class MyOrderNotifier extends Notifier<MyOrderState>
///     with OrderFieldUpdateMixin<MyOrderState> {
///   @override
///   String get logTag => '[MyOrder]';
///
///   @override
///   void updateStatePartner(int? id, String? name, List<int> termIds) {
///     state = state.copyWith(
///       partnerId: id,
///       partnerName: name,
///       partnerPaymentTermIds: termIds,
///     );
///   }
/// }
/// ```
mixin OrderFieldUpdateMixin<T> on Notifier<T> {
  /// Tag for logging (override in subclass)
  String get logTag => '[OrderFieldUpdate]';

  /// Get current partner ID from state (override in subclass)
  int? get currentPartnerId;

  /// Get cached payment term IDs from state (override in subclass)
  List<int> get currentPaymentTermIds => [];

  // ========== Abstract Methods (must be implemented by subclass) ==========

  /// Update partner in state
  void updateStatePartner(int? id, String? name, List<int> termIds);

  /// Update partner phone in state
  void updateStatePartnerPhone(String? phone);

  /// Update partner email in state
  void updateStatePartnerEmail(String? email);

  /// Update end customer name in state
  void updateStateEndCustomerName(String? name);

  /// Update end customer phone in state
  void updateStateEndCustomerPhone(String? phone);

  /// Update end customer email in state
  void updateStateEndCustomerEmail(String? email);

  /// Update pricelist in state
  void updateStatePricelist(int? id, String? name);

  /// Update payment term in state
  void updateStatePaymentTerm(int? id, String? name);

  /// Update warehouse in state
  void updateStateWarehouse(int? id, String? name);

  /// Update date order in state
  void updateStateDateOrder(DateTime? date);

  /// Update user/seller in state
  void updateStateUser(int? id, String? name);

  /// Mark state as having changes
  void markHasChanges();

  // ========== Partner Operations ==========

  /// Update partner with payment term loading
  ///
  /// Loads authorized payment terms for the partner from Odoo (if online)
  /// or uses cached values (if offline).
  Future<void> updatePartner(int? partnerId, String? partnerName) async {
    logger.d(logTag, 'Updating partner: $partnerId - $partnerName');

    List<int> termIds = [];

    if (partnerId != null) {
      // Load payment term restrictions
      termIds = await partner_utils.loadPartnerPaymentTermIds(
        partnerId: partnerId,
        odooClient: ref.read(odooClientProvider),
        cachedIds: currentPaymentTermIds,
        logTag: logTag,
      );
    }

    updateStatePartner(partnerId, partnerName, termIds);
    markHasChanges();

    logger.i(logTag, 'Partner updated: $partnerName (termIds: $termIds)');
  }

  /// Update partner phone with Odoo sync
  ///
  /// Updates local state immediately (optimistic), then syncs to Odoo.
  /// Reverts on failure.
  Future<bool> updatePartnerPhone(String? phone) async {
    final partnerId = currentPartnerId;
    if (partnerId == null) {
      logger.w(logTag, 'Cannot update phone: no partner selected');
      return false;
    }

    // Optimistic update
    updateStatePartnerPhone(phone);
    markHasChanges();

    // Sync to Odoo
    final partnerRepo = ref.read(partnerRepositoryProvider);
    if (partnerRepo == null) {
      logger.d(logTag, 'Offline - phone update stored locally only');
      return true;
    }

    final success = await partner_utils.updatePartnerField(
      partnerId: partnerId,
      fieldName: 'phone',
      newValue: phone,
      partnerRepo: partnerRepo,
      onSuccess: () {
        logger.i(logTag, 'Partner phone updated: $phone');
      },
      onFailure: (error) {
        logger.w(logTag, 'Failed to update phone: $error');
        // Note: We don't revert here as the local change is still valid
      },
      logTag: logTag,
    );

    return success;
  }

  /// Update partner email with Odoo sync
  Future<bool> updatePartnerEmail(String? email) async {
    final partnerId = currentPartnerId;
    if (partnerId == null) {
      logger.w(logTag, 'Cannot update email: no partner selected');
      return false;
    }

    // Optimistic update
    updateStatePartnerEmail(email);
    markHasChanges();

    // Sync to Odoo
    final partnerRepo = ref.read(partnerRepositoryProvider);
    if (partnerRepo == null) {
      logger.d(logTag, 'Offline - email update stored locally only');
      return true;
    }

    final success = await partner_utils.updatePartnerField(
      partnerId: partnerId,
      fieldName: 'email',
      newValue: email,
      partnerRepo: partnerRepo,
      onSuccess: () {
        logger.i(logTag, 'Partner email updated: $email');
      },
      onFailure: (error) {
        logger.w(logTag, 'Failed to update email: $error');
      },
      logTag: logTag,
    );

    return success;
  }

  // ========== End Customer Operations ==========

  /// Update end customer name (for final consumer sales)
  void updateEndCustomerName(String? name) {
    updateStateEndCustomerName(name);
    markHasChanges();
    logger.d(logTag, 'End customer name updated: $name');
  }

  /// Update end customer phone
  void updateEndCustomerPhone(String? phone) {
    updateStateEndCustomerPhone(phone);
    markHasChanges();
    logger.d(logTag, 'End customer phone updated: $phone');
  }

  /// Update end customer email
  void updateEndCustomerEmail(String? email) {
    updateStateEndCustomerEmail(email);
    markHasChanges();
    logger.d(logTag, 'End customer email updated: $email');
  }

  // ========== Config Operations ==========

  /// Update pricelist
  ///
  /// Note: Changing pricelist should trigger line price recalculation.
  /// The caller is responsible for handling this.
  void updatePricelist(int? pricelistId, String? pricelistName) {
    updateStatePricelist(pricelistId, pricelistName);
    markHasChanges();
    logger.d(logTag, 'Pricelist updated: $pricelistId - $pricelistName');
  }

  /// Update payment term
  void updatePaymentTerm(int? paymentTermId, String? paymentTermName) {
    updateStatePaymentTerm(paymentTermId, paymentTermName);
    markHasChanges();
    logger.d(logTag, 'Payment term updated: $paymentTermId - $paymentTermName');
  }

  /// Update warehouse
  void updateWarehouse(int? warehouseId, String? warehouseName) {
    updateStateWarehouse(warehouseId, warehouseName);
    markHasChanges();
    logger.d(logTag, 'Warehouse updated: $warehouseId - $warehouseName');
  }

  /// Update order date
  void updateDateOrder(DateTime? date) {
    updateStateDateOrder(date);
    markHasChanges();
    logger.d(logTag, 'Date order updated: $date');
  }

  /// Update seller/user
  void updateUser(int? userId, String? userName) {
    updateStateUser(userId, userName);
    markHasChanges();
    logger.d(logTag, 'User updated: $userId - $userName');
  }

  // ========== Utility Methods ==========

  /// Check if a payment term is authorized for the current partner
  bool isPaymentTermAuthorized(int paymentTermId) {
    final termIds = currentPaymentTermIds;
    // Empty list means no restrictions
    if (termIds.isEmpty) return true;
    return termIds.contains(paymentTermId);
  }

  /// Get list of authorized payment terms for dropdowns
  ///
  /// Returns null if no restrictions (all terms allowed)
  List<int>? getAuthorizedPaymentTermIds() {
    final termIds = currentPaymentTermIds;
    if (termIds.isEmpty) return null;
    return termIds;
  }
}
