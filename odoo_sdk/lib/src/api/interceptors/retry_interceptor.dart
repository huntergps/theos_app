/// Retry Interceptor for Dio
///
/// Automatically retries failed HTTP requests with exponential backoff.
/// Handles transient network errors and server unavailability.
library;

import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';

/// Retry metadata and classification for Odoo JSON-2 requests.
///
/// JSON-2 uses HTTP POST for both reads and mutations, so the HTTP verb alone
/// cannot establish whether replaying a request is safe. Only the explicitly
/// listed, side-effect-free Odoo methods are eligible for automatic retry.
/// Unknown methods are deliberately treated as mutations.
abstract final class OdooRetryPolicy {
  /// Request extra set by the transport after classifying the Odoo method.
  static const retrySafeExtraKey = 'odooRetrySafe';

  /// Non-sensitive diagnostic metadata used by metrics/tests.
  static const methodExtraKey = 'odooMethod';

  static const Set<String> _safeReadMethods = {
    'search',
    'read',
    'search_read',
    'search_count',
    'fields_get',
    // Standard read-only identity/display helpers.
    'context_get',
    'name_get',
    'name_search',
  };

  /// Whether an Odoo model method is safe to replay automatically.
  static bool isSafeReadMethod(String method) =>
      _safeReadMethods.contains(method.trim().toLowerCase());

  /// Extract the model method from a JSON-2 path (`/<model>/<method>`).
  static String? methodFromJson2Path(String path) {
    final uri = Uri.tryParse(path);
    final segments = uri?.pathSegments
        .where((segment) => segment.isNotEmpty)
        .toList(growable: false);
    if (segments == null || segments.length < 2) return null;
    return segments.last;
  }

  /// Metadata attached to a JSON-2 request without credentials or payloads.
  static Map<String, Object> metadataForJson2Path(String path) {
    final method = methodFromJson2Path(path);
    return {
      retrySafeExtraKey: method != null && isSafeReadMethod(method),
      if (method != null) methodExtraKey: method,
    };
  }

  /// Whether a Dio request may be replayed.
  ///
  /// JSON-2 POSTs must carry an explicit safe classification. Ordinary GET,
  /// HEAD and OPTIONS requests remain retryable because their HTTP semantics
  /// are idempotent; every other unclassified request is fail-closed.
  static bool isRequestRetrySafe(RequestOptions options) {
    final classified = options.extra[retrySafeExtraKey];
    if (classified is bool) return classified;

    return switch (options.method.toUpperCase()) {
      'GET' || 'HEAD' || 'OPTIONS' => true,
      _ => false,
    };
  }
}

/// Configuration for retry behavior.
class RetryConfig {
  /// Maximum number of retry attempts.
  final int maxRetries;

  /// Initial delay before first retry.
  final Duration initialDelay;

  /// Maximum delay between retries (cap for exponential backoff).
  final Duration maxDelay;

  /// Multiplier for exponential backoff (e.g., 2.0 doubles delay each time).
  final double backoffMultiplier;

  /// HTTP status codes that should trigger a retry.
  /// Default: 408, 429, 500, 502, 503, 504
  final Set<int> retryableStatusCodes;

  /// Whether to add jitter to retry delays (randomize slightly).
  final bool useJitter;

  /// Callback when a retry is attempted.
  final void Function(int attempt, Duration delay, Object error)? onRetry;

  const RetryConfig({
    this.maxRetries = 3,
    this.initialDelay = const Duration(milliseconds: 500),
    this.maxDelay = const Duration(seconds: 30),
    this.backoffMultiplier = 2.0,
    this.retryableStatusCodes = const {408, 429, 500, 502, 503, 504},
    this.useJitter = true,
    this.onRetry,
  });

  /// Default configuration for production use.
  static const production = RetryConfig(
    maxRetries: 3,
    initialDelay: Duration(seconds: 1),
    maxDelay: Duration(seconds: 30),
  );

  /// Aggressive retry configuration for critical operations.
  static const aggressive = RetryConfig(
    maxRetries: 5,
    initialDelay: Duration(milliseconds: 500),
    maxDelay: Duration(seconds: 60),
  );

  /// Minimal retry configuration for quick failures.
  static const minimal = RetryConfig(
    maxRetries: 2,
    initialDelay: Duration(milliseconds: 200),
    maxDelay: Duration(seconds: 5),
  );

  /// Calculate delay for a specific retry attempt (1-indexed).
  Duration getDelayForAttempt(int attempt) {
    // Exponential backoff: initialDelay * (multiplier ^ (attempt - 1))
    final exponentialDelay =
        initialDelay.inMilliseconds *
        pow(backoffMultiplier, attempt - 1).toInt();

    // Cap at maxDelay
    var delayMs = min(exponentialDelay, maxDelay.inMilliseconds);

    // Add jitter (±25% randomization)
    if (useJitter) {
      final jitter = (delayMs * 0.25 * (Random().nextDouble() * 2 - 1)).toInt();
      delayMs = max(0, delayMs + jitter);
    }

    return Duration(milliseconds: delayMs);
  }
}

/// Dio interceptor that automatically retries failed requests.
///
/// Usage:
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(RetryInterceptor(
///   config: RetryConfig.production,
/// ));
/// ```
class RetryInterceptor extends Interceptor {
  final Dio _dio;
  final RetryConfig config;

  /// Create a retry interceptor.
  ///
  /// The [dio] parameter should be the Dio instance this interceptor is added to.
  /// This is needed to retry requests.
  RetryInterceptor({required Dio dio, this.config = const RetryConfig()})
    : _dio = dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Check if we should retry this request
    if (!_shouldRetry(err)) {
      return handler.next(err);
    }

    // Get current retry count from request options
    final options = err.requestOptions;
    final retryCount = options.extra['retryCount'] as int? ?? 0;

    // Check if we've exceeded max retries
    if (retryCount >= config.maxRetries) {
      return handler.next(err);
    }

    // Calculate delay
    final delay = config.getDelayForAttempt(retryCount + 1);

    // Notify callback
    config.onRetry?.call(retryCount + 1, delay, err);

    // Wait before retrying
    await Future.delayed(delay);

    // Retry the request
    try {
      options.extra['retryCount'] = retryCount + 1;

      final response = await _dio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      // Let the error propagate to potentially retry again
      return handler.next(e);
    }
  }

  /// Determine if a request should be retried based on the error.
  bool _shouldRetry(DioException err) {
    // JSON-2 sends every operation as POST. Never replay a request unless the
    // transport classified it as a side-effect-free read.
    if (!OdooRetryPolicy.isRequestRetrySafe(err.requestOptions)) {
      return false;
    }

    // Don't retry if request was cancelled
    if (err.type == DioExceptionType.cancel) {
      return false;
    }

    // Retry on connection errors
    if (_isConnectionError(err)) {
      return true;
    }

    // Retry on timeout errors
    if (_isTimeoutError(err)) {
      return true;
    }

    // Retry on specific HTTP status codes
    if (err.response != null &&
        config.retryableStatusCodes.contains(err.response!.statusCode)) {
      return true;
    }

    return false;
  }

  /// Check if the error is a connection error.
  bool _isConnectionError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.unknown:
        // Check error message for connection-related keywords
        final message = err.message?.toLowerCase() ?? '';
        return message.contains('connection') ||
            message.contains('socket') ||
            message.contains('network');
      default:
        return false;
    }
  }

  /// Check if the error is a timeout error.
  bool _isTimeoutError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return true;
      default:
        return false;
    }
  }
}

/// Extension to easily add retry capability to Dio.
extension DioRetryExtension on Dio {
  /// Add retry interceptor with default configuration.
  void enableRetry([RetryConfig config = const RetryConfig()]) {
    interceptors.add(RetryInterceptor(dio: this, config: config));
  }

  /// Add retry interceptor with custom callback for logging/monitoring.
  void enableRetryWithCallback(
    void Function(int attempt, Duration delay, Object error) onRetry, {
    RetryConfig? config,
  }) {
    final effectiveConfig = config ?? const RetryConfig();
    interceptors.add(
      RetryInterceptor(
        dio: this,
        config: RetryConfig(
          maxRetries: effectiveConfig.maxRetries,
          initialDelay: effectiveConfig.initialDelay,
          maxDelay: effectiveConfig.maxDelay,
          backoffMultiplier: effectiveConfig.backoffMultiplier,
          retryableStatusCodes: effectiveConfig.retryableStatusCodes,
          useJitter: effectiveConfig.useJitter,
          onRetry: onRetry,
        ),
      ),
    );
  }
}
