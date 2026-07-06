import 'dart:async';
import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../providers/user_provider.dart';
import '../providers/company_config_provider.dart' show currentCompanyProvider;
import '../models/notification_counter.dart';
import '../../core/database/providers.dart'
    show
        activitiesProvider,
        collectionConfigsProvider,
        currentSessionProvider,
        sessionByIdProvider,
        taxCalculatorProvider;
import '../../core/database/repositories/repository_providers.dart';
import '../../core/services/websocket/odoo_websocket_service.dart';
import '../../core/services/logger_service.dart';
import '../../features/sales/providers/providers.dart';
import '../../features/sales/screens/fast_sale/fast_sale_providers.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show AppDatabase, uomManager, Uom, UomType, companyManager, CompanyManagerBusiness, saleOrderLineManager, SaleOrderLineManagerBusiness;

// Re-export providers for invalidation
export '../../core/database/providers.dart'
    show activitiesProvider, collectionConfigsProvider;

// Import offlineSyncServiceProvider for offline queue processing

import 'package:odoo_sdk/odoo_sdk.dart' show toStringOrNull;
import '../../core/managers/manager_providers.dart' show appDatabaseProvider;
import 'package:drift/drift.dart' show Value, DoUpdate;
import 'package:theos_pos_core/theos_pos_core.dart'
    show SaleOrderLine, LineDisplayType,
         WithholdLine, WithholdType, TaxSupportCode,
         PaymentLine, PaymentLineType, CardType,
         ResPartnerCompanion,
         SaleOrderWithholdLineCompanion,
         SaleOrderPaymentLineCompanion,
         AccountCreditCardBrandCompanion,
         AccountCreditCardDeadlineCompanion,
         AccountCardLoteCompanion,
         AccountJournalCompanion,
         AccountPaymentMethodLineCompanion,
         AccountAdvanceCompanion,
         AccountCreditNoteCompanion,
         AccountMoveCompanion,
         AccountTaxCompanion,
         CashOutCompanion,
         CollectionSessionDepositCompanion,
         CollectionSessionCashCompanion,
         ProductCategoryCompanion;
import '../../features/sales/screens/fast_sale/widgets/pos_payment_tab.dart'
    show posWithholdLinesByOrderProvider, posPaymentLinesByOrderProvider, posAvailableJournalsProvider,
    posCardBrandsByJournalProvider, posCardDeadlinesProvider;

part 'notification_handlers/notification_handlers_catalog.dart';
part 'notification_handlers/notification_handlers_partner_user_company.dart';
part 'notification_handlers/notification_handlers_card_payment.dart';
part 'notification_handlers/notification_handlers_finance.dart';
part 'notification_handlers/notification_handlers_cash.dart';
part 'notification_handlers/notification_handlers_activity.dart';
part 'notification_handlers/notification_handlers_collection.dart';
part 'notification_handlers/notification_handlers_sale_order_lines.dart';
part 'notification_handlers/notification_handlers_sale_order.dart';
part 'notification_handlers/notification_handlers_withhold_payment.dart';

/// Provider for notification counters
final notificationCounterProvider =
    NotifierProvider<NotificationCounterNotifier, NotificationCounter>(
      () => NotificationCounterNotifier(),
    );

class NotificationCounterNotifier extends Notifier<NotificationCounter>
    with
        _CatalogNotificationHandlers,
        _PartnerUserCompanyNotificationHandlers,
        _CardPaymentNotificationHandlers,
        _FinanceNotificationHandlers,
        _CashNotificationHandlers,
        _ActivityNotificationHandlers,
        _CollectionNotificationHandlers,
        _SaleOrderLineNotificationHandlers,
        _SaleOrderNotificationHandlers,
        _WithholdPaymentNotificationHandlers {
  Timer? _pollTimer;
  StreamSubscription? _wsSubscription;
  StreamSubscription<OdooWebSocketEvent>? _notificationSubscription;
  StreamSubscription<OdooWebSocketEvent>? _eventSubscription;
  bool _disposed = false;

  @override
  AppDatabase get _db => ref.read(appDatabaseProvider);

  @override
  NotificationCounter build() {
    // Register dispose callback
    ref.onDispose(() {
      _disposed = true;
      _stopPolling();
      _wsSubscription?.cancel();
      _notificationSubscription?.cancel();
      _eventSubscription?.cancel();
    });
    _initialize();
    return const NotificationCounter();
  }

  /// Check if notifier is still active
  bool get mounted => !_disposed;

  /// Initialize: fetch counters, setup WebSocket and start polling
  Future<void> _initialize() async {
    await fetchCounters();
    _setupWebSocket(); // WebSocket enabled with session management
    _startPolling();

    // Process any pending offline operations at startup
    _processOfflineQueue();
  }

  /// Fetch notification counters from Odoo
  Future<void> fetchCounters() async {
    try {
      final activityRepo = ref.read(activityRepositoryProvider);
      // Fetch init_messaging data (inbox, starred, channels)
      final messagingData = await activityRepo.getNotificationCounters();

      // Fetch activities data
      final activityData = await activityRepo.getActivityCounters();

      if (messagingData != null) {
        final newState = NotificationCounter.fromOdoo({
          ...messagingData,
          if (activityData != null)
            'activityCounter': activityData['activityCounter'] ?? 0,
        });

        state = newState;
        logger.d(
          '[NotificationProvider] ✅ Counters updated: inbox=${newState.inboxCounter}, activities=${newState.activityCounter}',
        );
      }
    } catch (e) {
      logger.e('[NotificationProvider]', ' Error fetching counters: $e');
    }
  }

  /// Setup WebSocket to listen for real-time updates
  void _setupWebSocket() {
    try {
      final wsService = ref.read(odooWebSocketServiceProvider);

      // Don't call connect() here - MainScreen already handles the connection
      // Use the new stream-based listener (supports multiple listeners)
      final notifier = this;

      // Subscribe to typed events for handling various notification types
      _notificationSubscription = wsService.addEventListener((event) {
        if (event is OdooRawNotificationEvent) {
          final notification = {'type': event.type, 'payload': event.payload};
          logger.d('[NotificationProvider]', '🎯 Stream notification received!');
          logger.d(
            '[NotificationProvider] 🎯 Notification type: ${event.type}',
          );
          logger.d(
            '[NotificationProvider] 🎯 Notifier mounted: ${notifier.mounted}',
          );
          if (notifier.mounted) {
            notifier._handleWebSocketNotification(notification);
          } else {
            logger.d(
              '[NotificationProvider] ⚠️ Notifier is disposed, skipping notification',
            );
          }
        }
      });

      // Subscribe to typed event stream for connection events (reconnection)
      _eventSubscription = wsService.eventStream.listen((event) {
        if (event is OdooConnectionEvent && event.isReconnection && event.isConnected) {
          if (notifier.mounted) {
            notifier._processOfflineQueue();
          }
        }
      });

      logger.d(
        '[NotificationProvider] ✅ WebSocket notification stream listener registered',
      );
      logger.i('[NotificationProvider]', ' Notifier instance: $this');
    } catch (e) {
      logger.e('[NotificationProvider]', ' Error setting up WebSocket: $e');
    }
  }

  /// Process offline queue when connection is restored
  Future<void> _processOfflineQueue() async {
    // FIX 4: Guard via databaseHelperProvider (reactivo) en lugar de
    // DatabaseHelper.isInitialized (estático). Así tras un cambio de servidor,
    // databaseHelperProvider devuelve null y el guard funciona correctamente
    // con la nueva instancia de BD.
    if (ref.read(databaseHelperProvider) == null) {
      logger.d('[NotificationProvider]', 'DB not ready, skipping queue processing');
      return;
    }

    try {
      final syncService = ref.read(offlineSyncServiceProvider);
      if (syncService == null) {
        logger.w(
          '[NotificationProvider]',
          '⚠️ OfflineSyncService not available',
        );
        return;
      }

      logger.i(
        '[NotificationProvider]',
        '🔄 Processing offline queue after reconnection',
      );
      final result = await syncService.processQueue();

      if (result.synced > 0 || result.failed > 0) {
        logger.i(
          '[NotificationProvider]',
          '✅ Offline sync complete: ${result.synced} synced, ${result.failed} failed',
        );

      }
    } catch (e) {
      if (e.toString().contains('connection was closed')) {
        logger.d('[NotificationProvider]', 'DB connection closed (server switch), skipping');
      } else {
        logger.e('[NotificationProvider]', '❌ Error processing offline queue: $e');
      }
    }
  }

  /// Handle WebSocket notification
  void _handleWebSocketNotification(Map<String, dynamic> notification) {
    logger.d('[NotificationProvider]', '🎯 === HANDLER CALLED ===');
    logger.d('[NotificationProvider] 🔔 WebSocket notification: $notification');

    // Check notification type and update counters from payload (avoid HTTP calls)
    final type = notification['type'] as String?;
    final payload = notification['payload'] as Map<String, dynamic>?;

    if (type == 'mail.message/inbox' && payload != null) {
      // New message received in inbox - increment counter locally (NO HTTP CALL)
      // Odoo sends this when a NEW message is created, but doesn't include the counter
      final messageId = payload['message_id'] as int?;
      if (messageId != null) {
        final newCount = state.inboxCounter + 1;
        state = state.copyWith(inboxCounter: newCount);
        logger.d(
          '[NotificationProvider] 📬 New inbox message received (id: $messageId), counter: $newCount',
        );
      }
    } else if (type == 'mail.message/mark_as_read' && payload != null) {
      // Message marked as read - use exact counter from payload (NO HTTP CALL)
      // Odoo includes the updated counter in this notification
      final inboxCounter = payload['needaction_inbox_counter'] as int?;
      if (inboxCounter != null) {
        state = state.copyWith(inboxCounter: inboxCounter);
        logger.d(
          '[NotificationProvider] ✅ Inbox counter updated from WebSocket: $inboxCounter',
        );
      }
    } else if (type == 'mail.activity/updated' && payload != null) {
      // Activity created/deleted - apply count diff to current counter (NO HTTP CALL)
      final countDiff = payload['count_diff'] as int?;
      if (countDiff != null) {
        final newCount = (state.activityCounter + countDiff).clamp(0, 999999);
        state = state.copyWith(activityCounter: newCount);
        logger.d(
          '[NotificationProvider] ✅ Activity counter updated: $newCount (diff: $countDiff)',
        );
      }
    } else if (type == 'activity_created' && payload != null) {
      // Custom notification: New activity created - fetch from Odoo and update local DB
      final activityId = payload['id'] as int?;
      if (activityId != null) {
        logger.d(
          '[NotificationProvider] 🆕 Activity created notification: $activityId',
        );
        _handleActivityCreatedOrUpdated(activityId);
      }
    } else if (type == 'activity_updated' && payload != null) {
      // Custom notification: Activity updated - refresh from Odoo
      final activityId = payload['id'] as int?;
      final activityState = payload['state'] as String?;
      if (activityId != null) {
        // If state is 'done', the activity was marked as completed and deleted from Odoo
        // We should delete it locally instead of trying to refresh it
        if (activityState == 'done') {
          logger.d(
            '[NotificationProvider] ✅ Activity $activityId marked as done - deleting locally',
          );
          _handleActivityDeleted(activityId);
        } else {
          logger.d(
            '[NotificationProvider] 🔄 Activity updated notification: $activityId',
          );
          _handleActivityCreatedOrUpdated(activityId);
        }
      }
    } else if (type == 'activity_deleted' && payload != null) {
      // Custom notification: Activity deleted - remove from local DB
      final activityId = payload['id'] as int?;
      if (activityId != null) {
        logger.d(
          '[NotificationProvider] 🗑️ Activity deleted notification: $activityId',
        );
        _handleActivityDeleted(activityId);
      }
    } else if (type == 'mail.channel/new_message' && payload != null) {
      // Channel message received - increment unread counter (NO HTTP CALL)
      final channelId = payload['channel_id'] as int?;
      if (channelId != null) {
        final newCount = state.channelsUnreadCounter + 1;
        state = state.copyWith(channelsUnreadCounter: newCount);
        logger.d(
          '[NotificationProvider] ✅ Channel unread counter incremented: $newCount',
        );
      }
    } else if (type == 'session_created_with_uuid' && payload != null) {
      // Collection session created with UUID - update currentSessionProvider
      logger.d(
        '[NotificationProvider] 🆕 Session created with UUID notification received',
      );
      final sessionId = payload['collection_session_id'] as int?;
      final sessionUuid = payload['session_uuid'] as String?;
      final sessionName = payload['session_name'] as String?;

      if (sessionId != null && sessionUuid != null) {
        // Don't await - let it run in background
        _handleSessionCreatedWithUuid(
          sessionId: sessionId,
          sessionUuid: sessionUuid,
          sessionName: sessionName,
        );
      }
      _handleCollectionUpdate(sessionId: sessionId);
    } else if (type == 'session_created' && payload != null) {
      // Collection session created (legacy) - refresh configs
      logger.d(
        '[NotificationProvider] 🆕 Session created notification received',
      );
      final sessionId = payload['collection_session_id'] as int?;
      _handleCollectionUpdate(sessionId: sessionId);
    } else if (type == 'session_updated' && payload != null) {
      // Collection session updated - refresh configs and session state
      // Handles state transitions: open -> closing_control -> closed
      final sessionId = payload['collection_session_id'] as int?;
      final sessionState = payload['state'] as String?;
      logger.d(
        '[NotificationProvider] 🔄 Session updated notification: '
        'sessionId=$sessionId, state=$sessionState',
      );
      _handleCollectionUpdate(sessionId: sessionId);
    } else if (type == 'config_updated' && payload != null) {
      // Collection config updated - refresh configs to update dashboard
      logger.d(
        '[NotificationProvider] 🔄 Config updated notification received',
      );
      _handleCollectionUpdate();
    } else if (type == 'sale_order_created' && payload != null) {
      // Sale order created - refresh from Odoo
      final orderId = payload['id'] as int?;
      if (orderId != null) {
        logger.d(
          '[NotificationProvider] 🆕 Sale order created notification: $orderId',
        );
        _handleSaleOrderCreated(orderId, payload);
      }
    } else if (type == 'sale_order_updated' && payload != null) {
      // Sale order updated - handle with conflict resolution
      // Support both 'id' (direct) and 'order_id' (from line notifications)
      final orderId = payload['id'] as int? ?? payload['order_id'] as int?;
      if (orderId != null) {
        logger.d(
          '[NotificationProvider] 🔄 Sale order updated notification: $orderId',
        );
        _handleSaleOrderUpdated(orderId, payload);
      }
    } else if (type == 'sale_order_deleted' && payload != null) {
      // Sale order deleted
      final orderId = payload['id'] as int?;
      if (orderId != null) {
        logger.d(
          '[NotificationProvider] 🗑️ Sale order deleted notification: $orderId',
        );
        _handleSaleOrderDeleted(orderId, payload);
      }
    }
    // M7: Product/catalog update notifications
    else if (type == 'product_price_updated' && payload != null) {
      // Product price updated - refresh product from Odoo
      final productId = payload['product_id'] as int?;
      if (productId != null) {
        logger.d(
          '[NotificationProvider] 📦 Product price updated notification: $productId',
        );
        _handleProductPriceUpdated(productId, payload);
      }
    } else if (type == 'pricelist_item_updated' && payload != null) {
      // Pricelist item updated - refresh pricelist items from Odoo
      final action = payload['action'] as String?;
      final pricelistItemId = payload['pricelist_item_id'] as int?;
      if (pricelistItemId != null) {
        logger.d(
          '[NotificationProvider] 💰 Pricelist item $action notification: $pricelistItemId',
        );
        _handlePricelistItemUpdated(pricelistItemId, payload);
      }
    } else if (type == 'product_uom_updated' && payload != null) {
      // Product UoM updated - refresh UoM from Odoo (custom model with barcodes)
      final action = payload['action'] as String?;
      final uomId = payload['uom_id'] as int?;
      if (uomId != null) {
        logger.d(
          '[NotificationProvider] 📐 Product UoM $action notification: $uomId',
        );
        _handleProductUomUpdated(uomId, payload);
      }
    } else if (type == 'uom_uom_updated' && payload != null) {
      // Standard uom.uom updated - refresh standard UoM from Odoo
      final action = payload['action'] as String?;
      final uomId = payload['uom_id'] as int?;
      if (uomId != null) {
        logger.d(
          '[NotificationProvider] 📏 Standard UoM $action notification: $uomId',
        );
        _handleUomUomUpdated(uomId, payload);
      }
    } else if (type == 'partner_updated' && payload != null) {
      // Partner/customer updated - sync partner and update denormalized names
      final action = payload['action'] as String?;
      final partnerId = payload['partner_id'] as int?;
      if (partnerId != null) {
        logger.d(
          '[NotificationProvider] 👤 Partner $action notification: $partnerId',
        );
        _handlePartnerUpdated(partnerId, payload);
      }
    } else if (type == 'user_updated' && payload != null) {
      // User updated - sync user and update denormalized names
      final action = payload['action'] as String?;
      final userId = payload['user_id'] as int?;
      if (userId != null) {
        logger.d(
          '[NotificationProvider] 👤 User $action notification: $userId',
        );
        _handleUserUpdated(userId, payload);
      }
    } else if ((type == 'company_updated' || type == 'company_config_updated') && payload != null) {
      // Company updated - sync company and update denormalized names
      final action = payload['action'] as String?;
      final companyId = payload['company_id'] as int?;
      if (companyId != null) {
        logger.d(
          '[NotificationProvider] 🏢 Company $action notification ($type): $companyId',
        );
        _handleCompanyUpdated(companyId, payload);
      }
    } else if (type == 'stock_quant_updated' && payload != null) {
      // Stock quantity updated - update local stock by warehouse table
      final productId = payload['product_id'] as int?;
      final warehouseId = payload['warehouse_id'] as int?;
      if (productId != null && warehouseId != null) {
        logger.d(
          '[NotificationProvider] 📦 Stock update notification: '
          'product=$productId, warehouse=$warehouseId',
        );
        _handleStockQuantUpdated(payload);
      }
    }
    // Sale order line notifications (created/updated/deleted from Odoo)
    else if (type == 'sale_order_line_created' && payload != null) {
      final lineId = payload['id'] as int?;
      final orderId = payload['order_id'] as int?;
      if (lineId != null && orderId != null) {
        logger.d(
          '[NotificationProvider] 📝 Sale order line created: '
          'lineId=$lineId, orderId=$orderId',
        );
        _handleSaleOrderLineCreated(payload);
      }
    } else if (type == 'sale_order_line_updated' && payload != null) {
      final lineId = payload['id'] as int?;
      final orderId = payload['order_id'] as int?;
      if (lineId != null && orderId != null) {
        logger.d(
          '[NotificationProvider] 📝 Sale order line updated: '
          'lineId=$lineId, orderId=$orderId',
        );
        _handleSaleOrderLineUpdated(payload);
      }
    } else if (type == 'sale_order_line_deleted' && payload != null) {
      final lineId = payload['id'] as int?;
      final orderId = payload['order_id'] as int?;
      if (lineId != null) {
        logger.d(
          '[NotificationProvider] 🗑️ Sale order line deleted: '
          'lineId=$lineId, orderId=$orderId',
        );
        _handleSaleOrderLineDeleted(payload);
      }
    } else if (type == 'sale_order_withhold_updated' && payload != null) {
      final saleId = payload['sale_id'] as int?;
      final action = payload['action'] as String?;
      if (saleId != null) {
        logger.d(
          '[NotificationProvider] 💰 Sale order withhold updated: '
          'saleId=$saleId, action=$action',
        );
        _handleSaleOrderWithholdUpdated(payload);
      }
    } else if (type == 'sale_order_payment_updated' && payload != null) {
      final saleId = payload['sale_id'] as int?;
      final action = payload['action'] as String?;
      if (saleId != null) {
        logger.d(
          '[NotificationProvider] 💳 Sale order payment updated: '
          'saleId=$saleId, action=$action',
        );
        _handleSaleOrderPaymentUpdated(payload);
      }
    }
    // Card payment tables sync
    else if (type == 'card_brand_updated' && payload != null) {
      final action = payload['action'] as String?;
      final brandId = payload['brand_id'] as int?;
      if (brandId != null) {
        logger.d(
          '[NotificationProvider] 💳 Card brand $action: brandId=$brandId',
        );
        _handleCardBrandUpdated(brandId, action, payload);
      }
    } else if (type == 'card_deadline_updated' && payload != null) {
      final action = payload['action'] as String?;
      final deadlineId = payload['deadline_id'] as int?;
      if (deadlineId != null) {
        logger.d(
          '[NotificationProvider] 📅 Card deadline $action: deadlineId=$deadlineId',
        );
        _handleCardDeadlineUpdated(deadlineId, action, payload);
      }
    } else if (type == 'card_lote_updated' && payload != null) {
      final action = payload['action'] as String?;
      final loteId = payload['lote_id'] as int?;
      if (loteId != null) {
        logger.d(
          '[NotificationProvider] 🎫 Card lote $action: loteId=$loteId',
        );
        _handleCardLoteUpdated(loteId, action, payload);
      }
    } else if (type == 'journal_updated' && payload != null) {
      final action = payload['action'] as String?;
      final journalId = payload['journal_id'] as int?;
      if (journalId != null) {
        logger.d(
          '[NotificationProvider] 📒 Journal $action: journalId=$journalId',
        );
        _handleJournalUpdated(journalId, action, payload);
      }
    }
    // Payment method line sync
    else if (type == 'payment_method_line_updated' && payload != null) {
      final action = payload['action'] as String?;
      final lineId = payload['line_id'] as int?;
      if (lineId != null) {
        logger.d(
          '[NotificationProvider] 💳 PaymentMethodLine $action: lineId=$lineId',
        );
        _handlePaymentMethodLineUpdated(lineId, action, payload);
      }
    }
    // Advance sync
    else if (type == 'advance_updated' && payload != null) {
      final action = payload['action'] as String?;
      final advanceId = payload['advance_id'] as int?;
      if (advanceId != null) {
        logger.d(
          '[NotificationProvider] 💵 Advance $action: advanceId=$advanceId',
        );
        _handleAdvanceUpdated(advanceId, action, payload);
      }
    }
    // Credit note sync
    else if (type == 'credit_note_updated' && payload != null) {
      final action = payload['action'] as String?;
      final moveId = payload['move_id'] as int?;
      if (moveId != null) {
        logger.d(
          '[NotificationProvider] 📄 CreditNote $action: moveId=$moveId',
        );
        _handleCreditNoteUpdated(moveId, action, payload);
      }
    }
    // Invoice (account.move) sync
    else if (type == 'invoice_updated' && payload != null) {
      final action = payload['action'] as String?;
      final moveId = payload['move_id'] as int?;
      if (moveId != null) {
        logger.d(
          '[NotificationProvider] 🧾 Invoice $action: moveId=$moveId',
        );
        _handleInvoiceUpdated(moveId, action, payload);
      }
    }
    // Tax (account.tax) sync
    else if (type == 'tax_updated' && payload != null) {
      final action = payload['action'] as String?;
      final taxId = payload['tax_id'] as int?;
      if (taxId != null) {
        logger.d(
          '[NotificationProvider] 🏷️ Tax $action: taxId=$taxId',
        );
        _handleTaxUpdated(taxId, action, payload);
      }
    }
    // Cash out sync
    else if (type == 'cash_out_updated' && payload != null) {
      final action = payload['action'] as String?;
      final cashOutId = payload['cash_out_id'] as int?;
      if (cashOutId != null) {
        logger.d(
          '[NotificationProvider] 💸 CashOut $action: cashOutId=$cashOutId',
        );
        _handleCashOutUpdated(cashOutId, action, payload);
      }
    }
    // Deposit sync
    else if (type == 'deposit_updated' && payload != null) {
      final action = payload['action'] as String?;
      final depositId = payload['deposit_id'] as int?;
      if (depositId != null) {
        logger.d(
          '[NotificationProvider] 🏦 Deposit $action: depositId=$depositId',
        );
        _handleDepositUpdated(depositId, action, payload);
      }
    }
    // Session cash sync
    else if (type == 'session_cash_updated' && payload != null) {
      final action = payload['action'] as String?;
      final cashId = payload['cash_id'] as int?;
      if (cashId != null) {
        logger.d(
          '[NotificationProvider] 💵 SessionCash $action: cashId=$cashId',
        );
        _handleSessionCashUpdated(cashId, action, payload);
      }
    }
    // Product category sync
    else if (type == 'product_category_updated' && payload != null) {
      final action = payload['action'] as String?;
      final categoryId = payload['category_id'] as int?;
      if (categoryId != null) {
        logger.d(
          '[NotificationProvider] 📁 ProductCategory $action: categoryId=$categoryId',
        );
        _handleProductCategoryUpdated(categoryId, action, payload);
      }
    } else {
      // Unknown notification type - log for debugging
      logger.d('[NotificationProvider] ℹ️ Unhandled notification type: $type');
    }
  }

  /// Start polling for updates (fallback if WebSocket fails)
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(
      const Duration(
        minutes: 10,
      ), // Reduced from 2 to 10 minutes (WebSocket handles real-time)
      (_) => fetchCounters(),
    );
  }

  /// Stop polling
  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

}
