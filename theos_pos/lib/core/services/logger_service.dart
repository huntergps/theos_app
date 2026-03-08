/// Re-export logger from odoo_offline_core package
///
/// This file maintains backward compatibility with existing imports.
/// All logging functionality is now provided by the core package.
///
/// Usage remains the same:
/// ```dart
/// import 'package:theos_pos/core/services/logger_service.dart';
/// logger.i('[MyScreen]', 'Screen initialized');
/// ```
library;

export 'package:odoo_sdk/odoo_sdk.dart'
    show AppLogger, LogLevel, logger;
