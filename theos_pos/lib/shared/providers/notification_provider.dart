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
        sessionByIdProvider;
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
import '../../core/database/database_helper.dart' show DatabaseHelper;
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
         AccountCreditNoteCompanion;
import '../../features/sales/screens/fast_sale/widgets/pos_payment_tab.dart'
    show posWithholdLinesByOrderProvider, posPaymentLinesByOrderProvider, posAvailableJournalsProvider,
    posCardBrandsByJournalProvider, posCardDeadlinesProvider;

/// Provider for notification counters
final notificationCounterProvider =
    NotifierProvider<NotificationCounterNotifier, NotificationCounter>(
      () => NotificationCounterNotifier(),
    );

class NotificationCounterNotifier extends Notifier<NotificationCounter> {
  Timer? _pollTimer;
  StreamSubscription? _wsSubscription;
  StreamSubscription<OdooWebSocketEvent>? _notificationSubscription;
  StreamSubscription<OdooWebSocketEvent>? _eventSubscription;
  bool _disposed = false;

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
      logger.e(
        '[NotificationProvider]',
        '❌ Error processing offline queue: $e',
      );
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
      // Collection session updated - refresh configs to update dashboard
      logger.d(
        '[NotificationProvider] 🔄 Session updated notification received',
      );
      final sessionId = payload['collection_session_id'] as int?;
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
    } else if (type == 'company_updated' && payload != null) {
      // Company updated - sync company and update denormalized names
      final action = payload['action'] as String?;
      final companyId = payload['company_id'] as int?;
      if (companyId != null) {
        logger.d(
          '[NotificationProvider] 🏢 Company $action notification: $companyId',
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

  /// Handle activity created or updated notification
  /// Fetches the specific activity from Odoo and updates local DB
  Future<void> _handleActivityCreatedOrUpdated(int activityId) async {
    try {
      final activityRepo = ref.read(activityRepositoryProvider);
      // Refresh single activity from Odoo (incremental sync)
      await activityRepo.refreshSingleActivity(activityId);

      // With StreamProvider, the UI auto-updates when local DB changes.
      // No manual refresh needed — the stream re-emits automatically.

      logger.d(
        '[NotificationProvider] ✅ Activity $activityId synced (stream auto-refreshes UI)',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling activity notification: $e',
      );
    }
  }

  /// Handle sale order created notification
  /// Fetches the new sale order from Odoo and updates local DB
  Future<void> _handleSaleOrderCreated(
    int orderId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ Repository not available for sale order refresh',
        );
        return;
      }

      // Refresh single sale order from Odoo
      await salesRepo.getById(orderId, forceRefresh: true);

      logger.d(
        '[NotificationProvider] ✅ Sale order $orderId created and synced',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order created: $e',
      );
    }
  }

  /// Handle sale order updated notification with conflict resolution
  Future<void> _handleSaleOrderUpdated(
    int orderId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ Repository not available for sale order refresh',
        );
        return;
      }

      // Obtener datos del payload
      // changed_fields puede ser Map o List dependiendo de dónde viene la notificación
      // - Desde sale.order.write(): Map<String, dynamic> con old/new values
      // - Desde sale.order.line._notify_parent_orders(): List<String> de nombres de campos
      Map<String, dynamic>? changedFields;
      final rawChangedFields = payload['changed_fields'];
      if (rawChangedFields is Map<String, dynamic>) {
        changedFields = rawChangedFields;
      } else if (rawChangedFields is List) {
        // Convertir lista a mapa vacío (solo nos importa que hay cambios)
        changedFields = {
          for (var field in rawChangedFields) field.toString(): true,
        };
      }
      final serverUserName = payload['user_name'] as String?;
      final writeDate = payload['write_date'] as String?;

      // Verificar si la orden está siendo editada localmente (usar provider unificado)
      final formNotifier = ref.read(saleOrderFormProvider.notifier);
      final formState = ref.read(saleOrderFormProvider);

      if (formState.order?.id == orderId &&
          formState.isEditing &&
          formState.hasChanges) {
        // La orden está siendo editada localmente - verificar conflictos
        logger.d(
          '[NotificationProvider] ⚠️ Order $orderId is being edited locally, checking conflicts...',
        );

        if (changedFields != null) {
          final hasConflict = formNotifier.processServerUpdate(
            serverChangedFields: changedFields,
            serverUserName: serverUserName,
            serverWriteDate: writeDate != null
                ? DateTime.parse(writeDate)
                : DateTime.now(),
          );

          if (hasConflict) {
            logger.d(
              '[NotificationProvider] ⚠️ Conflict detected! User will be notified.',
            );
            // El conflicto se maneja en el provider unificado
            // La UI mostrará el mensaje de conflicto
          }
        }
      } else {
        // La orden NO está siendo editada - actualizar directamente
        logger.d(
          '[NotificationProvider] 🔄 Order $orderId not being edited, updating directly',
        );

        // Verificar si estamos viendo el detalle de esta orden
        final formState = ref.read(saleOrderFormProvider);
        final isViewingThisOrder = formState.order?.id == orderId;
        final values = payload['values'] as Map<String, dynamic>?;

        // Si estamos viendo esta orden, usar actualización granular SIN hacer fetch completo
        // Esto evita regenerar toda la UI
        if (isViewingThisOrder) {
          // Determinar qué datos usar para la actualización granular:
          // - Si hay 'values' en el payload, usarlos (formato estructurado)
          // - Si no, usar los campos directos del payload (formato simple de bus.bus)
          final Map<String, dynamic> updateData;
          if (values != null) {
            updateData = values;
          } else {
            // Construir mapa de valores desde los campos directos del payload
            // Esto maneja el formato de notificación de bus.bus que no tiene 'values'
            updateData = <String, dynamic>{};
            // Copiar campos relevantes del payload que son campos de sale.order
            const orderFields = [
              'id',
              'name',
              'state',
              'partner_id',
              'partner_name',
              'amount_untaxed',
              'amount_tax',
              'amount_total',
              'date_order',
              'validity_date',
              'commitment_date',
              'pricelist_id',
              'pricelist_name',
              'payment_term_id',
              'payment_term_name',
              'warehouse_id',
              'warehouse_name',
              'user_id',
              'user_name',
              'client_order_ref',
              'note',
            ];
            for (final field in orderFields) {
              if (payload.containsKey(field)) {
                updateData[field] = payload[field];
              }
            }
          }

          // Solo hacer actualización granular si hay datos
          if (updateData.isNotEmpty) {
            ref
                .read(saleOrderFormProvider.notifier)
                .updateOrderFromWebSocket(orderId, updateData);

            // También actualizar FastSale (POS) si la orden está abierta
            ref
                .read(fastSaleProvider.notifier)
                .updateOrderFromWebSocket(orderId, updateData);
          }

          // Log de campos actualizados
          final changedFields = payload['changed_fields'];
          logger.d(
            '[NotificationProvider] 🎯 Granular update for order $orderId: '
            'changed_fields=$changedFields (skipped full fetch)',
          );

          // Actualizar la lista en background sin bloquear la UI
          // Usar unawaited para que no bloquee
          salesRepo.getById(orderId, forceRefresh: true);
        } else {
          // NO estamos viendo esta orden - hacer fetch completo
          await salesRepo.getById(orderId, forceRefresh: true);
        }
      }

      logger.d('[NotificationProvider] ✅ Sale order $orderId update handled');
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order updated: $e',
      );
    }
  }

  /// Handle sale order deleted notification
  Future<void> _handleSaleOrderDeleted(
    int orderId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) return;

      // Si la orden estaba siendo editada, limpiar estado
      final formState = ref.read(saleOrderFormProvider);
      if (formState.order?.id == orderId) {
        ref.read(saleOrderFormProvider.notifier).clearState();
        logger.d(
          '[NotificationProvider] 🗑️ Cleared edit state for deleted order $orderId',
        );
      }

      // Eliminar de la DB local
      await salesRepo.deleteLocal(orderId);

      logger.d(
        '[NotificationProvider] ✅ Sale order $orderId deleted and removed from local DB',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order deleted: $e',
      );
    }
  }

  /// Handle activity deleted notification
  /// Removes the activity from local DB
  Future<void> _handleActivityDeleted(int activityId) async {
    try {
      final activityRepo = ref.read(activityRepositoryProvider);
      // Delete activity from local DB
      await activityRepo.deleteLocalActivity(activityId);

      // With StreamProvider, the UI auto-updates when local DB changes.
      // No manual refresh needed — the stream re-emits automatically.

      logger.d(
        '[NotificationProvider] ✅ Activity $activityId deleted (stream auto-refreshes UI)',
      );
    } catch (e) {
      logger.d('[NotificationProvider] ❌ Error handling activity deletion: $e');
    }
  }

  /// Handle session created with UUID notification
  /// Updates currentSessionProvider with the real session data from Odoo
  Future<void> _handleSessionCreatedWithUuid({
    required int sessionId,
    required String sessionUuid,
    String? sessionName,
  }) async {
    try {
      logger.d(
        '[NotificationProvider] 🔄 Updating currentSession: id=$sessionId, uuid=$sessionUuid, name=$sessionName',
      );

      // Get current session from provider
      final currentSession = ref.read(currentSessionProvider);

      // If the current session has the same UUID (was created locally), update it
      if (currentSession != null && currentSession.sessionUuid == sessionUuid) {
        // Fetch the complete session from Odoo
        final collectionRepo = ref.read(collectionRepositoryProvider);
        if (collectionRepo != null) {
          final odooSession = await collectionRepo.fetchSessionFromOdoo(
            sessionId,
          );
          if (odooSession != null) {
            // Update currentSessionProvider with the real data
            ref.read(currentSessionProvider.notifier).state = odooSession;
            logger.d(
              '[NotificationProvider] ✅ currentSessionProvider updated: ${odooSession.name}',
            );
          }
        }
      }
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling session created with UUID: $e',
      );
    }
  }

  // ============ M7: Product/Catalog Update Handlers ============

  /// Handle product price updated notification
  /// Refreshes the specific product from Odoo and updates local DB
  /// Also updates denormalized productName in sale_order_line
  Future<void> _handleProductPriceUpdated(
    int productId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      if (catalogRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ CatalogSyncRepository not available for product refresh',
        );
        return;
      }

      // Sync the specific product from Odoo and get product data
      final productData = await catalogRepo.syncSingleProduct(productId);

      if (productData != null) {
        // Update denormalized productName in sale_order_line table
        final updatedLines = await catalogRepo.updateSaleOrderLinesProductName(
          productId,
          productData.name,
        );
        logger.d(
          '[NotificationProvider] ✅ Product $productId synced, updated $updatedLines sale order lines',
        );
      } else {
        logger.d(
          '[NotificationProvider] ⚠️ Product $productId sync returned no data (offline?)',
        );
      }
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling product price update: $e',
      );
    }
  }

  /// Handle pricelist item updated notification
  /// Refreshes pricelist items from Odoo and updates local DB
  Future<void> _handlePricelistItemUpdated(
    int pricelistItemId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      if (catalogRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ CatalogSyncRepository not available for pricelist refresh',
        );
        return;
      }

      final action = payload['action'] as String?;
      // Handle product_id: can be int, false (bool), or null
      final rawProductId = payload['product_id'];
      final productId = rawProductId is int ? rawProductId : null;

      // Also check product_tmpl_id for template-level pricelist items
      final rawProductTmplId = payload['product_tmpl_id'];
      final productTmplId = rawProductTmplId is int ? rawProductTmplId : null;

      if (action == 'deleted') {
        // Delete the pricelist item from local DB
        await catalogRepo.deletePricelistItem(pricelistItemId);
      } else {
        // Sync pricelist items for the affected product
        if (productId != null && productId > 0) {
          await catalogRepo.syncPricelistItemsForProduct(productId);
        } else if (productTmplId != null && productTmplId > 0) {
          // If product_id is false but we have template, sync products for this template
          // This handles cases where pricelist item applies to template (applied_on: 1_product)
          logger.d(
            '[NotificationProvider] 📦 Pricelist item for template $productTmplId - will sync on next full sync',
          );
        }
        // Skip full sync if no specific product - we can't do full sync without pricelistId
      }

      logger.d(
        '[NotificationProvider] ✅ Pricelist item $pricelistItemId ($action) synced',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling pricelist item update: $e',
      );
    }
  }

  /// Handle product UoM updated notification
  /// Refreshes product UoMs from Odoo and updates local DB
  Future<void> _handleProductUomUpdated(
    int uomId,
    Map<String, dynamic> payload,
  ) async {
    try {
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      if (catalogRepo == null) {
        logger.d(
          '[NotificationProvider] ❌ CatalogSyncRepository not available for UoM refresh',
        );
        return;
      }

      final action = payload['action'] as String?;
      // Handle product_id: can be int, false (bool), or null
      final rawProductId = payload['product_id'];
      final productId = rawProductId is int ? rawProductId : null;

      if (action == 'deleted') {
        // Delete the UoM from local DB
        await catalogRepo.deleteProductUom(uomId);
      } else {
        // Sync UoMs for the affected product
        if (productId != null && productId > 0) {
          await catalogRepo.syncProductUomsForProduct(productId);
        }
        // Skip full sync if no specific product - we sync UoMs per product only
      }

      logger.d('[NotificationProvider] ✅ Product UoM $uomId ($action) synced');
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling product UoM update: $e',
      );
    }
  }

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

  /// Handle stock quant update notification from Odoo WebSocket
  /// Updates local StockByWarehouse table directly from WebSocket payload
  Future<void> _handleStockQuantUpdated(Map<String, dynamic> payload) async {
    try {
      final catalogRepo = ref.read(catalogSyncRepositoryProvider);
      if (catalogRepo == null) {
        logger.d(
          '[NotificationProvider] ⚠️ CatalogSyncRepository not available for stock update',
        );
        return;
      }

      // Extract data from WebSocket payload
      final productId = payload['product_id'] as int;
      final productName = payload['product_name'] as String? ?? '';
      final defaultCode = payload['default_code'] as String?;
      final warehouseId = payload['warehouse_id'] as int;
      final warehouseName = payload['warehouse_name'] as String? ?? '';
      final quantity = (payload['quantity'] as num?)?.toDouble() ?? 0.0;
      final reservedQuantity =
          (payload['reserved_quantity'] as num?)?.toDouble() ?? 0.0;
      final availableQuantity =
          (payload['available_quantity'] as num?)?.toDouble() ?? 0.0;
      final operation = payload['operation'] as String?;
      final oldQuantity = (payload['old_quantity'] as num?)?.toDouble();

      // Update stock by warehouse table directly from WebSocket data
      final success = await catalogRepo.updateStockFromWebSocket(
        productId: productId,
        productName: productName,
        defaultCode: defaultCode,
        warehouseId: warehouseId,
        warehouseName: warehouseName,
        quantity: quantity,
        reservedQuantity: reservedQuantity,
        availableQuantity: availableQuantity,
      );

      if (success) {
        // Record stock change for audit if there was a quantity change
        if (operation == 'update' && oldQuantity != null) {
          await catalogRepo.recordStockChange(
            productId: productId,
            productName: productName,
            defaultCode: defaultCode,
            warehouseId: warehouseId,
            warehouseName: warehouseName,
            oldQuantity: oldQuantity,
            newQuantity: quantity,
          );
        }

        // NOTE: No need to invalidate provider - StockByWarehouse table
        // is watched directly by UI components that display stock data.
        // Updating the Drift table automatically triggers UI rebuilds.

        logger.d(
          '[NotificationProvider] ✅ Stock updated for product $productId '
          '($productName) in warehouse $warehouseId: qty=$quantity',
        );
      }
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling stock quant update: $e',
      );
    }
  }

  /// Handle collection session/config update notification
  /// Refreshes collection configs and sessions from Odoo to update dashboard and session screens
  /// If [sessionId] is provided, also refreshes the specific session from Odoo
  Future<void> _handleCollectionUpdate({int? sessionId}) async {
    try {
      // Force refresh collection configs provider to update UI immediately
      // This will trigger syncCollectionConfigs() which fetches fresh data from Odoo
      final _ = await ref.refresh(collectionConfigsProvider.future);

      // ✅ Si se proporciona sessionId, actualizar la sesión DESDE ODOO primero
      // y luego invalidar el provider para que la UI se actualice con datos frescos
      if (sessionId != null) {
        final collectionRepo = ref.read(collectionRepositoryProvider);
        if (collectionRepo != null) {
          // Forzar actualización desde Odoo (no solo base de datos local)
          final refreshedSession = await collectionRepo.getCollectionSession(
            sessionId,
            forceRefresh: true, // Obtener datos frescos de Odoo
          );

          if (refreshedSession != null) {
            logger.d(
              '[NotificationProvider] ✅ Session $sessionId refreshed from Odoo: state=${refreshedSession.state}',
            );

            // Si esta es la sesión actual, actualizar el currentSessionProvider también
            final currentSession = ref.read(currentSessionProvider);
            if (currentSession?.id == sessionId ||
                currentSession?.sessionUuid == refreshedSession.sessionUuid) {
              ref.read(currentSessionProvider.notifier).state =
                  refreshedSession;
              logger.d(
                '[NotificationProvider] ✅ currentSessionProvider updated with refreshed session',
              );
            }
          }
        }

        // Invalidar el provider para forzar recarga de la UI
        ref.invalidate(sessionByIdProvider(sessionId));
        logger.d(
          '[NotificationProvider] ✅ Session $sessionId provider invalidated',
        );
      }

      logger.d(
        '[NotificationProvider] ✅ Collection configs refreshed from WebSocket notification',
      );
    } catch (e) {
      logger.d('[NotificationProvider] ❌ Error handling collection update: $e');
    }
  }

  // ============ Sale Order Line WebSocket Handlers ============

  /// Handle sale order line created notification from Odoo WebSocket
  /// Creates or updates the line in local Drift database
  Future<void> _handleSaleOrderLineCreated(Map<String, dynamic> payload) async {
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) {
        logger.d(
          '[NotificationProvider] ⚠️ SalesRepository not available for line create',
        );
        return;
      }

      final lineId = payload['id'] as int;
      final orderId = payload['order_id'] as int;
      final lineUuid = payload['x_uuid'] as String?;

      // Check if this line was created by our app (has matching UUID)
      // If so, we already have it locally - just update with remote ID
      if (lineUuid != null && lineUuid.isNotEmpty) {
        // Line was created by Flutter app - update local record with remote ID
        logger.d(
          '[NotificationProvider] 📝 Line created by app, updating local with remote ID: $lineId',
        );
      }

      // Upsert line from WebSocket payload to local database
      await _upsertSaleOrderLineFromPayload(payload);

      // Actualizar granularmente el form provider si estamos viendo esta orden
      final formState = ref.read(saleOrderFormProvider);
      if (formState.order?.id == orderId) {
        // Construir SaleOrderLine desde el payload para actualización granular
        final newLine = _buildSaleOrderLineFromPayload(payload);
        if (newLine != null) {
          ref
              .read(saleOrderFormProvider.notifier)
              .updateLineFromWebSocket(newLine);
        }
      }

      // También actualizar FastSale (POS) si la orden está abierta
      final newLine = _buildSaleOrderLineFromPayload(payload);
      if (newLine != null) {
        ref.read(fastSaleProvider.notifier).updateLineFromWebSocket(newLine);
      }

      logger.d(
        '[NotificationProvider] ✅ Sale order line created: lineId=$lineId, orderId=$orderId',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order line created: $e',
      );
    }
  }

  /// Handle sale order line updated notification from Odoo WebSocket
  /// Updates the line in local Drift database and form provider (granularly)
  Future<void> _handleSaleOrderLineUpdated(Map<String, dynamic> payload) async {
    try {
      final salesRepo = ref.read(salesRepositoryProvider);
      if (salesRepo == null) {
        logger.d(
          '[NotificationProvider] ⚠️ SalesRepository not available for line update',
        );
        return;
      }

      final lineId = payload['id'] as int;
      final orderId = payload['order_id'] as int;

      // Update line from WebSocket payload to local database
      await _upsertSaleOrderLineFromPayload(payload);

      // Actualizar granularmente el form provider si estamos viendo esta orden
      final formState = ref.read(saleOrderFormProvider);
      if (formState.order?.id == orderId) {
        // Construir SaleOrderLine desde el payload para actualización granular
        final updatedLine = _buildSaleOrderLineFromPayload(payload);
        if (updatedLine != null) {
          ref
              .read(saleOrderFormProvider.notifier)
              .updateLineFromWebSocket(updatedLine);
        }
      }

      // También actualizar FastSale (POS) si la orden está abierta
      final updatedLine = _buildSaleOrderLineFromPayload(payload);
      if (updatedLine != null) {
        ref.read(fastSaleProvider.notifier).updateLineFromWebSocket(updatedLine);
      }

      logger.d(
        '[NotificationProvider] ✅ Sale order line updated: lineId=$lineId, orderId=$orderId',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order line updated: $e',
      );
    }
  }

  /// Handle sale order line deleted notification from Odoo WebSocket
  /// Removes the line from local Drift database and form provider (granularly)
  Future<void> _handleSaleOrderLineDeleted(Map<String, dynamic> payload) async {
    try {
      final lineId = payload['id'] as int;
      final orderId = payload['order_id'] as int?;

      // Delete line from local database
      await saleOrderLineManager.deleteLocal(lineId);

      // Actualizar granularmente el form provider si estamos viendo esta orden
      if (orderId != null) {
        final formState = ref.read(saleOrderFormProvider);
        if (formState.order?.id == orderId) {
          ref
              .read(saleOrderFormProvider.notifier)
              .removeLineFromWebSocket(lineId, orderId);
        }

        // También actualizar FastSale (POS) si la orden está abierta
        ref.read(fastSaleProvider.notifier).removeLineFromWebSocket(orderId, lineId);
      }

      logger.d(
        '[NotificationProvider] ✅ Sale order line deleted: lineId=$lineId, orderId=$orderId',
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] ❌ Error handling sale order line deleted: $e',
      );
    }
  }

  /// Handle sale order withhold updated from WebSocket
  Future<void> _handleSaleOrderWithholdUpdated(
      Map<String, dynamic> payload) async {
    try {
      final saleId = payload['sale_id'] as int;
      final action = payload['action'] as String?;
      final withholdLinesData = payload['withhold_lines'] as List<dynamic>?;
      final totalWithhold =
          (payload['total_withhold'] as num?)?.toDouble() ?? 0.0;
      final lineCount = payload['line_count'] as int? ?? 0;

      logger.i(
        '[NotificationProvider]',
        '📋 Withhold update: action=$action, saleId=$saleId, lines=$lineCount, total=$totalWithhold',
      );

      if (action == 'bulk_update' && withholdLinesData != null) {
        // Parse withhold lines from server notification data
        final lines = <WithholdLine>[];
        for (final lineData in withholdLinesData) {
          try {
            final data = lineData as Map<String, dynamic>;
            final taxName = data['tax_name'] as String? ?? 'Retención';

            // Infer withhold type from tax name if not provided
            WithholdType withholdType = WithholdType.incomeSale;
            if (taxName.toLowerCase().contains('iva') ||
                taxName.toLowerCase().contains('vat')) {
              withholdType = WithholdType.vatSale;
            }

            lines.add(WithholdLine(
              id: data['id'] as int? ?? 0,
              lineUuid: const Uuid().v4(),
              taxId: data['tax_id'] as int? ?? 0,
              taxName: taxName,
              taxPercent: (data['tax_amount'] as num?)?.toDouble() ?? 0.0,
              withholdType: withholdType,
              taxSupportCode: TaxSupportCode.fromCode(data['taxsupport_code']),
              base: (data['base'] as num?)?.toDouble() ?? 0.0,
              amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
              notes: data['notes'] as String?,
            ));
          } catch (e) {
            logger.w(
                '[NotificationProvider]', 'Error parsing withhold line: $e');
          }
        }

        // Save to local database for offline-first
        await _saveWithholdLinesToDb(saleId, withholdLinesData);

        // Update the withhold lines provider (in-memory)
        ref
            .read(posWithholdLinesByOrderProvider.notifier)
            .setLinesFromServer(saleId, lines);

        logger.i(
          '[NotificationProvider]',
          '✅ Withhold lines updated for order $saleId: ${lines.length} lines',
        );
      }
    } catch (e) {
      logger.e(
        '[NotificationProvider]',
        '❌ Error handling withhold updated: $e',
      );
    }
  }

  /// Save withhold lines to local database
  Future<void> _saveWithholdLinesToDb(
      int orderId, List<dynamic> linesData) async {
    try {
      if (!DatabaseHelper.isInitialized) return;
      final db = _db;

      // Delete existing lines for this order
      await (db.delete(db.saleOrderWithholdLine)
            ..where((t) => t.orderId.equals(orderId)))
          .go();

      // Insert new lines
      for (final lineData in linesData) {
        final data = lineData as Map<String, dynamic>;
        final taxName = data['tax_name'] as String? ?? 'Retención';

        // Infer withhold type from tax name if not provided
        String withholdType = 'withhold_income_sale';
        if (taxName.toLowerCase().contains('iva') ||
            taxName.toLowerCase().contains('vat')) {
          withholdType = 'withhold_vat_sale';
        }

        final companion = SaleOrderWithholdLineCompanion.insert(
          odooId: Value(data['id'] as int?),
          orderId: orderId,
          sequence: Value(data['sequence'] as int? ?? 10),
          taxId: data['tax_id'] as int? ?? 0,
          taxName: taxName,
          taxPercent: Value((data['tax_amount'] as num?)?.toDouble() ?? 0.0),
          withholdType: withholdType,
          taxsupportCode: Value(data['taxsupport_code'] as String?),
          base: Value((data['base'] as num?)?.toDouble() ?? 0.0),
          amount: Value((data['amount'] as num?)?.toDouble() ?? 0.0),
          notes: Value(data['notes'] as String?),
          isSynced: const Value(true),
          lastSyncDate: Value(DateTime.now()),
        );
        await db.into(db.saleOrderWithholdLine).insert(companion);
      }

      logger.d(
        '[NotificationProvider]',
        '💾 Saved ${linesData.length} withhold lines to DB for order $orderId',
      );
    } catch (e) {
      logger.e(
        '[NotificationProvider]',
        '❌ Error saving withhold lines to DB: $e',
      );
    }
  }

  /// Handle payment line updated from WebSocket
  Future<void> _handleSaleOrderPaymentUpdated(
      Map<String, dynamic> payload) async {
    try {
      final saleId = payload['sale_id'] as int;
      final action = payload['action'] as String?;
      final paymentLinesData = payload['payment_lines'] as List<dynamic>?;
      final totalPaid =
          (payload['total_paid'] as num?)?.toDouble() ?? 0.0;
      final lineCount = payload['line_count'] as int? ?? 0;

      logger.i(
        '[NotificationProvider]',
        '💳 Payment update: action=$action, saleId=$saleId, lines=$lineCount, total=$totalPaid',
      );

      if (action == 'bulk_update' && paymentLinesData != null) {
        // Parse payment lines from server notification data
        // Generate UUID once per line and use it for both in-memory and DB (fixes delete bug)
        final lines = <PaymentLine>[];
        final processedLinesData = <Map<String, dynamic>>[];

        for (final lineData in paymentLinesData) {
          try {
            final data = Map<String, dynamic>.from(lineData as Map<String, dynamic>);

            // Generate UUID if not provided by Odoo
            final lineUuid = data['uuid'] as String? ?? const Uuid().v4();
            data['uuid'] = lineUuid; // Ensure UUID is in the data for DB save

            // Determine payment line type
            PaymentLineType type = PaymentLineType.payment;
            if (data['advance_id'] != null) {
              type = PaymentLineType.advance;
            } else if (data['credit_note_id'] != null) {
              type = PaymentLineType.creditNote;
            }

            // Parse card type
            CardType? cardType;
            final cardTypeStr = data['card_type'] as String?;
            if (cardTypeStr == 'credit') {
              cardType = CardType.credit;
            } else if (cardTypeStr == 'debit') {
              cardType = CardType.debit;
            }

            // Parse date
            DateTime date = DateTime.now();
            if (data['date'] is String) {
              date = DateTime.tryParse(data['date']) ?? DateTime.now();
            }

            // Parse optional dates
            DateTime? effectiveDate;
            if (data['effective_date'] is String) {
              effectiveDate = DateTime.tryParse(data['effective_date']);
            }
            DateTime? voucherDate;
            if (data['bank_reference_date'] is String) {
              voucherDate = DateTime.tryParse(data['bank_reference_date']);
            }

            lines.add(PaymentLine(
              id: data['id'] as int? ?? 0, // ID from Odoo (primary identifier)
              lineUuid: lineUuid, // UUID for offline sync tracking
              type: type,
              date: date,
              amount: (data['amount'] as num?)?.toDouble() ?? 0.0,
              reference: data['payment_reference'] as String?,
              journalId: data['journal_id'] as int?,
              journalName: data['journal_name'] as String?,
              journalType: data['journal_type'] as String?,
              paymentMethodLineId: data['payment_method_line_id'] as int?,
              paymentMethodCode: data['payment_method_code'] as String?,
              paymentMethodName: data['payment_method_name'] as String?,
              bankId: data['bank_id'] as int?,
              bankName: data['bank_name'] as String?,
              cardType: cardType,
              cardBrandId: data['card_brand_id'] as int?,
              cardBrandName: data['card_brand_name'] as String?,
              cardDeadlineId: data['card_deadline_id'] as int?,
              cardDeadlineName: data['card_deadline_name'] as String?,
              loteId: data['lote_id'] as int?,
              loteName: data['lote_name'] as String?,
              voucherDate: voucherDate,
              partnerBankId: data['partner_bank_id'] as int?,
              partnerBankName: data['partner_bank_name'] as String?,
              effectiveDate: effectiveDate,
              advanceId: data['advance_id'] as int?,
              advanceName: data['advance_name'] as String?,
              creditNoteId: data['credit_note_id'] as int?,
              creditNoteName: data['credit_note_name'] as String?,
            ));

            processedLinesData.add(data); // Add to processed list with UUID
          } catch (e) {
            logger.w(
                '[NotificationProvider]', 'Error parsing payment line: $e');
          }
        }

        // Save to local database for offline-first (with UUIDs included)
        await _savePaymentLinesToDb(saleId, processedLinesData);

        // Update the payment lines provider (in-memory)
        ref
            .read(posPaymentLinesByOrderProvider.notifier)
            .setLinesFromServer(saleId, lines);

        logger.i(
          '[NotificationProvider]',
          '✅ Payment lines updated for order $saleId: ${lines.length} lines',
        );
      }
    } catch (e) {
      logger.e(
        '[NotificationProvider]',
        '❌ Error handling payment updated: $e',
      );
    }
  }

  /// Save payment lines to local database
  Future<void> _savePaymentLinesToDb(
      int orderId, List<dynamic> linesData) async {
    try {
      if (!DatabaseHelper.isInitialized) return;
      final db = _db;

      // Use transaction to avoid race conditions with multiple WebSocket notifications
      await db.transaction(() async {
        // Delete existing lines for this order
        await (db.delete(db.saleOrderPaymentLine)
              ..where((t) => t.orderId.equals(orderId)))
            .go();

        // Insert new lines
        for (final lineData in linesData) {
          final data = lineData as Map<String, dynamic>;

          // Parse dates
          DateTime? date;
          if (data['date'] is String) {
            date = DateTime.tryParse(data['date']);
          }
          DateTime? effectiveDate;
          if (data['effective_date'] is String) {
            effectiveDate = DateTime.tryParse(data['effective_date']);
          }
          DateTime? bankReferenceDate;
          if (data['bank_reference_date'] is String) {
            bankReferenceDate = DateTime.tryParse(data['bank_reference_date']);
          }

          final companion = SaleOrderPaymentLineCompanion.insert(
            odooId: Value(data['id'] as int?),
            lineUuid: Value(data['uuid'] as String?), // UUID is now included in processed data
            orderId: orderId,
            paymentType: Value(data['payment_type'] as String? ?? 'inbound'),
            journalId: Value(data['journal_id'] as int?),
            journalName: Value(data['journal_name'] as String?),
            journalType: Value(data['journal_type'] as String?),
            paymentMethodLineId: Value(data['payment_method_line_id'] as int?),
            paymentMethodCode: Value(data['payment_method_code'] as String?),
            paymentMethodName: Value(data['payment_method_name'] as String?),
            amount: Value((data['amount'] as num?)?.toDouble() ?? 0.0),
            date: Value(date),
            paymentReference: Value(data['payment_reference'] as String?),
            creditNoteId: Value(data['credit_note_id'] as int?),
            creditNoteName: Value(data['credit_note_name'] as String?),
            advanceId: Value(data['advance_id'] as int?),
            advanceName: Value(data['advance_name'] as String?),
            cardType: Value(data['card_type'] as String?),
            cardBrandId: Value(data['card_brand_id'] as int?),
            cardBrandName: Value(data['card_brand_name'] as String?),
            cardDeadlineId: Value(data['card_deadline_id'] as int?),
            cardDeadlineName: Value(data['card_deadline_name'] as String?),
            loteId: Value(data['lote_id'] as int?),
            loteName: Value(data['lote_name'] as String?),
            bankId: Value(data['bank_id'] as int?),
            bankName: Value(data['bank_name'] as String?),
            partnerBankId: Value(data['partner_bank_id'] as int?),
            partnerBankName: Value(data['partner_bank_name'] as String?),
            effectiveDate: Value(effectiveDate),
            bankReferenceDate: Value(bankReferenceDate),
            state: Value(data['state'] as String? ?? 'draft'),
            isSynced: const Value(true),
            lastSyncDate: Value(DateTime.now()),
          );
          await db.into(db.saleOrderPaymentLine).insert(companion);
        }
      });

      logger.d(
        '[NotificationProvider]',
        '💾 Saved ${linesData.length} payment lines to DB for order $orderId',
      );
    } catch (e) {
      logger.e(
        '[NotificationProvider]',
        '❌ Error saving payment lines to DB: $e',
      );
    }
  }

  /// Build a SaleOrderLine model from WebSocket payload
  /// Returns null if payload is invalid
  SaleOrderLine? _buildSaleOrderLineFromPayload(Map<String, dynamic> payload) {
    try {
      final lineId = payload['id'] as int;
      final orderId = payload['order_id'] as int;
      final lineUuid = payload['x_uuid'] as String?;
      final sequence = payload['sequence'] as int? ?? 10;
      final productId = payload['product_id'] as int?;
      final productName = payload['product_name'] as String?;
      final productCode = payload['product_code'] as String?;
      final name = payload['name'] as String? ?? '';
      final productUomQty =
          (payload['product_uom_qty'] as num?)?.toDouble() ?? 1.0;
      final productUomId = payload['product_uom_id'] as int?;
      final productUomName = payload['product_uom_name'] as String?;
      final priceUnit = (payload['price_unit'] as num?)?.toDouble() ?? 0.0;
      final discount = (payload['discount'] as num?)?.toDouble() ?? 0.0;
      final priceSubtotal =
          (payload['price_subtotal'] as num?)?.toDouble() ?? 0.0;
      final priceTax = (payload['price_tax'] as num?)?.toDouble() ?? 0.0;
      final priceTotal = (payload['price_total'] as num?)?.toDouble() ?? 0.0;
      final qtyDelivered =
          (payload['qty_delivered'] as num?)?.toDouble() ?? 0.0;
      final qtyInvoiced = (payload['qty_invoiced'] as num?)?.toDouble() ?? 0.0;
      final orderState = toStringOrNull(payload['state']);
      final displayTypeStr = toStringOrNull(payload['display_type']);
      final writeDateStr = toStringOrNull(payload['write_date']);

      DateTime? writeDate;
      if (writeDateStr != null) {
        writeDate = DateTime.tryParse(writeDateStr);
      }

      // Convert display_type string to enum
      LineDisplayType displayType = LineDisplayType.product;
      if (displayTypeStr != null && displayTypeStr.isNotEmpty) {
        switch (displayTypeStr) {
          case 'line_section':
            displayType = LineDisplayType.lineSection;
            break;
          case 'line_subsection':
            displayType = LineDisplayType.lineSubsection;
            break;
          case 'line_note':
            displayType = LineDisplayType.lineNote;
            break;
        }
      }

      return SaleOrderLine(
        id: lineId,
        orderId: orderId,
        lineUuid: lineUuid,
        sequence: sequence,
        productId: productId,
        productName: productName,
        productCode: productCode,
        name: name,
        productUomQty: productUomQty,
        productUomId: productUomId,
        productUomName: productUomName,
        priceUnit: priceUnit,
        discount: discount,
        priceSubtotal: priceSubtotal,
        priceTax: priceTax,
        priceTotal: priceTotal,
        qtyDelivered: qtyDelivered,
        qtyInvoiced: qtyInvoiced,
        orderState: orderState,
        displayType: displayType,
        writeDate: writeDate,
        isSynced: true,
      );
    } catch (e) {
      logger.d(
        '[NotificationProvider] Error building SaleOrderLine from payload: $e',
      );
      return null;
    }
  }

  /// Helper to upsert a sale order line from WebSocket payload to local database
  Future<void> _upsertSaleOrderLineFromPayload(
    Map<String, dynamic> payload,
  ) async {
    // Extract data from WebSocket payload (matches Odoo's _get_notification_data)
    final lineId = payload['id'] as int;
    final orderId = payload['order_id'] as int;
    final lineUuid = payload['x_uuid'] as String?;
    final sequence = payload['sequence'] as int? ?? 10;
    final productId = payload['product_id'] as int?;
    final productName = payload['product_name'] as String?;
    final name = payload['name'] as String? ?? '';
    final productUomQty =
        (payload['product_uom_qty'] as num?)?.toDouble() ?? 1.0;
    final productUomId = payload['product_uom_id'] as int?;
    final productUomName = payload['product_uom_name'] as String?;
    final priceUnit = (payload['price_unit'] as num?)?.toDouble() ?? 0.0;
    final discount = (payload['discount'] as num?)?.toDouble() ?? 0.0;
    final priceSubtotal =
        (payload['price_subtotal'] as num?)?.toDouble() ?? 0.0;
    final priceTax = (payload['price_tax'] as num?)?.toDouble() ?? 0.0;
    final priceTotal = (payload['price_total'] as num?)?.toDouble() ?? 0.0;
    final qtyDelivered = (payload['qty_delivered'] as num?)?.toDouble() ?? 0.0;
    final qtyInvoiced = (payload['qty_invoiced'] as num?)?.toDouble() ?? 0.0;
    final state = toStringOrNull(payload['state']);
    final displayType = toStringOrNull(payload['display_type']);
    final writeDateStr = toStringOrNull(payload['write_date']);

    DateTime? writeDate;
    if (writeDateStr != null) {
      writeDate = DateTime.tryParse(writeDateStr);
    }

    // Use SaleOrderLineManager to upsert the line
    await saleOrderLineManager.upsertSaleOrderLineFromWebSocket(
      odooId: lineId,
      orderId: orderId,
      lineUuid: lineUuid,
      sequence: sequence,
      productId: productId,
      productName: productName,
      name: name,
      productUomQty: productUomQty,
      productUomId: productUomId,
      productUomName: productUomName,
      priceUnit: priceUnit,
      discount: discount,
      priceSubtotal: priceSubtotal,
      priceTax: priceTax,
      priceTotal: priceTotal,
      qtyDelivered: qtyDelivered,
      qtyInvoiced: qtyInvoiced,
      orderState: state,
      displayType: displayType,
      writeDate: writeDate,
    );
  }

  // ============ Standard UoM (uom.uom) WebSocket Handler ============

  /// Handle standard uom.uom updated notification from Odoo
  /// This updates the UomUom table (standard Odoo UoM model)
  Future<void> _handleUomUomUpdated(
    int uomId,
    Map<String, dynamic> payload,
  ) async {
    final action = payload['action'] as String?;
    final values = payload['values'] as Map<String, dynamic>?;

    logger.i(
      '[NotificationProvider] 📏 Processing standard UoM update: '
      'id=$uomId, action=$action',
    );

    // Handle deletion
    if (action == 'deleted') {
      try {
        await uomManager.deleteLocal(uomId);
        logger.i('[NotificationProvider] ✅ Standard UoM deleted: $uomId');
      } catch (e) {
        logger.e('[NotificationProvider] Error deleting standard UoM: $e');
      }
      return;
    }

    // Handle create/update
    if (values == null) {
      logger.w('[NotificationProvider] No values in uom_uom_updated payload');
      return;
    }

    try {
      // Extract values from payload
      // NOTE: category_id, uom_type, factor_inv, rounding were removed in Odoo 19.2
      // Use safe defaults when absent to support both Odoo 19.1 and 19.2
      final name = values['name'] as String? ?? '';
      final categoryId = values['category_id'] as int? ?? 1;
      final categoryName = values['category_name'] as String?;
      final factor = (values['factor'] as num?)?.toDouble() ?? 1.0;
      final factorInv = (values['factor_inv'] as num?)?.toDouble() ?? 1.0;
      final uomTypeStr = values['uom_type'] as String? ?? 'reference';
      final rounding = (values['rounding'] as num?)?.toDouble() ?? 0.01;
      final active = values['active'] as bool? ?? true;
      final writeDateStr = values['write_date'] as String?;

      DateTime? writeDate;
      if (writeDateStr != null) {
        writeDate = DateTime.tryParse(writeDateStr);
      }

      final uomType = UomType.values.firstWhere(
        (t) => t.name == uomTypeStr,
        orElse: () => UomType.reference,
      );

      final uom = Uom(
        id: uomId,
        name: name,
        categoryId: categoryId,
        categoryName: categoryName,
        factor: factor,
        factorInv: factorInv,
        uomType: uomType,
        rounding: rounding,
        active: active,
        writeDate: writeDate,
      );

      await uomManager.upsertLocal(uom);

      logger.i(
        '[NotificationProvider] ✅ Standard UoM upserted: '
        'id=$uomId, name=$name, type=$uomTypeStr',
      );

      // Invalidate providers that depend on UoM data
      // Products provider invalidation handled elsewhere
    } catch (e) {
      logger.e('[NotificationProvider] Error upserting standard UoM: $e');
    }
  }

  // ============================================================
  // CARD PAYMENT TABLES - WebSocket Sync Handlers
  // ============================================================

  /// Handle card brand update notification from Odoo WebSocket
  /// Updates card brand in local database
  Future<void> _handleCardBrandUpdated(
    int brandId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete card brand from local DB
        await (db.delete(db.accountCreditCardBrand)
              ..where((t) => t.odooId.equals(brandId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Card brand $brandId deleted locally');
        return;
      }

      if (values == null) return;

      // Upsert card brand
      final name = values['name'] as String? ?? '';
      final code = values['code'] as String?;
      final active = values['active'] as bool? ?? true;

      final companion = AccountCreditCardBrandCompanion.insert(
        odooId: brandId,
        name: name,
        code: Value(code),
        active: Value(active),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.accountCreditCardBrand).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.accountCreditCardBrand.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ Card brand $brandId upserted: $name');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling card brand update: $e');
    }
  }

  /// Handle card deadline update notification from Odoo WebSocket
  /// Updates card deadline in local database
  Future<void> _handleCardDeadlineUpdated(
    int deadlineId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete card deadline from local DB
        await (db.delete(db.accountCreditCardDeadline)
              ..where((t) => t.odooId.equals(deadlineId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Card deadline $deadlineId deleted locally');
        return;
      }

      if (values == null) return;

      // Upsert card deadline
      final name = values['name'] as String? ?? '';
      final meses = values['meses'] as int? ?? 0;
      final active = values['active'] as bool? ?? true;

      final companion = AccountCreditCardDeadlineCompanion.insert(
        odooId: deadlineId,
        name: name,
        deadlineDays: meses, // Map meses to deadlineDays
        percentage: const Value(0.0), // Default percentage
        active: Value(active),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.accountCreditCardDeadline).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.accountCreditCardDeadline.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ Card deadline $deadlineId upserted: $name ($meses meses)');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling card deadline update: $e');
    }
  }

  /// Handle card lote update notification from Odoo WebSocket
  /// Updates card lote in local database
  Future<void> _handleCardLoteUpdated(
    int loteId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete card lote from local DB
        await (db.delete(db.accountCardLote)
              ..where((t) => t.odooId.equals(loteId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Card lote $loteId deleted locally');
        return;
      }

      if (values == null) return;

      // Check if this lote exists locally (may have been created offline)
      final existingLote = await (db.select(db.accountCardLote)
            ..where((t) => t.odooId.equals(loteId)))
          .getSingleOrNull();

      final name = values['name'] as String? ?? '';
      final numeroLote = values['numero_lote'] as String?;
      final state = values['state'] as String? ?? 'open';
      final amountTotal = (values['amount_total'] as num?)?.toDouble() ?? 0.0;
      final paymentCount = values['payment_count'] as int? ?? 0;

      // Extract journal_id
      int journalId;
      String? journalName;
      if (values['journal_id'] is List) {
        journalId = (values['journal_id'] as List).first as int;
        journalName = (values['journal_id'] as List).length > 1
            ? (values['journal_id'] as List)[1] as String
            : null;
      } else {
        journalId = values['journal_id'] as int? ?? 0;
      }

      // Parse date
      DateTime date = DateTime.now();
      if (values['date'] != null && values['date'] != false) {
        date = DateTime.tryParse(values['date'] as String) ?? DateTime.now();
      }

      if (existingLote != null) {
        // Update existing lote
        await (db.update(db.accountCardLote)
              ..where((t) => t.odooId.equals(loteId)))
            .write(AccountCardLoteCompanion(
          name: Value(name),
          code: Value(numeroLote ?? ''),
          state: Value(state),
          // isPosLote field doesn't exist in table
          // isPosLote: Value(isPosLote),
          totalAmount: Value(amountTotal),
          // amountBalance field doesn't exist in table
          // amountBalance: Value(amountBalance),
          transactionCount: Value(paymentCount),
          journalName: Value(journalName),
          // isSynced field doesn't exist in table
          // isSynced: const Value(true),
          writeDate: Value(DateTime.now()),
        ));
      } else {
        // Insert new lote
        await db.into(db.accountCardLote).insert(
          AccountCardLoteCompanion.insert(
            odooId: loteId,
            name: name,
            code: Value(numeroLote ?? ''),
            dateFrom: Value(date),
            dateTo: Value(date), // Using same date for both
            journalId: journalId,
            journalName: Value(journalName),
            state: Value(state),
            // isPosLote: Value(isPosLote), // Field doesn't exist
            totalAmount: Value(amountTotal),
            // amountBalance: Value(amountBalance), // Field doesn't exist
            transactionCount: Value(paymentCount),
            // isSynced: const Value(true), // Field doesn't exist
            writeDate: Value(DateTime.now()),
          ),
        );
      }

      logger.d('[NotificationProvider] ✅ Card lote $loteId upserted: $name (state: $state)');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling card lote update: $e');
    }
  }

  /// Handle journal update notification from Odoo WebSocket
  /// Updates journal card configuration in local database
  Future<void> _handleJournalUpdated(
    int journalId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete journal from local DB
        await (db.delete(db.accountJournal)
              ..where((t) => t.odooId.equals(journalId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Journal $journalId deleted locally');
        // Invalidate providers so UI refreshes
        ref.invalidate(posAvailableJournalsProvider);
        return;
      }

      if (values == null) return;

      // Check if journal exists locally
      final existingJournal = await (db.select(db.accountJournal)
            ..where((t) => t.odooId.equals(journalId)))
          .getSingleOrNull();

      if (existingJournal == null) {
        // Journal doesn't exist locally - trigger full sync
        logger.d('[NotificationProvider] Journal $journalId not found locally, skipping WebSocket update');
        return;
      }

      // Helper to extract M2O ID from Odoo value (handles [id, name] or false/null)
      int? extractM2OId(dynamic value) {
        if (value == null || value == false) return null;
        if (value is List && value.isNotEmpty) return value.first as int?;
        if (value is int) return value;
        return null;
      }

      // Only update card-related fields from WebSocket
      final isCardJournal = values['is_card_journal'] as bool?;
      final disponibleVentas = values['disponible_ventas'] as bool?;
      final disponiblePagos = values['disponible_pagos'] as bool?;

      // Extract M2O fields - handle both [id, name] tuples and false/null
      final hasDefaultCardBrandId = values.containsKey('default_card_brand_id');
      final defaultCardBrandId = extractM2OId(values['default_card_brand_id']);
      final hasDefaultDeadlineCreditId = values.containsKey('default_card_deadline_credit_id');
      final defaultDeadlineCreditId = extractM2OId(values['default_card_deadline_credit_id']);
      final hasDefaultDeadlineDebitId = values.containsKey('default_card_deadline_debit_id');
      final defaultDeadlineDebitId = extractM2OId(values['default_card_deadline_debit_id']);

      // Encode M2M fields as JSON
      final hasCardBrandIds = values.containsKey('card_brand_ids');
      String? cardBrandIds;
      final hasCardDeadlineCreditIds = values.containsKey('card_deadline_credit_ids');
      String? cardDeadlineCreditIds;
      final hasCardDeadlineDebitIds = values.containsKey('card_deadline_debit_ids');
      String? cardDeadlineDebitIds;

      if (values['card_brand_ids'] is List) {
        cardBrandIds = jsonEncode(values['card_brand_ids']);
      }
      if (values['card_deadline_credit_ids'] is List) {
        cardDeadlineCreditIds = jsonEncode(values['card_deadline_credit_ids']);
      }
      if (values['card_deadline_debit_ids'] is List) {
        cardDeadlineDebitIds = jsonEncode(values['card_deadline_debit_ids']);
      }

      // Update journal with card fields
      // Use Value(null) to clear a field, Value.absent() to leave unchanged
      await (db.update(db.accountJournal)
            ..where((t) => t.odooId.equals(journalId)))
          .write(AccountJournalCompanion(
        isCardJournal: isCardJournal != null ? Value(isCardJournal) : const Value.absent(),
        disponibleVentas: disponibleVentas != null ? Value(disponibleVentas) : const Value.absent(),
        disponiblePagos: disponiblePagos != null ? Value(disponiblePagos) : const Value.absent(),
        defaultCardBrandId: hasDefaultCardBrandId ? Value(defaultCardBrandId) : const Value.absent(),
        defaultCardDeadlineCreditId: hasDefaultDeadlineCreditId ? Value(defaultDeadlineCreditId) : const Value.absent(),
        defaultCardDeadlineDebitId: hasDefaultDeadlineDebitId ? Value(defaultDeadlineDebitId) : const Value.absent(),
        cardBrandIds: hasCardBrandIds ? Value(cardBrandIds ?? '[]') : const Value.absent(),
        cardDeadlineCreditIds: hasCardDeadlineCreditIds ? Value(cardDeadlineCreditIds ?? '[]') : const Value.absent(),
        cardDeadlineDebitIds: hasCardDeadlineDebitIds ? Value(cardDeadlineDebitIds ?? '[]') : const Value.absent(),
        writeDate: Value(DateTime.now()),
      ));

      logger.d('[NotificationProvider] ✅ Journal $journalId card config updated');
      logger.d('[NotificationProvider] Updated fields: cardBrandIds=$cardBrandIds, defaultBrand=$defaultCardBrandId');

      // Invalidate providers so UI refreshes with new card config
      ref.invalidate(posAvailableJournalsProvider);
      ref.invalidate(posCardBrandsByJournalProvider(journalId));
      // Invalidate deadlines for both card types
      ref.invalidate(posCardDeadlinesProvider((journalId: journalId, cardType: CardType.credit)));
      ref.invalidate(posCardDeadlinesProvider((journalId: journalId, cardType: CardType.debit)));
      logger.d('[NotificationProvider] 🔄 Journal card providers invalidated');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling journal update: $e');
    }
  }

  /// Handle payment method line update notification from Odoo WebSocket
  /// Updates payment method line in local database
  Future<void> _handlePaymentMethodLineUpdated(
    int lineId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete payment method line from local DB
        await (db.delete(db.accountPaymentMethodLine)
              ..where((t) => t.odooId.equals(lineId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ PaymentMethodLine $lineId deleted locally');
        // Invalidate journals provider so UI refreshes with updated payment methods
        ref.invalidate(posAvailableJournalsProvider);
        logger.d('[NotificationProvider] 🔄 posAvailableJournalsProvider invalidated');
        return;
      }

      if (values == null) return;

      // Upsert payment method line
      final name = values['name'] as String? ?? '';
      final paymentMethodId = values['payment_method_id'] is List
          ? (values['payment_method_id'] as List).first as int
          : values['payment_method_id'] as int? ?? 0;
      final paymentMethodName = values['payment_method_id'] is List && (values['payment_method_id'] as List).length > 1
          ? (values['payment_method_id'] as List)[1] as String?
          : null;
      final paymentMethodCode = values['payment_method_code'] as String?;
      final paymentType = values['payment_type'] as String?;
      final journalId = values['journal_id'] is List
          ? (values['journal_id'] as List).first as int
          : values['journal_id'] as int? ?? 0;
      final active = values['active'] as bool? ?? true;

      final companion = AccountPaymentMethodLineCompanion.insert(
        odooId: lineId,
        name: name,
        code: Value(paymentMethodCode),
        paymentMethodId: paymentMethodId,
        paymentMethodName: Value(paymentMethodName),
        journalId: journalId,
        journalName: Value(null), // Add journalName field
        paymentType: paymentType ?? 'inbound',
        active: Value(active),
        writeDate: Value(DateTime.now()),
      );
      // Use DoUpdate with target on odoo_id (not primary key id)
      await db.into(db.accountPaymentMethodLine).insert(
        companion,
        onConflict: DoUpdate(
          (old) => companion,
          target: [db.accountPaymentMethodLine.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ PaymentMethodLine $lineId upserted: $name');
      // Invalidate journals provider so UI refreshes with updated payment methods
      ref.invalidate(posAvailableJournalsProvider);
      logger.d('[NotificationProvider] 🔄 posAvailableJournalsProvider invalidated');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling payment method line update: $e');
    }
  }

  /// Handle advance update notification from Odoo WebSocket
  /// Updates advance in local database
  Future<void> _handleAdvanceUpdated(
    int advanceId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete advance from local DB
        await (db.delete(db.accountAdvance)
              ..where((t) => t.odooId.equals(advanceId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ Advance $advanceId deleted locally');
        return;
      }

      if (values == null) return;

      // Upsert advance
      final name = values['name'] as String? ?? '';
      final state = values['state'] as String? ?? 'draft';
      final advanceType = values['advance_type'] as String? ?? 'advance';
      final partnerType = values['partner_type'] as String? ?? 'customer';
      final partnerId = values['partner_id'] is List
          ? (values['partner_id'] as List).first as int
          : values['partner_id'] as int? ?? 0;
      final partnerName = values['partner_id'] is List && (values['partner_id'] as List).length > 1
          ? (values['partner_id'] as List)[1] as String?
          : values['partner_name'] as String?;
      final partnerVat = values['partner_vat'] as String?;
      final companyId = values['company_id'] is List
          ? (values['company_id'] as List).first as int
          : values['company_id'] as int? ?? 1;
      final currencyId = values['currency_id'] is List
          ? (values['currency_id'] as List).first as int?
          : values['currency_id'] as int?;
      final cashierId = values['cashier_id'] is List
          ? (values['cashier_id'] as List).first as int?
          : values['cashier_id'] as int?;
      final cashierName = values['cashier_id'] is List && (values['cashier_id'] as List).length > 1
          ? (values['cashier_id'] as List)[1] as String?
          : null;
      final reference = values['reference'] as String?;
      final dateStr = values['date'] as String?;
      final date = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
      final dateEstimatedStr = values['date_estimated'] as String?;
      final dateEstimated = dateEstimatedStr != null ? DateTime.tryParse(dateEstimatedStr) : null;
      final dateDueStr = values['date_due'] as String?;
      final dateDue = dateDueStr != null ? DateTime.tryParse(dateDueStr) : null;
      final amount = (values['amount'] as num?)?.toDouble() ?? 0.0;
      final amountUsed = (values['amount_used'] as num?)?.toDouble() ?? 0.0;
      final amountAvailable = (values['amount_available'] as num?)?.toDouble() ?? 0.0;
      final amountReturned = (values['amount_returned'] as num?)?.toDouble() ?? 0.0;
      final isExpired = values['is_expired'] as bool? ?? false;
      final collectionSessionId = values['collection_session_id'] is List
          ? (values['collection_session_id'] as List).first as int?
          : values['collection_session_id'] as int?;
      final collectionConfigId = values['collection_config_id'] is List
          ? (values['collection_config_id'] as List).first as int?
          : values['collection_config_id'] as int?;
      final saleOrderId = values['sale_order_id'] is List
          ? (values['sale_order_id'] as List).first as int?
          : values['sale_order_id'] as int?;

      final advanceCompanion = AccountAdvanceCompanion.insert(
        odooId: advanceId,
        name: name,
        state: Value(state),
        advanceType: advanceType,
        partnerType: partnerType,
        partnerId: partnerId,
        partnerName: Value(partnerName),
        partnerVat: Value(partnerVat),
        companyId: companyId,
        currencyId: Value(currencyId),
        cashierId: Value(cashierId),
        cashierName: Value(cashierName),
        reference: Value(reference),
        date: date,
        dateEstimated: Value(dateEstimated),
        dateDue: Value(dateDue),
        amount: Value(amount),
        amountUsed: Value(amountUsed),
        amountAvailable: Value(amountAvailable),
        amountReturned: Value(amountReturned),
        isExpired: Value(isExpired),
        collectionSessionId: Value(collectionSessionId),
        collectionConfigId: Value(collectionConfigId),
        saleOrderId: Value(saleOrderId),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.accountAdvance).insert(
        advanceCompanion,
        onConflict: DoUpdate(
          (old) => advanceCompanion,
          target: [db.accountAdvance.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ Advance $advanceId upserted: $name (available: $amountAvailable)');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling advance update: $e');
    }
  }

  /// Handle credit note update notification from Odoo WebSocket
  /// Updates credit note in local database
  Future<void> _handleCreditNoteUpdated(
    int moveId,
    String? action,
    Map<String, dynamic> payload,
  ) async {
    try {
      final db = _db;
      final values = payload['values'] as Map<String, dynamic>?;

      if (action == 'deleted') {
        // Delete credit note from local DB
        await (db.delete(db.accountCreditNote)
              ..where((t) => t.odooId.equals(moveId)))
            .go();
        logger.d('[NotificationProvider] 🗑️ CreditNote $moveId deleted locally');
        return;
      }

      if (values == null) return;

      // Upsert credit note
      final name = values['name'] as String? ?? '';
      final ref = values['ref'] as String?;
      final state = values['state'] as String? ?? 'draft';
      final partnerId = values['partner_id'] is List
          ? (values['partner_id'] as List).first as int
          : values['partner_id'] as int? ?? 0;
      final partnerName = values['partner_id'] is List && (values['partner_id'] as List).length > 1
          ? (values['partner_id'] as List)[1] as String?
          : values['partner_name'] as String?;
      final companyId = values['company_id'] is List
          ? (values['company_id'] as List).first as int
          : values['company_id'] as int? ?? 1;
      final dateStr = values['date'] as String?;
      final date = dateStr != null ? DateTime.tryParse(dateStr) ?? DateTime.now() : DateTime.now();
      final invoiceDateDueStr = values['invoice_date_due'] as String?;
      final invoiceDateDue = invoiceDateDueStr != null ? DateTime.tryParse(invoiceDateDueStr) : null;
      final amountTotal = (values['amount_total'] as num?)?.toDouble() ?? 0.0;
      final amountResidual = (values['amount_residual'] as num?)?.toDouble() ?? 0.0;

      final noteCompanion = AccountCreditNoteCompanion.insert(
        odooId: moveId,
        name: name,
        reference: Value(ref),
        partnerId: partnerId,
        partnerName: Value(partnerName),
        amount: Value(amountTotal),
        date: date,
        dateDue: Value(invoiceDateDue),
        state: Value(state),
        origin: Value(null), // Can be set if available
        companyId: companyId,
        companyName: Value(null), // Can be set if available
        active: const Value(true),
        writeDate: Value(DateTime.now()),
      );
      await db.into(db.accountCreditNote).insert(
        noteCompanion,
        onConflict: DoUpdate(
          (old) => noteCompanion,
          target: [db.accountCreditNote.odooId],
        ),
      );

      logger.d('[NotificationProvider] ✅ CreditNote $moveId upserted: $name (residual: $amountResidual)');
    } catch (e) {
      logger.e('[NotificationProvider] Error handling credit note update: $e');
    }
  }
}
