import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/expression_interpolator.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_skill/src/runtime/skill_result.dart';
import 'package:mcp_skill/src/runtime/context_types.dart';

void main() {
  // Helper to create a minimal SkillContext for tests.
  SkillContext _createContext({
    String skillId = 'test-skill',
    String request = 'Test request',
    Map<String, dynamic> inputs = const {},
  }) {
    return SkillContext(
      contextId: 'ctx-1',
      skillId: skillId,
      runId: 'run-1',
      traceId: 'trace-1',
      request: request,
      workspaceId: 'ws-1',
      asOf: DateTime(2025, 6, 1),
      inputs: inputs,
    );
  }

  group('ExpressionInterpolator', () {
    group('interpolate', () {
      test('returns plain text unchanged', () async {
        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
        );

        final result = await interpolator.interpolate('Hello World');

        expect(result, 'Hello World');
      });

      test('resolves input variables in template', () async {
        final context = _createContext(
          inputs: {'name': 'Alice', 'age': 30},
        );
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result =
            await interpolator.interpolate(r'Hello ${inputs.name}!');

        expect(result, 'Hello Alice!');
      });

      test('resolves multiple expressions in a single template', () async {
        final context = _createContext(
          inputs: {'first': 'Alice', 'last': 'Smith'},
        );
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result = await interpolator
            .interpolate(r'${inputs.first} ${inputs.last}');

        expect(result, 'Alice Smith');
      });

      test('resolves context root object properties', () async {
        final context = _createContext(skillId: 'my-skill');
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result =
            await interpolator.interpolate(r'Skill: ${context.skillId}');

        expect(result, 'Skill: my-skill');
      });

      test('resolves state variables', () async {
        final state = ContextState();
        state.set('counter', 42);

        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
          state: state,
        );

        final result =
            await interpolator.interpolate(r'Count: ${state.counter}');

        expect(result, 'Count: 42');
      });

      test('resolves config variables', () async {
        final config = SkillConfig({'model': 'gpt-4', 'temperature': 0.7});

        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
          config: config,
        );

        final result =
            await interpolator.interpolate(r'Model: ${config.model}');

        expect(result, 'Model: gpt-4');
      });

      test('resolves steps root object as map', () async {
        final stepResults = {
          'step1': const StepResult(
            stepId: 'step1',
            result: {'output': 'step1-result'},
          ),
        };

        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
          stepResults: stepResults,
        );

        // steps resolves to a Map<String, StepResult>
        // Accessing steps.step1 returns a StepResult object
        final stepsVal = await interpolator.evaluate('steps');
        expect(stepsVal, isA<Map>());
        expect((stepsVal as Map).containsKey('step1'), isTrue);
      });

      test('handles missing variables gracefully (returns empty)', () async {
        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
        );

        final result =
            await interpolator.interpolate(r'Value: ${inputs.nonexistent}');

        // Missing variables produce empty string in interpolation
        expect(result, 'Value: ');
      });

      test('preserves text around expressions', () async {
        final context = _createContext(inputs: {'x': 'mid'});
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result = await interpolator
            .interpolate(r'before ${inputs.x} after');

        expect(result, 'before mid after');
      });

      test('handles template with no expressions', () async {
        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
        );

        final result =
            await interpolator.interpolate('No expressions here');

        expect(result, 'No expressions here');
      });

      test('handles empty template', () async {
        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
        );

        final result = await interpolator.interpolate('');

        expect(result, '');
      });

      test('handles numeric expression results as strings', () async {
        final context = _createContext(inputs: {'count': 42});
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result =
            await interpolator.interpolate(r'Count is ${inputs.count}');

        expect(result, 'Count is 42');
      });
    });

    group('evaluate', () {
      test('returns raw value from expression', () async {
        final context = _createContext(inputs: {'val': 100});
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result = await interpolator.evaluate('inputs.val');

        expect(result, 100);
      });

      test('returns null for non-existent path', () async {
        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
        );

        final result = await interpolator.evaluate('inputs.missing');

        expect(result, isNull);
      });

      test('evaluates arithmetic expressions', () async {
        final context = _createContext(inputs: {'a': 10, 'b': 5});
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result = await interpolator.evaluate('inputs.a + inputs.b');

        expect(result, 15);
      });
    });

    group('evaluateCondition', () {
      test('returns true for truthy expression', () async {
        final context = _createContext(inputs: {'enabled': true});
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result =
            await interpolator.evaluateCondition('inputs.enabled');

        expect(result, isTrue);
      });

      test('returns false for falsy expression', () async {
        final context = _createContext(inputs: {'enabled': false});
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result =
            await interpolator.evaluateCondition('inputs.enabled');

        expect(result, isFalse);
      });

      test('evaluates comparison conditions', () async {
        final context = _createContext(inputs: {'score': 85});
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result =
            await interpolator.evaluateCondition('inputs.score > 70');

        expect(result, isTrue);
      });
    });

    group('interpolateMap', () {
      test('interpolates string values in map', () async {
        final context = _createContext(inputs: {'name': 'Alice'});
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result = await interpolator.interpolateMap({
          'greeting': r'Hello ${inputs.name}!',
          'count': 42,
        });

        expect(result['greeting'], 'Hello Alice!');
        expect(result['count'], 42);
      });

      test('recursively interpolates nested maps', () async {
        final context = _createContext(inputs: {'x': 'value'});
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result = await interpolator.interpolateMap({
          'outer': {
            'inner': r'${inputs.x}',
          },
        });

        expect((result['outer'] as Map)['inner'], 'value');
      });

      test('preserves non-string non-map values unchanged', () async {
        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
        );

        final result = await interpolator.interpolateMap({
          'number': 42,
          'bool_val': true,
          'list_val': [1, 2, 3],
          'null_val': null,
        });

        expect(result['number'], 42);
        expect(result['bool_val'], true);
        expect(result['list_val'], [1, 2, 3]);
        expect(result['null_val'], isNull);
      });

      test('handles empty map', () async {
        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
        );

        final result = await interpolator.interpolateMap({});

        expect(result, isEmpty);
      });

      test('handles deeply nested maps', () async {
        final context = _createContext(inputs: {'val': 'deep'});
        final interpolator = ExpressionInterpolator(
          skillContext: context,
        );

        final result = await interpolator.interpolateMap({
          'level1': {
            'level2': {
              'level3': r'${inputs.val}',
            },
          },
        });

        final level1 = result['level1'] as Map;
        final level2 = level1['level2'] as Map;
        expect(level2['level3'], 'deep');
      });
    });

    group('constructor defaults', () {
      test('uses empty ContextState when not provided', () async {
        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
        );

        // state should be empty, so state.anything resolves to null
        final result =
            await interpolator.interpolate(r'${state.anything}');

        expect(result, '');
      });

      test('uses empty SkillConfig when not provided', () async {
        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
        );

        final result =
            await interpolator.interpolate(r'${config.anything}');

        expect(result, '');
      });

      test('accepts claims and metrics as optional parameters', () async {
        final interpolator = ExpressionInterpolator(
          skillContext: _createContext(),
          claims: [
            {'id': 'c1', 'text': 'A claim'},
          ],
          metrics: {'accuracy': 0.95},
        );

        final metricsResult =
            await interpolator.evaluate('metrics.accuracy');
        expect(metricsResult, 0.95);
      });
    });
  });
}
