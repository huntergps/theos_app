/// Provider definitions for AdvanceService.
///
/// Separated from the service implementation to keep service files
/// free of flutter_riverpod dependencies (pure Dart / reusable).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/banks/providers/bank_providers.dart';
import '../../../core/services/odoo_service.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../services/advance_service.dart';

/// Application-scoped service for advance operations.
final advanceServiceProvider = Provider<AdvanceService>((ref) {
  return AdvanceService(
    ref.watch(odooServiceProvider),
    ref.watch(bankRepositoryProvider),
    ref.watch(offlineQueueDataSourceProvider),
  );
});
