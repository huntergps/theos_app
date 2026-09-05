import 'dart:convert';

/// Identifies the local data owned by one authenticated Odoo user.
///
/// The scope deliberately excludes API keys, session IDs and access tokens so
/// it is safe to use in database names, provider keys and diagnostic output.
final class SessionScope {
  static const String _driftDatabasePrefix = 'theos_pos_';

  SessionScope({
    required String serverUrl,
    required String database,
    required this.userId,
  }) : serverUrl = _normalizeServerUrl(serverUrl),
       database = database.trim() {
    if (this.database.isEmpty) {
      throw ArgumentError.value(database, 'database', 'Must not be empty');
    }
    if (userId <= 0) {
      throw ArgumentError.value(userId, 'userId', 'Must be positive');
    }
  }

  /// Canonical server origin/base path, without credentials, query or fragment.
  final String serverUrl;

  /// Odoo database name.
  final String database;

  /// Authenticated Odoo user ID.
  final int userId;

  /// Stable non-secret key for maps and secure-storage key prefixes.
  String get key => '$serverUrl|$database|$userId';

  /// Canonical Drift database name owned by this authenticated scope.
  ///
  /// This value contains only the normalized server, database and user ID
  /// represented by [storageIdentifier]. Credentials never participate in it.
  String get driftDatabaseName => '$_driftDatabasePrefix$storageIdentifier';

  /// Filesystem-safe identifier with a stable suffix to avoid sanitization
  /// collisions between otherwise distinct scopes.
  String get storageIdentifier {
    final uri = Uri.parse(serverUrl);
    final port = uri.hasPort ? '_${uri.port}' : '';
    final readable = '${uri.host}${port}_${database}_u$userId'
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_|_$'), '');
    final prefix = readable.length <= 72 ? readable : readable.substring(0, 72);
    return '${prefix}_${_fnv1a64(key)}';
  }

  static String _normalizeServerUrl(String value) {
    final trimmed = value.trim();
    final parsed = Uri.tryParse(trimmed);
    if (parsed == null ||
        !parsed.hasScheme ||
        !parsed.hasAuthority ||
        (parsed.scheme.toLowerCase() != 'http' &&
            parsed.scheme.toLowerCase() != 'https')) {
      throw ArgumentError.value(value, 'serverUrl', 'Must be an HTTP(S) URL');
    }
    if (parsed.userInfo.isNotEmpty ||
        parsed.query.isNotEmpty ||
        parsed.hasFragment) {
      throw ArgumentError.value(
        value,
        'serverUrl',
        'Credentials, query and fragment are not allowed',
      );
    }

    var path = parsed.path;
    while (path.length > 1 && path.endsWith('/')) {
      path = path.substring(0, path.length - 1);
    }
    if (path == '/') path = '';

    final scheme = parsed.scheme.toLowerCase();
    final isDefaultPort =
        (scheme == 'http' && parsed.port == 80) ||
        (scheme == 'https' && parsed.port == 443);
    return Uri(
      scheme: scheme,
      host: parsed.host.toLowerCase(),
      port: parsed.hasPort && !isDefaultPort ? parsed.port : null,
      path: path,
    ).toString();
  }

  static String _fnv1a64(String value) {
    final offsetBasis = BigInt.parse('cbf29ce484222325', radix: 16);
    final prime = BigInt.parse('100000001b3', radix: 16);
    final mask = BigInt.parse('ffffffffffffffff', radix: 16);
    var hash = offsetBasis;
    for (final byte in utf8.encode(value)) {
      hash ^= BigInt.from(byte);
      hash = (hash * prime) & mask;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SessionScope &&
          other.serverUrl == serverUrl &&
          other.database == database &&
          other.userId == userId;

  @override
  int get hashCode => Object.hash(serverUrl, database, userId);

  @override
  String toString() => 'SessionScope($serverUrl/$database, user: $userId)';
}
