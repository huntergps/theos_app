import 'package:dio/dio.dart';
import 'package:test/test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';

import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('RetryInterceptor', () {
    test('config calculates delay correctly', () {
      const config = RetryConfig(
        maxRetries: 3,
        initialDelay: Duration(milliseconds: 100),
        backoffMultiplier: 2.0,
        useJitter: false,
      );

      // First attempt: 100ms
      expect(config.getDelayForAttempt(1).inMilliseconds, equals(100));
      // Second attempt: 200ms (100 * 2)
      expect(config.getDelayForAttempt(2).inMilliseconds, equals(200));
      // Third attempt: 400ms (100 * 4)
      expect(config.getDelayForAttempt(3).inMilliseconds, equals(400));
    });

    test('config respects max delay', () {
      const config = RetryConfig(
        initialDelay: Duration(seconds: 10),
        maxDelay: Duration(seconds: 15),
        backoffMultiplier: 2.0,
        useJitter: false,
      );

      // First attempt: 10s
      expect(config.getDelayForAttempt(1).inSeconds, equals(10));
      // Second attempt: should be 20s but capped at 15s
      expect(config.getDelayForAttempt(2).inSeconds, equals(15));
    });

    test('default presets are configured correctly', () {
      expect(RetryConfig.production.maxRetries, equals(3));
      expect(RetryConfig.aggressive.maxRetries, equals(5));
      expect(RetryConfig.minimal.maxRetries, equals(2));
    });

    test('does not retry on 400 error', () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      final dioAdapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      var attempts = 0;

      dioAdapter.onGet(
        '/bad-request',
        (server) {
          attempts++;
          server.throws(
            400,
            DioException(
              requestOptions: RequestOptions(path: '/bad-request'),
              response: Response(
                requestOptions: RequestOptions(path: '/bad-request'),
                statusCode: 400,
                data: {'error': 'Bad Request'},
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        },
      );

      dio.interceptors.add(RetryInterceptor(
        dio: dio,
        config: const RetryConfig(maxRetries: 3),
      ));

      try {
        await dio.get('/bad-request');
        fail('Should have thrown');
      } catch (e) {
        expect(e, isA<DioException>());
      }

      expect(attempts, equals(1));
    });
  });

  group('MetricsInterceptor', () {
    late Dio dio;
    late DioAdapter dioAdapter;
    late MetricsCollector collector;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dioAdapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      collector = MetricsCollector();
      dio.interceptors.add(MetricsInterceptor(collector: collector));
    });

    test('records successful request metrics', () async {
      dioAdapter.onPost(
        '/res.partner/search_read',
        (server) => server.reply(200, [
          {'id': 1, 'name': 'Test'},
        ]),
      );

      await dio.post('/res.partner/search_read', data: {});

      final metrics = collector.metrics;
      expect(metrics.length, equals(1));
      expect(metrics.first.success, isTrue);
      expect(metrics.first.odooModel, equals('res.partner'));
      expect(metrics.first.odooMethod, equals('search_read'));
    });

    test('records failed request metrics', () async {
      dioAdapter.onPost(
        '/sale.order/create',
        (server) => server.throws(
          500,
          DioException(
            requestOptions: RequestOptions(path: '/sale.order/create'),
            response: Response(
              requestOptions: RequestOptions(path: '/sale.order/create'),
              statusCode: 500,
              data: {'error': 'Server Error'},
            ),
            type: DioExceptionType.badResponse,
          ),
        ),
      );

      try {
        await dio.post('/sale.order/create', data: {});
      } catch (_) {}

      final metrics = collector.metrics;
      expect(metrics.length, equals(1));
      expect(metrics.first.success, isFalse);
    });

    test('aggregates metrics correctly', () async {
      dioAdapter.onPost(
        '/res.partner/search_read',
        (server) => server.reply(200, []),
      );

      for (var i = 0; i < 5; i++) {
        await dio.post('/res.partner/search_read', data: {});
      }

      final stats = collector.aggregate(window: const Duration(minutes: 5));

      expect(stats.totalRequests, equals(5));
      expect(stats.successfulRequests, equals(5));
      expect(stats.successRate, equals(100.0));
    });
  });

  group('CacheInterceptor', () {
    late Dio dio;
    late DioAdapter dioAdapter;
    late ResponseCache cache;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dioAdapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      cache = ResponseCache();
      dio.interceptors.add(CacheInterceptor(
        cache: cache,
        config: const CacheConfig(
          useConditionalRequests: false, // Disable for testing
          rules: [
            CacheRule(
              pattern: '/**/search_read',
              ttl: Duration(minutes: 5),
            ),
          ],
        ),
      ));
    });

    test('caches response on first request', () async {
      dioAdapter.onPost(
        '/res.partner/search_read',
        (server) => server.reply(200, [
          {'id': 1, 'name': 'Cached Partner'},
        ]),
      );

      await dio.post('/res.partner/search_read', data: {'domain': []});

      expect(cache.stats.misses, equals(1));
      expect(cache.stats.entries, equals(1));
    });

    test('returns cached response on second request', () async {
      var serverHits = 0;

      dioAdapter.onPost(
        '/res.partner/search_read',
        (server) {
          serverHits++;
          server.reply(200, [
            {'id': 1, 'name': 'Partner'},
          ]);
        },
      );

      // First request
      await dio.post('/res.partner/search_read', data: {'domain': []});

      // Second request should hit cache
      final response =
          await dio.post('/res.partner/search_read', data: {'domain': []});

      expect(serverHits, equals(1)); // Only one server hit
      expect(cache.stats.hits, equals(1));
      expect(response.extra['fromCache'], isTrue);
    });

    test('invalidates cache correctly', () async {
      dioAdapter.onPost(
        '/res.partner/search_read',
        (server) => server.reply(200, []),
      );

      await dio.post('/res.partner/search_read', data: {'domain': []});
      expect(cache.stats.entries, equals(1));

      cache.invalidatePattern(r'/res\.partner/');
      expect(cache.stats.entries, equals(0));
    });
  });

  group('RateLimitInterceptor', () {
    late Dio dio;
    late DioAdapter dioAdapter;
    late RateLimitInterceptor rateLimiter;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'https://api.example.com'));
      dioAdapter = DioAdapter(dio: dio, matcher: const UrlRequestMatcher());
      rateLimiter = RateLimitInterceptor(
        config: const RateLimitConfig(
          rules: [
            RateLimitRule(
              pattern: '/**',
              maxRequests: 2,
              window: Duration(seconds: 1),
              burstCapacity: 2,
              maxWaitTime: Duration(milliseconds: 100),
            ),
          ],
        ),
      );
      dio.interceptors.add(rateLimiter);
    });

    test('allows requests within rate limit', () async {
      dioAdapter.onGet('/test', (server) => server.reply(200, 'OK'));

      // First two requests should succeed immediately
      await dio.get('/test');
      await dio.get('/test');

      expect(rateLimiter.stats.totalRequests, equals(2));
      expect(rateLimiter.stats.delayedRequests, equals(0));
    });

    test('rejects requests exceeding rate limit', () async {
      dioAdapter.onGet('/test', (server) => server.reply(200, 'OK'));

      // Make requests exceeding rate limit
      await dio.get('/test');
      await dio.get('/test');

      // Third request should be rejected (exceeded burst + maxWaitTime)
      try {
        await dio.get('/test');
        fail('Should have thrown RateLimitException');
      } catch (e) {
        expect(e, isA<RateLimitException>());
      }

      expect(rateLimiter.stats.rejectedRequests, greaterThan(0));
    });

    test('tracks statistics correctly', () async {
      dioAdapter.onGet('/test', (server) => server.reply(200, 'OK'));

      await dio.get('/test');

      final stats = rateLimiter.stats;
      expect(stats.totalRequests, equals(1));
    });
  });
}
