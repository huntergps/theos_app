import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show Company;
import '../../core/database/repositories/repository_providers.dart';
import '../../core/services/websocket/odoo_websocket_service.dart';
import '../../core/services/logger_service.dart';

part 'company_config_provider.g.dart';

/// Provider for current user's company configuration
///
/// Returns the company with sales config from local cache (offline-first).
/// Automatically syncs with server when online.
///
/// ## Usage
/// ```dart
/// final company = ref.watch(currentCompanyProvider).valueOrNull;
/// final validityDays = company?.quotationValidityDays ?? 30;
/// ```
@riverpod
Future<Company?> currentCompany(Ref ref) async {
  logger.d('[CurrentCompany]', 'Provider building...');

  final companyRepo = ref.watch(companyRepositoryProvider);
  if (companyRepo == null) {
    logger.w('[CurrentCompany]', 'companyRepo is NULL - returning null');
    return null;
  }

  logger.d('[CurrentCompany]', 'Calling getCurrentUserCompany()...');
  final company = await companyRepo.getCurrentUserCompany();
  logger.d(
    '[CurrentCompany]',
    'Got company: ${company?.name}, maxDiscount=${company?.maxDiscountPercentage}',
  );
  return company;
}

/// Provider for sales configuration defaults
///
/// Extracts only the sales-related configuration from company.
/// Returns sensible defaults if company is not available.
///
/// ## Usage
/// ```dart
/// final salesConfig = ref.watch(salesConfigProvider);
/// final validityDays = salesConfig.quotationValidityDays;
/// ```
@riverpod
SalesConfig salesConfig(Ref ref) {
  final companyAsync = ref.watch(currentCompanyProvider);
  final company = companyAsync.hasValue ? companyAsync.value : null;

  // Debug: Log the actual values being read
  logger.d(
    '[SalesConfig]',
    'Building config: isLoading=${companyAsync.isLoading}, '
    'hasValue=${companyAsync.hasValue}, hasError=${companyAsync.hasError}, '
    'maxDiscount=${company?.maxDiscountPercentage}',
  );

  return SalesConfig(
    quotationValidityDays: company?.quotationValidityDays ?? 30,
    portalConfirmationSign: company?.portalConfirmationSign ?? true,
    portalConfirmationPay: company?.portalConfirmationPay ?? false,
    prepaymentPercent: company?.prepaymentPercent ?? 1.0,
    saleDiscountProductId: company?.saleDiscountProductId,
    saleDiscountProductName: company?.saleDiscountProductName,
    defaultPricelistId: company?.defaultPricelistId,
    defaultPricelistName: company?.defaultPricelistName,
    defaultPaymentTermId: company?.defaultPaymentTermId,
    defaultPaymentTermName: company?.defaultPaymentTermName,
    // Ecuador SRI configuration
    saleCustomerInvoiceLimitSri: company?.saleCustomerInvoiceLimitSri,
    l10nEcLegalName: company?.l10nEcLegalName,
    l10nEcProductionEnv: company?.l10nEcProductionEnv ?? false,
    // Sales workflow configuration
    pedirEndCustomerData: company?.pedirEndCustomerData ?? false,
    pedirSaleReferrer: company?.pedirSaleReferrer ?? false,
    pedirTipoCanalCliente: company?.pedirTipoCanalCliente ?? false,
    // Credit control configuration
    creditOverdueDaysThreshold: company?.creditOverdueDaysThreshold ?? 30,
    creditOverdueInvoicesThreshold: company?.creditOverdueInvoicesThreshold ?? 3,
    maxDiscountPercentage: company?.maxDiscountPercentage ?? 100.0,
    // Reservation configuration
    reservationExpiryDays: company?.reservationExpiryDays ?? 7,
    reservationWarehouseId: company?.reservationWarehouseId,
    reservationWarehouseName: company?.reservationWarehouseName,
    reservationLocationId: company?.reservationLocationId,
    reservationLocationName: company?.reservationLocationName,
    reserveFromQuotation: company?.reserveFromQuotation ?? false,
  );
}

/// Get max discount percentage from database
///
/// This reads directly from the database to avoid async timing issues.
/// Falls back to 100.0 only if database is not available.
/// Works with both Ref and WidgetRef.
Future<double> getMaxDiscountPercentage(dynamic ref) async {
  try {
    final company = await ref.read(currentCompanyProvider.future);
    final maxDiscount = company?.maxDiscountPercentage ?? 100.0;
    logger.d('[MaxDiscount]', 'maxDiscountPercentage=$maxDiscount%');
    return maxDiscount;
  } catch (e) {
    logger.w('[MaxDiscount]', 'Error getting max discount: $e, defaulting to 100%');
    return 100.0;
  }
}

/// Provider for refreshing company configuration
///
/// Call this after login or when settings might have changed.
@riverpod
class CompanyConfigRefresh extends _$CompanyConfigRefresh {
  @override
  FutureOr<void> build() {}

  Future<void> refresh() async {
    final companyRepo = ref.read(companyRepositoryProvider);
    if (companyRepo == null) return;

    await companyRepo.syncCurrentUserCompany();

    // Invalidate currentCompany to re-fetch
    ref.invalidate(currentCompanyProvider);
  }

  Future<void> refreshCompany(int companyId) async {
    final companyRepo = ref.read(companyRepositoryProvider);
    if (companyRepo == null) return;

    await companyRepo.refreshCompany(companyId);
    ref.invalidate(currentCompanyProvider);
  }
}

/// Sales configuration data class
///
/// Contains only the sales-related settings from res.company.
/// Used for applying defaults to sale orders.
class SalesConfig {
  final int quotationValidityDays;
  final bool portalConfirmationSign;
  final bool portalConfirmationPay;
  final double prepaymentPercent;
  final int? saleDiscountProductId;
  final String? saleDiscountProductName;
  final int? defaultPricelistId;
  final String? defaultPricelistName;
  final int? defaultPaymentTermId;
  final String? defaultPaymentTermName;

  // Ecuador SRI configuration
  final double? saleCustomerInvoiceLimitSri;
  final String? l10nEcLegalName;
  final bool l10nEcProductionEnv;

  // Sales workflow configuration
  final bool pedirEndCustomerData;
  final bool pedirSaleReferrer;
  final bool pedirTipoCanalCliente;

  // Credit control configuration
  final int creditOverdueDaysThreshold;
  final int creditOverdueInvoicesThreshold;
  final double maxDiscountPercentage;

  // Reservation configuration
  final int reservationExpiryDays;
  final int? reservationWarehouseId;
  final String? reservationWarehouseName;
  final int? reservationLocationId;
  final String? reservationLocationName;
  final bool reserveFromQuotation;

  const SalesConfig({
    this.quotationValidityDays = 30,
    this.portalConfirmationSign = true,
    this.portalConfirmationPay = false,
    this.prepaymentPercent = 1.0,
    this.saleDiscountProductId,
    this.saleDiscountProductName,
    this.defaultPricelistId,
    this.defaultPricelistName,
    this.defaultPaymentTermId,
    this.defaultPaymentTermName,
    // Ecuador SRI configuration
    this.saleCustomerInvoiceLimitSri,
    this.l10nEcLegalName,
    this.l10nEcProductionEnv = false,
    // Sales workflow configuration
    this.pedirEndCustomerData = false,
    this.pedirSaleReferrer = false,
    this.pedirTipoCanalCliente = false,
    // Credit control configuration
    this.creditOverdueDaysThreshold = 30,
    this.creditOverdueInvoicesThreshold = 3,
    this.maxDiscountPercentage = 100.0,
    // Reservation configuration
    this.reservationExpiryDays = 7,
    this.reservationWarehouseId,
    this.reservationWarehouseName,
    this.reservationLocationId,
    this.reservationLocationName,
    this.reserveFromQuotation = false,
  });

  /// Calculate validity date from order date
  DateTime calculateValidityDate(DateTime orderDate) {
    return orderDate.add(Duration(days: quotationValidityDays));
  }

  /// Check if signature is required for portal confirmation
  bool get requiresSignature => portalConfirmationSign;

  /// Check if payment is required for portal confirmation
  bool get requiresPayment => portalConfirmationPay;

  /// Get prepayment as percentage (0-100 scale)
  double get prepaymentPercentage => prepaymentPercent * 100;

  /// Check if we're in production environment for SRI
  bool get isProductionEnvironment => l10nEcProductionEnv;

  /// Check if end customer data should be requested
  bool get shouldRequestEndCustomerData => pedirEndCustomerData;

  /// Check if sale referrer should be requested
  bool get shouldRequestSaleReferrer => pedirSaleReferrer;

  /// Check if customer channel type should be requested
  bool get shouldRequestTipoCanalCliente => pedirTipoCanalCliente;

  /// Check if reservations should be made from quotation
  bool get shouldReserveFromQuotation => reserveFromQuotation;

  @override
  String toString() => 'SalesConfig('
      'validityDays: $quotationValidityDays, '
      'sign: $portalConfirmationSign, '
      'pay: $portalConfirmationPay, '
      'prepay: ${prepaymentPercentage.toStringAsFixed(0)}%, '
      'maxDiscount: ${maxDiscountPercentage.toStringAsFixed(0)}%)';
}

/// Provider that sets up WebSocket listener for company config changes
///
/// This provider subscribes to the WebSocket event stream to listen
/// for `OdooCompanyConfigEvent` notifications from Odoo and automatically
/// refreshes the local company cache when changes are detected.
///
/// ## Usage
/// Watch this provider early in your app (e.g., in a top-level widget or after login):
/// ```dart
/// ref.watch(companyConfigWebSocketListenerProvider);
/// ```
@riverpod
void companyConfigWebSocketListener(Ref ref) {
  final wsService = ref.watch(odooWebSocketServiceProvider);

  // Subscribe to typed event stream for company config updates
  final subscription = wsService.eventStream.listen((event) {
    if (event is OdooCompanyConfigEvent) {
      logger.i(
        '[CompanyConfig]',
        'WebSocket: company ${event.companyId} config updated',
      );
      logger.d(
        '[CompanyConfig]',
        'New values: ${event.newValues}',
      );

      // Refresh the company data from the server
      ref.read(companyConfigRefreshProvider.notifier).refreshCompany(event.companyId);
    }
  });

  // Cleanup subscription when provider is disposed
  ref.onDispose(() {
    subscription.cancel();
  });
}
