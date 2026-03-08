/// Result type for related field resolution (Many2one, Many2many)
///
/// Used when resolving related fields following the flow:
/// Local Cache -> Remote (if online) -> Fallback [id, name]
library;

/// Result of a related field resolution
///
/// Contains the resolved record data or fallback information.
/// Tracks where the data came from (cache vs remote).
class RelatedFieldResult {
  /// Full record data from cache or remote
  final Map<String, dynamic>? record;

  /// ID of the related record
  final int? id;

  /// Fallback name from the original Many2one [id, name] tuple
  final String? fallbackName;

  /// Whether the data came from local cache
  final bool fromCache;

  /// Whether the data came from remote API
  final bool fromRemote;

  const RelatedFieldResult({
    this.record,
    this.id,
    this.fallbackName,
    this.fromCache = false,
    this.fromRemote = false,
  });

  /// Creates an empty result (no data found)
  const RelatedFieldResult.empty()
      : record = null,
        id = null,
        fallbackName = null,
        fromCache = false,
        fromRemote = false;

  /// Creates a result from fallback only
  const RelatedFieldResult.fallback({
    required this.id,
    required this.fallbackName,
  })  : record = null,
        fromCache = false,
        fromRemote = false;

  /// Whether we have the full record data
  bool get hasFullRecord => record != null;

  /// Whether we only have fallback [id, name] data
  bool get hasFallbackOnly =>
      record == null && (id != null || fallbackName != null);

  /// Whether we have any data at all
  bool get hasData => hasFullRecord || hasFallbackOnly;

  /// Display name: uses record if exists, otherwise fallback
  String get displayName {
    if (record != null) {
      return record!['display_name'] as String? ??
          record!['name'] as String? ??
          fallbackName ??
          (id != null ? 'ID: $id' : '');
    }
    return fallbackName ?? (id != null ? 'ID: $id' : '');
  }

  /// Direct access to name field
  String? get name => record?['name'] as String? ?? fallbackName;

  /// Access any field from the record
  dynamic operator [](String key) => record?[key];

  /// Get a typed value from the record
  T? get<T>(String key) => record?[key] as T?;

  @override
  String toString() {
    if (hasFullRecord) {
      return 'RelatedFieldResult(record: $displayName, fromCache: $fromCache, fromRemote: $fromRemote)';
    }
    if (hasFallbackOnly) {
      return 'RelatedFieldResult(fallback: $fallbackName, id: $id)';
    }
    return 'RelatedFieldResult.empty()';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RelatedFieldResult &&
        other.id == id &&
        other.fallbackName == fallbackName &&
        other.fromCache == fromCache &&
        other.fromRemote == fromRemote;
  }

  @override
  int get hashCode => Object.hash(id, fallbackName, fromCache, fromRemote);
}
