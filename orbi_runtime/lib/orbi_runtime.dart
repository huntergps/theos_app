export 'src/contracts.dart';
export 'src/auth/credential_store.dart';
export 'src/auth/native_auth_service.dart';
export 'src/auth/capability_runtime.dart';
export 'src/auth/runtime_capability_service.dart';
export 'src/connectivity/connectivity_monitor.dart';
export 'src/notifications/installation_system_id_registry.dart';
export 'src/notifications/system_notification_presenter.dart';
export 'src/notifications/runtime_notification_inbox.dart';
export 'src/session/session_runtime.dart';
export 'src/warehouse/warehouse_operation_port.dart';
export 'src/storage/runtime_database_owner.dart';
export 'src/sales/sale_runtime_adapters.dart';
export 'src/sales/collection_operation_port.dart';
export 'src/sales/durable_collection_producers.dart';
export 'src/sales/payment_transaction_collection_port.dart';
export 'src/sales/sale_command_port.dart';
export 'src/sales/sale_draft_repository.dart';

export 'package:theos_pos_core/theos_pos_core.dart'
    show
        AppDatabase,
        OfflineQueueDataSource,
        SaleCatalogProduct,
        SaleCatalogPartner,
        SaleDraftLineRecord,
        SaleDraftRecord,
        SaleDraftRepository;

export 'src/sync/catalog_sync.dart';
export 'src/read/json2_read_adapters.dart';
export 'src/read/local_catalog_adapters.dart';
export 'src/read/runtime_catalog_composition.dart';
export 'src/read/runtime_metadata_store.dart';
export 'src/read/runtime_order_reader.dart';
export 'src/sync/sync_coordinator_impl.dart';
export 'src/sync/sync_job.dart';
export 'src/sync/operations_sync_job.dart';

export 'package:odoo_sdk/odoo_sdk.dart'
    show
        OdooClient,
        OdooClientConfig,
        OdooTransportMode,
        ConflictInfo,
        OfflineOperation,
        OfflineQueueStore,
        OfflineReplayPolicy,
        OdooAuthenticationException,
        OdooAccessDeniedException;
export 'package:drift/drift.dart' show Value;

// Domain capability type intentionally crosses the runtime boundary so UI
// consumers do not need an implementation import or a direct core dependency.
export 'package:theos_pos_core/theos_pos_core.dart'
    show
        CapabilitySnapshot,
        FiscalState,
        NotificationChannel,
        NotificationEntry,
        NotificationEvent,
        NotificationInboxStore,
        NotificationKind,
        NotificationOrigin,
        NotificationQuery,
        NotificationScope,
        NotificationSeverity,
        NotificationTarget,
        NotificationSystemIdAllocator,
        OperationSyncState,
        OrderQuery,
        OrderWorkQueue,
        SaleOrderState;
export 'package:theos_pos_core/theos_pos_core.dart'
    show
        EntityReference,
        PaymentTermInstallment,
        SaleTermsClassification,
        SaleApprovalState,
        SaleDraftPayload,
        SaleShiftState,
        SaleConfirmationPayload,
        OfflineFiscalInvoicePayload,
        SaleDeliveryGate,
        SaleFiscalAction,
        OperationOutcome;
export 'package:theos_pos_core/theos_pos_core.dart'
    show
        AppDatabase,
        OfflineQueueCompanion,
        CollectionReconciliationPort,
        SaleCollectionPort,
        SaleCommandStore,
        SaleOperationOrchestrator,
        SaleShiftStore;
export 'package:theos_pos_core/theos_pos_core.dart' show OfflineQueueDataSource;
