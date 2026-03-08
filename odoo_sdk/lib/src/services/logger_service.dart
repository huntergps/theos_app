import '../utils/security_utils.dart';

/// Log levels for the application logger
enum LogLevel { debug, info, warning, error }

/// Function type for log output. Defaults to [print].
typedef LogOutput = void Function(Object?);

/// Pure Dart debug mode detection (replaces Flutter's _kDebugMode)
bool _isDebugMode() {
  bool debug = false;
  assert(() { debug = true; return true; }());
  return debug;
}

final bool _kDebugMode = _isDebugMode();

/// Centralized logging service for the application
///
/// Usage:
/// ```dart
/// logger.d('[SalesScreen]', 'Loading orders...');
/// logger.i('[SalesScreen]', 'Loaded 42 orders');
/// logger.w('[SalesScreen]', 'Some orders pending sync');
/// logger.e('[SalesScreen]', 'Failed to load', error, stackTrace);
/// ```
///
/// Features:
/// - Singleton pattern for global access
/// - Different log levels (debug, info, warning, error)
/// - Pretty formatting with emojis and timestamps
/// - Debug mode: logs to console
/// - Release mode: errors can be sent to analytics
class AppLogger {
  static final AppLogger _instance = AppLogger._internal();

  /// Factory constructor returns singleton instance
  factory AppLogger() => _instance;

  /// Private constructor for singleton
  AppLogger._internal();

  /// Static getter for singleton instance
  static AppLogger get instance => _instance;

  /// Minimum log level to output
  /// In debug mode: shows all logs (debug and above)
  /// In release mode: shows only info and above
  LogLevel minLevel = _kDebugMode ? LogLevel.debug : LogLevel.info;

  /// Configurable output handler for log messages.
  ///
  /// Defaults to [print]. Replace with a custom function to redirect
  /// log output (e.g., to a file, test buffer, or logging framework).
  ///
  /// Example:
  /// ```dart
  /// logger.logOutput = (message) => myCustomLogger.write(message);
  /// ```
  LogOutput logOutput = print;

  /// Optional callback for sending errors to analytics
  /// Set this to integrate with Firebase Crashlytics, Sentry, etc.
  void Function(String tag, String message, Object? error, StackTrace? stackTrace)?
      onErrorLogged;

  /// SEC-03: Whether automatic log sanitization is enabled.
  ///
  /// When true (default), all log messages are passed through
  /// [ErrorSanitizer.sanitize] to redact potential PII and credentials.
  /// Disable only for debugging in controlled environments.
  bool _sanitizeEnabled = true;

  /// Enable or disable automatic log sanitization.
  void setSanitization(bool enabled) {
    _sanitizeEnabled = enabled;
  }

  /// Whether log sanitization is currently enabled.
  bool get isSanitizationEnabled => _sanitizeEnabled;

  /// Log a debug message
  ///
  /// Use for detailed diagnostic information useful during development
  ///
  /// Accepts either:
  /// - Single argument: `logger.d('[Tag] message');`
  /// - Two arguments: `logger.d('[Tag]', 'message');`
  void d(String tagOrMessage, [String? message]) {
    if (message != null) {
      _log(LogLevel.debug, tagOrMessage, message);
    } else {
      _log(LogLevel.debug, '', tagOrMessage);
    }
  }

  /// Log an info message
  ///
  /// Use for general informational messages about application flow
  ///
  /// Accepts either:
  /// - Single argument: `logger.i('[Tag] message');`
  /// - Two arguments: `logger.i('[Tag]', 'message');`
  void i(String tagOrMessage, [String? message]) {
    if (message != null) {
      _log(LogLevel.info, tagOrMessage, message);
    } else {
      _log(LogLevel.info, '', tagOrMessage);
    }
  }

  /// Log a warning message
  ///
  /// Use for potentially harmful situations that aren't errors
  ///
  /// Accepts either:
  /// - Single argument: `logger.w('[Tag] message');`
  /// - Two arguments: `logger.w('[Tag]', 'message');`
  void w(String tagOrMessage, [String? message]) {
    if (message != null) {
      _log(LogLevel.warning, tagOrMessage, message);
    } else {
      _log(LogLevel.warning, '', tagOrMessage);
    }
  }

  /// Log an error message
  ///
  /// Use for error events that might still allow the app to continue
  ///
  /// Accepts either:
  /// - Single argument: `logger.e('[Tag] message');`
  /// - Two arguments: `logger.e('[Tag]', 'message');`
  /// - With error: `logger.e('[Tag]', 'message', error, stackTrace);`
  void e(
    String tagOrMessage, [
    String? message,
    Object? error,
    StackTrace? stackTrace,
  ]) {
    if (message != null) {
      _log(LogLevel.error, tagOrMessage, message, error, stackTrace);
    } else {
      _log(LogLevel.error, '', tagOrMessage, error, stackTrace);
    }
  }

  /// Internal log method that handles all logging
  void _log(
    LogLevel level,
    String tag,
    String message, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    // Skip if below minimum level
    if (level.index < minLevel.index) return;

    // SEC-03: Sanitize message and error to prevent credential leaks
    final safeMessage = _sanitizeEnabled ? ErrorSanitizer.sanitize(message) : message;
    final safeError = error != null && _sanitizeEnabled
        ? ErrorSanitizer.sanitize(error.toString())
        : error?.toString();

    final prefix = _getPrefix(level);
    final timestamp = DateTime.now().toIso8601String().substring(11, 23);

    // In debug mode, output to console with formatting
    if (_kDebugMode) {
      final tagPart = tag.isNotEmpty ? ' $tag' : '';
      logOutput('$timestamp $prefix$tagPart $safeMessage');
      if (safeError != null) {
        logOutput('  Error: $safeError');
      }
      if (stackTrace != null) {
        logOutput('  Stack: ${_sanitizeEnabled ? ErrorSanitizer.sanitizeStackTrace(stackTrace) : stackTrace}');
      }
    }

    // In release mode, send errors to analytics service
    if (level == LogLevel.error && !_kDebugMode) {
      onErrorLogged?.call(tag, safeMessage, error, stackTrace);
    }
  }

  /// Get formatted prefix for log level
  String _getPrefix(LogLevel level) {
    switch (level) {
      case LogLevel.debug:
        return '[DEBUG]';
      case LogLevel.info:
        return '[INFO]';
      case LogLevel.warning:
        return '[WARN]';
      case LogLevel.error:
        return '[ERROR]';
    }
  }

  /// Set minimum log level
  ///
  /// Example:
  /// ```dart
  /// logger.setMinLevel(LogLevel.warning); // Only show warnings and errors
  /// ```
  void setMinLevel(LogLevel level) {
    minLevel = level;
  }

  /// Check if a log level is enabled
  ///
  /// Example:
  /// ```dart
  /// if (logger.isLevelEnabled(LogLevel.debug)) {
  ///   // Do expensive debug calculation
  ///   logger.d('[Tag]', expensiveDebugInfo());
  /// }
  /// ```
  bool isLevelEnabled(LogLevel level) {
    return level.index >= minLevel.index;
  }
}

/// Global logger instance for convenient access throughout the app
///
/// Usage:
/// ```dart
/// import 'package:odoo_offline_core/odoo_offline_core.dart';
///
/// logger.i('[MyScreen]', 'Screen initialized');
/// ```
final logger = AppLogger.instance;
