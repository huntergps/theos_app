/// Theos POS Core - Data Layer
///
/// Pure Dart package containing:
/// - Models (Freezed classes for Odoo entities)
/// - Managers (OdooModelManager implementations for CRUD + sync)
/// - Database (Drift tables and datasources)
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
export 'src/database/database.dart'
    hide NotificationEntry, NotificationDelivery;
export 'src/database/database_helper.dart';

// Models exports
export 'src/models/models.dart';
export 'src/models/collection/pos_app_capabilities.dart';

// Database datasources (concrete implementations)
export 'src/database/datasources/datasources.dart';

// Managers exports. Generated and domain-specific managers share this
// package's single AppDatabase instance.
export 'src/managers/managers.dart';

// Services exports
export 'src/services/services.dart';
export 'src/services/catalog/product_record_mapper.dart';
export 'src/services/catalog/warehouse_record_mapper.dart';
export 'src/services/catalog/pricelist_record_mapper.dart';
export 'src/services/catalog/payment_term_record_mapper.dart';
export 'src/services/catalog/tax_record_mapper.dart';
export 'src/services/catalog/partner_record_mapper.dart';
export 'src/services/catalog/journal_record_mapper.dart';
export 'src/services/catalog/uom_record_mapper.dart';
export 'src/services/operations/capability_provisioner.dart';
export 'src/services/operations/capability_snapshot_store.dart';
export 'src/services/catalog/collection_config_record_mapper.dart';
export 'src/services/catalog/collection_session_record_mapper.dart';
export 'src/services/catalog/payment_config_record_mapper.dart';
export 'src/notifications/notification_contracts.dart';
export 'src/notifications/notification_delivery.dart';
export 'src/notifications/notification_entry.dart';
export 'src/notifications/notification_inbox_store.dart';

// Utils exports
export 'src/utils/utils.dart';

// Field registry — single source of truth for Odoo ↔ local field mappings
export 'src/odoo_field_registry.dart';

// Re-export commonly used types from dependencies
export 'package:odoo_sdk/odoo_sdk.dart'
    show
        // API
        OdooClient,
        OdooClientConfig,
        SyncResult,
        // Logging
        AppLogger,
        LogLevel,
        logger,
        // WebSocket
        OdooWebSocketService,
        OdooWebSocketConnectionInfo,
        // Utilities
        MoneyRounding,
        toStringOrNull,
        extractMany2oneId,
        extractMany2oneName,
        parseOdooDateTime,
        parseOdooDate,
        parseOdooBool,
        // Database
        IOdooDatabase,
        // Connectivity
        ServerHealthService,
        ConnectivityStatus,
        ServerConnectionState;
export 'package:odoo_sdk/odoo_sdk.dart'
    show OdooModelManager, OdooRecord, SmartOdooModel;
