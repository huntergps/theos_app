/// QWeb AST Nodes
///
/// Represents the Abstract Syntax Tree nodes for QWeb templates.
/// Each node type corresponds to a QWeb directive or HTML element.
library;

/// Base class for all QWeb AST nodes
sealed class QWebNode {
  const QWebNode();
}

/// Text content node
class QWebTextNode extends QWebNode {
  final String text;

  const QWebTextNode({required this.text});

  @override
  String toString() =>
      'TextNode("${text.length > 20 ? '${text.substring(0, 20)}...' : text}")';
}

/// HTML/XML element node
class QWebElementNode extends QWebNode {
  final String tagName;
  final Map<String, String> attributes;
  final List<QWebNode> children;

  const QWebElementNode({
    required this.tagName,
    this.attributes = const {},
    this.children = const [],
  });

  @override
  String toString() => 'ElementNode(<$tagName>, ${children.length} children)';
}

/// Fragment node (multiple children without wrapper)
class QWebFragmentNode extends QWebNode {
  final List<QWebNode> children;

  const QWebFragmentNode({required this.children});

  @override
  String toString() => 'FragmentNode(${children.length} children)';
}

/// Conditional node (t-if)
class QWebIfNode extends QWebNode {
  final String condition;
  final QWebNode thenBranch;
  final QWebNode? elseBranch;

  const QWebIfNode({
    required this.condition,
    required this.thenBranch,
    this.elseBranch,
  });

  @override
  String toString() => 'IfNode($condition)';
}

/// Loop node (t-foreach)
class QWebForEachNode extends QWebNode {
  final String expression;
  final String itemVariable;
  final QWebNode child;

  const QWebForEachNode({
    required this.expression,
    required this.itemVariable,
    required this.child,
  });

  /// Get the index variable name (item_index)
  String get indexVariable => '${itemVariable}_index';

  /// Get the first flag variable name (item_first)
  String get firstVariable => '${itemVariable}_first';

  /// Get the last flag variable name (item_last)
  String get lastVariable => '${itemVariable}_last';

  /// Get the size variable name (item_size)
  String get sizeVariable => '${itemVariable}_size';

  /// Get the value variable name (item_value) - alias for item
  String get valueVariable => '${itemVariable}_value';

  /// Get the odd flag variable name (item_odd) - true if index is odd
  String get oddVariable => '${itemVariable}_odd';

  /// Get the even flag variable name (item_even) - true if index is even
  String get evenVariable => '${itemVariable}_even';

  /// Get the parity variable name (item_parity) - 'odd' or 'even' string
  String get parityVariable => '${itemVariable}_parity';

  @override
  String toString() => 'ForEachNode($expression as $itemVariable)';
}

/// Variable assignment node (t-set with t-value)
class QWebSetNode extends QWebNode {
  final String variableName;
  final String expression;

  const QWebSetNode({
    required this.variableName,
    required this.expression,
  });

  @override
  String toString() => 'SetNode($variableName = $expression)';
}

/// Variable assignment with content (t-set without t-value)
class QWebSetContentNode extends QWebNode {
  final String variableName;
  final List<QWebNode> children;

  const QWebSetContentNode({
    required this.variableName,
    required this.children,
  });

  @override
  String toString() => 'SetContentNode($variableName)';
}

/// Escaped output node (t-esc)
class QWebEscNode extends QWebNode {
  final String expression;
  final String? options;

  const QWebEscNode({required this.expression, this.options});

  @override
  String toString() => 'EscNode($expression${options != null ? ', options: $options' : ''})';
}

/// Raw output node (t-out, t-raw)
class QWebOutNode extends QWebNode {
  final String expression;

  /// Default content to render if expression evaluates to null/false
  final List<QWebNode> children;

  const QWebOutNode({
    required this.expression,
    this.children = const [],
  });

  @override
  String toString() => 'OutNode($expression)';
}

/// Field rendering node (t-field)
class QWebFieldNode extends QWebNode {
  final String expression;
  final String? options;

  const QWebFieldNode({
    required this.expression,
    this.options,
  });

  @override
  String toString() => 'FieldNode($expression)';
}

/// Template call node (t-call)
class QWebCallNode extends QWebNode {
  final String templateName;
  final List<QWebNode> children;

  const QWebCallNode({
    required this.templateName,
    this.children = const [],
  });

  @override
  String toString() => 'CallNode($templateName)';
}

/// Dynamic attributes node (t-att-*, t-attf-*)
class QWebDynamicAttrsNode extends QWebNode {
  final QWebNode child;
  final Map<String, String> dynamicAttrs; // t-att-name="expr"
  final Map<String, String> formatAttrs; // t-attf-name="text {{expr}} text"

  const QWebDynamicAttrsNode({
    required this.child,
    this.dynamicAttrs = const {},
    this.formatAttrs = const {},
  });

  @override
  String toString() =>
      'DynamicAttrsNode(${dynamicAttrs.length + formatAttrs.length} attrs)';
}

/// Attribute conditional node (t-att)
class QWebAttNode extends QWebNode {
  final String expression; // Returns map or tuple
  final QWebNode child;

  const QWebAttNode({
    required this.expression,
    required this.child,
  });

  @override
  String toString() => 'AttNode($expression)';
}
