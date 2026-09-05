import 'package:flutter/foundation.dart';

import 'package:odoo_sdk/odoo_sdk.dart' show logger;

typedef UnhandledErrorReporter = void Function(
  String source,
  Object error,
  StackTrace stackTrace,
);

/// Installs the process-wide Flutter and platform error boundaries.
///
/// Zone errors are handled by `main` because the application must be started
/// inside the same zone that owns Flutter's bindings.
void installGlobalErrorHandlers({UnhandledErrorReporter? reporter}) {
  final report = reporter ?? reportUnhandledError;

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    report(
      'Flutter framework',
      details.exception,
      details.stack ?? StackTrace.current,
    );
  };

  PlatformDispatcher.instance.onError = (error, stackTrace) {
    report('Platform dispatcher', error, stackTrace);
    return true;
  };
}

/// Reports an uncaught error through the centralized, redacting logger.
void reportUnhandledError(String source, Object error, StackTrace stackTrace) {
  logger.e('[Unhandled]', source, error, stackTrace);
}
