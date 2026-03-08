import 'package:theos_pos_core/theos_pos_core.dart';

/// Centralized service for client calculations
///
/// Like Odoo's computed fields with @api.depends, this service provides
/// all calculation methods for client data. Methods are organized as:
///
/// **Static methods (no database needed):**
/// - `computeCreditAvailable()` - Calculate available credit
/// - `computeCreditAfterOrder()` - Calculate credit after an order
/// - `computeCreditUsagePercentage()` - Calculate usage percentage
///
/// **Instance methods (require managers):**
/// - `computeEffectiveOfflineLimit()` - Calculate limit with safety margin
/// - `prepareCreditInfo()` - Prepare full credit info for display
///
/// Usage:
/// ```dart
/// // Static calculations (no DB needed)
/// final available = ClientCalculatorService.computeCreditAvailable(client);
///
/// // Instance calculations (use managers)
/// final calculator = ref.read(clientCalculatorProvider);
/// final effectiveLimit = await calculator.computeEffectiveOfflineLimit(
///   client,
///   isOffline: true,
/// );
/// ```
class ClientCalculatorService {
  /// Cache for company data
  Company? _cachedCompany;

  ClientCalculatorService();

  // ============ STATIC COMPUTED FIELD METHODS ============

  /// Compute credit_available = credit_limit - (credit + credit_to_invoice)
  ///
  /// Equivalent to @api.depends('credit_limit', 'credit', 'credit_to_invoice')
  /// Returns null if no credit limit is configured.
  static double? computeCreditAvailable(Client client) {
    if (!client.hasCreditLimit) return null;
    final used = (client.credit ?? 0) + (client.creditToInvoice ?? 0);
    return client.creditLimit! - used;
  }

  /// Compute credit available after a new order
  ///
  /// Returns null if no credit limit is configured.
  static double? computeCreditAfterOrder(Client client, double orderAmount) {
    final available = computeCreditAvailable(client);
    if (available == null) return null;
    return available - orderAmount;
  }

  /// Compute credit usage percentage
  ///
  /// Equivalent to @api.depends('credit_limit', 'credit', 'credit_to_invoice')
  /// Returns null if no credit limit is configured.
  static double? computeCreditUsagePercentage(Client client) {
    if (!client.hasCreditLimit) return null;
    final used = (client.credit ?? 0) + (client.creditToInvoice ?? 0);
    return (used / client.creditLimit!) * 100;
  }

  /// Check if credit is exceeded
  ///
  /// Equivalent to @api.depends('credit_available')
  static bool computeCreditExceeded(Client client) {
    final available = computeCreditAvailable(client);
    return available != null && available < 0;
  }

  /// Compute credit status for UI display
  ///
  /// Equivalent to @api.depends('credit_available', 'total_overdue')
  static CreditStatus computeCreditStatus(Client client) {
    if (!client.hasCreditLimit) return CreditStatus.noLimit;
    if ((client.totalOverdue ?? 0) > 0) return CreditStatus.overdueDebt;
    if (computeCreditExceeded(client)) return CreditStatus.exceeded;
    final usage = computeCreditUsagePercentage(client) ?? 0;
    if (usage >= 80) return CreditStatus.warning;
    return CreditStatus.ok;
  }

  /// Compute amount exceeded for an order
  ///
  /// Returns null if order doesn't exceed limit or no limit is configured.
  static double? computeExceededAmount(Client client, double orderAmount) {
    if (!client.hasCreditLimit) return null;
    final available = computeCreditAvailable(client) ?? 0;
    final afterOrder = available - orderAmount;
    return afterOrder < 0 ? -afterOrder : null;
  }

  // ============ INSTANCE METHODS (require database) ============

  /// Compute effective credit limit for offline operations
  ///
  /// When offline, we apply a safety margin to prevent "double spending"
  /// across multiple POS terminals.
  ///
  /// Example: Real limit $1000, margin 10% → Offline max $900
  Future<double> computeEffectiveOfflineLimit(
    Client client, {
    required bool isOffline,
  }) async {
    if (!client.hasCreditLimit) return 0;
    if (!isOffline) return client.creditLimit!;

    final company = await _getCompany();
    final margin = company?.creditOfflineSafetyMargin ?? 10;
    final effectiveLimit = client.creditLimit! * (1 - margin / 100);

    logger.d(
      '[ClientCalculator]',
      'Effective offline limit for ${client.id}: '
          '${client.creditLimit} * (1 - $margin%) = $effectiveLimit',
    );

    return effectiveLimit;
  }

  /// Get max stale hours from company configuration
  ///
  /// Use this when checking if client credit data is stale.
  Future<int> getMaxStaleHours() async {
    final company = await _getCompany();
    return company?.creditDataMaxAgeHours ?? 24;
  }

  /// Check if credit data is stale based on company configuration
  Future<bool> isCreditDataStale(Client client) async {
    final company = await _getCompany();
    final maxAgeHours = company?.creditDataMaxAgeHours ?? 24;
    return client.isCreditDataStale(maxAgeHours);
  }

  /// Get company data from cache or database
  Future<Company?> _getCompany() async {
    if (_cachedCompany != null) return _cachedCompany;

    try {
      // Get current user's company via datasources
      final currentUser = await userManager.getCurrentUser();
      if (currentUser?.companyId != null) {
        _cachedCompany = await companyManager.readLocal(currentUser!.companyId!);
      }
    } catch (e) {
      logger.w('[ClientCalculator]', 'Failed to load company: $e');
    }

    return _cachedCompany;
  }

  /// Clear cached data (call after sync)
  void clearCache() {
    _cachedCompany = null;
    logger.d('[ClientCalculator]', 'Cache cleared');
  }
}
