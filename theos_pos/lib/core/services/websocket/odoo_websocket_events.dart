/// Re-export WebSocket events from odoo_offline_core package
///
/// This file maintains backward compatibility with existing imports.
/// All WebSocket event types are now defined in the core package.
///
/// Usage remains the same:
/// ```dart
/// import 'package:theos_pos/core/services/websocket/odoo_websocket_events.dart';
///
/// wsService.eventStream.listen((event) {
///   switch (event) {
///     case OdooRecordEvent e: handleRecord(e);
///     case OdooPresenceEvent e: handlePresence(e);
///     case OdooConnectionEvent e: handleConnection(e);
///   }
/// });
/// ```
library;

export 'package:odoo_sdk/odoo_sdk.dart'
    show
        // Base event
        OdooWebSocketEvent,
        // Connection events
        OdooConnectionEvent,
        OdooErrorEvent,
        // Presence events
        OdooPresenceEvent,
        // Record events
        OdooRecordAction,
        OdooRecordEvent,
        // Specialized events
        OdooOrderLineEvent,
        OdooWithholdBulkEvent,
        OdooCompanyConfigEvent,
        OdooCatalogEvent,
        // Raw events
        OdooRawNotificationEvent,
        // Parsing utilities
        parseRecordAction,
        extractRecordId,
        extractRecordName;
