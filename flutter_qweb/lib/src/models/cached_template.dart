/// Cached Template Model
///
/// Represents a QWeb template cached locally for offline PDF generation.
/// Contains the template XML, metadata, and sync information.
library;

/// Data class for cached QWeb templates
class CachedTemplate {
  /// Odoo template key (e.g., 'sale.report_saleorder_document')
  final String templateKey;

  /// Odoo record ID (ir.ui.view id)
  final int odooId;

  /// Human-readable template name
  final String? name;

  /// Odoo model this template renders (e.g., 'sale.order')
  final String? model;

  /// Fully consolidated XML content with all inheritance applied
  final String xmlContent;

  /// List of fields required to render this template
  final List<String> requiredFields;

  /// List of template dependencies (t-call references)
  final List<String> dependencies;

  /// When this template was last synced from Odoo
  final DateTime lastSynced;

  /// MD5 checksum for detecting changes
  final String checksum;

  const CachedTemplate({
    required this.templateKey,
    required this.odooId,
    this.name,
    this.model,
    required this.xmlContent,
    required this.requiredFields,
    required this.dependencies,
    required this.lastSynced,
    required this.checksum,
  });

  /// Create from JSON (e.g., from SQLite or API response)
  factory CachedTemplate.fromJson(Map<String, dynamic> json) {
    return CachedTemplate(
      templateKey: json['templateKey'] as String? ?? json['key'] as String,
      odooId: json['odooId'] as int? ?? json['id'] as int? ?? 0,
      name: json['name'] as String?,
      model: json['model'] as String?,
      xmlContent:
          json['xmlContent'] as String? ?? json['xml_content'] as String? ?? '',
      requiredFields:
          _parseStringList(json['requiredFields'] ?? json['required_fields']),
      dependencies: _parseStringList(json['dependencies']),
      lastSynced: json['lastSynced'] != null
          ? DateTime.parse(json['lastSynced'] as String)
          : DateTime.now(),
      checksum: json['checksum'] as String? ?? '',
    );
  }

  /// Create from Odoo API response
  factory CachedTemplate.fromOdoo(Map<String, dynamic> data) {
    return CachedTemplate(
      templateKey: data['key'] as String? ?? '',
      odooId: data['id'] as int? ?? 0,
      name: data['name'] as String?,
      model: data['model'] as String?,
      xmlContent: data['xml_content'] as String? ?? '',
      requiredFields: _parseStringList(data['required_fields']),
      dependencies: _parseStringList(data['dependencies']),
      lastSynced: DateTime.now(),
      checksum: data['checksum'] as String? ?? '',
    );
  }

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() => {
        'templateKey': templateKey,
        'odooId': odooId,
        'name': name,
        'model': model,
        'xmlContent': xmlContent,
        'requiredFields': requiredFields,
        'dependencies': dependencies,
        'lastSynced': lastSynced.toIso8601String(),
        'checksum': checksum,
      };

  /// Whether this template is stale (older than specified duration)
  bool isStale({Duration maxAge = const Duration(days: 7)}) {
    return DateTime.now().difference(lastSynced) > maxAge;
  }

  /// Create a copy with updated fields
  CachedTemplate copyWith({
    String? templateKey,
    int? odooId,
    String? name,
    String? model,
    String? xmlContent,
    List<String>? requiredFields,
    List<String>? dependencies,
    DateTime? lastSynced,
    String? checksum,
  }) {
    return CachedTemplate(
      templateKey: templateKey ?? this.templateKey,
      odooId: odooId ?? this.odooId,
      name: name ?? this.name,
      model: model ?? this.model,
      xmlContent: xmlContent ?? this.xmlContent,
      requiredFields: requiredFields ?? this.requiredFields,
      dependencies: dependencies ?? this.dependencies,
      lastSynced: lastSynced ?? this.lastSynced,
      checksum: checksum ?? this.checksum,
    );
  }

  static List<String> _parseStringList(dynamic value) {
    if (value == null) return [];
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  @override
  String toString() => 'CachedTemplate($templateKey, model: $model)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CachedTemplate &&
          runtimeType == other.runtimeType &&
          templateKey == other.templateKey &&
          checksum == other.checksum;

  @override
  int get hashCode => templateKey.hashCode ^ checksum.hashCode;
}
