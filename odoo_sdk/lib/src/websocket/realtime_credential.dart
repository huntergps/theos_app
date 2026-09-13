/// Real-time bus credential and its async provider.
///
/// Odoo 19.5 does not authenticate the `/websocket` route with a JSON-2
/// Bearer token: measured against ERP2, the bus closes the socket with 4001
/// when a Bearer header is the only credential offered. The bus identifies
/// the caller by session instead, so real-time connections need a
/// short-lived, real-time-only session minted by a project route (never the
/// long-lived JSON-2 API key itself).
///
/// [RealtimeCredential] is therefore fetched through an injectable
/// [RealtimeCredentialProvider] rather than stored as a plain field on
/// [OdooWebSocketConnectionInfo] — the exact route contract can change
/// without touching the WebSocket transport.
library;

import '../utils/security_utils.dart';

/// A short-lived session used to authenticate the real-time bus connection.
///
/// Sent as the `session_id` query parameter on the WebSocket URL — the
/// project module `l10n_ec_collection_box_pos` accepts `session_id` by
/// query on its `/websocket` override.
class RealtimeCredential {
  /// Real-time session id.
  final String sessionId;

  /// When the server stops honoring [sessionId].
  final DateTime expiresAt;

  const RealtimeCredential({required this.sessionId, required this.expiresAt});

  /// Whether [expiresAt] is already in the past.
  bool get isExpired => DateTime.now().isAfter(expiresAt);

  /// SEC-01: never expose [sessionId] in logs, error messages or crash
  /// reports.
  @override
  String toString() =>
      'RealtimeCredential(sessionId: ${CredentialMasker.hide(sessionId)}, '
      'expiresAt: $expiresAt)';
}

/// Fetches a fresh [RealtimeCredential].
///
/// Called:
/// - once, right before the first connection attempt;
/// - again on every reconnection (network drop, server error, manual
///   reconnect after a server switch);
/// - again proactively when the previously-issued credential's
///   [RealtimeCredential.expiresAt] is reached, so the socket renews itself
///   before the server drops it.
///
/// Consumers (orbi_runtime) implement this against the project route that
/// mints a real-time-only session from a JSON-2 API key.
typedef RealtimeCredentialProvider = Future<RealtimeCredential> Function();
