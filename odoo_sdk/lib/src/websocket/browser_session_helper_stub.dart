/// Browser Session Helper - Stub (Non-Web platforms)
///
/// No-op implementation for platforms that don't need browser session handling.
library;

/// Whether this is a web platform
const bool isWebPlatform = false;

/// No-op on non-web platforms
Future<bool> establishBrowserSession({
  required String baseUrl,
  required String apiKey,
  required String database,
  String? sessionId,
}) async {
  return true; // Always succeeds on non-web
}

/// No browser cookies on non-web platforms
bool hasSessionCookie() => true;

/// No browser cookies on non-web platforms
String? getSessionIdFromCookies() => null;
