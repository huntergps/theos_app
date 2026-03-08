/// Offline Preloader (Generic)
///
/// Defines the interface for feature-specific preloaders used to
/// warm up offline data stores.
library;

import '../api/odoo_client.dart';

/// Interface for feature-specific offline data preloading.
///
/// [DB] allows host apps to pass their own database type.
abstract class OfflinePreloader<DB> {
  /// Human-readable name for progress display.
  String get modelName;

  /// Weight of this preloader in total progress (0.0 - 1.0).
  double get progressWeight;

  /// Preload data from Odoo to local database.
  ///
  /// [client] - Odoo client for API calls
  /// [db] - Local database for storage
  /// [limit] - Optional limit on records to preload (null = unlimited)
  /// [onProgress] - Optional callback for progress updates
  ///
  /// Returns the number of records preloaded.
  Future<int> preload({
    required OdooClient client,
    required DB db,
    int? limit,
    void Function(int loaded)? onProgress,
  });
}

/// Result of a preload operation for a single preloader.
class PreloaderResult {
  final String modelName;
  final int recordsLoaded;
  final Duration duration;
  final String? error;

  const PreloaderResult({
    required this.modelName,
    required this.recordsLoaded,
    required this.duration,
    this.error,
  });

  bool get success => error == null;
}

/// Registry for offline preloaders.
class OfflinePreloaderRegistry<DB> {
  final List<OfflinePreloader<DB>> _preloaders = [];

  /// Register a preloader.
  void register(OfflinePreloader<DB> preloader) {
    _preloaders.add(preloader);
  }

  /// Get all registered preloaders.
  List<OfflinePreloader<DB>> get preloaders => List.unmodifiable(_preloaders);

  /// Get total progress weight (should be ~1.0).
  double get totalWeight =>
      _preloaders.fold(0.0, (sum, p) => sum + p.progressWeight);
}
