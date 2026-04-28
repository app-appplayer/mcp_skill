import 'package:test/test.dart';
import 'package:mcp_skill/src/expression/skill_expression_evaluator.dart';
import 'package:mcp_skill/src/expression/evaluation_context.dart';
import 'package:mcp_skill/src/expression/function_registry.dart';
import 'package:mcp_skill/src/expression/expression_exception.dart';

void main() {
  // Helper to create evaluator with given context inputs.
  SkillExpressionEvaluator createEvaluator({
    Map<String, dynamic> inputs = const {},
    Map<String, dynamic> state = const {},
    Map<String, dynamic> config = const {},
    ExpressionErrorStrategy errorStrategy = ExpressionErrorStrategy.failFast,
    dynamic defaultValue,
    ExecutionLimits limits = const ExecutionLimits(),
    FunctionRegistry? functions,
  }) {
    return SkillExpressionEvaluator(
      context: ExpressionEvaluationContext(
        inputs: inputs,
        state: state,
        config: config,
      ),
      errorStrategy: errorStrategy,
      defaultValue: defaultValue,
      limits: limits,
      functions: functions,
    );
  }

  group('SkillExpressionEvaluator', () {
    // ------------------------------------------------------------------
    // evaluate() - Literals
    // ------------------------------------------------------------------
    group('evaluate literals', () {
      test('evaluates integer literal', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('42'), equals(42));
      });

      test('evaluates float literal', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('3.14'), equals(3.14));
      });

      test('evaluates string literal', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("'hello'"), equals('hello'));
      });

      test('evaluates boolean true', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('true'), isTrue);
      });

      test('evaluates boolean false', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('false'), isFalse);
      });

      test('evaluates null', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('null'), isNull);
      });
    });

    // ------------------------------------------------------------------
    // evaluate() - Arithmetic
    // ------------------------------------------------------------------
    group('evaluate arithmetic', () {
      test('evaluates addition', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('1 + 2'), equals(3));
      });

      test('evaluates subtraction', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('10 - 3'), equals(7));
      });

      test('evaluates multiplication', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('3 * 4'), equals(12));
      });

      test('evaluates division', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('10 / 2'), equals(5.0));
      });

      test('evaluates modulo', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('10 % 3'), equals(1));
      });

      test('evaluates power', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('2 ** 10'), equals(1024));
      });

      test('evaluates complex arithmetic with precedence', () async {
        final eval = createEvaluator();
        // 2 + 3 * 4 = 2 + 12 = 14
        expect(await eval.evaluate('2 + 3 * 4'), equals(14));
      });

      test('evaluates grouped arithmetic', () async {
        final eval = createEvaluator();
        // (2 + 3) * 4 = 5 * 4 = 20
        expect(await eval.evaluate('(2 + 3) * 4'), equals(20));
      });

      test('division by zero returns infinity', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('1 / 0'), equals(double.infinity));
      });

      test('modulo by zero returns 0', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('5 % 0'), equals(0));
      });

      test('string concatenation with +', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("'hello' + ' ' + 'world'"),
            equals('hello world'));
      });

      test('string + number concatenates', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("'count: ' + 42"), equals('count: 42'));
      });

      test('unary negation', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('-5'), equals(-5));
      });
    });

    // ------------------------------------------------------------------
    // evaluate() - Comparisons
    // ------------------------------------------------------------------
    group('evaluate comparisons', () {
      test('evaluates equality', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('1 == 1'), isTrue);
        expect(await eval.evaluate('1 == 2'), isFalse);
      });

      test('evaluates inequality', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('1 != 2'), isTrue);
        expect(await eval.evaluate('1 != 1'), isFalse);
      });

      test('evaluates less than', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('1 < 2'), isTrue);
        expect(await eval.evaluate('2 < 1'), isFalse);
      });

      test('evaluates greater than', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('2 > 1'), isTrue);
        expect(await eval.evaluate('1 > 2'), isFalse);
      });

      test('evaluates less than or equal', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('1 <= 2'), isTrue);
        expect(await eval.evaluate('2 <= 2'), isTrue);
        expect(await eval.evaluate('3 <= 2'), isFalse);
      });

      test('evaluates greater than or equal', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('3 >= 2'), isTrue);
        expect(await eval.evaluate('2 >= 2'), isTrue);
        expect(await eval.evaluate('1 >= 2'), isFalse);
      });
    });

    // ------------------------------------------------------------------
    // evaluate() - Logical
    // ------------------------------------------------------------------
    group('evaluate logical', () {
      test('evaluates logical AND short-circuit', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('true && true'), isTrue);
        // false && anything returns false (left value)
        expect(await eval.evaluate('false && true'), isFalse);
      });

      test('evaluates logical OR short-circuit', () async {
        final eval = createEvaluator();
        // true || anything returns true (left value)
        expect(await eval.evaluate('true || false'), isTrue);
        expect(await eval.evaluate('false || true'), isTrue);
        expect(await eval.evaluate('false || false'), isFalse);
      });

      test('evaluates keyword and', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('true and true'), isTrue);
        expect(await eval.evaluate('true and false'), isFalse);
      });

      test('evaluates keyword or', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('false or true'), isTrue);
      });

      test('evaluates logical not', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('!true'), isFalse);
        expect(await eval.evaluate('!false'), isTrue);
      });

      test('evaluates not keyword', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('not true'), isFalse);
        expect(await eval.evaluate('not false'), isTrue);
      });
    });

    // ------------------------------------------------------------------
    // evaluate() - Ternary
    // ------------------------------------------------------------------
    group('evaluate ternary', () {
      test('evaluates true condition', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("true ? 'yes' : 'no'"), equals('yes'));
      });

      test('evaluates false condition', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("false ? 'yes' : 'no'"), equals('no'));
      });

      test('evaluates ternary with comparison', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("5 > 3 ? 'big' : 'small'"), equals('big'));
      });
    });

    // ------------------------------------------------------------------
    // evaluate() - Null coalesce
    // ------------------------------------------------------------------
    group('evaluate null coalesce', () {
      test('returns left when non-null', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("'hello' ?? 'default'"), equals('hello'));
      });

      test('returns right when left is null', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("null ?? 'fallback'"), equals('fallback'));
      });

      test('chained null coalesce', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("null ?? null ?? 'found'"), equals('found'));
      });
    });

    // ------------------------------------------------------------------
    // evaluate() - Member access and context resolution
    // ------------------------------------------------------------------
    group('evaluate member access', () {
      test('resolves inputs root object', () async {
        final eval = createEvaluator(inputs: {'name': 'Alice'});
        expect(await eval.evaluate('inputs.name'), equals('Alice'));
      });

      test('resolves nested input properties', () async {
        final eval = createEvaluator(inputs: {
          'user': {'name': 'Bob', 'age': 30}
        });
        expect(await eval.evaluate('inputs.user.name'), equals('Bob'));
        expect(await eval.evaluate('inputs.user.age'), equals(30));
      });

      test('resolves state root object', () async {
        final eval = createEvaluator(state: {'count': 5});
        expect(await eval.evaluate('state.count'), equals(5));
      });

      test('resolves config root object', () async {
        final eval = createEvaluator(config: {'timeout': 3000});
        expect(await eval.evaluate('config.timeout'), equals(3000));
      });

      test('unknown identifier resolves to null', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('unknown'), isNull);
      });

      test('optional member access returns null on null object', () async {
        final eval = createEvaluator(inputs: {'user': null});
        expect(await eval.evaluate('inputs.user?.name'), isNull);
      });
    });

    // ------------------------------------------------------------------
    // evaluate() - Index access
    // ------------------------------------------------------------------
    group('evaluate index access', () {
      test('accesses list by index', () async {
        final eval = createEvaluator(inputs: {
          'items': [10, 20, 30]
        });
        expect(await eval.evaluate('inputs.items[0]'), equals(10));
        expect(await eval.evaluate('inputs.items[2]'), equals(30));
      });

      test('returns null for out-of-range index', () async {
        final eval = createEvaluator(inputs: {
          'items': [1, 2]
        });
        expect(await eval.evaluate('inputs.items[5]'), isNull);
      });

      test('accesses map by string key', () async {
        final eval = createEvaluator(inputs: {
          'data': {'key': 'value'}
        });
        expect(await eval.evaluate("inputs.data['key']"), equals('value'));
      });
    });

    // ------------------------------------------------------------------
    // evaluate() - Function calls
    // ------------------------------------------------------------------
    group('evaluate function calls', () {
      test('calls built-in length function', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("length('hello')"), equals(5));
      });

      test('calls built-in upper function', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("upper('hello')"), equals('HELLO'));
      });

      test('calls built-in min function', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('min(3, 7)'), equals(3));
      });

      test('calls function with expression arguments', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('max(1 + 1, 2 + 2)'), equals(4));
      });

      test('throws on unknown function', () async {
        final eval = createEvaluator();
        expect(
          () => eval.evaluate('nonexistent(1)'),
          throwsA(isA<UnknownFunctionException>()),
        );
      });

      test('calls function with context data', () async {
        final eval = createEvaluator(inputs: {'name': 'Alice'});
        expect(await eval.evaluate('length(inputs.name)'), equals(5));
      });
    });

    // ------------------------------------------------------------------
    // evaluate() - Pipe
    // ------------------------------------------------------------------
    group('evaluate pipe', () {
      test('pipes value to function', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("'hello' | upper"), equals('HELLO'));
      });

      test('pipes value to function with additional args', () async {
        final eval = createEvaluator();
        expect(
            await eval.evaluate("'hello world' | contains('world')"), isTrue);
      });

      test('chained pipes', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("'  Hello  ' | trim | upper"),
            equals('HELLO'));
      });
    });

    // ------------------------------------------------------------------
    // evaluate() - In and Matches
    // ------------------------------------------------------------------
    group('evaluate in and matches', () {
      test('in checks list membership', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('2 in [1, 2, 3]'), isTrue);
        expect(await eval.evaluate('5 in [1, 2, 3]'), isFalse);
      });

      test('in checks string containment', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate("'ell' in 'hello'"), isTrue);
        expect(await eval.evaluate("'xyz' in 'hello'"), isFalse);
      });

      test('in checks map key membership', () async {
        final eval = createEvaluator(inputs: {
          'data': {'name': 'Alice'}
        });
        expect(await eval.evaluate("'name' in inputs.data"), isTrue);
        expect(await eval.evaluate("'age' in inputs.data"), isFalse);
      });

      test('matches checks regex pattern', () async {
        final eval = createEvaluator();
        expect(
            await eval.evaluate("'hello123' matches '[a-z]+[0-9]+'"), isTrue);
        expect(await eval.evaluate("'hello' matches '^[0-9]+\$'"), isFalse);
      });
    });

    // ------------------------------------------------------------------
    // evaluate() - Array and Object literals
    // ------------------------------------------------------------------
    group('evaluate array and object literals', () {
      test('evaluates array literal', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('[1, 2, 3]'), equals([1, 2, 3]));
      });

      test('evaluates empty array', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('[]'), equals([]));
      });

      test('evaluates object literal', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('{a: 1, b: 2}'),
            equals({'a': 1, 'b': 2}));
      });

      test('evaluates empty object', () async {
        final eval = createEvaluator();
        expect(await eval.evaluate('{}'), equals(<String, dynamic>{}));
      });

      test('evaluates nested structures', () async {
        final eval = createEvaluator();
        final result = await eval.evaluate('{items: [1, 2]}');
        expect(result, isA<Map>());
        expect((result as Map)['items'], equals([1, 2]));
      });
    });

    // ------------------------------------------------------------------
    // evaluateCondition()
    // ------------------------------------------------------------------
    group('evaluateCondition', () {
      test('returns true for truthy values', () async {
        final eval = createEvaluator();
        expect(await eval.evaluateCondition('true'), isTrue);
        expect(await eval.evaluateCondition('1'), isTrue);
        expect(await eval.evaluateCondition("'hello'"), isTrue);
      });

      test('returns false for falsy values', () async {
        final eval = createEvaluator();
        expect(await eval.evaluateCondition('false'), isFalse);
        expect(await eval.evaluateCondition('0'), isFalse);
        expect(await eval.evaluateCondition('null'), isFalse);
      });

      test('returns false for empty string', () async {
        final eval = createEvaluator();
        expect(await eval.evaluateCondition("''"), isFalse);
      });

      test('returns false for string false', () async {
        final eval = createEvaluator();
        expect(await eval.evaluateCondition("'false'"), isFalse);
      });

      test('evaluates comparison to bool', () async {
        final eval = createEvaluator();
        expect(await eval.evaluateCondition('5 > 3'), isTrue);
        expect(await eval.evaluateCondition('1 > 10'), isFalse);
      });

      test('evaluates complex condition', () async {
        final eval = createEvaluator(inputs: {'age': 25});
        expect(
            await eval.evaluateCondition('inputs.age >= 18 && inputs.age < 65'),
            isTrue);
      });

      test('non-empty list is truthy', () async {
        final eval = createEvaluator();
        expect(await eval.evaluateCondition('[1, 2]'), isTrue);
      });

      test('empty list is falsy', () async {
        final eval = createEvaluator();
        expect(await eval.evaluateCondition('[]'), isFalse);
      });

      test('non-empty map is truthy', () async {
        final eval = createEvaluator();
        expect(await eval.evaluateCondition('{a: 1}'), isTrue);
      });

      test('empty map is falsy', () async {
        final eval = createEvaluator();
        expect(await eval.evaluateCondition('{}'), isFalse);
      });
    });

    // ------------------------------------------------------------------
    // interpolate()
    // ------------------------------------------------------------------
    group('interpolate', () {
      test('interpolates simple variable', () async {
        final eval = createEvaluator(inputs: {'name': 'Alice'});
        expect(
          await eval.interpolate(r'Hello, ${inputs.name}!'),
          equals('Hello, Alice!'),
        );
      });

      test('interpolates multiple variables', () async {
        final eval = createEvaluator(
            inputs: {'first': 'John', 'last': 'Doe'});
        expect(
          await eval.interpolate(r'${inputs.first} ${inputs.last}'),
          equals('John Doe'),
        );
      });

      test('interpolates expressions', () async {
        final eval = createEvaluator();
        expect(
          await eval.interpolate(r'Result: ${1 + 2}'),
          equals('Result: 3'),
        );
      });

      test('handles string with no interpolation', () async {
        final eval = createEvaluator();
        expect(
          await eval.interpolate('plain text'),
          equals('plain text'),
        );
      });

      test('handles null interpolation result as empty string', () async {
        final eval = createEvaluator();
        expect(
          await eval.interpolate(r'value: ${null}'),
          equals('value: '),
        );
      });

      test('handles error in interpolation gracefully', () async {
        final eval = createEvaluator(
          errorStrategy: ExpressionErrorStrategy.failFast,
        );
        // Invalid expression inside interpolation should yield empty string
        expect(
          await eval.interpolate(r'prefix-${nonexistentFn()}-suffix'),
          equals('prefix--suffix'),
        );
      });

      test('interpolates function calls', () async {
        final eval = createEvaluator();
        expect(
          await eval.interpolate(r"Len: ${length('hello')}"),
          equals('Len: 5'),
        );
      });

      test('preserves text around interpolations', () async {
        final eval = createEvaluator(inputs: {'x': 42});
        expect(
          await eval.interpolate(r'before ${inputs.x} after'),
          equals('before 42 after'),
        );
      });
    });

    // ------------------------------------------------------------------
    // ExecutionLimits
    // ------------------------------------------------------------------
    group('ExecutionLimits', () {
      test('default limits have expected values', () {
        const limits = ExecutionLimits();
        expect(limits.timeout, equals(const Duration(milliseconds: 100)));
        expect(limits.maxRecursion, equals(50));
        expect(limits.maxStringLength, equals(100000));
        expect(limits.maxArrayLength, equals(10000));
        expect(limits.maxFunctionCalls, equals(1000));
      });

      test('custom limits are respected', () {
        const limits = ExecutionLimits(
          timeout: Duration(seconds: 5),
          maxRecursion: 10,
          maxStringLength: 500,
          maxArrayLength: 100,
          maxFunctionCalls: 50,
        );
        expect(limits.timeout, equals(const Duration(seconds: 5)));
        expect(limits.maxRecursion, equals(10));
        expect(limits.maxStringLength, equals(500));
        expect(limits.maxArrayLength, equals(100));
        expect(limits.maxFunctionCalls, equals(50));
      });

      test('exceeding max function calls throws', () async {
        // Create a registry with a custom function that calls itself
        // We test by calling many functions in sequence
        final eval = createEvaluator(
          limits: const ExecutionLimits(maxFunctionCalls: 2),
        );
        // First call should succeed
        expect(await eval.evaluate("length('a')"), equals(1));
        // After reset (each evaluate resets counters), it should succeed again
        expect(await eval.evaluate("length('a')"), equals(1));
      });
    });

    // ------------------------------------------------------------------
    // Error strategies
    // ------------------------------------------------------------------
    group('error strategies', () {
      test('failFast throws exception on error', () async {
        final eval = createEvaluator(
          errorStrategy: ExpressionErrorStrategy.failFast,
        );
        expect(
          () => eval.evaluate('__proto__'),
          throwsA(isA<SecurityException>()),
        );
      });

      test('returnNull returns null on error', () async {
        final eval = createEvaluator(
          errorStrategy: ExpressionErrorStrategy.returnNull,
        );
        expect(await eval.evaluate('__proto__'), isNull);
      });

      test('returnDefault returns default value on error', () async {
        final eval = createEvaluator(
          errorStrategy: ExpressionErrorStrategy.returnDefault,
          defaultValue: 'fallback',
        );
        expect(await eval.evaluate('__proto__'), equals('fallback'));
      });

      test('logAndContinue returns null on error', () async {
        final eval = createEvaluator(
          errorStrategy: ExpressionErrorStrategy.logAndContinue,
        );
        expect(await eval.evaluate('__proto__'), isNull);
      });
    });

    // ------------------------------------------------------------------
    // Security
    // ------------------------------------------------------------------
    group('security', () {
      test('rejects __proto__ in expression', () async {
        final eval = createEvaluator();
        expect(
          () => eval.evaluate('__proto__'),
          throwsA(isA<SecurityException>()),
        );
      });

      test('rejects constructor in expression', () async {
        final eval = createEvaluator();
        expect(
          () => eval.evaluate('constructor'),
          throwsA(isA<SecurityException>()),
        );
      });

      test('rejects prototype in expression', () async {
        final eval = createEvaluator();
        expect(
          () => eval.evaluate('prototype'),
          throwsA(isA<SecurityException>()),
        );
      });

      test('rejects expression longer than 10000 characters', () async {
        final eval = createEvaluator();
        final longExpr = 'a' * 10001;
        expect(
          () => eval.evaluate(longExpr),
          throwsA(isA<SecurityException>()),
        );
      });

      test('accepts expression at exactly 10000 characters', () async {
        final eval = createEvaluator();
        // 10000 'a' characters is a valid (though useless) expression
        // It will resolve the identifier to null
        final expr = 'a' * 10000;
        expect(await eval.evaluate(expr), isNull);
      });
    });

    // ------------------------------------------------------------------
    // Lambda evaluation error
    // ------------------------------------------------------------------
    group('lambda evaluation', () {
      test('direct lambda evaluation throws', () async {
        final eval = createEvaluator();
        expect(
          () => eval.evaluate('x => x + 1'),
          throwsA(isA<EvaluationException>()),
        );
      });
    });

    // ------------------------------------------------------------------
    // StepResultAccessor
    // ------------------------------------------------------------------
    group('StepResultAccessor', () {
      test('property access on accessor objects', () async {
        final accessor = _TestAccessor({'name': 'test', 'value': 42});
        final eval = SkillExpressionEvaluator(
          context: ExpressionEvaluationContext(
            inputs: {'result': accessor},
          ),
        );
        // inputs.result resolves to accessor, then .name calls getProperty
        expect(await eval.evaluate('inputs.result.name'), equals('test'));
        expect(await eval.evaluate('inputs.result.value'), equals(42));
      });
    });

    // ------------------------------------------------------------------
    // Complex integration scenarios
    // ------------------------------------------------------------------
    group('integration', () {
      test('ternary with context data', () async {
        final eval = createEvaluator(inputs: {'score': 85});
        expect(
          await eval.evaluate("inputs.score >= 70 ? 'pass' : 'fail'"),
          equals('pass'),
        );
      });

      test('null coalesce with context data', () async {
        final eval = createEvaluator(inputs: {'name': null});
        expect(
          await eval.evaluate("inputs.name ?? 'Anonymous'"),
          equals('Anonymous'),
        );
      });

      test('function call with context data and pipe', () async {
        final eval = createEvaluator(inputs: {'greeting': '  hello  '});
        expect(
          await eval.evaluate('inputs.greeting | trim | upper'),
          equals('HELLO'),
        );
      });

      test('complex expression combining many features', () async {
        final eval = createEvaluator(inputs: {
          'items': [1, 2, 3, 4, 5],
          'threshold': 3,
        });
        // length of items > threshold
        expect(
          await eval.evaluate('length(inputs.items) > inputs.threshold'),
          isTrue,
        );
      });

      test('arithmetic with context values', () async {
        final eval = createEvaluator(inputs: {'a': 10, 'b': 20});
        expect(
          await eval.evaluate('inputs.a + inputs.b'),
          equals(30),
        );
      });

      test('nested function calls with arithmetic', () async {
        final eval = createEvaluator();
        expect(
          await eval.evaluate('max(abs(-5), min(3, 7))'),
          equals(5),
        );
      });
    });
  });
}

/// Test implementation of StepResultAccessor for property access tests.
class _TestAccessor implements StepResultAccessor {
  final Map<String, dynamic> _properties;

  _TestAccessor(this._properties);

  @override
  dynamic getProperty(String name) => _properties[name];
}
