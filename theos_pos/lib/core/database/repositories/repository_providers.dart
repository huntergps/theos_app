import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import '../database_helper.dart';
import '../../../features/sync/services/offline_mode_service.dart';
import '../../../features/sync/providers/offline_mode_providers.dart';
import '../../../features/sync/services/offline_sync_service.dart';
import '../../../features/products/services/stock_sync_service.dart';
import '../../services/handlers/related_record_resolver.dart';
import '../../services/platform/server_connectivity_service.dart';
import '../../managers/manager_providers.dart';

// Core Repositories
import 'common_repository.dart';
import '../../../features/company/repositories/company_repository.dart';

// Feature Repositories
import '../../../features/users/repositories/user_repository.dart';
import '../../../features/collection/repositories/collection_repository.dart';

// Feature Repositories (Simplified)
import '../../../features/activities/repositories/activity_repository.dart';
import '../../../features/authentication/repositories/auth_repository.dart';
import '../../../shared/providers/datasource_providers.dart';
import '../datasources/datasources.dart';

import '../../../features/sales/repositories/sales_repository.dart';
export '../../../features/sales/repositories/sales_repository.dart';
import '../../../features/products/repositories/product_repository.dart';
import '../../../features/clients/repositories/client_repository.dart';
import '../../../features/invoices/repositories/invoice_repository.dart';

// Catalog Sync Repository
import '../../../features/sync/repositories/catalog_sync_repository.dart';

// Re-export data classes
export '../../../features/sync/repositories/catalog_sync_repository.dart'
    show
        SyncProgress,
        SyncModelInfo,
        SyncCancelledException,
        SyncProgressCallback,
        PartnerSyncData,
        ProductSyncData,
        UomSyncData,
        UserSyncData,
        CompanySyncData;

part 'repository_providers.g.dart';

// ============ Core Infrastructure Providers ============
// Notifiers kept manual — @riverpod would change provider names

/// Notifier for OdooClient instance - null until initialized
class OdooClientNotifier extends Notifier<OdooClient?> {
  @override
  OdooClient? build() => null;

  void set(OdooClient? client) => state = client;
}

/// Provider for OdooClient instance - null until initialized
final odooClientProvider = NotifierProvider<OdooClientNotifier, OdooClient?>(
  () => OdooClientNotifier(),
);

/// Notifier for DatabaseHelper instance - null until initialized
class DatabaseHelperNotifier extends Notifier<DatabaseHelper?> {
  @override
  DatabaseHelper? build() => null;

  void set(DatabaseHelper? helper) => state = helper;
}

/// Provider for DatabaseHelper instance - null until initialized
final databaseHelperProvider =
    NotifierProvider<DatabaseHelperNotifier, DatabaseHelper?>(
      () => DatabaseHelperNotifier(),
    );

// ============ Core Providers (codegen) ============

@Riverpod(keepAlive: true)
OfflineQueueDataSource? offlineQueueDataSource(Ref ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  if (dbHelper == null) return null;
  return OfflineQueueDataSource(ref.watch(appDatabaseProvider));
}

// ============ Core Repository Providers ============

@Riverpod(keepAlive: true)
UserRepository? userRepository(Ref ref) {
  final odooClient = ref.watch(odooClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);

  if (odooClient == null || dbHelper == null) return null;

  return UserRepository(
    odooClient: odooClient,
    db: dbHelper,
    appDb: ref.watch(appDatabaseProvider),
  );
}

@Riverpod(keepAlive: true)
CommonRepository? commonRepository(Ref ref) {
  final odooClient = ref.watch(odooClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);
  final fieldSelectionDatasource = ref.watch(fieldSelectionDatasourceProvider);

  if (odooClient == null || dbHelper == null) return null;

  return CommonRepository(
    odooClient: odooClient,
    db: dbHelper,
    fieldSelectionDatasource: fieldSelectionDatasource,
  );
}

@Riverpod(keepAlive: true)
CollectionRepository? collectionRepository(Ref ref) {
  final odooClient = ref.watch(odooClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);
  final userRepo = ref.watch(userRepositoryProvider);
  final offlineQueue = ref.watch(offlineQueueDataSourceProvider);
  final sessionManager = ref.watch(collectionSessionManagerProvider);
  final paymentManager = ref.watch(accountPaymentManagerProvider);
  final cashOutMgr = ref.watch(cashOutManagerProvider);
  final sessionCashMgr = ref.watch(collectionSessionCashManagerProvider);
  final sessionDepositMgr = ref.watch(collectionSessionDepositManagerProvider);

  if (odooClient == null || dbHelper == null || userRepo == null) return null;

  return CollectionRepository(
    odooClient: odooClient,
    db: dbHelper,
    userRepository: userRepo,
    sessionManager: sessionManager,
    paymentManager: paymentManager,
    cashOutManager: cashOutMgr,
    sessionCashManager: sessionCashMgr,
    sessionDepositManager: sessionDepositMgr,
    offlineQueue: offlineQueue,
  );
}

@Riverpod(keepAlive: true)
CompanyRepository? companyRepository(Ref ref) {
  final odooClient = ref.watch(odooClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);

  if (odooClient == null || dbHelper == null) return null;

  return CompanyRepository(
    odooClient: odooClient,
    db: dbHelper,
  );
}

// ============ Feature Repository Providers ============

@Riverpod(keepAlive: true)
ActivityRepository activityRepository(Ref ref) {
  final odooClient = ref.watch(healthAwareOdooClientProvider);

  return ActivityRepository(
    odooClient: odooClient,
  );
}

@Riverpod(keepAlive: true)
AuthRepository authRepository(Ref ref) {
  final odooClient = ref.watch(odooClientProvider);

  return AuthRepository(odooClient: odooClient);
}

@Riverpod(keepAlive: true)
RelatedRecordResolver? relatedRecordResolver(Ref ref) {
  final odooClient = ref.watch(healthAwareOdooClientProvider);
  return RelatedRecordResolver(odooClient: odooClient, db: ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
ProductRepository? productRepository(Ref ref) {
  final odooClient = ref.watch(healthAwareOdooClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);

  if (dbHelper == null) return null;

  return ProductRepository(db: ref.watch(appDatabaseProvider), odooClient: odooClient);
}

@Riverpod(keepAlive: true)
ClientRepository? partnerRepository(Ref ref) {
  final odooClient = ref.watch(healthAwareOdooClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);

  if (dbHelper == null) return null;

  return ClientRepository(
    odooClient: odooClient,
    db: dbHelper,
    appDb: ref.watch(appDatabaseProvider),
  );
}

@Riverpod(keepAlive: true)
SalesRepository? salesRepository(Ref ref) {
  final odooClient = ref.watch(healthAwareOdooClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);
  final offlineQueue = ref.watch(offlineQueueDataSourceProvider);
  final relatedResolver = ref.watch(relatedRecordResolverProvider);
  final productRepository = ref.watch(productRepositoryProvider);

  if (dbHelper == null) return null;

  return SalesRepository(
    db: dbHelper,
    appDb: ref.watch(appDatabaseProvider),
    odooClient: odooClient,
    offlineQueue: offlineQueue,
    relatedResolver: relatedResolver,
    productRepository: productRepository,
  );
}
@Riverpod(keepAlive: true)
InvoiceRepository invoiceRepository(Ref ref) {
  final odooClient = ref.watch(healthAwareOdooClientProvider);
  final productRepository = ref.watch(productRepositoryProvider);

  return InvoiceRepository(
    odooClient: odooClient,
    productRepository: productRepository,
    appDb: ref.watch(appDatabaseProvider),
  );
}

@Riverpod(keepAlive: true)
OfflineSyncService? offlineSyncService(Ref ref) {
  final odooClient = ref.watch(odooClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);
  final offlineQueue = ref.watch(offlineQueueDataSourceProvider);
  final sessionManager = ref.watch(collectionSessionManagerProvider);
  final paymentManager = ref.watch(accountPaymentManagerProvider);

  if (dbHelper == null || offlineQueue == null) return null;

  return OfflineSyncService(
    db: dbHelper,
    appDb: ref.watch(appDatabaseProvider),
    odooClient: odooClient,
    offlineQueue: offlineQueue,
    sessionManager: sessionManager,
    paymentManager: paymentManager,
  );
}

@Riverpod(keepAlive: true)
CatalogSyncRepository? catalogSyncRepository(Ref ref) {
  final odooClient = ref.watch(healthAwareOdooClientProvider);
  final dbHelper = ref.watch(databaseHelperProvider);
  final productRepository = ref.watch(productRepositoryProvider);

  if (dbHelper == null) return null;

  return CatalogSyncRepository(
    db: dbHelper,
    odooClient: odooClient,
    productRepository: productRepository,
  );
}

// ============ Offline Mode Services ============

@Riverpod(keepAlive: true)
StockSyncService? stockSyncServiceImpl(Ref ref) {
  final odooClient = ref.watch(odooClientProvider);
  return StockSyncService(odooClient, ref.watch(appDatabaseProvider));
}

@Riverpod(keepAlive: true)
OfflineModeService offlineModeServiceImpl(Ref ref) {
  final odooClient = ref.watch(odooClientProvider);
  final stockSync = ref.watch(stockSyncServiceImplProvider);
  return OfflineModeService(
    odooClient: odooClient,
    stockSyncService: stockSync,
    db: ref.watch(appDatabaseProvider),
  );
}

/// Provider that returns OdooClient only if NOT in offline mode
@Riverpod(keepAlive: true)
OdooClient? effectiveOdooClient(Ref ref) {
  final odooClient = ref.watch(odooClientProvider);
  final offlineModeConfig = ref.watch(offlineModeConfigProvider);

  final isOfflineModeActive = offlineModeConfig.when(
    data: (config) => config.isEnabled,
    loading: () => false,
    error: (_, _) => false,
  );

  if (isOfflineModeActive) {
    return null;
  }

  return odooClient;
}

// ============ Helper Functions ============

/// Check if core dependencies are initialized (for WidgetRef)
bool areCoreProvidersReady(WidgetRef ref) {
  return ref.read(odooClientProvider) != null &&
      ref.read(databaseHelperProvider) != null;
}

/// Check if core dependencies are initialized (for Ref)
bool areCoreProvidersReadyFromRef(Ref ref) {
  return ref.read(odooClientProvider) != null &&
      ref.read(databaseHelperProvider) != null;
}
