/// Parsed expression AST nodes for the QWeb expression evaluator.
///
/// These represent pre-parsed forms of QWeb/Python-like expressions,
/// enabling a parse-once, evaluate-many optimization via an LRU cache.
library;

/// Base sealed class for all parsed expression types.
sealed class ParsedExpression {
  const ParsedExpression();
}

/// A literal value (string, number, bool, null).
final class LiteralExpr extends ParsedExpression {
  final dynamic value;
  const LiteralExpr(this.value);
}

/// A dot-separated path like "doc.partner_id.name".
final class PathExpr extends ParsedExpression {
  final List<String> segments;
  const PathExpr(this.segments);
}

/// A binary operation like "a + b", "x == 5", "a and b".
final class BinaryOpExpr extends ParsedExpression {
  final ParsedExpression left;
  final String op;
  final ParsedExpression right;
  const BinaryOpExpr(this.left, this.op, this.right);
}

/// A unary operation like "not x".
final class UnaryOpExpr extends ParsedExpression {
  final String op;
  final ParsedExpression operand;
  const UnaryOpExpr(this.op, this.operand);
}

/// A Python-style ternary: "trueExpr if condition else falseExpr".
final class TernaryExpr extends ParsedExpression {
  final ParsedExpression condition;
  final ParsedExpression trueExpr;
  final ParsedExpression falseExpr;
  const TernaryExpr(this.condition, this.trueExpr, this.falseExpr);
}

/// A membership test like "'a' in items".
final class MembershipExpr extends ParsedExpression {
  final ParsedExpression item;
  final ParsedExpression collection;
  const MembershipExpr(this.item, this.collection);
}

/// A parenthesized expression that simply wraps another expression.
final class ParenExpr extends ParsedExpression {
  final ParsedExpression inner;
  const ParenExpr(this.inner);
}

/// Fallback for complex expressions that are not fully parsed into AST form.
/// These are evaluated using the original regex-based path.
final class RawExpr extends ParsedExpression {
  final String source;
  const RawExpr(this.source);
}
