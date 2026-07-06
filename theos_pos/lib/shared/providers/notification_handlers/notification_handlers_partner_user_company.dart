part of '../notification_provider.dart';

// ============================================================
// PARTNER / USER / COMPANY — WebSocket Sync Handlers
// ============================================================
//
// Extraído de notification_provider.dart (refactor de descomposición,
// plan aprobado por software-architect). Cero cambio de comportamiento:
// los métodos se movieron tal cual, solo cambia su ubicación física.

mixin _PartnerUserCompanyNotificationHandlers {
  /// Provisto por [NotificationCounterNotifier] (via `Notifier<T>`).
  Ref get ref;

  /// Provisto por [NotificationCounterNotifier].
  AppDatabase get _db;

  /// Handle partner updated notification
  /// Syncs the partner from Odoo and updates all denormalized partner fields in sale_orders
  /// This ensures that when customer data changes, all related sale orders show the new values
  Future<void> _handlePartnerUpdated(
    int partnerId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      if (catalogRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ CatalogSyncRepository not available for partner sync',
        );
        return;
      }

      final action = payload['action'] as String?;

      if (action == 'deleted') {
        // Partner deleted - we don't remove from local DB since sale orders may still reference it
        logger.d(
          '[NotificationProvider] 👤 Partner $partnerId deleted in Odoo (keeping local copy for history)',
        );
        return;
      }

      // Sync the partner from Odoo (this updates res_partner table)
      // Returns PartnerSyncData with all fields: name, vat, street, phone, email, avatar
      final partnerData = await catalogRepo.syncSinglePartner(partnerId);

      // Update credit fields from WebSocket payload (they come in 'values')
      // This is more efficient than making another RPC call
      final values = payload['values'] as Map<String, dynamic>?;
      if (values != null) {
        await _updatePartnerCreditFields(partnerId, values);
      }

      if (partnerData != null) {
        // Update all denormalized partner fields in sale_orders with this partner
        final updatedOrders = await catalogRepo.updateSaleOrdersPartnerFields(
          partnerId,
          name: partnerData.name,
          vat: partnerData.vat,
          street: partnerData.street,
          phone: partnerData.phone,
          email: partnerData.email,
          avatar: partnerData.avatar,
        );

        if (updatedOrders > 0) {
          // Update form provider if currently viewing a sale order with this partner
          // Use granular update instead of full refresh to avoid rebuilding entire form
          final formState = ref.read(saleOrderFormProvider);
          if (formState.order?.partnerId == partnerId) {
            ref
                .read(saleOrderFormProvider.notifier)
                .updatePartnerFieldsOnly(
                  partnerId,
                  name: partnerData.name,
                  vat: partnerData.vat,
                  street: partnerData.street,
                  phone: partnerData.phone,
                  email: partnerData.email,
                  avatar: partnerData.avatar,
                );
          }

          logger.d(
            '[NotificationProvider] ✅ Partner $partnerId synced, $updatedOrders sale orders updated: '
            'name=${partnerData.name}, vat=${partnerData.vat}, street=${partnerData.street}, '
            'phone=${partnerData.phone}, email=${partnerData.email}, avatar=${partnerData.avatar != null ? '(${partnerData.avatar!.length} chars)' : 'null'}',
          );
        } else {
          logger.d(
            '[NotificationProvider] ✅ Partner $partnerId synced (no sale orders to update)',
          );
        }
      }
    } catch (e) {
      logger.d('[NotificationProvider] ❌ Error handling partner update: $e');
    }
  }

  /// Update partner credit fields from WebSocket payload values
  ///
  /// The WebSocket notification includes credit data in 'values':
  /// - credit_limit, credit, credit_to_invoice
  /// - allow_over_credit, use_partner_credit_limit, total_overdue, unpaid_invoices_count
  Future<void> _updatePartnerCreditFields(
    int partnerId,
    Map<String, dynamic> values,
  ) async {
    try {
      final creditLimit = _parseDouble(values['credit_limit']);
      final credit = _parseDouble(values['credit']);
      final creditToInvoice = _parseDouble(values['credit_to_invoice']);
      final allowOverCredit = values['allow_over_credit'] == true;
      final usePartnerCreditLimit = values['use_partner_credit_limit'] == true;
      final totalOverdue = _parseDouble(values['total_overdue']);
      final overdueInvoicesCount = values['unpaid_invoices_count'] as int? ?? 0;

      // Only update if we have credit data
      if (creditLimit == null && credit == null && totalOverdue == null) {
        return;
      }

      // Calculate derived fields only if credit control is enabled
      double? creditAvailable;
      double? creditUsagePercentage;
      bool creditExceeded = false;

      if (usePartnerCreditLimit && creditLimit != null && creditLimit > 0) {
        final creditUsed = (credit ?? 0) + (creditToInvoice ?? 0);
        creditAvailable = creditLimit - creditUsed;
        creditUsagePercentage = (creditUsed / creditLimit) * 100;
        creditExceeded = creditAvailable < 0;
      }

      // Update the database directly
      final db = _db;
      await (db.update(db.resPartner)
            ..where((tbl) => tbl.odooId.equals(partnerId)))
          .write(
        ResPartnerCompanion(
          creditLimit: Value(creditLimit ?? 0.0),
          credit: Value(credit ?? 0.0),
          creditToInvoice: Value(creditToInvoice ?? 0.0),
          allowOverCredit: Value(allowOverCredit),
          usePartnerCreditLimit: Value(usePartnerCreditLimit),
          totalOverdue: Value(totalOverdue ?? 0.0),
          unpaidInvoicesCount: Value(overdueInvoicesCount),
          creditAvailable: Value(creditAvailable),
          creditUsagePercentage: Value(creditUsagePercentage),
          creditExceeded: Value(creditExceeded),
          creditLastSyncDate: Value(DateTime.now()),
        ),
      );

      logger.d(
        '[NotificationProvider] 💳 Partner $partnerId credit updated: '
        'limit=$creditLimit, credit=$credit, available=$creditAvailable, '
        'overdue=$totalOverdue, exceeded=$creditExceeded, useCredit=$usePartnerCreditLimit',
      );
    } catch (e) {
      logger.d('[NotificationProvider] ❌ Error updating partner credit: $e');
    }
  }

  /// Parse dynamic value to double
  double? _parseDouble(dynamic val) {
    if (val == null || val == false) return null;
    if (val is double) return val;
    if (val is int) return val.toDouble();
    if (val is String) return double.tryParse(val);
    return null;
  }

  /// Handle user updated notification
  /// Syncs the user from Odoo and updates all denormalized userName fields in sale_orders and activities
  Future<void> _handleUserUpdated(
    int userId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      if (catalogRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ CatalogSyncRepository not available for user sync',
        );
        return;
      }

      final action = payload['action'] as String?;

      if (action == 'deleted') {
        // User deleted - we don't remove from local DB since sale orders may still reference it
        logger.d(
          '[NotificationProvider] 👤 User $userId deleted in Odoo (keeping local copy for history)',
        );
        return;
      }

      // Check if permissions (group_ids) changed
      final changedFields = payload['changed_fields'];
      List<String> fieldsToCheck = [];
      if (changedFields is List) {
        fieldsToCheck = changedFields.map((e) => e.toString()).toList();
      }

      final groupsChanged = fieldsToCheck.contains('group_ids') ||
          fieldsToCheck.contains('groups_id') ||
          fieldsToCheck.contains('all_group_ids');

      // If groups changed, sync them to local database
      if (groupsChanged) {
        try {
          await catalogRepo.syncUserGroups(userId);
          logger.i(
            '[NotificationProvider]',
            'Synced group memberships for user $userId',
          );
        } catch (e) {
          logger.d('[NotificationProvider] Failed to sync user groups: $e');
        }
      }

      // Refresh current user's permissions if it's them
      // IMPORTANT: User.id is the Odoo ID - userId from WebSocket is Odoo ID
      final currentUser = ref.read(userProvider);
      if (currentUser != null && currentUser.id == userId && groupsChanged) {
        logger.i(
          '[NotificationProvider]',
          'Permissions changed for current user - Refreshing user data...',
        );
        ref.read(userProvider.notifier).fetchUser();
      }

      final userData = await catalogRepo.syncSingleUser(userId);

      if (userData != null) {
        // Update denormalized userName in sale_orders
        final updatedOrders = await catalogRepo.updateSaleOrdersUserName(
          userId,
          userData.name,
        );

        // Update denormalized userName in activities
        final updatedActivities = await catalogRepo.updateActivitiesUserName(
          userId,
          userData.name,
        );

        if (updatedOrders > 0 || updatedActivities > 0) {
          // Invalidate activities provider if activities were updated
          if (updatedActivities > 0) {
            ref.invalidate(activitiesProvider);
          }

          logger.d(
            '[NotificationProvider] ✅ User $userId synced, $updatedOrders sale orders and $updatedActivities activities updated: '
            'name=${userData.name}',
          );
        } else {
          logger.d(
            '[NotificationProvider] ✅ User $userId synced (no sale orders or activities to update)',
          );
        }
      }
    } catch (e) {
      logger.d('[NotificationProvider] ❌ Error handling user update: $e');
    }
  }

  /// Handle company update notification from Odoo WebSocket
  /// Updates company config in local database and invalidates providers
  Future<void> _handleCompanyUpdated(
    int companyId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final action = payload['action'] as String?;

      // Skip deleted companies
      if (action == 'deleted') {
        logger.d(
          '[NotificationProvider] 🏢 Company $companyId was deleted, skipping',
        );
        return;
      }

      // Get values from WebSocket payload
      final values = payload['values'] as Map<String, dynamic>?;

      // Update company config in local database from WebSocket payload
      if (values != null && values.isNotEmpty) {
        await companyManager.updateCompanyConfigFromWebSocket(
          companyId,
          values,
        );
        logger.d(
          '[NotificationProvider] ✅ Company $companyId config updated in database',
        );
      }

      // Update denormalized company_name field in sale_orders
      final companyName = values?['name'] as String? ??
                          payload['company_name'] as String?;

      if (companyName != null) {
        final catalogRepo = ref.read(catalogSyncRepositoryProvider);
        if (catalogRepo != null) {
          final updatedOrders = await catalogRepo.updateSaleOrdersCompanyName(
            companyId,
            companyName,
          );

          if (updatedOrders > 0) {
            logger.d(
              '[NotificationProvider] ✅ Company $companyId: $updatedOrders sale orders updated',
            );
          }
        }
      }

      // Invalidate company config providers to refresh with new values from database
      ref.invalidate(currentCompanyProvider);

      logger.d(
        '[NotificationProvider] ✅ Company $companyId config invalidated',
      );
    } catch (e) {
      logger.d('[NotificationProvider] ❌ Error handling company update: $e');
    }
  }
}
