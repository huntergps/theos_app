/// Utility class for parsing Odoo API responses.
///
/// Provides static methods to safely extract typed values from Odoo's
/// dynamic JSON responses, handling the various formats Odoo uses
/// (Many2one as [id, name], false for null, etc.)
class OdooResponseParser {
  OdooResponseParser._(); // Private constructor - static only

  /// Parse Many2one field from Odoo response.
  ///
  /// Odoo Many2one fields are returned as:
  /// - `[id, name]` tuple when set
  /// - `false` when not set
  /// - `null` in some contexts
  ///
  /// Returns the ID portion, or null if not set.
  static int? parseMany2oneId(dynamic value) {
    if (value == null || value == false) return null;
    if (value is List && value.isNotEmpty) return value[0] as int;
    if (value is int) return value;
    return null;
  }

  /// Parse Many2one name from Odoo response.
  ///
  /// Returns the name portion of a Many2one field, or null if not set.
  static String? parseMany2oneName(dynamic value) {
    if (value == null || value == false) return null;
    if (value is List && value.length > 1) return value[1] as String;
    return null;
  }

  /// Parse boolean from Odoo response.
  ///
  /// Odoo often returns `false` instead of `null` for unset values,
  /// which can be ambiguous for boolean fields.
  static bool parseBool(dynamic value) {
    if (value == null || value == false) return false;
    if (value is bool) return value;
    return false;
  }

  /// Parse string from Odoo response.
  ///
  /// Returns empty string for null/false values.
  static String parseString(dynamic value) {
    if (value == null || value == false) return '';
    return value.toString();
  }

  /// Parse integer from Odoo response.
  ///
  /// Returns null for null/false values.
  static int? parseInt(dynamic value) {
    if (value == null || value == false) return null;
    if (value is int) return value;
    if (value is double) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  /// Parse double from Odoo response.
  ///
  /// Returns null for null/false values.
  static double? parseDouble(dynamic value) {
    if (value == null || value == false) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Parse Many2many/One2many field from Odoo response.
  ///
  /// These fields are returned as lists of IDs.
  static List<int> parseMany2manyIds(dynamic value) {
    if (value == null || value == false) return [];
    if (value is List) {
      return value.whereType<int>().toList();
    }
    return [];
  }

  /// Check if a value represents "not set" in Odoo.
  ///
  /// Odoo uses `false` instead of `null` for many unset values.
  static bool isNotSet(dynamic value) {
    return value == null || value == false;
  }

  /// Extract ID from various Odoo field formats.
  ///
  /// Handles: int, [id, name], Map with 'id' key
  static int? extractId(dynamic value) {
    if (value == null || value == false) return null;
    if (value is int) return value;
    if (value is List && value.isNotEmpty) return value[0] as int?;
    if (value is Map && value.containsKey('id')) return value['id'] as int?;
    return null;
  }
}
