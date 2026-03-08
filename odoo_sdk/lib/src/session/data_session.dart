/// Data session — immutable credentials and connection info for a data context.
library;

import 'package:meta/meta.dart';
import '../api/client/odoo_http_client.dart' show OdooClientConfig;
import '../utils/security_utils.dart';

/// Immutable session descriptor for a [DataContext].
///
/// Holds credentials, endpoint info, and optional metadata.
/// Use [validate] to check for configuration errors before creating a context.
///
/// ```dart
/// final session = DataSession(
///   id: 'pos-store-1',
///   label: 'POS Store 1',
///   baseUrl: 'https://odoo.example.com',
///   database: 'production',
///   apiKey: 'key_abc123',
/// );
/// ```
@immutable
class DataSession {
  /// Unique identifier for this session (used as context key).
  final String id;

  /// Human-readable label (e.g. "POS Store 1").
  final String label;

  /// Odoo server base URL (e.g. "https://odoo.example.com").
  final String baseUrl;

  /// Odoo database name.
  final String database;

  /// API key for JSON-2 authentication.
  final String apiKey;

  /// Default language code (e.g. "en_US", "es_EC").
  final String defaultLanguage;

  /// Whether to allow insecure (HTTP) connections.
  final bool allowInsecure;

  /// Arbitrary metadata attached to this session.
  final Map<String, dynamic> metadata;

  const DataSession({
    required this.id,
    required this.label,
    required this.baseUrl,
    required this.database,
    required this.apiKey,
    this.defaultLanguage = 'en_US',
    this.allowInsecure = false,
    this.metadata = const {},
  });

  /// Validate session configuration.
  ///
  /// Returns a list of error messages. Empty list means valid.
  List<String> validate() {
    final errors = <String>[];
    if (id.isEmpty) errors.add('Session id must not be empty');
    if (baseUrl.isEmpty) {
      errors.add('baseUrl must not be empty');
    } else if (!baseUrl.startsWith('http://') &&
        !baseUrl.startsWith('https://')) {
      errors.add('baseUrl must start with http:// or https://');
    }
    if (database.isEmpty) errors.add('database must not be empty');
    if (apiKey.isEmpty) errors.add('apiKey must not be empty');
    if (!allowInsecure && baseUrl.startsWith('http://')) {
      errors.add(
        'Insecure (http) connections require allowInsecure: true',
      );
    }
    return errors;
  }

  /// Convert to [OdooClientConfig] for creating an [OdooClient].
  OdooClientConfig toClientConfig() {
    return OdooClientConfig(
      baseUrl: baseUrl,
      apiKey: apiKey,
      database: database,
      defaultLanguage: defaultLanguage,
      allowInsecure: allowInsecure,
    );
  }

  /// Create a copy with modified fields.
  DataSession copyWith({
    String? id,
    String? label,
    String? baseUrl,
    String? database,
    String? apiKey,
    String? defaultLanguage,
    bool? allowInsecure,
    Map<String, dynamic>? metadata,
  }) {
    return DataSession(
      id: id ?? this.id,
      label: label ?? this.label,
      baseUrl: baseUrl ?? this.baseUrl,
      database: database ?? this.database,
      apiKey: apiKey ?? this.apiKey,
      defaultLanguage: defaultLanguage ?? this.defaultLanguage,
      allowInsecure: allowInsecure ?? this.allowInsecure,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DataSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'DataSession($id, $label, $baseUrl/$database, key: ${CredentialMasker.mask(apiKey)})';
}
