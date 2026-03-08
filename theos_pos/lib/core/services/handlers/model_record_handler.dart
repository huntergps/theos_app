/// Model Record Handler - App adapter
///
/// Re-export the generic interfaces from odoo_offline_core and
/// bind them to the AppDatabase type for convenience.
library;

import 'package:odoo_sdk/odoo_sdk.dart' as core;
import 'package:theos_pos_core/theos_pos_core.dart' show AppDatabase;

typedef ModelRecordHandler = core.ModelRecordHandler<AppDatabase>;
typedef ModelRecordHandlerRegistry = core.ModelRecordHandlerRegistry<AppDatabase>;
