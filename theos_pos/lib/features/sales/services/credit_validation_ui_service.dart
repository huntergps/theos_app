import '../../../core/services/logger_service.dart';
import '../../clients/clients.dart';

/// Unified result type for credit validation in UI context
///
/// Used by both Fast Sale and Sale Order Form screens.
class UnifiedCreditResult {
  /// Whether a credit dialog needs to be shown
  final bool requiresDialog;

  /// Whether the operation can proceed without showing a dialog
  final bool canProceed;

  /// The client being validated (if available)
  final Client? client;

  /// Detailed validation result from ClientValidationService
  final CreditValidationResult? validationResult;

  /// The order amount being validated
  final double orderAmount;

  /// Whether we're currently online
  final bool isOnline;

  /// Error message if validation failed
  final String? errorMessage;

  const UnifiedCreditResult({
    required this.requiresDialog,
    required this.canProceed,
    this.client,
    this.validationResult,
    this.orderAmount = 0,
    this.isOnline = false,
    this.errorMessage,
  });

  /// Validation passed - can proceed without showing dialog
  factory UnifiedCreditResult.proceed() => const UnifiedCreditResult(
        requiresDialog: false,
        canProceed: true,
      );

  /// No validation needed (no client, no credit limit, etc.)
  factory UnifiedCreditResult.notRequired() => const UnifiedCreditResult(
        requiresDialog: false,
        canProceed: true,
      );

  /// Error occurred during validation
  factory UnifiedCreditResult.error(String message) => UnifiedCreditResult(
        requiresDialog: false,
        canProceed: false,
        errorMessage: message,
      );

  /// Credit issues found - need to show dialog
  factory UnifiedCreditResult.showDialog({
    required Client client,
    required CreditValidationResult validationResult,
    required double orderAmount,
    required bool isOnline,
  }) =>
      UnifiedCreditResult(
        requiresDialog: true,
        canProceed: false,
        client: client,
        validationResult: validationResult,
        orderAmount: orderAmount,
        isOnline: isOnline,
      );
}

/// Service for credit validation in UI context
///
/// Provides a unified interface for validating client credit
/// across both Fast Sale and Sale Order Form screens.
///
/// Features:
/// - Fetches client from local DB using ClientRepository
/// - Optionally refreshes data from Odoo if online
/// - Validates against company credit configuration
/// - Returns unified result for UI handling
class CreditValidationUIService {
  final ClientRepository _clientRepo;
  final ClientCreditService _creditService;

  CreditValidationUIService({
    required ClientRepository clientRepo,
    required ClientCreditService creditService,
  })  : _clientRepo = clientRepo,
        _creditService = creditService;

  /// Validate credit for a client
  ///
  /// Parameters:
  /// - [clientId]: The client/partner ID to validate
  /// - [orderAmount]: The order amount for credit calculation
  /// - [skipIfBypassed]: If true and bypass flag is set, skip validation
  /// - [isBypassed]: Whether credit check has been bypassed
  /// - [logTag]: Tag for logging (e.g., '[FastSale]', '[SaleOrderForm]')
  ///
  /// Returns [UnifiedCreditResult] indicating:
  /// - proceed: Validation passed
  /// - notRequired: No validation needed
  /// - showDialog: Credit issues, need to show dialog
  /// - error: Validation failed
  Future<UnifiedCreditResult> validateCredit({
    required int? clientId,
    required double orderAmount,
    bool skipIfBypassed = true,
    bool isBypassed = false,
    String logTag = '[CreditValidation]',
  }) async {
    // Check bypass flag
    if (skipIfBypassed && isBypassed) {
      logger.d(logTag, 'Credit check bypassed');
      return UnifiedCreditResult.notRequired();
    }

    // Check client ID
    if (clientId == null) {
      logger.d(logTag, 'No client ID provided');
      return UnifiedCreditResult.notRequired();
    }

    try {
      // 1. Get client using ClientRepository
      Client? client = await _clientRepo.getById(clientId);

      if (client == null) {
        logger.w(logTag, 'Client $clientId not found in local DB');
        return UnifiedCreditResult.notRequired();
      }

      // 2. Check if credit limit is configured
      if (!client.hasCreditLimit) {
        logger.d(logTag, 'Client ${client.name} has no credit limit');
        return UnifiedCreditResult.proceed();
      }

      // 3. Determine online status
      final isOnline = _clientRepo.isOnline;

      // 4. If online and data is stale, refresh credit data
      if (isOnline && client.isCreditDataStale(1)) {
        try {
          final refreshedClient = await _clientRepo.refreshCreditData(clientId);
          client = refreshedClient;
        } catch (e) {
          logger.w(logTag, 'Failed to refresh credit data: $e');
          // Continue with local data
        }
      }

      // 5. Validate credit using ClientCreditService
      // client is guaranteed non-null at this point (checked earlier)
      final result = await _creditService.validateOrderCreditForClient(
        client: client!,
        orderAmount: orderAmount,
        isOnline: isOnline,
        bypassCheck: false,
      );

      // 6. Return result
      if (!result.isValid) {
        logger.i(
          logTag,
          'Credit validation failed: ${result.message ?? result.type.name}',
        );
        return UnifiedCreditResult.showDialog(
          client: client,
          validationResult: result,
          orderAmount: orderAmount,
          isOnline: isOnline,
        );
      }

      logger.d(logTag, 'Credit validation passed');
      return UnifiedCreditResult.proceed();
    } catch (e, stack) {
      logger.e(logTag, 'Error validating credit', e, stack);
      return UnifiedCreditResult.error('Error al validar crédito: $e');
    }
  }

  /// Quick check if client has credit limit configured
  ///
  /// Returns true if client exists and has credit limit > 0
  Future<bool> hasClientCreditLimit(int clientId) async {
    try {
      final client = await _clientRepo.getById(clientId);
      return client?.hasCreditLimit ?? false;
    } catch (e) {
      logger.w('[CreditValidation]', 'Error checking credit limit: $e');
      return false;
    }
  }
}
