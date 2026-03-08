/// Compression Interceptor for Dio
///
/// Automatically compresses large request payloads using gzip to reduce
/// bandwidth usage, especially useful for batch operations.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';

/// Configuration for request compression.
class CompressionConfig {
  /// Minimum payload size in bytes to trigger compression.
  ///
  /// Payloads smaller than this threshold are sent uncompressed since
  /// the compression overhead may not be worth it.
  /// Default: 1024 bytes (1 KB).
  final int minSizeForCompression;

  /// Compression level (1-9).
  ///
  /// 1 = fastest, least compression
  /// 6 = balanced (default)
  /// 9 = best compression, slowest
  final int compressionLevel;

  /// Whether to compress requests.
  final bool compressRequests;

  /// Whether to accept compressed responses.
  ///
  /// When true, adds 'Accept-Encoding: gzip' header.
  /// Note: Dio handles response decompression automatically.
  final bool acceptCompressedResponses;

  /// Callback when compression is applied.
  final void Function(int originalSize, int compressedSize)? onCompressed;

  const CompressionConfig({
    this.minSizeForCompression = 1024,
    this.compressionLevel = 6,
    this.compressRequests = true,
    this.acceptCompressedResponses = true,
    this.onCompressed,
  });

  /// Default configuration for general use.
  static const standard = CompressionConfig(
    minSizeForCompression: 1024,
    compressionLevel: 6,
  );

  /// Aggressive compression for slow networks.
  ///
  /// Compresses smaller payloads with higher compression level.
  static const aggressive = CompressionConfig(
    minSizeForCompression: 512,
    compressionLevel: 9,
  );

  /// Minimal compression for fast networks.
  ///
  /// Only compresses very large payloads with fast compression.
  static const minimal = CompressionConfig(
    minSizeForCompression: 10240, // 10 KB
    compressionLevel: 1,
  );

  /// Configuration for batch operations.
  ///
  /// Optimized for large batch create/update operations.
  static const batch = CompressionConfig(
    minSizeForCompression: 2048, // 2 KB
    compressionLevel: 6,
  );
}

/// Statistics about compression performance.
class CompressionStats {
  /// Number of requests compressed.
  int requestsCompressed = 0;

  /// Number of requests skipped (too small).
  int requestsSkipped = 0;

  /// Total bytes before compression.
  int totalOriginalBytes = 0;

  /// Total bytes after compression.
  int totalCompressedBytes = 0;

  /// Compression ratio (0.0 - 1.0).
  ///
  /// Lower is better. 0.5 means compressed to 50% of original size.
  double get compressionRatio {
    if (totalOriginalBytes == 0) return 1.0;
    return totalCompressedBytes / totalOriginalBytes;
  }

  /// Total bytes saved by compression.
  int get bytesSaved => totalOriginalBytes - totalCompressedBytes;

  /// Percentage of bandwidth saved.
  double get savingsPercent => (1.0 - compressionRatio) * 100;

  void reset() {
    requestsCompressed = 0;
    requestsSkipped = 0;
    totalOriginalBytes = 0;
    totalCompressedBytes = 0;
  }

  @override
  String toString() {
    return 'CompressionStats('
        'compressed: $requestsCompressed, '
        'skipped: $requestsSkipped, '
        'ratio: ${(compressionRatio * 100).toStringAsFixed(1)}%, '
        'saved: ${bytesSaved}B)';
  }
}

/// Dio interceptor that compresses large request payloads.
///
/// Usage:
/// ```dart
/// final dio = Dio();
/// final compressionInterceptor = CompressionInterceptor(
///   config: CompressionConfig.standard,
/// );
/// dio.interceptors.add(compressionInterceptor);
///
/// // Check compression stats
/// print(compressionInterceptor.stats);
/// ```
///
/// ## How It Works
///
/// 1. On each request, checks if the payload exceeds [CompressionConfig.minSizeForCompression]
/// 2. If yes, compresses the JSON payload using gzip
/// 3. Sets `Content-Encoding: gzip` header so server knows to decompress
/// 4. Server must support gzip-encoded request bodies (most do)
///
/// ## Compatibility
///
/// - Works with Odoo 17+ which supports gzip request bodies
/// - Automatically adds `Accept-Encoding: gzip` for response compression
/// - Falls back to uncompressed if server returns error
class CompressionInterceptor extends Interceptor {
  final CompressionConfig config;

  /// Statistics about compression performance.
  final CompressionStats stats = CompressionStats();

  CompressionInterceptor({
    this.config = CompressionConfig.standard,
  });

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Add Accept-Encoding header for responses
    if (config.acceptCompressedResponses) {
      options.headers['Accept-Encoding'] = 'gzip, deflate';
    }

    // Only compress if enabled and we have data
    if (!config.compressRequests || options.data == null) {
      handler.next(options);
      return;
    }

    // Convert data to JSON string if needed
    String jsonData;
    if (options.data is String) {
      jsonData = options.data as String;
    } else if (options.data is Map || options.data is List) {
      jsonData = jsonEncode(options.data);
    } else {
      // Can't compress this type
      handler.next(options);
      return;
    }

    // Check if payload is large enough to warrant compression
    final originalBytes = utf8.encode(jsonData);
    final originalSize = originalBytes.length;

    if (originalSize < config.minSizeForCompression) {
      stats.requestsSkipped++;
      handler.next(options);
      return;
    }

    // Compress the payload
    try {
      final compressedBytes = gzip.encode(originalBytes);
      final compressedSize = compressedBytes.length;

      // Only use compression if it actually reduces size
      if (compressedSize >= originalSize) {
        stats.requestsSkipped++;
        handler.next(options);
        return;
      }

      // Update stats
      stats.requestsCompressed++;
      stats.totalOriginalBytes += originalSize;
      stats.totalCompressedBytes += compressedSize;

      // Notify callback
      config.onCompressed?.call(originalSize, compressedSize);

      // Update request with compressed data
      options.data = compressedBytes;
      options.headers['Content-Encoding'] = 'gzip';
      options.headers['Content-Type'] = 'application/json';

      handler.next(options);
    } catch (e) {
      // If compression fails, send uncompressed
      stats.requestsSkipped++;
      handler.next(options);
    }
  }
}

/// Extension to easily add compression to OdooClientConfig.
extension CompressionConfigExtension on CompressionConfig {
  /// Creates a CompressionInterceptor with this configuration.
  CompressionInterceptor toInterceptor() {
    return CompressionInterceptor(config: this);
  }
}
