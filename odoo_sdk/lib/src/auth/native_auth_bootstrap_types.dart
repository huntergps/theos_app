/// Result of exchanging an interactive Odoo login for a short-lived RPC key.
final class NativeAuthBootstrapResult {
  const NativeAuthBootstrapResult({
    required this.userId,
    required this.apiKey,
    this.apiKeyId,
    this.expiresAt,
  });

  final int userId;
  final String apiKey;

  /// The `res.users.apikeys` record id backing [apiKey], resolved right
  /// after creation so a caller that fails to persist [apiKey] locally can
  /// pass it to [NativeOdooAuthBootstrap.revokeApiKey] and avoid leaving an
  /// orphaned credential on the server. `null` only when that best-effort
  /// lookup itself failed to find the record — the login already succeeded
  /// and is never rolled back because of it, but revocation is then not
  /// possible and the caller must decide how to surface that.
  final int? apiKeyId;

  /// When [apiKey] stops working, computed from the wizard's own `duration`
  /// selection (in days) at the moment it was minted — the native wizard
  /// never returns an expiry timestamp directly. `null` only if that
  /// computation could not be made; a caller that cannot learn this never
  /// renews the key proactively, it only relies on the reactive 401 path.
  final DateTime? expiresAt;
}

enum NativeAuthBootstrapFailureKind {
  unsupportedPlatform,
  insecureTransport,
  invalidCredentials,
  additionalVerificationRequired,
  accessDenied,
  protocol,
  connection,
}

/// Deliberately contains no server payload or submitted credential.
final class NativeAuthBootstrapException implements Exception {
  const NativeAuthBootstrapException(this.kind, {this.authMethods = const []});

  final NativeAuthBootstrapFailureKind kind;
  final List<String> authMethods;

  @override
  String toString() => 'NativeAuthBootstrapException(${kind.name})';
}

/// Thrown by [NativeOdooAuthBootstrap.revokeApiKey] when the best-effort
/// cleanup of an already-issued API key does not succeed.
///
/// A caller that revokes a key because some *other* step failed (typically
/// persisting it locally) MUST catch this separately from that original
/// failure: a cleanup error must never replace or hide the error that
/// triggered the cleanup in the first place.
final class NativeAuthBootstrapRevocationException implements Exception {
  const NativeAuthBootstrapRevocationException(this.message);

  final String message;

  @override
  String toString() => 'NativeAuthBootstrapRevocationException($message)';
}
