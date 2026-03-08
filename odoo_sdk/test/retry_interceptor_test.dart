import 'package:test/test.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

void main() {
  group('RetryConfig', () {
    test('default values are sensible', () {
      const config = RetryConfig();
      expect(config.maxRetries, 3);
      expect(config.initialDelay, const Duration(milliseconds: 500));
      expect(config.maxDelay, const Duration(seconds: 30));
      expect(config.backoffMultiplier, 2.0);
      expect(config.useJitter, true);
      expect(config.retryableStatusCodes, contains(500));
      expect(config.retryableStatusCodes, contains(502));
      expect(config.retryableStatusCodes, contains(503));
    });

    test('production preset has correct values', () {
      const config = RetryConfig.production;
      expect(config.maxRetries, 3);
      expect(config.initialDelay, const Duration(seconds: 1));
    });

    test('aggressive preset has more retries', () {
      const config = RetryConfig.aggressive;
      expect(config.maxRetries, 5);
    });

    test('minimal preset has fewer retries', () {
      const config = RetryConfig.minimal;
      expect(config.maxRetries, 2);
    });

    group('getDelayForAttempt', () {
      test('first attempt uses initial delay', () {
        const config = RetryConfig(
          initialDelay: Duration(seconds: 1),
          useJitter: false,
        );
        expect(config.getDelayForAttempt(1), const Duration(seconds: 1));
      });

      test('second attempt doubles delay', () {
        const config = RetryConfig(
          initialDelay: Duration(seconds: 1),
          backoffMultiplier: 2.0,
          useJitter: false,
        );
        expect(config.getDelayForAttempt(2), const Duration(seconds: 2));
      });

      test('third attempt quadruples delay', () {
        const config = RetryConfig(
          initialDelay: Duration(seconds: 1),
          backoffMultiplier: 2.0,
          useJitter: false,
        );
        expect(config.getDelayForAttempt(3), const Duration(seconds: 4));
      });

      test('delay is capped at maxDelay', () {
        const config = RetryConfig(
          initialDelay: Duration(seconds: 10),
          maxDelay: Duration(seconds: 15),
          backoffMultiplier: 2.0,
          useJitter: false,
        );
        // 10 * 2 = 20, but capped at 15
        expect(config.getDelayForAttempt(2), const Duration(seconds: 15));
      });

      test('jitter adds randomization', () {
        const config = RetryConfig(
          initialDelay: Duration(seconds: 1),
          useJitter: true,
        );

        // Run multiple times to verify jitter adds variation
        final delays = <Duration>[];
        for (var i = 0; i < 10; i++) {
          delays.add(config.getDelayForAttempt(1));
        }

        // With jitter, delays should vary (not all the same)
        // Jitter is ±25%, so values should be in range 750-1250ms
        for (final delay in delays) {
          expect(delay.inMilliseconds, greaterThanOrEqualTo(750));
          expect(delay.inMilliseconds, lessThanOrEqualTo(1250));
        }
      });
    });

    test('retryableStatusCodes includes expected codes', () {
      const config = RetryConfig();
      expect(config.retryableStatusCodes, contains(408)); // Request Timeout
      expect(config.retryableStatusCodes, contains(429)); // Too Many Requests
      expect(config.retryableStatusCodes, contains(500)); // Internal Server Error
      expect(config.retryableStatusCodes, contains(502)); // Bad Gateway
      expect(config.retryableStatusCodes, contains(503)); // Service Unavailable
      expect(config.retryableStatusCodes, contains(504)); // Gateway Timeout
    });

    test('custom retryable status codes', () {
      const config = RetryConfig(
        retryableStatusCodes: {500, 502},
      );
      expect(config.retryableStatusCodes, hasLength(2));
      expect(config.retryableStatusCodes, contains(500));
      expect(config.retryableStatusCodes, contains(502));
      expect(config.retryableStatusCodes.contains(503), false);
    });

    test('onRetry callback can be set', () {
      var callbackCalled = false;
      final config = RetryConfig(
        onRetry: (attempt, delay, error) {
          callbackCalled = true;
        },
      );
      expect(config.onRetry, isNotNull);
      config.onRetry!(1, const Duration(seconds: 1), Exception('test'));
      expect(callbackCalled, true);
    });
  });

  group('OdooClientConfig retry options', () {
    test('enableRetry defaults to true', () {
      const config = OdooClientConfig(
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
      );
      expect(config.enableRetry, true);
    });

    test('enableRetry can be disabled', () {
      const config = OdooClientConfig(
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        enableRetry: false,
      );
      expect(config.enableRetry, false);
    });

    test('custom retryConfig can be set', () {
      const config = OdooClientConfig(
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        retryConfig: RetryConfig.aggressive,
      );
      expect(config.retryConfig.maxRetries, 5);
    });

    test('copyWith preserves retry settings', () {
      const original = OdooClientConfig(
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        enableRetry: true,
        retryConfig: RetryConfig.aggressive,
      );

      final copied = original.copyWith(database: 'test-db');
      expect(copied.enableRetry, true);
      expect(copied.retryConfig.maxRetries, 5);
    });

    test('copyWith can update retry settings', () {
      const original = OdooClientConfig(
        baseUrl: 'https://example.com',
        apiKey: 'test-key',
        enableRetry: true,
      );

      final copied = original.copyWith(
        enableRetry: false,
        retryConfig: RetryConfig.minimal,
      );
      expect(copied.enableRetry, false);
      expect(copied.retryConfig.maxRetries, 2);
    });
  });
}
