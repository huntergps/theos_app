/// Core Services - Main barrel file
///
/// Re-exports all core services organized by category.
/// Import this file for convenient access to all services.
library;

// ═══════════════════════════════════════════════════════════════════════════
// Root-level services (core infrastructure)
// ═══════════════════════════════════════════════════════════════════════════

export 'app_initializer.dart';
export 'config_service.dart';
export 'logger_service.dart';
export 'odoo_service.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Organized service categories
// ═══════════════════════════════════════════════════════════════════════════

export 'handlers/handlers.dart';
export 'websocket/websocket.dart';
export 'platform/platform.dart';

// Sync services moved to features/sync/
export '../../features/sync/services/offline_sync_service.dart' hide SyncFieldResult, SyncResult;
export '../../features/sync/services/offline_mode_service.dart';
export '../../features/sync/services/websocket_sync_service.dart' hide SyncFieldResult, SyncResult;
export '../../features/sync/services/connectivity_sync_orchestrator.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Re-exports from features (for backward compatibility)
// ═══════════════════════════════════════════════════════════════════════════

// Authentication
export '../../features/authentication/services/server_service.dart';

// Collection
export '../../features/collection/services/session_service.dart';

// Products
export '../../features/products/services/stock_sync_service.dart';
