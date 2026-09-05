import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:theos_pos_core/theos_pos_core.dart' show SessionState;

import '../../../core/database/providers.dart' show currentSessionProvider;

/// Provider that checks if there's an active collection session.
///
/// Returns `true` when the current session is in an active state
/// (`openingControl`, `opened`, `paused`, or `closingControl`).
/// Returns `false` when there is no session, or when the session is `closed`.
///
/// Usage in widgets:
/// ```dart
/// final hasActiveSession = ref.watch(hasActiveCollectionSessionProvider);
/// if (!hasActiveSession) {
///   // show warning to user
/// }
/// ```
///
/// Note: This provider intentionally reads only from [currentSessionProvider]
/// (in-memory state) without triggering any network or database fetch.
/// The session is populated on app init or when the user opens/navigates to
/// the collection dashboard.
final hasActiveCollectionSessionProvider = Provider<bool>((ref) {
  final session = ref.watch(currentSessionProvider);
  if (session == null) return false;

  // Closed sessions are not considered active for POS operations.
  // This is a route/session-existence guard. Transaction controls separately
  // require `canRegisterTransactions`, so a paused session remains visible but
  // cannot accept payments, cash outs or advances.
  return session.state != SessionState.closed;
});
