import 'package:test/test.dart';
import 'package:mcp_skill/mcp_skill.dart';

void main() {
  group('ExecutionContext', () {
    test('creates context with default values', () {
      final ctx = ExecutionContext();

      expect(ctx.inputs, isEmpty);
      expect(ctx.variables, isEmpty);
      expect(ctx.stepResults, isEmpty);
    });

    test('creates context with inputs', () {
      final ctx = ExecutionContext(inputs: {'name': 'John', 'age': 30});

      expect(ctx.getInput('name'), equals('John'));
      expect(ctx.getInput('age'), equals(30));
      expect(ctx.getInput('missing'), isNull);
    });

    test('getVariable and setVariable work correctly', () {
      final ctx = ExecutionContext();

      ctx.setVariable('count', 0);
      expect(ctx.getVariable('count'), equals(0));

      ctx.setVariable('count', 5);
      expect(ctx.getVariable('count'), equals(5));
    });

    test('hasVariable checks existence', () {
      final ctx = ExecutionContext(variables: {'exists': true});

      expect(ctx.hasVariable('exists'), isTrue);
      expect(ctx.hasVariable('missing'), isFalse);
    });

    test('variables includes parent variables', () {
      final parent = ExecutionContext(variables: {'parentVar': 'parent'});
      final child = parent.child({'childVar': 'child'});

      expect(child.getVariable('parentVar'), equals('parent'));
      expect(child.getVariable('childVar'), equals('child'));
      expect(child.hasVariable('parentVar'), isTrue);
    });

    test('child context overrides parent variables', () {
      final parent = ExecutionContext(variables: {'value': 'parent'});
      final child = parent.child({'value': 'child'});

      expect(child.getVariable('value'), equals('child'));
    });

    test('setStepResult and getStepResult work correctly', () {
      final ctx = ExecutionContext();

      ctx.setStepResult('step-1', {'result': 'success'});
      expect(ctx.getStepResult('step-1'), equals({'result': 'success'}));
      expect(ctx.getStepResult('missing'), isNull);
    });

    test('toMap returns all context data', () {
      final ctx = ExecutionContext(
        inputs: {'input1': 'value1'},
        variables: {'var1': 'value1'},
      );
      ctx.setStepResult('step-1', 'result1');

      final map = ctx.toMap();
      expect(map['inputs'], equals({'input1': 'value1'}));
      expect(map['variables'], equals({'var1': 'value1'}));
      expect(map['steps'], equals({'step-1': 'result1'}));
    });

    test('inputs are immutable', () {
      final ctx = ExecutionContext(inputs: {'key': 'value'});
      final inputs = ctx.inputs;

      expect(() => (inputs as Map)['newKey'] = 'newValue', throwsA(anything));
    });
  });

  group('ExecutionResult', () {
    test('creates success result', () {
      final result = ExecutionResult.success('output value');

      expect(result.success, isTrue);
      expect(result.output, equals('output value'));
      expect(result.error, isNull);
    });

    test('creates success result with step results', () {
      final result = ExecutionResult.success(
        42,
        stepResults: {'step-1': 'done'},
        duration: const Duration(milliseconds: 100),
      );

      expect(result.stepResults['step-1'], equals('done'));
      expect(result.duration, equals(const Duration(milliseconds: 100)));
    });

    test('creates failure result', () {
      final result = ExecutionResult.failure('Something went wrong');

      expect(result.success, isFalse);
      expect(result.error, equals('Something went wrong'));
      expect(result.output, isNull);
    });

    test('toString shows correct format', () {
      final success = ExecutionResult.success('ok');
      final failure = ExecutionResult.failure('error');

      expect(success.toString(), contains('success'));
      expect(failure.toString(), contains('failure'));
    });
  });

  group('ExecutionTrace', () {
    test('add and entries work correctly', () {
      final trace = ExecutionTrace();

      trace.add(TraceEntry(
        stepId: 'step-1',
        type: TraceType.start,
        timestamp: DateTime.now(),
      ));

      expect(trace.entries.length, equals(1));
      expect(trace.entries.first.stepId, equals('step-1'));
    });

    test('clear removes all entries', () {
      final trace = ExecutionTrace();
      trace.add(TraceEntry(
        stepId: 'step-1',
        type: TraceType.start,
        timestamp: DateTime.now(),
      ));
      trace.add(TraceEntry(
        stepId: 'step-2',
        type: TraceType.complete,
        timestamp: DateTime.now(),
      ));

      trace.clear();
      expect(trace.entries, isEmpty);
    });
  });

  group('TraceEntry', () {
    test('creates entry with required fields', () {
      final now = DateTime.now();
      final entry = TraceEntry(
        stepId: 'step-1',
        type: TraceType.start,
        timestamp: now,
      );

      expect(entry.stepId, equals('step-1'));
      expect(entry.type, equals(TraceType.start));
      expect(entry.timestamp, equals(now));
      expect(entry.input, isNull);
      expect(entry.output, isNull);
    });

    test('creates entry with all fields', () {
      final entry = TraceEntry(
        stepId: 'step-2',
        type: TraceType.complete,
        timestamp: DateTime.now(),
        input: {'data': 'input'},
        output: {'data': 'output'},
        duration: const Duration(milliseconds: 50),
      );

      expect(entry.input, equals({'data': 'input'}));
      expect(entry.output, equals({'data': 'output'}));
      expect(entry.duration, equals(const Duration(milliseconds: 50)));
    });

    test('error entry has error field', () {
      final entry = TraceEntry(
        stepId: 'step-3',
        type: TraceType.error,
        timestamp: DateTime.now(),
        error: 'Step failed',
      );

      expect(entry.type, equals(TraceType.error));
      expect(entry.error, equals('Step failed'));
    });
  });
}
