import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../evaluator/expression_evaluator.dart';
import '../parser/qweb_node.dart';
import 'pdf_value_formatter.dart';

/// Debug mode flag - set to false for production
const bool _kDebugPdfRenderer = false;

/// No-op debug print that compiles to nothing when disabled
void _debugPrint(String message) {
  if (_kDebugPdfRenderer) {
    // ignore: avoid_print
    print(message);
  }
}

/// Handles text extraction, interpolation, alignment, and inline style parsing
/// for PDF rendering.
///
/// Extracted from [QWebPdfRenderer] to separate text-related concerns from
/// node rendering, layout, and value formatting.
class PdfTextRenderer {
  final ExpressionEvaluator _evaluator;
  final PdfValueFormatter _valueFormatter;

  PdfTextRenderer(this._evaluator, this._valueFormatter);

  /// Interpolate {{expressions}} in text.
  String interpolate(String text, Map<String, dynamic> context) {
    final regex = RegExp(r'\{\{(.+?)\}\}');
    return text.replaceAllMapped(regex, (match) {
      final expr = match.group(1)!.trim();
      final value = _evaluator.evaluate(expr, context);
      return value?.toString() ?? '';
    });
  }

  /// Interpolate format string with #{expr} syntax (Odoo-compatible).
  String interpolateFormat(String template, Map<String, dynamic> context) {
    // Pattern matches #{expr} and {{expr}}
    final regex = RegExp(r'#\{([^}]+)\}|\{\{([^}]+)\}\}');
    return template.replaceAllMapped(regex, (match) {
      final expr = (match.group(1) ?? match.group(2))!.trim();
      final value = _evaluator.evaluate(expr, context);
      return value?.toString() ?? '';
    });
  }

  /// Get text content from a node.
  String getTextContent(QWebNode node, Map<String, dynamic> context) {
    String text = '';
    if (node is QWebTextNode) {
      text = interpolate(node.text, context);
    } else if (node is QWebElementNode) {
      // Skip scripts and styles in text content
      if (['script', 'style', 'head', 'title']
          .contains(node.tagName.toLowerCase())) {
        return '';
      }
      text = node.children.map((n) => getTextContent(n, context)).join('');
    } else if (node is QWebFragmentNode) {
      text = node.children.map((n) => getTextContent(n, context)).join('');
    } else if (node is QWebEscNode || node is QWebOutNode) {
      final expr = node is QWebEscNode
          ? node.expression
          : (node as QWebOutNode).expression;
      final value = _evaluator.evaluate(expr, context);
      text = value?.toString() ?? '';
    } else if (node is QWebFieldNode) {
      final value = _evaluator.evaluate(node.expression, context);
      text = value?.toString() ?? '';
    }

    // Clean up DOCTYPE and boilerplate from text
    if (text.contains('<!DOCTYPE')) {
      text =
          text.replaceAll(RegExp(r'<!DOCTYPE[^>]*>', caseSensitive: false), '');
    }

    return text;
  }

  /// Extract text directly from QWeb nodes before rendering (more reliable).
  String getTextFromNode(QWebNode node, Map<String, dynamic> context) {
    if (node is QWebTextNode) {
      return node.text.trim();
    } else if (node is QWebEscNode) {
      final value = _evaluator.evaluate(node.expression, context);
      if (value == null) return '';
      // Format numeric values to 2 decimal places for monetary/price fields
      if (value is num && _valueFormatter.isMonetaryFieldName(node.expression)) {
        return value.toStringAsFixed(2);
      }
      return value.toString();
    } else if (node is QWebOutNode) {
      final value = _evaluator.evaluate(node.expression, context);
      if (value == null) return '';
      // Format numeric values to 2 decimal places for monetary/price fields
      if (value is num && _valueFormatter.isMonetaryFieldName(node.expression)) {
        return value.toStringAsFixed(2);
      }
      // Also format any numeric value to avoid floating point display issues
      if (value is double) {
        // Check if it's a whole number or needs decimal formatting
        if (value == value.roundToDouble()) {
          return value.toStringAsFixed(2);
        }
        return value.toStringAsFixed(2);
      }
      return value.toString();
    } else if (node is QWebFieldNode) {
      final value = _evaluator.evaluate(node.expression, context);
      if (value == null) return '';
      Map<String, dynamic>? options;
      if (node.options != null) {
        options = _valueFormatter.parseOptions(node.options!, context);
      }

      // Auto-detect monetary/numeric fields if no widget specified (same as _renderField)
      if (options == null || !options.containsKey('widget')) {
        final expression = node.expression.toLowerCase();
        final isMonetaryField =
            _valueFormatter.isMonetaryFieldName(expression);

        if (isMonetaryField && value is num) {
          // Auto-apply monetary formatting
          options ??= <String, dynamic>{};
          options['widget'] = 'monetary';
        } else if (value is num) {
          // For any numeric field, ensure 2 decimal places
          return value.toDouble().toStringAsFixed(2);
        }
      }

      final formatted = _evaluator.formatValue(value, options, context);
      return formatted.toString();
    } else if (node is QWebIfNode) {
      // Handle conditional nodes - evaluate condition and extract from appropriate branch
      final condition =
          _evaluator.evaluateCondition(node.condition, context);
      // DEBUG: Log collapse_prices evaluation
      if (node.condition.contains('collapse_prices') ||
          node.condition.contains('price_field')) {
        _debugPrint(
            '  [_getTextFromNode] Evaluating "${node.condition}" => $condition');
        _debugPrint(
            '   -> collapse_prices in context: ${context['collapse_prices']}');
      }
      if (condition) {
        // Extract from thenBranch
        final text = getTextFromNode(node.thenBranch, context);
        return text;
      } else if (node.elseBranch != null) {
        // Extract from elseBranch
        return getTextFromNode(node.elseBranch!, context);
      }
      return '';
    } else if (node is QWebElementNode) {
      // For elements like <span>, extract text from children
      return node.children
          .map((n) => getTextFromNode(n, context))
          .where((t) => t.isNotEmpty)
          .join(' ');
    } else if (node is QWebFragmentNode) {
      return node.children
          .map((n) => getTextFromNode(n, context))
          .where((t) => t.isNotEmpty)
          .join(' ');
    } else if (node is QWebDynamicAttrsNode) {
      // Handle dynamic attributes wrapper - extract text from child
      return getTextFromNode(node.child, context);
    } else if (node is QWebSetNode) {
      // Execute t-set to update context (critical for loops!)
      final value = _evaluator.evaluate(node.expression, context);
      context[node.variableName] = value;
      return ''; // t-set doesn't produce text, but updates context
    } else if (node is QWebSetContentNode) {
      // Execute t-set with content children
      final texts = node.children
          .map((n) => getTextFromNode(n, context))
          .where((t) => t.isNotEmpty)
          .toList();
      context[node.variableName] = texts.join(' ');
      return ''; // t-set doesn't produce text
    }
    return '';
  }

  /// Extract text content from a widget (for concatenating multiple widgets
  /// into single line).
  String getTextFromWidget(pw.Widget widget) {
    if (widget is pw.Text) {
      // Try to extract text from Text widget using toString
      final widgetStr = widget.toString();

      // Try multiple patterns to extract text
      // Pattern 1: Text('...')
      var match = RegExp(r"Text\('([^']*)'").firstMatch(widgetStr);
      if (match != null) return match.group(1) ?? '';

      // Pattern 2: Text("...")
      match = RegExp(r'Text\("([^"]*)"').firstMatch(widgetStr);
      if (match != null) return match.group(1) ?? '';

      // Pattern 3: text: '...'
      match = RegExp(r"text:\s*'([^']*)'").firstMatch(widgetStr);
      if (match != null) return match.group(1) ?? '';

      // Pattern 4: text: "..."
      match = RegExp(r'text:\s*"([^"]*)"').firstMatch(widgetStr);
      if (match != null) return match.group(1) ?? '';

      // Pattern 5: data: '...' (for some Text widget formats)
      match = RegExp(r"data:\s*'([^']*)'").firstMatch(widgetStr);
      if (match != null) return match.group(1) ?? '';

      // Pattern 6: Any quoted string (single quotes first, but more specific)
      match = RegExp(r"'([^']{1,100})'").firstMatch(widgetStr);
      if (match != null) {
        final extracted = match.group(1) ?? '';
        // Only return if it looks like actual content (not just "Text")
        if (extracted != 'Text' && extracted.isNotEmpty) {
          return extracted;
        }
      }

      // Pattern 7: Double quotes
      match = RegExp(r'"([^"]{1,100})"').firstMatch(widgetStr);
      if (match != null) {
        final extracted = match.group(1) ?? '';
        // Only return if it looks like actual content (not just "Text")
        if (extracted != 'Text' && extracted.isNotEmpty) {
          return extracted;
        }
      }
    }
    return '';
  }

  /// Get text alignment from CSS class.
  /// For numeric columns (Cantidad, P.Unitario, Descuento, Impuestos, SubTotal),
  /// default to right alignment.
  pw.TextAlign getAlignment(String? cssClass, {String? cellName}) {
    if (cssClass == null) {
      // Default numeric columns to right alignment
      if (cellName != null) {
        final numericColumns = [
          'th_quantity',
          'td_product_quantity',
          'th_priceunit',
          'td_product_priceunit',
          'th_discount',
          'td_product_discount',
          'th_taxes',
          'td_product_taxes',
          'th_subtotal',
          'td_product_subtotal',
          'o_td_quantity',
          'o_price_total'
        ];
        if (numericColumns.any((col) => cellName.contains(col))) {
          return pw.TextAlign.right;
        }
      }
      return pw.TextAlign.left;
    }
    if (cssClass.contains('text-end') || cssClass.contains('text-right')) {
      return pw.TextAlign.right;
    }
    if (cssClass.contains('text-center')) {
      return pw.TextAlign.center;
    }
    // Default numeric columns to right alignment even without explicit class
    if (cellName != null) {
      final numericColumns = [
        'th_quantity',
        'td_product_quantity',
        'th_priceunit',
        'td_product_priceunit',
        'th_discount',
        'td_product_discount',
        'th_taxes',
        'td_product_taxes',
        'th_subtotal',
        'td_product_subtotal',
        'o_td_quantity',
        'o_price_total'
      ];
      if (numericColumns.any((col) => cellName.contains(col))) {
        return pw.TextAlign.right;
      }
    }
    return pw.TextAlign.left;
  }

  /// Parse inline CSS styles and return a map with parsed values.
  /// Supports: border, padding, margin, and their variants.
  Map<String, dynamic> parseInlineStyles(String styleStr) {
    final result = <String, dynamic>{};

    if (styleStr.isEmpty) return result;

    // Parse border: "border: 1px solid #2c3e50"
    final borderMatch = RegExp(
            r'border\s*:\s*(\d+(?:\.\d+)?)px\s+solid\s+(#[0-9a-fA-F]{6})',
            caseSensitive: false)
        .firstMatch(styleStr);
    if (borderMatch != null) {
      final width = double.tryParse(borderMatch.group(1) ?? '1') ?? 1.0;
      final colorHex = borderMatch.group(2) ?? '#000000';
      result['borderWidth'] = width;
      result['borderColor'] = parseColorHex(colorHex);
    }

    // Parse padding: "padding: 15px" or "padding: 10px 5px"
    final paddingMatch =
        RegExp(r'padding\s*:\s*([^;]+)', caseSensitive: false)
            .firstMatch(styleStr);
    if (paddingMatch != null) {
      final paddingValue = paddingMatch.group(1)?.trim() ?? '';
      final pxValues =
          RegExp(r'(\d+(?:\.\d+)?)px').allMatches(paddingValue);
      if (pxValues.isNotEmpty) {
        final values = pxValues
            .map((m) => double.tryParse(m.group(1) ?? '0') ?? 0.0)
            .toList();
        if (values.length == 1) {
          // padding: 15px
          result['padding'] = values[0];
        } else if (values.length == 2) {
          // padding: 10px 5px (vertical horizontal)
          result['paddingTop'] = values[0];
          result['paddingBottom'] = values[0];
          result['paddingLeft'] = values[1];
          result['paddingRight'] = values[1];
        } else if (values.length == 4) {
          // padding: top right bottom left
          result['paddingTop'] = values[0];
          result['paddingRight'] = values[1];
          result['paddingBottom'] = values[2];
          result['paddingLeft'] = values[3];
        }
      }
    }

    // Parse padding-top, padding-bottom, etc.
    for (final side in ['top', 'bottom', 'left', 'right']) {
      final match = RegExp(r'padding-$side\s*:\s*(\d+(?:\.\d+)?)px',
              caseSensitive: false)
          .firstMatch(styleStr);
      if (match != null) {
        final value = double.tryParse(match.group(1) ?? '0') ?? 0.0;
        result['padding${side[0].toUpperCase()}${side.substring(1)}'] =
            value;
      }
    }

    // Parse margin-bottom: "margin-bottom: 15px"
    final marginBottomMatch =
        RegExp(r'margin-bottom\s*:\s*(\d+(?:\.\d+)?)px',
                caseSensitive: false)
            .firstMatch(styleStr);
    if (marginBottomMatch != null) {
      final value =
          double.tryParse(marginBottomMatch.group(1) ?? '0') ?? 0.0;
      result['marginBottom'] = value;
    }

    // Parse general margin: "margin: 15px"
    final marginMatch =
        RegExp(r'margin\s*:\s*(\d+(?:\.\d+)?)px', caseSensitive: false)
            .firstMatch(styleStr);
    if (marginMatch != null && !result.containsKey('marginBottom')) {
      final value = double.tryParse(marginMatch.group(1) ?? '0') ?? 0.0;
      result['marginBottom'] = value;
    }

    return result;
  }

  /// Parse hex color string to PdfColor.
  PdfColor parseColorHex(String hex) {
    if (!hex.startsWith('#')) return PdfColors.black;
    final hexValue = hex.substring(1);
    if (hexValue.length == 6) {
      final intColor = int.tryParse(hexValue, radix: 16);
      if (intColor != null) {
        return PdfColor.fromInt(0xFF000000 | intColor);
      }
    }
    return PdfColors.black;
  }
}
