import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart';

import 'web_credential_store.dart';

/// Why every failure of this route is its own kind rather than an HTTP code.
///
/// The route answers with an explicit status AND a body carrying a code
/// (`WEB_AUTH.md`, and `controllers/web_token_auth.py`). Keeping them as a
/// closed set here means the screen never has to reason about HTTP, and the
/// classifier has exactly one place to translate them.
enum WebTokenAuthFailureKind {
  /// 401 `invalid_credentials`. A wrong password and a login that does not
  /// exist are THE SAME answer — same status, same body, same headers, and
  /// the same hash verification is spent either way so they cannot be told
  /// apart by timing either. Deliberate, upstream. Never try to split them.
  invalidCredentials,

  /// 403 `mfa_required`. The account has a second factor and a stateless
  /// single call has nowhere to ask for it.
  mfaRequired,

  /// 403 `not_allowed` / `login_rejected` / `forbidden_origin`.
  forbidden,

  /// 429 `too_many_attempts`. Says nothing about the credential.
  tooManyAttempts,

  /// 400 `invalid_request` / `database_unavailable`.
  badRequest,

  /// 500 `server_error`, or any 5xx.
  serverError,

  /// Never reached the server, or the answer was not this route's.
  transport,

  /// A 200 that did not carry the six fields this route promises.
  malformedResponse,
}

final class WebTokenAuthException implements Exception {
  const WebTokenAuthException(this.kind);

  final WebTokenAuthFailureKind kind;

  /// Carries no server payload and no submitted credential, on purpose —
  /// same rule as `NativeAuthBootstrapException`.
  @override
  String toString() => 'WebTokenAuthException(${kind.name})';
}

/// One HTTP exchange, reduced to what this route needs.
///
/// A port rather than a direct `dio` call for two reasons: `theos_panel` does
/// not declare `dio` (it arrives transitively through `odoo_sdk`, and adding
/// a direct dependency would regenerate a lockfile that was resolved with a
/// pinned SDK), and every test below drives a fake instead of a socket.
typedef OrbiTokenTransport =
    Future<OrbiTokenHttpResponse> Function(Uri url, Map<String, Object?> body);

final class OrbiTokenHttpResponse {
  const OrbiTokenHttpResponse({required this.statusCode, this.body});

  final int statusCode;

  /// Decoded JSON object, or null when the answer was not one.
  final Map<String, Object?>? body;
}

/// Exchanges a password for a short-lived API key, in one call and with no
/// cookie — the piece that makes password sign-in possible in a browser.
///
/// `/web/session/authenticate` cannot be used from a browser: it is
/// `type='jsonrpc'`, declares no CORS, and the preflight comes back 415
/// before the password ever leaves the page (measured against ERP2,
/// 11-sep-2026). See `WEB_AUTH.md`.
final class OrbiWebTokenAuthClient {
  const OrbiWebTokenAuthClient({
    required this.transport,
    this.deviceLabel = 'Orbi web',
  });

  final OrbiTokenTransport transport;

  /// A label the person can recognise — and revoke — in their own Odoo user
  /// preferences. Not an identifier and not a secret.
  final String deviceLabel;

  static const String routePath = '/orbi/auth/token';

  /// Builds the endpoint from the SAVED SERVER's origin, never from
  /// `Uri.base`.
  ///
  /// That distinction is the whole point: ERP2 now serves Orbi from its own
  /// domain under `/orbi/`, and the app is also meant to run from somewhere
  /// else entirely. Deriving the URL from where the page happens to be hosted
  /// would work in exactly one of those two and silently break the other.
  static Uri endpointFor(String serverUrl) {
    final base = Uri.parse(serverUrl.trim());
    return base.replace(path: routePath, query: null, fragment: null);
  }

  /// Returns the credential in the SAME shape that gets persisted, on
  /// purpose.
  ///
  /// [WebAuthCredential.fromResponse] already reads this exact 200 body and
  /// [WebAuthCredential.parseServerExpiry] already handles the one genuinely
  /// dangerous field. Parsing it a second time here would mean two readings
  /// of one contract that could drift apart — and the field they would drift
  /// on is an expiry, where a disagreement means using a dead key and blaming
  /// the network. One reading, owned by the half that has to honour it.
  Future<WebAuthCredential> issue({
    required String serverUrl,
    required String login,
    required String password,
    String? database,
  }) async {
    if (serverUrl.trim().isEmpty ||
        login.trim().isEmpty ||
        password.isEmpty) {
      throw const WebTokenAuthException(WebTokenAuthFailureKind.badRequest);
    }
    final OrbiTokenHttpResponse response;
    try {
      response = await transport(endpointFor(serverUrl), {
        'login': login,
        'password': password,
        // Only ever PINS the expected database; it never selects one. Sending
        // a different db than the host serves is refused rather than silently
        // entering another database.
        if (database != null && database.trim().isNotEmpty) 'db': database,
        'device': deviceLabel,
      });
    } catch (_) {
      throw const WebTokenAuthException(WebTokenAuthFailureKind.transport);
    }
    if (response.statusCode == 200) return _parse(response.body);

    throw WebTokenAuthException(
      _failureFor(response.statusCode, response.body),
    );
  }

  static WebAuthCredential _parse(Map<String, Object?>? body) {
    if (body == null) {
      throw const WebTokenAuthException(
        WebTokenAuthFailureKind.malformedResponse,
      );
    }
    try {
      return WebAuthCredential.fromResponse(
        Map<String, dynamic>.from(body),
      );
    } on FormatException {
      // A 200 that did not carry what this route promises. The password was
      // accepted and a usable credential still did not arrive — the same
      // situation the native path calls `protocol`, and never something to
      // report as a bad password.
      throw const WebTokenAuthException(
        WebTokenAuthFailureKind.malformedResponse,
      );
    } on TypeError {
      throw const WebTokenAuthException(
        WebTokenAuthFailureKind.malformedResponse,
      );
    }
  }

  static WebTokenAuthFailureKind _failureFor(
    int statusCode,
    Map<String, Object?>? body,
  ) {
    final code = body?['error'];
    if (code is String) {
      switch (code) {
        case 'invalid_credentials':
          return WebTokenAuthFailureKind.invalidCredentials;
        case 'mfa_required':
          return WebTokenAuthFailureKind.mfaRequired;
        case 'forbidden_origin':
        case 'not_allowed':
        case 'login_rejected':
          return WebTokenAuthFailureKind.forbidden;
        case 'too_many_attempts':
          return WebTokenAuthFailureKind.tooManyAttempts;
        case 'invalid_request':
        case 'database_unavailable':
          return WebTokenAuthFailureKind.badRequest;
        case 'server_error':
          return WebTokenAuthFailureKind.serverError;
      }
    }
    // A status with no code we recognise: trust the status, never guess a
    // friendlier story than the server told.
    return switch (statusCode) {
      400 => WebTokenAuthFailureKind.badRequest,
      401 => WebTokenAuthFailureKind.invalidCredentials,
      403 => WebTokenAuthFailureKind.forbidden,
      429 => WebTokenAuthFailureKind.tooManyAttempts,
      >= 500 => WebTokenAuthFailureKind.serverError,
      // 303 is what a GET to this path returns (it falls through to the
      // catch-all that redirects to login). A redirect on our POST means we
      // did not reach the route we meant to.
      _ => WebTokenAuthFailureKind.transport,
    };
  }
}

/// A transport backed by `odoo_sdk`'s HTTP client.
///
/// Built here rather than in the composition root only because unwrapping the
/// error needs care: the underlying client throws on any 4xx, and this route
/// says everything that matters IN those 4xx bodies. `theos_panel` cannot
/// name `DioException` (it does not declare `dio`), so the response is read
/// off the thrown object dynamically — narrow, deliberate, and the only place
/// in the app that does it.
OrbiTokenTransport odooSdkTokenTransport() {
  return (url, body) async {
    final client = OdooClient(
      config: OdooClientConfig(
        baseUrl: url.origin,
        // No credential of any kind: this route is `auth='none'`, takes no
        // cookie, and is the call that GETS us a credential.
        apiKey: '',
        allowInsecure: url.scheme != 'https',
      ),
    );
    try {
      final response = await client.http.post(url.toString(), data: body);
      return OrbiTokenHttpResponse(
        statusCode: response.statusCode ?? 0,
        body: _asJsonObject(response.data),
      );
    } catch (error) {
      final dynamic response = _responseOf(error);
      if (response == null) rethrow;
      return OrbiTokenHttpResponse(
        statusCode: (response.statusCode as int?) ?? 0,
        body: _asJsonObject(response.data),
      );
    }
  };
}

dynamic _responseOf(Object error) {
  try {
    return (error as dynamic).response;
  } catch (_) {
    // Not an HTTP error object: a socket/DNS/CORS failure, which has no
    // response to read.
    return null;
  }
}

Map<String, Object?>? _asJsonObject(Object? data) {
  if (data is Map) {
    return data.map((key, value) => MapEntry(key.toString(), value));
  }
  return null;
}

/// **Inert by default; the composition root supplies the real one.**
///
/// Same shape — and same hard-won reason — as
/// `networkPresenceProbeProvider` and `workspaceUnlockBackendProvider`: a
/// default that opens a real socket would make any widget test that submits
/// the login form reach for the network inside a fake-async zone. The inert
/// default refuses in a way the classifier already has words for, so a test
/// that forgets to override it gets a clear message instead of a hang.
final orbiWebTokenClientProvider = Provider<OrbiWebTokenAuthClient?>(
  (ref) => null,
);

/// What `bootstrap.dart` registers so the browser really calls the server.
final orbiWebTokenClientOverride = orbiWebTokenClientProvider.overrideWithValue(
  OrbiWebTokenAuthClient(transport: odooSdkTokenTransport()),
);
