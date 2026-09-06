import 'package:dio/dio.dart';

import 'native_auth_bootstrap_types.dart';

/// Native-only, interactive bootstrap for Odoo's JSON-2 bearer credential.
///
/// The web-session cookie and password stay in memory for this method only.
/// Runtime ORM calls continue to use [OdooClient] and JSON-2 bearer auth.
class NativeOdooAuthBootstrap {
  NativeOdooAuthBootstrap({Dio? httpClient}) : _http = httpClient ?? Dio();

  final Dio _http;
  int _requestId = 0;
  String? _sessionCookie;

  Future<NativeAuthBootstrapResult> authenticateAndCreateApiKey({
    required String baseUrl,
    required String database,
    required String login,
    required String password,
    String apiKeyName = 'Orbi ERP native login',
  }) async {
    final normalizedUrl = _validatedBaseUrl(baseUrl);
    _sessionCookie = null;
    try {
      final session = await _rpc(
        normalizedUrl,
        '/web/session/authenticate',
        {'db': database, 'login': login, 'password': password},
        captureCookie: true,
        errorKind: NativeAuthBootstrapFailureKind.invalidCredentials,
      );
      final userId = _positiveInt((session as Map?)?['uid']);
      if (userId == null || _sessionCookie == null) {
        throw const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.invalidCredentials,
        );
      }

      await _confirmFreshIdentity(normalizedUrl, password);
      final duration = await _preferredAllowedDuration(normalizedUrl);
      final wizardId = _positiveInt(
        await _callKw(
          normalizedUrl,
          model: 'res.users.apikeys.description',
          method: 'create',
          args: [
            {'name': apiKeyName, 'scope': 'rpc', 'duration': duration},
          ],
        ),
      );
      if (wizardId == null) {
        throw const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.protocol,
        );
      }
      final action = await _callKw(
        normalizedUrl,
        model: 'res.users.apikeys.description',
        method: 'make_key',
        args: [
          [wizardId],
        ],
      );
      final context = (action as Map?)?['context'];
      final apiKey = context is Map ? context['default_key'] : null;
      if (apiKey is! String || apiKey.isEmpty) {
        throw const NativeAuthBootstrapException(
          NativeAuthBootstrapFailureKind.protocol,
        );
      }
      return NativeAuthBootstrapResult(userId: userId, apiKey: apiKey);
    } on NativeAuthBootstrapException {
      rethrow;
    } on DioException {
      throw const NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.connection,
      );
    } finally {
      _sessionCookie = null;
    }
  }

  String _validatedBaseUrl(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || uri.host.isEmpty) {
      throw const NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.insecureTransport,
      );
    }
    return value.endsWith('/') ? value.substring(0, value.length - 1) : value;
  }

  Future<void> _confirmFreshIdentity(String baseUrl, String password) async {
    final result = await _rpc(baseUrl, '/web/session/identity/check', {
      'type': 'password',
      'password': password,
    }, errorKind: NativeAuthBootstrapFailureKind.invalidCredentials);
    if (result == null) return;
    if (result is Map && result['mfa'] == true) {
      final methods =
          (result['auth_methods'] as List?)?.whereType<String>().toList(
            growable: false,
          ) ??
          const <String>[];
      throw NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.additionalVerificationRequired,
        authMethods: methods,
      );
    }
    throw const NativeAuthBootstrapException(
      NativeAuthBootstrapFailureKind.accessDenied,
    );
  }

  Future<String> _preferredAllowedDuration(String baseUrl) async {
    final result = await _callKw(
      baseUrl,
      model: 'res.users.apikeys.description',
      method: 'fields_get',
      args: const [],
      kwargs: const {
        'allfields': ['duration'],
        'attributes': ['selection'],
      },
    );
    dynamic selection;
    if (result is Map) {
      final duration = result['duration'];
      if (duration is Map) selection = duration['selection'];
    }
    final allowed = selection is List
        ? selection
              .whereType<List>()
              .map(
                (entry) => entry.isEmpty ? null : int.tryParse('${entry[0]}'),
              )
              .whereType<int>()
              .where((days) => days > 0 && days <= 90)
              .toList()
        : <int>[];
    return allowed.isEmpty ? '1' : '${allowed.reduce((a, b) => a > b ? a : b)}';
  }

  Future<dynamic> _callKw(
    String baseUrl, {
    required String model,
    required String method,
    required List<dynamic> args,
    Map<String, dynamic> kwargs = const {},
  }) => _rpc(baseUrl, '/web/dataset/call_kw/$model/$method', {
    'model': model,
    'method': method,
    'args': args,
    'kwargs': kwargs,
  });

  Future<dynamic> _rpc(
    String baseUrl,
    String path,
    Map<String, dynamic> params, {
    bool captureCookie = false,
    NativeAuthBootstrapFailureKind errorKind =
        NativeAuthBootstrapFailureKind.accessDenied,
  }) async {
    final response = await _http.post<dynamic>(
      '$baseUrl$path',
      data: {
        'jsonrpc': '2.0',
        'method': 'call',
        'params': params,
        'id': ++_requestId,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (_sessionCookie != null) 'Cookie': _sessionCookie,
        },
        followRedirects: false,
        validateStatus: (status) => status != null && status < 500,
      ),
    );
    if (captureCookie) _captureSessionCookie(response.headers);
    final body = response.data;
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw NativeAuthBootstrapException(
        response.statusCode == 401
            ? NativeAuthBootstrapFailureKind.invalidCredentials
            : NativeAuthBootstrapFailureKind.accessDenied,
      );
    }
    if (body is Map && body['error'] != null) {
      throw NativeAuthBootstrapException(errorKind);
    }
    if (body is! Map || !body.containsKey('result')) {
      throw const NativeAuthBootstrapException(
        NativeAuthBootstrapFailureKind.protocol,
      );
    }
    return body['result'];
  }

  void _captureSessionCookie(Headers headers) {
    final values = headers.map['set-cookie'] ?? const <String>[];
    for (final value in values) {
      final match = RegExp(r'(?:^|[;,]\s*)session_id=([^;,]+)')
          .firstMatch(value);
      if (match != null) {
        _sessionCookie = 'session_id=${match.group(1)}';
        return;
      }
    }
  }

  int? _positiveInt(dynamic value) {
    if (value is int && value > 0) return value;
    if (value is num && value.toInt() > 0) return value.toInt();
    return null;
  }
}
