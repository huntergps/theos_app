import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../services/offline_mode_service.dart';

/// Provider for OfflineModeService
/// Note: Use offlineModeServiceProviderImpl from repository_providers.dart
/// This is kept for backward compatibility but delegates to the impl
final offlineModeServiceProvider = Provider<OfflineModeService>((ref) {
  // Import the implementation from repository_providers
  // This creates an instance without dependencies for basic operations
  // Full functionality requires odooClient to be initialized
  return OfflineModeService(db: ref.watch(appDatabaseProvider));
});

/// Offline mode config — non-blocking with sync default.
///
/// Starts with `const OfflineModeConfig()` (disabled, idle) immediately,
/// then loads the persisted config from SharedPreferences in the background.
/// Consumers never see a loading state — they get safe defaults first.
final offlineModeConfigProvider = StreamProvider<OfflineModeConfig>((ref) async* {
  // Emit default immediately so consumers never block on loading
  yield const OfflineModeConfig();

  // Then load persisted config
  final service = ref.watch(offlineModeServiceProvider);
  final persisted = await service.loadConfig();
  yield persisted;
});

/// Whether offline mode is currently active.
///
/// Derived from [offlineModeConfigProvider]. Returns `false` while loading.
final isOfflineModeActiveProvider = Provider<bool>((ref) {
  final config = ref.watch(offlineModeConfigProvider);
  return config.maybeWhen(data: (c) => c.isEnabled, orElse: () => false);
});

/// Current preload status.
///
/// Derived from [offlineModeConfigProvider]. Returns `idle` while loading.
final preloadStatusProvider = Provider<PreloadStatus>((ref) {
  final config = ref.watch(offlineModeConfigProvider);
  return config.maybeWhen(data: (c) => c.preloadStatus, orElse: () => PreloadStatus.idle);
});

/// Reactive pending operations count — watches the offline queue table.
///
/// Auto-updates when operations are added/processed/removed from the queue.
final pendingOperationsCountProvider = StreamProvider<int>((ref) {
  final service = ref.watch(offlineModeServiceProvider);
  return service.watchPendingOperationsCount();
});
