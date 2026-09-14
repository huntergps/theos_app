import 'package:dio/dio.dart';

import '../interceptors/auth_interceptor.dart';
import '../interceptors/retry_interceptor.dart';
import '../interceptors/compression_interceptor.dart';
import '../../utils/security_utils.dart';

import 'native_helpers.dart'
    if (dart.library.js_interop) 'web_helpers.dart'
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

/// HTTP authentication/dispatch mode for an Odoo client.
enum OdooTransportMode { json2Bearer, webSession }

/// Configuration for Odoo HTTP client
class OdooClientConfig {
  final String baseUrl;
  final String apiKey;
  final String? database;
  final OdooTransportMode transportMode;
  final String? csrfToken;
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

  /// Default timezone for API calls (e.g., 'America/Guayaquil'), IANA name.
  ///
  /// `null` (the default) means the request's `context` carries no `tz` key
  /// at all — Odoo's `with_context` REPLACES the whole context per call, so
  /// there is no server-side fallback to rely on here. Only set this once
  /// the authenticated user's own `res.users.tz` is known (see
  /// `OdooClient.updateLocale`); never hardcode a timezone.
  final String? defaultTimezone;

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
    this.transportMode = OdooTransportMode.json2Bearer,
    this.csrfToken,
    this.sendTimeout = const Duration(seconds: 30),
    this.receiveTimeout = const Duration(seconds: 30),
    this.enableRetry = true,
    this.retryConfig = const RetryConfig(),
    this.defaultLanguage = 'en_US',
    this.defaultTimezone,
    this.tokenRefreshHandler,
    this.onApiKeyRefreshed,
    this.allowInsecure = false,
    this.certificatePinning,
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
    OdooTransportMode? transportMode,
    String? csrfToken,
    Duration? sendTimeout,
    Duration? receiveTimeout,
    bool? enableRetry,
    RetryConfig? retryConfig,
    String? defaultLanguage,
    String? defaultTimezone,
    TokenRefreshHandler? tokenRefreshHandler,
    void Function(String newApiKey)? onApiKeyRefreshed,
    bool? allowInsecure,
    CertificatePinningConfig? certificatePinning,
    bool? enableCompression,
    CompressionConfig? compressionConfig,
  }) {
    return OdooClientConfig(
      baseUrl: baseUrl ?? this.baseUrl,
      apiKey: apiKey ?? this.apiKey,
      database: database ?? this.database,
      transportMode: transportMode ?? this.transportMode,
      csrfToken: csrfToken ?? this.csrfToken,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      enableRetry: enableRetry ?? this.enableRetry,
      retryConfig: retryConfig ?? this.retryConfig,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      defaultTimezone: defaultTimezone ?? this.defaultTimezone,
      tokenRefreshHandler: tokenRefreshHandler ?? this.tokenRefreshHandler,
      onApiKeyRefreshed: onApiKeyRefreshed ?? this.onApiKeyRefreshed,
      allowInsecure: allowInsecure ?? this.allowInsecure,
      certificatePinning: certificatePinning ?? this.certificatePinning,
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
    final maskedKey = CredentialMasker.hide(apiKey);
    return 'OdooClientConfig(baseUrl: $baseUrl, apiKey: $maskedKey, '
        'database: $database, language: $defaultLanguage, secure: ${!allowInsecure}, '
        'certificatePinning: ${certificatePinning != null ? 'enabled (${certificatePinning!.sha256Pins.length} pins)' : 'disabled'})';
  }
}

/// Low-level HTTP client for Odoo communication
///
/// Handles:
/// - Dio configuration and interceptors
/// - Request/response logging
/// - Generic POST/GET operations
class OdooHttpClient {
  final Dio _dio;
  OdooClientConfig _config;

  OdooHttpClient({required OdooClientConfig config})
    : _config = config,
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

    // SEC-02: Add auth interceptor for token refresh if handler provided
    if (_config.tokenRefreshHandler != null) {
      _dio.interceptors.add(
        AuthInterceptor(
          dio: _dio,
          config: AuthInterceptorConfig(
            refreshHandler: _config.tokenRefreshHandler!,
            onRetry: (options, newToken) {
              // Update stored API key
              _config.onApiKeyRefreshed?.call(newToken);
              // Update default headers for future requests
              _dio.options.headers['Authorization'] = 'Bearer $newToken';
            },
          ),
        ),
      );
    }

    // Add retry interceptor if enabled (after auth to not retry 401s)
    if (_config.enableRetry) {
      _dio.interceptors.add(
        RetryInterceptor(dio: _dio, config: _config.retryConfig),
      );
    }

    // Add compression interceptor if enabled
    if (_config.enableCompression) {
      _dio.interceptors.add(
        CompressionInterceptor(config: _config.compressionConfig),
      );
    }

    _applyConfig();
  }

  void _applyConfig() {
    _dio.options
      ..baseUrl = _config.transportMode == OdooTransportMode.webSession
          ? _config.normalizedBaseUrl
          : _config.json2Endpoint
      ..headers = {
        'Content-Type': 'application/json',
        if (_config.transportMode == OdooTransportMode.json2Bearer)
          'Authorization': 'Bearer ${_config.apiKey}',
        // Odoo uses this header to select the requested database when the
        // host serves more than one — including from a browser. Whether a
        // browser is actually ALLOWED to send it cross-origin depends
        // entirely on the specific server, never on Odoo by itself:
        //   - Stock Odoo (the `rpc` module's JSON-2 controller,
        //     `odoo/addons/rpc/controllers/json2.py`) declares no `cors` at
        //     all on `/json/2/...` — a different origin is rejected
        //     outright, preflight or not.
        //   - This project's ERP2 test instance allows it, but only because
        //     of two separate, independently-installed addons:
        //     `l10n_ec_collection_box`'s `cors_controller.py` re-declares
        //     the `/json/2` routes with `cors='*'` (that alone only grants
        //     Access-Control-Allow-Origin/-Methods), and
        //     `l10n_ec_collection_box_pos`'s `ir_http.py` separately
        //     monkey-patches Odoo's `Dispatcher.pre_dispatch` to add this
        //     exact header — and `X-Openerp-Session-Id` — to the preflight
        //     Access-Control-Allow-Headers list. Odoo's own unpatched list
        //     (`odoo/http/dispatcher.py`) never includes it, which is also
        //     what Odoo's own `test_http` suite asserts. The first addon
        //     without the second still gets this header rejected by the
        //     browser.
        //   - The reverse proxy in front (nginx, on ERP2) adds none of
        //     this — measured directly against a route Odoo does not
        //     declare `cors` on: zero `Access-Control-*` headers came back.
        // None of the above is guaranteed on any other installation. Check
        // the actual target server; never assume this comment describes it.
        if (_config.transportMode == OdooTransportMode.json2Bearer &&
            _config.database != null &&
            _config.database!.isNotEmpty)
          'X-Odoo-Database': _config.database!,
      }
      ..connectTimeout = const Duration(seconds: 15)
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

  /// Underlying Dio instance for advanced integrations and HTTP test
  /// adapters. Normal application code should use [OdooClient] methods.
  Dio get dio => _dio;

  /// Whether the client has valid credentials
  bool get isConfigured => _config.transportMode == OdooTransportMode.webSession
      ? _config.baseUrl.isNotEmpty
      : _config.apiKey.isNotEmpty;

  /// Make a POST request to JSON-2 API endpoint.
  ///
  /// Optionally pass a [cancelToken] to allow cancelling the request.
  Future<Response<dynamic>> postJson2(
    String path, {
    Map<String, dynamic>? data,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        options: Options(extra: OdooRetryPolicy.metadataForJson2Path(path)),
        cancelToken: cancelToken,
      );
    } on DioException {
      rethrow;
    }
  }

  /// Call Odoo's standard cookie-session JSON-RPC dispatcher.
  Future<Response<dynamic>> postWebSessionRpc({
    required String model,
    required String method,
    required Map<String, dynamic> params,
    CancelToken? cancelToken,
  }) => _dio.post(
    '/web/dataset/call_kw/$model.$method',
    data: {
      'jsonrpc': '2.0',
      'id': DateTime.now().microsecondsSinceEpoch,
      'params': params,
    },
    options: Options(
      headers: {
        if (_config.csrfToken != null) 'X-CSRFToken': _config.csrfToken!,
      },
      extra: {'withCredentials': true},
    ),
    cancelToken: cancelToken,
  );

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
}
