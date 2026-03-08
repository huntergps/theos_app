/// Managers barrel export
///
/// All OdooModelManager implementations organized by domain.
/// Individual domain exports available via sub-barrels:
/// - `sales_managers.dart`
/// - `product_managers.dart`
/// - `collection_managers.dart`
/// - `invoice_managers.dart`
/// - `config_managers.dart`
library;

export 'sales_managers.dart';
export 'product_managers.dart';

// Clients
export 'clients/partner_manager.dart';

export 'collection_managers.dart';
export 'invoice_managers.dart';
export 'config_managers.dart';
