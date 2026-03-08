/// Provider definitions for AdvanceService.
///
/// Separated from the service implementation to keep service files
/// free of flutter_riverpod dependencies (pure Dart / reusable).
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/banks/repositories/bank_repository.dart';
import '../../../core/services/odoo_service.dart';
import '../services/advance_service.dart';

/// Provider for AdvanceService.
///
/// Note: This provider requires BankRepository to be available.
/// Returns AdvanceService directly - will throw if BankRepository is not initialized.
final advanceServiceProvider = Provider<AdvanceService>((ref) {
  final bankRepo = ref.watch(bankRepositoryProvider);
  if (bankRepo == null) {
    throw StateError(
      'AdvanceService requires BankRepository to be initialized. '
      'Ensure the app is properly initialized before using payment features.',
    );
  }

  return AdvanceService(
    ref.watch(odooServiceProvider),
    bankRepo,
  );
});
