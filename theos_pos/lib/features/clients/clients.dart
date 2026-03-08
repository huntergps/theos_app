/// Clients feature module
///
/// Centralizes all client/partner-related functionality in one place.
/// Follows Odoo patterns for computed fields and validations.
///
/// **Models:**
/// - [Client] - Main client model with computed fields like Odoo @api.depends
/// - [CreditValidationResult] - Validation results for credit checks
///
/// **Services:**
/// - [ClientCalculatorService] - Computed fields and calculations (like _compute_* in Odoo)
/// - [ClientValidationService] - Validations (like @api.constrains in Odoo)
/// - [ClientCreditService] - Consolidated credit operations
///
/// **Repositories:**
/// - [ClientRepository] - Offline-first data access
///
/// **Providers:**
/// - [clientByIdProvider] - Reactive stream of client by ID (StreamProvider)
/// - [clientSearchProvider] - Search clients
/// - [clientWithCreditProvider] - Get client with fresh credit data
/// - [validateOrderCreditProvider] - Validate credit for order
///
/// Usage:
/// ```dart
/// // Watch client reactively (auto-updates on DB changes)
/// final clientAsync = ref.watch(clientByIdProvider(123));
///
/// // Computed fields (auto-calculated getters)
/// final available = client?.creditAvailable;
/// final status = client?.creditStatus;
///
/// // Validate credit for order
/// final creditService = ref.read(clientCreditServiceProvider);
/// final result = await creditService?.validateOrderCredit(
///   clientId: 123,
///   orderAmount: 500.0,
/// );
/// ```
library;

// Models - from theos_pos_core
export 'package:theos_pos_core/theos_pos_core.dart' show Client, CreditStatus, ClientManager, clientManager;

// Services
export 'services/client_validation_types.dart';
export 'services/client_calculator_service.dart';
export 'services/client_validation_service.dart';
export 'services/client_credit_service.dart';

// Repositories
export 'repositories/client_repository.dart';
export '../sync/repositories/partner_sync_repository.dart';

// Providers
export 'providers/client_providers.dart';

// Widgets
export 'widgets/widgets.dart';

