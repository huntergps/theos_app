/// Metrics Interceptor for Dio
///
/// Collects performance metrics and provides observability hooks
/// for HTTP requests to Odoo.
library;

import 'package:dio/dio.dart';

/// A single request metric data point.
class RequestMetric {
  /// Unique request ID.
  final String requestId;

  /// HTTP method (GET, POST, etc.).
  final String method;

  /// Request path/URL.
  final String path;

  /// Odoo model being accessed (extracted from path).
  final String? odooModel;

  /// Odoo method being called (extracted from path).
  final String? odooMethod;

  /// Start time of the request.
  final DateTime startTime;

  /// End time of the request (null if still in progress).
  final DateTime? endTime;

  /// HTTP status code (null if request failed before response).
  final int? statusCode;

  /// Whether the request succeeded.
  final bool success;

  /// Error message if the request failed.
  final String? error;

  /// Response size in bytes (if available).
  final int? responseSize;

  /// Retry attempt number (0 for first attempt).
  final int retryAttempt;

  const RequestMetric({
    required this.requestId,
    required this.method,
    required this.path,
    this.odooModel,
    this.odooMethod,
    required this.startTime,
    this.endTime,
    this.statusCode,
    this.success = false,
    this.error,
    this.responseSize,
    this.retryAttempt = 0,
  });

  /// Duration of the request (null if still in progress).
  Duration? get duration =>
      endTime?.difference(startTime);

  /// Duration in milliseconds (null if still in progress).
  int? get durationMs => duration?.inMilliseconds;

  RequestMetric copyWith({
    DateTime? endTime,
    int? statusCode,
    bool? success,
    String? error,
    int? responseSize,
  }) {
    return RequestMetric(
      requestId: requestId,
      method: method,
      path: path,
      odooModel: odooModel,
      odooMethod: odooMethod,
      startTime: startTime,
      endTime: endTime ?? this.endTime,
      statusCode: statusCode ?? this.statusCode,
      success: success ?? this.success,
      error: error ?? this.error,
      responseSize: responseSize ?? this.responseSize,
      retryAttempt: retryAttempt,
    );
  }

  @override
  String toString() =>
      'RequestMetric($method $path, ${durationMs}ms, status: $statusCode, success: $success)';
}

/// Callback type for metric events.
typedef MetricCallback = void Function(RequestMetric metric);

/// Aggregated metrics for a time window.
class AggregatedMetrics {
  /// Total number of requests.
  final int totalRequests;

  /// Number of successful requests.
  final int successfulRequests;

  /// Number of failed requests.
  final int failedRequests;

  /// Average latency in milliseconds.
  final double averageLatencyMs;

  /// P50 (median) latency in milliseconds.
  final double p50LatencyMs;

  /// P95 latency in milliseconds.
  final double p95LatencyMs;

  /// P99 latency in milliseconds.
  final double p99LatencyMs;

  /// Requests grouped by Odoo model.
  final Map<String, int> requestsByModel;

  /// Errors grouped by type.
  final Map<String, int> errorsByType;

  /// Start of the aggregation window.
  final DateTime windowStart;

  /// End of the aggregation window.
  final DateTime windowEnd;

  const AggregatedMetrics({
    required this.totalRequests,
    required this.successfulRequests,
    required this.failedRequests,
    required this.averageLatencyMs,
    required this.p50LatencyMs,
    required this.p95LatencyMs,
    required this.p99LatencyMs,
    required this.requestsByModel,
    required this.errorsByType,
    required this.windowStart,
    required this.windowEnd,
  });

  /// Success rate as a percentage (0-100).
  double get successRate =>
      totalRequests > 0 ? (successfulRequests / totalRequests) * 100 : 0;

  /// Failure rate as a percentage (0-100).
  double get failureRate =>
      totalRequests > 0 ? (failedRequests / totalRequests) * 100 : 0;

  @override
  String toString() =>
      'AggregatedMetrics(requests: $totalRequests, success: ${successRate.toStringAsFixed(1)}%, '
      'avgLatency: ${averageLatencyMs.toStringAsFixed(0)}ms)';
}

/// Collector for request metrics with aggregation support.
class MetricsCollector {
  final List<RequestMetric> _metrics = [];
  final int _maxMetrics;

  /// Callbacks to notify when metrics are recorded.
  final List<MetricCallback> _callbacks = [];

  MetricsCollector({int maxMetrics = 1000}) : _maxMetrics = maxMetrics;

  /// Add a callback to be notified of new metrics.
  void addCallback(MetricCallback callback) {
    _callbacks.add(callback);
  }

  /// Remove a callback.
  void removeCallback(MetricCallback callback) {
    _callbacks.remove(callback);
  }

  /// Record a new metric.
  void record(RequestMetric metric) {
    _metrics.add(metric);

    // Trim old metrics if we exceed the limit
    while (_metrics.length > _maxMetrics) {
      _metrics.removeAt(0);
    }

    // Notify callbacks
    for (final callback in _callbacks) {
      callback(metric);
    }
  }

  /// Get all recorded metrics.
  List<RequestMetric> get metrics => List.unmodifiable(_metrics);

  /// Get metrics for a specific model.
  List<RequestMetric> metricsForModel(String model) {
    return _metrics.where((m) => m.odooModel == model).toList();
  }

  /// Get metrics within a time window.
  List<RequestMetric> metricsInWindow(DateTime start, DateTime end) {
    return _metrics
        .where(
          (m) =>
              m.startTime.isAfter(start) &&
              m.startTime.isBefore(end),
        )
        .toList();
  }

  /// Get aggregated metrics for a time window.
  AggregatedMetrics aggregate({DateTime? since, Duration? window}) {
    final windowEnd = DateTime.now();
    final windowStart = since ?? windowEnd.subtract(window ?? const Duration(minutes: 5));

    final windowMetrics = metricsInWindow(windowStart, windowEnd);

    if (windowMetrics.isEmpty) {
      return AggregatedMetrics(
        totalRequests: 0,
        successfulRequests: 0,
        failedRequests: 0,
        averageLatencyMs: 0,
        p50LatencyMs: 0,
        p95LatencyMs: 0,
        p99LatencyMs: 0,
        requestsByModel: {},
        errorsByType: {},
        windowStart: windowStart,
        windowEnd: windowEnd,
      );
    }

    final successful = windowMetrics.where((m) => m.success).length;
    final failed = windowMetrics.length - successful;

    // Calculate latencies
    final latencies = windowMetrics
        .where((m) => m.durationMs != null)
        .map((m) => m.durationMs!)
        .toList()
      ..sort();

    double avg = 0;
    double p50 = 0;
    double p95 = 0;
    double p99 = 0;

    if (latencies.isNotEmpty) {
      avg = latencies.reduce((a, b) => a + b) / latencies.length;
      p50 = _percentile(latencies, 50);
      p95 = _percentile(latencies, 95);
      p99 = _percentile(latencies, 99);
    }

    // Group by model
    final byModel = <String, int>{};
    for (final m in windowMetrics) {
      if (m.odooModel != null) {
        byModel[m.odooModel!] = (byModel[m.odooModel!] ?? 0) + 1;
      }
    }

    // Group errors by type
    final byError = <String, int>{};
    for (final m in windowMetrics.where((m) => !m.success)) {
      final errorType = m.error ?? 'unknown';
      byError[errorType] = (byError[errorType] ?? 0) + 1;
    }

    return AggregatedMetrics(
      totalRequests: windowMetrics.length,
      successfulRequests: successful,
      failedRequests: failed,
      averageLatencyMs: avg,
      p50LatencyMs: p50,
      p95LatencyMs: p95,
      p99LatencyMs: p99,
      requestsByModel: byModel,
      errorsByType: byError,
      windowStart: windowStart,
      windowEnd: windowEnd,
    );
  }

  /// Clear all recorded metrics.
  void clear() {
    _metrics.clear();
  }

  /// Calculates the given percentile from a sorted list of values.
  ///
  /// Returns 0 if the list is empty. The [percentile] should be
  /// between 0 and 100 (e.g., 95 for p95).
  double _percentile(List<int> sorted, int percentile) {
    if (sorted.isEmpty) return 0;
    final index = (percentile / 100 * (sorted.length - 1)).round();
    return sorted[index].toDouble();
  }
}

/// Dio interceptor that collects request metrics.
///
/// Usage:
/// ```dart
/// final collector = MetricsCollector();
/// final dio = Dio();
/// dio.interceptors.add(MetricsInterceptor(collector: collector));
///
/// // Listen to metrics
/// collector.addCallback((metric) {
///   print('Request: ${metric.path} took ${metric.durationMs}ms');
/// });
///
/// // Get aggregated stats
/// final stats = collector.aggregate(window: Duration(minutes: 5));
/// print('Success rate: ${stats.successRate}%');
/// ```
class MetricsInterceptor extends Interceptor {
  final MetricsCollector collector;
  int _requestCounter = 0;

  MetricsInterceptor({required this.collector});

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Generate unique request ID
    final requestId = 'req_${++_requestCounter}_${DateTime.now().millisecondsSinceEpoch}';
    options.extra['metricsRequestId'] = requestId;
    options.extra['metricsStartTime'] = DateTime.now();

    // Extract Odoo model and method from path
    // Path format: /{model}/{method}
    final pathParts = options.path.split('/').where((p) => p.isNotEmpty).toList();
    if (pathParts.length >= 2) {
      options.extra['metricsOdooModel'] = pathParts[0];
      options.extra['metricsOdooMethod'] = pathParts[1];
    }

    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    _recordMetric(
      response.requestOptions,
      statusCode: response.statusCode,
      success: true,
      responseSize: _calculateResponseSize(response),
    );
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    _recordMetric(
      err.requestOptions,
      statusCode: err.response?.statusCode,
      success: false,
      error: _categorizeError(err),
    );
    handler.next(err);
  }

  /// Records a metric for a completed request.
  ///
  /// Extracts timing information from request extras and creates
  /// a [RequestMetric] that is passed to the collector.
  void _recordMetric(
    RequestOptions options, {
    int? statusCode,
    required bool success,
    String? error,
    int? responseSize,
  }) {
    final requestId = options.extra['metricsRequestId'] as String? ?? 'unknown';
    final startTime = options.extra['metricsStartTime'] as DateTime? ?? DateTime.now();
    final retryCount = options.extra['retryCount'] as int? ?? 0;

    final metric = RequestMetric(
      requestId: requestId,
      method: options.method,
      path: options.path,
      odooModel: options.extra['metricsOdooModel'] as String?,
      odooMethod: options.extra['metricsOdooMethod'] as String?,
      startTime: startTime,
      endTime: DateTime.now(),
      statusCode: statusCode,
      success: success,
      error: error,
      responseSize: responseSize,
      retryAttempt: retryCount,
    );

    collector.record(metric);
  }

  /// Calculates the response body size in bytes if determinable.
  ///
  /// Returns the length for String or `List<int>` data types.
  /// Returns null for other types where size cannot be easily determined.
  int? _calculateResponseSize(Response response) {
    final data = response.data;
    if (data is String) return data.length;
    if (data is List<int>) return data.length;
    // For other types, we can't easily determine size
    return null;
  }

  /// Categorizes a Dio exception into a human-readable error type string.
  ///
  /// Returns strings like 'connection_timeout', 'http_404', 'cancelled', etc.
  /// Used for grouping errors in metrics aggregation.
  String _categorizeError(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionTimeout:
        return 'connection_timeout';
      case DioExceptionType.sendTimeout:
        return 'send_timeout';
      case DioExceptionType.receiveTimeout:
        return 'receive_timeout';
      case DioExceptionType.connectionError:
        return 'connection_error';
      case DioExceptionType.badResponse:
        return 'http_${err.response?.statusCode ?? "unknown"}';
      case DioExceptionType.cancel:
        return 'cancelled';
      default:
        return 'unknown';
    }
  }
}

/// Extension to easily add metrics to Dio.
extension DioMetricsExtension on Dio {
  /// Add metrics interceptor with a new collector.
  MetricsCollector enableMetrics() {
    final collector = MetricsCollector();
    interceptors.add(MetricsInterceptor(collector: collector));
    return collector;
  }

  /// Add metrics interceptor with an existing collector.
  void enableMetricsWithCollector(MetricsCollector collector) {
    interceptors.add(MetricsInterceptor(collector: collector));
  }
}
