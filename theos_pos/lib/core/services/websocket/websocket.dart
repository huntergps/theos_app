/// WebSocket Services - Real-time connection infrastructure
///
/// Provides WebSocket connection management, event handling,
/// and platform-specific connection implementations.
library;

export 'odoo_websocket_service.dart';
export 'odoo_websocket_events.dart';
// Note: websocket_connect_*.dart files are platform-specific
// and should be imported via conditional imports
