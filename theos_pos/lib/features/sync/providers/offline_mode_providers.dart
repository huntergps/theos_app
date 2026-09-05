import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../services/offline_mode_service.dart';

/// Application-scoped offline-mode service.
final offlineModeServiceProvider = Provider<OfflineModeService>((ref) {
  // Import the implementation from repository_providers
  // This creates an instance without dependencies for basic operations
  // Full functionality requires odooClient to be initialized
  return OfflineModeService(db: ref.watch(appDatabaseProvider));
});

/// Offline mode config loaded from durable preferences.
///
/// Loading and corrupt-state errors remain explicit. Consumers that control
/// network access fail closed until this value is known.
final offlineModeConfigProvider = StreamProvider<OfflineModeConfig>((
  ref,
) async* {
  final service = ref.watch(offlineModeServiceProvider);
  yield await service.loadConfig();
});

/// Whether offline mode is currently active.
///
/// Derived from [offlineModeConfigProvider]. Loading/errors conservatively
/// disable remote work by reporting offline active.
final isOfflineModeActiveProvider = Provider<bool>((ref) {
  final config = ref.watch(offlineModeConfigProvider);
  return config.maybeWhen(data: (c) => c.isEnabled, orElse: () => true);
});

/// Current preload status.
///
/// Derived from [offlineModeConfigProvider]. Returns `idle` while loading.
final preloadStatusProvider = Provider<PreloadStatus>((ref) {
  final config = ref.watch(offlineModeConfigProvider);
  return config.maybeWhen(
    data: (c) => c.preloadStatus,
    orElse: () => PreloadStatus.idle,
  );
});

/// Reactive pending operations count — watches the offline queue table.
///
/// Auto-updates when operations are added/processed/removed from the queue.
final pendingOperationsCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(offlineModeServiceProvider);
  return service.watchPendingOperationsCount();
});
