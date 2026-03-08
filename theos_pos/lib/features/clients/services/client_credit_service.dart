import 'package:theos_pos_core/theos_pos_core.dart';
import 'client_validation_types.dart';
import '../repositories/client_repository.dart';
import 'client_calculator_service.dart';
import 'client_validation_service.dart';

/// Consolidated service for all credit-related operations
///
/// This service combines credit calculation, validation, and data operations
/// into a single high-level API. Like Odoo's credit control system, it:
///
/// - Fetches credit data with offline-first pattern
/// - Validates credit limits and overdue debt
/// - Applies safety margins for offline scenarios
/// - Tracks data freshness (TTL)
///
/// Usage:
/// ```dart
/// final creditService = ref.read(clientCreditServiceProvider);
///
/// // Get credit info for display
/// final client = await creditService?.getClientWithCredit(123, forceRefresh: false);
///
/// // Validate before order confirmation
/// final result = await creditService?.validateOrderCredit(
///   clientId: 123,
///   orderAmount: 500.0,
/// );
///
/// if (result?.isValid == false) {
///   showError(result.message);
/// }
/// ```
class ClientCreditService {
  final ClientCalculatorService _calculator;
  final ClientValidationService _validator;
  final ClientRepository _repository;

  ClientCreditService({
    required ClientCalculatorService calculator,
    required ClientValidationService validator,
    required ClientRepository repository,
  })  : _calculator = calculator,
        _validator = validator,
        _repository = repository;

  // ============ CREDIT INFO OPERATIONS ============

  /// Get client with fresh credit data
  ///
  /// This is the main method to get credit data for UI display.
  /// - If [forceRefresh] is true, always fetches from Odoo
  /// - Otherwise, uses cached data if fresh (within TTL)
  /// - Returns [Client] with all computed credit fields
  Future<Client> getClientWithCredit(
    int clientId, {
    bool forceRefresh = false,
  }) async {
    final client = await _repository.getById(clientId);
    if (client == null) {
      throw ClientNotFoundException(clientId);
    }

    final isOnline = _repository.isOnline;

    // Refresh if forced or data is stale and we're online
    if (isOnline && (forceRefresh || await _calculator.isCreditDataStale(client))) {
      try {
        return await _repository.refreshCreditData(clientId);
      } catch (e) {
        logger.w('[ClientCreditService]', 'Failed to refresh credit data: $e');
        // Fall through to use cached data
      }
    }

    return client;
  }

  /// Get max stale hours for credit data from company config
  Future<int> getMaxStaleHours() => _calculator.getMaxStaleHours();

  // ============ CREDIT VALIDATION OPERATIONS ============

  /// Validate if an order can proceed based on credit
  ///
  /// This is the main entry point for order credit validation.
  /// Returns [CreditValidationResult] with:
  /// - `isValid` - whether order can proceed
  /// - `type` - type of validation result
  /// - `message` - user-friendly message
  /// - `creditAvailable` - available credit (if applicable)
  Future<CreditValidationResult> validateOrderCredit({
    required int clientId,
    required double orderAmount,
    bool bypassCheck = false,
  }) async {
    if (bypassCheck) {
      return CreditValidationResult.ok();
    }

    final client = await _repository.getById(clientId);
    if (client == null) {
      return CreditValidationResult.ok(); // No client = no credit check
    }

    final isOnline = _repository.isOnline;
    final company = await _getCompany();

    return _validator.validateCreditForOrder(
      client: client,
      orderAmount: orderAmount,
      isOnline: isOnline,
      company: company,
      bypassCheck: bypassCheck,
    );
  }

  /// Validate credit for a client object (no fetch)
  ///
  /// Use this when you already have the client object.
  Future<CreditValidationResult> validateOrderCreditForClient({
    required Client client,
    required double orderAmount,
    required bool isOnline,
    bool bypassCheck = false,
  }) async {
    if (bypassCheck) {
      return CreditValidationResult.ok();
    }

    final company = await _getCompany();

    return _validator.validateCreditForOrder(
      client: client,
      orderAmount: orderAmount,
      isOnline: isOnline,
      company: company,
      bypassCheck: bypassCheck,
    );
  }

  // ============ CREDIT HELPER OPERATIONS ============

  /// Check if client has overdue debt issues
  ///
  /// Returns true if the client has overdue debt that exceeds
  /// company-configured thresholds.
  Future<bool> hasOverdueDebtIssues(Client client) async {
    if (!client.hasOverdueDebt) return false;

    final company = await _getCompany();
    final daysThreshold = company?.creditOverdueDaysThreshold ?? 30;
    final invoicesThreshold = company?.creditOverdueInvoicesThreshold ?? 3;

    return (client.oldestOverdueDays ?? 0) >= daysThreshold ||
        (client.overdueInvoicesCount ?? 0) >= invoicesThreshold;
  }

  /// Get effective credit limit for a client
  ///
  /// Returns the effective limit considering:
  /// - If offline, applies safety margin
  /// - If credit control disabled, returns 0
  Future<double> getEffectiveLimit(Client client) async {
    final isOnline = _repository.isOnline;
    return _calculator.computeEffectiveOfflineLimit(
      client,
      isOffline: !isOnline,
    );
  }

  /// Check if credit data is stale
  ///
  /// Returns true if data is older than company-configured TTL.
  Future<bool> isCreditDataStale(Client client) async {
    return _calculator.isCreditDataStale(client);
  }

  /// Calculate credit available after an order
  ///
  /// Returns null if no credit limit is configured.
  double? creditAfterOrder(Client client, double orderAmount) {
    return ClientCalculatorService.computeCreditAfterOrder(client, orderAmount);
  }

  /// Check if order would exceed credit limit
  ///
  /// Returns the exceeded amount, or null if within limit.
  double? wouldExceedLimit(Client client, double orderAmount) {
    return ClientCalculatorService.computeExceededAmount(client, orderAmount);
  }

  // ============ INTERNAL HELPERS ============

  Future<Company?> _getCompany() async {
    try {
      return await _repository.getCompany();
    } catch (e) {
      logger.w('[ClientCreditService]', 'Failed to get company: $e');
      return null;
    }
  }

  /// Clear all caches (call after sync)
  void clearCache() {
    _calculator.clearCache();
    _repository.clearCache();
  }
}
