import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/error_aggregator.dart';
import 'package:mcp_skill/src/exceptions/execution_exceptions.dart';

void main() {
  group('ErrorAggregator', () {
    late ErrorAggregator aggregator;

    setUp(() {
      aggregator = ErrorAggregator();
    });

    test('starts with no errors', () {
      expect(aggregator.hasErrors, false);
      expect(aggregator.hasFatalErrors, false);
      expect(aggregator.stepErrors, isEmpty);
    });

    test('addStepError adds to list', () {
      final error = StepError(
        stepId: 'step1',
        exception: SkillExecutionException('test'),
        recovered: false,
      );
      aggregator.addStepError(error);
      expect(aggregator.stepErrors.length, 1);
      expect(aggregator.hasErrors, true);
    });

    test('hasErrors is true after adding an error', () {
      aggregator.addStepError(StepError(
        stepId: 'step1',
        exception: SkillExecutionException('fail'),
        recovered: true,
      ));
      expect(aggregator.hasErrors, true);
    });

    test('hasFatalErrors is false when all errors are recovered', () {
      aggregator.addStepError(StepError(
        stepId: 'step1',
        exception: SkillExecutionException('recovered error'),
        recovered: true,
      ));
      expect(aggregator.hasFatalErrors, false);
    });

    test('hasFatalErrors is true when any error is unrecovered', () {
      aggregator.addStepError(StepError(
        stepId: 'step1',
        exception: SkillExecutionException('recovered'),
        recovered: true,
      ));
      aggregator.addStepError(StepError(
        stepId: 'step2',
        exception: SkillExecutionException('fatal'),
        recovered: false,
      ));
      expect(aggregator.hasFatalErrors, true);
    });

    test('aggregate throws StateError when no errors', () {
      expect(() => aggregator.aggregate(), throwsStateError);
    });

    test('aggregate returns ProcedureError with single error', () {
      final stepError = StepError(
        stepId: 'step1',
        exception: SkillExecutionException('single error'),
        recovered: false,
      );
      aggregator.addStepError(stepError);

      final result = aggregator.aggregate();
      expect(result.primaryError, stepError);
      expect(result.allErrors.length, 1);
      expect(result.message, 'single error');
    });

    test('aggregate with multiple errors builds aggregate message', () {
      aggregator.addStepError(StepError(
        stepId: 'step1',
        exception: SkillExecutionException('first error'),
        recovered: true,
      ));
      aggregator.addStepError(StepError(
        stepId: 'step2',
        exception: SkillExecutionException('second error'),
        recovered: false,
      ));

      final result = aggregator.aggregate();
      expect(result.allErrors.length, 2);
      expect(result.message, contains('2 errors'));
      expect(result.message, contains('first error'));
    });

    test('aggregate selects first fatal error as primaryError', () {
      aggregator.addStepError(StepError(
        stepId: 'step1',
        exception: SkillExecutionException('recovered'),
        recovered: true,
      ));
      aggregator.addStepError(StepError(
        stepId: 'step2',
        exception: SkillExecutionException('fatal one'),
        recovered: false,
      ));
      aggregator.addStepError(StepError(
        stepId: 'step3',
        exception: SkillExecutionException('fatal two'),
        recovered: false,
      ));

      final result = aggregator.aggregate();
      expect(result.primaryError.stepId, 'step2');
    });

    test('aggregate uses first error as primary when no fatal errors', () {
      aggregator.addStepError(StepError(
        stepId: 'step1',
        exception: SkillExecutionException('first recovered'),
        recovered: true,
      ));
      aggregator.addStepError(StepError(
        stepId: 'step2',
        exception: SkillExecutionException('second recovered'),
        recovered: true,
      ));

      final result = aggregator.aggregate();
      expect(result.primaryError.stepId, 'step1');
    });

    test('aggregate allErrors is unmodifiable', () {
      aggregator.addStepError(StepError(
        stepId: 'step1',
        exception: SkillExecutionException('error'),
        recovered: false,
      ));

      final result = aggregator.aggregate();
      expect(
        () => result.allErrors.add(StepError(
          stepId: 'extra',
          exception: SkillExecutionException('extra'),
          recovered: false,
        )),
        throwsUnsupportedError,
      );
    });
  });

  group('StepError', () {
    test('constructor sets all fields', () {
      final exception = SkillExecutionException('test message');
      final error = StepError(
        stepId: 'step_abc',
        exception: exception,
        recovered: true,
        recoveryResult: null,
      );
      expect(error.stepId, 'step_abc');
      expect(error.exception, exception);
      expect(error.recovered, true);
      expect(error.recoveryResult, isNull);
    });

    test('message delegates to exception.message', () {
      final error = StepError(
        stepId: 'step1',
        exception: SkillExecutionException('delegated message'),
        recovered: false,
      );
      expect(error.message, 'delegated message');
    });
  });

  group('ProcedureError', () {
    test('constructor sets all fields', () {
      final stepError = StepError(
        stepId: 'step1',
        exception: SkillExecutionException('err'),
        recovered: false,
      );
      final procedureError = ProcedureError(
        primaryError: stepError,
        allErrors: [stepError],
        message: 'aggregated',
      );
      expect(procedureError.primaryError, stepError);
      expect(procedureError.allErrors.length, 1);
      expect(procedureError.message, 'aggregated');
    });
  });
}
