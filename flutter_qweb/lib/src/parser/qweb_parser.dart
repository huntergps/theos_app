import 'package:xml/xml.dart';

import 'qweb_node.dart';

/// Parser for QWeb XML templates
///
/// Converts QWeb XML into an Abstract Syntax Tree (AST) that can be
/// evaluated with a data context.
class QWebParser {
  /// Parse XML string into QWeb AST
  QWebNode parse(String xmlContent) {
    try {
      final document = XmlDocument.parse(xmlContent);
      return _parseElement(document.rootElement);
    } catch (e) {
      // If parsing fails, try wrapping in a root element
      try {
        final wrapped = '<root>$xmlContent</root>';
        final document = XmlDocument.parse(wrapped);
        return _parseElement(document.rootElement);
      } catch (e2) {
        throw QWebParseException('Failed to parse QWeb template: $e');
      }
    }
  }

  /// Parse an XML element into a QWeb node
  QWebNode _parseElement(XmlElement element) {
    final tagName = element.name.local;
    final attributes = <String, String>{};
    final qwebDirectives = <String, String>{};

    // Separate QWeb directives (t-*) from regular attributes
    for (final attr in element.attributes) {
      final name = attr.name.local;
      final value = attr.value;

      if (name.startsWith('t-')) {
        qwebDirectives[name] = value;
      } else {
        attributes[name] = value;
      }
    }

    // Check for special QWeb elements
    if (tagName == 't') {
      return _parseQWebElement(element, qwebDirectives, attributes);
    }

    // Check for QWeb directives on regular elements
    if (qwebDirectives.isNotEmpty) {
      return _parseElementWithDirectives(
        element,
        tagName,
        qwebDirectives,
        attributes,
      );
    }

    // Regular HTML/XML element
    final children = _parseChildren(element);
    return QWebElementNode(
      tagName: tagName,
      attributes: attributes,
      children: children,
    );
  }

  /// Parse `<t>` element with QWeb directives
  QWebNode _parseQWebElement(
    XmlElement element,
    Map<String, String> directives,
    Map<String, String> attributes,
  ) {
    // t-if: Conditional rendering
    if (directives.containsKey('t-if')) {
      return _parseConditional(element, directives);
    }

    // t-foreach: Loop
    if (directives.containsKey('t-foreach')) {
      return _parseLoop(element, directives);
    }

    // t-set: Variable assignment
    if (directives.containsKey('t-set')) {
      return _parseSetVariable(element, directives);
    }

    // t-call: Template call
    if (directives.containsKey('t-call')) {
      return QWebCallNode(
        templateName: directives['t-call']!,
        children: _parseChildren(element),
      );
    }

    // t-esc: Escape and output expression
    if (directives.containsKey('t-esc')) {
      return QWebEscNode(
        expression: directives['t-esc']!,
        options: directives['t-options'],
      );
    }

    // t-out / t-raw: Output without escaping (with optional default children)
    if (directives.containsKey('t-out')) {
      return QWebOutNode(
        expression: directives['t-out']!,
        children: _parseChildren(element),
      );
    }
    if (directives.containsKey('t-raw')) {
      return QWebOutNode(
        expression: directives['t-raw']!,
        children: _parseChildren(element),
      );
    }

    // t-field: Field rendering with widget support
    if (directives.containsKey('t-field')) {
      return QWebFieldNode(
        expression: directives['t-field']!,
        options: directives['t-options'],
      );
    }

    // Default: just process children (transparent <t> element)
    final children = _parseChildren(element);
    if (children.length == 1) {
      return children.first;
    }
    return QWebFragmentNode(children: children);
  }

  /// Parse element with QWeb directives (non-`<t>` element)
  QWebNode _parseElementWithDirectives(
    XmlElement element,
    String tagName,
    Map<String, String> directives,
    Map<String, String> attributes,
  ) {
    // Determine children: if t-esc or t-out is present, use that as content
    // Otherwise parse children normally
    List<QWebNode> elementChildren;

    if (directives.containsKey('t-esc')) {
      // t-esc: Replace element content with escaped expression value
      elementChildren = [
        QWebEscNode(
          expression: directives['t-esc']!,
          options: directives['t-options'],
        )
      ];
    } else if (directives.containsKey('t-out') ||
        directives.containsKey('t-raw')) {
      // t-out/t-raw: Replace element content with raw expression value
      final expr = directives['t-out'] ?? directives['t-raw']!;
      elementChildren = [
        QWebOutNode(expression: expr, children: _parseChildren(element))
      ];
    } else {
      // Normal children
      elementChildren = _parseChildren(element);
    }

    QWebNode innerNode = QWebElementNode(
      tagName: tagName,
      attributes: attributes,
      children: elementChildren,
    );

    // Apply directives from innermost to outermost

    // t-att-* and t-attf-*: Dynamic attributes
    final dynamicAttrs = <String, String>{};
    final formatAttrs = <String, String>{};
    for (final entry in directives.entries) {
      if (entry.key.startsWith('t-att-')) {
        final attrName = entry.key.substring(6);
        dynamicAttrs[attrName] = entry.value;
      } else if (entry.key.startsWith('t-attf-')) {
        final attrName = entry.key.substring(7);
        formatAttrs[attrName] = entry.value;
      }
    }

    if (dynamicAttrs.isNotEmpty || formatAttrs.isNotEmpty) {
      innerNode = QWebDynamicAttrsNode(
        child: innerNode,
        dynamicAttrs: dynamicAttrs,
        formatAttrs: formatAttrs,
      );
    }

    // t-field: Replace element content with field value
    // This handles <div t-field="doc.name"/> -> shows doc.name as text
    if (directives.containsKey('t-field')) {
      return QWebFieldNode(
        expression: directives['t-field']!,
        options: directives['t-options'],
      );
    }

    // t-foreach: Wrap in loop
    if (directives.containsKey('t-foreach')) {
      final itemVar = directives['t-as'] ?? 'item';
      innerNode = QWebForEachNode(
        expression: directives['t-foreach']!,
        itemVariable: itemVar,
        child: innerNode,
      );
    }

    // t-if: Wrap in conditional
    if (directives.containsKey('t-if')) {
      // Look for t-elif and t-else siblings (like in _parseConditional)
      QWebNode? elseBranch;
      final siblings =
          element.parent?.children.whereType<XmlElement>().toList() ?? [];
      final currentIndex = siblings.indexOf(element);

      if (currentIndex >= 0 && currentIndex < siblings.length - 1) {
        final nextSibling = siblings[currentIndex + 1];
        final nextDirectives = <String, String>{};
        final nextAttributes = <String, String>{};
        for (final attr in nextSibling.attributes) {
          if (attr.name.local.startsWith('t-')) {
            nextDirectives[attr.name.local] = attr.value;
          } else {
            nextAttributes[attr.name.local] = attr.value;
          }
        }

        if (nextDirectives.containsKey('t-elif')) {
          // Build a new conditional for the elif branch
          // Remove t-elif and treat it like t-if for parsing
          final elifDirectives = Map<String, String>.from(nextDirectives);
          elifDirectives['t-if'] = elifDirectives.remove('t-elif')!;

          elseBranch = _parseElementWithDirectives(
            nextSibling,
            nextSibling.name.local,
            elifDirectives,
            nextAttributes,
          );
        } else if (nextDirectives.containsKey('t-else')) {
          // The else branch - parse without t-else directive
          final elseDirectives = Map<String, String>.from(nextDirectives);
          elseDirectives.remove('t-else');

          if (elseDirectives.isEmpty) {
            // Simple element with just t-else
            elseBranch = QWebElementNode(
              tagName: nextSibling.name.local,
              attributes: nextAttributes,
              children: _parseChildren(nextSibling),
            );
          } else {
            elseBranch = _parseElementWithDirectives(
              nextSibling,
              nextSibling.name.local,
              elseDirectives,
              nextAttributes,
            );
          }
        }
      }

      innerNode = QWebIfNode(
        condition: directives['t-if']!,
        thenBranch: innerNode,
        elseBranch: elseBranch,
      );
    }

    return innerNode;
  }

  /// Parse conditional (t-if, t-elif, t-else)
  QWebNode _parseConditional(
    XmlElement element,
    Map<String, String> directives,
  ) {
    final condition = directives['t-if']!;

    // Check for other output directives on the same element (t-esc, t-out, t-field)
    // This handles patterns like: <t t-if="condition" t-esc="expression"/>
    QWebNode? outputNode;
    if (directives.containsKey('t-esc')) {
      outputNode = QWebEscNode(
        expression: directives['t-esc']!,
        options: directives['t-options'],
      );
    } else if (directives.containsKey('t-out')) {
      outputNode = QWebOutNode(
        expression: directives['t-out']!,
        children: _parseChildren(element),
      );
    } else if (directives.containsKey('t-raw')) {
      outputNode = QWebOutNode(
        expression: directives['t-raw']!,
        children: _parseChildren(element),
      );
    } else if (directives.containsKey('t-field')) {
      outputNode = QWebFieldNode(
        expression: directives['t-field']!,
        options: directives['t-options'],
      );
    }

    // If no output directive, fall back to parsing children
    final children = outputNode != null ? <QWebNode>[outputNode] : _parseChildren(element);

    // Look for t-elif and t-else siblings
    QWebNode? elseBranch;
    final siblings =
        element.parent?.children.whereType<XmlElement>().toList() ?? [];
    final currentIndex = siblings.indexOf(element);

    if (currentIndex >= 0 && currentIndex < siblings.length - 1) {
      final nextSibling = siblings[currentIndex + 1];
      final nextDirectives = <String, String>{};
      for (final attr in nextSibling.attributes) {
        if (attr.name.local.startsWith('t-')) {
          nextDirectives[attr.name.local] = attr.value;
        }
      }

      if (nextDirectives.containsKey('t-elif')) {
        // Convert t-elif to t-if for recursive parsing
        elseBranch = QWebIfNode(
          condition: nextDirectives['t-elif']!,
          thenBranch: QWebFragmentNode(children: _parseChildren(nextSibling)),
          elseBranch: null, // Would need to continue checking
        );
      } else if (nextDirectives.containsKey('t-else')) {
        elseBranch = QWebFragmentNode(children: _parseChildren(nextSibling));
      }
    }

    return QWebIfNode(
      condition: condition,
      thenBranch: children.length == 1
          ? children.first
          : QWebFragmentNode(children: children),
      elseBranch: elseBranch,
    );
  }

  /// Parse loop (t-foreach, t-as)
  QWebNode _parseLoop(XmlElement element, Map<String, String> directives) {
    final expression = directives['t-foreach']!;
    final itemVar = directives['t-as'] ?? 'item';
    final children = _parseChildren(element);

    return QWebForEachNode(
      expression: expression,
      itemVariable: itemVar,
      child: children.length == 1
          ? children.first
          : QWebFragmentNode(children: children),
    );
  }

  /// Parse variable assignment (t-set, t-value)
  QWebNode _parseSetVariable(
    XmlElement element,
    Map<String, String> directives,
  ) {
    final varName = directives['t-set']!;
    final value = directives['t-value'];

    if (value != null) {
      return QWebSetNode(variableName: varName, expression: value);
    }

    // If no t-value, the content becomes the value
    final children = _parseChildren(element);
    return QWebSetContentNode(
      variableName: varName,
      children: children,
    );
  }

  /// Parse child nodes of an element
  List<QWebNode> _parseChildren(XmlElement element) {
    final children = <QWebNode>[];

    for (final child in element.children) {
      if (child is XmlElement) {
        // Skip t-elif and t-else as they're handled by t-if
        final hasElif = child.attributes.any((a) => a.name.local == 't-elif');
        final hasElse = child.attributes.any((a) => a.name.local == 't-else');
        if (!hasElif && !hasElse) {
          children.add(_parseElement(child));
        }
      } else if (child is XmlText) {
        final text = child.value.trim();
        if (text.isNotEmpty) {
          children.add(QWebTextNode(text: child.value));
        }
      }
    }

    return children;
  }
}

/// Exception thrown during QWeb parsing
class QWebParseException implements Exception {
  final String message;

  QWebParseException(this.message);

  @override
  String toString() => 'QWebParseException: $message';
}
