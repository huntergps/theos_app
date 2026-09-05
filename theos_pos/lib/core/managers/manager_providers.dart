/// Manager Providers - Riverpod integration for ModelManagers
///
/// Provides access to ModelManagers through Riverpod.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart';
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        ProductManager,
        productManager,
        ClientManager,
        clientManager,
        TaxManager,
        taxManager,
        SaleOrderManager,
        saleOrderManager,
        SaleOrderLineManager,
        saleOrderLineManager,
        CollectionSessionManager,
        collectionSessionManager,
        UserManager,
        userManager,
        AccountPaymentManager,
        accountPaymentManager,
        CashOutManager,
        cashOutManager,
        CollectionSessionCashManager,
        collectionSessionCashManager,
        CollectionSessionDepositManager,
        collectionSessionDepositManager,
        accountMoveManager,
        accountMoveLineManager,
        companyManager,
        collectionConfigManager,
        resCountryManager,
        resCountryStateManager,
        resLangManager,
        resourceCalendarManager,
        warehouseManager,
        pricelistManager,
        pricelistItemManager,
        paymentTermManager,
        advanceManager,
        mailActivityManager,
        uomManager,
        productUomManager,
        bankManager,
        partnerBankManager,
        salesTeamManager,
        fiscalPositionManager,
        productCategoryManager,
        withholdLineManager,
        paymentLineManager,
        cardLoteManager,
        advanceLineManager;
import 'package:theos_pos_core/theos_pos_core.dart'
    show AppDatabase, currencyManager, decimalPrecisionManager;

import '../database/database_helper.dart';
import '../database/repositories/repository_providers.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Database Provider
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the app database.
///
/// Watches [databaseHelperProvider] so that when the database is re-created
/// (e.g. after a server switch on login), this provider — and all downstream
/// providers that depend on it — automatically rebuild with the new DB.
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  // Watch databaseHelperProvider to trigger rebuild when DB changes
  ref.watch(databaseHelperProvider);
  return DatabaseHelper.database;
});

// ═══════════════════════════════════════════════════════════════════════════
// Individual Manager Providers
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for ProductManager (generated singleton)
final productManagerProvider = Provider<ProductManager>((ref) {
  return productManager;
});

/// Provider for ClientManager (was PartnerManager)
final partnerManagerProvider = Provider<ClientManager>((ref) {
  return clientManager;
});

/// Provider for TaxManager (generated singleton)
final taxManagerProvider = Provider<TaxManager>((ref) {
  return taxManager;
});

/// Provider for SaleOrderManager (generated singleton)
final saleOrderManagerProvider = Provider<SaleOrderManager>((ref) {
  return saleOrderManager;
});

/// Provider for SaleOrderLineManager (generated singleton)
final saleOrderLineManagerProvider = Provider<SaleOrderLineManager>((ref) {
  return saleOrderLineManager;
});

/// Provider for CollectionSessionManager (generated singleton)
final collectionSessionManagerProvider = Provider<CollectionSessionManager>((
  ref,
) {
  return collectionSessionManager;
});

/// Provider for UserManager (generated singleton)
final userManagerProvider = Provider<UserManager>((ref) {
  return userManager;
});

/// Provider for AccountPaymentManager (generated singleton)
final accountPaymentManagerProvider = Provider<AccountPaymentManager>((ref) {
  return accountPaymentManager;
});

/// Provider for CashOutManager (generated singleton)
final cashOutManagerProvider = Provider<CashOutManager>((ref) {
  return cashOutManager;
});

/// Provider for CollectionSessionCashManager (generated singleton)
final collectionSessionCashManagerProvider =
    Provider<CollectionSessionCashManager>((ref) {
      return collectionSessionCashManager;
    });

/// Provider for CollectionSessionDepositManager (generated singleton)
final collectionSessionDepositManagerProvider =
    Provider<CollectionSessionDepositManager>((ref) {
      return collectionSessionDepositManager;
    });

// ═══════════════════════════════════════════════════════════════════════════
// Model Registry Initialization
// ═══════════════════════════════════════════════════════════════════════════

/// All managers that need database initialization and registry registration.
/// Uses global singletons directly — no Ref needed.
List<OdooModelManager> _getAllManagers() {
  return [
    productManager,
    clientManager,
    taxManager,
    saleOrderManager,
    saleOrderLineManager,
    collectionSessionManager,
    userManager,
    accountPaymentManager,
    cashOutManager,
    collectionSessionCashManager,
    collectionSessionDepositManager,
    companyManager,
    collectionConfigManager,
    // Invoice managers
    accountMoveManager,
    accountMoveLineManager,
    // Catalog managers
    resCountryManager,
    resCountryStateManager,
    resLangManager,
    resourceCalendarManager,
    warehouseManager,
    pricelistManager,
    pricelistItemManager,
    paymentTermManager,
    advanceManager,
    mailActivityManager,
    uomManager,
    productUomManager,
    currencyManager,
    decimalPrecisionManager,
    bankManager,
    partnerBankManager,
    salesTeamManager,
    fiscalPositionManager,
    productCategoryManager,
    withholdLineManager,
    paymentLineManager,
    cardLoteManager,
    advanceLineManager,
  ];
}

/// Initializes all model managers with database access and registry registration.
/// Call once during app startup after database is ready.
///
/// The application has exactly one active user scope. Every entry path
/// (online login, offline login and cold-start restoration) must call this
/// same function so managers never retain a client, queue or memory cache from
/// another scope.
OfflineQueueWrapper? _activeManagerQueue;

Future<void> initializeModelManagers({
  required OfflineQueueStore queueStore,
  OdooClient? client,
  AppDatabase? db,
}) async {
  final appDb = db ?? DatabaseHelper.database;
  final managers = _getAllManagers();
  final queue = OfflineQueueWrapper(queueStore);
  await queue.initialize();

  for (final manager in managers) {
    manager.bindSession(client: client, db: appDb, queue: queue);
    ModelRegistry.register(manager);
  }

  final previousQueue = _activeManagerQueue;
  _activeManagerQueue = queue;
  previousQueue?.dispose();
}

/// Removes every dependency and in-memory record from the active manager
/// scope. This is intentionally synchronous and must run before Drift closes.
void resetModelManagersSession() {
  for (final manager in _getAllManagers()) {
    manager.resetSession();
  }
  ModelRegistry.resetSession();
  _activeManagerQueue?.dispose();
  _activeManagerQueue = null;
}
