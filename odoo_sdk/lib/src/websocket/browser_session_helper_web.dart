/// Browser Session Helper - Web Implementation
///
/// Handles session cookie management for WebSocket authentication on Web platform.
library;

// ignore: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

import '../services/logger_service.dart';

/// Whether this is a web platform
const bool isWebPlatform = true;

/// Set session cookie directly in browser
///
/// Since Dio doesn't set browser cookies and native HttpRequest fails with CORS,
/// we manually set the session cookie using document.cookie.
Future<bool> establishBrowserSession({
  required String baseUrl,
  required String apiKey,
  required String database,
  String? sessionId,
}) async {
  try {
    logger.d('[BrowserSession]', 'Setting browser session cookie...');

    if (sessionId == null || sessionId.isEmpty) {
      logger.d('[BrowserSession]', 'No session_id provided');
      return false;
    }

    // Parse the base URL to get the domain for the cookie
    final uri = Uri.parse(baseUrl);
    final domain = uri.host;

    // Set session_id cookie manually
    // Note: For localhost, we don't set domain (browser will use current host)
    // For production, we might need to set the domain
    final cookieValue = 'session_id=$sessionId; path=/; SameSite=Lax';

    html.document.cookie = cookieValue;

    logger.d(
      '[BrowserSession]',
      'Cookie set: session_id=${sessionId.substring(0, 10)}...',
    );
    logger.d('[BrowserSession]', 'Domain: $domain');

    // Verify the cookie was set
    final cookies = html.document.cookie ?? '';
    if (cookies.contains('session_id=')) {
      logger.d('[BrowserSession]', 'Cookie verified in browser');
      return true;
    } else {
      logger.d('[BrowserSession]', 'Cookie NOT found after setting');
      return false;
    }
  } catch (e) {
    logger.d('[BrowserSession]', 'Error setting session cookie: $e');
    return false;
  }
}

/// Check if we have a session cookie in the browser
bool hasSessionCookie() {
  final cookies = html.document.cookie ?? '';
  return cookies.contains('session_id=');
}

/// Get session_id from browser cookies
String? getSessionIdFromCookies() {
  final cookies = html.document.cookie ?? '';
  final match = RegExp(r'session_id=([^;]+)').firstMatch(cookies);
  return match?.group(1);
}
