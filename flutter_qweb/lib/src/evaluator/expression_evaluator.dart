/// QWeb Expression Evaluator
///
/// Evaluates QWeb expressions like "doc.partner_id.name" or "line.price_unit * line.qty"
/// against a data context.
///
/// Uses a parse-once, evaluate-many optimization with an LRU cache of parsed
/// expression ASTs. Common patterns (literals, paths, binary ops, ternary,
/// unary not, membership) are fully parsed into AST form. Complex patterns
/// (function calls, index access, list comprehensions, generator expressions)
/// are stored as [RawExpr] and evaluated via the original regex-based path.
///
/// Internally delegates to:
/// - [ExpressionParser] for parsing expressions into AST nodes
/// - [ExpressionValueFormatter] for raw/fallback evaluation and value formatting
library;

import 'expression_parser.dart';
import 'expression_value_formatter.dart';
import 'parsed_expression.dart';

/// Re-export so consumers can use ParsedExpression types if needed.
export 'parsed_expression.dart';

/// Evaluates QWeb expressions against a data context
class ExpressionEvaluator {
  final ExpressionParser _parser = ExpressionParser();
  late final ExpressionValueFormatter _formatter;

  ExpressionEvaluator() {
    _formatter = ExpressionValueFormatter(
      evaluate: evaluate,
      evaluateCondition: evaluateCondition,
      isTruthy: _isTruthy,
    );
  }

  /// Clear the expression parse cache. Useful in tests or when memory
  /// pressure is high.
  static void clearCache() => ExpressionParser.clearCache();

  /// Current number of cached parsed expressions.
  static int get cacheSize => ExpressionParser.cacheSize;

  // ── Public API (signatures unchanged) ─────────────────────────────────

  /// Evaluate an expression against a context.
  ///
  /// Uses an internal LRU cache so that repeated evaluation of the same
  /// expression string only parses it once.
  dynamic evaluate(String expression, Map<String, dynamic> context) {
    expression = expression.trim();
    if (expression.isEmpty) return null;

    final parsed = _parser.cachedParse(expression);
    return evaluateParsed(parsed, context);
  }

  /// Evaluate a boolean condition.
  bool evaluateCondition(String expression, Map<String, dynamic> context) {
    final result = evaluate(expression, context);
    return _isTruthy(result);
  }

  /// Parse an expression string into a [ParsedExpression] AST node.
  ParsedExpression parse(String expression) => _parser.parse(expression);

  // ── evaluateParsed: walk the AST ─────────────────────────────────────

  /// Evaluate a pre-parsed [ParsedExpression] against the given [context].
  dynamic evaluateParsed(
      ParsedExpression expr, Map<String, dynamic> context) {
    switch (expr) {
      case LiteralExpr(:final value):
        return value;

      case PathExpr(:final segments):
        return _evaluatePathSegments(segments, context);

      case BinaryOpExpr(:final left, :final op, :final right):
        return _evaluateBinaryOp(left, op, right, context);

      case UnaryOpExpr(op: 'not', :final operand):
        return !_isTruthy(evaluateParsed(operand, context));

      case UnaryOpExpr(:final operand):
        return evaluateParsed(operand, context);

      case TernaryExpr(:final condition, :final trueExpr, :final falseExpr):
        return _isTruthy(evaluateParsed(condition, context))
            ? evaluateParsed(trueExpr, context)
            : evaluateParsed(falseExpr, context);

      case MembershipExpr(:final item, :final collection):
        final itemVal = evaluateParsed(item, context);
        final collVal = evaluateParsed(collection, context);
        if (collVal is List) return collVal.contains(itemVal);
        if (collVal is String) return collVal.contains(itemVal.toString());
        if (collVal is Map) return collVal.containsKey(itemVal);
        return false;

      case ParenExpr(:final inner):
        return evaluateParsed(inner, context);

      case RawExpr(:final source):
        return _formatter.evaluateRaw(source, context);
    }
  }

  /// Evaluate a binary operation from its pre-parsed components.
  dynamic _evaluateBinaryOp(
    ParsedExpression left,
    String op,
    ParsedExpression right,
    Map<String, dynamic> context,
  ) {
    switch (op) {
      case 'and':
        final leftVal = evaluateParsed(left, context);
        if (!_isTruthy(leftVal)) return leftVal;
        return evaluateParsed(right, context);

      case 'or':
        final leftVal = evaluateParsed(left, context);
        if (_isTruthy(leftVal)) return leftVal;
        return evaluateParsed(right, context);

      case '==':
      case '!=':
      case '>':
      case '<':
      case '>=':
      case '<=':
        final leftVal = evaluateParsed(left, context);
        final rightVal = evaluateParsed(right, context);
        return _compare(leftVal, rightVal, op);

      case '+':
      case '-':
      case '*':
      case '/':
      case '%':
        final leftVal = evaluateParsed(left, context);
        final rightVal = evaluateParsed(right, context);
        return _arithmetic(leftVal, rightVal, op);

      default:
        evaluateParsed(left, context);
        return evaluateParsed(right, context);
    }
  }

  /// Resolve a dot-notation path from pre-split segments.
  dynamic _evaluatePathSegments(
      List<String> segments, Map<String, dynamic> context) {
    dynamic current = context;
    for (final part in segments) {
      if (current == null) return null;
      if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Check if a value is truthy (Python-like)
  bool _isTruthy(dynamic value) {
    if (value == null) return false;
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) return value.isNotEmpty;
    if (value is List) return value.isNotEmpty;
    if (value is Map) return value.isNotEmpty;
    return true;
  }

  /// Compare two values
  dynamic _compare(dynamic left, dynamic right, String op) {
    switch (op) {
      case '==':
        return left == right;
      case '!=':
        return left != right;
      case '>':
        if (left is num && right is num) return left > right;
        if (left is String && right is String) {
          return left.compareTo(right) > 0;
        }
        return false;
      case '<':
        if (left is num && right is num) return left < right;
        if (left is String && right is String) {
          return left.compareTo(right) < 0;
        }
        return false;
      case '>=':
        if (left is num && right is num) return left >= right;
        if (left is String && right is String) {
          return left.compareTo(right) >= 0;
        }
        return false;
      case '<=':
        if (left is num && right is num) return left <= right;
        if (left is String && right is String) {
          return left.compareTo(right) <= 0;
        }
        return false;
      default:
        return false;
    }
  }

  /// Perform arithmetic operation
  dynamic _arithmetic(dynamic left, dynamic right, String op) {
    if (op == '+' && (left is String || right is String)) {
      return '${left ?? ''}${right ?? ''}';
    }

    final leftNum = _toNum(left);
    final rightNum = _toNum(right);
    if (leftNum == null || rightNum == null) return null;

    switch (op) {
      case '+':
        return leftNum + rightNum;
      case '-':
        return leftNum - rightNum;
      case '*':
        return leftNum * rightNum;
      case '/':
        if (rightNum == 0) return null;
        return leftNum / rightNum;
      case '%':
        if (rightNum == 0) return null;
        return leftNum % rightNum;
      default:
        return null;
    }
  }

  num? _toNum(dynamic value) {
    if (value is num) return value;
    if (value is String) return num.tryParse(value);
    return null;
  }

  /// Format a value with options (for t-field)
  String formatValue(
    dynamic value,
    Map<String, dynamic>? options,
    Map<String, dynamic> context,
  ) {
    return _formatter.formatValue(value, options, context);
  }
}
