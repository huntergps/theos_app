/// Result of a session authentication attempt
class OdooSessionResult {
  final String sessionId;
  final int uid;
  final int? partnerId;
  final Map<String, dynamic>? extra;

  const OdooSessionResult({
    required this.sessionId,
    required this.uid,
    this.partnerId,
    this.extra,
  });

  factory OdooSessionResult.fromMap(Map<String, dynamic> data) {
    return OdooSessionResult(
      sessionId: data['session_id'] as String,
      uid: data['uid'] as int,
      partnerId: data['partner_id'] as int?,
      extra: data,
    );
  }

  Map<String, dynamic> toMap() => {
    'session_id': sessionId,
    'uid': uid,
    if (partnerId != null) 'partner_id': partnerId,
    ...?extra,
  };

  /// SEC-01: Secure string representation that masks session ID.
  ///
  /// Session IDs are masked to prevent accidental exposure
  /// in logs, error messages, or stack traces.
  @override
  String toString() {
    final maskedSessionId = sessionId.length <= 4
        ? '*' * sessionId.length
        : '${sessionId.substring(0, 2)}${'*' * (sessionId.length - 4)}${sessionId.substring(sessionId.length - 2)}';
    return 'OdooSessionResult(sessionId: $maskedSessionId, uid: $uid, partnerId: $partnerId)';
  }
}

/// Abstract strategy for Odoo session authentication
///
/// Different authentication methods for different platforms/scenarios:
/// - Mobile: Uses custom mobile_get_websocket_session endpoint
/// - Web: Uses /web/session/authenticate with cookies
/// - API Key: Bearer token authentication (no session needed)
abstract class OdooAuthStrategy {
  /// Name of this authentication strategy (for logging)
  String get name;

  /// Attempt to authenticate and obtain a session
  ///
  /// Returns [OdooSessionResult] on success, null on failure.
  Future<OdooSessionResult?> authenticate();

  /// Whether this strategy can be used with current configuration
  bool get isAvailable;
}
