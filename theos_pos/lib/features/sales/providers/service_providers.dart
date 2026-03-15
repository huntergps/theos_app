/// Provider definitions for sales-related services.
///
/// Separated from service implementations to keep service files
/// free of flutter_riverpod dependencies (pure Dart / reusable).
///
/// Services wired here:
/// - [CashOutService] via [cashOutServiceProvider]
/// - [WithholdService] via [withholdServiceProvider]
/// - [PaymentService] via [paymentServiceProvider]
/// - [OrderDefaultsService] via [orderDefaultsServiceProvider] / [localOrderDefaultsProvider]
/// - [OrderLineCreationService] via [orderLineCreationServiceProvider]
/// - [OrderService] via [orderServiceProvider]
/// - [OrderConfirmationService] via [orderConfirmationServiceProvider]
/// - [CreditValidationUIService] via [creditValidationUIServiceProvider]
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/odoo_service.dart';
import '../../../core/database/providers.dart'
    show pricelistCalculatorProvider, taxCalculatorProvider;
import '../../../core/database/repositories/repository_providers.dart';
import '../../../features/banks/repositories/bank_repository.dart';
import '../../../core/managers/manager_providers.dart' show appDatabaseProvider, cashOutManagerProvider;
import '../../../shared/providers/company_config_provider.dart';
import '../../clients/clients.dart'
    show clientRepositoryProvider, clientCreditServiceProvider;
import '../services/cash_out_service.dart';
import '../services/withhold_service.dart';
import '../services/payment_service.dart';
import '../services/order_defaults_service.dart';
import '../services/order_line_creation_service.dart';
import '../services/order_service.dart';
import '../services/order_confirmation_service.dart';
import '../services/credit_validation_ui_service.dart';
import '../services/sale_order_logic_engine.dart';
import '../services/line_operations_helper.dart';

// =============================================================================
// CashOutService
// =============================================================================

final cashOutServiceProvider = Provider((ref) {
  return CashOutService(
    ref.watch(odooServiceProvider),
    ref.watch(cashOutManagerProvider),
    ref.watch(offlineQueueDataSourceProvider),
    ref.watch(appDatabaseProvider),
  );
});

// =============================================================================
// WithholdService
// =============================================================================

final withholdServiceProvider = Provider((ref) {
  return WithholdService(
    ref.watch(odooServiceProvider),
    salesRepo: ref.watch(salesRepositoryProvider),
  );
});

// =============================================================================
// PaymentService
// =============================================================================

/// Provider for PaymentService.
///
/// Note: This provider requires BankRepository to be available.
/// Returns PaymentService directly - will throw if BankRepository is not initialized.
final paymentServiceProvider = Provider<PaymentService>((ref) {
  final bankRepo = ref.watch(bankRepositoryProvider);
  if (bankRepo == null) {
    throw StateError(
      'PaymentService requires BankRepository to be initialized. '
      'Ensure the app is properly initialized before using payment features.',
    );
  }

  return PaymentService(
    ref.watch(odooServiceProvider),
    bankRepo,
    ref.watch(offlineQueueDataSourceProvider),
    ref.watch(appDatabaseProvider),
  );
});

// =============================================================================
// OrderDefaultsService
// =============================================================================

/// Provider for OrderDefaultsService
final orderDefaultsServiceProvider = Provider<OrderDefaultsService>((ref) {
  return OrderDefaultsService(
    db: ref.watch(appDatabaseProvider),
    salesRepo: ref.watch(salesRepositoryProvider),
  );
});

/// Provider that caches local defaults (auto-updates when company changes).
///
/// Stays as FutureProvider because [OrderDefaultsService.getLocalDefaults] does
/// multiple async lookups across different managers (userManager, companyManager,
/// partnerManager) that cannot be expressed as a single Drift `.watch()` stream.
///
/// Auto-refreshes when [currentCompanyProvider] emits a new value (e.g. after
/// WebSocket-driven company config update or manual refresh).
final localOrderDefaultsProvider = FutureProvider<OrderDefaults>((ref) async {
  // Watch company so this provider rebuilds when company config changes.
  ref.watch(currentCompanyProvider);

  final service = ref.watch(orderDefaultsServiceProvider);
  return await service.getLocalDefaults();
});

// =============================================================================
// OrderLineCreationService
// =============================================================================

/// Provider for OrderLineCreationService
final orderLineCreationServiceProvider = Provider<OrderLineCreationService>(
  (ref) => OrderLineCreationService(
    db: ref.watch(appDatabaseProvider),
    pricelistCalculator: ref.watch(pricelistCalculatorProvider),
    productRepository: ref.watch(productRepositoryProvider),
    taxCalculator: ref.watch(taxCalculatorProvider),
    maxDiscountResolver: () => getMaxDiscountPercentage(ref),
  ),
);

// =============================================================================
// OrderService
// =============================================================================

/// Provider for OrderService
final orderServiceProvider = Provider<OrderService>((ref) => OrderService(
      defaultsService: ref.read(orderDefaultsServiceProvider),
      salesRepo: ref.read(salesRepositoryProvider),
    ));

// =============================================================================
// CreditValidationUIService
// =============================================================================

/// Provider for CreditValidationUIService
///
/// Returns null if required dependencies are not available.
final creditValidationUIServiceProvider =
    Provider<CreditValidationUIService?>((ref) {
  final clientRepo = ref.watch(clientRepositoryProvider);
  final creditService = ref.watch(clientCreditServiceProvider);

  if (clientRepo == null || creditService == null) return null;

  return CreditValidationUIService(
    clientRepo: clientRepo,
    creditService: creditService,
  );
});

// =============================================================================
// OrderConfirmationService
// =============================================================================

/// Provider for OrderConfirmationService
final orderConfirmationServiceProvider = Provider<OrderConfirmationService>(
  (ref) => OrderConfirmationService(
    salesRepo: ref.watch(salesRepositoryProvider),
    logicEngine: ref.watch(saleOrderLogicEngineProvider),
    creditValidationService: ref.watch(creditValidationUIServiceProvider),
    offlineQueue: ref.watch(offlineQueueDataSourceProvider),
  ),
);

// =============================================================================
// SaleOrderLogicEngine
// =============================================================================

/// Provider for SaleOrderLogicEngine
final saleOrderLogicEngineProvider = Provider<SaleOrderLogicEngine>((ref) {
  return SaleOrderLogicEngine(
    getCompany: () => ref.read(currentCompanyProvider.future),
    getSalesConfig: () => ref.read(salesConfigProvider),
    productRepo: ref.watch(productRepositoryProvider),
    creditService: ref.watch(clientCreditServiceProvider),
  );
});

// =============================================================================
// LineOperationsHelper
// =============================================================================

/// Provider for LineOperationsHelper
final lineOperationsHelperProvider = Provider.family<LineOperationsHelper, String>(
  (ref, logTag) => LineOperationsHelper(
    ref.watch(orderLineCreationServiceProvider),
    logTag: logTag,
  ),
);
