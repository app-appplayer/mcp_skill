import 'package:test/test.dart';
import 'package:mcp_skill/src/expression/evaluation_context.dart';
import 'package:mcp_skill/src/runtime/skill_context.dart';
import 'package:mcp_skill/src/runtime/skill_result.dart';

void main() {
  group('ExpressionEvaluationContext', () {
    test('constructor with defaults', () {
      final ctx = ExpressionEvaluationContext();

      expect(ctx.inputs, isEmpty);
      expect(ctx.steps, isEmpty);
      expect(ctx.skillContext, isNull);
      expect(ctx.state, isEmpty);
      expect(ctx.config, isEmpty);
      expect(ctx.bundle, isNull);
      expect(ctx.facts, isNull);
      expect(ctx.claims, isNull);
      expect(ctx.metrics, isNull);
    });

    test('constructor with all fields', () {
      final skillCtx = SkillContext(
        contextId: 'ctx1',
        skillId: 'skill1',
        runId: 'run1',
        traceId: 'trace1',
        request: 'test request',
        workspaceId: 'ws1',
        asOf: DateTime(2025, 1, 1),
      );

      final stepResults = {
        'step1': StepResult(stepId: 'step1', result: 'done'),
      };

      final ctx = ExpressionEvaluationContext(
        inputs: {'query': 'test'},
        steps: stepResults,
        skillContext: skillCtx,
        state: {'counter': 0},
        config: {'maxRetries': 3},
        bundle: {'id': 'bundle1'},
        facts: [
          {'factId': 'f1'}
        ],
        claims: [
          {'claimId': 'c1'}
        ],
        metrics: {'accuracy': 0.95},
      );

      expect(ctx.inputs['query'], equals('test'));
      expect(ctx.steps['step1']!.stepId, equals('step1'));
      expect(ctx.skillContext, isNotNull);
      expect(ctx.state['counter'], equals(0));
      expect(ctx.config['maxRetries'], equals(3));
      expect(ctx.bundle, isNotNull);
      expect(ctx.facts, isNotNull);
      expect(ctx.claims, isNotNull);
      expect(ctx.metrics!['accuracy'], equals(0.95));
    });

    group('resolve()', () {
      late ExpressionEvaluationContext ctx;

      setUp(() {
        ctx = ExpressionEvaluationContext(
          inputs: {'query': 'hello'},
          steps: {
            's1': StepResult(stepId: 's1', result: 42),
          },
          skillContext: SkillContext(
            contextId: 'ctx1',
            skillId: 'skill1',
            runId: 'run1',
            traceId: 'trace1',
            request: 'test',
            workspaceId: 'ws1',
            asOf: DateTime(2025, 1, 1),
            policyVersion: 'v1',
            userId: 'user1',
          ),
          state: {'mode': 'fast'},
          config: {'limit': 100},
          bundle: {'name': 'test-bundle'},
          facts: {'entities': []},
          claims: ['claim1'],
          metrics: {'score': 0.9},
        );
      });

      test('resolves inputs root', () {
        final result = ctx.resolve('inputs');
        expect(result, isA<Map>());
        expect(result['query'], equals('hello'));
      });

      test('resolves steps root', () {
        final result = ctx.resolve('steps');
        expect(result, isA<Map>());
        expect((result as Map).containsKey('s1'), isTrue);
      });

      test('resolves context root to _contextMap()', () {
        final result = ctx.resolve('context');
        expect(result, isA<Map>());
        expect(result['contextId'], equals('ctx1'));
        expect(result['skillId'], equals('skill1'));
        expect(result['runId'], equals('run1'));
        expect(result['traceId'], equals('trace1'));
        expect(result['request'], equals('test'));
        expect(result['workspaceId'], equals('ws1'));
        expect(result['policyVersion'], equals('v1'));
        expect(result['userId'], equals('user1'));
        expect(result['asOf'], isA<String>());
      });

      test('resolves state root', () {
        final result = ctx.resolve('state');
        expect(result, isA<Map>());
        expect(result['mode'], equals('fast'));
      });

      test('resolves config root', () {
        final result = ctx.resolve('config');
        expect(result, isA<Map>());
        expect(result['limit'], equals(100));
      });

      test('resolves bundle root', () {
        final result = ctx.resolve('bundle');
        expect(result['name'], equals('test-bundle'));
      });

      test('resolves facts root', () {
        final result = ctx.resolve('facts');
        expect(result, isA<Map>());
      });

      test('resolves claims root', () {
        final result = ctx.resolve('claims');
        expect(result, isA<List>());
        expect((result as List).length, equals(1));
      });

      test('resolves metrics root', () {
        final result = ctx.resolve('metrics');
        expect(result, isA<Map>());
        expect(result['score'], equals(0.9));
      });

      test('returns null for unknown root', () {
        expect(ctx.resolve('unknown'), isNull);
        expect(ctx.resolve(''), isNull);
        expect(ctx.resolve('Inputs'), isNull);
      });
    });

    group('resolve() with null context', () {
      test('context root returns null when skillContext is null', () {
        final ctx = ExpressionEvaluationContext();
        expect(ctx.resolve('context'), isNull);
      });

      test('claims root returns null when claims is null', () {
        final ctx = ExpressionEvaluationContext();
        expect(ctx.resolve('claims'), isNull);
      });

      test('metrics root returns null when metrics is null', () {
        final ctx = ExpressionEvaluationContext();
        expect(ctx.resolve('metrics'), isNull);
      });

      test('bundle root returns null when bundle is null', () {
        final ctx = ExpressionEvaluationContext();
        expect(ctx.resolve('bundle'), isNull);
      });

      test('facts root returns null when facts is null', () {
        final ctx = ExpressionEvaluationContext();
        expect(ctx.resolve('facts'), isNull);
      });
    });

    group('_contextMap()', () {
      test('includes all SkillContext fields', () {
        final asOf = DateTime(2025, 6, 15);
        final ctx = ExpressionEvaluationContext(
          skillContext: SkillContext(
            contextId: 'c1',
            skillId: 's1',
            runId: 'r1',
            traceId: 't1',
            request: 'analyze data',
            workspaceId: 'w1',
            asOf: asOf,
            policyVersion: 'p1',
            userId: 'u1',
          ),
        );

        final contextMap = ctx.resolve('context') as Map<String, dynamic>;

        expect(contextMap['contextId'], equals('c1'));
        expect(contextMap['skillId'], equals('s1'));
        expect(contextMap['runId'], equals('r1'));
        expect(contextMap['traceId'], equals('t1'));
        expect(contextMap['request'], equals('analyze data'));
        expect(contextMap['workspaceId'], equals('w1'));
        expect(contextMap['asOf'], equals(asOf.toIso8601String()));
        expect(contextMap['policyVersion'], equals('p1'));
        expect(contextMap['userId'], equals('u1'));
      });
    });
  });
}
