import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../../core/database/repositories/repository_providers.dart';
import '../../../core/managers/manager_providers.dart' show appDatabaseProvider;
import '../../../core/services/platform/server_connectivity_service.dart';
import 'package:theos_pos_core/theos_pos_core.dart';
import '../services/client_validation_types.dart';
import '../repositories/client_repository.dart';
import '../services/client_calculator_service.dart';
import '../services/client_credit_service.dart';
import '../services/client_validation_service.dart';

part 'client_providers.g.dart';

// ============ CORE SERVICE PROVIDERS ============

@Riverpod(keepAlive: true)
ClientCalculatorService? clientCalculator(Ref ref) {
  return ClientCalculatorService();
}

@Riverpod(keepAlive: true)
ClientValidationService? clientValidation(Ref ref) {
  final calculator = ref.watch(clientCalculatorProvider);
  if (calculator == null) return null;
  return ClientValidationService(calculator);
}

@Riverpod(keepAlive: true)
ClientRepository? clientRepository(Ref ref) {
  final dbHelper = ref.watch(databaseHelperProvider);
  final odooClient = ref.watch(healthAwareOdooClientProvider);

  if (dbHelper == null || odooClient == null) return null;

  return ClientRepository(
    odooClient: odooClient,
    db: dbHelper,
    appDb: ref.watch(appDatabaseProvider),
  );
}

@Riverpod(keepAlive: true)
ClientCreditService? clientCreditService(Ref ref) {
  final calculator = ref.watch(clientCalculatorProvider);
  final validator = ref.watch(clientValidationProvider);
  final repository = ref.watch(clientRepositoryProvider);

  if (calculator == null || validator == null || repository == null) {
    return null;
  }

  return ClientCreditService(
    calculator: calculator,
    validator: validator,
    repository: repository,
  );
}

// ============ DATA PROVIDERS ============

/// Reactive stream of a client by ID using Drift's native watch.
///
/// Replaces the old FutureProvider [clientById] with a StreamProvider
/// that auto-re-emits whenever the partner record changes in the local DB.
final clientByIdProvider = StreamProvider.family<Client?, int>((ref, clientId) {
  return clientManager.watchPartner(clientId);
});

/// Search clients by query (name, VAT, email).
///
/// Offline-first: returns local results immediately, enriched with Odoo
/// data when online. The Odoo search saves results to local DB so they
/// become available for future offline searches.
@Riverpod(keepAlive: true)
Future<List<Client>> clientSearch(Ref ref, String query) async {
  final repository = ref.watch(clientRepositoryProvider);
  if (repository == null) return [];
  return repository.search(query);
}

/// Get client with credit data — offline-first with background refresh.
///
/// Uses a StreamProvider backed by Drift's `watchPartner()` so the UI
/// auto-updates when the partner record changes in the local DB.
/// On first subscription, triggers a background credit refresh from Odoo
/// (if online and data is stale). The refresh saves to local DB, which
/// causes the stream to re-emit automatically — true offline-first flow:
///
///   UI ← Stream(local DB) ← background refresh → Odoo → local DB → Stream re-emits
///
/// If offline, returns cached local data immediately with no error.
@Riverpod(keepAlive: true)
Stream<Client?> clientWithCredit(Ref ref, int clientId) {
  // Trigger background credit refresh (fire-and-forget)
  final creditService = ref.watch(clientCreditServiceProvider);
  if (creditService != null) {
    Future.microtask(() async {
      try {
        await creditService.getClientWithCredit(clientId, forceRefresh: false);
      } catch (_) {
        // Silently fail — local data is shown via the stream
      }
    });
  }

  // Reactive stream from local DB — auto-updates when data changes
  return clientManager.watchPartner(clientId);
}

@Riverpod(keepAlive: true)
Future<CreditValidationResult> validateOrderCredit(
  Ref ref,
  ({int clientId, double amount}) params,
) async {
  final creditService = ref.watch(clientCreditServiceProvider);
  if (creditService == null) return CreditValidationResult.ok();

  return creditService.validateOrderCredit(
    clientId: params.clientId,
    orderAmount: params.amount,
  );
}
