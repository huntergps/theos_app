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
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase, currencyManager, decimalPrecisionManager;

import '../database/database_helper.dart';

// ═══════════════════════════════════════════════════════════════════════════
// Database Provider
// ═══════════════════════════════════════════════════════════════════════════

/// Provider for the app database
final appDatabaseProvider = Provider<AppDatabase>((ref) {
  // ignore: deprecated_member_use_from_same_package
  return DatabaseHelper.db;
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
final collectionSessionManagerProvider =
    Provider<CollectionSessionManager>((ref) {
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
/// Uses global manager singletons directly — no Ref or WidgetRef needed.
/// [db] is the AppDatabase instance to use for all managers.
void initializeModelManagers({AppDatabase? db}) {
  // ignore: deprecated_member_use_from_same_package
  final appDb = db ?? DatabaseHelper.db;
  final managers = _getAllManagers();

  for (final manager in managers) {
    manager.initDb(appDb);
    ModelRegistry.register(manager);
  }
}
