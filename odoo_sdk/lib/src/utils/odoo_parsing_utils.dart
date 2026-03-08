/// Utility functions for parsing Odoo API responses.
///
/// Handles the various data formats returned by Odoo:
/// - Many2one: [id, name] or false
/// - Many2many/One2many: [id, id, ...] or []
/// - Dates: "YYYY-MM-DD HH:MM:SS" or "YYYY-MM-DD"
/// - Booleans: true/false (not 1/0)
library;

import 'dart:convert';

// ============================================================================
// MANY2ONE EXTRACTION
// ============================================================================

/// Extract ID from a Many2one field.
///
/// Many2one fields return either:
/// - [id, name] tuple when set
/// - false when not set
///
/// Example:
/// ```dart
/// final partnerId = extractMany2oneId(data['partner_id']); // 42 or null
/// ```
int? extractMany2oneId(dynamic value) {
  if (value == null || value == false) return null;
  if (value is int) return value;
  if (value is List && value.isNotEmpty) {
    return value[0] as int?;
  }
  return null;
}

/// Extract display name from a Many2one field.
///
/// Many2one fields return either:
/// - [id, name] tuple when set
/// - false when not set
///
/// Example:
/// ```dart
/// final partnerName = extractMany2oneName(data['partner_id']); // "John Doe" or null
/// ```
String? extractMany2oneName(dynamic value) {
  if (value == null || value == false) return null;
  if (value is List && value.length >= 2) {
    return value[1]?.toString();
  }
  return null;
}

/// Extract both ID and name from a Many2one field.
///
/// Returns a record with both values for convenience.
///
/// Example:
/// ```dart
/// final (id, name) = extractMany2one(data['partner_id']);
/// ```
(int?, String?) extractMany2one(dynamic value) {
  return (extractMany2oneId(value), extractMany2oneName(value));
}

// ============================================================================
// MANY2MANY / ONE2MANY EXTRACTION
// ============================================================================

/// Extract list of IDs from a Many2many or One2many field.
///
/// Handles both [id1, id2, ...] and [[id1, name1], [id2, name2], ...] formats.
///
/// Example:
/// ```dart
/// final tagIds = extractMany2manyIds(data['tag_ids']); // [1, 2, 3]
/// ```
List<int> extractMany2manyIds(dynamic value) {
  if (value == null || value == false) return [];
  if (value is List) {
    final ids = <int>[];
    for (final item in value) {
      if (item is int) {
        ids.add(item);
      } else if (item is List && item.isNotEmpty && item[0] is int) {
        ids.add(item[0] as int);
      }
    }
    return ids;
  }
  return [];
}

/// Extract IDs from a Many2many field and returns as comma-separated string.
///
/// Example:
/// ```dart
/// final ids = extractMany2manyIdsAsString(data['tag_ids']); // "1,2,3"
/// ```
String? extractMany2manyIdsAsString(dynamic value) {
  final ids = extractMany2manyIds(value);
  if (ids.isEmpty) return null;
  return ids.join(',');
}

/// Extracts and encodes Many2many IDs to a JSON string.
///
/// Handles both [id1, id2, ...] and [[id1, name1], [id2, name2], ...] formats.
/// Returns null if no valid IDs found.
String? extractMany2manyToJson(dynamic value) {
  final ids = extractMany2manyIds(value);
  if (ids.isEmpty) return null;
  return '[${ids.join(',')}]';
}

/// Encodes a list of integers to a JSON string.
///
/// Used for storing Many2many IDs in SQLite as a JSON array.
/// Returns null if the list is empty or contains no integers.
String? encodeIntListToJson(List<dynamic>? value) {
  if (value == null || value.isEmpty) return null;
  final ids = value.whereType<int>().toList();
  if (ids.isEmpty) return null;
  return '[${ids.join(',')}]';
}

// ============================================================================
// DATETIME PARSING
// ============================================================================

/// Parse a DateTime from Odoo format.
///
/// Odoo returns datetimes as "YYYY-MM-DD HH:MM:SS" strings in UTC.
///
/// Example:
/// ```dart
/// final date = parseOdooDateTime(data['create_date']);
/// ```
DateTime? parseOdooDateTime(dynamic value) {
  if (value == null || value == false) return null;
  if (value is DateTime) return value;
  if (value is String) {
    try {
      // Odoo sends dates in UTC without 'Z' suffix
      if (!value.endsWith('Z') && !value.contains('+')) {
        // Handle datetime format: "YYYY-MM-DD HH:MM:SS"
        if (value.contains(' ')) {
          return DateTime.tryParse('${value.replaceFirst(' ', 'T')}Z');
        }
        // Handle date-only format: "YYYY-MM-DD" (add T00:00:00Z for valid ISO)
        if (value.length == 10 && value.contains('-')) {
          return DateTime.tryParse('${value}T00:00:00Z');
        }
        return DateTime.tryParse('${value}Z');
      }
      return DateTime.tryParse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Parse a Date (without time) from Odoo format.
///
/// Odoo returns dates as "YYYY-MM-DD" strings.
/// Returns DateTime at midnight.
///
/// Example:
/// ```dart
/// final date = parseOdooDate(data['date_order']);
/// ```
DateTime? parseOdooDate(dynamic value) {
  if (value == null || value == false) return null;
  if (value is DateTime) return DateTime(value.year, value.month, value.day);
  if (value is String) {
    try {
      final parts = value.split('-');
      if (parts.length >= 3) {
        return DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2].split(' ')[0].split('T')[0]),
        );
      }
      return DateTime.tryParse(value);
    } catch (_) {
      return null;
    }
  }
  return null;
}

/// Format a DateTime for Odoo API (datetime field).
///
/// Converts to "YYYY-MM-DD HH:MM:SS" format expected by Odoo.
///
/// Example:
/// ```dart
/// final odooDate = formatOdooDateTime(DateTime.now());
/// ```
String? formatOdooDateTime(DateTime? value) {
  if (value == null) return null;
  final utc = value.toUtc();
  return '${utc.year.toString().padLeft(4, '0')}-'
      '${utc.month.toString().padLeft(2, '0')}-'
      '${utc.day.toString().padLeft(2, '0')} '
      '${utc.hour.toString().padLeft(2, '0')}:'
      '${utc.minute.toString().padLeft(2, '0')}:'
      '${utc.second.toString().padLeft(2, '0')}';
}

/// Format a Date for Odoo API (date field).
///
/// Converts to "YYYY-MM-DD" format expected by Odoo.
///
/// Example:
/// ```dart
/// final odooDate = formatOdooDate(DateTime.now());
/// ```
String? formatOdooDate(DateTime? value) {
  if (value == null) return null;
  return '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

// ============================================================================
// TYPE CONVERSIONS
// ============================================================================

/// Parse a boolean from Odoo response.
///
/// Odoo uses Python's True/False which map to JSON true/false.
/// This function also handles potential edge cases.
///
/// Example:
/// ```dart
/// final active = parseOdooBool(data['active']); // true/false
/// ```
bool parseOdooBool(dynamic value, {bool defaultValue = false}) {
  if (value == null) return defaultValue;
  if (value is bool) return value;
  if (value is int) return value != 0;
  if (value is String) {
    return value.toLowerCase() == 'true' || value == '1';
  }
  return defaultValue;
}

/// Parse a double from Odoo response.
///
/// Odoo returns floats as JSON numbers, but this handles edge cases.
///
/// Example:
/// ```dart
/// final price = parseOdooDouble(data['list_price']); // 19.99
/// ```
double parseOdooDouble(dynamic value, {double defaultValue = 0.0}) {
  if (value == null || value == false) return defaultValue;
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) {
    return double.tryParse(value) ?? defaultValue;
  }
  return defaultValue;
}

/// Parse an integer from Odoo response.
///
/// Example:
/// ```dart
/// final quantity = parseOdooInt(data['product_uom_qty']); // 5
/// ```
int parseOdooInt(dynamic value, {int defaultValue = 0}) {
  if (value == null || value == false) return defaultValue;
  if (value is int) return value;
  if (value is double) return value.toInt();
  if (value is String) {
    return int.tryParse(value) ?? defaultValue;
  }
  return defaultValue;
}

/// Parse a string from Odoo response.
///
/// Handles the case where Odoo returns false for empty strings.
///
/// Example:
/// ```dart
/// final name = parseOdooString(data['name']); // "Product A" or null
/// ```
String? parseOdooString(dynamic value) {
  if (value == null || value == false) return null;
  if (value is String) return value.isEmpty ? null : value;
  return value.toString();
}

/// Parse a required string (never null).
String parseOdooStringRequired(dynamic value, {String defaultValue = ''}) {
  return parseOdooString(value) ?? defaultValue;
}

/// Extracts an integer value from various input types.
///
/// Handles: int, List (Many2one), String
int? extractInt(dynamic value) {
  if (value == null || value == false) return null;
  if (value is int) return value;
  if (value is List && value.isNotEmpty) return value[0] as int;
  if (value is String) return int.tryParse(value);
  return null;
}

/// Parse JSON/Map from Odoo response.
///
/// Example:
/// ```dart
/// final metadata = parseOdooJson(data['metadata']);
/// ```
Map<String, dynamic>? parseOdooJson(dynamic value) {
  if (value == null || value == false) return null;
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return value.map((k, v) => MapEntry(k.toString(), v));
  }
  if (value is String) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
    } catch (_) {
      // Not valid JSON
    }
  }
  return null;
}

/// Convert a value to a JSON string for storage.
///
/// Handles Map, List, and String inputs. Returns null for null input.
String? toJsonString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is Map || value is List) {
    return jsonEncode(value);
  }
  return value.toString();
}

/// Parse a selection value from Odoo response.
///
/// Selection fields return the value key as a string.
///
/// Example:
/// ```dart
/// final state = parseOdooSelection(data['state']); // "draft"
/// ```
String? parseOdooSelection(dynamic value) {
  return parseOdooString(value);
}

// ============================================================================
// CASE CONVERSION
// ============================================================================

/// Converts a camelCase string to snake_case.
///
/// Used for mapping Dart model fields to SQLite/Odoo column names.
/// Example: 'partnerId' -> 'partner_id'
String toSnakeCase(String input) {
  return input.replaceAllMapped(
    RegExp(r'[A-Z]'),
    (match) => '_${match.group(0)!.toLowerCase()}',
  );
}

/// Converts a snake_case string to camelCase.
///
/// Used for mapping SQLite/Odoo column names to Dart model fields.
/// Example: 'partner_id' -> 'partnerId'
String toCamelCase(String input) {
  return input.replaceAllMapped(
    RegExp(r'_([a-z])'),
    (match) => match.group(1)!.toUpperCase(),
  );
}

// ============================================================================
// ODOO VALUE BUILDING (for API calls)
// ============================================================================

/// Convert a Dart value to Odoo format for API calls.
///
/// Handles the reverse conversion of all types.
dynamic toOdooValue(dynamic value) {
  if (value == null) return false;
  if (value is DateTime) return formatOdooDateTime(value);
  if (value is List<int>) return value; // Many2many IDs
  return value;
}

/// Build a Many2one command for create/write.
///
/// Returns the ID or false for clearing the field.
dynamic buildMany2oneValue(int? id) {
  return id ?? false;
}

/// Build Many2many commands for create/write.
///
/// Odoo uses special command format:
/// - (6, 0, [ids]) - Replace all with these IDs
/// - (4, id) - Add ID to set
/// - (3, id) - Remove ID from set
/// - (5,) - Clear all
///
/// Example:
/// ```dart
/// final command = buildMany2manyReplace([1, 2, 3]); // [[6, 0, [1, 2, 3]]]
/// ```
List<List<dynamic>> buildMany2manyReplace(List<int> ids) {
  return [
    [6, 0, ids]
  ];
}

/// Build command to add IDs to Many2many.
List<List<dynamic>> buildMany2manyAdd(List<int> ids) {
  return ids.map((id) => [4, id, 0]).toList();
}

/// Build command to remove IDs from Many2many.
List<List<dynamic>> buildMany2manyRemove(List<int> ids) {
  return ids.map((id) => [3, id, 0]).toList();
}

/// Build command to clear Many2many.
List<List<dynamic>> buildMany2manyClear() {
  return [
    [5, 0, 0]
  ];
}

/// Build One2many commands for create/write.
///
/// Odoo uses special command format:
/// - (0, 0, values) - Create new record
/// - (1, id, values) - Update existing record
/// - (2, id) - Delete record
/// - (3, id) - Unlink record (remove from set)
/// - (4, id) - Link existing record
/// - (5,) - Clear all
/// - (6, 0, [ids]) - Replace all with existing records
///
/// Example:
/// ```dart
/// final command = buildOne2manyCreate({'name': 'Line 1'});
/// ```
List<dynamic> buildOne2manyCreate(Map<String, dynamic> values) {
  return [0, 0, values];
}

List<dynamic> buildOne2manyUpdate(int id, Map<String, dynamic> values) {
  return [1, id, values];
}

List<dynamic> buildOne2manyDelete(int id) {
  return [2, id, 0];
}

List<dynamic> buildOne2manyUnlink(int id) {
  return [3, id, 0];
}

List<dynamic> buildOne2manyLink(int id) {
  return [4, id, 0];
}

/// Convert a value to String, returning null for null or false.
///
/// Useful for Odoo fields that return false instead of null.
String? toStringOrNull(dynamic value) {
  if (value == null || value == false) return null;
  return value.toString();
}
