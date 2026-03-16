/// Provider definitions for AdvanceService.
///
/// Separated from the service implementation to keep service files
/// free of flutter_riverpod dependencies (pure Dart / reusable).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/banks/repositories/bank_repository.dart';
import '../../../core/services/odoo_service.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../services/advance_service.dart';

/// Provider for AdvanceService.
///
/// Returns `null` when [bankRepositoryProvider] is not yet initialized
/// (e.g., before the app completes its startup sequence).
///
/// Consumers MUST perform a null-check before using the service:
/// ```dart
/// final advanceService = ref.watch(advanceServiceProvider);
/// if (advanceService == null) return; // or show loading/disabled state
/// ```
final advanceServiceProvider = Provider<AdvanceService?>((ref) {
  final bankRepo = ref.watch(bankRepositoryProvider);
  if (bankRepo == null) return null;

  return AdvanceService(
    ref.watch(odooServiceProvider),
    bankRepo,
    ref.watch(offlineQueueDataSourceProvider),
  );
});
