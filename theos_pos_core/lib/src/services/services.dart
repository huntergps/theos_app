/// Services barrel export
///
/// Pure Dart business logic services (no Flutter dependencies).
/// Note: Services that depend on Flutter (UI, Riverpod) stay in the main app.
library;

// Price calculation services
export 'prices/prices.dart';

// Sales calculation services
export 'sales/sales.dart';
export 'sales/sale_draft_repository.dart';

// Tax calculation services
export 'taxes/taxes.dart';

export 'operations/operation_commands.dart';
export 'operations/operation_outcome.dart';
export 'operations/order_query.dart';
