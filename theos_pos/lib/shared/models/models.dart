/// Barrel file for shared models
///
/// Note: Many models have been moved to feature modules:
/// - Products: `import 'package:theos_pos/features/products/products.dart'`
/// - Clients: `import 'package:theos_pos/features/clients/clients.dart'`
/// - Users: `import 'package:theos_pos/features/users/users.dart'`
/// - Warehouses: `import 'package:theos_pos/features/warehouses/warehouses.dart'`
/// - Prices: `import 'package:theos_pos/features/prices/prices.dart'`
/// - Payment Terms: `import 'package:theos_pos/features/payment_terms/payment_terms.dart'`
library;

// Location data - from theos_pos_core
export 'package:theos_pos_core/theos_pos_core.dart'
    show ResCountry, ResCountryState, ResLang, ResourceCalendar;

// App configuration (stays in shared - cross-cutting)
export 'app_config_model.dart';
export 'config_profile.dart';

// Device/session info (local - not in core)
export 'res_device.model.dart';

// Company configuration (from theos_pos_core)
export 'package:theos_pos_core/theos_pos_core.dart' show Company;

// Notifications (cross-cutting concern)
export 'notification_counter.dart';
export 'im_status.dart';

// Partner snapshot for quick lookups
export 'partner_snapshot.dart';
