import 'dart:async';

/// Serializes teardown of server-scoped resources.
///
/// Logout, token expiration and server switching can arrive at the same time.
/// The first caller owns the cleanup; concurrent callers await the same future
/// instead of running cleanup twice or racing a new login.
final class SessionTeardownCoordinator {
  Future<void>? _inFlight;

  bool get isRunning => _inFlight != null;

  Future<void> run(FutureOr<void> Function() teardown) {
    final current = _inFlight;
    if (current != null) return current;

    final future = Future<void>.sync(teardown);
    _inFlight = future;
    future.then(
      (_) {
        if (identical(_inFlight, future)) _inFlight = null;
      },
      onError: (Object _, StackTrace _) {
        if (identical(_inFlight, future)) _inFlight = null;
      },
    );
    return future;
  }
}
