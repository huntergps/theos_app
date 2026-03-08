import 'package:test/test.dart';
import 'package:flutter_qweb/src/evaluator/expression_evaluator.dart';

void main() {
  late ExpressionEvaluator evaluator;

  setUp(() {
    evaluator = ExpressionEvaluator();
  });

  group('ExpressionEvaluator', () {
    group('literals', () {
      test('evaluates string literals', () {
        expect(evaluator.evaluate("'hello'", {}), equals('hello'));
        expect(evaluator.evaluate('"world"', {}), equals('world'));
      });

      test('evaluates numeric literals', () {
        expect(evaluator.evaluate('42', {}), equals(42));
        expect(evaluator.evaluate('3.14', {}), equals(3.14));
        expect(evaluator.evaluate('-10', {}), equals(-10));
      });

      test('evaluates boolean literals', () {
        expect(evaluator.evaluate('True', {}), equals(true));
        expect(evaluator.evaluate('False', {}), equals(false));
      });

      test('evaluates None/null', () {
        expect(evaluator.evaluate('None', {}), isNull);
      });
    });

    group('path access', () {
      test('accesses simple variable', () {
        expect(evaluator.evaluate('name', {'name': 'Test'}), equals('Test'));
      });

      test('accesses nested property', () {
        final ctx = {
          'doc': {
            'partner_id': {'name': 'Acme'}
          }
        };
        expect(evaluator.evaluate('doc.partner_id.name', ctx), equals('Acme'));
      });

      test('returns null for missing path', () {
        expect(evaluator.evaluate('doc.missing', {'doc': {}}), isNull);
      });

      test('returns null for null intermediate', () {
        expect(evaluator.evaluate('doc.partner.name', {'doc': {'partner': null}}), isNull);
      });
    });

    group('arithmetic operators', () {
      test('addition', () {
        expect(evaluator.evaluate('a + b', {'a': 10, 'b': 5}), equals(15));
      });

      test('subtraction', () {
        expect(evaluator.evaluate('a - b', {'a': 10, 'b': 3}), equals(7));
      });

      test('multiplication', () {
        expect(evaluator.evaluate('a * b', {'a': 4, 'b': 5}), equals(20));
      });

      test('division', () {
        expect(evaluator.evaluate('a / b', {'a': 10, 'b': 2}), equals(5));
      });

      test('modulo', () {
        expect(evaluator.evaluate('a % b', {'a': 10, 'b': 3}), equals(1));
      });

      test('string concatenation with +', () {
        expect(evaluator.evaluate('a + b', {'a': 'Hello ', 'b': 'World'}), equals('Hello World'));
      });
    });

    group('comparison operators', () {
      test('equals', () {
        expect(evaluator.evaluate('a == 5', {'a': 5}), equals(true));
        expect(evaluator.evaluate('a == 5', {'a': 3}), equals(false));
      });

      test('not equals', () {
        expect(evaluator.evaluate("state != 'draft'", {'state': 'sale'}), equals(true));
        expect(evaluator.evaluate("state != 'draft'", {'state': 'draft'}), equals(false));
      });

      test('greater than', () {
        expect(evaluator.evaluate('price > 100', {'price': 150}), equals(true));
        expect(evaluator.evaluate('price > 100', {'price': 50}), equals(false));
      });

      test('less than', () {
        expect(evaluator.evaluate('qty < 10', {'qty': 5}), equals(true));
      });

      test('greater or equal', () {
        expect(evaluator.evaluate('qty >= 10', {'qty': 10}), equals(true));
        expect(evaluator.evaluate('qty >= 10', {'qty': 9}), equals(false));
      });

      test('less or equal', () {
        expect(evaluator.evaluate('qty <= 10', {'qty': 10}), equals(true));
        expect(evaluator.evaluate('qty <= 10', {'qty': 11}), equals(false));
      });
    });

    group('logical operators', () {
      test('and operator', () {
        expect(evaluator.evaluate('a and b', {'a': true, 'b': true}), equals(true));
        expect(evaluator.evaluate('a and b', {'a': true, 'b': false}), equals(false));
      });

      test('or operator', () {
        expect(evaluator.evaluate('a or b', {'a': false, 'b': true}), equals(true));
        expect(evaluator.evaluate('a or b', {'a': false, 'b': false}), equals(false));
      });

      test('not operator', () {
        expect(evaluator.evaluate('not a', {'a': false}), equals(true));
        expect(evaluator.evaluate('not a', {'a': true}), equals(false));
      });

      test('combined not and and', () {
        final ctx = {'is_section': false, 'is_note': false};
        final result = evaluator.evaluateCondition('not is_section and not is_note', ctx);
        expect(result, isTrue);
      });

      test('or returns first truthy value (Python semantics)', () {
        expect(evaluator.evaluate("name or 'Unknown'", {'name': ''}), equals('Unknown'));
        expect(evaluator.evaluate("name or 'Unknown'", {'name': 'Test'}), equals('Test'));
      });
    });

    group('evaluateCondition', () {
      test('truthy values', () {
        expect(evaluator.evaluateCondition('val', {'val': true}), isTrue);
        expect(evaluator.evaluateCondition('val', {'val': 1}), isTrue);
        expect(evaluator.evaluateCondition('val', {'val': 'text'}), isTrue);
        expect(evaluator.evaluateCondition('val', {'val': [1]}), isTrue);
      });

      test('falsy values', () {
        expect(evaluator.evaluateCondition('val', {'val': false}), isFalse);
        expect(evaluator.evaluateCondition('val', {'val': 0}), isFalse);
        expect(evaluator.evaluateCondition('val', {'val': ''}), isFalse);
        expect(evaluator.evaluateCondition('val', {'val': []}), isFalse);
        expect(evaluator.evaluateCondition('val', {'val': null}), isFalse);
      });

      test('expression conditions', () {
        expect(evaluator.evaluateCondition('qty > 0', {'qty': 5}), isTrue);
        expect(evaluator.evaluateCondition('qty > 0', {'qty': 0}), isFalse);
      });
    });

    group('ternary expressions', () {
      test('evaluates true branch', () {
        final result = evaluator.evaluate("'Yes' if active else 'No'", {'active': true});
        expect(result, equals('Yes'));
      });

      test('evaluates false branch', () {
        final result = evaluator.evaluate("'Yes' if active else 'No'", {'active': false});
        expect(result, equals('No'));
      });

      test('ternary with complex condition', () {
        final result = evaluator.evaluate("'In Stock' if qty > 0 else 'Out of Stock'", {'qty': 10});
        expect(result, equals('In Stock'));
      });
    });

    group('membership operator (in)', () {
      test('checks item in list', () {
        expect(evaluator.evaluate("'a' in items", {'items': ['a', 'b', 'c']}), equals(true));
        expect(evaluator.evaluate("'z' in items", {'items': ['a', 'b', 'c']}), equals(false));
      });

      test('checks substring in string', () {
        expect(evaluator.evaluate("'@' in email", {'email': 'test@example.com'}), equals(true));
        expect(evaluator.evaluate("'@' in email", {'email': 'no-at-sign'}), equals(false));
      });
    });

    group('built-in functions', () {
      test('len() on list', () {
        expect(evaluator.evaluate('len(items)', {'items': [1, 2, 3]}), equals(3));
      });

      test('len() on string', () {
        expect(evaluator.evaluate("len('hello')", {}), equals(5));
      });

      test('str()', () {
        expect(evaluator.evaluate('str(42)', {}), equals('42'));
      });

      test('int()', () {
        expect(evaluator.evaluate("int('42')", {}), equals(42));
      });

      test('float()', () {
        expect(evaluator.evaluate("float('3.14')", {}), equals(3.14));
      });

      test('bool() truthy', () {
        expect(evaluator.evaluate('bool(1)', {}), equals(true));
      });

      test('bool() falsy', () {
        expect(evaluator.evaluate('bool(0)', {}), equals(false));
      });

      test('round()', () {
        expect(evaluator.evaluate('round(3.14159, 2)', {}), equals(3.14));
      });
    });

    group('aggregate functions', () {
      test('sum()', () {
        expect(evaluator.evaluate('sum(nums)', {'nums': [1, 2, 3, 4]}), equals(10));
      });

      test('min()', () {
        // Use List<dynamic> to avoid Dart typed-list reduce issue
        expect(evaluator.evaluate('min(nums)', {'nums': <dynamic>[5, 2, 8]}), equals(2));
      });

      test('max()', () {
        expect(evaluator.evaluate('max(nums)', {'nums': <dynamic>[5, 2, 8]}), equals(8));
      });

      test('any() with truthy item', () {
        expect(evaluator.evaluate('any(items)', {'items': [false, true, false]}), equals(true));
      });

      test('all() with all truthy', () {
        expect(evaluator.evaluate('all(items)', {'items': [true, true, true]}), equals(true));
      });

      test('all() with falsy item', () {
        expect(evaluator.evaluate('all(items)', {'items': [true, false, true]}), equals(false));
      });
    });

    group('string methods', () {
      test('upper()', () {
        expect(evaluator.evaluate('text.upper()', {'text': 'hello'}), equals('HELLO'));
      });

      test('lower()', () {
        expect(evaluator.evaluate('text.lower()', {'text': 'HELLO'}), equals('hello'));
      });

      test('strip()', () {
        expect(evaluator.evaluate('text.strip()', {'text': '  hi  '}), equals('hi'));
      });

      test('split()', () {
        expect(evaluator.evaluate("text.split(',')", {'text': 'a,b,c'}), equals(['a', 'b', 'c']));
      });

      test('replace()', () {
        expect(evaluator.evaluate("text.replace('l', 'L')", {'text': 'hello'}), equals('heLLo'));
      });

      test('startswith()', () {
        expect(evaluator.evaluate("text.startswith('he')", {'text': 'hello'}), equals(true));
      });

      test('endswith()', () {
        expect(evaluator.evaluate("text.endswith('lo')", {'text': 'hello'}), equals(true));
      });

      test('join()', () {
        expect(evaluator.evaluate("', '.join(items)", {'items': ['a', 'b', 'c']}), equals('a, b, c'));
      });
    });

    group('sequence functions', () {
      test('range(stop)', () {
        expect(evaluator.evaluate('range(5)', {}), equals([0, 1, 2, 3, 4]));
      });

      test('range(start, stop)', () {
        expect(evaluator.evaluate('range(2, 5)', {}), equals([2, 3, 4]));
      });

      test('sorted()', () {
        expect(evaluator.evaluate('sorted(items)', {'items': [3, 1, 2]}), equals([1, 2, 3]));
      });
    });

    group('dict methods', () {
      test('get() with existing key', () {
        expect(evaluator.evaluate("d.get('a', 0)", {'d': {'a': 1}}), equals(1));
      });

      test('get() with missing key returns default', () {
        expect(evaluator.evaluate("d.get('b', 0)", {'d': {'a': 1}}), equals(0));
      });

      test('keys()', () {
        final result = evaluator.evaluate('d.keys()', {'d': {'a': 1, 'b': 2}});
        expect(result, isA<List>());
        expect((result as List).toSet(), equals({'a', 'b'}));
      });

      test('values()', () {
        final result = evaluator.evaluate('d.values()', {'d': {'a': 1, 'b': 2}});
        expect(result, isA<List>());
        expect((result as List).toSet(), equals({1, 2}));
      });
    });

    group('index access', () {
      test('list index', () {
        expect(evaluator.evaluate('items[0]', {'items': ['a', 'b', 'c']}), equals('a'));
        expect(evaluator.evaluate('items[2]', {'items': ['a', 'b', 'c']}), equals('c'));
      });

      test('negative index', () {
        expect(evaluator.evaluate('items[-1]', {'items': ['a', 'b', 'c']}), equals('c'));
      });
    });

    group('list comprehension', () {
      test('simple comprehension', () {
        expect(
          evaluator.evaluate('[x * 2 for x in numbers]', {'numbers': [1, 2, 3]}),
          equals([2, 4, 6]),
        );
      });

      test('comprehension with nested path', () {
        final ctx = {
          'lines': [
            {'name': 'A'},
            {'name': 'B'},
          ]
        };
        expect(
          evaluator.evaluate('[line.name for line in lines]', ctx),
          equals(['A', 'B']),
        );
      });
    });

    group('generator expressions', () {
      test('sum with generator', () {
        final ctx = {
          'lines': [
            {'price': 10.0},
            {'price': 20.0},
            {'price': 30.0},
          ]
        };
        expect(evaluator.evaluate('sum(line.price for line in lines)', ctx), equals(60.0));
      });

      test('any with generator', () {
        final ctx = {
          'lines': [
            {'qty': 0},
            {'qty': 5},
            {'qty': 0},
          ]
        };
        expect(evaluator.evaluate('any(line.qty > 0 for line in lines)', ctx), equals(true));
      });
    });

    group('complex expressions', () {
      test('nested path with arithmetic', () {
        final ctx = {
          'line': {'qty': 3, 'price': 10.5}
        };
        expect(evaluator.evaluate('line.qty * line.price', ctx), equals(31.5));
      });

      test('combined comparison and logical', () {
        final ctx = {'state': 'sale', 'qty': 5};
        expect(
          evaluator.evaluateCondition("state == 'sale' and qty > 0", ctx),
          isTrue,
        );
      });

      test('format value for monetary', () {
        final result = evaluator.formatValue(
          1234.56,
          {'widget': 'monetary'},
          {'currency_id': {'symbol': r'$'}},
        );
        expect(result, isA<String>());
        expect(result, contains('1234'));
      });

      test('format value for integer', () {
        final result = evaluator.formatValue(42, {'widget': 'integer'}, {});
        expect(result, equals('42'));
      });
    });
  });
}
