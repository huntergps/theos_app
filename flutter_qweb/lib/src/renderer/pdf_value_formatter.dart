import '../evaluator/expression_evaluator.dart';

/// Handles value formatting, option parsing, and monetary field detection
/// for PDF rendering.
///
/// Extracted from [QWebPdfRenderer] to separate value formatting concerns
/// from node rendering and layout.
class PdfValueFormatter {
  final ExpressionEvaluator _evaluator;

  PdfValueFormatter(this._evaluator);

  /// Check if field name suggests it's a monetary field.
  bool isMonetaryFieldName(String expression) {
    // Common monetary field name patterns in Odoo
    final monetaryPatterns = [
      'price',
      'amount',
      'total',
      'subtotal',
      'discount_amount',
      'tax_amount',
      'cost',
      'value',
      'fee',
      'charge',
      'payment',
      'balance',
      'credit',
      'debit',
    ];

    return monetaryPatterns.any((pattern) => expression.contains(pattern));
  }

  /// Try to extract currency from context based on expression path.
  Map<String, dynamic>? getCurrencyFromContext(
      String expression, Map<String, dynamic> context) {
    // Try to get currency from line.currency_id or doc.currency_id
    // Expression might be: line.discount_amount, doc.amount_total, etc.

    // Check if expression contains 'line.'
    if (expression.contains('line.')) {
      final line = context['line'];
      if (line is Map) {
        final currencyId = line['currency_id'];
        if (currencyId is Map) {
          return Map<String, dynamic>.from(currencyId);
        }
      }
    }

    // Check doc.currency_id
    final doc = context['doc'];
    if (doc is Map) {
      final currencyId = doc['currency_id'];
      if (currencyId is Map) {
        return Map<String, dynamic>.from(currencyId);
      }
    }

    // Fallback: try to get from root context
    final currencyId = context['currency_id'];
    if (currencyId is Map) {
      return Map<String, dynamic>.from(currencyId);
    }

    return null;
  }

  /// Parse t-options string to Map.
  Map<String, dynamic> parseOptions(
      String optionsStr, Map<String, dynamic> context) {
    final result = <String, dynamic>{};

    // Decode HTML entities first
    var content = optionsStr
        .replaceAll('&quot;', '"')
        .replaceAll('&apos;', "'")
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();

    // Try to parse as JSON first (most reliable)
    try {
      if (content.startsWith('{')) {
        final parsed = _parseJsonLike(content);
        if (parsed != null) return parsed;
      }
    } catch (_) {}

    // Fallback: Manual parsing
    // Remove outer braces
    if (content.startsWith('{')) content = content.substring(1);
    if (content.endsWith('}')) {
      content = content.substring(0, content.length - 1);
    }

    // Split by comma (simple approach)
    final pairs = content.split(',');
    for (final pair in pairs) {
      final parts = pair.split(':');
      if (parts.length == 2) {
        var key = parts[0].trim();
        var value = parts[1].trim();

        // Remove quotes from key
        if (key.startsWith("'") || key.startsWith('"')) {
          key = key.substring(1, key.length - 1);
        }

        // Parse value
        if (value.startsWith("'") || value.startsWith('"')) {
          result[key] = value.substring(1, value.length - 1);
        } else if (value == 'True' || value == 'true') {
          result[key] = true;
        } else if (value == 'False' || value == 'false') {
          result[key] = false;
        } else if (int.tryParse(value) != null) {
          result[key] = int.parse(value);
        } else {
          // It's an expression - evaluate it
          result[key] = _evaluator.evaluate(value, context);
        }
      }
    }

    return result;
  }

  /// Parse JSON-like string to Map.
  Map<String, dynamic>? _parseJsonLike(String jsonStr) {
    try {
      // Convert Python True/False to JSON true/false
      var normalized = jsonStr
          .replaceAll("'", '"')
          .replaceAll(': True', ': true')
          .replaceAll(': False', ': false')
          .replaceAll(':True', ':true')
          .replaceAll(':False', ':false');

      // Try to parse as JSON
      final decoded = _jsonDecode(normalized);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
    } catch (_) {}
    return null;
  }

  /// Safe JSON decode.
  dynamic _jsonDecode(String source) {
    try {
      return source.isEmpty ? null : _simpleJsonParse(source);
    } catch (_) {
      return null;
    }
  }

  /// Simple JSON parser for t-options.
  dynamic _simpleJsonParse(String source) {
    source = source.trim();

    // Object
    if (source.startsWith('{') && source.endsWith('}')) {
      final result = <String, dynamic>{};
      final content = source.substring(1, source.length - 1).trim();
      if (content.isEmpty) return result;

      // Parse key-value pairs
      var depth = 0;
      var inString = false;
      var currentPair = '';

      for (var i = 0; i < content.length; i++) {
        final char = content[i];
        if (char == '"' && (i == 0 || content[i - 1] != '\\')) {
          inString = !inString;
        }
        if (!inString) {
          if (char == '{' || char == '[') depth++;
          if (char == '}' || char == ']') depth--;
          if (char == ',' && depth == 0) {
            _parseJsonPair(currentPair, result);
            currentPair = '';
            continue;
          }
        }
        currentPair += char;
      }
      if (currentPair.isNotEmpty) {
        _parseJsonPair(currentPair, result);
      }
      return result;
    }

    // Array
    if (source.startsWith('[') && source.endsWith(']')) {
      final content = source.substring(1, source.length - 1).trim();
      if (content.isEmpty) return <dynamic>[];
      // For simplicity, split by comma (doesn't handle nested)
      return content
          .split(',')
          .map((s) => _simpleJsonParse(s.trim()))
          .toList();
    }

    // String
    if (source.startsWith('"') && source.endsWith('"')) {
      return source.substring(1, source.length - 1);
    }

    // Boolean/null
    if (source == 'true') return true;
    if (source == 'false') return false;
    if (source == 'null') return null;

    // Number
    return num.tryParse(source) ?? source;
  }

  void _parseJsonPair(String pair, Map<String, dynamic> result) {
    final colonIndex = pair.indexOf(':');
    if (colonIndex > 0) {
      var key = pair.substring(0, colonIndex).trim();
      final value = pair.substring(colonIndex + 1).trim();
      // Remove quotes from key
      if (key.startsWith('"') && key.endsWith('"')) {
        key = key.substring(1, key.length - 1);
      }
      result[key] = _simpleJsonParse(value);
    }
  }
}
