import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../services/stock_sync_service.dart';

/// Provider for StockSyncService
/// Note: Use stockSyncServiceProviderImpl from repository_providers.dart for full functionality
final stockSyncServiceProvider = Provider<StockSyncService>((ref) {
  // Basic provider without OdooClient - for read operations only
  return StockSyncService(null, ref.watch(appDatabaseProvider));
});

/// Provider for pending price changes count (reactive via Drift `.watch()`)
///
/// Auto-updates when the `productPriceChange` table changes — no need for
/// manual `ref.invalidate()`.
final pendingPriceChangesCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(stockSyncServiceProvider);
  return service.watchPendingPriceChanges().map((changes) => changes.length);
});

/// Provider for pending stock changes count (reactive via Drift `.watch()`)
///
/// Auto-updates when the `stockQuantityChange` table changes — no need for
/// manual `ref.invalidate()`.
final pendingStockChangesCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(stockSyncServiceProvider);
  return service.watchPendingStockChanges().map((changes) => changes.length);
});
