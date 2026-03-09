import 'package:dio/dio.dart';

import '../interceptors/auth_interceptor.dart';
import '../interceptors/retry_interceptor.dart';
import '../interceptors/compression_interceptor.dart';

import 'native_helpers.dart'
    if (dart.library.html) 'web_helpers.dart'
    as platform_helpers;

/// SEC-04: Exception thrown when insecure connection is attempted.
class InsecureConnectionException implements Exception {
  final String message;
  final String url;

  const InsecureConnectionException(this.message, {required this.url});

  @override
  String toString() => 'InsecureConnectionException: $message (url: $url)';
}

/// Configuration for SSL certificate pinning.
///
/// Supports SHA-256 fingerprint pinning to prevent MITM attacks.
/// Provide one or more pin hashes; the connection succeeds if
/// ANY pin matches (allows rotation).
///
/// Example:
/// ```dart
/// CertificatePinningConfig(
///   sha256Pins: {
///     'AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=', // current
///     'BBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBBB=', // backup
///   },
/// )
/// ```
class CertificatePinningConfig {
  /// SHA-256 fingerprints of trusted certificates (Base64-encoded).
  final Set<String> sha256Pins;

  /// Whether to also accept system-trusted certificates.
  ///
  /// When `false` (default), ONLY pinned certificates are accepted.
  /// When `true`, connections succeed if the cert is either pinned
  /// OR system-trusted (useful during migration).
  final bool allowSystemCertificates;

  const CertificatePinningConfig({
    required this.sha256Pins,
    this.allowSystemCertificates = false,
  });
}

/// Configuration for Odoo HTTP client
class OdooClientConfig {
  final String baseUrl;
  final String apiKey;
  final String? database;
  final Duration sendTimeout;
  final Duration receiveTimeout;

  /// Enable automatic retry on transient failures.
  final bool enableRetry;

  /// Retry configuration (used when enableRetry is true).
  final RetryConfig retryConfig;

  /// Default language for API calls (e.g., 'en_US', 'es_EC', 'fr_FR').
  ///
  /// This is included in the context of all API calls unless overridden.
  /// Uses Odoo locale format: `{language}_{COUNTRY}`.
  final String defaultLanguage;

  /// SEC-02: Optional handler for automatic token refresh on 401 responses.
  ///
  /// When provided, the client will automatically attempt to refresh the token
  /// when receiving a 401 Unauthorized response and retry the failed request.
  ///
  /// If null, 401 responses will propagate as normal errors.
  final TokenRefreshHandler? tokenRefreshHandler;

  /// Callback when token is refreshed and API key should be updated.
  ///
  /// This is called after successful token refresh so you can update
  /// any stored credentials.
  final void Function(String newApiKey)? onApiKeyRefreshed;

  /// SEC-04: Whether to allow insecure HTTP connections.
  ///
  /// SECURITY: Should be `false` in production to enforce HTTPS.
  /// Set to `true` only for local development (e.g., localhost).
  ///
  /// When `false` and [baseUrl] uses http://, [validateSecureConnection()]
  /// will throw [InsecureConnectionException].
  final bool allowInsecure;

  /// SEC-05: Optional certificate pinning configuration.
  ///
  /// When provided, the HTTP client will validate server certificates
  /// against the pinned SHA-256 fingerprints. This prevents MITM attacks
  /// even if a CA is compromised.
  ///
  /// Only effective on native platforms (iOS/Android/desktop).
  /// Ignored on web (browsers manage their own certificate validation).
  final CertificatePinningConfig? certificatePinning;

  /// Whether the app is running on a web platform.
  ///
  /// Used to skip cookie management on web (browsers handle cookies natively).
  /// Pass `true` when running on web, `false` otherwise.
  final bool isWeb;

  /// Whether to enable request payload compression.
  ///
  /// When enabled, large request payloads are automatically compressed
  /// using gzip before sending. Useful for batch operations.
  final bool enableCompression;

  /// Configuration for compression behavior.
  ///
  /// Only used when [enableCompression] is true.
  final CompressionConfig compressionConfig;

  const OdooClientConfig({
    required this.baseUrl,
    required this.apiKey,
    this.database,
    this.sendTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.enableRetry = true,
    this.retryConfig = const RetryConfig(),
    this.defaultLanguage = 'en_US',
    this.tokenRefreshHandler,
    this.onApiKeyRefreshed,
    this.allowInsecure = false,
    this.certificatePinning,
    this.isWeb = false,
    this.enableCompression = false,
    this.compressionConfig = CompressionConfig.standard,
  });

  /// Normalized base URL (without trailing slash)
  String get normalizedBaseUrl => baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;

  /// JSON-2 API endpoint
  String get json2Endpoint => '$normalizedBaseUrl/json/2';

  /// Whether this configuration uses a secure HTTPS connection.
  bool get isSecure {
    try {
      final uri = Uri.parse(baseUrl);
      return uri.scheme == 'https';
    } catch (_) {
      return false;
    }
  }

  /// SEC-04: Validates that the connection uses HTTPS.
  ///
  /// Throws [InsecureConnectionException] if:
  /// - URL uses http:// and [allowInsecure] is false
  ///
  /// Does nothing if [allowInsecure] is true or URL uses https://.
  void validateSecureConnection() {
    if (allowInsecure) return;

    final uri = Uri.parse(baseUrl);

    if (uri.scheme == 'http') {
      throw InsecureConnectionException(
        'Insecure HTTP connection not allowed in production. '
        'Use https:// or set allowInsecure=true for development.',
        url: baseUrl,
      );
    }

    if (uri.scheme != 'https') {
      throw InsecureConnectionException(
        'Invalid URL scheme: ${uri.scheme}. Must be http:// or https://.',
        url: baseUrl,
      );
    }
  }

  OdooClientConfig copyWith({
    String? baseUrl,
    String? apiKey,
    String? database,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableRetry,
    RetryConfig? retryConfig,
    String? defaultLanguage,
    TokenRefreshHandler? tokenRefreshHandler,
    void Function(String newApiKey)? onApiKeyRefreshed,
    bool? allowInsecure,
    CertificatePinningConfig? certificatePinning,
    bool? isWeb,
    bool? enableCompression,
    CompressionConfig? compressionConfig,
  }) {
    return OdooClientConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      database: database ?? this.database,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      enableRetry: enableRetry ?? this.enableRetry,
      retryConfig: retryConfig ?? this.retryConfig,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      tokenRefreshHandler: tokenRefreshHandler ?? this.tokenRefreshHandler,
      onApiKeyRefreshed: onApiKeyRefreshed ?? this.onApiKeyRefreshed,
      allowInsecure: allowInsecure ?? this.allowInsecure,
      certificatePinning: certificatePinning ?? this.certificatePinning,
      isWeb: isWeb ?? this.isWeb,
      enableCompression: enableCompression ?? this.enableCompression,
      compressionConfig: compressionConfig ?? this.compressionConfig,
    );
  }

  /// Secure string representation that does not expose sensitive data.
  ///
  /// SECURITY: API keys and credentials are masked to prevent
  /// accidental exposure in logs, error messages, or stack traces.
  @override
  String toString() {
    final maskedKey = apiKey.length > 4
        ? '${apiKey.substring(0, 2)}${'*' * (apiKey.length - 4)}${apiKey.substring(apiKey.length - 2)}'
        : '****';
    return 'OdooClientConfig(baseUrl: $baseUrl, apiKey: $maskedKey, '
        'database: $database, language: $defaultLanguage, secure: ${!allowInsecure}, '
        'certificatePinning: ${certificatePinning != null ? 'enabled (${certificatePinning!.sha256Pins.length} pins)' : 'disabled'})';
  }
}

/// Low-level HTTP client for Odoo communication
///
/// Handles:
/// - Dio configuration and interceptors
/// - Cookie management (native platforms)
/// - Request/response logging
/// - Generic POST/GET operations
class OdooHttpClient {
  final Dio _dio;
  final Object _cookieJar;
  OdooClientConfig _config;

  OdooHttpClient({required OdooClientConfig config})
    : _config = config,
      _cookieJar = platform_helpers.createCookieJar(),
      _dio = Dio() {
    _initialize();
  }

  void _initialize() {
    // SEC-04: Validate secure connection
    _config.validateSecureConnection();

    // SEC-05: Configure certificate pinning
    if (_config.certificatePinning != null) {
      _configureCertificatePinning(_config.certificatePinning!);
    }

    // Add cookie manager only on native platforms
    if (!_config.isWeb) {
      platform_helpers.addCookieManager(_dio, _cookieJar);
    }

    // SEC-02: Add auth interceptor for token refresh if handler provided
    if (_config.tokenRefreshHandler != null) {
      _dio.interceptors.add(AuthInterceptor(
        dio: _dio,
        config: AuthInterceptorConfig(
          refreshHandler: _config.tokenRefreshHandler!,
          onRetry: (options, newToken) {
            // Update stored API key
            _config.onApiKeyRefreshed?.call(newToken);
            // Update default headers for future requests
            _dio.options.headers['Authorization'] = 'bearer $newToken';
          },
        ),
      ));
    }

    // Add retry interceptor if enabled (after auth to not retry 401s)
    if (_config.enableRetry) {
      _dio.interceptors.add(RetryInterceptor(
        dio: _dio,
        config: _config.retryConfig,
      ));
    }

    // Add compression interceptor if enabled
    if (_config.enableCompression) {
      _dio.interceptors.add(CompressionInterceptor(
        config: _config.compressionConfig,
      ));
    }

    _applyConfig();
  }

  void _applyConfig() {
    _dio.options
      ..baseUrl = _config.json2Endpoint
      ..headers = {
        'Content-Type': 'application/json',
        'Authorization': 'bearer ${_config.apiKey}',
        // On web, X-Odoo-Database triggers CORS preflight that standard Odoo
        // doesn't allow. Omit the header on web — Odoo's monodb detection or
        // a CORS module on the server handles it. On native, always send it.
        if (!_config.isWeb &&
            _config.database != null &&
            _config.database!.isNotEmpty)
          'X-Odoo-Database': _config.database!,
      }
      ..sendTimeout = _config.sendTimeout
      ..receiveTimeout = _config.receiveTimeout
      ..followRedirects = true
      ..maxRedirects = 5;
  }

  /// SEC-05: Configure certificate pinning on the Dio HTTP adapter.
  void _configureCertificatePinning(CertificatePinningConfig pinConfig) {
    platform_helpers.configureCertificatePinning(
      _dio,
      pinConfig.sha256Pins.toList(),
      pinConfig.allowSystemCertificates,
    );
  }

  /// Update client configuration
  void updateConfig(OdooClientConfig config) {
    _config = config;
    _applyConfig();
  }

  /// Current configuration
  OdooClientConfig get config => _config;

  /// Cookie jar for session management (Object on web, CookieJar on native)
  Object get cookieJar => _cookieJar;

  /// Whether the client has valid credentials
  bool get isConfigured => _config.apiKey.isNotEmpty;

  /// Make a POST request to JSON-2 API endpoint.
  ///
  /// Optionally pass a [cancelToken] to allow cancelling the request.
  Future<Response<dynamic>> postJson2(
    String path, {
    Map<String, dynamic>? data,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post(path, data: data, cancelToken: cancelToken);
    } on DioException {
      rethrow;
    }
  }

  /// Make a GET request to any Odoo endpoint.
  ///
  /// Optionally pass a [cancelToken] to allow cancelling the request.
  Future<Response<dynamic>> get(
    String url, {
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get(
        url,
        options: headers != null ? Options(headers: headers) : null,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  /// Make a POST request to any Odoo endpoint (non JSON-2).
  ///
  /// Optionally pass a [cancelToken] to allow cancelling the request.
  Future<Response<dynamic>> post(
    String url, {
    dynamic data,
    Map<String, String>? headers,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post(
        url,
        data: data,
        options: headers != null ? Options(headers: headers) : null,
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  /// Load cookies for a given URL (returns Cookie list on native, empty on web)
  Future<List<dynamic>> loadCookies(Uri uri) async {
    return platform_helpers.loadCookies(_cookieJar, uri);
  }
}
