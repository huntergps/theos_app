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

/// A single-use ticket used to open the real-time bus session.
///
/// `POST /app_sync/realtime/session` (project module `l10n_ec_app_sync`)
/// exchanges the JSON-2 API key for this ticket instead of handing back a
/// long-lived session id directly: a 1-hour session id sent as
/// `?session_id=` would sit in cleartext in every access log and proxy log
/// line for the handshake (`"GET /websocket?..." `). [ticket] is only good
/// for [expiresAt] (a handful of seconds) and exactly one handshake — the
/// server exchanges it for the real, longer-lived session and discards it,
/// so nothing long-lived is ever written to a log.
///
/// Sent as the `ticket` query parameter on the WebSocket URL, once, on
/// every connection attempt (see [RealtimeCredentialProvider] — a ticket is
/// never stored or reused). A used or expired ticket makes the handshake
/// fail with HTTP 403; that is a retry-with-backoff case, never
/// `disabled` — only a 404 on the session route means that.
class RealtimeCredential {
  /// Single-use ticket for the next WebSocket handshake.
  final String ticket;

  /// When the server stops honoring [ticket] itself (a short, fixed TTL —
  /// informational only: callers always send [ticket] immediately on the
  /// next connection attempt and never check this before doing so).
  final DateTime expiresAt;

  /// When the SESSION the server opens by redeeming [ticket] will expire
  /// (≤ 1 h, never longer than the API key). This — not [expiresAt] — is
  /// what schedules the proactive reconnect: see
  /// [WebSocketConnectionManager]'s credential-expiry timer.
  final DateTime sessionExpiresAt;

  /// The bus protocol version this SPECIFIC server expects on `?version=`
  /// (Odoo's `WebsocketConnectionHandler._VERSION`, e.g. `saas-19.5-1`) —
  /// it changes with every Odoo series, so the SDK cannot hardcode it. A
  /// mismatch gets the socket closed CLEANLY with reason `OUTDATED_VERSION`
  /// (measured against ERP2 19.5, 13-sep-2026: the SDK's own hardcoded
  /// `19.0-2` default never matched).
  ///
  /// `null` when the session route does not report it yet (an older server
  /// module) — [WebSocketConnectionManager] then falls back to
  /// [WebSocketModelRegistry.wsVersion].
  final String? websocketVersion;

  const RealtimeCredential({
    required this.ticket,
    required this.expiresAt,
    required this.sessionExpiresAt,
    this.websocketVersion,
  });

  /// Whether [sessionExpiresAt] is already in the past.
  bool get isExpired => DateTime.now().isAfter(sessionExpiresAt);

  /// SEC-01: never expose [ticket] in logs, error messages or crash
  /// reports.
  @override
  String toString() =>
      'RealtimeCredential(ticket: ${CredentialMasker.hide(ticket)}, '
      'expiresAt: $expiresAt, sessionExpiresAt: $sessionExpiresAt)';
}

/// Fetches a fresh [RealtimeCredential].
///
/// Called on EVERY connection attempt — never cached, never reused:
/// - once, right before the first connection attempt;
/// - again on every reconnection (network drop, server error, manual
///   reconnect after a server switch, a 403 from a used/expired ticket);
/// - again proactively when the previously-issued credential's
///   [RealtimeCredential.sessionExpiresAt] is reached, so the socket renews
///   itself before the server drops it.
///
/// Consumers (orbi_runtime) implement this against the project route that
/// mints a real-time-only ticket from a JSON-2 API key.
typedef RealtimeCredentialProvider = Future<RealtimeCredential> Function();
