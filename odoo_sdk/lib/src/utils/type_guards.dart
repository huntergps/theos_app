/// Type-safe casting utilities for Odoo Model Manager.
///
/// Provides safe type conversion methods that handle invalid data gracefully
/// instead of throwing exceptions on type mismatches.
library;

/// Safe generic type cast.
///
/// Returns the value cast to type T if it matches, otherwise null.
///
/// Example:
/// ```dart
/// final data = {'name': 'test', 'count': 42};
/// final name = safeCast<String>(data['name']); // 'test'
/// final count = safeCast<String>(data['count']); // null (int, not String)
/// ```
T? safeCast<T>(dynamic value) => value is T ? value : null;

/// Safe integer extraction.
///
/// Handles:
/// - int values directly
/// - String values via int.tryParse
/// - double values via truncation
/// - null values
///
/// Example:
/// ```dart
/// safeInt(42);        // 42
/// safeInt('42');      // 42
/// safeInt(42.7);      // 42
/// safeInt('invalid'); // null
/// safeInt(null);      // null
/// ```
int? safeInt(dynamic value) {
  if (value is int) return value;
  if (value is String) return int.tryParse(value);
  if (value is double) return value.toInt();
  return null;
}

/// Safe double extraction.
///
/// Handles:
/// - double values directly
/// - int values via conversion
/// - String values via double.tryParse
/// - null values
///
/// Example:
/// ```dart
/// safeDouble(42.5);      // 42.5
/// safeDouble(42);        // 42.0
/// safeDouble('42.5');    // 42.5
/// safeDouble('invalid'); // null
/// safeDouble(null);      // null
/// ```
double? safeDouble(dynamic value) {
  if (value is double) return value;
  if (value is int) return value.toDouble();
  if (value is String) return double.tryParse(value);
  return null;
}

/// Safe string extraction.
///
/// Handles:
/// - String values directly
/// - Other values via toString() (optional)
/// - null values
///
/// Example:
/// ```dart
/// safeString('test');           // 'test'
/// safeString(42);               // null (strict mode)
/// safeString(42, convert: true); // '42'
/// safeString(null);             // null
/// ```
String? safeString(dynamic value, {bool convert = false}) {
  if (value is String) return value;
  if (convert && value != null) return value.toString();
  return null;
}

/// Safe boolean extraction.
///
/// Handles:
/// - bool values directly
/// - String 'true'/'false' (case insensitive)
/// - int 1/0
/// - null values
///
/// Example:
/// ```dart
/// safeBool(true);     // true
/// safeBool('true');   // true
/// safeBool('TRUE');   // true
/// safeBool(1);        // true
/// safeBool(0);        // false
/// safeBool('invalid'); // null
/// safeBool(null);     // null
/// ```
bool? safeBool(dynamic value) {
  if (value is bool) return value;
  if (value is String) {
    final lower = value.toLowerCase();
    if (lower == 'true') return true;
    if (lower == 'false') return false;
  }
  if (value is int) {
    if (value == 1) return true;
    if (value == 0) return false;
  }
  return null;
}

/// Safe map extraction.
///
/// Returns the value as Map<String, dynamic> if it matches, otherwise null.
///
/// Example:
/// ```dart
/// safeMap({'key': 'value'});  // {'key': 'value'}
/// safeMap([1, 2, 3]);         // null
/// safeMap('not a map');       // null
/// safeMap(null);              // null
/// ```
Map<String, dynamic>? safeMap(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    // Try to cast keys to strings
    try {
      return Map<String, dynamic>.from(value);
    } on TypeError {
      return null;
    }
  }
  return null;
}

/// Safe list extraction.
///
/// Returns the value as List if it matches, otherwise null.
///
/// Example:
/// ```dart
/// safeList([1, 2, 3]);       // [1, 2, 3]
/// safeList({'key': 'value'}); // null
/// safeList('not a list');    // null
/// safeList(null);            // null
/// ```
List<dynamic>? safeList(dynamic value) {
  if (value is List) return value;
  return null;
}

/// Safe typed list extraction.
///
/// Returns a list with all elements cast to type T.
/// Elements that don't match type T are filtered out.
///
/// Example:
/// ```dart
/// safeListOf<int>([1, 2, 'skip', 3]);   // [1, 2, 3]
/// safeListOf<String>([1, 'a', 2, 'b']); // ['a', 'b']
/// safeListOf<int>('not a list');        // null
/// ```
List<T>? safeListOf<T>(dynamic value) {
  if (value is! List) return null;
  return value.whereType<T>().toList();
}

/// Safe list of integers extraction.
///
/// Extracts all valid integers from a list, converting strings if possible.
///
/// Example:
/// ```dart
/// safeIntList([1, 2, '3', 'invalid', 4]);  // [1, 2, 3, 4]
/// safeIntList('not a list');               // null
/// ```
List<int>? safeIntList(dynamic value) {
  if (value is! List) return null;
  final result = <int>[];
  for (final item in value) {
    final intValue = safeInt(item);
    if (intValue != null) {
      result.add(intValue);
    }
  }
  return result;
}

/// Safe DateTime extraction from various formats.
///
/// Handles:
/// - DateTime objects directly
/// - ISO 8601 strings
/// - Odoo datetime strings ('YYYY-MM-DD HH:MM:SS')
/// - Unix timestamps (int, in seconds)
/// - null values
///
/// Example:
/// ```dart
/// safeDateTime(DateTime.now());              // DateTime
/// safeDateTime('2024-01-15T10:30:00Z');      // DateTime
/// safeDateTime('2024-01-15 10:30:00');       // DateTime
/// safeDateTime(1705312200);                  // DateTime (from timestamp)
/// safeDateTime('invalid');                   // null
/// safeDateTime(null);                        // null
/// ```
DateTime? safeDateTime(dynamic value) {
  if (value is DateTime) return value;
  if (value is String) {
    // Try ISO 8601 format first
    final parsed = DateTime.tryParse(value);
    if (parsed != null) return parsed;

    // Try Odoo format: 'YYYY-MM-DD HH:MM:SS'
    final odooPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2}) (\d{2}):(\d{2}):(\d{2})$');
    final match = odooPattern.firstMatch(value);
    if (match != null) {
      try {
        return DateTime(
          int.parse(match.group(1)!),
          int.parse(match.group(2)!),
          int.parse(match.group(3)!),
          int.parse(match.group(4)!),
          int.parse(match.group(5)!),
          int.parse(match.group(6)!),
        );
      } on FormatException {
        return null;
      }
    }
  }
  if (value is int) {
    // Assume Unix timestamp in seconds
    return DateTime.fromMillisecondsSinceEpoch(value * 1000);
  }
  return null;
}

/// Extension methods for safe map value access.
extension SafeMapExtension on Map<String, dynamic> {
  /// Get value as int or null.
  int? getInt(String key) => safeInt(this[key]);

  /// Get value as double or null.
  double? getDouble(String key) => safeDouble(this[key]);

  /// Get value as String or null.
  String? getString(String key) => safeString(this[key]);

  /// Get value as bool or null.
  bool? getBool(String key) => safeBool(this[key]);

  /// Get value as Map<String, dynamic> or null.
  Map<String, dynamic>? getMap(String key) => safeMap(this[key]);

  /// Get value as List or null.
  List<dynamic>? getList(String key) => safeList(this[key]);

  /// Get value as List<int> or null.
  List<int>? getIntList(String key) => safeIntList(this[key]);

  /// Get value as DateTime or null.
  DateTime? getDateTime(String key) => safeDateTime(this[key]);

  /// Get value cast to type T or null.
  T? get<T>(String key) => safeCast<T>(this[key]);
}
