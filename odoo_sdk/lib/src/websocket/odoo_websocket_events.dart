/// Typed WebSocket events for Odoo real-time notifications
///
/// This module provides a type-safe event hierarchy for WebSocket notifications
/// from Odoo. Instead of using callbacks, consumers subscribe to a typed event
/// stream and pattern-match on event types.
///
/// Example usage:
/// ```dart
/// wsService.eventStream.listen((event) {
///   switch (event) {
///     case OdooPresenceEvent e:
///       print('User ${e.partnerId} is ${e.imStatus}');
///     case OdooRecordEvent e when e.model == 'sale.order':
///       print('Order ${e.recordId} was ${e.action}');
///     case OdooConnectionEvent e:
///       print('Connected: ${e.isConnected}');
///   }
/// });
/// ```
library;

import 'websocket_model_registry.dart';

/// Base class for all Odoo WebSocket events
sealed class OdooWebSocketEvent {
  final DateTime timestamp;

  OdooWebSocketEvent() : timestamp = DateTime.now();
}

// ============================================================================
// CONNECTION EVENTS
// ============================================================================

/// Event fired when WebSocket connection state changes
final class OdooConnectionEvent extends OdooWebSocketEvent {
  final bool isConnected;
  final bool isReconnection;
  final String? error;

  OdooConnectionEvent({
    required this.isConnected,
    this.isReconnection = false,
    this.error,
  });

  @override
  String toString() =>
      'OdooConnectionEvent(connected: $isConnected, reconnection: $isReconnection)';
}

/// Event fired when a WebSocket error occurs
final class OdooErrorEvent extends OdooWebSocketEvent {
  final Object error;
  final StackTrace? stackTrace;

  OdooErrorEvent(this.error, [this.stackTrace]);

  @override
  String toString() => 'OdooErrorEvent($error)';
}

// ============================================================================
// PRESENCE EVENTS
// ============================================================================

/// Event fired when a user's presence/IM status changes
final class OdooPresenceEvent extends OdooWebSocketEvent {
  final int partnerId;
  final String imStatus;

  OdooPresenceEvent({
    required this.partnerId,
    required this.imStatus,
  });

  @override
  String toString() => 'OdooPresenceEvent(partner: $partnerId, status: $imStatus)';
}

// ============================================================================
// RECORD EVENTS (CRUD operations)
// ============================================================================

/// Action type for record events
enum OdooRecordAction { created, updated, deleted }

/// Event fired when a record is created, updated, or deleted
final class OdooRecordEvent extends OdooWebSocketEvent {
  /// Odoo model name (e.g., 'sale.order', 'res.partner')
  final String model;

  /// Record ID
  final int recordId;

  /// Record display name (if available)
  final String? recordName;

  /// Action that triggered the event
  final OdooRecordAction action;

  /// Field values from server (for created/updated)
  final Map<String, dynamic> values;

  /// List of changed field names (for updated)
  final List<String> changedFields;

  /// Server write_date at time of change
  final DateTime? writeDate;

  OdooRecordEvent({
    required this.model,
    required this.recordId,
    this.recordName,
    required this.action,
    this.values = const {},
    this.changedFields = const [],
    this.writeDate,
  });

  /// Check if a specific field was changed
  bool hasField(String fieldName) => changedFields.contains(fieldName);

  /// Get a field value with type casting
  T? getValue<T>(String fieldName) {
    final value = values[fieldName];
    if (value is T) return value;
    return null;
  }

  @override
  String toString() =>
      'OdooRecordEvent($model[$recordId] ${action.name}, fields: ${changedFields.length})';
}

// ============================================================================
// SPECIALIZED RECORD EVENTS (for common patterns)
// ============================================================================

/// Event for sale order line changes (includes order context)
final class OdooOrderLineEvent extends OdooWebSocketEvent {
  final int lineId;
  final int orderId;
  final OdooRecordAction action;
  final Map<String, dynamic> values;
  final List<String> changedFields;

  OdooOrderLineEvent({
    required this.lineId,
    required this.orderId,
    required this.action,
    this.values = const {},
    this.changedFields = const [],
  });

  @override
  String toString() =>
      'OdooOrderLineEvent(line: $lineId, order: $orderId, ${action.name})';
}

/// Event for withhold line bulk updates
final class OdooWithholdBulkEvent extends OdooWebSocketEvent {
  final int orderId;
  final String? orderName;
  final List<Map<String, dynamic>> withholdLines;
  final double totalWithhold;
  final int lineCount;

  OdooWithholdBulkEvent({
    required this.orderId,
    this.orderName,
    required this.withholdLines,
    required this.totalWithhold,
    required this.lineCount,
  });

  @override
  String toString() =>
      'OdooWithholdBulkEvent(order: $orderId, lines: $lineCount, total: $totalWithhold)';
}

/// Event for company configuration changes
final class OdooCompanyConfigEvent extends OdooWebSocketEvent {
  final int companyId;
  final Map<String, dynamic> newValues;

  OdooCompanyConfigEvent({
    required this.companyId,
    required this.newValues,
  });

  @override
  String toString() =>
      'OdooCompanyConfigEvent(company: $companyId, fields: ${newValues.keys.toList()})';
}

/// Event for price/catalog updates (product prices, pricelist items, UoMs)
final class OdooCatalogEvent extends OdooWebSocketEvent {
  final String catalogType; // 'product_price', 'pricelist_item', 'uom'
  final int recordId;
  final OdooRecordAction action;
  final Map<String, dynamic> values;

  OdooCatalogEvent({
    required this.catalogType,
    required this.recordId,
    required this.action,
    this.values = const {},
  });

  @override
  String toString() =>
      'OdooCatalogEvent($catalogType[$recordId] ${action.name})';
}

// ============================================================================
// RAW NOTIFICATION EVENT (for unhandled types)
// ============================================================================

/// Event for raw/unhandled notifications
/// Consumers can handle custom notification types through this event
final class OdooRawNotificationEvent extends OdooWebSocketEvent {
  final String? type;
  final Map<String, dynamic> payload;

  OdooRawNotificationEvent({
    this.type,
    required this.payload,
  });

  @override
  String toString() => 'OdooRawNotificationEvent(type: $type)';
}

// ============================================================================
// EVENT PARSING UTILITIES
// ============================================================================

/// Parse action string to enum
OdooRecordAction? parseRecordAction(String? action) {
  return switch (action) {
    'created' => OdooRecordAction.created,
    'updated' => OdooRecordAction.updated,
    'deleted' => OdooRecordAction.deleted,
    _ => null,
  };
}

/// Extract record ID from various payload formats.
///
/// Uses [WebSocketModelRegistry] for model-specific ID field mappings.
int? extractRecordId(Map<String, dynamic> payload, String model) {
  final idField = WebSocketModelRegistry.instance.getIdField(model);

  final value = payload[idField] ?? payload['id'];
  if (value is int) return value;
  if (value is List && value.isNotEmpty) return value[0] as int?;
  return null;
}

/// Extract record name from payload.
///
/// Uses [WebSocketModelRegistry] for model-specific name field mappings.
String? extractRecordName(Map<String, dynamic> payload, String model) {
  final nameField = WebSocketModelRegistry.instance.getNameField(model);

  return payload[nameField] as String? ?? payload['name'] as String?;
}
