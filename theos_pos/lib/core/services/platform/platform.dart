/// Platform Services - Device and connectivity infrastructure
///
/// Provides platform-specific services for device info, server connectivity,
/// multi-database support, and notifications.
library;

export 'device_service.dart';
export 'server_connectivity_service.dart';
export 'server_database_service.dart';
export 'global_notification_service.dart';
// Note: browser_session_helper_*.dart files are platform-specific
// and should be imported via conditional imports
