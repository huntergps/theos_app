import 'package:odoo_sdk/odoo_sdk.dart'
    show OdooConnectionException, OdooOfflineException, OdooTimeoutException;

/// Only transport unavailability may fall back to a previously committed
/// offline session. Protocol, server, validation and programming errors must
/// remain visible instead of being disguised as an offline login.
bool isOfflineFallbackEligible(Object error) =>
    error is OdooConnectionException ||
    error is OdooTimeoutException ||
    error is OdooOfflineException;

/// Ensures a failed offline authentication/resume attempt cannot leave its
/// scoped database or background work active.
final class OfflineSessionAttemptGuard {
  OfflineSessionAttemptGuard(this._deactivate);

  final Future<void> Function() _deactivate;
  bool _succeeded = false;
  bool _closed = false;

  bool get succeeded => _succeeded;

  void markSucceeded() {
    if (_closed) {
      throw StateError('Offline attempt is already closed');
    }
    _succeeded = true;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    if (!_succeeded) await _deactivate();
  }
}
