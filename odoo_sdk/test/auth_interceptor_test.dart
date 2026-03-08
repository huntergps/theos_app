import 'dart:async';

import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

/// Mock implementation of TokenRefreshHandler for testing.
class MockTokenRefreshHandler implements TokenRefreshHandler {
  final Completer<TokenRefreshResult> _refreshCompleter;
  int refreshCallCount = 0;
  String? lastRefreshedToken;
  Object? lastFailedError;

  MockTokenRefreshHandler({TokenRefreshResult? result})
      : _refreshCompleter = Completer() {
    if (result != null) {
      _refreshCompleter.complete(result);
    }
  }

  /// Set the result that will be returned by refreshToken().
  void setResult(TokenRefreshResult result) {
    if (!_refreshCompleter.isCompleted) {
      _refreshCompleter.complete(result);
    }
  }

  @override
  Future<TokenRefreshResult> refreshToken() async {
    refreshCallCount++;
    return _refreshCompleter.future;
  }

  @override
  void onTokenRefreshed(String newToken) {
    lastRefreshedToken = newToken;
  }

  @override
  void onRefreshFailed(Object error) {
    lastFailedError = error;
  }
}

/// Mock that tracks refresh with delayed completion.
class DelayedMockTokenRefreshHandler implements TokenRefreshHandler {
  final Duration delay;
  final TokenRefreshResult result;
  int refreshCallCount = 0;

  DelayedMockTokenRefreshHandler({
    required this.delay,
    required this.result,
  });

  @override
  Future<TokenRefreshResult> refreshToken() async {
    refreshCallCount++;
    await Future.delayed(delay);
    return result;
  }

  @override
  void onTokenRefreshed(String newToken) {}

  @override
  void onRefreshFailed(Object error) {}
}

void main() {
  group('TokenRefreshResult', () {
    test('success() creates successful result with token', () {
      final result = TokenRefreshResult.success('new-token-123');

      expect(result.success, isTrue);
      expect(result.newToken, equals('new-token-123'));
      expect(result.error, isNull);
    });

    test('failed() creates failed result with error', () {
      final error = Exception('Token expired');
      final result = TokenRefreshResult.failed(error);

      expect(result.success, isFalse);
      expect(result.newToken, isNull);
      expect(result.error, equals(error));
    });

    test('toString() masks token in success result', () {
      final result = TokenRefreshResult.success('new-token-123');
      expect(result.toString(), contains('****'));
      expect(result.toString(), isNot(contains('new-token-123')));
    });

    test('toString() shows error in failed result', () {
      final result = TokenRefreshResult.failed('Auth failed');
      expect(result.toString(), contains('failed'));
      expect(result.toString(), contains('Auth failed'));
    });
  });

  group('AuthInterceptorConfig', () {
    test('has default values', () {
      final handler = MockTokenRefreshHandler(
        result: TokenRefreshResult.success('token'),
      );
      final config = AuthInterceptorConfig(refreshHandler: handler);

      expect(config.refreshTriggerCodes, equals({401}));
      expect(config.maxRefreshAttempts, equals(1));
      expect(config.queueDuringRefresh, isTrue);
      expect(config.onRetry, isNull);
    });

    test('accepts custom values', () {
      final handler = MockTokenRefreshHandler(
        result: TokenRefreshResult.success('token'),
      );
      String? retryToken;

      final config = AuthInterceptorConfig(
        refreshHandler: handler,
        refreshTriggerCodes: {401, 403},
        maxRefreshAttempts: 3,
        queueDuringRefresh: false,
        onRetry: (options, token) => retryToken = token,
      );

      expect(config.refreshTriggerCodes, equals({401, 403}));
      expect(config.maxRefreshAttempts, equals(3));
      expect(config.queueDuringRefresh, isFalse);

      // Test callback
      config.onRetry!(RequestOptions(path: '/test'), 'test-token');
      expect(retryToken, equals('test-token'));
    });
  });

  group('AuthInterceptor', () {
    late Dio dio;
    late MockTokenRefreshHandler mockHandler;

    setUp(() {
      dio = Dio();
    });

    test('passes non-401 errors through', () async {
      mockHandler = MockTokenRefreshHandler(
        result: TokenRefreshResult.success('new-token'),
      );

      dio.interceptors.add(AuthInterceptor(
        dio: dio,
        config: AuthInterceptorConfig(refreshHandler: mockHandler),
      ));

      // Simulate a 500 error
      dio.httpClientAdapter = _MockAdapter(statusCode: 500);

      expect(
        () => dio.get('/test'),
        throwsA(predicate<DioException>((e) => e.response?.statusCode == 500)),
      );

      // Wait a bit to ensure async operations complete
      await Future.delayed(const Duration(milliseconds: 50));

      // Should not have called refresh
      expect(mockHandler.refreshCallCount, equals(0));
    });

    test('ignores cancelled requests', () async {
      mockHandler = MockTokenRefreshHandler(
        result: TokenRefreshResult.success('new-token'),
      );

      dio.interceptors.add(AuthInterceptor(
        dio: dio,
        config: AuthInterceptorConfig(refreshHandler: mockHandler),
      ));

      final cancelToken = CancelToken();
      cancelToken.cancel('User cancelled');

      dio.httpClientAdapter = _MockAdapter(statusCode: 401);

      try {
        await dio.get('/test', cancelToken: cancelToken);
      } catch (e) {
        // Expected
      }

      await Future.delayed(const Duration(milliseconds: 50));
      expect(mockHandler.refreshCallCount, equals(0));
    });

    test('calls onRefreshFailed when refresh fails', () async {
      final error = Exception('Refresh failed');
      mockHandler = MockTokenRefreshHandler(
        result: TokenRefreshResult.failed(error),
      );

      dio.interceptors.add(AuthInterceptor(
        dio: dio,
        config: AuthInterceptorConfig(refreshHandler: mockHandler),
      ));

      dio.httpClientAdapter = _MockAdapter(statusCode: 401);

      try {
        await dio.get('/test');
      } catch (e) {
        // Expected
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(mockHandler.refreshCallCount, equals(1));
      expect(mockHandler.lastFailedError, isNotNull);
    });

    test('config maxRefreshAttempts is configurable', () {
      mockHandler = MockTokenRefreshHandler(
        result: TokenRefreshResult.success('new-token'),
      );

      final config1 = AuthInterceptorConfig(
        refreshHandler: mockHandler,
        maxRefreshAttempts: 1,
      );
      expect(config1.maxRefreshAttempts, equals(1));

      final config5 = AuthInterceptorConfig(
        refreshHandler: mockHandler,
        maxRefreshAttempts: 5,
      );
      expect(config5.maxRefreshAttempts, equals(5));
    });

    test('config allows setting queueDuringRefresh', () {
      mockHandler = MockTokenRefreshHandler(
        result: TokenRefreshResult.success('new-token'),
      );

      final config = AuthInterceptorConfig(
        refreshHandler: mockHandler,
        queueDuringRefresh: true,
      );

      expect(config.queueDuringRefresh, isTrue);

      final config2 = AuthInterceptorConfig(
        refreshHandler: mockHandler,
        queueDuringRefresh: false,
      );

      expect(config2.queueDuringRefresh, isFalse);
    });

    test('calls onTokenRefreshed on successful refresh', () async {
      mockHandler = MockTokenRefreshHandler(
        result: TokenRefreshResult.success('brand-new-token'),
      );

      dio.interceptors.add(AuthInterceptor(
        dio: dio,
        config: AuthInterceptorConfig(refreshHandler: mockHandler),
      ));

      // First request fails with 401, retry succeeds
      var callCount = 0;
      dio.httpClientAdapter = _MockAdapter(
        statusCode: 401,
        onRequest: () {
          callCount++;
          if (callCount > 1) {
            return 200; // Success on retry
          }
          return null; // Use configured status code
        },
      );

      try {
        await dio.get('/test');
      } catch (e) {
        // May or may not succeed depending on mock setup
      }

      await Future.delayed(const Duration(milliseconds: 100));

      expect(mockHandler.lastRefreshedToken, equals('brand-new-token'));
    });
  });

  group('DioAuthExtension', () {
    test('enableTokenRefresh adds AuthInterceptor', () {
      final dio = Dio();
      final handler = MockTokenRefreshHandler(
        result: TokenRefreshResult.success('token'),
      );

      dio.enableTokenRefresh(handler);

      expect(
        dio.interceptors.whereType<AuthInterceptor>().length,
        equals(1),
      );
    });

    test('enableTokenRefresh accepts custom config', () {
      final dio = Dio();
      final handler = MockTokenRefreshHandler(
        result: TokenRefreshResult.success('token'),
      );
      var retryCalled = false;

      dio.enableTokenRefresh(
        handler,
        triggerCodes: {401, 403},
        maxAttempts: 5,
        queueDuringRefresh: false,
        onRetry: (_, __) => retryCalled = true,
      );

      final interceptor = dio.interceptors.whereType<AuthInterceptor>().first;
      expect(interceptor.config.refreshTriggerCodes, equals({401, 403}));
      expect(interceptor.config.maxRefreshAttempts, equals(5));
      expect(interceptor.config.queueDuringRefresh, isFalse);

      // Verify callback is set
      interceptor.config.onRetry!(RequestOptions(path: '/'), 'token');
      expect(retryCalled, isTrue);
    });
  });

  group('OdooClientConfig with token refresh', () {
    test('supports tokenRefreshHandler', () {
      final handler = MockTokenRefreshHandler(
        result: TokenRefreshResult.success('token'),
      );

      final config = OdooClientConfig(
        baseUrl: 'https://odoo.example.com',
        apiKey: 'test-key',
        tokenRefreshHandler: handler,
      );

      expect(config.tokenRefreshHandler, equals(handler));
    });

    test('copyWith preserves tokenRefreshHandler', () {
      final handler = MockTokenRefreshHandler(
        result: TokenRefreshResult.success('token'),
      );

      final config = OdooClientConfig(
        baseUrl: 'https://odoo.example.com',
        apiKey: 'test-key',
        tokenRefreshHandler: handler,
      );

      final copied = config.copyWith(apiKey: 'new-key');

      expect(copied.tokenRefreshHandler, equals(handler));
      expect(copied.apiKey, equals('new-key'));
    });

    test('supports onApiKeyRefreshed callback', () {
      String? refreshedKey;

      final config = OdooClientConfig(
        baseUrl: 'https://odoo.example.com',
        apiKey: 'test-key',
        onApiKeyRefreshed: (key) => refreshedKey = key,
      );

      config.onApiKeyRefreshed?.call('new-api-key');
      expect(refreshedKey, equals('new-api-key'));
    });
  });
}

/// Mock HTTP adapter for testing.
class _MockAdapter implements HttpClientAdapter {
  final int statusCode;
  final int? Function()? onRequest;

  _MockAdapter({
    required this.statusCode,
    this.onRequest,
  });

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final effectiveStatus = onRequest?.call() ?? statusCode;

    if (effectiveStatus >= 400) {
      throw DioException(
        requestOptions: options,
        response: Response(
          requestOptions: options,
          statusCode: effectiveStatus,
        ),
        type: DioExceptionType.badResponse,
      );
    }

    return ResponseBody.fromString(
      '{"success": true}',
      effectiveStatus,
      headers: {
        Headers.contentTypeHeader: ['application/json'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
