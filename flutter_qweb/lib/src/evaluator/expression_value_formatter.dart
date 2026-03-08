/// QWeb Expression Value Formatter
///
/// Handles raw/fallback expression evaluation (function calls, index access,
/// list comprehensions, generator expressions) and value formatting for
/// t-field rendering.
library;

import 'expression_parser.dart';

/// Debug flag for expression evaluation logging
const bool _kDebugAnyAll = false;

/// Handles raw expression evaluation (fallback for expressions not fully parsed
/// into AST form) and value formatting for t-field rendering.
///
/// This class is used internally by [ExpressionEvaluator] and should not be
/// instantiated directly.
class ExpressionValueFormatter {
  static final RegExp _ternaryRegex = ExpressionParser.ternaryRegex;
  static final RegExp _listCompSimpleRegex =
      RegExp(r'^(.+?)\s+for\s+(\w+)\s+in\s+(.+)$');
  static final RegExp _listCompWithFilterRegex =
      RegExp(r'^(.+?)\s+for\s+(\w+)\s+in\s+(.+?)(?:\s+if\s+(.+))?$');

  /// Reference to the top-level evaluate function, for recursive calls.
  final dynamic Function(String, Map<String, dynamic>) evaluate;

  /// Reference to the top-level evaluateCondition function.
  final bool Function(String, Map<String, dynamic>) evaluateCondition;

  /// Reference to the top-level _isTruthy function.
  final bool Function(dynamic) isTruthy;

  ExpressionValueFormatter({
    required this.evaluate,
    required this.evaluateCondition,
    required this.isTruthy,
  });

  /// Evaluate an expression string using the original regex-based logic.
  /// This is the fallback for RawExpr nodes.
  dynamic evaluateRaw(String expression, Map<String, dynamic> context) {
    expression = expression.trim();
    if (expression.isEmpty) return null;

    // Check for Python-style ternary FIRST
    final ternaryMatch = _ternaryRegex.firstMatch(expression);
    if (ternaryMatch != null) {
      final trueValue = ternaryMatch.group(1)!.trim();
      final condition = ternaryMatch.group(2)!.trim();
      final falseValue = ternaryMatch.group(3)!.trim();
      return evaluateCondition(condition, context)
          ? evaluate(trueValue, context)
          : evaluate(falseValue, context);
    }

    // String literal
    if ((expression.startsWith("'") && expression.endsWith("'")) ||
        (expression.startsWith('"') && expression.endsWith('"'))) {
      return expression.substring(1, expression.length - 1);
    }

    // Numeric literal
    final numValue = num.tryParse(expression);
    if (numValue != null) return numValue;

    // Boolean literals
    if (expression == 'True' || expression == 'true') return true;
    if (expression == 'False' || expression == 'false') return false;
    if (expression == 'None' || expression == 'null') return null;

    // Check for list comprehension FIRST: [expr for var in iterable]
    if (expression.startsWith('[') && expression.endsWith(']')) {
      final inner = expression.substring(1, expression.length - 1).trim();
      final forMatch = _listCompSimpleRegex.firstMatch(inner);
      if (forMatch != null) {
        return _evaluateListComprehension(
          forMatch.group(1)!,
          forMatch.group(2)!,
          forMatch.group(3)!,
          context,
        );
      }
      return _evaluateLiteralList(inner, context);
    }

    // Unwrap outer parentheses
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
        return evaluate(
            expression.substring(1, expression.length - 1), context);
      }
    }

    // Check for operators
    if (ExpressionParser.containsOperator(expression)) {
      return _evaluateOperation(expression, context);
    }

    // Check for list/index access BEFORE function calls
    if (expression.contains('[')) {
      int bracketIdx = ExpressionParser.findFirstTopLevelBracket(expression);
      if (bracketIdx != -1) {
        return _evaluateIndexAccess(expression, context);
      }
    }

    // Check for function calls
    if (expression.contains('(') && expression.endsWith(')')) {
      return _evaluateFunctionCall(expression, context);
    }

    // Simple variable or dot notation
    return _evaluatePath(expression, context);
  }

  /// Evaluate a list comprehension: [expr for var in iterable]
  List<dynamic> _evaluateListComprehension(
    String expr,
    String varName,
    String iterableExpr,
    Map<String, dynamic> context,
  ) {
    final iterable = evaluate(iterableExpr.trim(), context);
    if (iterable is! List) return [];

    final result = <dynamic>[];
    for (final item in iterable) {
      final innerContext = Map<String, dynamic>.from(context);
      innerContext[varName] = item;
      result.add(evaluate(expr.trim(), innerContext));
    }
    return result;
  }

  /// Evaluate a generator expression: expr for var in iterable [if condition]
  List<dynamic> _evaluateGeneratorExpression(
    String genExpr,
    Map<String, dynamic> context,
  ) {
    final forMatch = _listCompWithFilterRegex.firstMatch(genExpr.trim());
    if (forMatch == null) return [];

    final expr = forMatch.group(1)!.trim();
    final varName = forMatch.group(2)!.trim();
    final iterableExpr = forMatch.group(3)!.trim();
    final conditionExpr = forMatch.group(4)?.trim();

    final iterable = evaluate(iterableExpr, context);
    if (iterable is! List || iterable.isEmpty) return [];

    final result = <dynamic>[];
    for (final item in iterable) {
      final innerContext = Map<String, dynamic>.from(context);
      innerContext[varName] = item;

      if (conditionExpr != null) {
        final condResult = evaluate(conditionExpr, innerContext);
        if (!isTruthy(condResult)) continue;
      }

      result.add(evaluate(expr, innerContext));
    }
    return result;
  }

  /// Evaluate a literal list like [1, 2, 3]
  dynamic _evaluateLiteralList(String inner, Map<String, dynamic> context) {
    if (inner.isEmpty) return [];
    final items = _splitListItems(inner);
    return items.map((item) => evaluate(item.trim(), context)).toList();
  }

  /// Split list items by comma, respecting nested brackets
  List<String> _splitListItems(String inner) {
    final items = <String>[];
    var depth = 0;
    var start = 0;

    for (var i = 0; i < inner.length; i++) {
      final c = inner[i];
      if (c == '[' || c == '(' || c == '{') {
        depth++;
      } else if (c == ']' || c == ')' || c == '}') {
        depth--;
      } else if (c == ',' && depth == 0) {
        items.add(inner.substring(start, i));
        start = i + 1;
      }
    }
    if (start < inner.length) {
      items.add(inner.substring(start));
    }
    return items;
  }

  /// Evaluate an expression with operators
  dynamic _evaluateOperation(String expression, Map<String, dynamic> context) {
    final ternaryMatch = _ternaryRegex.firstMatch(expression);
    if (ternaryMatch != null) {
      final trueValue = ternaryMatch.group(1)!.trim();
      final condition = ternaryMatch.group(2)!.trim();
      final falseValue = ternaryMatch.group(3)!.trim();
      return evaluateCondition(condition, context)
          ? evaluate(trueValue, context)
          : evaluate(falseValue, context);
    }

    // Handle 'and' / 'or' first (lowest precedence)
    if (expression.contains(' and ')) {
      final parts = expression.split(' and ');
      dynamic result;
      for (final part in parts) {
        result = evaluate(part.trim(), context);
        if (!isTruthy(result)) return result;
      }
      return result;
    }

    if (expression.contains(' or ')) {
      final parts = expression.split(' or ');
      dynamic result;
      for (final part in parts) {
        result = evaluate(part.trim(), context);
        if (isTruthy(result)) return result;
      }
      return result;
    }

    // Handle 'not'
    if (expression.startsWith('not ')) {
      final inner = expression.substring(4).trim();
      return !evaluateCondition(inner, context);
    }

    // Handle comparisons
    for (final op in ['==', '!=', '>=', '<=', '>', '<']) {
      if (expression.contains(op)) {
        final parts = expression.split(op);
        if (parts.length == 2) {
          final left = evaluate(parts[0].trim(), context);
          final right = evaluate(parts[1].trim(), context);
          return _compare(left, right, op);
        }
      }
    }

    // Handle 'in' operator
    if (expression.contains(' in ')) {
      final parts = expression.split(' in ');
      if (parts.length == 2) {
        final item = evaluate(parts[0].trim(), context);
        final collection = evaluate(parts[1].trim(), context);
        if (collection is List) return collection.contains(item);
        if (collection is String) return collection.contains(item.toString());
        if (collection is Map) return collection.containsKey(item);
        return false;
      }
    }

    // Handle arithmetic
    for (final op in ['+', '-', '*', '/', '%']) {
      final opIndex = ExpressionParser.findOperatorIndex(expression, op);
      if (opIndex > 0) {
        final left = evaluate(expression.substring(0, opIndex).trim(), context);
        final right =
            evaluate(expression.substring(opIndex + 1).trim(), context);
        return _arithmetic(left, right, op);
      }
    }

    // Fallback to path evaluation
    return _evaluatePath(expression, context);
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

  /// Evaluate a function call
  dynamic _evaluateFunctionCall(
      String expression, Map<String, dynamic> context) {
    final parenIndex = expression.indexOf('(');
    final funcPath = expression.substring(0, parenIndex);
    final argsStr = expression.substring(parenIndex + 1, expression.length - 1);

    final func = _evaluatePath(funcPath, context);
    final args = _parseArguments(argsStr, context);

    final funcName = funcPath.split('.').last;
    switch (funcName) {
      case 'len':
        if (args.isNotEmpty) {
          final val = args[0];
          if (val is String) return val.length;
          if (val is List) return val.length;
          if (val is Map) return val.length;
        }
        return 0;

      case 'str':
        return args.isNotEmpty ? args[0]?.toString() ?? '' : '';

      case 'int':
        if (args.isNotEmpty) {
          final val = args[0];
          if (val is num) return val.toInt();
          if (val is String) return int.tryParse(val) ?? 0;
        }
        return 0;

      case 'float':
        if (args.isNotEmpty) {
          final val = args[0];
          if (val is num) return val.toDouble();
          if (val is String) return double.tryParse(val) ?? 0.0;
        }
        return 0.0;

      case 'format':
        if (args.isNotEmpty && args[0] is String) {
          return _formatString(args[0] as String, args.sublist(1));
        }
        return '';

      case 'join':
        final targetPath =
            funcPath.substring(0, funcPath.length - 5); // Remove '.join'
        final trimmed = targetPath.trim();
        if ((trimmed.startsWith("'") && trimmed.endsWith("'")) ||
            (trimmed.startsWith('"') && trimmed.endsWith('"'))) {
          final separator = trimmed.substring(1, trimmed.length - 1);
          if (argsStr.contains(' for ') && argsStr.contains(' in ')) {
            final items = _evaluateGeneratorExpression(argsStr, context);
            return items
                .map((e) => e?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .join(separator);
          }
          if (args.isNotEmpty && args[0] is List) {
            return (args[0] as List)
                .map((e) => e?.toString() ?? '')
                .where((s) => s.isNotEmpty)
                .join(separator);
          }
          return '';
        }
        final target = _evaluatePath(targetPath, context);
        if (target is List && args.isNotEmpty) {
          return target.map((e) => e.toString()).join(args[0].toString());
        }
        return '';

      case 'split':
        final target =
            _evaluatePath(funcPath.substring(0, funcPath.length - 6), context);
        if (target is String && args.isNotEmpty) {
          return target.split(args[0].toString());
        }
        return [];

      case 'strip':
      case 'trim':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is String) return target.trim();
        return target;

      case 'startswith':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is String && args.isNotEmpty) {
          return target.startsWith(args[0].toString());
        }
        return false;

      case 'endswith':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is String && args.isNotEmpty) {
          return target.endsWith(args[0].toString());
        }
        return false;

      case 'upper':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is String) return target.toUpperCase();
        return target;

      case 'lower':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is String) return target.toLowerCase();
        return target;

      case 'round':
        if (args.isNotEmpty) {
          final val = args[0];
          final decimals = args.length > 1 ? (args[1] as num).toInt() : 0;
          if (val is num) {
            final multiplier = _pow10(decimals);
            return (val * multiplier).round() / multiplier;
          }
        }
        return 0;

      case 'any':
        if (argsStr.contains(' for ') && argsStr.contains(' in ')) {
          return _evaluateAnyAllGenerator(argsStr, context, isAny: true);
        }
        if (args.isNotEmpty && args[0] is List) {
          return (args[0] as List).any((e) => isTruthy(e));
        }
        return false;

      case 'all':
        if (argsStr.contains(' for ') && argsStr.contains(' in ')) {
          return _evaluateAnyAllGenerator(argsStr, context, isAny: false);
        }
        if (args.isNotEmpty && args[0] is List) {
          return (args[0] as List).every((e) => isTruthy(e));
        }
        return true;

      case 'bool':
        if (args.isNotEmpty) return isTruthy(args[0]);
        return false;

      case 'range':
        if (args.isEmpty) return <int>[];
        final start = args.length > 1 ? (args[0] as num).toInt() : 0;
        final stop = args.length > 1
            ? (args[1] as num).toInt()
            : (args[0] as num).toInt();
        final step = args.length > 2 ? (args[2] as num).toInt() : 1;
        if (step == 0) return <int>[];
        final result = <int>[];
        if (step > 0) {
          for (int i = start; i < stop; i += step) {
            result.add(i);
          }
        } else {
          for (int i = start; i > stop; i += step) {
            result.add(i);
          }
        }
        return result;

      case 'min':
        if (args.isEmpty) return null;
        if (args.length == 1 && args[0] is List) {
          final list = args[0] as List;
          if (list.isEmpty) return null;
          return list
              .reduce((a, b) => (a as Comparable).compareTo(b) < 0 ? a : b);
        }
        return args
            .reduce((a, b) => (a as Comparable).compareTo(b) < 0 ? a : b);

      case 'max':
        if (args.isEmpty) return null;
        if (args.length == 1 && args[0] is List) {
          final list = args[0] as List;
          if (list.isEmpty) return null;
          return list
              .reduce((a, b) => (a as Comparable).compareTo(b) > 0 ? a : b);
        }
        return args
            .reduce((a, b) => (a as Comparable).compareTo(b) > 0 ? a : b);

      case 'sum':
        if (argsStr.contains(' for ') && argsStr.contains(' in ')) {
          return _evaluateSumGenerator(argsStr, context);
        }
        if (args.isNotEmpty && args[0] is List) {
          final list = args[0] as List;
          num total = 0;
          for (final item in list) {
            if (item is num) total += item;
          }
          return total;
        }
        return 0;

      case 'sorted':
        if (args.isNotEmpty && args[0] is List) {
          final list = List.from(args[0] as List);
          list.sort();
          return list;
        }
        return [];

      case 'reversed':
        if (args.isNotEmpty && args[0] is List) {
          return (args[0] as List).reversed.toList();
        }
        return [];

      case 'list':
        if (args.isNotEmpty) {
          if (args[0] is List) return List.from(args[0] as List);
          if (args[0] is String) return (args[0] as String).split('');
          if (args[0] is Map) return (args[0] as Map).keys.toList();
        }
        return [];

      case 'dict':
        if (args.isNotEmpty && args[0] is List) {
          final result = <dynamic, dynamic>{};
          for (final item in args[0] as List) {
            if (item is List && item.length >= 2) {
              result[item[0]] = item[1];
            }
          }
          return result;
        }
        return {};

      case 'enumerate':
        if (args.isNotEmpty && args[0] is List) {
          final list = args[0] as List;
          return list.asMap().entries.map((e) => [e.key, e.value]).toList();
        }
        return [];

      case 'zip':
        if (args.isEmpty) return [];
        final lists = args.whereType<List>().toList();
        if (lists.isEmpty) return [];
        final minLen =
            lists.map((l) => l.length).reduce((a, b) => a < b ? a : b);
        final result = <List>[];
        for (int i = 0; i < minLen; i++) {
          result.add(lists.map((l) => l[i]).toList());
        }
        return result;

      case 'find':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is String && args.isNotEmpty) {
          return target.indexOf(args[0].toString());
        }
        return -1;

      case 'replace':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is String && args.length >= 2) {
          return target.replaceAll(args[0].toString(), args[1].toString());
        }
        return target;

      case 'get':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is Map && args.isNotEmpty) {
          final key = args[0];
          final defaultVal = args.length > 1 ? args[1] : null;
          return target.containsKey(key) ? target[key] : defaultVal;
        }
        return args.length > 1 ? args[1] : null;

      case 'keys':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is Map) return target.keys.toList();
        return [];

      case 'values':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is Map) return target.values.toList();
        return [];

      case 'items':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is Map) {
          return target.entries.map((e) => [e.key, e.value]).toList();
        }
        return [];

      case 'append':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is List && args.isNotEmpty) target.add(args[0]);
        return null;

      case 'extend':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is List && args.isNotEmpty && args[0] is List) {
          target.addAll(args[0] as List);
        }
        return null;

      case 'update':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is Map && args.isNotEmpty && args[0] is Map) {
          target.addAll(args[0] as Map);
        }
        return null;

      case 'contains':
        final target = _evaluatePath(
            funcPath.substring(0, funcPath.lastIndexOf('.')), context);
        if (target is String && args.isNotEmpty) {
          return target.contains(args[0].toString());
        }
        if (target is List) return target.contains(args[0]);
        return false;

      default:
        if (func is Function) {
          try {
            return Function.apply(func, args);
          } catch (e, _) {
            return null;
          }
        }
        return func;
    }
  }

  double _pow10(int exponent) {
    double result = 1;
    for (int i = 0; i < exponent; i++) {
      result *= 10;
    }
    return result;
  }

  /// Parse function arguments
  List<dynamic> _parseArguments(String argsStr, Map<String, dynamic> context) {
    if (argsStr.trim().isEmpty) return [];

    final args = <dynamic>[];
    var current = '';
    var depth = 0;
    var inString = false;
    String? stringChar;

    for (var i = 0; i < argsStr.length; i++) {
      final char = argsStr[i];

      if (!inString && (char == '"' || char == "'")) {
        inString = true;
        stringChar = char;
        current += char;
      } else if (inString && char == stringChar) {
        inString = false;
        stringChar = null;
        current += char;
      } else if (!inString && (char == '(' || char == '[' || char == '{')) {
        depth++;
        current += char;
      } else if (!inString && (char == ')' || char == ']' || char == '}')) {
        depth--;
        current += char;
      } else if (!inString && depth == 0 && char == ',') {
        args.add(_evaluateArgument(current.trim(), context));
        current = '';
      } else {
        current += char;
      }
    }

    if (current.trim().isNotEmpty) {
      args.add(_evaluateArgument(current.trim(), context));
    }

    return args;
  }

  /// Evaluate a single argument, handling keyword arguments like "key=value"
  dynamic _evaluateArgument(String arg, Map<String, dynamic> context) {
    final kwargMatch = RegExp(r'^(\w+)=(?!=)(.+)$').firstMatch(arg);
    if (kwargMatch != null) {
      final value = kwargMatch.group(2)!.trim();
      return evaluate(value, context);
    }
    return evaluate(arg, context);
  }

  /// Format string with arguments (Python-like)
  String _formatString(String format, List<dynamic> args) {
    var result = format;
    for (var i = 0; i < args.length; i++) {
      result = result.replaceFirst('{}', args[i]?.toString() ?? '');
      result = result.replaceAll('{$i}', args[i]?.toString() ?? '');
    }
    return result;
  }

  /// Evaluate index/key access
  dynamic _evaluateIndexAccess(
      String expression, Map<String, dynamic> context) {
    final bracketIndex = ExpressionParser.findFirstTopLevelBracket(expression);
    if (bracketIndex == -1) return null;

    final path = expression.substring(0, bracketIndex);

    int closingBracket = _findMatchingBracket(expression, bracketIndex);
    if (closingBracket == -1) return null;

    final indexExpr = expression.substring(bracketIndex + 1, closingBracket);

    String? suffixExpr;
    if (closingBracket < expression.length - 1) {
      suffixExpr = expression.substring(closingBracket + 1);
    }

    final target = evaluate(path, context);

    // Slice notation
    if (_containsTopLevelColon(indexExpr)) {
      final colonIndex = _findTopLevelColon(indexExpr);
      final startExpr = indexExpr.substring(0, colonIndex).trim();
      final endExpr = indexExpr.substring(colonIndex + 1).trim();

      final start = startExpr.isEmpty ? null : evaluate(startExpr, context);
      final end = endExpr.isEmpty ? null : evaluate(endExpr, context);

      dynamic sliceResult;

      if (target is String) {
        final startIdx = start as int? ?? 0;
        final endIdx = end as int? ?? target.length;
        final actualStart = startIdx < 0 ? target.length + startIdx : startIdx;
        final actualEnd = endIdx < 0 ? target.length + endIdx : endIdx;
        final safeStart = actualStart.clamp(0, target.length);
        final safeEnd = actualEnd.clamp(0, target.length);
        sliceResult =
            safeStart <= safeEnd ? target.substring(safeStart, safeEnd) : '';
      } else if (target is List) {
        final startIdx = start as int? ?? 0;
        final endIdx = end as int? ?? target.length;
        final actualStart = startIdx < 0 ? target.length + startIdx : startIdx;
        final actualEnd = endIdx < 0 ? target.length + endIdx : endIdx;
        final safeStart = actualStart.clamp(0, target.length);
        final safeEnd = actualEnd.clamp(0, target.length);
        sliceResult =
            safeStart <= safeEnd ? target.sublist(safeStart, safeEnd) : [];
      }

      if (suffixExpr != null && suffixExpr.isNotEmpty && sliceResult != null) {
        final tempContext = Map<String, dynamic>.from(context);
        tempContext['__temp_slice_result__'] = sliceResult;
        return evaluate('__temp_slice_result__$suffixExpr', tempContext);
      }
      return sliceResult;
    }

    // Regular index access
    final index = evaluate(indexExpr, context);
    dynamic result;

    if (target is List && index is int) {
      final actualIndex = index < 0 ? target.length + index : index;
      if (actualIndex >= 0 && actualIndex < target.length) {
        result = target[actualIndex];
      }
    } else if (target is String && index is int) {
      final actualIndex = index < 0 ? target.length + index : index;
      if (actualIndex >= 0 && actualIndex < target.length) {
        result = target[actualIndex];
      }
    } else if (target is Map) {
      result = target[index];
    }

    if (suffixExpr != null && suffixExpr.isNotEmpty && result != null) {
      final tempContext = Map<String, dynamic>.from(context);
      tempContext['__temp_slice_result__'] = result;
      return evaluate('__temp_slice_result__$suffixExpr', tempContext);
    }
    return result;
  }

  int _findMatchingBracket(String expr, int openBracketIndex) {
    int depth = 0;
    bool inString = false;
    String stringChar = '';

    for (int i = openBracketIndex; i < expr.length; i++) {
      final char = expr[i];
      if (!inString && (char == '"' || char == "'")) {
        inString = true;
        stringChar = char;
      } else if (inString && char == stringChar) {
        if (i > 0 && expr[i - 1] != '\\') inString = false;
      } else if (!inString) {
        if (char == '[' || char == '(') {
          depth++;
        } else if (char == ']' || char == ')') {
          depth--;
          if (depth == 0 && char == ']') return i;
        }
      }
    }
    return -1;
  }

  bool _containsTopLevelColon(String expr) => _findTopLevelColon(expr) != -1;

  int _findTopLevelColon(String expr) {
    int depth = 0;
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
        if (char == '(' || char == '[') {
          depth++;
        } else if (char == ')' || char == ']') {
          depth--;
        } else if (char == ':' && depth == 0) {
          return i;
        }
      }
    }
    return -1;
  }

  /// Evaluate a dot-notation path
  dynamic _evaluatePath(String path, Map<String, dynamic> context) {
    final parts = path.split('.');
    dynamic current = context;

    for (final part in parts) {
      if (current == null) return null;
      if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Format a value with options (for t-field)
  String formatValue(
    dynamic value,
    Map<String, dynamic>? options,
    Map<String, dynamic> context,
  ) {
    if (value == null) return '';

    final widget = options?['widget'] as String?;
    final currencySymbol = context['_currency_symbol'] ?? '\$';

    switch (widget) {
      case 'monetary':
        final currency = options?['display_currency'];
        String symbol = currencySymbol;

        if (currency is Map && currency['symbol'] != null) {
          symbol = currency['symbol'].toString();
        } else {
          final lineCurrency = context['line'] is Map
              ? (context['line'] as Map)['currency_id']
              : null;
          if (lineCurrency is Map && lineCurrency['symbol'] != null) {
            symbol = lineCurrency['symbol'].toString();
          } else {
            final docCurrency = context['doc'] is Map
                ? (context['doc'] as Map)['currency_id']
                : null;
            if (docCurrency is Map && docCurrency['symbol'] != null) {
              symbol = docCurrency['symbol'].toString();
            } else {
              final rootCurrency = context['currency_id'];
              if (rootCurrency is Map && rootCurrency['symbol'] != null) {
                symbol = rootCurrency['symbol'].toString();
              }
            }
          }
        }

        if (value is num) {
          return '$symbol ${value.toStringAsFixed(2)}';
        }
        return '$symbol $value';

      case 'float':
        final precision = options?['precision'] as int? ??
            options?['decimal_precision'] as int? ??
            2;
        if (value is num) return value.toStringAsFixed(precision);
        return value.toString();

      case 'integer':
        if (value is num) return value.toInt().toString();
        return value.toString();

      case 'date':
        if (value is DateTime) {
          return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}';
        }
        return value.toString();

      case 'datetime':
        if (value is DateTime) {
          return '${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year} ${value.hour.toString().padLeft(2, '0')}:${value.minute.toString().padLeft(2, '0')}';
        }
        return value.toString();

      case 'text':
        return value.toString();

      case 'contact':
        if (value is Map) {
          final fields = options?['fields'] as List<dynamic>?;
          final parts = <String>[];
          for (final field in fields ?? ['name', 'address']) {
            final fieldValue = value[field];
            if (fieldValue != null && fieldValue.toString().isNotEmpty) {
              parts.add(fieldValue.toString());
            }
          }
          return parts.join('\n');
        }
        return value.toString();

      case 'duration':
        if (value is num) {
          final seconds = value.toInt().abs();
          final hours = seconds ~/ 3600;
          final mins = (seconds % 3600) ~/ 60;
          final secs = seconds % 60;
          final parts = <String>[];
          if (hours > 0) parts.add('$hours h');
          if (mins > 0) parts.add('$mins min');
          if (parts.isEmpty && secs > 0) parts.add('$secs sec');
          return parts.isEmpty ? '0 sec' : parts.join(' ');
        }
        return value.toString();

      case 'relative':
        if (value is DateTime) {
          final now = DateTime.now();
          final diff = now.difference(value);
          final inFuture = diff.isNegative;
          final absDiff = diff.abs();

          String timeStr;
          if (absDiff.inDays >= 365) {
            final years = absDiff.inDays ~/ 365;
            timeStr = '$years ${years == 1 ? 'year' : 'years'}';
          } else if (absDiff.inDays >= 30) {
            final months = absDiff.inDays ~/ 30;
            timeStr = '$months ${months == 1 ? 'month' : 'months'}';
          } else if (absDiff.inDays > 0) {
            timeStr =
                '${absDiff.inDays} ${absDiff.inDays == 1 ? 'day' : 'days'}';
          } else if (absDiff.inHours > 0) {
            timeStr =
                '${absDiff.inHours} ${absDiff.inHours == 1 ? 'hour' : 'hours'}';
          } else if (absDiff.inMinutes > 0) {
            timeStr =
                '${absDiff.inMinutes} ${absDiff.inMinutes == 1 ? 'minute' : 'minutes'}';
          } else {
            return 'just now';
          }
          return inFuture ? 'in $timeStr' : '$timeStr ago';
        }
        return value.toString();

      case 'image':
        if (value is String && value.isNotEmpty) {
          if (value.startsWith('data:')) return value;
          return 'data:image/png;base64,$value';
        }
        return '';

      case 'html':
        return value.toString();

      case 'selection':
        if (value is List && value.length >= 2) return value[1].toString();
        if (value is Map && value['name'] != null) {
          return value['name'].toString();
        }
        return value.toString();

      case 'many2one':
        if (value is List && value.length >= 2) return value[1].toString();
        if (value is Map) {
          return (value['display_name'] ?? value['name'] ?? '').toString();
        }
        return value.toString();

      case 'many2many':
      case 'one2many':
        if (value is List) {
          final names = value.map((item) {
            if (item is List && item.length >= 2) return item[1].toString();
            if (item is Map) {
              return (item['display_name'] ?? item['name'] ?? '').toString();
            }
            return item.toString();
          }).where((s) => s.isNotEmpty);
          return names.join(', ');
        }
        return value.toString();

      default:
        if (value is Map) {
          if (value.containsKey('id')) {
            return (value['display_name'] ?? value['name'] ?? value.toString())
                .toString();
          }
          if (value.containsKey('name')) return value['name'].toString();
        }
        return value.toString();
    }
  }

  /// Evaluate generator expression for any() or all().
  bool _evaluateAnyAllGenerator(
    String genExpr,
    Map<String, dynamic> context, {
    required bool isAny,
  }) {
    if (_kDebugAnyAll) {
      // ignore: avoid_print
      print('[ExprEval] ${isAny ? "any" : "all"}() called with: $genExpr');
    }

    final forMatch = _listCompWithFilterRegex.firstMatch(genExpr.trim());
    if (forMatch == null) return isAny ? false : true;

    final expr = forMatch.group(1)!.trim();
    final varName = forMatch.group(2)!.trim();
    final iterableExpr = forMatch.group(3)!.trim();
    final conditionExpr = forMatch.group(4)?.trim();

    final iterable = evaluate(iterableExpr, context);
    if (iterable is! List || iterable.isEmpty) return isAny ? false : true;

    int itemIndex = 0;
    for (final item in iterable) {
      final innerContext = Map<String, dynamic>.from(context);
      innerContext[varName] = item;

      if (conditionExpr != null) {
        final condResult = evaluate(conditionExpr, innerContext);
        if (!isTruthy(condResult)) continue;
      }

      final result = evaluate(expr, innerContext);
      final truthy = isTruthy(result);

      if (_kDebugAnyAll && itemIndex < 5) {
        final itemName = item is Map
            ? (item['name'] ?? item['product_id']?['name'] ?? 'item')
            : 'item';
        // ignore: avoid_print
        print(
            '[ExprEval] Item $itemIndex ($itemName): result=$result, truthy=$truthy');
      }

      if (isAny && truthy) return true;
      if (!isAny && !truthy) return false;
      itemIndex++;
    }

    return isAny ? false : true;
  }

  /// Evaluate generator expression for sum().
  num _evaluateSumGenerator(
    String genExpr,
    Map<String, dynamic> context,
  ) {
    final forMatch = _listCompWithFilterRegex.firstMatch(genExpr.trim());
    if (forMatch == null) return 0;

    final expr = forMatch.group(1)!.trim();
    final varName = forMatch.group(2)!.trim();
    final iterableExpr = forMatch.group(3)!.trim();
    final conditionExpr = forMatch.group(4)?.trim();

    final iterable = evaluate(iterableExpr, context);
    if (iterable is! List || iterable.isEmpty) return 0;

    num total = 0;
    for (final item in iterable) {
      final innerContext = Map<String, dynamic>.from(context);
      innerContext[varName] = item;

      if (conditionExpr != null) {
        final condResult = evaluate(conditionExpr, innerContext);
        if (!isTruthy(condResult)) continue;
      }

      final result = evaluate(expr, innerContext);
      if (result is num) {
        total += result;
      } else if (result is String) {
        final parsed = num.tryParse(result);
        if (parsed != null) total += parsed;
      }
    }
    return total;
  }
}
