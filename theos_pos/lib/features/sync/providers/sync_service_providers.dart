/// Provider definitions for sync-related services.
///
/// Separated from service implementations to keep service files
/// free of flutter_riverpod dependencies (pure Dart / reusable).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../services/data_purge_service.dart';

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
