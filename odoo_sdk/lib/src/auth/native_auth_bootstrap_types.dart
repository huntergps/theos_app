/// Result of exchanging an interactive Odoo login for a short-lived RPC key.
final class NativeAuthBootstrapResult {
  const NativeAuthBootstrapResult({required this.userId, required this.apiKey});

  final int userId;
  final String apiKey;
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
