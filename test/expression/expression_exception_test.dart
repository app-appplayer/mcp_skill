import 'package:test/test.dart';
import 'package:mcp_skill/src/expression/expression_exception.dart';

void main() {
  group('SyntaxException', () {
    test('constructor stores all fields', () {
      final ex = SyntaxException('inputs.name +', 13, 'Unexpected end');

      expect(ex.expression, equals('inputs.name +'));
      expect(ex.position, equals(13));
      expect(ex.message, equals('Unexpected end'));
    });

    test('implements ExpressionException', () {
      final ex = SyntaxException('bad', 0, 'err');
      expect(ex, isA<ExpressionException>());
    });

    test('implements Exception', () {
      final ex = SyntaxException('bad', 0, 'err');
      expect(ex, isA<Exception>());
    });

    test('toString returns class name and message', () {
      final ex = SyntaxException('x +', 2, 'Expected operand');

      expect(ex.toString(), equals('SyntaxException: Expected operand'));
    });
  });

  group('EvaluationException', () {
    test('constructor with message only', () {
      final ex = EvaluationException('Division by zero');

      expect(ex.message, equals('Division by zero'));
      expect(ex.path, isNull);
    });

    test('constructor with path', () {
      final ex = EvaluationException('Null reference', path: 'inputs.query');

      expect(ex.message, equals('Null reference'));
      expect(ex.path, equals('inputs.query'));
    });

    test('implements ExpressionException', () {
      final ex = EvaluationException('err');
      expect(ex, isA<ExpressionException>());
    });

    test('toString returns class name and message', () {
      final ex = EvaluationException('Not found');

      expect(ex.toString(), equals('EvaluationException: Not found'));
    });
  });

  group('TypeCoercionException', () {
    test('constructor sets computed message', () {
      final ex = TypeCoercionException('String', 'int');

      expect(ex.sourceType, equals('String'));
      expect(ex.targetType, equals('int'));
      expect(ex.message, equals('Cannot coerce String to int'));
    });

    test('implements ExpressionException', () {
      final ex = TypeCoercionException('A', 'B');
      expect(ex, isA<ExpressionException>());
    });

    test('toString returns class name and message', () {
      final ex = TypeCoercionException('bool', 'List');

      expect(
        ex.toString(),
        equals('TypeCoercionException: Cannot coerce bool to List'),
      );
    });
  });

  group('ExpressionTimeoutException', () {
    test('constructor sets computed message', () {
      final ex = ExpressionTimeoutException(Duration(seconds: 5));

      expect(ex.timeout, equals(Duration(seconds: 5)));
      expect(
        ex.message,
        equals('Expression evaluation timed out after 5000ms'),
      );
    });

    test('constructor with milliseconds', () {
      final ex = ExpressionTimeoutException(Duration(milliseconds: 250));

      expect(
        ex.message,
        equals('Expression evaluation timed out after 250ms'),
      );
    });

    test('implements ExpressionException', () {
      final ex = ExpressionTimeoutException(Duration(seconds: 1));
      expect(ex, isA<ExpressionException>());
    });

    test('toString returns class name and message', () {
      final ex = ExpressionTimeoutException(Duration(seconds: 10));

      expect(
        ex.toString(),
        equals(
            'ExpressionTimeoutException: Expression evaluation timed out after 10000ms'),
      );
    });
  });

  group('UnknownFunctionException', () {
    test('constructor sets computed message', () {
      final ex = UnknownFunctionException('myFunc');

      expect(ex.functionName, equals('myFunc'));
      expect(ex.message, equals('Unknown function: myFunc'));
    });

    test('implements ExpressionException', () {
      final ex = UnknownFunctionException('f');
      expect(ex, isA<ExpressionException>());
    });

    test('toString returns class name and message', () {
      final ex = UnknownFunctionException('doStuff');

      expect(
        ex.toString(),
        equals('UnknownFunctionException: Unknown function: doStuff'),
      );
    });
  });

  group('SecurityException', () {
    test('constructor stores message', () {
      final ex = SecurityException('Access denied to restricted scope');

      expect(ex.message, equals('Access denied to restricted scope'));
    });

    test('implements ExpressionException', () {
      final ex = SecurityException('forbidden');
      expect(ex, isA<ExpressionException>());
    });

    test('toString returns class name and message', () {
      final ex = SecurityException('Scope violation');

      expect(
        ex.toString(),
        equals('SecurityException: Scope violation'),
      );
    });
  });

  group('ExpressionException sealed class', () {
    test('all subtypes are ExpressionException', () {
      final exceptions = <ExpressionException>[
        SyntaxException('x', 0, 'err'),
        EvaluationException('err'),
        TypeCoercionException('A', 'B'),
        ExpressionTimeoutException(Duration(seconds: 1)),
        UnknownFunctionException('f'),
        SecurityException('denied'),
      ];

      for (final ex in exceptions) {
        expect(ex, isA<ExpressionException>());
        expect(ex, isA<Exception>());
        expect(ex.message, isNotEmpty);
        expect(ex.toString(), contains(ex.message));
      }
      expect(exceptions.length, equals(6));
    });
  });
}
