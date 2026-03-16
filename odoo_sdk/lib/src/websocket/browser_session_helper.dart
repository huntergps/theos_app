/// Browser Session Helper
///
/// Establishes browser session cookies for WebSocket authentication on Web platform.
/// Uses conditional imports for platform-specific implementations.
library;

import 'browser_session_helper_stub.dart'
    if (dart.library.js_interop) 'browser_session_helper_web.dart'
    as platform;

/// Helper to establish browser session cookies for WebSocket authentication
///
/// This is necessary because:
/// 1. Dio stores cookies in memory, not in browser's cookie storage
/// 2. WebSocket uses browser's native cookie storage
/// 3. Odoo WebSocket validates session from cookies, not query parameters
class BrowserSessionHelper {
  /// Set session cookie directly in browser
  ///
  /// Since Dio doesn't set browser cookies and native HttpRequest fails with CORS,
  /// we manually set the session cookie using document.cookie.
  ///
  /// The sessionId should come from Dio's response headers (Set-Cookie) or
  /// from the authenticateSession() method in OdooClient.
  ///
  /// Returns true if cookie was set successfully, false otherwise.
  /// On non-web platforms, always returns true (no-op).
  static Future<bool> establishBrowserSession({
    required String baseUrl,
    required String apiKey,
    required String database,
    String? sessionId,
  }) async {
    return platform.establishBrowserSession(
      baseUrl: baseUrl,
      apiKey: apiKey,
      database: database,
      sessionId: sessionId,
    );
  }

  /// Check if we have a session cookie in the browser
  ///
  /// On non-web platforms, always returns true.
  static bool hasSessionCookie() {
    return platform.hasSessionCookie();
  }

  /// Get session_id from browser cookies
  ///
  /// On non-web platforms, returns null.
  static String? getSessionIdFromCookies() {
    return platform.getSessionIdFromCookies();
  }

  /// Whether this platform requires browser session handling
  static bool get isWebPlatform => platform.isWebPlatform;
}
