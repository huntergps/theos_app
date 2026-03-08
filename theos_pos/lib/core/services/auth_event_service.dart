import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:odoo_sdk/odoo_sdk.dart' show TokenRefreshHandler, TokenRefreshResult;

enum AuthEvent { sessionExpired }

/// Service that broadcasts authentication events (e.g., session expired).
///
/// Uses a debounce mechanism to prevent flooding when multiple 401 responses
/// arrive simultaneously.
class AuthEventService {
  final _controller = StreamController<AuthEvent>.broadcast();
  bool _isHandling = false;

  Stream<AuthEvent> get events => _controller.stream;

  void notifySessionExpired() {
    if (_isHandling) return;
    _isHandling = true;
    _controller.add(AuthEvent.sessionExpired);
    Future.delayed(const Duration(seconds: 5), () => _isHandling = false);
  }

  void reset() => _isHandling = false;

  void dispose() => _controller.close();
}

final authEventServiceProvider = Provider<AuthEventService>((ref) {
  final service = AuthEventService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// TokenRefreshHandler that always fails refresh and notifies session expired.
///
/// For Odoo API key authentication, there is no token refresh mechanism.
/// When a 401 is received, the API key has been revoked or expired,
/// so we notify the app to redirect to login.
class SessionExpiredHandler implements TokenRefreshHandler {
  final AuthEventService _authEventService;

  SessionExpiredHandler(this._authEventService);

  @override
  Future<TokenRefreshResult> refreshToken() async {
    // API keys cannot be refreshed — always fail
    return TokenRefreshResult.failed('API key expired or revoked');
  }

  @override
  void onTokenRefreshed(String newToken) {
    // Will never be called since refreshToken always fails
  }

  @override
  void onRefreshFailed(Object error) {
    _authEventService.notifySessionExpired();
  }
}
