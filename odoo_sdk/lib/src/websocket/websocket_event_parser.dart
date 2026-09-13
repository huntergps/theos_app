/// Internal event parser for OdooWebSocketService.
///
/// Parses raw WebSocket messages into typed [OdooWebSocketEvent] instances.
library;

import 'dart:convert';

import '../services/logger_service.dart';
import 'odoo_websocket_events.dart';
import 'websocket_model_registry.dart';

/// Parses raw WebSocket messages into typed events.
///
/// Handles JSON decoding, notification item processing, and
/// dispatching to type-specific handlers.
class WebSocketEventParser {
  int _lastNotificationId = 0;

  /// Last notification ID from the server.
  int get lastNotificationId => _lastNotificationId;

  /// Seeds [lastNotificationId] with a value persisted from a previous
  /// session (see [OdooWebSocketConnectionInfo.initialLast] in
  /// `odoo_websocket_service.dart`), so the next `subscribe` message resumes
  /// from there instead of starting at 0. Only meant to be called once,
  /// before any live message has moved the id forward.
  void seedLastNotificationId(int value) {
    _lastNotificationId = value;
  }

  /// Last raw notification for monitoring.
  Map<String, dynamic>? lastNotification;

  /// Parses a raw WebSocket message.
  ///
  /// Calls [onEvent] for each typed event produced.
  /// Returns the list of raw notifications found.
  List<Map<String, dynamic>> parseMessage(
    dynamic message, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    final notifications = <Map<String, dynamic>>[];

    try {
      final data = jsonDecode(message as String);

      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            if (item['internal'] == true) {
              _processInternalMessage(item, onEvent: onEvent);
              continue;
            }
            final notification = _processNotificationItem(
              item,
              onEvent: onEvent,
            );
            if (notification != null) notifications.add(notification);
          }
        }
      } else if (data is Map<String, dynamic>) {
        if (data['internal'] == true) {
          _processInternalMessage(data, onEvent: onEvent);
        } else {
          final notification = _processNotificationItem(data, onEvent: onEvent);
          if (notification != null) notifications.add(notification);
        }
      }
    } catch (e) {
      logger.e('[OdooWebSocket]', 'Error parsing message: $e');
    }

    return notifications;
  }

  /// Handles a `subscribe`-bookkeeping message from the server (`internal:
  /// true` — never a real notification, so it never touches
  /// [lastNotification] and is never counted towards [parseMessage]'s
  /// returned list). See `odoo_websocket_events.dart` for the wire shape and
  /// where each type comes from server-side.
  void _processInternalMessage(
    Map<String, dynamic> item, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    switch (item['type']) {
      case 'bus/subscription_outdated':
        onEvent(OdooSubscriptionOutdatedEvent());
      case 'bus/last_id_reset':
        final newId = item['payload'];
        if (newId is int) {
          _lastNotificationId = newId;
          onEvent(OdooLastIdResetEvent(newId));
        }
    }
  }

  /// Process a single notification item from the WebSocket message.
  ///
  /// Returns the notification map if valid, or null if it should be skipped.
  Map<String, dynamic>? _processNotificationItem(
    Map<String, dynamic> item, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    try {
      // Update last notification ID
      if (item.containsKey('id')) {
        _lastNotificationId = item['id'] as int;
      }

      if (!item.containsKey('message')) return null;

      final notification = item['message'];
      if (notification is! Map<String, dynamic>) return null;

      lastNotification = notification;

      final type = notification['type'] as String?;
      _processNotificationType(type, notification, onEvent: onEvent);

      return notification;
    } catch (e) {
      logger.e('[OdooWebSocket]', 'Error processing notification: $e');
      return null;
    }
  }

  /// Process notification type and emit appropriate typed events.
  void _processNotificationType(
    String? type,
    Map<String, dynamic> notification, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    final payload = notification['payload'];
    if (payload is! Map<String, dynamic>) return;

    // Handle special built-in types
    switch (type) {
      case 'bus.bus/im_status_updated':
        _handlePresenceUpdate(payload, onEvent: onEvent);
      case 'company_config_updated':
        _handleCompanyConfigUpdate(payload, onEvent: onEvent);
    }

    // Look up in registry for model-based notification types
    if (type != null) {
      final mapping = WebSocketModelRegistry.instance.getMapping(type);
      if (mapping != null) {
        final action = _resolveAction(type, payload);
        if (mapping.isOrderLineEvent) {
          _handleOrderLineEvent(payload, action, onEvent: onEvent);
        } else if (mapping.isCatalogEvent && mapping.catalogType != null) {
          _handleCatalogEvent(
            mapping.catalogType!,
            action,
            payload,
            onEvent: onEvent,
          );
        } else {
          _handleRecordEvent(
            mapping.model,
            mapping.idField,
            mapping.nameField,
            action,
            payload,
            onEvent: onEvent,
          );
        }
      }
    }

    // Always emit a raw notification event so consumers that listen for
    // OdooRawNotificationEvent receive ALL notifications regardless of
    // whether a typed handler or registry mapping exists.
    onEvent(OdooRawNotificationEvent(type: type, payload: payload));
  }

  /// Resolves the record action for a notification.
  ///
  /// POS-style types (e.g. `sale_order_updated`) always carry the type
  /// `_updated` and put the real action inside `payload.action`
  /// (`created`/`updated`/`deleted`), so that takes priority. Base types
  /// that don't carry `payload.action` fall back to the `_created`/
  /// `_deleted` suffix on the type itself, defaulting to `updated`.
  OdooRecordAction _resolveAction(String type, Map<String, dynamic> payload) {
    return parseRecordAction(payload['action'] as String?) ??
        _parseActionFromType(type);
  }

  OdooRecordAction _parseActionFromType(String type) {
    if (type.endsWith('_created')) return OdooRecordAction.created;
    if (type.endsWith('_deleted')) return OdooRecordAction.deleted;
    return OdooRecordAction.updated;
  }

  void _handlePresenceUpdate(
    Map<String, dynamic> payload, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    final imStatus = payload['im_status'] as String?;
    final partnerId = payload['partner_id'] as int?;
    if (imStatus != null && partnerId != null) {
      onEvent(OdooPresenceEvent(partnerId: partnerId, imStatus: imStatus));
    }
  }

  void _handleCompanyConfigUpdate(
    Map<String, dynamic> payload, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    final companyId = payload['company_id'] as int?;
    final newValues = payload['new_values'] as Map<String, dynamic>?;
    if (companyId != null) {
      onEvent(
        OdooCompanyConfigEvent(
          companyId: companyId,
          newValues: newValues ?? {},
        ),
      );
    }
  }

  void _handleOrderLineEvent(
    Map<String, dynamic> payload,
    OdooRecordAction action, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    onEvent(
      OdooOrderLineEvent(
        lineId: payload['id'] as int? ?? 0,
        orderId: payload['order_id'] as int? ?? 0,
        action: action,
        values: payload,
        changedFields:
            (payload['changed_fields'] as List?)?.cast<String>() ?? [],
      ),
    );
  }

  void _handleCatalogEvent(
    String catalogType,
    OdooRecordAction action,
    Map<String, dynamic> payload, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    final idField = WebSocketModelRegistry.instance.getCatalogIdField(
      catalogType,
    );
    onEvent(
      OdooCatalogEvent(
        catalogType: catalogType,
        recordId: payload[idField] as int? ?? 0,
        action: action,
        values: payload,
      ),
    );
  }

  void _handleRecordEvent(
    String model,
    String idField,
    String nameField,
    OdooRecordAction action,
    Map<String, dynamic> payload, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    onEvent(
      OdooRecordEvent(
        model: model,
        recordId: payload[idField] as int? ?? 0,
        recordName: payload[nameField] as String?,
        action: action,
        values: payload['values'] as Map<String, dynamic>? ?? payload,
        changedFields:
            (payload['changed_fields'] as List?)?.cast<String>() ?? [],
      ),
    );
  }
}
