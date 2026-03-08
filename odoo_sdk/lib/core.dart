/// Odoo SDK Core — networking and API layer
///
/// Provides the HTTP client, interceptors, WebSocket service,
/// offline queue infrastructure, and error types.
///
/// This is equivalent to the old `package:odoo_offline_core`.
library;

// API / Networking
export 'src/api/odoo_client.dart';
export 'src/api/odoo_exception.dart';
export 'src/api/odoo_response_parser.dart';
export 'src/api/multi_tenant_manager.dart';
export 'src/api/client/odoo_http_client.dart';
export 'src/api/client/odoo_crud_api.dart';
export 'src/api/auth/odoo_auth_strategy.dart';
export 'src/api/auth/json_rpc_auth_strategy.dart';
export 'src/api/auth/mobile_auth_strategy.dart';
export 'src/api/session/odoo_session_manager.dart';
export 'src/api/interceptors/auth_interceptor.dart';
export 'src/api/interceptors/cache_interceptor.dart';
export 'src/api/interceptors/compression_interceptor.dart';
export 'src/api/interceptors/metrics_interceptor.dart';
export 'src/api/interceptors/rate_limit_interceptor.dart';
export 'src/api/interceptors/retry_interceptor.dart';

// Database
export 'src/database/interfaces/i_odoo_database.dart';
export 'src/database/repository/base_repository.dart';
export 'src/database/tables/offline_queue.dart';
export 'src/database/tables/sync_audit_log.dart';
export 'src/database/tables/system_tables.dart';

// WebSocket
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

// Services
export 'src/services/device_service.dart';
export 'src/services/logger_service.dart';
export 'src/services/server_connectivity_service.dart';
export 'src/services/server_database_service.dart';

// Sync infrastructure
export 'src/sync/base_sync_repository.dart';
export 'src/sync/offline_queue.dart';
export 'src/sync/offline_queue_processor.dart';
export 'src/sync/offline_queue_types.dart';
export 'src/sync/sync_metrics.dart';
export 'src/sync/sync_models.dart';
export 'src/sync/sync_types.dart';

// Errors
export 'src/errors/exceptions.dart';
export 'src/errors/failures.dart';
export 'src/errors/result.dart';

// Utils
export 'src/utils/odoo_parsing_utils.dart';
export 'src/utils/formatting_utils.dart';
export 'src/utils/exponential_backoff.dart';
export 'src/utils/money_rounding.dart';
export 'src/utils/lru_cache.dart';
export 'src/utils/cache_constants.dart';
export 'src/utils/value_stream.dart';
