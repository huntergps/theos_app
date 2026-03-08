/// Services barrel export
///
/// Pure Dart business logic services (no Flutter dependencies).
/// Note: Services that depend on Flutter (UI, Riverpod) stay in the main app.
library;

// Re-export logger from odoo_offline_core
export 'package:odoo_sdk/odoo_sdk.dart'
    show AppLogger, LogLevel, logger;

// Price calculation services
export 'prices/prices.dart';

// Sales calculation services
export 'sales/sales.dart';

// Tax calculation services
export 'taxes/taxes.dart';
