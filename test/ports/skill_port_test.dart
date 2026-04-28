import 'package:test/test.dart';
import 'package:mcp_skill/src/ports/skill_port.dart';

void main() {
  group('SkillExecutionResult', () {
    test('constructor sets all fields', () {
      final result = SkillExecutionResult(
        executionId: 'exec-1',
        skillId: 'skill-1',
        success: true,
        output: 'hello',
        error: null,
        duration: const Duration(seconds: 2),
        stepResults: {'step1': 'done'},
      );
      expect(result.executionId, 'exec-1');
      expect(result.skillId, 'skill-1');
      expect(result.success, true);
      expect(result.output, 'hello');
      expect(result.error, isNull);
      expect(result.duration, const Duration(seconds: 2));
      expect(result.stepResults, {'step1': 'done'});
    });

    test('constructor uses default stepResults', () {
      const result = SkillExecutionResult(
        executionId: 'exec-1',
        skillId: 'skill-1',
        success: true,
        duration: Duration(seconds: 1),
      );
      expect(result.stepResults, isEmpty);
    });

    group('success factory', () {
      test('creates success result', () {
        final result = SkillExecutionResult.success(
          executionId: 'exec-ok',
          skillId: 'skill-ok',
          output: {'data': 42},
          duration: const Duration(milliseconds: 500),
        );
        expect(result.success, true);
        expect(result.output, {'data': 42});
        expect(result.error, isNull);
        expect(result.stepResults, isEmpty);
      });

      test('creates success result with stepResults', () {
        final result = SkillExecutionResult.success(
          executionId: 'exec-ok',
          skillId: 'skill-ok',
          output: 'done',
          duration: const Duration(seconds: 1),
          stepResults: {'s1': 'r1'},
        );
        expect(result.stepResults, {'s1': 'r1'});
      });
    });

    group('failure factory', () {
      test('creates failure result', () {
        final result = SkillExecutionResult.failure(
          executionId: 'exec-fail',
          skillId: 'skill-fail',
          error: 'something went wrong',
          duration: const Duration(seconds: 3),
        );
        expect(result.success, false);
        expect(result.output, isNull);
        expect(result.error, 'something went wrong');
        expect(result.stepResults, isEmpty);
      });

      test('creates failure result with stepResults', () {
        final result = SkillExecutionResult.failure(
          executionId: 'exec-fail',
          skillId: 'skill-fail',
          error: 'error',
          duration: const Duration(seconds: 1),
          stepResults: {'s1': 'partial'},
        );
        expect(result.stepResults, {'s1': 'partial'});
      });
    });
  });

  group('ActionContext', () {
    test('constructor sets all fields', () {
      const ctx = ActionContext(
        executionId: 'exec-1',
        skillId: 'skill-1',
        stepId: 'step-1',
        variables: {'var1': 'val1'},
        inputs: {'in1': 'val_in1'},
      );
      expect(ctx.executionId, 'exec-1');
      expect(ctx.skillId, 'skill-1');
      expect(ctx.stepId, 'step-1');
      expect(ctx.variables, {'var1': 'val1'});
      expect(ctx.inputs, {'in1': 'val_in1'});
    });

    test('constructor uses default empty maps', () {
      const ctx = ActionContext(
        executionId: 'exec-1',
        skillId: 'skill-1',
        stepId: 'step-1',
      );
      expect(ctx.variables, isEmpty);
      expect(ctx.inputs, isEmpty);
    });
  });
}
