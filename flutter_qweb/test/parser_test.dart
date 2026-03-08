import 'package:test/test.dart';
import 'package:flutter_qweb/src/parser/qweb_parser.dart';
import 'package:flutter_qweb/src/parser/qweb_node.dart';

void main() {
  late QWebParser parser;

  setUp(() {
    parser = QWebParser();
  });

  group('QWebParser', () {
    group('t-if parsing', () {
      test('parses simple t-if', () {
        const xml = '<t t-name="test"><t t-if="active"><span>Active</span></t></t>';
        final root = parser.parse(xml);

        expect(root, isA<QWebNode>());
        // Should contain an if node somewhere in the tree
        final hasIf = _findNodeOfType<QWebIfNode>(root);
        expect(hasIf, isNotNull);
        expect(hasIf!.condition, equals('active'));
      });

      test('parses t-if with t-else', () {
        const xml = '''
          <t t-name="test">
            <t t-if="active"><span>Active</span></t>
            <t t-else=""><span>Inactive</span></t>
          </t>
        ''';
        final root = parser.parse(xml);
        final ifNode = _findNodeOfType<QWebIfNode>(root);
        expect(ifNode, isNotNull);
        expect(ifNode!.elseBranch, isNotNull);
      });

      test('parses t-if on HTML element', () {
        const xml = '<t t-name="test"><div t-if="show">Content</div></t>';
        final root = parser.parse(xml);
        final ifNode = _findNodeOfType<QWebIfNode>(root);
        expect(ifNode, isNotNull);
        expect(ifNode!.condition, equals('show'));
      });
    });

    group('t-foreach parsing', () {
      test('parses t-foreach with t-as', () {
        const xml = '''
          <t t-name="test">
            <t t-foreach="items" t-as="item">
              <span t-esc="item.name"/>
            </t>
          </t>
        ''';
        final root = parser.parse(xml);
        final forEach = _findNodeOfType<QWebForEachNode>(root);
        expect(forEach, isNotNull);
        expect(forEach!.expression, equals('items'));
        expect(forEach.itemVariable, equals('item'));
      });

      test('forEach node generates loop variables', () {
        const xml = '<t t-name="test"><t t-foreach="lines" t-as="line"><t t-esc="line"/></t></t>';
        final root = parser.parse(xml);
        final forEach = _findNodeOfType<QWebForEachNode>(root);
        expect(forEach, isNotNull);
        expect(forEach!.indexVariable, equals('line_index'));
        expect(forEach.firstVariable, equals('line_first'));
        expect(forEach.lastVariable, equals('line_last'));
        expect(forEach.sizeVariable, equals('line_size'));
      });
    });

    group('t-esc parsing', () {
      test('parses t-esc on t element', () {
        const xml = '<t t-name="test"><t t-esc="doc.name"/></t>';
        final root = parser.parse(xml);
        final escNode = _findNodeOfType<QWebEscNode>(root);
        expect(escNode, isNotNull);
        expect(escNode!.expression, equals('doc.name'));
      });

      test('parses t-esc on span element', () {
        const xml = '<t t-name="test"><span t-esc="value"/></t>';
        final root = parser.parse(xml);
        final escNode = _findNodeOfType<QWebEscNode>(root);
        expect(escNode, isNotNull);
        expect(escNode!.expression, equals('value'));
      });
    });

    group('t-set parsing', () {
      test('parses t-set with t-value', () {
        const xml = '<t t-name="test"><t t-set="total" t-value="100"/></t>';
        final root = parser.parse(xml);
        final setNode = _findNodeOfType<QWebSetNode>(root);
        expect(setNode, isNotNull);
        expect(setNode!.variableName, equals('total'));
        expect(setNode.expression, equals('100'));
      });
    });

    group('element parsing', () {
      test('parses regular HTML elements', () {
        const xml = '<t t-name="test"><div class="container"><p>Hello</p></div></t>';
        final root = parser.parse(xml);
        final div = _findNodeOfType<QWebElementNode>(root);
        expect(div, isNotNull);
        expect(div!.tagName, equals('div'));
        expect(div.attributes['class'], equals('container'));
      });

      test('parses text nodes', () {
        const xml = '<t t-name="test"><p>Some text</p></t>';
        final root = parser.parse(xml);
        final text = _findNodeOfType<QWebTextNode>(root);
        expect(text, isNotNull);
        expect(text!.text.trim(), contains('Some text'));
      });
    });

    group('error handling', () {
      test('handles empty XML gracefully', () {
        // Should not throw
        final root = parser.parse('<t t-name="test"></t>');
        expect(root, isNotNull);
      });
    });
  });
}

/// Recursively find first node of a given type in the AST.
T? _findNodeOfType<T extends QWebNode>(QWebNode node) {
  if (node is T) return node;

  if (node is QWebElementNode) {
    for (final child in node.children) {
      final found = _findNodeOfType<T>(child);
      if (found != null) return found;
    }
  } else if (node is QWebFragmentNode) {
    for (final child in node.children) {
      final found = _findNodeOfType<T>(child);
      if (found != null) return found;
    }
  } else if (node is QWebIfNode) {
    final found = _findNodeOfType<T>(node.thenBranch);
    if (found != null) return found;
    if (node.elseBranch != null) {
      return _findNodeOfType<T>(node.elseBranch!);
    }
  } else if (node is QWebForEachNode) {
    return _findNodeOfType<T>(node.child);
  } else if (node is QWebDynamicAttrsNode) {
    return _findNodeOfType<T>(node.child);
  } else if (node is QWebCallNode) {
    for (final child in node.children) {
      final found = _findNodeOfType<T>(child);
      if (found != null) return found;
    }
  } else if (node is QWebOutNode) {
    for (final child in node.children) {
      final found = _findNodeOfType<T>(child);
      if (found != null) return found;
    }
  }

  return null;
}
