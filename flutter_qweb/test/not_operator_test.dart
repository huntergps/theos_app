import 'package:test/test.dart';
import 'package:flutter_qweb/src/evaluator/expression_evaluator.dart';

void main() {
  late ExpressionEvaluator eval;
  late Map<String, dynamic> ctx;

  setUp(() {
    eval = ExpressionEvaluator();
    ctx = {
      'is_section': false,
      'is_note': false,
    };
  });

  group('not operator', () {
    test('negates false to true', () {
      final result = eval.evaluate('not is_section', ctx);
      expect(result, isTrue);
    });

    test('negates false to true for second variable', () {
      final result = eval.evaluate('not is_note', ctx);
      expect(result, isTrue);
    });

    test('combined not with and operator', () {
      final result = eval.evaluate('not is_section and not is_note', ctx);
      expect(result, isTrue);
    });

    test('evaluateCondition with combined not and', () {
      final result =
          eval.evaluateCondition('not is_section and not is_note', ctx);
      expect(result, isTrue);
    });

    test('negates true to false', () {
      ctx['is_section'] = true;
      final result = eval.evaluate('not is_section', ctx);
      expect(result, isFalse);
    });

    test('combined not with and when one is true', () {
      ctx['is_section'] = true;
      final result = eval.evaluate('not is_section and not is_note', ctx);
      expect(result, isFalse);
    });
  });
}
