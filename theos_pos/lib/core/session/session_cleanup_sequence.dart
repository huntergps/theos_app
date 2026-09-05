import 'dart:async';

/// One named phase of the session shutdown sequence.
final class SessionCleanupStep {
  const SessionCleanupStep(this.name, this.action);

  final String name;
  final FutureOr<void> Function() action;
}

/// Runs every cleanup phase in order, even when an earlier phase fails.
///
/// Logout and process shutdown must still revoke credentials and close the
/// scoped database after a background service reports an error. Individual
/// failures are surfaced through [onError] without aborting the remaining
/// phases.
Future<void> runBestEffortSessionCleanup(
  Iterable<SessionCleanupStep> steps, {
  void Function(String step, Object error, StackTrace stackTrace)? onError,
}) async {
  for (final step in steps) {
    try {
      await step.action();
    } catch (error, stackTrace) {
      onError?.call(step.name, error, stackTrace);
    }
  }
}
