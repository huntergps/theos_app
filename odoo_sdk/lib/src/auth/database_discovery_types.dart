/// Reasons a database-listing attempt against a bare Odoo server did not
/// produce a usable list.
///
/// None of these are bugs to surface as errors: every caller must treat them
/// as an expected outcome and fall back to letting the person type the
/// database name by hand.
enum DatabaseDiscoveryFailureKind {
  /// No platform this SDK runs on actually produces this today — kept only
  /// so existing callers that switch on this enum exhaustively (e.g.
  /// `theos_panel`'s server picker) keep compiling.
  ///
  /// This used to be thrown unconditionally on Flutter web, on the
  /// assumption that a browser build is always cross-origin from the target
  /// Odoo host and therefore always CORS-blocked on `/web/database/list`.
  /// That assumption does not hold: CORS only restricts *cross-origin*
  /// requests, and Odoo does not declare a CORS policy on this controller
  /// either way (measured against a real server, and no addon in this
  /// project overrides it — that is unrelated to whether the JSON-2 data
  /// interface allows cross-origin calls on some server, which depends
  /// entirely on that installation's addons; see the `X-Odoo-Database`
  /// header comment in `odoo_http_client.dart`). A browser build served
  /// from the SAME origin as the Odoo host — the deployment
  /// `docs/orbi_panel/decisions/W01-web-auth.md` recommends — is not
  /// cross-origin at all and the call succeeds like any other client's.
  /// Web now actually attempts the request (see `database_discovery.dart`);
  /// a genuinely cross-origin, unsupported deployment surfaces as
  /// [connection], not this.
  unsupportedPlatform,

  /// The server reachable, but the deployment turned listing off on
  /// purpose (`--no-database-list` / `list_db=False`). Common in production.
  disabled,

  /// The request could not complete: the server is unreachable, the URL is
  /// wrong, DNS failed, the connection timed out, etc.
  connection,

  /// The server answered but not with the shape this client understands.
  protocol,
}

/// Thrown by [OdooDatabaseDiscovery.listDatabases] when the databases
/// exposed by a server cannot be discovered.
///
/// This is deliberately a normal, expected exception type — not a signal
/// that something is broken. Every caller must catch it and fall back to
/// manual database entry; never present it as a dead end.
final class DatabaseDiscoveryException implements Exception {
  const DatabaseDiscoveryException(this.kind, {this.message});

  final DatabaseDiscoveryFailureKind kind;

  /// Optional detail from the server, for logs only — never shown verbatim
  /// to the end user, and never containing credentials (this call carries
  /// none).
  final String? message;

  @override
  String toString() => 'DatabaseDiscoveryException(${kind.name})';
}
