import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/repositories/repository_providers.dart'
    show odooClientProvider, offlineQueueDataSourceProvider;
import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../repositories/bank_repository.dart';

/// Application-scoped repository for bank and partner-bank operations.
///
/// The database is the offline source of truth. The configured Odoo client and
/// queue are injected when available, and Riverpod rebuilds this repository
/// after login or a server switch.
final bankRepositoryProvider = Provider<BankRepository>((ref) {
  return BankRepository(
    db: ref.watch(appDatabaseProvider),
    odooClient: ref.watch(odooClientProvider),
    offlineQueue: ref.watch(offlineQueueDataSourceProvider),
  );
});
