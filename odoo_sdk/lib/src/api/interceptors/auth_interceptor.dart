/// Authentication Interceptor for Dio
///
/// Automatically handles token refresh on 401 responses.
/// When a request fails with 401 Unauthorized, it calls the
/// configured token refresh handler and retries the request.
///
/// SEC-02: Token refresh implementation.
library;

import 'dart:async';

import 'package:dio/dio.dart';

/// Handler for token refresh operations.
///
/// Implement this interface to provide custom token refresh logic.
/// The handler is called when a 401 response is received.
///
/// Example:
/// ```dart
/// class MyTokenRefresher implements TokenRefreshHandler {
///   @override
///   Future<TokenRefreshResult> refreshToken() async {
///     final newToken = await myAuthService.refreshToken();
///     return TokenRefreshResult.success(newToken);
///   }
///
///   @override
///   void onTokenRefreshed(String newToken) {
///     myAuthService.updateStoredToken(newToken);
///   }
///
///   @override
///   void onRefreshFailed(Object error) {
///     myAuthService.logout();
///   }
/// }
/// ```
abstract class TokenRefreshHandler {
  /// Attempt to refresh the authentication token.
  ///
  /// Called when a 401 response is received. Should return a new token
  /// if refresh succeeds, or an error result if it fails.
  ///
  /// This method should NOT throw exceptions - instead return
  /// [TokenRefreshResult.failed] with the error.
  Future<TokenRefreshResult> refreshToken();

  /// Called when a token has been successfully refreshed.
  ///
  /// Use this to update stored credentials or notify other parts
  /// of the application about the new token.
  void onTokenRefreshed(String newToken);

  /// Called when token refresh fails.
  ///
  /// Use this to trigger logout, show error messages, or clean up.
  void onRefreshFailed(Object error);
}

/// Result of a token refresh attempt.
class TokenRefreshResult {
  /// Whether the refresh was successful.
  final bool success;

  /// The new token (if successful).
  final String? newToken;

  /// Error that occurred (if failed).
  final Object? error;

  const TokenRefreshResult._({
    required this.success,
    this.newToken,
    this.error,
  });

  /// Create a successful result with the new token.
  factory TokenRefreshResult.success(String newToken) {
    return TokenRefreshResult._(success: true, newToken: newToken);
  }

  /// Create a failed result with the error.
  factory TokenRefreshResult.failed(Object error) {
    return TokenRefreshResult._(success: false, error: error);
  }

  @override
  String toString() => success
      ? 'TokenRefreshResult.success(token: ${newToken?.substring(0, 4)}****)'
      : 'TokenRefreshResult.failed($error)';
}

/// Configuration for authentication interceptor.
class AuthInterceptorConfig {
  /// Handler for refreshing tokens.
  final TokenRefreshHandler refreshHandler;

  /// HTTP status codes that trigger token refresh.
  /// Default: [401] (Unauthorized)
  final Set<int> refreshTriggerCodes;

  /// Maximum number of refresh attempts before giving up.
  /// Default: 1 (one refresh attempt per request)
  final int maxRefreshAttempts;

  /// Whether to queue requests during refresh.
  ///
  /// If true, multiple concurrent 401s will wait for a single refresh.
  /// If false, each 401 triggers its own refresh (may cause race conditions).
  /// Default: true
  final bool queueDuringRefresh;

  /// Callback when a request is retried after token refresh.
  final void Function(RequestOptions options, String newToken)? onRetry;

  const AuthInterceptorConfig({
    required this.refreshHandler,
    this.refreshTriggerCodes = const {401},
    this.maxRefreshAttempts = 1,
    this.queueDuringRefresh = true,
    this.onRetry,
  });
}

/// Dio interceptor that handles automatic token refresh on 401 responses.
///
/// This interceptor:
/// 1. Intercepts 401 (Unauthorized) responses
/// 2. Calls the configured [TokenRefreshHandler] to get a new token
/// 3. Retries the original request with the new token
/// 4. Queues concurrent requests to avoid multiple refresh calls
///
/// Usage:
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(AuthInterceptor(
///   dio: dio,
///   config: AuthInterceptorConfig(
///     refreshHandler: MyTokenRefresher(),
///   ),
/// ));
/// ```
class AuthInterceptor extends QueuedInterceptor {
  final Dio _dio;
  final AuthInterceptorConfig config;

  /// Whether a refresh is currently in progress.
  bool _isRefreshing = false;

  /// Completer for waiting on ongoing refresh.
  Completer<TokenRefreshResult>? _refreshCompleter;

  /// Create an authentication interceptor.
  ///
  /// The [dio] parameter should be the Dio instance this interceptor is added to.
  AuthInterceptor({
    required Dio dio,
    required this.config,
  }) : _dio = dio;

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    // Check if this is a refresh-triggering response
    if (!_shouldRefresh(err)) {
      return handler.next(err);
    }

    // Check if we've already tried refreshing for this request
    final options = err.requestOptions;
    final refreshAttempts = options.extra['authRefreshAttempts'] as int? ?? 0;

    if (refreshAttempts >= config.maxRefreshAttempts) {
      // Already tried refreshing, give up
      return handler.next(err);
    }

    // Attempt token refresh
    final result = await _refreshToken();

    if (!result.success || result.newToken == null) {
      // Refresh failed, propagate original error
      config.refreshHandler.onRefreshFailed(result.error ?? err);
      return handler.next(err);
    }

    // Refresh succeeded, retry request with new token
    try {
      options.extra['authRefreshAttempts'] = refreshAttempts + 1;

      // Update the Authorization header with new token
      options.headers['Authorization'] = 'bearer ${result.newToken}';

      // Notify callback
      config.onRetry?.call(options, result.newToken!);

      // Retry the request
      final response = await _dio.fetch(options);
      return handler.resolve(response);
    } on DioException catch (e) {
      return handler.next(e);
    }
  }

  /// Determine if a response should trigger token refresh.
  bool _shouldRefresh(DioException err) {
    // Don't refresh if request was cancelled
    if (err.type == DioExceptionType.cancel) {
      return false;
    }

    // Check if status code triggers refresh
    final statusCode = err.response?.statusCode;
    if (statusCode != null && config.refreshTriggerCodes.contains(statusCode)) {
      return true;
    }

    return false;
  }

  /// Perform token refresh, queuing concurrent requests if configured.
  Future<TokenRefreshResult> _refreshToken() async {
    if (config.queueDuringRefresh && _isRefreshing) {
      // Wait for ongoing refresh
      return _refreshCompleter!.future;
    }

    _isRefreshing = true;
    _refreshCompleter = Completer<TokenRefreshResult>();

    try {
      final result = await config.refreshHandler.refreshToken();

      if (result.success && result.newToken != null) {
        config.refreshHandler.onTokenRefreshed(result.newToken!);
      }

      _refreshCompleter!.complete(result);
      return result;
    } catch (e) {
      final result = TokenRefreshResult.failed(e);
      _refreshCompleter!.complete(result);
      return result;
    } finally {
      _isRefreshing = false;
      _refreshCompleter = null;
    }
  }
}

/// Extension for easily adding auth interceptor to Dio.
extension DioAuthExtension on Dio {
  /// Add authentication interceptor with a refresh handler.
  void enableTokenRefresh(TokenRefreshHandler handler, {
    Set<int> triggerCodes = const {401},
    int maxAttempts = 1,
    bool queueDuringRefresh = true,
    void Function(RequestOptions options, String newToken)? onRetry,
  }) {
    interceptors.add(AuthInterceptor(
      dio: this,
      config: AuthInterceptorConfig(
        refreshHandler: handler,
        refreshTriggerCodes: triggerCodes,
        maxRefreshAttempts: maxAttempts,
        queueDuringRefresh: queueDuringRefresh,
        onRetry: onRetry,
      ),
    ));
  }
}
