/// Reasons a database-listing attempt against a bare Odoo server did not
/// produce a usable list.
///
/// None of these are bugs to surface as errors: every caller must treat them
/// as an expected outcome and fall back to letting the person type the
/// database name by hand.
enum DatabaseDiscoveryFailureKind {
  /// The current platform cannot reach `/web/database/list` at all.
  ///
  /// Browser builds hit this unconditionally: Odoo does not declare a CORS
  /// policy on that controller (measured against a real server — unlike the
  /// JSON-2 data interface, which explicitly allows any origin), so the
  /// browser blocks the cross-origin request before it reaches the server.
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
