/// Rate Limiting Interceptor for Dio
///
/// Provides client-side rate limiting with:
/// - Per-route or global rate limits
/// - Token bucket algorithm
/// - Configurable burst capacity
/// - Queue with timeout for exceeded limits
library;

import 'dart:async';

import 'package:dio/dio.dart';

/// Configuration for a rate limit rule.
class RateLimitRule {
  /// Pattern to match against request path (supports wildcards: * and **).
  ///
  /// Examples:
  /// - `/res.partner/*` - matches any method on res.partner
  /// - `/**/search_read` - matches search_read on any model
  /// - `/**` - matches all requests (global limit)
  final String pattern;

  /// Maximum requests allowed per time window.
  final int maxRequests;

  /// Time window for the rate limit.
  final Duration window;

  /// Maximum burst capacity (requests that can be made immediately).
  /// Defaults to maxRequests.
  final int? burstCapacity;

  /// Maximum time to wait in queue if rate limited.
  /// If exceeded, the request fails with a RateLimitException.
  final Duration maxWaitTime;

  const RateLimitRule({
    required this.pattern,
    required this.maxRequests,
    this.window = const Duration(seconds: 1),
    this.burstCapacity,
    this.maxWaitTime = const Duration(seconds: 30),
  });

  /// Effective burst capacity.
  int get effectiveBurstCapacity => burstCapacity ?? maxRequests;

  /// Check if this rule matches a request path.
  bool matches(String path) {
    final regex = _patternToRegex(pattern);
    return regex.hasMatch(path);
  }

  RegExp _patternToRegex(String pattern) {
    var regexPattern = pattern
        .replaceAll('.', r'\.')
        .replaceAll('**', '{{DOUBLE_STAR}}')
        .replaceAll('*', r'[^/]+')
        .replaceAll('{{DOUBLE_STAR}}', r'.*');
    return RegExp('^$regexPattern\$');
  }

  @override
  String toString() =>
      'RateLimitRule($pattern, $maxRequests/${window.inSeconds}s)';
}

/// Token bucket for rate limiting.
class _TokenBucket {
  final int capacity;
  final Duration refillInterval;
  final int refillAmount;

  double _tokens;
  DateTime _lastRefill;

  _TokenBucket({
    required this.capacity,
    required this.refillInterval,
    required this.refillAmount,
  })  : _tokens = capacity.toDouble(),
        _lastRefill = DateTime.now();

  /// Try to consume a token. Returns true if successful.
  bool tryConsume() {
    _refill();
    if (_tokens >= 1) {
      _tokens -= 1;
      return true;
    }
    return false;
  }

  /// Time until at least one token is available.
  Duration get timeUntilAvailable {
    _refill();
    if (_tokens >= 1) return Duration.zero;

    final tokensNeeded = 1 - _tokens;
    final refillsNeeded = (tokensNeeded / refillAmount).ceil();
    return refillInterval * refillsNeeded;
  }

  /// Current available tokens.
  double get availableTokens {
    _refill();
    return _tokens;
  }

  /// Refills tokens based on elapsed time since last refill.
  ///
  /// Uses a token bucket algorithm where tokens are added at a fixed rate
  /// up to the maximum capacity.
  void _refill() {
    final now = DateTime.now();
    final elapsed = now.difference(_lastRefill);

    if (elapsed >= refillInterval) {
      final refills = elapsed.inMicroseconds / refillInterval.inMicroseconds;
      _tokens = (_tokens + refills * refillAmount).clamp(0, capacity).toDouble();
      _lastRefill = now;
    }
  }
}

/// Exception thrown when rate limit is exceeded and max wait time is reached.
class RateLimitException extends DioException {
  /// The rule that was exceeded.
  final RateLimitRule rule;

  /// Time until the rate limit resets.
  final Duration retryAfter;

  RateLimitException({
    required super.requestOptions,
    required this.rule,
    required this.retryAfter,
  }) : super(
          type: DioExceptionType.unknown,
          message: 'Rate limit exceeded for ${rule.pattern}. '
              'Retry after ${retryAfter.inMilliseconds}ms',
        );
}

/// Statistics about rate limiting.
class RateLimitStats {
  /// Total requests processed.
  final int totalRequests;

  /// Requests that were delayed due to rate limiting.
  final int delayedRequests;

  /// Requests that failed due to exceeding max wait time.
  final int rejectedRequests;

  /// Total delay time added to requests.
  final Duration totalDelayTime;

  const RateLimitStats({
    required this.totalRequests,
    required this.delayedRequests,
    required this.rejectedRequests,
    required this.totalDelayTime,
  });

  /// Percentage of requests that were delayed.
  double get delayedPercentage =>
      totalRequests > 0 ? (delayedRequests / totalRequests) * 100 : 0;

  /// Percentage of requests that were rejected.
  double get rejectedPercentage =>
      totalRequests > 0 ? (rejectedRequests / totalRequests) * 100 : 0;

  @override
  String toString() =>
      'RateLimitStats(total: $totalRequests, delayed: $delayedRequests '
      '(${delayedPercentage.toStringAsFixed(1)}%), rejected: $rejectedRequests)';
}

/// Configuration for the rate limit interceptor.
class RateLimitConfig {
  /// Rate limit rules ordered by specificity (most specific first).
  final List<RateLimitRule> rules;

  /// Callback when a request is delayed due to rate limiting.
  final void Function(RequestOptions options, Duration delay)? onDelayed;

  /// Callback when a request is rejected due to rate limiting.
  final void Function(RequestOptions options, RateLimitRule rule)? onRejected;

  const RateLimitConfig({
    this.rules = const [],
    this.onDelayed,
    this.onRejected,
  });

  /// Preset for conservative API usage (1 req/sec global).
  static const RateLimitConfig conservative = RateLimitConfig(
    rules: [
      RateLimitRule(
        pattern: '/**',
        maxRequests: 1,
        window: Duration(seconds: 1),
        burstCapacity: 3,
      ),
    ],
  );

  /// Preset for moderate API usage (5 req/sec global).
  static const RateLimitConfig moderate = RateLimitConfig(
    rules: [
      RateLimitRule(
        pattern: '/**',
        maxRequests: 5,
        window: Duration(seconds: 1),
        burstCapacity: 10,
      ),
    ],
  );

  /// Preset for Odoo-optimized rate limiting.
  static const RateLimitConfig odooDefault = RateLimitConfig(
    rules: [
      // Writes are slower, limit more strictly
      RateLimitRule(
        pattern: '/**/write',
        maxRequests: 3,
        window: Duration(seconds: 1),
        burstCapacity: 5,
      ),
      RateLimitRule(
        pattern: '/**/create',
        maxRequests: 3,
        window: Duration(seconds: 1),
        burstCapacity: 5,
      ),
      RateLimitRule(
        pattern: '/**/unlink',
        maxRequests: 2,
        window: Duration(seconds: 1),
        burstCapacity: 3,
      ),
      // Reads can be faster
      RateLimitRule(
        pattern: '/**/search_read',
        maxRequests: 10,
        window: Duration(seconds: 1),
        burstCapacity: 20,
      ),
      RateLimitRule(
        pattern: '/**/read',
        maxRequests: 10,
        window: Duration(seconds: 1),
        burstCapacity: 20,
      ),
      // Global fallback
      RateLimitRule(
        pattern: '/**',
        maxRequests: 10,
        window: Duration(seconds: 1),
        burstCapacity: 15,
      ),
    ],
  );
}

/// Dio interceptor that enforces client-side rate limits.
///
/// Usage:
/// ```dart
/// final dio = Dio();
/// dio.interceptors.add(RateLimitInterceptor(
///   config: RateLimitConfig.odooDefault,
/// ));
///
/// // Or with custom rules
/// dio.interceptors.add(RateLimitInterceptor(
///   config: RateLimitConfig(
///     rules: [
///       RateLimitRule(
///         pattern: '/sale.order/*',
///         maxRequests: 5,
///         window: Duration(seconds: 1),
///       ),
///     ],
///   ),
/// ));
/// ```
class RateLimitInterceptor extends Interceptor {
  final RateLimitConfig config;
  final Map<String, _TokenBucket> _buckets = {};

  // Statistics
  int _totalRequests = 0;
  int _delayedRequests = 0;
  int _rejectedRequests = 0;
  Duration _totalDelayTime = Duration.zero;

  RateLimitInterceptor({
    this.config = const RateLimitConfig(),
  });

  /// Get current rate limit statistics.
  RateLimitStats get stats => RateLimitStats(
        totalRequests: _totalRequests,
        delayedRequests: _delayedRequests,
        rejectedRequests: _rejectedRequests,
        totalDelayTime: _totalDelayTime,
      );

  /// Reset statistics.
  void resetStats() {
    _totalRequests = 0;
    _delayedRequests = 0;
    _rejectedRequests = 0;
    _totalDelayTime = Duration.zero;
  }

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    _totalRequests++;

    // Skip if no rate limiting configured
    if (config.rules.isEmpty) {
      handler.next(options);
      return;
    }

    // Find matching rule
    final rule = _findMatchingRule(options.path);
    if (rule == null) {
      handler.next(options);
      return;
    }

    // Get or create token bucket for this rule
    final bucket = _getOrCreateBucket(rule);

    // Try to acquire a token
    if (bucket.tryConsume()) {
      handler.next(options);
      return;
    }

    // Need to wait - check if we should delay or reject
    final waitTime = bucket.timeUntilAvailable;

    if (waitTime > rule.maxWaitTime) {
      // Reject the request
      _rejectedRequests++;
      config.onRejected?.call(options, rule);

      handler.reject(RateLimitException(
        requestOptions: options,
        rule: rule,
        retryAfter: waitTime,
      ));
      return;
    }

    // Delay the request
    _delayedRequests++;
    _totalDelayTime += waitTime;
    config.onDelayed?.call(options, waitTime);

    await Future.delayed(waitTime);

    // Try again after waiting
    if (bucket.tryConsume()) {
      handler.next(options);
    } else {
      // Still can't acquire - reject
      _rejectedRequests++;
      handler.reject(RateLimitException(
        requestOptions: options,
        rule: rule,
        retryAfter: bucket.timeUntilAvailable,
      ));
    }
  }

  RateLimitRule? _findMatchingRule(String path) {
    for (final rule in config.rules) {
      if (rule.matches(path)) {
        return rule;
      }
    }
    return null;
  }

  _TokenBucket _getOrCreateBucket(RateLimitRule rule) {
    final key = rule.pattern;
    return _buckets.putIfAbsent(
      key,
      () => _TokenBucket(
        capacity: rule.effectiveBurstCapacity,
        refillInterval: rule.window ~/ rule.maxRequests,
        refillAmount: 1,
      ),
    );
  }
}

/// Extension to easily add rate limiting to Dio.
extension DioRateLimitExtension on Dio {
  /// Add rate limit interceptor with default configuration.
  void enableRateLimiting({RateLimitConfig config = RateLimitConfig.moderate}) {
    interceptors.add(RateLimitInterceptor(config: config));
  }
}
