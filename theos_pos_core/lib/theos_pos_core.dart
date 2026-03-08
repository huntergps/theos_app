/// Theos POS Core - Data Layer
///
/// Pure Dart package containing:
/// - Models (Freezed classes for Odoo entities)
/// - Managers (OdooModelManager implementations for CRUD + sync)
/// - Database (Drift tables, datasources, repositories)
/// - Services (Business logic without UI dependencies)
///
/// This package has NO Flutter dependencies and can be used in:
/// - Flutter apps (theos_pos, theos_mobile, etc.)
/// - Dart CLI tools
/// - Dart backend servers
library theos_pos_core;

// Database exports
// AppDatabase and all Drift-generated types are now consolidated in theos_pos_core
// The app (theos_pos) no longer has its own database, it uses core's database directly
export 'src/database/database.dart';
export 'src/database/database_helper.dart';

// Models exports
export 'src/models/models.dart';

// Database datasources (concrete implementations)
export 'src/database/datasources/datasources.dart';

// Managers exports
// NOTE: Managers depend on theos_pos_core's AppDatabase which is incompatible
// with theos_pos's AppDatabase. Import individual managers directly if needed.
// For theos_pos, use local manager wrappers instead.
export 'src/managers/managers.dart';

// Services exports
export 'src/services/services.dart';

// Utils exports
export 'src/utils/utils.dart';

// Field registry — single source of truth for Odoo ↔ local field mappings
export 'src/odoo_field_registry.dart';

// Re-export commonly used types from dependencies
export 'package:odoo_sdk/odoo_sdk.dart'
    show
        // API
        OdooClient, OdooClientConfig, SyncResult,
        // Logging
        AppLogger, LogLevel, logger,
        // WebSocket
        OdooWebSocketService, OdooWebSocketConnectionInfo,
        // Utilities
        MoneyRounding, toStringOrNull,
        extractMany2oneId, extractMany2oneName,
        parseOdooDateTime, parseOdooDate, parseOdooBool,
        // Database
        IOdooDatabase,
        // Connectivity
        ServerHealthService, ConnectivityStatus, ServerConnectionState;
export 'package:odoo_sdk/odoo_sdk.dart'
    show OdooModelManager, OdooRecord, SmartOdooModel;
