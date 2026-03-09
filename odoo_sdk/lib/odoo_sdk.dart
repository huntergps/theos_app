/// Odoo SDK — offline-first Flutter framework for Odoo 19.0+
///
/// Unified package combining networking, model management, sync,
/// WebSocket, and multi-context data layer functionality.
///
/// ## Quick start
///
/// ```dart
/// import 'package:odoo_sdk/odoo_sdk.dart';
///
/// final client = OdooClient(config: OdooClientConfig(
///   baseUrl: 'https://odoo.example.com',
///   apiKey: 'key_abc123',
///   database: 'production',
/// ));
/// ```
///
/// ## Sub-libraries
///
/// - `package:odoo_sdk/core.dart` — networking/API layer only
/// - `package:odoo_sdk/latam.dart` — Ecuador localization utilities
library;

// ═══════════════════════════════════════════════════════════════════════════════
// API / Networking
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/api/odoo_client.dart';
export 'src/api/odoo_exception.dart';
export 'src/api/odoo_version.dart';
export 'src/api/odoo_response_parser.dart';
export 'src/api/multi_tenant_manager.dart';
export 'src/api/client/odoo_http_client.dart';
export 'src/api/client/odoo_crud_api.dart';
export 'src/api/auth/odoo_auth_strategy.dart';
export 'src/api/auth/json_rpc_auth_strategy.dart';
export 'src/api/auth/mobile_auth_strategy.dart';
export 'src/api/session/odoo_session_manager.dart';
export 'src/api/session/session_persistence.dart';
export 'src/api/interceptors/auth_interceptor.dart';
export 'src/api/interceptors/cache_interceptor.dart';
export 'src/api/interceptors/compression_interceptor.dart';
export 'src/api/interceptors/metrics_interceptor.dart';
export 'src/api/interceptors/rate_limit_interceptor.dart';
export 'src/api/interceptors/retry_interceptor.dart';
export 'src/api/interceptors/log_sanitizer_interceptor.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Drift types needed by generated code
// ═══════════════════════════════════════════════════════════════════════════════

export 'package:drift/drift.dart'
    show Variable, RawValuesInsertable, GeneratedDatabase, TableInfo,
         CustomExpression;

// ═══════════════════════════════════════════════════════════════════════════════
// Database
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/database/interfaces/i_odoo_database.dart';
export 'src/database/repository/base_repository.dart';
export 'src/database/tables/offline_queue.dart';
export 'src/database/tables/sync_audit_log.dart';
export 'src/database/tables/system_tables.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// WebSocket
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/websocket/odoo_websocket_events.dart';
export 'src/websocket/odoo_websocket_service.dart';
export 'src/websocket/websocket_channel_manager.dart';
export 'src/websocket/websocket_connection_manager.dart';
export 'src/websocket/websocket_event_parser.dart';
export 'src/websocket/websocket_handler.dart';
export 'src/websocket/websocket_heartbeat_manager.dart';
export 'src/websocket/websocket_message_deduplicator.dart';
export 'src/websocket/websocket_model_registry.dart';
export 'src/websocket/websocket_reconnection_manager.dart';
export 'src/websocket/browser_session_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Services
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/services/device_service.dart';
export 'src/services/logger_service.dart';
export 'src/services/model_record_handler.dart';
export 'src/services/offline_preloader.dart';
export 'src/services/related_field_service.dart';
export 'src/services/polling_connectivity_monitor.dart';
export 'src/services/server_connectivity_service.dart';
export 'src/services/server_database_service.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Sync
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/sync/base_sync_repository.dart';
export 'src/sync/generic_sync_repository.dart';
export 'src/sync/offline_queue.dart';
export 'src/sync/offline_queue_processor.dart';
export 'src/sync/offline_queue_types.dart';
export 'src/sync/sync_coordinator.dart';
export 'src/sync/sync_metrics.dart';
export 'src/sync/sync_metrics_persistence.dart';
export 'src/sync/sync_models.dart';
export 'src/sync/sync_types.dart';
export 'src/sync/data_sync_orchestrator.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Errors
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/errors/exceptions.dart';
export 'src/errors/failures.dart';
export 'src/errors/result.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Model Management
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/model/odoo_model_manager.dart';
export 'src/model/odoo_record.dart';
export 'src/model/odoo_field_annotations.dart';
export 'src/model/smart_model_config.dart';
export 'src/model/smart_odoo_model.dart';
export 'src/model/model_registry.dart';
export 'src/model/field_definition.dart';
export 'src/model/computed_field_engine.dart';
export 'src/model/conflict_resolution.dart';
export 'src/model/drift_model_mixin.dart';
export 'src/model/generic_drift_operations.dart';
export 'src/model/related_record.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Interfaces
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/interfaces/i_cache.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Bridge
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/bridge/data_layer_bridge.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Security
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/security/secure_credential_store.dart';
export 'src/security/credential_guard.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// QWeb / Reports
// ═══════════════════════════════════════════════════════════════════════════════
// NOTE: qweb/ and reports/ depend on package:flutter_qweb which is handled
// separately. Import these files directly if you need them:
//   import 'package:odoo_sdk/src/qweb/odoo_client_adapter.dart';
//   import 'package:odoo_sdk/src/reports/qweb_template_repository.dart';
//   import 'package:odoo_sdk/src/reports/qweb_template_sync_repository.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Utils
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/utils/odoo_model_exceptions.dart';
export 'src/utils/odoo_parsing_utils.dart';
export 'src/utils/formatting_utils.dart';
export 'src/utils/fuzzy_search.dart';
export 'src/utils/lru_cache.dart';
export 'src/utils/record_cache.dart';
export 'src/utils/encrypted_record_cache.dart';
export 'src/utils/cache_constants.dart';
export 'src/utils/cache_encryption.dart';
export 'src/utils/security_utils.dart';
export 'src/utils/money_rounding.dart';
export 'src/utils/exponential_backoff.dart';
export 'src/utils/paginated_loader.dart';
export 'src/utils/related_field_result.dart';
export 'src/utils/sync_constants.dart';
export 'src/utils/type_guards.dart';
export 'src/utils/value_stream.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Data Layer (multi-context)
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/session/data_session.dart';
export 'src/context/data_context.dart';
export 'src/context/context_registries.dart';
export 'src/context/context_state.dart';
export 'src/facade/odoo_data_layer.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// Ecuador Localization
// ═══════════════════════════════════════════════════════════════════════════════

export 'src/utils/latam/ecuador_vat_validator.dart';
export 'src/utils/latam/sri_key_generator.dart';
