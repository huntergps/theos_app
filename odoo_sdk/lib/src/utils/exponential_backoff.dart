import 'dart:async';
import 'dart:math';

/// Exponential backoff configuration for retry operations
///
/// Implements exponential backoff with optional jitter to prevent
/// thundering herd problems when multiple clients reconnect.
///
/// Usage:
/// ```dart
/// final backoff = ExponentialBackoff(
///   initialDelay: Duration(seconds: 1),
///   maxDelay: Duration(minutes: 1),
///   maxAttempts: 10,
/// );
///
/// while (backoff.shouldRetry) {
///   try {
///     await connect();
///     backoff.reset();
///     break;
///   } catch (e) {
///     await backoff.wait();
///   }
/// }
/// ```
class ExponentialBackoff {
  /// Initial delay before first retry
  final Duration initialDelay;

  /// Maximum delay between retries
  final Duration maxDelay;

  /// Maximum number of attempts (0 = unlimited)
  final int maxAttempts;

  /// Backoff multiplier (default: 2.0 for doubling)
  final double multiplier;

  /// Whether to add random jitter to delay
  final bool useJitter;

  /// Jitter factor (0.0 to 1.0, default: 0.25 = +/-25% variance)
  final double jitterFactor;

  /// Current attempt number
  int _attempts = 0;

  /// Current delay
  Duration _currentDelay;

  /// Random generator for jitter
  final Random _random = Random();

  /// Callback when a retry is about to happen
  void Function(int attempt, Duration delay)? onRetry;

  /// Callback when max attempts reached
  void Function()? onMaxAttemptsReached;

  ExponentialBackoff({
    this.initialDelay = const Duration(seconds: 1),
    this.maxDelay = const Duration(minutes: 1),
    this.maxAttempts = 10,
    this.multiplier = 2.0,
    this.useJitter = true,
    this.jitterFactor = 0.25,
    this.onRetry,
    this.onMaxAttemptsReached,
  }) : _currentDelay = initialDelay;

  /// Current attempt number (0 = not started)
  int get attempts => _attempts;

  /// Whether we should retry (haven't exceeded max attempts)
  bool get shouldRetry => maxAttempts == 0 || _attempts < maxAttempts;

  /// Whether max attempts has been reached
  bool get maxAttemptsReached => maxAttempts > 0 && _attempts >= maxAttempts;

  /// Get the next delay without waiting
  Duration get nextDelay {
    if (_attempts == 0) return initialDelay;

    var delay = _currentDelay;

    // Apply jitter if enabled
    if (useJitter) {
      final jitterRange = delay.inMilliseconds * jitterFactor;
      final jitter = (_random.nextDouble() * 2 - 1) * jitterRange;
      delay = Duration(milliseconds: delay.inMilliseconds + jitter.round());
    }

    return delay;
  }

  /// Wait for the next backoff delay
  ///
  /// Returns false if max attempts reached, true otherwise.
  Future<bool> wait() async {
    if (!shouldRetry) {
      onMaxAttemptsReached?.call();
      return false;
    }

    final delay = nextDelay;
    _attempts++;

    onRetry?.call(_attempts, delay);

    await Future.delayed(delay);

    // Calculate next delay
    _currentDelay = Duration(
      milliseconds: min(
        (_currentDelay.inMilliseconds * multiplier).round(),
        maxDelay.inMilliseconds,
      ),
    );

    return true;
  }

  /// Reset the backoff state
  void reset() {
    _attempts = 0;
    _currentDelay = initialDelay;
  }

  /// Execute an operation with automatic retries
  ///
  /// Returns the result of the operation, or throws the last error
  /// if max attempts is reached.
  Future<T> execute<T>(Future<T> Function() operation) async {
    reset();
    Object? lastError;
    StackTrace? lastStackTrace;

    while (shouldRetry) {
      try {
        final result = await operation();
        reset();
        return result;
      } catch (e, st) {
        lastError = e;
        lastStackTrace = st;

        if (!await wait()) {
          break;
        }
      }
    }

    if (lastError != null) {
      Error.throwWithStackTrace(lastError, lastStackTrace ?? StackTrace.current);
    }
    throw StateError('Unexpected state in exponential backoff');
  }
}

/// Preset backoff configurations for common use cases
class BackoffPresets {
  /// Fast reconnect for WebSocket (1s -> 30s, 10 attempts)
  static ExponentialBackoff websocket({
    void Function(int attempt, Duration delay)? onRetry,
    void Function()? onMaxAttemptsReached,
  }) =>
      ExponentialBackoff(
        initialDelay: const Duration(seconds: 1),
        maxDelay: const Duration(seconds: 30),
        maxAttempts: 10,
        onRetry: onRetry,
        onMaxAttemptsReached: onMaxAttemptsReached,
      );

  /// Network requests (500ms -> 10s, 5 attempts)
  static ExponentialBackoff networkRequest({
    void Function(int attempt, Duration delay)? onRetry,
    void Function()? onMaxAttemptsReached,
  }) =>
      ExponentialBackoff(
        initialDelay: const Duration(milliseconds: 500),
        maxDelay: const Duration(seconds: 10),
        maxAttempts: 5,
        onRetry: onRetry,
        onMaxAttemptsReached: onMaxAttemptsReached,
      );

  /// Sync operations (2s -> 60s, 10 attempts)
  static ExponentialBackoff sync({
    void Function(int attempt, Duration delay)? onRetry,
    void Function()? onMaxAttemptsReached,
  }) =>
      ExponentialBackoff(
        initialDelay: const Duration(seconds: 2),
        maxDelay: const Duration(seconds: 60),
        maxAttempts: 10,
        onRetry: onRetry,
        onMaxAttemptsReached: onMaxAttemptsReached,
      );

  /// Aggressive retry (100ms -> 5s, 15 attempts)
  static ExponentialBackoff aggressive({
    void Function(int attempt, Duration delay)? onRetry,
    void Function()? onMaxAttemptsReached,
  }) =>
      ExponentialBackoff(
        initialDelay: const Duration(milliseconds: 100),
        maxDelay: const Duration(seconds: 5),
        maxAttempts: 15,
        multiplier: 1.5,
        onRetry: onRetry,
        onMaxAttemptsReached: onMaxAttemptsReached,
      );

  /// Conservative retry (5s -> 5m, 5 attempts)
  static ExponentialBackoff conservative({
    void Function(int attempt, Duration delay)? onRetry,
    void Function()? onMaxAttemptsReached,
  }) =>
      ExponentialBackoff(
        initialDelay: const Duration(seconds: 5),
        maxDelay: const Duration(minutes: 5),
        maxAttempts: 5,
        onRetry: onRetry,
        onMaxAttemptsReached: onMaxAttemptsReached,
      );
}

/// Mixin for adding auto-reconnect capability to services
mixin AutoReconnectMixin {
  ExponentialBackoff? _backoff;
  Timer? _reconnectTimer;
  bool _isReconnecting = false;

  /// Whether auto-reconnect is currently active
  bool get isAutoReconnecting => _isReconnecting;

  /// Current reconnect attempt number
  int get reconnectAttempt => _backoff?.attempts ?? 0;

  /// Initialize auto-reconnect with given backoff configuration
  void initAutoReconnect(ExponentialBackoff backoff) {
    _backoff = backoff;
  }

  /// Start auto-reconnect process
  Future<void> startAutoReconnect(Future<bool> Function() reconnectFn) async {
    if (_isReconnecting || _backoff == null) return;

    _isReconnecting = true;

    while (_backoff!.shouldRetry && _isReconnecting) {
      try {
        final connected = await reconnectFn();
        if (connected) {
          _backoff!.reset();
          _isReconnecting = false;
          return;
        }
      } catch (e) {
        // Continue to next retry
      }

      if (!await _backoff!.wait()) {
        break;
      }
    }

    _isReconnecting = false;
  }

  /// Stop auto-reconnect process
  void stopAutoReconnect() {
    _isReconnecting = false;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
  }

  /// Reset auto-reconnect state
  void resetAutoReconnect() {
    stopAutoReconnect();
    _backoff?.reset();
  }
}
