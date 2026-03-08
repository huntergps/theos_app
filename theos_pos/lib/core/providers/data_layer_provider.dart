/// Provider definitions for OdooDataLayer multi-context support.
///
/// Progressive migration: existing code continues to use
/// [odooClientProvider] and [appDatabaseProvider]. New features
/// can use [odooDataLayerProvider] and [activeDataContextProvider]
/// for context-isolated data access.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart'
    show OdooDataLayer, DataContext, DataSession;
import 'package:theos_pos_core/theos_pos_core.dart'
    show
        OfflineQueueDataSource,
        // Managers (global singletons)
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
        accountMoveManager,
        accountMoveLineManager,
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
        productUomManager;

import '../managers/manager_providers.dart' show appDatabaseProvider;

/// Singleton OdooDataLayer instance.
///
/// Manages multiple [DataContext]s and keeps track of which one is active.
/// The active context's managers are automatically synced to the global
/// [OdooRecordRegistry].
final odooDataLayerProvider = Provider<OdooDataLayer>((ref) {
  final layer = OdooDataLayer();
  ref.onDispose(() => layer.dispose());
  return layer;
});

/// The currently active [DataContext], or null if none initialized.
///
/// Watches [odooDataLayerProvider] and the active context's stream.
/// Returns null until [initializeDataContext] is called.
final activeDataContextProvider = StreamProvider<DataContext?>((ref) {
  final layer = ref.watch(odooDataLayerProvider);
  return layer.contextChanges.map((_) => layer.activeContext);
});

/// Initialize the POS data context using existing app infrastructure.
///
/// This bridges the current initialization flow (AppInitializer + DatabaseHelper)
/// with the new OdooDataLayer multi-context architecture.
///
/// Call after [AppInitializer.initialize()] and [initializeModelManagers()]
/// have completed.
Future<void> initializeDataContext(
  WidgetRef ref, {
  required String sessionId,
  required String label,
  required String baseUrl,
  required String database,
  required String apiKey,
}) async {
  final layer = ref.read(odooDataLayerProvider);

  // Skip if context already exists
  if (layer.getContext(sessionId) != null) return;

  final db = ref.read(appDatabaseProvider);

  final session = DataSession(
    id: sessionId,
    label: label,
    baseUrl: baseUrl,
    database: database,
    apiKey: apiKey,
  );

  final queueStore = OfflineQueueDataSource(db);

  await layer.createAndInitializeContext(
    session: session,
    database: db,
    queueStore: queueStore,
    registerModels: _registerAllModels,
    setActive: true,
  );
}

/// Register all model managers into a [DataContext].
///
/// This mirrors [initializeModelManagers()] but for the context-based
/// architecture. Each global singleton manager is registered so the
/// context can manage its lifecycle.
void _registerAllModels(DataContext ctx) {
  ctx.registerManager(productManager);
  ctx.registerManager(clientManager);
  ctx.registerManager(taxManager);
  ctx.registerManager(saleOrderManager);
  ctx.registerManager(saleOrderLineManager);
  ctx.registerManager(collectionSessionManager);
  ctx.registerManager(userManager);
  ctx.registerManager(accountPaymentManager);
  ctx.registerManager(cashOutManager);
  ctx.registerManager(collectionSessionCashManager);
  ctx.registerManager(collectionSessionDepositManager);
  ctx.registerManager(companyManager);
  ctx.registerManager(collectionConfigManager);
  ctx.registerManager(accountMoveManager);
  ctx.registerManager(accountMoveLineManager);
  ctx.registerManager(resCountryManager);
  ctx.registerManager(resCountryStateManager);
  ctx.registerManager(resLangManager);
  ctx.registerManager(resourceCalendarManager);
  ctx.registerManager(warehouseManager);
  ctx.registerManager(pricelistManager);
  ctx.registerManager(paymentTermManager);
  ctx.registerManager(advanceManager);
  ctx.registerManager(mailActivityManager);
  ctx.registerManager(uomManager);
  ctx.registerManager(productUomManager);
}
