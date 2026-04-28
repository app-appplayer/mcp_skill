import 'package:test/test.dart';
import 'package:mcp_skill/src/runtime/error_context.dart';
import 'package:mcp_skill/src/exceptions/execution_exceptions.dart';

void main() {
  group('ErrorContext', () {
    late ErrorContext context;
    late DateTime timestamp;

    setUp(() {
      timestamp = DateTime(2025, 1, 15, 10, 30, 0);
      context = ErrorContext(
        skillId: 'skill-1',
        procedureId: 'proc-1',
        stepId: 'step-1',
        timestamp: timestamp,
        correlationId: 'corr-abc',
        inputs: {'input1': 'value1'},
        stepResults: {'step0': 'result0'},
        executedSteps: ['step0'],
        exception: SkillExecutionException('something failed'),
      );
    });

    test('constructor sets all fields', () {
      expect(context.skillId, 'skill-1');
      expect(context.procedureId, 'proc-1');
      expect(context.stepId, 'step-1');
      expect(context.timestamp, timestamp);
      expect(context.correlationId, 'corr-abc');
      expect(context.inputs, {'input1': 'value1'});
      expect(context.stepResults, {'step0': 'result0'});
      expect(context.executedSteps, ['step0']);
      expect(context.exception.message, 'something failed');
    });

    test('toJson includes all required fields', () {
      final json = context.toJson();
      expect(json['skillId'], 'skill-1');
      expect(json['procedureId'], 'proc-1');
      expect(json['stepId'], 'step-1');
      expect(json['timestamp'], timestamp.toIso8601String());
      expect(json['correlationId'], 'corr-abc');
      expect(json['executedSteps'], ['step0']);
      expect(json['error'], isA<Map<String, dynamic>>());
      expect(json['error']['code'], 'EXECUTION_ERROR');
      expect(json['error']['message'], 'something failed');
      expect(json['error']['isRetryable'], false);
    });

    test('toJson omits null optional fields', () {
      final ctx = ErrorContext(
        skillId: 'skill-2',
        procedureId: 'proc-2',
        timestamp: timestamp,
        inputs: {},
        stepResults: {},
        executedSteps: [],
        exception: SkillExecutionException('error'),
      );
      final json = ctx.toJson();
      expect(json.containsKey('stepId'), false);
      expect(json.containsKey('correlationId'), false);
    });

    test('toJson error section reflects retryable exception', () {
      final ctx = ErrorContext(
        skillId: 'skill-3',
        procedureId: 'proc-3',
        timestamp: timestamp,
        inputs: {},
        stepResults: {},
        executedSteps: [],
        exception: SkillTimeoutException('llm_call', const Duration(seconds: 5)),
      );
      final json = ctx.toJson();
      expect(json['error']['isRetryable'], true);
      expect(json['error']['code'], 'TIMEOUT');
    });
  });

  group('ErrorLogLevel', () {
    test('has all expected values', () {
      expect(ErrorLogLevel.values, hasLength(4));
      expect(ErrorLogLevel.values, contains(ErrorLogLevel.fatal));
      expect(ErrorLogLevel.values, contains(ErrorLogLevel.error));
      expect(ErrorLogLevel.values, contains(ErrorLogLevel.debug));
      expect(ErrorLogLevel.values, contains(ErrorLogLevel.trace));
    });

    test('name returns correct strings', () {
      expect(ErrorLogLevel.fatal.name, 'fatal');
      expect(ErrorLogLevel.error.name, 'error');
      expect(ErrorLogLevel.debug.name, 'debug');
      expect(ErrorLogLevel.trace.name, 'trace');
    });
  });
}
