import 'package:test/test.dart';
import 'package:mcp_skill/src/executor/skill_executor.dart';
import 'package:mcp_skill/src/definition/skill.dart';
import 'package:mcp_skill/src/definition/parameter.dart';
import 'package:mcp_skill/src/definition/step.dart';

void main() {
  group('ExecutionException', () {
    test('constructor creates exception with message', () {
      final exception = ExecutionException('Test error');

      expect(exception.message, equals('Test error'));
    });

    test('toString returns formatted message', () {
      final exception = ExecutionException('Something went wrong');

      final str = exception.toString();

      expect(str, contains('ExecutionException'));
      expect(str, contains('Something went wrong'));
    });
  });

  group('SkillExecutor', () {
    test('constructor creates instance with defaults', () {
      final executor = SkillExecutor();

      expect(executor.actionHandlers, isEmpty);
      expect(executor.maxSteps, equals(1000));
      expect(executor.timeout, isNull);
    });

    test('constructor accepts custom values', () {
      final handlers = {
        'testAction': (args, context) async => 'result',
      };
      final executor = SkillExecutor(
        actionHandlers: handlers,
        maxSteps: 100,
        timeout: const Duration(seconds: 30),
      );

      expect(executor.actionHandlers, equals(handlers));
      expect(executor.maxSteps, equals(100));
      expect(executor.timeout, equals(const Duration(seconds: 30)));
    });

    group('execute', () {
      test('returns failure for invalid inputs', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          inputs: [
            Parameter(name: 'required', type: ParameterType.string, required: true),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isFalse);
        expect(result.error, contains('validation failed'));
      });

      test('applies default input values', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          inputs: [
            Parameter(
              name: 'value',
              type: ParameterType.integer,
              required: false,
              defaultValue: 42,
            ),
          ],
          steps: [
            SkillStep(
              id: 'output',
              type: StepType.output,
              config: {'value': r'${inputs.value}'},
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isTrue);
        expect(result.output, equals(42));
      });

      test('returns success for empty steps', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isTrue);
        expect(result.output, isNull);
      });

      test('executes setVar step', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'setVar',
              type: StepType.setVar,
              config: {'name': 'count', 'value': 10},
            ),
            SkillStep(
              id: 'output',
              type: StepType.output,
              config: {'value': 'done'},
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isTrue);
        // Verify setVar step was executed by checking step results
        expect(result.stepResults['setVar'], equals(10));
      });

      test('executes transform step', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          inputs: [
            Parameter(name: 'value', type: ParameterType.integer),
          ],
          steps: [
            SkillStep(
              id: 'transform',
              type: StepType.transform,
              config: {'expression': 'inputs.value * 2', 'resultVar': 'doubled'},
            ),
            SkillStep(
              id: 'output',
              type: StepType.output,
              config: {'value': 'done'},
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {'value': 5});

        expect(result.success, isTrue);
        // Verify transform step computed correct result
        expect(result.stepResults['transform'], equals(10));
      });

      test('executes action step with handler', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'action',
              type: StepType.action,
              config: {
                'action': 'multiply',
                'arguments': {'a': 3, 'b': 4},
              },
            ),
            SkillStep(
              id: 'output',
              type: StepType.output,
              config: {'value': r'${steps.action}'},
            ),
          ],
        );

        final executor = SkillExecutor(
          actionHandlers: {
            'multiply': (args, context) async {
              final a = args['a'] as int;
              final b = args['b'] as int;
              return a * b;
            },
          },
        );
        final result = await executor.execute(skill, {});

        expect(result.success, isTrue);
        expect(result.output, equals(12));
      });

      test('returns failure for unknown action', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'action',
              type: StepType.action,
              config: {'action': 'unknownAction'},
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isFalse);
        expect(result.error, contains('Unknown action'));
      });

      test('returns failure for action step without action name', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'action',
              type: StepType.action,
              config: {}, // missing 'action' key
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isFalse);
        expect(result.error, contains('missing action name'));
      });

      test('skips step when condition is false', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          inputs: [
            Parameter(name: 'enabled', type: ParameterType.boolean),
          ],
          steps: [
            SkillStep(
              id: 'setVar',
              type: StepType.setVar,
              condition: 'inputs.enabled',
              config: {'name': 'value', 'value': 'executed'},
            ),
            SkillStep(
              id: 'output',
              type: StepType.output,
              config: {'value': 'done'},
            ),
          ],
        );

        final executor = SkillExecutor();

        // Should skip setVar step when enabled=false
        final result = await executor.execute(skill, {'enabled': false});
        expect(result.success, isTrue);
        expect(result.stepResults['setVar'], isNull);
      });

      test('executes step when condition is true', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          inputs: [
            Parameter(name: 'enabled', type: ParameterType.boolean),
          ],
          steps: [
            SkillStep(
              id: 'setVar',
              type: StepType.setVar,
              condition: 'inputs.enabled',
              config: {'name': 'value', 'value': 'executed'},
            ),
            SkillStep(
              id: 'output',
              type: StepType.output,
              config: {'value': 'done'},
            ),
          ],
        );

        final executor = SkillExecutor();

        final result = await executor.execute(skill, {'enabled': true});
        expect(result.success, isTrue);
        expect(result.stepResults['setVar'], equals('executed'));
      });

      test('executes wait step', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'wait',
              type: StepType.wait,
              config: {'duration': 10}, // 10ms
            ),
            SkillStep(
              id: 'output',
              type: StepType.output,
              config: {'value': 'done'},
            ),
          ],
        );

        final executor = SkillExecutor();
        final startTime = DateTime.now();
        final result = await executor.execute(skill, {});
        final elapsed = DateTime.now().difference(startTime);

        expect(result.success, isTrue);
        expect(result.output, equals('done'));
        expect(elapsed.inMilliseconds, greaterThanOrEqualTo(10));
      });

      test('executes log step', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'log',
              type: StepType.log,
              config: {'message': 'Test log message'},
            ),
            SkillStep(
              id: 'output',
              type: StepType.output,
              config: {'value': 'logged'},
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isTrue);
        expect(result.output, equals('logged'));
      });

      test('returns failure for transform step without expression', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'transform',
              type: StepType.transform,
              config: {}, // missing expression
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isFalse);
        expect(result.error, contains('missing expression'));
      });

      test('returns failure for setVar step without name', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'setVar',
              type: StepType.setVar,
              config: {'value': 'test'}, // missing name
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isFalse);
        expect(result.error, contains('missing variable name'));
      });

      test('returns failure for unimplemented step types', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'parallel',
              type: StepType.parallel,
              config: {},
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isFalse);
        expect(result.error, contains('not implemented'));
      });

      test('returns failure when max steps exceeded', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'step1',
              type: StepType.setVar,
              config: {'name': 'count', 'value': 0},
              next: ['step1'], // infinite loop
            ),
          ],
        );

        final executor = SkillExecutor(maxSteps: 5);
        final result = await executor.execute(skill, {});

        expect(result.success, isFalse);
        expect(result.error, contains('Maximum step count'));
      });

      test('follows next step', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'step1',
              type: StepType.setVar,
              config: {'name': 'value', 'value': 1},
              next: ['step3'], // skip step2
            ),
            SkillStep(
              id: 'step2',
              type: StepType.setVar,
              config: {'name': 'value', 'value': 2},
            ),
            SkillStep(
              id: 'step3',
              type: StepType.output,
              config: {'value': 'done'},
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isTrue);
        // step2 was skipped because step1 explicitly jumps to step3
        expect(result.stepResults['step1'], equals(1));
        expect(result.stepResults.containsKey('step2'), isFalse);
      });

      test('handles error step on failure', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'failStep',
              type: StepType.action,
              config: {'action': 'fail'},
              onError: 'errorHandler',
            ),
            SkillStep(
              id: 'errorHandler',
              type: StepType.output,
              config: {'value': 'error handled'},
            ),
          ],
        );

        final executor = SkillExecutor(
          actionHandlers: {
            'fail': (args, context) async => throw Exception('Intentional failure'),
          },
        );
        final result = await executor.execute(skill, {});

        expect(result.success, isTrue);
        expect(result.output, equals('error handled'));
      });

      test('returns output from output step immediately', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'output1',
              type: StepType.output,
              config: {'value': 'first output'},
            ),
            SkillStep(
              id: 'step2',
              type: StepType.setVar,
              config: {'name': 'never', 'value': 'reached'},
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isTrue);
        expect(result.output, equals('first output'));
      });

      test('returns null for output step without value', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'output',
              type: StepType.output,
              config: {},
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isTrue);
        expect(result.output, isNull);
      });

      test('includes step results in output', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'step1',
              type: StepType.setVar,
              config: {'name': 'x', 'value': 10},
            ),
            SkillStep(
              id: 'step2',
              type: StepType.setVar,
              config: {'name': 'y', 'value': 20},
            ),
            SkillStep(
              id: 'output',
              type: StepType.output,
              config: {'value': 'done'},
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.success, isTrue);
        expect(result.stepResults['step1'], equals(10));
        expect(result.stepResults['step2'], equals(20));
      });

      test('result includes duration', () async {
        final skill = Skill(
          id: 'skill1',
          name: 'Test Skill',
          steps: [
            SkillStep(
              id: 'wait',
              type: StepType.wait,
              config: {'duration': 10},
            ),
            SkillStep(
              id: 'output',
              type: StepType.output,
              config: {'value': 'done'},
            ),
          ],
        );

        final executor = SkillExecutor();
        final result = await executor.execute(skill, {});

        expect(result.duration, isNotNull);
        expect(result.duration!.inMilliseconds, greaterThanOrEqualTo(10));
      });
    });
  });
}
