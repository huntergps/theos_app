/// Provider definitions for sync-related services.
///
/// Separated from service implementations to keep service files
/// free of flutter_riverpod dependencies (pure Dart / reusable).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../../../core/services/websocket/odoo_websocket_service.dart';
import '../../../shared/providers/user_provider.dart';
import '../../sales/screens/fast_sale/fast_sale_providers.dart';
import '../../sales/screens/fast_sale/widgets/pos_payment_tab.dart'
    show posWithholdLinesByOrderProvider;
import '../../sales/providers/providers.dart'
    show saleOrderWithLinesProvider;
import '../services/data_purge_service.dart';
import '../services/websocket_sync_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart' hide DatabaseHelper;

// =============================================================================
// DataPurgeService
// =============================================================================

/// Provider for DataPurgeService
final dataPurgeServiceProvider = Provider<DataPurgeService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DataPurgeService(
    db,
    OfflineQueueDataSource(db),
    ref.watch(userRepositoryProvider),
  );
});

// =============================================================================
// WebSocketSyncService
// =============================================================================

/// Provider for WebSocketSyncService
final webSocketSyncServiceProvider = Provider<WebSocketSyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final wsService = ref.watch(odooWebSocketServiceProvider);
  final catalogRepo = ref.watch(catalogSyncRepositoryProvider);

  final service = WebSocketSyncService(
    db: db,
    wsService: wsService,
    catalogRepo: catalogRepo,
    getCurrentUser: () => ref.read(userProvider),
    onRefreshCurrentUser: () => ref.read(userProvider.notifier).fetchUser(),
    onWithholdLinesUpdate: (orderId, lines) {
      ref
          .read(posWithholdLinesByOrderProvider.notifier)
          .setLinesFromServer(orderId, lines);
    },
    onSaleOrdersInvalidate: () {},
    onSaleOrderInvalidate: (orderId) {
      ref.invalidate(saleOrderWithLinesProvider(orderId));
    },
    isOrderOpenInFastSale: (orderId) {
      final fastSale = ref.read(fastSaleProvider);
      return fastSale.tabs.any((tab) => tab.orderId == orderId);
    },
    onFastSaleOrderUpdate: (orderId, updateData) {
      ref
          .read(fastSaleProvider.notifier)
          .updateOrderFromWebSocket(orderId, updateData);
    },
  );
  service.initialize();
  ref.onDispose(() => service.dispose());
  return service;
});
