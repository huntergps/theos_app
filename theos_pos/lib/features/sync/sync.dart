/// Sync feature module
///
/// Centralizes all synchronization functionality:
/// - Offline-first sync with Odoo
/// - Catalog synchronization
/// - WebSocket sync
/// - Offline queue management
library;

// Repositories
export 'repositories/base_sync_repository.dart';
export 'repositories/catalog_sync_repository.dart';
export 'repositories/sync_models.dart';
export 'repositories/partner_sync_repository.dart';
export 'repositories/product_sync_repository.dart';
export 'repositories/sale_order_sync_repository.dart';
export 'repositories/user_sync_repository.dart';
export 'repositories/qweb_template_sync_repository.dart';

// Services
export 'services/offline_sync_service.dart' hide SyncFieldResult, SyncResult;
export 'services/offline_mode_service.dart';
export 'services/websocket_sync_service.dart' hide SyncFieldResult, SyncResult;
export 'services/connectivity_sync_orchestrator.dart';
export 'services/data_purge_service.dart';
export 'services/offline_preloader.dart';

// Providers
// Hide SyncStatus from sync_provider.dart - use the one from odoo_offline_core
export 'providers/sync_provider.dart' hide SyncStatus;
export 'providers/offline_mode_providers.dart';

// Screens
export 'screens/sync_screen.dart';
export 'screens/offline_sync_management_screen.dart';

// Widgets
export 'widgets/sync_widgets.dart';
