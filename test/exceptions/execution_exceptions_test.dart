import 'package:test/test.dart';
import 'package:mcp_skill/src/exceptions/execution_exceptions.dart';
import 'package:mcp_skill/src/exceptions/skill_exception.dart';

void main() {
  group('SkillExecutionException', () {
    test('sets message and default code', () {
      final ex = SkillExecutionException('exec failed');
      expect(ex.message, 'exec failed');
      expect(ex.code, 'EXECUTION_ERROR');
    });

    test('accepts optional path, cause, stackTrace', () {
      final cause = Exception('root');
      final trace = StackTrace.current;
      final ex = SkillExecutionException(
        'fail',
        path: 'steps[0]',
        cause: cause,
        stackTrace: trace,
      );
      expect(ex.path, 'steps[0]');
      expect(ex.cause, same(cause));
      expect(ex.stackTrace, same(trace));
    });

    test('isRetryable is false by default', () {
      expect(SkillExecutionException('x').isRetryable, isFalse);
    });

    test('extends SkillException', () {
      expect(SkillExecutionException('x'), isA<SkillException>());
    });
  });

  group('StepExecutionException', () {
    test('stores stepId and stepOrder', () {
      final ex = StepExecutionException('step-1', 3, 'step failed');
      expect(ex.stepId, 'step-1');
      expect(ex.stepOrder, 3);
      expect(ex.message, 'step failed');
      expect(ex.path, 'steps[step-1]');
    });

    test('overrides code to STEP_EXECUTION_ERROR', () {
      expect(StepExecutionException('s', 0, 'm').code, 'STEP_EXECUTION_ERROR');
    });

    test('accepts optional cause', () {
      final cause = Exception('inner');
      final ex = StepExecutionException('s', 0, 'm', cause: cause);
      expect(ex.cause, same(cause));
    });

    test('extends SkillExecutionException', () {
      expect(
        StepExecutionException('s', 0, 'm'),
        isA<SkillExecutionException>(),
      );
    });
  });

  group('ActionExecutionException', () {
    test('stores actionType and optional stepId', () {
      final ex = ActionExecutionException('llm', 'LLM call failed',
          stepId: 'step-2');
      expect(ex.actionType, 'llm');
      expect(ex.stepId, 'step-2');
      expect(ex.message, 'LLM call failed');
    });

    test('overrides code to ACTION_EXECUTION_ERROR', () {
      expect(
        ActionExecutionException('llm', 'm').code,
        'ACTION_EXECUTION_ERROR',
      );
    });

    test('accepts optional cause', () {
      final cause = Exception('e');
      final ex = ActionExecutionException('tool', 'm', cause: cause);
      expect(ex.cause, same(cause));
    });

    test('extends SkillExecutionException', () {
      expect(
        ActionExecutionException('llm', 'm'),
        isA<SkillExecutionException>(),
      );
    });
  });

  group('UnsupportedActionException', () {
    test('stores actionType and generates message', () {
      final ex = UnsupportedActionException('quantum');
      expect(ex.actionType, 'quantum');
      expect(ex.message, 'Action type "quantum" is not supported');
    });

    test('overrides code to UNSUPPORTED_ACTION', () {
      expect(UnsupportedActionException('x').code, 'UNSUPPORTED_ACTION');
    });

    test('extends SkillExecutionException', () {
      expect(
        UnsupportedActionException('x'),
        isA<SkillExecutionException>(),
      );
    });
  });

  group('SkillTimeoutException', () {
    test('stores operation and timeout', () {
      final ex = SkillTimeoutException(
        'llm.complete',
        const Duration(seconds: 30),
      );
      expect(ex.operation, 'llm.complete');
      expect(ex.timeout, const Duration(seconds: 30));
      expect(ex.message, contains('30000ms'));
      expect(ex.message, contains('llm.complete'));
    });

    test('overrides code to TIMEOUT', () {
      expect(
        SkillTimeoutException('op', Duration.zero).code,
        'TIMEOUT',
      );
    });

    test('isRetryable is true', () {
      final ex = SkillTimeoutException('op', Duration.zero);
      expect(ex.isRetryable, isTrue);
    });

    test('retryDelay is 1 second', () {
      final ex = SkillTimeoutException('op', Duration.zero);
      expect(ex.retryDelay, const Duration(seconds: 1));
    });

    test('extends SkillExecutionException', () {
      expect(
        SkillTimeoutException('op', Duration.zero),
        isA<SkillExecutionException>(),
      );
    });
  });

  group('BudgetExceededException', () {
    test('stores budgetType, limit, actual', () {
      final ex = BudgetExceededException('tokens', 1000, 1500);
      expect(ex.budgetType, 'tokens');
      expect(ex.limit, 1000);
      expect(ex.actual, 1500);
      expect(ex.message, 'tokens budget exceeded: 1500 > 1000');
    });

    test('overrides code to BUDGET_EXCEEDED', () {
      expect(BudgetExceededException('t', 0, 0).code, 'BUDGET_EXCEEDED');
    });

    test('extends SkillExecutionException', () {
      expect(
        BudgetExceededException('t', 0, 0),
        isA<SkillExecutionException>(),
      );
    });
  });

  group('QualityGateException', () {
    test('stores gateId and custom message', () {
      final ex = QualityGateException('gate-1', 'score too low');
      expect(ex.gateId, 'gate-1');
      expect(ex.message, 'score too low');
    });

    test('generates default message when message is null', () {
      final ex = QualityGateException('gate-2', null);
      expect(ex.message, 'Quality gate gate-2 failed');
    });

    test('overrides code to QUALITY_GATE_FAILED', () {
      expect(QualityGateException('g', null).code, 'QUALITY_GATE_FAILED');
    });

    test('extends SkillExecutionException', () {
      expect(
        QualityGateException('g', null),
        isA<SkillExecutionException>(),
      );
    });
  });
}
