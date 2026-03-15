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

  /// Last raw notification for monitoring.
  Map<String, dynamic>? lastNotification;

  /// Parses a raw WebSocket message.
  ///
  /// Calls [onEvent] for each typed event produced.
  /// Calls [onNotification] for each raw notification (legacy API).
  /// Returns the list of raw notifications found.
  List<Map<String, dynamic>> parseMessage(
    dynamic message, {
    required void Function(OdooWebSocketEvent) onEvent,
    required void Function(Map<String, dynamic>) onNotification,
  }) {
    final notifications = <Map<String, dynamic>>[];

    try {
      final data = jsonDecode(message as String);

      if (data is List) {
        for (final item in data) {
          if (item is Map<String, dynamic>) {
            final notification =
                _processNotificationItem(item, onEvent: onEvent);
            if (notification != null) notifications.add(notification);
          }
        }
      } else if (data is Map<String, dynamic>) {
        final notification =
            _processNotificationItem(data, onEvent: onEvent);
        if (notification != null) notifications.add(notification);
      }
    } catch (e) {
      logger.e('[OdooWebSocket]', 'Error parsing message: $e');
    }

    for (final n in notifications) {
      onNotification(n);
    }

    return notifications;
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
        if (mapping.isOrderLineEvent) {
          final action = _parseActionFromType(type);
          _handleOrderLineEvent(payload, action, onEvent: onEvent);
        } else if (mapping.isCatalogEvent && mapping.catalogType != null) {
          _handleCatalogEvent(mapping.catalogType!, payload, onEvent: onEvent);
        } else {
          _handleRecordEvent(
              mapping.model, mapping.idField, mapping.nameField, payload,
              onEvent: onEvent);
        }
      }
    }

    // Always emit a raw notification event so consumers that listen for
    // OdooRawNotificationEvent receive ALL notifications regardless of
    // whether a typed handler or registry mapping exists.
    onEvent(OdooRawNotificationEvent(type: type, payload: payload));
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
      onEvent(OdooCompanyConfigEvent(
          companyId: companyId, newValues: newValues ?? {}));
    }
  }

  void _handleOrderLineEvent(
    Map<String, dynamic> payload,
    OdooRecordAction action, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    onEvent(OdooOrderLineEvent(
      lineId: payload['id'] as int? ?? 0,
      orderId: payload['order_id'] as int? ?? 0,
      action: action,
      values: payload,
      changedFields:
          (payload['changed_fields'] as List?)?.cast<String>() ?? [],
    ));
  }

  void _handleCatalogEvent(
    String catalogType,
    Map<String, dynamic> payload, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    final idField =
        WebSocketModelRegistry.instance.getCatalogIdField(catalogType);
    onEvent(OdooCatalogEvent(
      catalogType: catalogType,
      recordId: payload[idField] as int? ?? 0,
      action: parseRecordAction(payload['action'] as String?) ??
          OdooRecordAction.updated,
      values: payload,
    ));
  }

  void _handleRecordEvent(
    String model,
    String idField,
    String nameField,
    Map<String, dynamic> payload, {
    required void Function(OdooWebSocketEvent) onEvent,
  }) {
    final action = payload['action'] as String?;
    final recordAction = parseRecordAction(action);
    if (recordAction != null) {
      onEvent(OdooRecordEvent(
        model: model,
        recordId: payload[idField] as int? ?? 0,
        recordName: payload[nameField] as String?,
        action: recordAction,
        values: payload['values'] as Map<String, dynamic>? ?? payload,
        changedFields:
            (payload['changed_fields'] as List?)?.cast<String>() ?? [],
      ));
    }
  }
}
