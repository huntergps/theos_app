/// QWeb Expression Parser
///
/// Parses QWeb/Python-like expression strings into [ParsedExpression] AST nodes.
/// Uses an LRU cache so repeated parsing of the same expression string is O(1).
library;

import 'dart:collection';

import 'parsed_expression.dart';

/// Parses QWeb expression strings into [ParsedExpression] AST nodes.
///
/// Common patterns (literals, paths, binary ops, ternary, unary not, membership)
/// are fully parsed. Complex patterns (function calls, index access, list
/// comprehensions) are stored as [RawExpr] and evaluated via the fallback path.
class ExpressionParser {
  // Cached regex patterns for performance
  static final RegExp ternaryRegex =
      RegExp(r'^(.+?)\s+if\s+(.+?)\s+else\s+(.+)$');

  // ── LRU cache for parsed expressions ──────────────────────────────────

  /// LRU cache: insertion-ordered LinkedHashMap. Oldest entries are evicted
  /// when the cache exceeds [_maxCacheSize].
  static final LinkedHashMap<String, ParsedExpression> _cache =
      LinkedHashMap<String, ParsedExpression>();

  /// Maximum number of entries in the parse cache.
  static const int _maxCacheSize = 256;

  /// Clear the expression parse cache.
  static void clearCache() => _cache.clear();

  /// Current number of cached parsed expressions.
  static int get cacheSize => _cache.length;

  /// Return a cached [ParsedExpression] for [expression], parsing on cache
  /// miss and evicting the oldest entry when the cache is full.
  ParsedExpression cachedParse(String expression) {
    final cached = _cache.remove(expression);
    if (cached != null) {
      _cache[expression] = cached;
      return cached;
    }

    final parsed = parse(expression);

    if (_cache.length >= _maxCacheSize) {
      _cache.remove(_cache.keys.first);
    }
    _cache[expression] = parsed;
    return parsed;
  }

  /// Parse an expression string into a [ParsedExpression] AST node.
  ParsedExpression parse(String expression) {
    expression = expression.trim();
    if (expression.isEmpty) return const LiteralExpr(null);

    // ── Python-style ternary ──
    final ternaryMatch = ternaryRegex.firstMatch(expression);
    if (ternaryMatch != null) {
      return TernaryExpr(
        parse(ternaryMatch.group(2)!.trim()), // condition
        parse(ternaryMatch.group(1)!.trim()), // trueExpr
        parse(ternaryMatch.group(3)!.trim()), // falseExpr
      );
    }

    // ── String literal ──
    if ((expression.startsWith("'") && expression.endsWith("'")) ||
        (expression.startsWith('"') && expression.endsWith('"'))) {
      return LiteralExpr(expression.substring(1, expression.length - 1));
    }

    // ── Numeric literal ──
    final numValue = num.tryParse(expression);
    if (numValue != null) return LiteralExpr(numValue);

    // ── Boolean / None literals ──
    if (expression == 'True' || expression == 'true') {
      return const LiteralExpr(true);
    }
    if (expression == 'False' || expression == 'false') {
      return const LiteralExpr(false);
    }
    if (expression == 'None' || expression == 'null') {
      return const LiteralExpr(null);
    }

    // ── List comprehensions & literal lists → RawExpr ──
    if (expression.startsWith('[') && expression.endsWith(']')) {
      return RawExpr(expression);
    }

    // ── Parenthesized expression ──
    if (expression.startsWith('(') && expression.endsWith(')')) {
      int depth = 0;
      bool isOuterParens = true;
      for (int i = 0; i < expression.length - 1; i++) {
        if (expression[i] == '(') depth++;
        if (expression[i] == ')') depth--;
        if (depth == 0 && i < expression.length - 1) {
          isOuterParens = false;
          break;
        }
      }
      if (isOuterParens) {
        return ParenExpr(
            parse(expression.substring(1, expression.length - 1)));
      }
    }

    // ── Operators ──
    if (containsOperator(expression)) {
      return _parseOperation(expression);
    }

    // ── Index access → RawExpr (complex) ──
    if (expression.contains('[')) {
      final bracketIdx = findFirstTopLevelBracket(expression);
      if (bracketIdx != -1) {
        return RawExpr(expression);
      }
    }

    // ── Function / method calls → RawExpr (complex) ──
    if (expression.contains('(') && expression.endsWith(')')) {
      return RawExpr(expression);
    }

    // ── Simple path (variable or dot notation) ──
    return PathExpr(expression.split('.'));
  }

  /// Parse an expression that is known to contain operators into an AST node.
  ParsedExpression _parseOperation(String expression) {
    final ternaryMatch = ternaryRegex.firstMatch(expression);
    if (ternaryMatch != null) {
      return TernaryExpr(
        parse(ternaryMatch.group(2)!.trim()),
        parse(ternaryMatch.group(1)!.trim()),
        parse(ternaryMatch.group(3)!.trim()),
      );
    }

    // ── 'and' / 'or' (lowest precedence, left-to-right) ──
    final andIndex = findTopLevelKeyword(expression, ' and ');
    if (andIndex != -1) {
      return BinaryOpExpr(
        parse(expression.substring(0, andIndex).trim()),
        'and',
        parse(expression.substring(andIndex + 5).trim()),
      );
    }

    final orIndex = findTopLevelKeyword(expression, ' or ');
    if (orIndex != -1) {
      return BinaryOpExpr(
        parse(expression.substring(0, orIndex).trim()),
        'or',
        parse(expression.substring(orIndex + 4).trim()),
      );
    }

    // ── 'not' (unary) ──
    if (expression.startsWith('not ')) {
      return UnaryOpExpr('not', parse(expression.substring(4).trim()));
    }

    // ── Comparisons ──
    for (final op in ['==', '!=', '>=', '<=', '>', '<']) {
      final idx = findTopLevelOperator(expression, op);
      if (idx != -1) {
        return BinaryOpExpr(
          parse(expression.substring(0, idx).trim()),
          op,
          parse(expression.substring(idx + op.length).trim()),
        );
      }
    }

    // ── 'in' membership ──
    final inIndex = findTopLevelKeyword(expression, ' in ');
    if (inIndex != -1) {
      return MembershipExpr(
        parse(expression.substring(0, inIndex).trim()),
        parse(expression.substring(inIndex + 4).trim()),
      );
    }

    // ── Arithmetic (+, -, *, /, %) ──
    for (final op in ['+', '-', '*', '/', '%']) {
      final opIndex = findOperatorIndex(expression, op);
      if (opIndex > 0) {
        return BinaryOpExpr(
          parse(expression.substring(0, opIndex).trim()),
          op,
          parse(expression.substring(opIndex + 1).trim()),
        );
      }
    }

    // Fallback
    return RawExpr(expression);
  }

  // ── Shared scanning helpers (used by both parser and raw evaluator) ────

  /// Find the first top-level occurrence of a keyword like ' and ' or ' or '
  /// that is not inside strings, brackets, or parentheses.
  static int findTopLevelKeyword(String expr, String keyword) {
    int depth = 0;
    bool inString = false;
    String? stringChar;

    for (int i = 0; i < expr.length; i++) {
      final char = expr[i];

      if (!inString && (char == '"' || char == "'")) {
        inString = true;
        stringChar = char;
        continue;
      }
      if (inString && char == stringChar) {
        inString = false;
        stringChar = null;
        continue;
      }
      if (inString) continue;

      if (char == '(' || char == '[' || char == '{') {
        depth++;
        continue;
      }
      if (char == ')' || char == ']' || char == '}') {
        depth--;
        continue;
      }

      if (depth == 0 && i + keyword.length <= expr.length) {
        if (expr.substring(i, i + keyword.length) == keyword) {
          return i;
        }
      }
    }
    return -1;
  }

  /// Find the first top-level occurrence of a symbolic operator like '=='.
  static int findTopLevelOperator(String expr, String op) {
    int depth = 0;
    bool inString = false;
    String? stringChar;

    for (int i = 0; i < expr.length; i++) {
      final char = expr[i];

      if (!inString && (char == '"' || char == "'")) {
        inString = true;
        stringChar = char;
        continue;
      }
      if (inString && char == stringChar) {
        inString = false;
        stringChar = null;
        continue;
      }
      if (inString) continue;

      if (char == '(' || char == '[' || char == '{') {
        depth++;
        continue;
      }
      if (char == ')' || char == ']' || char == '}') {
        depth--;
        continue;
      }

      if (depth == 0 && i + op.length <= expr.length) {
        if (expr.substring(i, i + op.length) == op) {
          return i;
        }
      }
    }
    return -1;
  }

  /// Check if expression contains operators at the top level.
  static bool containsOperator(String expr) {
    if (expr.startsWith('not ')) return true;

    final operators = [
      ' and ', ' or ', ' not ', ' in ', ' is ',
      '==', '!=', '>=', '<=', '>', '<',
      '+', '-', '*', '/', '%',
    ];

    var depth = 0;
    var inString = false;
    String? stringChar;

    for (var i = 0; i < expr.length; i++) {
      final char = expr[i];

      if (!inString && (char == '"' || char == "'")) {
        inString = true;
        stringChar = char;
        continue;
      }
      if (inString && char == stringChar) {
        inString = false;
        stringChar = null;
        continue;
      }
      if (inString) continue;

      if (char == '(' || char == '[' || char == '{') {
        depth++;
        continue;
      }
      if (char == ')' || char == ']' || char == '}') {
        depth--;
        continue;
      }

      if (depth == 0) {
        for (final op in operators) {
          if (i + op.length <= expr.length) {
            final substring = expr.substring(i, i + op.length);
            if (substring == op) {
              return true;
            }
          }
        }
      }
    }
    return false;
  }

  /// Find operator index, respecting parentheses (scans right-to-left).
  static int findOperatorIndex(String expr, String op) {
    int depth = 0;
    for (int i = expr.length - 1; i >= 0; i--) {
      final char = expr[i];
      if (char == ')') depth++;
      if (char == '(') depth--;
      if (depth == 0 && expr.substring(i).startsWith(op)) {
        return i;
      }
    }
    return -1;
  }

  /// Find the first top-level [ (not inside parens or strings).
  static int findFirstTopLevelBracket(String expr) {
    int parenDepth = 0;
    bool inString = false;
    String stringChar = '';

    for (int i = 0; i < expr.length; i++) {
      final char = expr[i];

      if (!inString && (char == '"' || char == "'")) {
        inString = true;
        stringChar = char;
      } else if (inString &&
          char == stringChar &&
          (i == 0 || expr[i - 1] != '\\')) {
        inString = false;
      } else if (!inString) {
        if (char == '(') {
          parenDepth++;
        } else if (char == ')') {
          parenDepth--;
        } else if (char == '[' && parenDepth == 0) {
          return i;
        }
      }
    }
    return -1;
  }
}
