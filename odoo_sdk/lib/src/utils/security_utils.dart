/// Security utilities for Odoo Model Manager.
///
/// Provides:
/// - Domain clause validation (prevents injection attacks)
/// - Error message sanitization (prevents PII exposure)
/// - Security exceptions hierarchy
library;

/// Security exception for domain validation failures.
class OdooDomainSecurityException implements Exception {
  final String message;
  final String? field;

  const OdooDomainSecurityException(this.message, {this.field});

  @override
  String toString() => 'OdooDomainSecurityException: $message';
}

/// Security exception for PII exposure risks.
class OdooPiiExposureException implements Exception {
  final String message;

  const OdooPiiExposureException(this.message);

  @override
  String toString() => 'OdooPiiExposureException: $message';
}

/// Validates Odoo domain clauses for security.
///
/// Prevents potential injection attacks by validating:
/// - Domain structure (list of clauses)
/// - Field names (no SQL injection patterns)
/// - Operators (only valid Odoo operators)
/// - Values (sanitized for safe use)
class DomainValidator {
  /// Valid Odoo domain operators.
  static const validOperators = {
    '=',
    '!=',
    '>',
    '>=',
    '<',
    '<=',
    'like',
    'ilike',
    'not like',
    'not ilike',
    '=like',
    '=ilike',
    'in',
    'not in',
    'child_of',
    'parent_of',
    '=?',
  };

  /// Patterns that indicate potential injection attacks.
  static final _dangerousPatterns = [
    RegExp(r';\s*--'), // SQL comment
    RegExp(r';\s*DROP', caseSensitive: false), // DROP statement
    RegExp(r';\s*DELETE', caseSensitive: false), // DELETE statement
    RegExp(r';\s*UPDATE', caseSensitive: false), // UPDATE statement
    RegExp(r';\s*INSERT', caseSensitive: false), // INSERT statement
    RegExp(r'UNION\s+SELECT', caseSensitive: false), // UNION injection
    RegExp(r"'\s*OR\s+'1'\s*=\s*'1", caseSensitive: false), // OR injection
    RegExp(r'--\s*$'), // Trailing comment
    RegExp(r'/\*.*\*/'), // Block comment
  ];

  /// Fields that should never be queried directly for security reasons.
  static const sensitiveFields = {
    'password',
    'password_crypt',
    'api_key',
    'token',
    'secret',
    'private_key',
    'credit_card',
    'ssn',
    'pin',
  };

  /// Validates a domain clause list.
  ///
  /// Throws [OdooDomainSecurityException] if validation fails.
  ///
  /// Example:
  /// ```dart
  /// DomainValidator.validate([
  ///   ['name', 'ilike', 'test'],
  ///   ['active', '=', true],
  /// ]);
  /// ```
  static void validate(List<dynamic>? domain) {
    if (domain == null || domain.isEmpty) return;

    for (final clause in domain) {
      _validateClause(clause);
    }
  }

  /// Validates a single domain clause.
  static void _validateClause(dynamic clause) {
    // Handle logical operators
    if (clause is String) {
      if (clause != '&' && clause != '|' && clause != '!') {
        throw OdooDomainSecurityException(
          'Invalid logical operator: $clause. Use &, |, or !',
        );
      }
      return;
    }

    // Must be a list [field, operator, value]
    if (clause is! List) {
      throw OdooDomainSecurityException(
        'Domain clause must be a list, got: ${clause.runtimeType}',
      );
    }

    if (clause.length != 3) {
      throw OdooDomainSecurityException(
        'Domain clause must have 3 elements [field, operator, value], '
        'got ${clause.length} elements',
      );
    }

    final field = clause[0];
    final operator = clause[1];

    // Validate field name
    _validateFieldName(field);

    // Validate operator
    _validateOperator(operator);

    // Validate value for injection patterns
    _validateValue(clause[2], field as String);
  }

  /// Validates a field name for security.
  static void _validateFieldName(dynamic field) {
    if (field is! String) {
      throw OdooDomainSecurityException(
        'Field name must be a string, got: ${field.runtimeType}',
      );
    }

    if (field.isEmpty) {
      throw const OdooDomainSecurityException('Field name cannot be empty');
    }

    // Check for dangerous patterns in field name
    for (final pattern in _dangerousPatterns) {
      if (pattern.hasMatch(field)) {
        throw OdooDomainSecurityException(
          'Potential injection detected in field name',
          field: field,
        );
      }
    }

    // Check for sensitive fields
    final lowerField = field.toLowerCase();
    for (final sensitive in sensitiveFields) {
      if (lowerField.contains(sensitive)) {
        throw OdooDomainSecurityException(
          'Query on sensitive field not allowed: $field',
          field: field,
        );
      }
    }

    // Valid field name pattern: letters, numbers, underscores, dots
    final validFieldPattern = RegExp(r'^[a-zA-Z_][a-zA-Z0-9_.]*$');
    if (!validFieldPattern.hasMatch(field)) {
      throw OdooDomainSecurityException(
        'Invalid field name format: $field',
        field: field,
      );
    }
  }

  /// Validates an operator.
  static void _validateOperator(dynamic operator) {
    if (operator is! String) {
      throw OdooDomainSecurityException(
        'Operator must be a string, got: ${operator.runtimeType}',
      );
    }

    final lowerOp = operator.toLowerCase();
    if (!validOperators.contains(lowerOp)) {
      throw OdooDomainSecurityException(
        'Invalid operator: $operator. Valid operators: ${validOperators.join(', ')}',
      );
    }
  }

  /// Validates a value for injection patterns.
  static void _validateValue(dynamic value, String field) {
    if (value == null) return;

    // For string values, check for injection patterns
    if (value is String) {
      for (final pattern in _dangerousPatterns) {
        if (pattern.hasMatch(value)) {
          throw OdooDomainSecurityException(
            'Potential injection detected in value for field: $field',
            field: field,
          );
        }
      }
    }

    // For list values (in/not in operators), validate each element
    if (value is List) {
      for (final item in value) {
        _validateValue(item, field);
      }
    }
  }

  /// Quick check if a domain looks safe (for logging/debugging).
  ///
  /// Returns `true` if domain passes basic validation, `false` otherwise.
  /// Does not throw exceptions.
  static bool isSafe(List<dynamic>? domain) {
    try {
      validate(domain);
      return true;
    } on OdooDomainSecurityException {
      // Domain validation failed - return false as expected
      return false;
    }
  }
}

/// Sanitizes error messages to prevent PII exposure.
///
/// Use this utility to clean error messages before logging or displaying
/// to users, especially for errors that may contain user data.
class ErrorSanitizer {
  /// Patterns to redact from error messages.
  static final _redactPatterns = [
    // Email addresses
    RegExp(r'\b[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Z|a-z]{2,}\b'),
    // Phone numbers (various formats)
    RegExp(r'\+?\d{1,3}[-.\s]?\(?\d{1,4}\)?[-.\s]?\d{1,4}[-.\s]?\d{1,9}'),
    // Credit card numbers (basic pattern)
    RegExp(r'\b\d{4}[-\s]?\d{4}[-\s]?\d{4}[-\s]?\d{4}\b'),
    // SSN-like patterns
    RegExp(r'\b\d{3}[-\s]?\d{2}[-\s]?\d{4}\b'),
    // API keys / tokens (long alphanumeric strings)
    RegExp(r'\b[A-Za-z0-9]{32,}\b'),
    // UUID patterns
    RegExp(
        r'\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b'),
    // IP addresses
    RegExp(r'\b\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}\b'),
    // Passwords in common formats (simplified patterns)
    RegExp(r'password\s*[:=]\s*\S+', caseSensitive: false),
    RegExp(r'pwd\s*[:=]\s*\S+', caseSensitive: false),
    RegExp(r'secret\s*[:=]\s*\S+', caseSensitive: false),
    RegExp(r'token\s*[:=]\s*\S+', caseSensitive: false),
    RegExp(r'api_key\s*[:=]\s*\S+', caseSensitive: false),
  ];

  /// Placeholder used to replace redacted content.
  static const redactedPlaceholder = '[REDACTED]';

  /// Sanitizes an error message by removing potential PII.
  ///
  /// Example:
  /// ```dart
  /// final original = 'User john@example.com failed login';
  /// final safe = ErrorSanitizer.sanitize(original);
  /// // Result: 'User [REDACTED] failed login'
  /// ```
  static String sanitize(String message) {
    var result = message;

    for (final pattern in _redactPatterns) {
      result = result.replaceAll(pattern, redactedPlaceholder);
    }

    return result;
  }

  /// Sanitizes an exception for safe logging.
  ///
  /// Returns a new exception with sanitized message.
  static Exception sanitizeException(Exception e) {
    final sanitizedMessage = sanitize(e.toString());
    return SanitizedException(sanitizedMessage, original: e);
  }

  /// Sanitizes a stack trace by removing file paths that might reveal
  /// system structure.
  static String sanitizeStackTrace(StackTrace stackTrace) {
    final lines = stackTrace.toString().split('\n');
    final sanitized = lines.map((line) {
      // Remove absolute paths, keep relative
      return line.replaceAll(RegExp(r'/[A-Za-z]:/|/home/[^/]+/|/Users/[^/]+/'),
          '/[PATH]/');
    }).join('\n');
    return sanitized;
  }
}

/// Exception wrapper with sanitized message.
class SanitizedException implements Exception {
  final String message;
  final Exception? original;

  const SanitizedException(this.message, {this.original});

  @override
  String toString() => message;
}

/// SEC-01: Utility for masking sensitive credentials in toString() output.
///
/// Use this utility to mask API keys, tokens, passwords, and other
/// sensitive data before including them in string representations.
///
/// Example:
/// ```dart
/// class MyConfig {
///   final String apiKey;
///   final String? sessionToken;
///
///   @override
///   String toString() {
///     return 'MyConfig(apiKey: ${CredentialMasker.mask(apiKey)}, '
///            'sessionToken: ${CredentialMasker.maskNullable(sessionToken)})';
///   }
/// }
/// ```
class CredentialMasker {
  /// Default mask character.
  static const String maskChar = '*';

  /// Default placeholder for null values.
  static const String nullPlaceholder = 'null';

  /// Completely hidden placeholder for highly sensitive data.
  static const String hiddenPlaceholder = '********';

  /// Masks a credential string, showing only first and last characters.
  ///
  /// For short strings (≤4 chars), returns all asterisks.
  /// For longer strings, shows first 2 and last 2 characters.
  ///
  /// Example:
  /// - 'abc' → '***'
  /// - 'abcd' → '****'
  /// - 'my-secret-key' → 'my*********ey'
  static String mask(String value) {
    if (value.isEmpty) return '';

    if (value.length <= 4) {
      return maskChar * value.length;
    }

    const visibleStart = 2;
    const visibleEnd = 2;
    final maskedLength = value.length - visibleStart - visibleEnd;

    return '${value.substring(0, visibleStart)}'
        '${maskChar * maskedLength}'
        '${value.substring(value.length - visibleEnd)}';
  }

  /// Masks a nullable credential string.
  ///
  /// Returns [nullPlaceholder] if value is null.
  static String maskNullable(String? value) {
    if (value == null) return nullPlaceholder;
    return mask(value);
  }

  /// Completely hides a credential (returns asterisks only).
  ///
  /// Use for highly sensitive data like passwords where even
  /// partial exposure is unacceptable.
  static String hide(String value) {
    if (value.isEmpty) return '';
    return hiddenPlaceholder;
  }

  /// Completely hides a nullable credential.
  static String hideNullable(String? value) {
    if (value == null) return nullPlaceholder;
    return hide(value);
  }

  /// Masks showing only the first N characters.
  ///
  /// Example with prefixLength=4:
  /// - 'my-secret-api-key' → 'my-s*************'
  static String maskWithPrefix(String value, {int prefixLength = 4}) {
    if (value.isEmpty) return '';

    if (value.length <= prefixLength) {
      return maskChar * value.length;
    }

    return '${value.substring(0, prefixLength)}'
        '${maskChar * (value.length - prefixLength)}';
  }

  /// Masks a URL, hiding credentials but keeping the structure visible.
  ///
  /// Example:
  /// - 'https://user:password@example.com/path' → 'https://****:****@example.com/path'
  static String maskUrl(String url) {
    try {
      final uri = Uri.parse(url);

      if (uri.userInfo.isEmpty) {
        return url; // No credentials in URL
      }

      final parts = uri.userInfo.split(':');
      final maskedUserInfo = parts.map((p) => maskChar * 4).join(':');

      return uri.replace(userInfo: maskedUserInfo).toString();
    } catch (_) {
      // If URL parsing fails, return masked version
      return mask(url);
    }
  }

  /// Creates a secure string representation for a map containing credentials.
  ///
  /// Automatically masks values for keys that look like credentials.
  ///
  /// Example:
  /// ```dart
  /// final config = {'apiKey': 'secret123', 'name': 'Test'};
  /// print(CredentialMasker.maskMap(config));
  /// // {apiKey: se*****23, name: Test}
  /// ```
  static String maskMap(
    Map<String, dynamic> map, {
    Set<String>? additionalSensitiveKeys,
  }) {
    const defaultSensitiveKeys = {
      'apiKey',
      'api_key',
      'apikey',
      'password',
      'pwd',
      'secret',
      'token',
      'sessionToken',
      'session_token',
      'sessionId',
      'session_id',
      'accessToken',
      'access_token',
      'refreshToken',
      'refresh_token',
      'privateKey',
      'private_key',
      'credentials',
      'auth',
      'authorization',
    };

    final sensitiveKeys = {
      ...defaultSensitiveKeys,
      ...?additionalSensitiveKeys,
    };

    final buffer = StringBuffer('{');
    var first = true;

    for (final entry in map.entries) {
      if (!first) buffer.write(', ');
      first = false;

      buffer.write('${entry.key}: ');

      final lowerKey = entry.key.toLowerCase();
      final isSensitive = sensitiveKeys.any(
        (k) => lowerKey.contains(k.toLowerCase()),
      );

      if (isSensitive && entry.value is String) {
        buffer.write(mask(entry.value as String));
      } else if (entry.value is Map<String, dynamic>) {
        buffer.write(maskMap(
          entry.value as Map<String, dynamic>,
          additionalSensitiveKeys: additionalSensitiveKeys,
        ));
      } else {
        buffer.write(entry.value);
      }
    }

    buffer.write('}');
    return buffer.toString();
  }
}
